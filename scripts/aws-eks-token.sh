#!/usr/bin/env bash
# kubeconfig exec용 래퍼: stale AWS 환경 변수를 제거하고 aws eks get-token 실행
# → credential_process (OIDC)가 항상 우선되도록 보장
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
exec aws "$@"
