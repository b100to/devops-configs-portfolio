# Helm Provider Docker Credential Error

## 문제 증상

Terraform plan/apply 실행 시 다음과 같은 에러 발생:

```
Error: could not login to OCI registry "public.ecr.aws": error storing credentials - err: exec: "docker-credential-osxkeychain": executable file not found in $PATH, out: ``

  with provider["registry.terraform.io/hashicorp/helm"],
  on _terramate_generated_k8s_provider_config.tf line 10, in provider "helm":
  10: provider "helm" {
```

## 원인

Helm provider가 OCI registry (public.ecr.aws)에 접근하려고 할 때 Docker credential helper를 찾지 못해 발생하는 문제입니다.

Docker Desktop은 설치되어 있지만, credential helper 바이너리들이 시스템 PATH에 없는 상태입니다:
- `docker-credential-osxkeychain`
- `docker-credential-desktop`
- `docker-credential-ecr-login`

이들은 `/Applications/Docker.app/Contents/Resources/bin/` 경로에 존재하지만 PATH에 포함되어 있지 않습니다.

## 영향 범위

다음 스택에서 Helm provider를 사용하는 경우 발생:
- `stacks/acme/add_ons/main/dev`
- `stacks/acme/add_ons/main/prd`
- Helm chart를 OCI registry에서 가져오는 모든 스택

## 해결 방법

### 방법 1: PATH에 Docker 바이너리 경로 추가 (권장)

#### 임시 해결 (현재 터미널 세션만)
```bash
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
```

#### 영구 해결

**zsh 사용자 (macOS 기본)**
```bash
echo 'export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**bash 사용자**
```bash
echo 'export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
```

### 방법 2: 심볼릭 링크 생성

```bash
sudo ln -sf /Applications/Docker.app/Contents/Resources/bin/docker-credential-osxkeychain /usr/local/bin/
sudo ln -sf /Applications/Docker.app/Contents/Resources/bin/docker-credential-desktop /usr/local/bin/
sudo ln -sf /Applications/Docker.app/Contents/Resources/bin/docker-credential-ecr-login /usr/local/bin/
```

## 확인 방법

해결 후 다음 명령어로 확인:

```bash
# credential helper가 PATH에 있는지 확인
which docker-credential-osxkeychain

# 정상 출력 예시
/Applications/Docker.app/Contents/Resources/bin/docker-credential-osxkeychain
```

## 관련 파일

- [_terramate_generated_k8s_provider_config.tf](../../../stacks/acme/add_ons/main/dev/_terramate_generated_k8s_provider_config.tf)
- [_terramate_generated_providers.tf](../../../stacks/acme/add_ons/main/dev/_terramate_generated_providers.tf)

## 참고사항

### Docker Desktop 확인

Docker Desktop이 설치되어 있는지 확인:
```bash
ls -la /Applications/Docker.app/Contents/Resources/bin/ | grep credential
```

정상 출력:
```
docker-credential-desktop
docker-credential-ecr-login
docker-credential-osxkeychain
```

### Helm Provider 설정

현재 Helm provider는 다음과 같이 OCI registry 인증을 설정하고 있습니다:

```hcl
provider "helm" {
  registry {
    password = data.aws_ecrpublic_authorization_token.token.password
    url      = "oci://public.ecr.aws"
    username = data.aws_ecrpublic_authorization_token.token.user_name
  }
  # ...
}
```

이 설정은 AWS ECR Public에서 Helm chart를 가져올 때 필요합니다.

## 추가 경고

함께 발생할 수 있는 경고:

```
Warning: Deprecated attribute

  on .terraform/modules/addons/main.tf line 21, in locals:
  21:   region     = data.aws_region.current.name

The attribute "name" is deprecated. Refer to the provider documentation for details.
```

이 경고는 별도로 처리가 필요할 수 있습니다. `data.aws_region.current.id` 사용을 권장합니다.

## 관련 이슈

- GitHub Issue: [링크]
- Terraform Helm Provider: https://registry.terraform.io/providers/hashicorp/helm/latest/docs
- Docker Credential Helpers: https://docs.docker.com/engine/reference/commandline/login/#credential-helpers
