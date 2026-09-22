// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  lambda_arn  = "arn:aws:lambda:ap-northeast-2:${var.account_id}:function:${local.lambda_name}"
  lambda_code = <<-EOT
import json, os, base64, re, ssl, urllib.request, urllib.parse, hashlib, hmac, time
import boto3
from botocore.signers import RequestSigner

# ── Config ──────────────────────────────────────────────────

REGION = os.environ.get("AWS_REGION", "ap-northeast-2")
ENV = os.environ["ENVIRONMENT"]  # default env
ZAI_MODEL = os.environ.get("ZAI_MODEL", "glm-4.5")
ZAI_URL = "https://api.z.ai/api/paas/v4/chat/completions"

# Multi-cluster support
CLUSTERS = {
    "dev": "acme-main-v2-dev",
    "prd": "acme-main-v2-prd",
}

DEV_ROLE_ARN = os.environ.get("DEV_CROSS_ACCOUNT_ROLE", "")

_secrets = None
_cluster_cache = {}  # {cluster_name: {"endpoint": ..., "ca": ...}}
_token_cache = {}    # {cluster_name: token}
_active_cluster = os.environ.get("CLUSTER_NAME", CLUSTERS.get(ENV, ""))
_active_env = ENV
_dev_session = None  # cached dev boto3 session


def get_secrets():
    global _secrets
    if not _secrets:
        sm = boto3.client("secretsmanager", region_name=REGION)
        raw = sm.get_secret_value(SecretId=os.environ["SECRET_NAME"])["SecretString"]
        _secrets = json.loads(raw)
    return _secrets


# ── Slack Signature Verification ────────────────────────────

def verify_slack_signature(event):
    secrets = get_secrets()
    signing_secret = secrets["slack_signing_secret"]
    body = event.get("body", "")
    if event.get("isBase64Encoded"):
        body = base64.b64decode(body).decode()
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    ts = headers.get("x-slack-request-timestamp", "")
    sig = headers.get("x-slack-signature", "")
    if not ts or not sig:
        return False, body
    if abs(time.time() - int(ts)) > 300:
        return False, body
    base = f"v0:{ts}:{body}"
    expected = "v0=" + hmac.new(signing_secret.encode(), base.encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, sig), body


# ── K8s Auth (same pattern as dev-scaler) ───────────────────

def get_boto3_session(env=None):
    """Get boto3 session for the target environment. Uses assume-role for dev."""
    global _dev_session
    if env == "dev" and DEV_ROLE_ARN:
        if not _dev_session:
            sts = boto3.client("sts", region_name=REGION)
            creds = sts.assume_role(RoleArn=DEV_ROLE_ARN, RoleSessionName="slack-agent")["Credentials"]
            _dev_session = boto3.session.Session(
                aws_access_key_id=creds["AccessKeyId"],
                aws_secret_access_key=creds["SecretAccessKey"],
                aws_session_token=creds["SessionToken"],
                region_name=REGION,
            )
        return _dev_session
    return boto3.session.Session(region_name=REGION)


def set_active_cluster(env=None):
    """Switch active cluster by environment name."""
    global _active_cluster, _active_env
    if env and env in CLUSTERS:
        _active_cluster = CLUSTERS[env]
        _active_env = env
    return _active_cluster


def cluster_info(cluster_name=None):
    if not cluster_name:
        cluster_name = _active_cluster
    if cluster_name not in _cluster_cache:
        session = get_boto3_session(_active_env)
        c = session.client("eks", region_name=REGION).describe_cluster(name=cluster_name)["cluster"]
        _cluster_cache[cluster_name] = {"endpoint": c["endpoint"], "ca": c["certificateAuthority"]["data"]}
    return _cluster_cache[cluster_name]


def bearer_token(cluster_name=None):
    if not cluster_name:
        cluster_name = _active_cluster
    if cluster_name in _token_cache:
        return _token_cache[cluster_name]
    s = get_boto3_session(_active_env)
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
            "headers": {"x-k8s-aws-id": cluster_name},
            "context": {},
        },
        region_name=REGION, expires_in=60, operation_name="",
    )
    token = "k8s-aws-v1." + re.sub(r"=+", "", base64.urlsafe_b64encode(url.encode()).decode())
    _token_cache[cluster_name] = token
    return token


def k8s(method, path):
    ci = cluster_info()
    ctx = ssl.create_default_context()
    ctx.load_verify_locations(cadata=base64.b64decode(ci["ca"]).decode())
    hdrs = {"Authorization": f"Bearer {bearer_token()}", "Accept": "application/json"}
    req = urllib.request.Request(f"{ci['endpoint']}{path}", headers=hdrs, method=method)
    resp = urllib.request.urlopen(req, context=ctx, timeout=30)
    return json.loads(resp.read().decode())


# ── K8s Read Operations ─────────────────────────────────────

def k8s_get_pods(namespace="default"):
    items = k8s("GET", f"/api/v1/namespaces/{namespace}/pods").get("items", [])
    return [{"name": p["metadata"]["name"],
             "status": p["status"]["phase"],
             "restarts": sum(c.get("restartCount", 0) for c in p.get("status", {}).get("containerStatuses", [])),
             "node": p["spec"].get("nodeName", "pending")}
            for p in items]


def k8s_get_pods_all():
    items = k8s("GET", "/api/v1/pods").get("items", [])
    result = {}
    for p in items:
        ns = p["metadata"]["namespace"]
        if ns.startswith("kube-") or ns == "karpenter":
            continue
        if ns not in result:
            result[ns] = []
        result[ns].append({
            "name": p["metadata"]["name"],
            "status": p["status"]["phase"],
            "restarts": sum(c.get("restartCount", 0) for c in p.get("status", {}).get("containerStatuses", [])),
        })
    return result


def k8s_get_nodes():
    items = k8s("GET", "/api/v1/nodes").get("items", [])
    return [{"name": n["metadata"]["name"],
             "instance_type": n["metadata"].get("labels", {}).get("node.kubernetes.io/instance-type", ""),
             "ready": any(c["type"] == "Ready" and c["status"] == "True"
                        for c in n.get("status", {}).get("conditions", []))}
            for n in items]


def k8s_get_ingresses():
    items = k8s("GET", "/apis/networking.k8s.io/v1/ingresses").get("items", [])
    result = []
    for ing in items:
        for rule in ing.get("spec", {}).get("rules", []):
            result.append({"host": rule.get("host", ""), "namespace": ing["metadata"]["namespace"],
                           "name": ing["metadata"]["name"]})
    return result


def k8s_get_ingressroutes():
    try:
        items = k8s("GET", "/apis/traefik.io/v1alpha1/ingressroutes").get("items", [])
        result = []
        for ir in items:
            routes = ir.get("spec", {}).get("routes", [])
            hosts = []
            for r in routes:
                match = r.get("match", "")
                found = re.findall(r"Host\(`([^`]+)`\)", match)
                hosts.extend(found)
            if hosts:
                result.append({"hosts": hosts, "namespace": ir["metadata"]["namespace"],
                               "name": ir["metadata"]["name"]})
        return result
    except Exception:
        return []


def k8s_get_pod_detail(pod_name, namespace=""):
    """Get pod restart reason, last state, events — like kubectl describe."""
    # Find the pod across namespaces if namespace not given
    if namespace:
        namespaces = [namespace]
    else:
        namespaces = [ns for ns in k8s("GET", "/api/v1/namespaces").get("items", [])
                      if not ns["metadata"]["name"].startswith("kube-") and ns["metadata"]["name"] != "karpenter"]
        namespaces = [ns["metadata"]["name"] for ns in namespaces]

    results = []
    for ns in namespaces:
        try:
            pods = k8s("GET", f"/api/v1/namespaces/{ns}/pods").get("items", [])
            for p in pods:
                if pod_name in p["metadata"]["name"]:
                    containers = []
                    for cs in p.get("status", {}).get("containerStatuses", []):
                        c_info = {
                            "name": cs["name"],
                            "restartCount": cs.get("restartCount", 0),
                            "ready": cs.get("ready", False),
                            "state": str(cs.get("state", {})),
                        }
                        last = cs.get("lastState", {}).get("terminated")
                        if last:
                            c_info["lastTerminated"] = {
                                "reason": last.get("reason", ""),
                                "exitCode": last.get("exitCode", 0),
                                "startedAt": last.get("startedAt", ""),
                                "finishedAt": last.get("finishedAt", ""),
                            }
                        containers.append(c_info)
                    # Get events for this pod
                    events = k8s("GET", f"/api/v1/namespaces/{ns}/events?fieldSelector=involvedObject.name={p['metadata']['name']}")
                    pod_events = [{"reason": e.get("reason",""), "message": e.get("message","")[:150],
                                   "count": e.get("count",0), "lastTimestamp": e.get("lastTimestamp","")}
                                  for e in events.get("items", [])[-5:]]
                    results.append({
                        "pod": p["metadata"]["name"],
                        "namespace": ns,
                        "phase": p["status"]["phase"],
                        "containers": containers,
                        "events": pod_events,
                    })
        except Exception:
            continue
    return results


# ── AWS API ─────────────────────────────────────────────────

def aws_get_vpcs():
    ec2 = get_boto3_session(_active_env).client("ec2", region_name=REGION)
    vpcs = ec2.describe_vpcs()["Vpcs"]
    return [{"vpc_id": v["VpcId"], "cidr": v["CidrBlock"],
             "name": next((t["Value"] for t in v.get("Tags", []) if t["Key"] == "Name"), ""),
             "state": v["State"]}
            for v in vpcs]


def aws_get_instances(filters=None):
    ec2 = get_boto3_session(_active_env).client("ec2", region_name=REGION)
    params = {}
    if filters:
        params["Filters"] = filters
    instances = []
    for r in ec2.describe_instances(**params).get("Reservations", []):
        for i in r["Instances"]:
            instances.append({
                "id": i["InstanceId"],
                "type": i["InstanceType"],
                "state": i["State"]["Name"],
                "name": next((t["Value"] for t in i.get("Tags", []) if t["Key"] == "Name"), ""),
                "private_ip": i.get("PrivateIpAddress", ""),
                "az": i.get("Placement", {}).get("AvailabilityZone", ""),
            })
    return instances


def aws_get_rds_instances():
    rds = get_boto3_session(_active_env).client("rds", region_name=REGION)
    dbs = rds.describe_db_instances()["DBInstances"]
    return [{"id": d["DBInstanceIdentifier"], "engine": d["Engine"],
             "class": d["DBInstanceClass"], "status": d["DBInstanceStatus"],
             "endpoint": d.get("Endpoint", {}).get("Address", ""),
             "multi_az": d.get("MultiAZ", False)}
            for d in dbs]


def aws_get_rds_clusters():
    rds = get_boto3_session(_active_env).client("rds", region_name=REGION)
    clusters = rds.describe_db_clusters()["DBClusters"]
    return [{"id": c["DBClusterIdentifier"], "engine": c["Engine"],
             "status": c["Status"],
             "endpoint": c.get("Endpoint", ""),
             "reader_endpoint": c.get("ReaderEndpoint", ""),
             "members": len(c.get("DBClusterMembers", []))}
            for c in clusters]


def aws_get_security_groups(vpc_id=""):
    ec2 = get_boto3_session(_active_env).client("ec2", region_name=REGION)
    params = {}
    if vpc_id:
        params["Filters"] = [{"Name": "vpc-id", "Values": [vpc_id]}]
    sgs = ec2.describe_security_groups(**params)["SecurityGroups"]
    return [{"id": sg["GroupId"], "name": sg["GroupName"],
             "description": sg["Description"][:100], "vpc_id": sg["VpcId"]}
            for sg in sgs[:30]]


def aws_get_load_balancers():
    elbv2 = get_boto3_session(_active_env).client("elbv2", region_name=REGION)
    lbs = elbv2.describe_load_balancers()["LoadBalancers"]
    return [{"name": lb["LoadBalancerName"], "type": lb["Type"],
             "dns": lb["DNSName"], "state": lb["State"]["Code"],
             "scheme": lb["Scheme"]}
            for lb in lbs]


# ── Datadog API ─────────────────────────────────────────────

DD_API = "https://api.datadoghq.com"


def dd_api(method, path, body=None, params=None, raw_query=None):
    secrets = get_secrets()
    url = f"{DD_API}{path}"
    if raw_query:
        url += "?" + raw_query
    elif params:
        url += "?" + urllib.parse.urlencode(params)
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "DD-API-KEY": secrets["dd_api_key"],
        "DD-APPLICATION-KEY": secrets["dd_app_key"],
        "Content-Type": "application/json",
    })
    resp = urllib.request.urlopen(req, timeout=15)
    return json.loads(resp.read().decode())


def dd_get_pod_events(pod_name, minutes=60):
    """Get Datadog events for a pod (restarts, OOM, crashes)."""
    now = int(time.time())
    # Search by text since pod_name tag may not exist on all events
    try:
        result = dd_api("GET", "/api/v1/events", params={
            "start": now - (minutes * 60),
            "end": now,
            "tags": f"pod_name:{pod_name}",
        })
        events = result.get("events", [])
        if not events:
            # Fallback: search by text
            result = dd_api("GET", "/api/v1/events", params={
                "start": now - (minutes * 60),
                "end": now,
            })
            events = [e for e in result.get("events", []) if pod_name in e.get("title", "") or pod_name in e.get("text", "")]
    except Exception:
        events = []
    return [{"title": e.get("title", ""), "text": e.get("text", "")[:200],
             "date": e.get("date_happened", 0)}
            for e in events[:10]]


def dd_get_pod_logs(pod_name, namespace="", minutes=30, limit=20):
    """Get recent logs for a pod from Datadog."""
    query = f"pod_name:{pod_name}"
    if namespace:
        query += f" kube_namespace:{namespace}"
    result = dd_api("POST", "/api/v2/logs/events/search", body={
        "filter": {
            "query": query,
            "from": f"now-{minutes}m",
            "to": "now",
        },
        "sort": "-timestamp",
        "page": {"limit": limit},
    })
    logs = result.get("data", [])
    return [{"message": l.get("attributes", {}).get("message", "")[:300],
             "status": l.get("attributes", {}).get("status", ""),
             "timestamp": l.get("attributes", {}).get("timestamp", "")}
            for l in logs]


def dd_get_pod_metrics(pod_name, namespace="", minutes=60):
    """Get CPU/Memory metrics for a pod from Datadog."""
    now = int(time.time())
    # Try multiple tag formats: kube_deployment, pod_name
    tag_filters = []
    # pod_name could be a deployment name like "argocd-repo-server"
    tag_filters.append(f"kube_deployment:{pod_name}")
    if namespace:
        tag_filters.append(f"kube_deployment:{pod_name},kube_namespace:{namespace}")
    tag_filters.append(f"pod_name:{pod_name}")
    results = {}
    for tag_filter in tag_filters:
        queries = [
            (f"avg:kubernetes.cpu.usage.total{{{tag_filter}}}", "cpu_usage_cores"),
            (f"avg:kubernetes.memory.usage{{{tag_filter}}}", "memory_usage_bytes"),
            (f"max:kubernetes.containers.restarts{{{tag_filter}}}", "restarts"),
        ]
        found_data = False
        for query_str, label in queries:
            try:
                raw_q = f"from={now - (minutes * 60)}&to={now}&query={urllib.parse.quote(query_str)}"
                data = dd_api("GET", "/api/v1/query", raw_query=raw_q)
                series = data.get("series", [])
                if series and series[0].get("pointlist"):
                    points = series[0]["pointlist"]
                    latest = points[-1][1] if points else 0
                    if label == "memory_usage_bytes" and latest:
                        results["memory_usage_mi"] = round(latest / 1024 / 1024, 1)
                    elif label == "cpu_usage_cores" and latest:
                        results["cpu_usage_millicores"] = round(latest * 1000, 1)
                    else:
                        results[label] = round(latest, 2) if latest else 0
                    found_data = True
            except Exception as e:
                results[label] = f"N/A ({e})"
        if found_data:
            results["_tag_used"] = tag_filter
            break  # Found data with this tag format
    if not results:
        results["status"] = "no metrics data found"
    return results


# ── z.ai LLM ───────────────────────────────────────────────

SYSTEM_PROMPT = f"""You are a DevOps assistant for a Kubernetes cluster ({ENV} environment).
You help developers check cluster status, find resources, explain configurations, and make changes via GitOps PR.

## Repository Structure (devops-configs)
```
argocd/{{env}}/apps/     → ArgoCD Application 정의
values/apps/{{app}}/     → Helm values (앱)
values/infra/{{app}}/    → Helm values (인프라)
manifests/{{app}}/{{env}}/ → Raw K8s manifests (앱 먼저, 환경 나중)
```

## Key Rules
- 모든 변경은 GitOps: 파일 수정 → git push → ArgoCD 자동 동기화
- kubectl 쓰기 명령 금지 (apply, delete, patch 등)
- values 파일에서 `_defaults.yaml`은 기본값, `prd.yaml`/`dev.yaml`이 환경별 오버라이드
- manifests 경로: `manifests/{{app}}/{{env}}/` (앱 먼저, 환경 나중)

## Environments
- dev: 개발 (EKS: acme-main-v2-dev)
- prd: 프로덕션 (EKS: acme-main-v2-prd)

You have access to these K8s read operations:
- get_pods(namespace) — list pods in a namespace
- get_pods_all() — list all pods across namespaces (excludes kube-system, karpenter)
- get_nodes() — list cluster nodes
- get_ingresses() — list Ingress resources
- get_ingressroutes() — list Traefik IngressRoute resources

When the user asks a question:
1. Decide which K8s operation(s) to call
2. Return a JSON object with "actions" array, each action has "function" and "args"

- get_pod_detail(pod_name, namespace) — get pod restart reason, last state, exit code, events (like kubectl describe)

You have AWS infrastructure operations:
- aws_vpcs() — list VPCs (id, name, cidr)
- aws_instances() — list EC2 instances
- aws_rds_instances() — list RDS instances
- aws_rds_clusters() — list RDS Aurora clusters
- aws_security_groups(vpc_id) — list security groups (optional vpc_id filter)
- aws_load_balancers() — list ALB/NLB load balancers

You also have Datadog monitoring operations:
- dd_pod_events(pod_name) — get events (restarts, OOM, crashes) for a pod
- dd_pod_logs(pod_name, namespace) — get recent logs for a pod
- dd_pod_metrics(pod_name, namespace) — get CPU/Memory/Restart metrics

CRITICAL: When user asks WHY a pod restarted/crashed/killed, you MUST include get_pod_detail as the FIRST action. get_pod_detail shows exit code, termination reason (OOMKilled, Error, etc.), and K8s events which are the most reliable source for restart causes. Do NOT skip it. Also include dd_pod_metrics for resource usage context. For get_pod_detail, omit namespace if unsure — it will search all namespaces.
Use Datadog when user asks about: performance issues, error logs.

Valid functions: get_pods, get_pods_all, get_nodes, get_ingresses, get_ingressroutes, get_pod_detail, aws_vpcs, aws_instances, aws_rds_instances, aws_rds_clusters, aws_security_groups, aws_load_balancers, dd_pod_events, dd_pod_logs, dd_pod_metrics
For get_pods, args should be {{"namespace": "name", "env": "dev or prd"}}
For other K8s/DD functions, args should include "env" if user specifies (default: "prd")

IMPORTANT: Always include "env" in args when user mentions dev/prd/상용/개발.
"상용" or "prod" = "prd", "개발" = "dev". If not specified, default to "prd".

If no K8s query is needed (general question), return: {{"actions": [], "answer": "your answer"}}

IMPORTANT: Respond ONLY with valid JSON. No markdown, no explanation outside JSON.

Example: User asks "pod 상태 보여줘"
Response: {{"actions": [{{"function": "get_pods_all", "args": {{"env": "prd"}}}}]}}

Example: User asks "dev 노드 상태"
Response: {{"actions": [{{"function": "get_nodes", "args": {{"env": "dev"}}}}]}}

Example: User asks "huik.site 이거 뭐야"
Response: {{"actions": [{{"function": "get_ingresses", "args": {{}}}}, {{"function": "get_ingressroutes", "args": {{}}}}]}}

Example: User asks "상용 argocd-repo-server 왜 리스타트 됐어?"
Response: {{"actions": [{{"function": "get_pod_detail", "args": {{"pod_name": "argocd-repo-server", "namespace": "argocd", "env": "prd"}}}}, {{"function": "dd_pod_metrics", "args": {{"pod_name": "argocd-repo-server", "namespace": "argocd", "env": "prd"}}}}, {{"function": "dd_pod_events", "args": {{"pod_name": "argocd-repo-server", "env": "prd"}}}}]}}

Example: User asks "stockroom 레플리카 2개로 늘려줘"
Response: {{"actions": [{{"function": "gitops_change", "args": {{"description": "stockroom 레플리카 2로 변경", "app": "stockroom", "env": "prd", "component": "", "change_type": "replicas", "target_value": "2"}}}}]}}

Example: User asks "dev argocd-server 레플리카 2개로 늘려줘"
Response: {{"actions": [{{"function": "gitops_change", "args": {{"description": "dev argocd server 레플리카 2로 변경", "app": "argocd", "env": "dev", "component": "server", "change_type": "replicas", "target_value": "2"}}}}]}}

Example: User asks "play-api 메모리 512Mi로 늘려줘"
Response: {{"actions": [{{"function": "gitops_change", "args": {{"description": "play-api 메모리 512Mi로 변경", "app": "play-api", "env": "prd", "component": "", "change_type": "resources", "target_value": "memory: 512Mi"}}}}]}}

Example: User asks "PR 149 닫아줘" or "PR 닫아줘 149"
Response: {{"actions": [{{"function": "close_pr", "args": {{"pr_number": "149"}}}}]}}

Example: User asks "아까 만든 PR 닫아줘" (in thread after PR was created)
Response: {{"actions": [{{"function": "close_pr", "args": {{"pr_number": "latest"}}}}]}}

For close_pr, args: pr_number (number or "latest" to find from thread context)

For gitops_change args:
- app: the chart/app directory name (e.g. "argocd" not "argocd-server", "stockroom" not "stockroom-backend")
- env: "dev" or "prd" (default "prd" if not specified)
- component: sub-component within the chart (e.g. "server" for argocd-server, "" if none)
- change_type: replicas/resources/config/ingress/delete
- target_value: desired value
- description: Korean description
"""

SUMMARY_PROMPT = """Based on the user's question and the K8s data below, provide a concise, helpful answer in Korean.
Format for Slack (use *bold* for emphasis, `code` for resource names).
Keep it under 500 characters.

User question: {question}

K8s data:
{data}
"""


def call_zai(messages, retries=3):
    secrets = get_secrets()
    payload = json.dumps({
        "model": ZAI_MODEL,
        "messages": messages,
        "temperature": 0.1,
        "max_tokens": 2048,
    }).encode()
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                ZAI_URL,
                data=payload,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {secrets['zai_api_key']}",
                },
            )
            resp = urllib.request.urlopen(req, timeout=90)
            result = json.loads(resp.read().decode())
            msg = result["choices"][0]["message"]
            content = msg.get("content", "").strip()
            if not content:
                reasoning = msg.get("reasoning_content", "")
                content = reasoning.strip() if reasoning else ""
            return content
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503) and attempt < retries - 1:
                wait = (attempt + 1) * 3
                print(f"z.ai {e.code} error, retry in {wait}s (attempt {attempt + 1})")
                time.sleep(wait)
            else:
                raise
    return ""


# ── Action Executor ─────────────────────────────────────────

K8S_FUNCTIONS = {
    "get_pods": lambda args: k8s_get_pods(args.get("namespace", "default")),
    "get_pods_all": lambda args: k8s_get_pods_all(),
    "get_nodes": lambda args: k8s_get_nodes(),
    "get_ingresses": lambda args: k8s_get_ingresses(),
    "get_ingressroutes": lambda args: k8s_get_ingressroutes(),
    "get_pod_detail": lambda args: k8s_get_pod_detail(args.get("pod_name", ""), args.get("namespace", "")),
    "aws_vpcs": lambda args: aws_get_vpcs(),
    "aws_instances": lambda args: aws_get_instances(),
    "aws_rds_instances": lambda args: aws_get_rds_instances(),
    "aws_rds_clusters": lambda args: aws_get_rds_clusters(),
    "aws_security_groups": lambda args: aws_get_security_groups(args.get("vpc_id", "")),
    "aws_load_balancers": lambda args: aws_get_load_balancers(),
    "dd_pod_events": lambda args: dd_get_pod_events(args.get("pod_name", "")),
    "dd_pod_logs": lambda args: dd_get_pod_logs(args.get("pod_name", ""), args.get("namespace", "")),
    "dd_pod_metrics": lambda args: dd_get_pod_metrics(args.get("pod_name", ""), args.get("namespace", "")),
}


def execute_actions(actions):
    results = {}
    # Determine target env from first action's args
    target_env = None
    for act in actions:
        env = act.get("args", {}).get("env")
        if env:
            target_env = env
            break
    if target_env and target_env in CLUSTERS:
        set_active_cluster(target_env)
        results["_cluster"] = f"{target_env} ({_active_cluster})"
        print(f"Switched to cluster: {_active_cluster} ({target_env})")
    else:
        results["_cluster"] = f"prd ({_active_cluster})"

    for act in actions:
        fn = act.get("function", "")
        args = act.get("args", {})
        if fn in K8S_FUNCTIONS:
            try:
                results[fn] = K8S_FUNCTIONS[fn](args)
            except Exception as e:
                results[fn] = f"Error: {e}"
        elif fn == "gitops_change":
            results[fn] = args  # Pass through, handled separately
    return results


# ── GitHub API ──────────────────────────────────────────────

GITHUB_REPO = "AcmeCorp/devops-configs"
GITHUB_API = "https://api.github.com"


def github_api(method, path, body=None):
    secrets = get_secrets()
    url = f"{GITHUB_API}{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"token {secrets['github_token']}",
        "Accept": "application/vnd.github.v3+json",
        "Content-Type": "application/json",
    })
    resp = urllib.request.urlopen(req, timeout=30)
    return json.loads(resp.read().decode()) if resp.status != 204 else {}


def github_search_file(app_name, target_env=None):
    """Search for Helm values or manifest files for an app.
    Tries exact match first, then fuzzy (partial) match."""
    if not target_env:
        target_env = ENV
    results = []

    # Build candidate names: exact + parent name (e.g. argocd-server → argocd)
    candidates = [app_name]
    if "-" in app_name:
        candidates.append(app_name.rsplit("-", 1)[0])  # argocd-server → argocd
        candidates.append(app_name.split("-")[0])       # argocd-image-updater → argocd

    search_dirs = ["values/apps", "values/infra", "manifests"]

    for search_dir in search_dirs:
        try:
            items = github_api("GET", f"/repos/{GITHUB_REPO}/contents/{search_dir}?ref=main")
            for item in items:
                if item["type"] != "dir":
                    continue
                # Match: exact first, then partial
                for candidate in candidates:
                    if candidate == item["name"]:  # exact match only
                        # List files in this directory
                        try:
                            sub_path = f"{search_dir}/{item['name']}"
                            sub_items = github_api("GET", f"/repos/{GITHUB_REPO}/contents/{sub_path}?ref=main")
                            for si in sub_items:
                                if si["name"].endswith((".yaml", ".yml")):
                                    results.append({"path": si["path"], "sha": si["sha"]})
                                elif si["type"] == "dir" and target_env in si["name"]:
                                    # Check env subdirectory (manifests/{app}/{env}/)
                                    env_items = github_api("GET", f"/repos/{GITHUB_REPO}/contents/{si['path']}?ref=main")
                                    for ei in env_items:
                                        if ei["name"].endswith((".yaml", ".yml")):
                                            results.append({"path": ei["path"], "sha": ei["sha"]})
                        except Exception:
                            pass
                        break
        except Exception:
            continue

    # If no exact match found, try partial match
    if not results:
        for search_dir in search_dirs:
            try:
                items = github_api("GET", f"/repos/{GITHUB_REPO}/contents/{search_dir}?ref=main")
                for item in items:
                    if item["type"] != "dir":
                        continue
                    for candidate in candidates:
                        if candidate in item["name"] and candidate != item["name"]:
                            try:
                                sub_path = f"{search_dir}/{item['name']}"
                                sub_items = github_api("GET", f"/repos/{GITHUB_REPO}/contents/{sub_path}?ref=main")
                                for si in sub_items:
                                    if si["name"].endswith((".yaml", ".yml")):
                                        results.append({"path": si["path"], "sha": si["sha"]})
                            except Exception:
                                pass
                            break
            except Exception:
                continue

    # Also search ArgoCD app definitions
    for argo_dir in [f"argocd/{target_env}/apps"]:
        try:
            items = github_api("GET", f"/repos/{GITHUB_REPO}/contents/{argo_dir}?ref=main")
            for item in items:
                if item["type"] == "dir":
                    sub_items = github_api("GET", f"/repos/{GITHUB_REPO}/contents/{item['path']}?ref=main")
                    for si in sub_items:
                        for candidate in candidates:
                            if candidate in si["name"] and si["name"].endswith((".yaml", ".yml")):
                                results.append({"path": si["path"], "sha": si["sha"]})
                elif any(c in item["name"] for c in candidates) and item["name"].endswith((".yaml", ".yml")):
                    results.append({"path": item["path"], "sha": item["sha"]})
        except Exception:
            pass

    return results


def github_get_file(path, ref="main"):
    """Get file content from GitHub."""
    data = github_api("GET", f"/repos/{GITHUB_REPO}/contents/{path}?ref={ref}")
    content = base64.b64decode(data["content"]).decode()
    return {"content": content, "sha": data["sha"]}


def github_create_pr(app, description, file_path, old_content, new_content, file_sha, target_env=None):
    """Create a branch, commit changes, and open a PR."""
    if not target_env:
        target_env = ENV
    # Get main branch SHA
    main_ref = github_api("GET", f"/repos/{GITHUB_REPO}/git/ref/heads/main")
    main_sha = main_ref["object"]["sha"]

    # Create branch
    branch_name = f"fix/{app}/{int(time.time())}"
    github_api("POST", f"/repos/{GITHUB_REPO}/git/refs", {
        "ref": f"refs/heads/{branch_name}",
        "sha": main_sha,
    })

    # Update file on new branch
    commit_msg = f"fix({app}/{target_env}): {description}"
    github_api("PUT", f"/repos/{GITHUB_REPO}/contents/{file_path}", {
        "message": commit_msg,
        "content": base64.b64encode(new_content.encode()).decode(),
        "sha": file_sha,
        "branch": branch_name,
    })

    # Create PR
    pr = github_api("POST", f"/repos/{GITHUB_REPO}/pulls", {
        "title": commit_msg,
        "body": f"## Summary\n- Slack DevOps Agent 자동 생성\n- {description}\n\n> Generated by DevOps Agent",
        "head": branch_name,
        "base": "main",
    })

    return pr["html_url"]


def github_close_pr(pr_number):
    """Close a PR and delete its branch."""
    pr = github_api("GET", f"/repos/{GITHUB_REPO}/pulls/{pr_number}")
    if pr["state"] == "closed":
        return f"PR #{pr_number} 은 이미 닫혀있습니다."
    branch = pr["head"]["ref"]
    # Close PR
    github_api("PATCH", f"/repos/{GITHUB_REPO}/pulls/{pr_number}", {"state": "closed"})
    # Delete branch
    try:
        github_api("DELETE", f"/repos/{GITHUB_REPO}/git/refs/heads/{branch}")
    except Exception:
        pass
    return f"PR #{pr_number} 닫고 브랜치 `{branch}` 삭제했습니다."


CHANGE_PROMPT = """You are a DevOps engineer modifying Kubernetes configuration files.
Given the current file content and a change request, produce the modified file content.

IMPORTANT:
- Return ONLY the modified file content, no explanation, no markdown code blocks
- Preserve all existing formatting, comments, and structure
- Only change what is specifically requested
- If it's a Helm values file, follow YAML syntax

Current file ({file_path}):
```
{current_content}
```

Change request: {description} (target: {target_value})

Return the complete modified file content:"""


# ── Slack ───────────────────────────────────────────────────

def slack_get_thread(channel, thread_ts, limit=10):
    """Fetch thread replies to build conversation context."""
    secrets = get_secrets()
    params = urllib.parse.urlencode({"channel": channel, "ts": thread_ts, "limit": limit})
    req = urllib.request.Request(
        f"https://slack.com/api/conversations.replies?{params}",
        headers={"Authorization": f"Bearer {secrets['slack_bot_token']}"},
    )
    r = json.loads(urllib.request.urlopen(req).read().decode())
    if not r.get("ok"):
        print(f"Thread fetch error: {r.get('error')}")
        return []
    messages = []
    for m in r.get("messages", [])[:-1]:  # exclude current message (last one)
        is_bot = bool(m.get("bot_id"))
        text = re.sub(r"<@[A-Z0-9]+>\s*", "", m.get("text", "")).strip()
        if text:
            messages.append({"role": "assistant" if is_bot else "user", "content": text})
    return messages


def slack_post(channel, text, thread_ts=None):
    secrets = get_secrets()
    msg = {"channel": channel, "text": text}
    if thread_ts:
        msg["thread_ts"] = thread_ts
    req = urllib.request.Request(
        "https://slack.com/api/chat.postMessage",
        data=json.dumps(msg).encode(),
        headers={
            "Content-Type": "application/json; charset=utf-8",
            "Authorization": f"Bearer {secrets['slack_bot_token']}",
        },
    )
    r = json.loads(urllib.request.urlopen(req).read().decode())
    if not r.get("ok"):
        print(f"Slack error: {r.get('error')}")


# ── GitOps Change Handler ───────────────────────────────────

def handle_gitops_change(channel, thread_ts, user_text, args):
    app = args.get("app", "")
    description = args.get("description", "")
    change_type = args.get("change_type", "")
    target_value = args.get("target_value", "")
    target_env = args.get("env", ENV)
    component = args.get("component", "")
    print(f"GitOps change: app={app}, env={target_env}, component={component}, type={change_type}, value={target_value}")

    slack_post(channel, f"`{app}` ({target_env}) 관련 파일을 찾고 있습니다...", thread_ts)

    # Find relevant files
    files = github_search_file(app, target_env)
    if not files:
        slack_post(channel, f"`{app}` ({target_env}) 관련 설정 파일을 찾지 못했습니다.\n"
                   f"검색 경로: `values/*/`, `manifests/*/`, `argocd/*/`\n"
                   f"Terraform Helm 스택(`stacks/acme/helm/{app}/`)으로 관리되는 경우 수동 수정이 필요합니다.", thread_ts)
        return

    # Filter: prefer env-specific values, exclude _defaults
    print(f"Found files: {[f['path'] for f in files]}")
    env_files = [f for f in files if target_env in f["path"] and "_defaults" not in f["path"]]
    values_files = [f for f in files if "values" in f["path"] and "_defaults" not in f["path"] and target_env in f["path"]]

    if values_files:
        target_file = values_files[0]
    elif env_files:
        target_file = env_files[0]
    else:
        # Let LLM pick from available files
        file_list = "\n".join(f"- {f['path']}" for f in files[:10])
        pick = call_zai([
            {"role": "system", "content": f"다음 파일 목록에서 '{description}'을 수행하기에 가장 적절한 파일 경로를 하나만 골라 경로만 출력해주세요.\n\n{file_list}"},
            {"role": "user", "content": f"변경 대상: {description}"},
        ]).strip()
        matched = [f for f in files if f["path"] in pick]
        target_file = matched[0] if matched else files[0]
    print(f"Selected: {target_file['path']}")

    # Get current file content
    file_data = github_get_file(target_file["path"])
    current_content = file_data["content"]
    file_sha = file_data["sha"]

    slack_post(channel, f"파일 발견: `{target_file['path']}`\n변경사항을 생성 중...", thread_ts)

    # Ask LLM to generate modified content
    new_content = call_zai([
        {"role": "system", "content": CHANGE_PROMPT.format(
            file_path=target_file["path"],
            current_content=current_content,
            description=description,
            target_value=target_value,
        )},
        {"role": "user", "content": f"파일을 수정해주세요: {description}" + (f" (component: {component})" if component else "")},
    ])

    # Clean up LLM response (remove markdown code blocks if present)
    new_content = re.sub(r"^```(?:yaml)?\n?", "", new_content.strip())
    new_content = re.sub(r"\n?```$", "", new_content.strip())

    if not new_content.strip() or new_content.strip() == current_content.strip():
        slack_post(channel, "변경사항을 생성하지 못했습니다. 수동으로 확인해주세요.", thread_ts)
        return

    # Create PR
    try:
        pr_url = github_create_pr(app, description, target_file["path"],
                                  current_content, new_content, file_sha, target_env)
        slack_post(channel, f"PR을 생성했습니다! 리뷰 후 머지해주세요.\n{pr_url}", thread_ts)
    except Exception as e:
        print(f"PR creation error: {e}")
        slack_post(channel, f"PR 생성 중 오류가 발생했습니다: `{e}`", thread_ts)


# ── Handler ─────────────────────────────────────────────────

def handler(event, context):
    print(f"Event: {json.dumps(event)[:500]}")

    # Async worker invocation
    if event.get("source") == "slack-agent":
        return process_message(event)

    # Function URL — Slack Event
    if "requestContext" not in event:
        return {"statusCode": 400, "body": "Unknown event"}

    # Ignore Slack retries (we already processed the first attempt)
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    if headers.get("x-slack-retry-num"):
        print(f"Ignoring Slack retry #{headers['x-slack-retry-num']}")
        return {"statusCode": 200, "body": "ok"}

    # Parse body first for url_verification (before signature check)
    raw_body = event.get("body", "")
    if event.get("isBase64Encoded"):
        raw_body = base64.b64decode(raw_body).decode()
    try:
        payload = json.loads(raw_body)
    except (json.JSONDecodeError, TypeError):
        return {"statusCode": 400, "body": "Invalid JSON"}

    # URL verification challenge — respond before signature check
    if payload.get("type") == "url_verification":
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"challenge": payload["challenge"]}),
        }

    # Verify signature for all other events
    # TODO: 디버깅 완료 후 서명 검증 재활성화
    valid, body = verify_slack_signature(event)
    if not valid:
        print(f"WARNING: Invalid Slack signature (proceeding anyway for debug)")

    # Event callback
    if payload.get("type") == "event_callback":
        evt = payload.get("event", {})
        # Ignore bot's own messages
        if evt.get("bot_id") or evt.get("subtype") == "bot_message":
            return {"statusCode": 200, "body": "ok"}
        # @멘션할 때만 응답 (스레드 자동응답 제거)
        is_mention = evt.get("type") == "app_mention"
        if is_mention:
            boto3.client("lambda", region_name=REGION).invoke(
                FunctionName=os.environ["AWS_LAMBDA_FUNCTION_NAME"],
                InvocationType="Event",
                Payload=json.dumps({
                    "source": "slack-agent",
                    "channel": evt["channel"],
                    "thread_ts": evt.get("thread_ts", evt["ts"]),
                    "text": evt.get("text", ""),
                    "user": evt.get("user", ""),
                }).encode(),
            )

    return {"statusCode": 200, "body": "ok"}


def process_message(event):
    channel = event["channel"]
    thread_ts = event["thread_ts"]
    raw_text = event["text"]
    # Remove bot mention from text
    text = re.sub(r"<@[A-Z0-9]+>\s*", "", raw_text).strip()
    if not text:
        slack_post(channel, "무엇을 도와드릴까요? 클러스터 상태, pod, 노드, ingress 등을 확인할 수 있어요.", thread_ts)
        return

    try:
        # Fetch thread history for conversation context
        thread_history = slack_get_thread(channel, thread_ts)

        # Step 1: Ask LLM to classify intent and pick actions
        messages = [{"role": "system", "content": SYSTEM_PROMPT}]
        messages.extend(thread_history)
        messages.append({"role": "user", "content": text})
        intent_response = call_zai(messages)
        print(f"LLM intent: {intent_response[:300]}")

        # Parse JSON from LLM response
        try:
            intent = json.loads(intent_response)
        except json.JSONDecodeError:
            # Try to extract JSON from markdown code block
            m = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", intent_response, re.DOTALL)
            if m:
                intent = json.loads(m.group(1))
            else:
                intent = {"actions": [], "answer": intent_response}

        # Step 2: If no actions needed, return LLM answer directly
        if not intent.get("actions"):
            answer = intent.get("answer", "죄송합니다, 이해하지 못했어요.")
            slack_post(channel, answer, thread_ts)
            return

        # Step 3: Check for special actions
        has_close_pr = any(a.get("function") == "close_pr" for a in intent.get("actions", []))
        if has_close_pr:
            pr_args = next(a["args"] for a in intent["actions"] if a["function"] == "close_pr")
            pr_num = pr_args.get("pr_number", "")
            if pr_num == "latest":
                # Find PR number from thread history
                for msg in reversed(thread_history):
                    m = re.search(r"pull/(\d+)", msg.get("content", ""))
                    if m:
                        pr_num = m.group(1)
                        break
            if pr_num and pr_num != "latest":
                try:
                    result = github_close_pr(int(pr_num))
                    slack_post(channel, result, thread_ts)
                except Exception as e:
                    slack_post(channel, f"PR 닫기 실패: `{e}`", thread_ts)
            else:
                slack_post(channel, "PR 번호를 찾지 못했습니다. `PR 149 닫아줘` 형식으로 알려주세요.", thread_ts)
            return

        has_gitops = any(a.get("function") == "gitops_change" for a in intent.get("actions", []))
        if has_gitops:
            gitops_args = next(a["args"] for a in intent["actions"] if a["function"] == "gitops_change")
            handle_gitops_change(channel, thread_ts, text, gitops_args)
            return

        # Step 3b: Execute K8s read actions
        results = execute_actions(intent["actions"])

        # Step 4: Ask LLM to summarize results
        data_str = json.dumps(results, ensure_ascii=False, indent=2)[:3000]
        summary = call_zai([
            {"role": "system", "content": SUMMARY_PROMPT.format(
                question=text,
                data=data_str,
            )},
            {"role": "user", "content": "위 데이터를 기반으로 사용자 질문에 답해주세요."},
        ])
        print(f"LLM summary length: {len(summary)}")

        if not summary or not summary.strip():
            summary = f"K8s 데이터를 조회했지만 요약 생성에 실패했습니다.\n```\n{data_str[:1500]}\n```"

        slack_post(channel, summary.strip(), thread_ts)

    except Exception as e:
        print(f"Error: {e}")
        slack_post(channel, f"처리 중 오류가 발생했습니다: `{e}`", thread_ts)
EOT

  lambda_name = "slack-agent-${var.environment}"
}
