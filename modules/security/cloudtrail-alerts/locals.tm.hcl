generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      bucket_name    = "acme-cloudtrail-${var.environment}"
      sns_topic_name = "acme-cloudtrail-alerts-${var.environment}"
      lambda_name    = "acme-cloudtrail-slack-${var.environment}"

      # EventBridge event patterns by category
      alert_rules = {
        iam-changes = {
          description = "IAM changes (user/role/policy)"
          pattern = jsonencode({
            source      = ["aws.iam"]
            detail-type = ["AWS API Call via CloudTrail"]
            detail = {
              eventSource = ["iam.amazonaws.com"]
              eventName = [
                "CreateUser", "DeleteUser",
                "CreateRole", "DeleteRole",
                "AttachRolePolicy", "DetachRolePolicy",
                "AttachUserPolicy", "DetachUserPolicy",
                "PutUserPolicy", "DeleteUserPolicy",
                "PutRolePolicy", "DeleteRolePolicy",
                "CreateAccessKey", "DeleteAccessKey",
              ]
            }
          })
        }
        network-changes = {
          description = "Security group changes"
          pattern = jsonencode({
            source      = ["aws.ec2"]
            detail-type = ["AWS API Call via CloudTrail"]
            detail = {
              eventSource = ["ec2.amazonaws.com"]
              eventName = [
                "AuthorizeSecurityGroupIngress", "AuthorizeSecurityGroupEgress",
                "RevokeSecurityGroupIngress", "RevokeSecurityGroupEgress",
                "CreateSecurityGroup", "DeleteSecurityGroup",
              ]
            }
          })
        }
        destructive-actions = {
          description = "Destructive actions (instance/DB/bucket deletion)"
          pattern = jsonencode({
            source      = ["aws.ec2", "aws.rds", "aws.s3"]
            detail-type = ["AWS API Call via CloudTrail"]
            detail = {
              eventName = [
                "TerminateInstances",
                "DeleteDBInstance", "DeleteDBCluster",
                "DeleteBucket",
              ]
            }
          })
        }
        root-account-usage = {
          description = "Root account console login"
          pattern = jsonencode({
            source      = ["aws.signin"]
            detail-type = ["AWS Console Sign In via CloudTrail"]
            detail = {
              userIdentity = {
                type = ["Root"]
              }
            }
          })
        }
        cloudtrail-tampering = {
          description = "CloudTrail stop/delete/update"
          pattern = jsonencode({
            source      = ["aws.cloudtrail"]
            detail-type = ["AWS API Call via CloudTrail"]
            detail = {
              eventSource = ["cloudtrail.amazonaws.com"]
              eventName   = ["StopLogging", "DeleteTrail", "UpdateTrail"]
            }
          })
        }
        kms-changes = {
          description = "KMS key changes (create/disable/delete/policy)"
          pattern = jsonencode({
            source      = ["aws.kms"]
            detail-type = ["AWS API Call via CloudTrail"]
            detail = {
              eventSource = ["kms.amazonaws.com"]
              eventName = [
                "CreateKey", "DisableKey", "EnableKey",
                "ScheduleKeyDeletion", "CancelKeyDeletion",
                "PutKeyPolicy", "CreateGrant",
                "DisableKeyRotation", "EnableKeyRotation",
              ]
            }
          })
        }
        s3-policy-changes = {
          description = "S3 bucket policy/ACL changes"
          pattern = jsonencode({
            source      = ["aws.s3"]
            detail-type = ["AWS API Call via CloudTrail"]
            detail = {
              eventSource = ["s3.amazonaws.com"]
              eventName = [
                "PutBucketPolicy", "DeleteBucketPolicy",
                "PutBucketPublicAccessBlock",
                "PutBucketAcl",
              ]
            }
          })
        }
        secrets-manager-changes = {
          description = "Secrets Manager secret changes"
          pattern = jsonencode({
            source      = ["aws.secretsmanager"]
            detail-type = ["AWS API Call via CloudTrail"]
            detail = {
              eventSource = ["secretsmanager.amazonaws.com"]
              eventName = [
                "DeleteSecret", "PutSecretValue",
                "UpdateSecret", "RestoreSecret",
              ]
            }
          })
        }
        eks-changes = {
          description = "EKS cluster/nodegroup changes"
          pattern = jsonencode({
            source      = ["aws.eks"]
            detail-type = ["AWS API Call via CloudTrail"]
            detail = {
              eventSource = ["eks.amazonaws.com"]
              eventName = [
                "DeleteCluster", "UpdateClusterConfig",
                "CreateNodegroup", "DeleteNodegroup",
                "UpdateNodegroupConfig",
              ]
            }
          })
        }
        lambda-changes = {
          description = "Lambda function changes"
          pattern = jsonencode({
            source      = ["aws.lambda"]
            detail-type = ["AWS API Call via CloudTrail"]
            detail = {
              eventSource = ["lambda.amazonaws.com"]
              eventName = [
                "CreateFunction20150331", "DeleteFunction20150331",
                "UpdateFunctionCode20150331v2",
                "UpdateFunctionConfiguration20150331v2",
                "AddPermission20150331v2",
              ]
            }
          })
        }
      }

      # Global services emit EventBridge events only in us-east-1
      global_service_rules = ["iam-changes", "root-account-usage"]
      global_rules         = { for k, v in local.alert_rules : k => v if contains(local.global_service_rules, k) }

      lambda_code = <<-PYTHON
import json
import os
import urllib.request
import ipaddress

BOT_TOKEN = os.environ["SLACK_BOT_TOKEN"]
CHANNEL = os.environ["SLACK_CHANNEL"]
ENVIRONMENT = os.environ.get("ENVIRONMENT", "unknown")
ALLOWED_IPS = [ipaddress.ip_network(cidr) for cidr in json.loads(os.environ.get("ALLOWED_IPS", "[]"))]

CATEGORY_LABELS = {
    "iam.amazonaws.com": "IAM",
    "ec2.amazonaws.com": "Network",
    "rds.amazonaws.com": "RDS",
    "s3.amazonaws.com": "S3",
    "cloudtrail.amazonaws.com": "CloudTrail",
    "signin.amazonaws.com": "Sign-In",
    "kms.amazonaws.com": "KMS",
    "secretsmanager.amazonaws.com": "Secrets Manager",
    "eks.amazonaws.com": "EKS",
    "lambda.amazonaws.com": "Lambda",
}

# Automated roles to skip (prefix match on assumed-role name)
IGNORED_ROLE_PREFIXES = [
    "KarpenterController",
    "acme-main-v2-dev-cluster",
    "acme-main-v2-prd-cluster",
    "eks-pod-identity-aws-load-balancer-controller",
    "GitHubActions",
]


def handler(event, context):
    for record in event.get("Records", []):
        message = json.loads(record["Sns"]["Message"])
        detail = message.get("detail", {})

        # Skip AWS internal service calls (e.g., KMS CreateGrant from ec2/rds)
        source_ip = detail.get("sourceIPAddress", "")
        if source_ip.endswith(".amazonaws.com"):
            continue

        # Skip automated role calls
        identity = detail.get("userIdentity", {})
        arn = identity.get("arn", "")
        role_part = arn.split("assumed-role/")[-1].split("/")[0] if "assumed-role/" in arn else ""
        if any(role_part.startswith(prefix) for prefix in IGNORED_ROLE_PREFIXES):
            continue

        # Skip clone DB deletion (routine maintenance — e.g. acmemall-prod-db-clone-YYYY-MM-DD)
        # 인스턴스/클러스터 clone 모두 커버 (airflow-green-v2가 매일 생성·삭제)
        event_name_early = detail.get("eventName", "")
        if event_name_early in ("DeleteDBInstance", "DeleteDBCluster"):
            req_params = detail.get("requestParameters") or {}
            db_id = req_params.get("dBInstanceIdentifier") or req_params.get("dBClusterIdentifier") or ""
            if "clone" in db_id:
                continue

        event_source = detail.get("eventSource", "")
        event_name = detail.get("eventName", "unknown")
        category = CATEGORY_LABELS.get(event_source, event_source)

        principal = identity.get("arn", identity.get("userName", identity.get("type", "unknown")))

        source_ip = detail.get("sourceIPAddress", "unknown")
        event_time = detail.get("eventTime", "unknown")
        aws_region = detail.get("awsRegion", "unknown")

        # Check if source IP is from an unknown/external location
        is_unknown_ip = False
        if ALLOWED_IPS and source_ip != "unknown":
            try:
                addr = ipaddress.ip_address(source_ip)
                is_unknown_ip = not any(addr in net for net in ALLOWED_IPS)
            except ValueError:
                # AWS internal calls use service names (e.g., "ecs.amazonaws.com")
                is_unknown_ip = not source_ip.endswith(".amazonaws.com")

        error_code = detail.get("errorCode")
        error_msg = detail.get("errorMessage")

        resources = detail.get("resources", [])
        resource_str = ", ".join(r.get("ARN", r.get("accountId", "")) for r in resources) if resources else "N/A"

        params = detail.get("requestParameters")
        params_str = json.dumps(params, ensure_ascii=False)[:200] if params else "N/A"

        color = "#dc3545"
        status = "SUCCESS"
        if error_code:
            color = "#ffc107"
            status = f"FAILED ({error_code})"

        ip_warning = ""
        if is_unknown_ip:
            color = "#7b2d8b"
            ip_warning = " [UNKNOWN IP]"

        slack_message = {
            "channel": CHANNEL,
            "attachments": [
                {
                    "color": color,
                    "blocks": [
                        {
                            "type": "header",
                            "text": {"type": "plain_text", "text": f"[{ENVIRONMENT.upper()}] {category} - {event_name}{ip_warning}"},
                        },
                        {
                            "type": "section",
                            "fields": [
                                {"type": "mrkdwn", "text": f"*Actor:*\n{principal}"},
                                {"type": "mrkdwn", "text": f"*Status:*\n{status}"},
                                {"type": "mrkdwn", "text": f"*Source IP:*\n{source_ip}"},
                                {"type": "mrkdwn", "text": f"*Region:*\n{aws_region}"},
                                {"type": "mrkdwn", "text": f"*Time:*\n{event_time}"},
                                {"type": "mrkdwn", "text": f"*Resource:*\n{resource_str}"},
                            ],
                        },
                        {
                            "type": "section",
                            "text": {"type": "mrkdwn", "text": f"*Parameters:*\n```{params_str}```"},
                        },
                    ],
                }
            ]
        }

        if error_msg:
            slack_message["attachments"][0]["blocks"].append(
                {"type": "section", "text": {"type": "mrkdwn", "text": f"*Error:*\n{error_msg}"}}
            )

        req = urllib.request.Request(
            "https://slack.com/api/chat.postMessage",
            data=json.dumps(slack_message).encode("utf-8"),
            headers={
                "Content-Type": "application/json; charset=utf-8",
                "Authorization": f"Bearer {BOT_TOKEN}",
            },
        )
        resp = urllib.request.urlopen(req)
        result = json.loads(resp.read().decode("utf-8"))
        if not result.get("ok"):
            raise Exception(f"Slack API error: {result.get('error')}")
      PYTHON
    }
  }
}
