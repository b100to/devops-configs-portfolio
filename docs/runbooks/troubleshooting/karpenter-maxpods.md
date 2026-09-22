# Karpenter maxPods 설정 가이드

## 문제
Karpenter로 프로비저닝된 노드의 Pod 최대 개수가 ENI 기반 기본값(예: 58개)으로 제한됨.

## 해결 방법

### 1. VPC CNI Prefix Delegation 활성화

maxPods를 ENI 제한 이상으로 늘리려면 필수.

```bash
kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true
kubectl set env daemonset aws-node -n kube-system WARM_PREFIX_TARGET=1
```

### 2. EC2NodeClass 설정 (Karpenter v1)

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  kubelet:
    maxPods: 110  # Karpenter 네이티브 설정
  amiFamily: AL2023
  metadataOptions:
    httpPutResponseHopLimit: 2  # Prefix Delegation에 필요
```

### 3. AL2023 userData (선택)

AL2023에서는 nodeadm을 사용하므로 bootstrap.sh 방식은 동작하지 않음.

```yaml
# 잘못된 예 (AL2 방식)
userData: |
  #!/bin/bash
  /etc/eks/bootstrap.sh cluster-name --kubelet-extra-args '--max-pods=110'

# 올바른 예 (AL2023 방식)
userData: |
  ---
  apiVersion: node.eks.aws/v1alpha1
  kind: NodeConfig
  spec:
    kubelet:
      config:
        maxPods: 110
```

## 적용 순서

1. VPC CNI Prefix Delegation 활성화
2. EC2NodeClass에 `spec.kubelet.maxPods` 설정
3. `httpPutResponseHopLimit: 2` 설정
4. Terraform apply
5. 기존 노드 drain하여 새 노드 프로비저닝
6. 확인: `kubectl get nodes -o custom-columns='NAME:.metadata.name,PODS:.status.allocatable.pods'`

## 참고

- `spec.kubelet.maxPods`가 userData보다 우선 적용됨
- Prefix Delegation 없이는 ENI 기반 제한을 넘을 수 없음
