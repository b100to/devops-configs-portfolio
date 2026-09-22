generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      lambda_name    = "dev-scaler-lambda-${var.environment}"
      schedule_group = "dev-scaler"
      lambda_arn     = "arn:aws:lambda:${global.region}:${var.account_id}:function:${local.lambda_name}"

      lambda_code = <<-PYTHON
import json, os, base64, re, ssl, urllib.request, urllib.parse, datetime, time
import boto3
from botocore.signers import RequestSigner

CLUSTER = os.environ["CLUSTER_NAME"]
SLACK_TOKEN = os.environ["SLACK_BOT_TOKEN"]
SLACK_CHANNEL = os.environ["SLACK_CHANNEL"]
LAMBDA_ARN = os.environ["LAMBDA_ARN"]
SCHEDULER_ROLE = os.environ["SCHEDULER_ROLE_ARN"]
REGION = os.environ.get("AWS_REGION", "ap-northeast-2")
NODEPOOLS = json.loads(os.environ.get("NODEPOOLS_CONFIG", '[{"name":"base","limits":{"cpu":"8"}}]'))
SCHEDULE_GROUP = "dev-scaler"
SESSION_PARAM = "/dev-scaler/session"
LIMITS_PARAM = "/dev-scaler/original-limits"
FALLBACK_LIMITS = {p["name"]: p["limits"] for p in NODEPOOLS}
WARMUP_POD_NS = "default"
WARMUP_POD_NAME = "dev-scaler-warmup"

_cluster = {}
_token = None


# ── K8s Auth ─────────────────────────────────────────────────

def cluster_info():
    global _cluster
    if not _cluster:
        c = boto3.client("eks", region_name=REGION).describe_cluster(name=CLUSTER)["cluster"]
        _cluster = {"endpoint": c["endpoint"], "ca": c["certificateAuthority"]["data"]}
    return _cluster


def bearer_token():
    global _token
    if _token:
        return _token
    s = boto3.session.Session()
    c = s.client("sts", region_name=REGION)
    signer = RequestSigner(
        c.meta.service_model.service_id, REGION, "sts", "v4",
        s.get_credentials(), s.events,
    )
    url = signer.generate_presigned_url(
        {
            "method": "GET",
            "url": f"https://sts.{REGION}.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15",
            "body": {},
            "headers": {"x-k8s-aws-id": CLUSTER},
            "context": {},
        },
        region_name=REGION, expires_in=60, operation_name="",
    )
    _token = "k8s-aws-v1." + re.sub(r"=+", "", base64.urlsafe_b64encode(url.encode()).decode())
    return _token


def k8s(method, path, body=None):
    ci = cluster_info()
    ctx = ssl.create_default_context()
    ctx.load_verify_locations(cadata=base64.b64decode(ci["ca"]).decode())
    hdrs = {"Authorization": f"Bearer {bearer_token()}", "Accept": "application/json"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        hdrs["Content-Type"] = "application/merge-patch+json" if method == "PATCH" else "application/json"
    req = urllib.request.Request(f"{ci['endpoint']}{path}", data=data, headers=hdrs, method=method)
    resp = urllib.request.urlopen(req, context=ctx, timeout=30)
    return json.loads(resp.read().decode())


# ── Karpenter Operations ────────────────────────────────────

def get_nodepool(name):
    return k8s("GET", f"/apis/karpenter.sh/v1/nodepools/{name}")


def get_all_nodeclaims():
    pool_names = {p["name"] for p in NODEPOOLS}
    items = k8s("GET", "/apis/karpenter.sh/v1/nodeclaims").get("items", [])
    return [nc for nc in items if nc["metadata"].get("labels", {}).get("karpenter.sh/nodepool") in pool_names]


def do_scale_down():
    r = {"nodes_deleted": 0, "errors": []}
    # Save current limits → SSM, then set all pools to 0
    all_limits = {}
    for pool in NODEPOOLS:
        name = pool["name"]
        try:
            np = get_nodepool(name)
            all_limits[name] = np["spec"].get("limits", pool["limits"])
            k8s("PATCH", f"/apis/karpenter.sh/v1/nodepools/{name}",
                {"spec": {"limits": {"cpu": "0"}}})
            print(f"NodePool {name} limits set to cpu:0 (was {all_limits[name]})")
        except Exception as e:
            r["errors"].append(f"patch {name}: {e}")
    if all_limits:
        ssm_put(LIMITS_PARAM, json.dumps(all_limits))
    # Delete all NodeClaims → nodes drain
    try:
        for nc in get_all_nodeclaims():
            nc_name = nc["metadata"]["name"]
            try:
                k8s("DELETE", f"/apis/karpenter.sh/v1/nodeclaims/{nc_name}")
                r["nodes_deleted"] += 1
            except Exception as e:
                r["errors"].append(f"delete {nc_name}: {e}")
    except Exception as e:
        r["errors"].append(f"list nodeclaims: {e}")
    return r


def create_warmup_pod():
    """Create a small pause pod to trigger Karpenter node provisioning."""
    try:
        k8s("DELETE", f"/api/v1/namespaces/{WARMUP_POD_NS}/pods/{WARMUP_POD_NAME}")
        time.sleep(3)
    except Exception:
        pass
    pod = {
        "apiVersion": "v1",
        "kind": "Pod",
        "metadata": {"name": WARMUP_POD_NAME, "namespace": WARMUP_POD_NS},
        "spec": {
            "restartPolicy": "Never",
            "containers": [{"name": "pause",
                "image": "public.ecr.aws/eks-distro/kubernetes/pause:3.9",
                "resources": {"requests": {"cpu": "100m", "memory": "64Mi"}}}],
        },
    }
    k8s("POST", f"/api/v1/namespaces/{WARMUP_POD_NS}/pods", pod)
    print("Warmup pod created")


def wait_for_node(timeout=240):
    """Wait until at least one Karpenter NodeClaim is Ready."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            for nc in get_all_nodeclaims():
                for cond in nc.get("status", {}).get("conditions", []):
                    if cond.get("type") == "Ready" and cond.get("status") == "True":
                        print(f"Node ready: {nc['metadata']['name']}")
                        return True
        except Exception as e:
            print(f"wait_for_node error: {e}")
        time.sleep(10)
    print("Timeout waiting for node ready")
    return False


def delete_warmup_pod():
    """Delete the warmup pod."""
    try:
        k8s("DELETE", f"/api/v1/namespaces/{WARMUP_POD_NS}/pods/{WARMUP_POD_NAME}")
        print("Warmup pod deleted")
    except Exception as e:
        print(f"delete warmup pod: {e}")


def do_scale_up():
    r = {"limits_restored": False, "limits": FALLBACK_LIMITS, "errors": []}
    try:
        raw = ssm_get(LIMITS_PARAM)
        saved = json.loads(raw) if raw else {}
    except Exception:
        saved = {}
    for pool in NODEPOOLS:
        name = pool["name"]
        limits = saved.get(name, pool["limits"])
        try:
            k8s("PATCH", f"/apis/karpenter.sh/v1/nodepools/{name}",
                {"spec": {"limits": limits}})
            print(f"NodePool {name} limits restored to {limits}")
        except Exception as e:
            r["errors"].append(f"restore {name}: {e}")
    r["limits_restored"] = len(r["errors"]) == 0
    r["limits"] = {p["name"]: saved.get(p["name"], p["limits"]) for p in NODEPOOLS}
    # Warmup: force Karpenter to provision a node so it's ready before workloads start
    if r["limits_restored"]:
        try:
            create_warmup_pod()
            wait_for_node()
            delete_warmup_pod()
        except Exception as e:
            r["errors"].append(f"warmup: {e}")
    return r


# ── SSM helpers ─────────────────────────────────────────────

def ssm_get(name):
    try:
        return boto3.client("ssm", region_name=REGION).get_parameter(Name=name)["Parameter"]["Value"]
    except Exception:
        return None


def ssm_put(name, value):
    boto3.client("ssm", region_name=REGION).put_parameter(
        Name=name, Value=value, Type="String", Overwrite=True,
    )


# ── Session ──────────────────────────────────────────────────

def get_session():
    v = ssm_get(SESSION_PARAM)
    return json.loads(v) if v else {}


def set_session(data):
    ssm_put(SESSION_PARAM, json.dumps(data))


def create_session(user, hours):
    end = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=hours)
    data = {"user": user, "end_time": end.isoformat(), "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    set_session(data)
    sched = boto3.client("scheduler", region_name=REGION)
    try:
        sched.delete_schedule(Name="session-end", GroupName=SCHEDULE_GROUP)
    except Exception:
        pass
    sched.create_schedule(
        Name="session-end", GroupName=SCHEDULE_GROUP,
        ScheduleExpression=f"at({end.strftime('%Y-%m-%dT%H:%M:%S')})",
        ScheduleExpressionTimezone="UTC",
        FlexibleTimeWindow={"Mode": "OFF"},
        Target={
            "Arn": LAMBDA_ARN, "RoleArn": SCHEDULER_ROLE,
            "Input": json.dumps({"source": "self", "action": "session_end"}),
        },
        ActionAfterCompletion="DELETE",
    )
    return data


def delete_session():
    set_session({})
    try:
        boto3.client("scheduler", region_name=REGION).delete_schedule(
            Name="session-end", GroupName=SCHEDULE_GROUP,
        )
    except Exception:
        pass


# ── Slack ────────────────────────────────────────────────────

def slack_post(blocks, text=""):
    msg = {"channel": SLACK_CHANNEL, "text": text, "blocks": blocks}
    req = urllib.request.Request(
        "https://slack.com/api/chat.postMessage",
        data=json.dumps(msg).encode(),
        headers={
            "Content-Type": "application/json; charset=utf-8",
            "Authorization": f"Bearer {SLACK_TOKEN}",
        },
    )
    r = json.loads(urllib.request.urlopen(req).read().decode())
    if not r.get("ok"):
        print(f"Slack error: {r.get('error')}")


def notify_down(results, trigger):
    blocks = [
        {"type": "header", "text": {"type": "plain_text", "text": "Dev Cluster Scaled Down"}},
        {"type": "section", "text": {"type": "mrkdwn", "text": (
            f"*Trigger:* {trigger}\n"
            f"*Nodes deleted:* {results['nodes_deleted']}\n"
            f"*NodePool limits:* cpu=0"
        )}},
    ]
    if results["errors"]:
        blocks.append({"type": "section", "text": {"type": "mrkdwn", "text":
            f"*Errors ({len(results['errors'])}):*\n" + "\\n".join(results["errors"][:5])}})
    slack_post(blocks, "Dev cluster scaled down")


def notify_up(results, trigger):
    limits = results.get("limits", FALLBACK_LIMITS)
    blocks = [
        {"type": "header", "text": {"type": "plain_text", "text": "Dev Cluster Scaled Up"}},
        {"type": "section", "text": {"type": "mrkdwn", "text": (
            f"*Trigger:* {trigger}\n"
            f"*Limits restored:* {results['limits_restored']}\n"
            f"*NodePool limits:* {json.dumps(limits)}"
        )}},
    ]
    if results["errors"]:
        blocks.append({"type": "section", "text": {"type": "mrkdwn", "text":
            f"*Errors ({len(results['errors'])}):*\n" + "\\n".join(results["errors"][:5])}})
    slack_post(blocks, "Dev cluster scaled up")


# ── Handler ──────────────────────────────────────────────────

def handler(event, context):
    print(f"Event: {json.dumps(event)}")
    if event.get("source") == "self":
        return worker(event)
    if "requestContext" in event:
        return slash_command(event)
    if "action" in event:
        return worker(event)
    return {"statusCode": 400, "body": "Unknown event"}


def slash_command(event):
    body = event.get("body", "")
    if event.get("isBase64Encoded"):
        body = base64.b64decode(body).decode()
    p = urllib.parse.parse_qs(body)
    text = p.get("text", [""])[0].strip()
    user = p.get("user_name", ["unknown"])[0]
    parts = text.split() if text else ["status"]
    cmd, args = parts[0], parts[1:]

    if cmd not in ("up", "down", "status"):
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "response_type": "ephemeral",
                "text": "Usage: `/dev [up [hours] | down | status]`",
            }),
        }

    action = cmd
    if cmd == "up" and args:
        action = "session"
    elif cmd == "down":
        action = "end"

    boto3.client("lambda", region_name=REGION).invoke(
        FunctionName=os.environ["AWS_LAMBDA_FUNCTION_NAME"],
        InvocationType="Event",
        Payload=json.dumps({"source": "self", "action": action, "args": args, "user": user}).encode(),
    )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"response_type": "ephemeral", "text": f"Processing `/dev {text or 'status'}`..."}),
    }


def worker(event):
    action = event.get("action", "")
    user = event.get("user", "scheduler")
    args = event.get("args", [])

    if action == "scale_up":
        notify_up(do_scale_up(), "Schedule (08:00 KST)")
    elif action == "scale_down":
        s = get_session()
        if s.get("end_time"):
            end = datetime.datetime.fromisoformat(s["end_time"])
            if end > datetime.datetime.now(datetime.timezone.utc):
                slack_post([{"type": "section", "text": {"type": "mrkdwn",
                    "text": f"Scheduled scale-down skipped: session by *{s.get('user', '?')}* until `{s['end_time'][:16]}`"}}])
                return
        notify_down(do_scale_down(), "Schedule (00:00 KST)")
    elif action == "up":
        notify_up(do_scale_up(), f"`/dev up` by {user}")
    elif action == "session":
        hours = float(args[0]) if args else 2
        r = do_scale_up()
        sess = create_session(user, hours)
        notify_up(r, f"`/dev up {hours}` by {user}")
        end_str = sess["end_time"][:16].replace("T", " ")
        slack_post([{"type": "section", "text": {"type": "mrkdwn",
            "text": f"Session created: auto scale-down at `{end_str} UTC`"}}])
    elif action == "session_end":
        delete_session()
        notify_down(do_scale_down(), "Session expired")
    elif action == "end":
        delete_session()
        notify_down(do_scale_down(), f"`/dev down` by {user}")
    elif action == "status":
        report_status()


def report_status():
    s = get_session()
    try:
        all_limits = {}
        scaled_down = True
        for pool in NODEPOOLS:
            np = get_nodepool(pool["name"])
            lim = np["spec"].get("limits", {})
            all_limits[pool["name"]] = lim
            if str(lim.get("cpu", "")) != "0":
                scaled_down = False
        nodes = len(get_all_nodeclaims())
    except Exception as e:
        slack_post([{"type": "section", "text": {"type": "mrkdwn", "text": f"Error: {e}"}}])
        return

    st = "Scaled Down" if scaled_down else "Running"
    limits_str = ", ".join(f"{k}: cpu={v.get('cpu','?')}" for k, v in all_limits.items())
    blocks = [
        {"type": "header", "text": {"type": "plain_text", "text": f"Dev Cluster: {st}"}},
        {"type": "section", "fields": [
            {"type": "mrkdwn", "text": f"*Nodes:* {nodes}"},
            {"type": "mrkdwn", "text": f"*NodePool limits:* {limits_str}"},
        ]},
    ]
    if s.get("end_time"):
        end = datetime.datetime.fromisoformat(s["end_time"])
        rem = end - datetime.datetime.now(datetime.timezone.utc)
        if rem.total_seconds() > 0:
            m = int(rem.total_seconds() / 60)
            blocks.append({"type": "section", "text": {"type": "mrkdwn",
                "text": f"*Session:* by {s.get('user', '?')}, {m // 60}h {m % 60}m remaining"}})
        else:
            blocks.append({"type": "section", "text": {"type": "mrkdwn", "text": "*Session:* expired"}})
    else:
        blocks.append({"type": "section", "text": {"type": "mrkdwn", "text": "*Session:* None"}})
    slack_post(blocks, f"Dev cluster: {st}")
      PYTHON
    }
  }
}
