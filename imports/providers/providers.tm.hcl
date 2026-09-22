# Unified Providers Configuration
#
# 사용법: 스택의 config.tm.hcl에서 provider_preset 설정
#
# globals {
#   provider_preset = "aws"       # AWS만 (VPC, IAM, PIA)
#   provider_preset = "helm"      # AWS + helm + kubernetes
#   provider_preset = "manifests" # AWS + kubectl + kubernetes
#   provider_preset = "eks"       # AWS + 전체 (EKS 생성)
#
#   enable_k8s_provider_config = true  # 클러스터 연결 설정 (helm, manifests에서 사용)
# }

# =============================================================================
# Preset: aws (기본) - VPC, IAM, PIA 등
# =============================================================================
generate_hcl "_terramate_generated_providers.tf" {
  condition = tm_try(global.provider_preset, "aws") == "aws"

  content {
    terraform {
      required_version = global.terraform_version

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = global.terraform_aws_provider_version
        }
      }
    }

    provider "aws" {
      region  = global.region
      profile = global.environment
    }
  }
}

# =============================================================================
# Preset: helm - Helm chart 설치용
# =============================================================================
generate_hcl "_terramate_generated_providers.tf" {
  condition = tm_try(global.provider_preset, "aws") == "helm"

  content {
    terraform {
      required_version = global.terraform_version

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = global.terraform_aws_provider_version
        }
        helm = {
          source  = "hashicorp/helm"
          version = global.terraform_helm_provider_version
        }
        kubectl = {
          source  = "gavinbunney/kubectl"
          version = global.terraform_kubectl_provider_version
        }
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = global.terraform_k8s_provider_version
        }
      }
    }

    provider "aws" {
      region  = global.region
      profile = global.environment
    }
  }
}

# =============================================================================
# Preset: manifests - kubectl manifests 배포용
# =============================================================================
generate_hcl "_terramate_generated_providers.tf" {
  condition = tm_try(global.provider_preset, "aws") == "manifests"

  content {
    terraform {
      required_version = global.terraform_version

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = global.terraform_aws_provider_version
        }
        kubectl = {
          source  = "gavinbunney/kubectl"
          version = global.terraform_kubectl_provider_version
        }
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = global.terraform_k8s_provider_version
        }
      }
    }

    provider "aws" {
      region  = global.region
      profile = global.environment
    }
  }
}

# =============================================================================
# Preset: eks - EKS 클러스터 생성용 (전체 포함)
# =============================================================================
generate_hcl "_terramate_generated_providers.tf" {
  condition = tm_try(global.provider_preset, "aws") == "eks"

  content {
    terraform {
      required_version = global.terraform_version

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = global.terraform_aws_provider_version
        }
        helm = {
          source  = "hashicorp/helm"
          version = global.terraform_helm_provider_version
        }
        kubectl = {
          source  = "gavinbunney/kubectl"
          version = global.terraform_kubectl_provider_version
        }
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = global.terraform_k8s_provider_version
        }
        tls = {
          source  = "hashicorp/tls"
          version = global.terraform_tls_provider_version
        }
      }
    }

    provider "aws" {
      region  = global.region
      profile = global.environment
    }
  }
}

# =============================================================================
# Preset: datadog - Datadog Monitor/Integration 관리용
# - aws provider로 Secrets Manager에서 DD_API_KEY/DD_APP_KEY 조회
# - datadog provider block은 모듈에서 직접 구성 (main.tm.hcl에서 data source 참조)
# =============================================================================
generate_hcl "_terramate_generated_providers.tf" {
  condition = tm_try(global.provider_preset, "aws") == "datadog"

  content {
    terraform {
      required_version = global.terraform_version

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = global.terraform_aws_provider_version
        }
        datadog = {
          source  = "DataDog/datadog"
          version = global.terraform_datadog_provider_version
        }
      }
    }

    provider "aws" {
      region  = global.region
      profile = global.environment
    }
  }
}

# =============================================================================
# K8s Provider Config (클러스터 연결 설정)
# - helm, manifests preset에서 enable_k8s_provider_config = true 시 사용
# =============================================================================
generate_hcl "_terramate_generated_k8s_provider_config.tf" {
  condition = tm_try(global.enable_k8s_provider_config, false)

  content {
    # ECR Public 인증 (Karpenter 등 public.ecr.aws 차트용)
    provider "aws" {
      region  = "us-east-1"
      alias   = "virginia"
      profile = global.environment
    }

    data "aws_ecrpublic_authorization_token" "token" {
      provider = aws.virginia
    }

    # Helm Provider
    provider "helm" {
      registry {
        url      = "oci://public.ecr.aws"
        username = data.aws_ecrpublic_authorization_token.token.user_name
        password = data.aws_ecrpublic_authorization_token.token.password
      }
      repository_config_path = "${path.module}/.helm/repositories.yaml"
      repository_cache       = "${path.module}/.helm"

      kubernetes {
        host                   = var.cluster_endpoint
        cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

        exec {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--profile", global.environment]
        }
      }
    }

    # Kubernetes Provider
    provider "kubernetes" {
      host                   = var.cluster_endpoint
      cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--profile", global.environment]
      }
    }

    # Kubectl Provider
    provider "kubectl" {
      host                   = var.cluster_endpoint
      cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
      load_config_file       = false

      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--profile", global.environment]
      }
    }
  }
}
