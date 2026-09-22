# GitHub Copilot Instructions for DevOps Configurations

## Purpose
This file provides context and instructions to GitHub Copilot when assisting with this repository.

## Quick Reference

### Repository Type
- **Type**: DevOps GitOps repository
- **Main Tools**: ArgoCD, Terraform, Terramate, Kubernetes, Helm
- **Deployment Method**: GitOps (ArgoCD auto-sync)

### Critical Rules
1. ❌ **Never use** `kubectl apply/create/patch` - This repo uses GitOps
2. ❌ **Never edit** `_terramate_generated_*.tf` files directly
3. ✅ **Always** commit to Git and let ArgoCD deploy
4. ✅ **Always** use Terramate for Terraform code generation

## Directory Structure

```
argocd/          # ArgoCD Applications (App of Apps pattern)
  ├── dev/          # Dev environment
  │   ├── apps/     # Application definitions
  │   └── infra/    # Infrastructure definitions
  └── prd/          # Production environment
      ├── apps/
      └── infra/

values/          # Helm chart values
  ├── apps/         # Application service values
  └── infra/        # Infrastructure service values

manifests/       # Raw Kubernetes manifests
  ├── vpa/          # VerticalPodAutoscaler configs
  └── traefik/      # Traefik routes

modules/         # Terraform reusable modules
stacks/          # Terramate stacks
```

## Common Tasks

### Adding a New Application
1. Create ArgoCD Application: `argocd/{env}/apps/{app-name}.yaml`
2. Create Helm values: `values/apps/{service}/{env}.yaml`
3. Commit and push - ArgoCD will auto-deploy

### Modifying Terraform Infrastructure
1. Edit `.tm.hcl` files (NOT `_terramate_generated_*.tf`)
2. Run: `terramate generate`
3. Push → CI/CD automatically runs plan + apply

### Updating Helm Values
1. Edit: `values/{apps|infra}/{service}/{env}.yaml`
2. Commit and push - ArgoCD syncs automatically

## Response Guidelines

When helping with this repository:
- Use Korean language (한국어) for responses
- Be concise and actionable
- Reference existing patterns before creating new ones
- Always consider both dev and prd environments
- Validate YAML syntax
- Check for resource limits/requests
- Consider security implications

## Code Style

### YAML Files
- Use 2 spaces for indentation
- Use kebab-case for names
- Always include metadata labels
- Include resource requests and limits

### Terraform/Terramate
- Follow existing module patterns in `modules/`
- Use descriptive variable names
- Add comments for complex logic
- Use locals for repeated values

## ArgoCD App of Apps Pattern

This repo uses the App of Apps pattern:
- `root-app-v2` (created by Terraform) monitors `argocd/{env}/`
- Adding an Application YAML to `apps/` or `infra/` triggers auto-deployment
- No need to re-run Terraform when adding new apps

## Environment Differences

### Dev Environment
- Lower resource limits
- Single replica
- More verbose logging
- Faster sync intervals

### Production Environment
- Higher resource limits
- Multiple replicas (HA)
- Production-grade monitoring
- Careful change management

## Security Considerations
- Never commit secrets - use External Secrets Operator
- Always set NetworkPolicies
- Follow least privilege for RBAC
- Enable Pod Security Standards

## Troubleshooting

### ArgoCD Issues
- Check Application status in ArgoCD UI
- Review sync errors
- Verify values file paths
- Check Helm chart compatibility

### Terraform Issues
- Ensure Terramate generated files are up to date
- Check state file consistency
- Verify provider versions
- Review plan output carefully
