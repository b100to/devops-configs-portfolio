# aws-vault 설정 가이드

> **⚠️ DEPRECATED**: 현재 인증 표준은 OIDC 기반(`aws-cli-oidc.md`)으로 통일되었습니다. 이 문서는 과거 이력 보존용으로만 남겨둡니다.

AWS 자격증명을 macOS Keychain에 안전하게 저장하고, 임시 자격증명으로 작업하는 도구.

## 설치

```bash
brew install aws-vault
```

## 프로필 등록

```bash
aws-vault add dev
aws-vault add prd
aws-vault add orbit-dev
aws-vault add orbit-prd
```

키체인 패스워드 설정 → 1Password에 저장 (항목명: aws-vault keychain)

## ~/.aws/config

```ini
[profile dev]
region = ap-northeast-2
output = json

[profile prd]
region = ap-northeast-2
output = json

[profile orbit-dev]
region = ap-northeast-2
output = json

[profile orbit-prd]
region = ap-northeast-2
output = json
```

`credential_process` 불필요. aws-vault가 환경변수로 자격증명 주입.

## Alias (~/.zshrc)

```bash
# aws-vault 단축키
alias av="aws-vault"             # av list, av remove 등
alias avl="aws-vault login"      # 콘솔 로그인: avl dev
# 서브쉘 진입 (자주 씀)
alias avd="aws-vault exec dev"
alias avp="aws-vault exec prd"
alias avdd="aws-vault exec orbit-dev"
alias avdp="aws-vault exec orbit-prd"
# 단일 명령 (r=run)
alias avrd="aws-vault exec dev --"
alias avrp="aws-vault exec prd --"
alias avrdd="aws-vault exec orbit-dev --"
alias avrdp="aws-vault exec orbit-prd --"
```

## 사용법

### 서브쉘 진입 (권장)

```bash
avd          # dev 환경 진입
avp          # prd 환경 진입
exit         # 서브쉘 종료
```

서브쉘 안에서는 kubectl, k9s, terraform 등 모든 AWS 명령이 팝업 없이 작동.

### 단일 명령 실행

```bash
avrd kubectl get pods
avrp make plan prd:eks
```

### 콘솔 로그인

```bash
avl dev      # 브라우저에서 AWS 콘솔 열림
avl prd
```

### 프로필 관리

```bash
av list              # 등록된 프로필 목록
av remove dev        # 프로필 삭제
av rotate dev        # 키 로테이션
```

## 키체인 설정

Keychain Access 앱에서 "aws-vault" 키체인:
- **Change Settings for Keychain** → Lock after 시간 늘리기 또는 체크 해제
- 하루 1회 정도만 패스워드 입력하면 됨

## 주의사항

- 서브쉘 안에서 다른 프로필 전환 불가 → `exit` 후 다시 진입
- 키 잘못 입력 시: `av remove <profile>` → `av add <profile>`

## 이전 방식 (1Password CLI) 제거

```bash
# ~/.aws/credentials 삭제
rm ~/.aws/credentials*

# ~/.aws/config에서 credential_process 라인 삭제
```
