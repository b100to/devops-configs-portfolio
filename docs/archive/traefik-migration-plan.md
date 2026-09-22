# Istio → Traefik 마이그레이션 계획

## 개요

### 목적
- Istio Service Mesh에서 Traefik Ingress Controller로 전환
- 비용 절감 및 관리 복잡도 감소
- 1인 관리 환경에 적합한 간소화된 아키텍처

### 현재 아키텍처
```
Internet → ALB → Istio Ingress Gateway (NodePort) → Istio VirtualService → Backend Services
```

### 목표 아키텍처
```
Internet → ALB (Terraform 관리) → Traefik (NodePort) → Traefik IngressRoute → Backend Services
```

## 마이그레이션 전략

### Phase 0: 준비 단계 (1-2일)

#### 0.1 Terraform ALB 생성
```bash
# Dev 환경에서 먼저 시작 - 코드 수정 후 push → CI/CD 자동 적용
# 로컬에서 plan 확인만 가능
terramate run --tags=dev:alb-traefik --enable-sharing --mock-on-fail -- terraform plan
```

**검증:**
- ALB DNS name 확인
- Target Group에 EKS 노드 자동 등록 확인
- Health check 상태 확인 (처음에는 unhealthy, Traefik 배포 후 healthy로 변경됨)

**Output:**
- ALB DNS: `acme-main-dev-traefik-xxxxxxxxx.ap-northeast-2.elb.amazonaws.com`
- ALB Zone ID: `Z1XXXXXX`

#### 0.2 Route53 테스트 도메인 설정
```bash
# 테스트용 서브도메인 생성 (예: traefik.dev.acme.example)
# ALB DNS를 가리키도록 ALIAS 레코드 생성
```

**검증:**
```bash
dig traefik.dev.acme.example
curl -I https://traefik.dev.acme.example
# 503 응답 정상 (Traefik이 아직 없으므로)
```

---

### Phase 1: Traefik 배포 (1일)

#### 1.1 ArgoCD Application 생성
```bash
# Traefik Helm chart 배포 (GitOps 방식)
# argocd/dev/infra/networking/traefik.yaml 파일을 생성하고 Git에 커밋/푸시합니다.
# ArgoCD가 자동으로 감지하고 배포합니다.

# ArgoCD UI에서 확인
# https://argocd.dev.acme.example
```

**검증:**
```bash
# Traefik pod 확인
kubectl get pods -n traefik

# Service NodePort 확인
kubectl get svc -n traefik
# traefik NodePort: 30080, 30443 확인

# ALB Target Group health check
# AWS Console → EC2 → Target Groups → traefik-tg
# Health status: Healthy 확인
```

#### 1.2 Traefik 헬스 체크 확인
```bash
# Traefik /ping endpoint 확인
kubectl port-forward -n traefik svc/traefik 9000:9000
curl http://localhost:9000/ping
# 응답: OK

# ALB를 통한 health check
curl -I https://traefik.dev.acme.example/ping
# 응답: 200 OK
```

---

### Phase 2: 테스트 서비스 마이그레이션 (1-2일)

#### 2.1 단일 서비스 테스트 (ArgoCD)

**이유:** 가장 안전한 도구 서비스부터 시작

```bash
# Traefik IngressRoute 생성
kubectl apply -f manifests/traefik/dev/routes/tools.yaml

# Route53에 테스트 레코드 추가
# argocd-traefik.dev.acme.example → ALB
```

**검증:**
```bash
# Traefik dashboard에서 라우트 확인 (optional)
kubectl port-forward -n traefik svc/traefik 9000:9000
# http://localhost:9000/dashboard/

# 실제 접속 테스트
curl -I https://argocd-traefik.dev.acme.example
# 200 OK 확인

# 브라우저에서 접속 테스트
open https://argocd-traefik.dev.acme.example
```

**성공 시:**
- Traefik 라우팅 정상 동작 확인
- CORS, SSL 등 모든 기능 정상 확인

#### 2.2 복잡한 서비스 테스트 (Mall V4)

**이유:** Rewrite 기능이 있는 복잡한 라우팅 테스트

```bash
# Middleware 생성
kubectl apply -f manifests/traefik/dev/middlewares/common.yaml

# Mall V4 IngressRoute 생성
kubectl apply -f manifests/traefik/dev/routes/mall-v4.yaml

# 테스트 도메인 추가
# api-v4-traefik.dev.acme.example → ALB
```

**검증:**
```bash
# 각 경로별 테스트
# 1. Seller API (rewrite 테스트)
curl https://api-v4-traefik.dev.acme.example/seller/health
# Backend에는 /health로 전달되어야 함

# 2. Admin API (rewrite 테스트)
curl https://api-v4-traefik.dev.acme.example/admin/health

# 3. Default API
curl https://api-v4-traefik.dev.acme.example/health

# 4. CORS 테스트
curl -I -X OPTIONS https://api-v4-traefik.dev.acme.example/seller/test \
  -H "Origin: https://admin.acme.example" \
  -H "Access-Control-Request-Method: POST"
# CORS headers 확인
```

---

### Phase 3: 전체 서비스 마이그레이션 (2-3일)

#### 3.1 모든 IngressRoute 배포

```bash
# ArgoCD를 통해 전체 배포
kubectl apply -f argocd/dev/infra/networking/traefik-routes.yaml

# 또는 수동으로
kubectl apply -f manifests/traefik/dev/
```

#### 3.2 Route53 레코드 전환 계획

**준비 작업:**
1. 모든 서비스의 테스트 완료
2. 트래픽이 적은 시간대 선정 (새벽 2-4시)
3. 롤백 스크립트 준비

**전환 스크립트 (예시):**
```bash
#!/bin/bash
# route53-cutover.sh

HOSTED_ZONE_ID="Z0XXXXXXXX"
ALB_DNS="acme-main-dev-traefik-xxxxx.ap-northeast-2.elb.amazonaws.com"
ALB_ZONE_ID="Z1XXXXXX"

DOMAINS=(
  "argocd.dev.acme.example"
  "grafana.dev.acme.example"
  "kafka.dev.acme.example"
  "api-v4.dev.acme.example"
  "venue-admin.dev.acme.example"
  # ... 모든 도메인 추가
)

for DOMAIN in "${DOMAINS[@]}"; do
  echo "Updating $DOMAIN to Traefik ALB..."

  # Route53 change batch JSON 생성
  cat > /tmp/change-batch-$DOMAIN.json <<EOF
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "$DOMAIN",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "$ALB_ZONE_ID",
        "DNSName": "$ALB_DNS",
        "EvaluateTargetHealth": true
      }
    }
  }]
}
EOF

  # Route53 레코드 업데이트
  aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file:///tmp/change-batch-$DOMAIN.json

  echo "✓ $DOMAIN updated"
  sleep 2
done

echo "All domains updated successfully!"
```

#### 3.3 점진적 전환 (권장)

**Option 1: Weighted Routing (점진적)**
```json
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "api-v4.dev.acme.example",
      "Type": "A",
      "SetIdentifier": "traefik-alb",
      "Weight": 10,  // 10% 트래픽
      "AliasTarget": {
        "HostedZoneId": "Z1XXXXXX",
        "DNSName": "acme-main-dev-traefik-xxx.elb.amazonaws.com",
        "EvaluateTargetHealth": true
      }
    }
  }]
}
```

**전환 스케줄:**
- Day 1: 10% 트래픽 → Traefik
- Day 2: 50% 트래픽 → Traefik (문제 없으면)
- Day 3: 100% 트래픽 → Traefik

**Option 2: 일괄 전환 (빠른 방식)**
- 모든 도메인을 한 번에 Traefik ALB로 전환
- 새벽 시간대 진행
- 5분 이내 롤백 가능하도록 준비

---

### Phase 4: 모니터링 및 검증 (1주일)

#### 4.1 메트릭 확인
```bash
# Prometheus에서 Traefik 메트릭 확인
# - traefik_service_requests_total
# - traefik_service_request_duration_seconds
# - traefik_entrypoint_requests_total

# Grafana dashboard 구성
# https://grafana.dev.acme.example
```

#### 4.2 로그 모니터링
```bash
# Traefik access logs 확인
kubectl logs -n traefik -l app=traefik --tail=100 -f

# 에러 로그 확인
kubectl logs -n traefik -l app=traefik | grep -i error
```

#### 4.3 성능 비교
- Latency 비교 (Istio vs Traefik)
- CPU/Memory 사용량 비교
- 비용 절감 효과 측정

---

### Phase 5: Istio 제거 (1일)

**전제 조건:**
- 모든 트래픽이 Traefik으로 전환된 후 1주일 이상 안정적으로 운영
- 롤백 계획 폐기 결정

```bash
# 1. Istio VirtualService, Gateway 삭제
kubectl delete -f manifests/istio/dev/

# 2. Istio Ingress Gateway 삭제
kubectl delete -f argocd/dev/infra/networking/istio-ingress.yaml
kubectl delete -f argocd/dev/infra/networking/istio-manifests.yaml

# 3. Istio control plane 삭제
kubectl delete -f argocd/dev/infra/networking/istio.yaml

# 4. 기존 ALB 삭제 (AWS Console 또는 kubectl)
# ingress/default.yaml에서 생성된 ALB 삭제
```

**리소스 절감 예상:**
- Control Plane (istiod): ~200m CPU, ~512Mi memory
- Ingress Gateway: ~50m CPU, ~100Mi memory
- **총 절감: ~250m CPU, ~600Mi memory**

---

## 롤백 계획

### 롤백 시나리오

#### Scenario 1: Traefik 라우팅 문제 발견 (Phase 3 중)

**증상:**
- 특정 서비스 접속 불가
- 500/502 에러 발생
- CORS 에러

**조치:**
```bash
# 1. Route53 레코드를 즉시 Istio ALB로 복구
./rollback-route53.sh <domain>

# 2. Traefik IngressRoute 수정
kubectl edit ingressroute <name> -n <namespace>

# 3. 문제 해결 후 재전환
```

**롤백 스크립트:**
```bash
#!/bin/bash
# rollback-route53.sh

DOMAIN=$1
HOSTED_ZONE_ID="Z0XXXXXXXX"
OLD_ALB_DNS="acme-main-dev-istio-ingress-xxxxx.elb.amazonaws.com"
OLD_ALB_ZONE_ID="Z1XXXXXX"

echo "Rolling back $DOMAIN to Istio ALB..."

cat > /tmp/rollback-$DOMAIN.json <<EOF
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "$DOMAIN",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "$OLD_ALB_ZONE_ID",
        "DNSName": "$OLD_ALB_DNS",
        "EvaluateTargetHealth": true
      }
    }
  }]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file:///tmp/rollback-$DOMAIN.json

echo "✓ $DOMAIN rolled back to Istio"
```

#### Scenario 2: Traefik Pod 장애 (Phase 4 중)

**증상:**
- Traefik pod CrashLoopBackOff
- ALB health check failed

**조치:**
```bash
# 1. 즉시 모든 도메인 Istio로 롤백
./rollback-all-domains.sh

# 2. Traefik 로그 확인
kubectl logs -n traefik -l app=traefik --tail=500

# 3. Traefik Helm values 수정
kubectl edit application traefik -n argocd

# 4. 문제 해결 후 재배포
kubectl rollout restart deployment traefik -n traefik
```

#### Scenario 3: 완전 롤백 (Phase 5 전)

**이유:**
- 예상치 못한 성능 저하
- 비즈니스 크리티컬한 버그 발견
- 경영진 결정

**조치:**
```bash
# 1. 모든 Route53 레코드 복구
./rollback-all-domains.sh

# 2. Traefik 관련 모든 리소스 제거
kubectl delete -f argocd/dev/infra/networking/traefik-routes.yaml
kubectl delete -f argocd/dev/infra/networking/traefik.yaml

# 3. Terraform ALB 삭제
cd stacks/acme/08_alb-traefik/dev
terraform destroy

# 4. Istio는 그대로 유지 (이미 실행 중)
```

---

## 리스크 분석

### 높음 (High)

| 리스크 | 영향 | 완화 방안 |
|--------|------|-----------|
| Route53 전환 중 다운타임 | 서비스 중단 | Weighted routing으로 점진적 전환 |
| Rewrite 로직 불일치 | 기능 오류 | Phase 2에서 철저한 테스트 |
| CORS 설정 누락 | Frontend 에러 | Middleware로 공통 CORS 정책 적용 |

### 중간 (Medium)

| 리스크 | 영향 | 완화 방안 |
|--------|------|-----------|
| 성능 저하 | 사용자 경험 저하 | Phase 4에서 1주일 모니터링 |
| ALB Target Group unhealthy | 간헐적 503 | Health check 파라미터 튜닝 |
| 미지원 기능 발견 | 일부 기능 동작 안 함 | 모든 VirtualService 분석 완료 |

### 낮음 (Low)

| 리스크 | 영향 | 완화 방안 |
|--------|------|-----------|
| Terraform state 충돌 | 인프라 관리 문제 | Remote state 사용, locking 활성화 |
| ArgoCD sync 실패 | 자동 배포 실패 | 수동 배포 대안 준비 |

---

## 체크리스트

### 시작 전 체크리스트

- [ ] 모든 팀원에게 마이그레이션 일정 공지
- [ ] Slack/Discord 알림 채널 준비
- [ ] 모니터링 대시보드 구성
- [ ] 롤백 스크립트 테스트 완료
- [ ] Terraform ALB 배포 완료
- [ ] Production ACM 인증서 ARN 확인

### Phase별 체크리스트

#### Phase 0
- [ ] Terraform ALB 생성 완료
- [ ] Health check 정상
- [ ] 테스트 도메인 설정 완료

#### Phase 1
- [ ] Traefik pod Running
- [ ] NodePort 30080, 30443 확인
- [ ] `/ping` endpoint 응답 정상

#### Phase 2
- [ ] ArgoCD 접속 정상 (테스트 도메인)
- [ ] Mall V4 모든 경로 테스트 통과
- [ ] CORS 정상 동작

#### Phase 3
- [ ] 모든 IngressRoute 배포 완료
- [ ] Route53 전환 스크립트 검증
- [ ] 전환 시간대 결정 및 공지

#### Phase 4
- [ ] 1주일 모니터링 완료
- [ ] 에러 로그 0건
- [ ] 성능 지표 정상

#### Phase 5
- [ ] Istio 리소스 삭제 완료
- [ ] 기존 ALB 삭제 완료
- [ ] 비용 절감 효과 측정

---

## 예상 타임라인

**Development 환경:**
- Week 1: Phase 0-2 (준비 및 테스트 서비스)
- Week 2: Phase 3-4 (전체 전환 및 모니터링)
- Week 3: Phase 5 (Istio 제거)

**Production 환경:**
- Dev 안정화 후 2주 뒤 시작
- 동일한 프로세스 반복
- 더 보수적인 weighted routing 적용 (5% → 25% → 50% → 100%)

---

## 연락처 및 지원

**긴급 상황:**
- On-call: [담당자 연락처]
- Slack: #devops-alerts

**참고 문서:**
- Traefik 공식 문서: https://doc.traefik.io/traefik/
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- ArgoCD 공식 문서: https://argo-cd.readthedocs.io/

---

**작성일:** 2025-12-18
**작성자:** DevOps Team
**버전:** 1.0
