# Pod Topology Spread (노드 분산) 가이드

> prd 노드가 한쪽으로 쏠려 메모리 포화로 다운된 사고(2026-06-02)를 계기로 정리.
> 동일 deployment의 replica가 한 노드에 몰리지 않게 강제하는 방법과, 그 과정에서 만난 함정들.

---

## TL;DR

- **목표**: 같은 앱의 replica를 노드에 고르게 분산 → 한 노드 죽어도 서비스 유지 + 한 노드 메모리 포화 방지
- **핵심 설정 3종 세트** (이거 다 있어야 prd에서 제대로 동작):
  1. `whenUnsatisfiable: DoNotSchedule` — 분산 강제 (soft 아님)
  2. `nodeTaintsPolicy: Honor` — taint 노드를 분산 계산에서 제외 (**3-replica 앱 필수**)
  3. `matchLabelKeys: [pod-template-hash]` — 롤아웃 데드락 방지

---

## 배경: 2026-06-02 사고

- `79-110`(base-b, AZ 2c) 노드가 메모리 94% 포화 상태에서 다운.
- 원인: JVM 앱들의 replica가 그 노드 한쪽에 쏠려 있었음.
- 왜 쏠렸나: spread 제약이 **없거나(`stockroom`)** **soft(`ScheduleAnyway`)** 라서, 노드 재기동 시 한쪽으로 몰려도 그대로 허용 → descheduler 없어 고착.

---

## 1. `whenUnsatisfiable` — soft vs hard

| 값 | 의미 | 결과 |
|----|------|------|
| `ScheduleAnyway` (soft) | "되도록 분산. 안 되면 그냥 올려" | 압박받으면 무시 → **쏠림** |
| `DoNotSchedule` (hard) | "분산 안 되면 차라리 Pending으로 대기" | 강제 → 쏠림 차단 |

> `maxSkew: 1`이 있어도 `ScheduleAnyway`면 **권고일 뿐 강제력 없음.** 한 노드에 다 들어갈 수 있다.

---

## 2. `nodeTaintsPolicy: Honor` — 가장 중요한 함정 ⚠️

### 무엇인가
> **분산 개수를 셀 때, pod이 갈 수 없는 taint 노드는 제외하라.**

### 왜 필요한가 (Ignore 기본값의 함정)

topology spread는 "노드(domain)별로 pod 몇 개?"를 센다. 근데 **어떤 노드를 셀지**가 문제.

prd 노드:
```
worker:  27-224, 79-110        ← 앱이 갈 수 있음
기타:    airflow, batch, fargate ← taint 걸림 (앱 못 감)
```

**`nodeTaintsPolicy: Ignore`(기본값)** = taint 노드도 분산 도메인으로 카운트:
```
27-224: 1   79-110: 1
airflow: 0  batch: 0  fargate: 0   ← 유령 도메인 (갈 수도 없는데 0개로 카운트)
```

3-replica 앱의 3번째 pod을 worker에 올리면:
```
27-224: 2  vs  airflow: 0  →  skew 2 > maxSkew 1  →  DoNotSchedule 차단 → Pending
```

→ **갈 수도 없는 빈 노드 때문에 skew가 뻥튀기**되어 막힌다.

### 해결

`nodeTaintsPolicy: Honor` → tolerate 못 하는 taint 노드를 계산에서 제외:
```
worker 2개만 카운트 → 27-224: 2  vs  79-110: 1  →  skew 1 ≤ 1  →  정상 배치 ✅
```

### 왜 2-replica는 괜찮고 3-replica만 터지나

| replica | 분포 | 유령 도메인(0) 있어도 |
|---------|------|----------------------|
| 2 | 1:1 | skew 1 → OK (우연히 안전) |
| 3+ | 2:1 | 한 노드가 2 되는 순간 유령(0)과 skew 2 → **막힘** |

→ **3-replica 이상 앱(traefik, mall-v3-api, play-api)에는 `Honor` 필수.** 2-replica도 안전을 위해 넣는 걸 권장.

> 실제 사례: traefik(3 replica)에 `Honor` 없이 배포 → 3번째 pod `FailedScheduling: didn't match pod topology spread constraints` 로 Pending. `Honor` 추가 후 즉시 정상 (PR #253).

---

## 3. `matchLabelKeys: [pod-template-hash]` — 롤아웃 데드락 방지

`DoNotSchedule`만 쓰고 이게 없으면 **롤링 업데이트가 멈춘다.**

- 롤아웃 중엔 구버전 pod + 신버전 pod가 **같이** 카운트됨
- 구버전이 이미 노드를 차지 → 신버전이 들어갈 자리가 maxSkew 위반 → **신버전 Pending → 배포 멈춤**

`matchLabelKeys: [pod-template-hash]` → **리비전(pod-template-hash)별로 따로** 계산 → 구/신 안 섞임 → 롤아웃 정상.

- k8s 1.27+ 기능 (현재 prd 1.35라 사용 가능)
- 스케줄러가 자동으로 `pod-template-hash In [<현재 hash>]` 조건을 labelSelector에 추가해줌

---

## Goal 템플릿 (복붙용)

```yaml
topologySpreadConstraints:
  # zone: AZ 분산은 best-effort (soft). 현재 AZ당 노드 1대라 hostname hard가 zone도 보장
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    nodeTaintsPolicy: Honor
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: <앱 pod 라벨>   # 실제 pod 라벨 확인 필수
    matchLabelKeys:
      - pod-template-hash
  # hostname: 동일 노드 중복 배치 금지 (hard)
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    nodeTaintsPolicy: Honor
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: <앱 pod 라벨>
    matchLabelKeys:
      - pod-template-hash
```

> ⚠️ `labelSelector`가 실제 pod 라벨과 안 맞으면 spread가 **무력화**된다(no-op). `kubectl get pods -l <selector>` 로 매칭 수 확인할 것.

---

## 적용 방식: 공통 차트 vs 앱별 override

`charts/app`(공통 차트)는 helper에서 TSC를 렌더한다.

| 방식 | 특징 | 언제 |
|------|------|------|
| **차트 helper 수정** | 차트 쓰는 **모든 앱이 동시 롤아웃** | batch 불필요할 때 (전부 한 번에 OK) |
| **앱별 명시적 TSC** (`values.yaml`의 `topologySpreadConstraints`) | 그 앱만 롤아웃 → **timing 제어 가능** | batch 필요할 때 (JVM 등) |

- 차트의 `defaultTopologySpread.enabled: true`면 기본 TSC가 들어가는데, **기본값이 `ScheduleAnyway`(soft)** 였음 → hard로 바꾸려면 앱별 명시 또는 차트 수정.
- 앱별 override 시: `defaultTopologySpread.enabled: false` + 명시적 `topologySpreadConstraints` 지정.

---

## Batch 전략 (JVM 주의)

> **JVM 앱은 콜드스타트가 느리고 시작 시 CPU/메모리를 많이 먹는다.** 여러 개를 동시에 롤아웃하면 리소스 폭증 → 노드 압박.

- **non-JVM (homepage·authentik·traefik)**: 한 번에 OK
- **JVM (mall·venue)**: 2~3개씩 나눠서 머지 → 분산·안정화 확인 후 다음 batch
- 차트 일괄 수정은 JVM·non-JVM을 동시에 굴려서 batch가 깨짐 → **앱별 override로 진행**

실제 진행(2026-06-08):
1. non-JVM 3종 (+ traefik Honor hotfix)
2. mall-v3-api, mall-v4-api
3. mall-v4-api-admin, mall-v4-api-seller
4. venue beacon-api, member-api
5. venue play-api, user-api, studio-user-api

각 batch 머지 후 `kubectl get pods -o wide`로 양 노드 분산 확인.

---

## 검증 방법

```bash
# 특정 앱 replica가 양 노드에 나뉘었는지
kubectl --context=acme-prd get pods -n <ns> -l app.kubernetes.io/name=<app> -o wide

# 전체 multi-replica 워크로드 쏠림 스캔 (한 노드에만 있으면 ❌)
kubectl --context=acme-prd get pods -A -o json | <owner별 node 분포 집계>
```

- 2-replica → 1:1, 3-replica → 2:1 이면 정상.
- Pending 발생 시 → `nodeTaintsPolicy: Honor` 또는 `matchLabelKeys` 누락 의심.

---

## 한계 (topology spread로 해결 안 되는 것)

- **zone-pinned StatefulSet** (loki, kafka 등 PV가 특정 AZ에 고정) → 그 AZ 노드에만 갈 수 있음
- **단일 replica 앱, DaemonSet** → 분산 대상 아님
- **EKS managed addon** (coredns, efs-csi-controller) → Terraform addon 값으로 설정. efs-csi는 leader election이라 쏠려도 저위험.
- 이미 쏠린 pod의 **재배치**는 spread만으론 안 됨(예방만) → rollout 또는 descheduler 필요.

---

## 관련

- 사고 대응 PR: #250(kubecost 중단), #252~#257(batch), #253(Honor hotfix)
- 공통 차트: `charts/app/templates/_helpers.tpl` (`app.topologySpreadConstraints`)
- 참고: [Kubernetes Pod Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)
