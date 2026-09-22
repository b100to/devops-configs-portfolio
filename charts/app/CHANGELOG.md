# Changelog

All notable changes to the App Helm Chart will be documented in this file.

## [1.3.0] - 2026-07-27

### Added
- 🛡️ PodDisruptionBudget (PDB) 지원 — `templates/pdb.yaml`
  - descheduler, node drain 등 voluntary eviction으로부터 최소 가용 replica 보장
  - 기본값은 `podDisruptionBudget.enabled: false` — 기존 릴리스 렌더링 결과에 영향 없음
  - 서비스별로 `podDisruptionBudget.enabled: true` + `minAvailable` (또는 `maxUnavailable`) 설정으로 opt-in
  - 배경: prd 노드 장애 복구 후 descheduler가 topology spread 위반 pod를 rebalance 목적으로 evict하는데, PDB가 없으면 2-3 replica 서비스의 전체 replica가 동시에 evict될 수 있음. PDB는 Eviction API 차원에서 이를 차단하는 안전장치

## [1.0.0] - 2024-12-10

### Added
- 🎉 통합 애플리케이션 Helm 차트 첫 릴리스
- ✨ Mall v3, Mall v4, Venue를 모두 지원하는 단일 차트
- 🔧 Namespace 자동 생성 기능 (lookup으로 중복 확인)
- 🔐 Service Account 생성 및 IAM Role 연동 지원 (lookup으로 중복 확인)
- 🔑 External Secrets 지원 (AWS Secrets Manager 연동)
- 📊 Datadog APM 자동 통합
- ☁️ AWS 자격 증명 자동 설정
- 🏥 유연한 Health Check 설정 (HTTP, TCP, Exec)
- 📈 HPA (Horizontal Pod Autoscaler) 지원
- 🎯 Topology Spread Constraints 기본 지원
- 📦 Volume 및 VolumeMount 커스터마이징
- 🏷️ 유연한 레이블 및 어노테이션 관리

### Features

#### Core Features
- Deployment with flexible configuration
- Service with multiple service types support
- Horizontal Pod Autoscaling
- Namespace and Service Account management

#### Integrations
- **External Secrets**: AWS Secrets Manager integration, automatic secret synchronization
- **Datadog**: APM, logs injection, distributed tracing
- **AWS**: ECR image registry, IAM roles, credentials management
- **Kubernetes**: Full support for native features

#### Scheduling
- Node Selector
- Node Affinity / Pod Affinity / Pod Anti-Affinity
- Tolerations
- Topology Spread Constraints
- Priority Classes

#### Observability
- Liveness Probe (HTTP, TCP, Exec)
- Readiness Probe (HTTP, TCP, Exec)
- Startup Probe (HTTP, TCP, Exec)

#### Security
- Service Account with annotations
- Pod Security Context
- Container Security Context
- Image Pull Secrets

### Documentation
- 📖 Comprehensive README.md with examples
- 🧪 TESTING.md with validation scripts
- 📝 Complete values.yaml documentation
- 💡 Real-world examples for Mall and Venue

### Examples
- Mall v4 API example
- Venue Beacon API example
- Mall v3 Worker example

## Migration Notes

### From Mall v3 Chart

**Key Changes:**
- `datadog.tags.env` → `global.env`
- `datadog.tags.version` → `datadog.version`
- Helper function names updated to use `app` prefix

### From Mall v4 Chart

**Key Changes:**
- `env` → `global.env`
- Service Account creation is now configurable
- Helper function names updated to use `app` prefix

### From Venue Chart

**Key Changes:**
- `app.name` → `fullnameOverride`
- `app.replicas` → `replicaCount`
- `app.image.repository` → `image.repository`
- `app.probe.path` → `livenessProbe.httpGet.path` and `readinessProbe.httpGet.path`
- `app.probe.port` → `service.port`
- `app.resources` → `resources`
- `app.env` → `env`

## Compatibility

- **Kubernetes**: 1.24+
- **Helm**: 3.0+
- **Container Runtimes**: Docker, containerd, CRI-O

## Known Issues

None at this time.

## Future Plans

### Version 1.1.0 (Planned)
- [ ] ConfigMap 자동 생성 기능
- [ ] Secret 자동 생성 기능
- [ ] Ingress 리소스 지원
- [ ] ServiceMonitor (Prometheus) 지원
- [x] PodDisruptionBudget 지원 (1.3.0에서 조기 구현)

### Version 1.2.0 (Planned)
- [ ] StatefulSet 지원
- [ ] DaemonSet 지원
- [ ] Multiple container 지원
- [ ] Sidecar container 지원

### Version 2.0.0 (Future)
- [ ] Multi-region 배포 지원
- [ ] Blue-Green 배포 지원
- [ ] Canary 배포 지원
- [ ] GitOps 최적화

## Contributing

차트 개선을 위한 기여를 환영합니다!

1. Feature branch 생성
2. 변경사항 구현
3. 테스트 진행
4. Pull Request 생성

## Support

- GitHub Issues: [devops-configs/issues]
- Documentation: [charts/app/README.md]

## Credits

Developed and maintained by AcmeCorp DevOps Team.

## License

Copyright © 2024 AcmeCorp
