// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

provider "aws" {
  alias   = "virginia"
  profile = "dev"
  region  = "us-east-1"
}
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}
provider "helm" {
  repository_cache       = "${path.module}/.helm"
  repository_config_path = "${path.module}/.helm/repositories.yaml"
  registry {
    password = data.aws_ecrpublic_authorization_token.token.password
    url      = "oci://public.ecr.aws"
    username = data.aws_ecrpublic_authorization_token.token.user_name
  }
  kubernetes {
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
    host                   = var.cluster_endpoint
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        var.cluster_name,
        "--profile",
        "dev",
      ]
      command = "aws"
    }
  }
}
provider "kubernetes" {
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  host                   = var.cluster_endpoint
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      var.cluster_name,
      "--profile",
      "dev",
    ]
    command = "aws"
  }
}
provider "kubectl" {
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  host                   = var.cluster_endpoint
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      var.cluster_name,
      "--profile",
      "dev",
    ]
    command = "aws"
  }
}
