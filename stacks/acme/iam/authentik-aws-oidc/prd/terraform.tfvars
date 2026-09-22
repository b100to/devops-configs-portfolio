# authentik OIDC Provider for AWS CLI
# Provider URL은 authentik의 OpenID Configuration endpoint (trailing slash 필수)
oidc_provider_url = "https://sso.acme.example/application/o/aws-cli/"

oidc_client_ids = ["aws-cli"]

# sso.acme.example TLS chain root CA(Amazon Root CA 1) SHA-1 thumbprint
# leaf 지문은 인증서 갱신마다 바뀌므로 root CA로 고정 (docs/to-do/eks-maintenance.md 참조)
oidc_thumbprints = ["06b25927c42a721631c1efd9431e648fa62e1e39"]

admin_role_name     = "authentik-oidc-admin"
developer_role_name = "authentik-oidc-developer"

admin_policy_arns = [
  "arn:aws:iam::aws:policy/AdministratorAccess",
]

# prd: ReadOnlyAccess for developers
developer_policy_arns = [
  "arn:aws:iam::aws:policy/ReadOnlyAccess",
]

# Office IP only
allowed_source_ips = ["203.0.113.10/32"]

# 12h
max_session_duration = 43200
