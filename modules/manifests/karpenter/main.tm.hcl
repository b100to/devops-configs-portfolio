generate_hcl "_terramate_generated_karpenter_manifests.tf" {
  content {
    locals {
      cluster_name    = var.cluster_name
      cluster_version = var.cluster_version
      ami_family      = "AL2023"
      instance_type   = tm_try(global.instance_type, "")
      instance_types  = tm_try(global.instance_types, [])
      memory_limit    = "64Gi"
    }

    # 공유 NodeClass (base, base-b 모두 참조)
    resource "kubernetes_manifest" "node_class" {
      manifest = yamldecode(templatefile("${path.module}/nodeclass.yaml.tmpl", {
        name             = "base"
        ami_family       = local.ami_family
        karpenter_role   = var.node_iam_role_arn
        subnet_discovery = "true"
        sg_discovery     = local.cluster_name
        name_tag         = "${local.cluster_name}-base"
        environment      = global.environment
        k8s_version      = local.cluster_version

        ignore_fields = ["metadata.resourceVersion"]
      }))
      field_manager {
        force_conflicts = true
      }
    }

    # EC2NodeClass finalizer 제거를 위한 null_resource
    resource "null_resource" "remove_nodeclass_finalizer" {
      triggers = {
        nodeclass_name = "base"
      }

      provisioner "local-exec" {
        when    = destroy
        command = "kubectl patch ec2nodeclass base --type=json -p='[{\"op\": \"remove\", \"path\": \"/metadata/finalizers\"}]' || true"
      }
    }

    # base NodePool: ap-northeast-2a, expireAfter 360h (15일) - 기존 이름 유지 (노드 drain 방지)
    resource "kubernetes_manifest" "node_pool_a" {
      manifest = yamldecode(templatefile("${path.module}/nodepool.yaml.tmpl", {
        name              = "base"
        node_group        = "base"
        instance_type     = local.instance_type
        instance_types    = local.instance_types
        cpu_limit         = global.cpu_limit
        memory_limit      = local.memory_limit
        expire_after      = "720h"
        availability_zone = "ap-northeast-2a"
        discovery_tag     = local.cluster_name
        environment       = global.environment
        apply_only        = true
        validate_schema   = false
        force_conflicts   = true
        server_side_apply = true
      }))

      depends_on = [
        kubernetes_manifest.node_class
      ]
      field_manager {
        force_conflicts = true
      }
    }

    # base-b NodePool은 prd 스택의 nodepool_b.tf 에서 별도 관리 (dev는 불필요)
  }
}