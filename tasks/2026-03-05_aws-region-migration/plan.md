# AWS Region Migration Plan: me-south-1 to eu-central-1

- [Context](#context)
- [Decisions](#decisions)
- [Complete "me-south-1" Reference Inventory](#complete-me-south-1-reference-inventory)
  - [Category 1: Terraform Files](#category-1-terraform-files)
  - [Category 2: CDK env-var JSON Files (~40 files)](#category-2-cdk-env-var-json-files-40-files)
  - [Category 3: aws-lambda-tools-defaults.json (32+ files)](#category-3-aws-lambda-tools-defaultsjson-32-files)
  - [Category 4: Infrastructure C# Code (2 files)](#category-4-infrastructure-c-code-2-files)
  - [Category 5: Test Files (lower priority, ~6 files)](#category-5-test-files-lower-priority-6-files)
  - [Category 6: ConfigMap YAML Files](#category-6-configmap-yaml-files)
  - [Category 7: Mobile Scanner CI/CD (1 file, 3 references)](#category-7-mobile-scanner-cicd-1-file-3-references)
  - [Category 8: Dashboard CSP (1 file)](#category-8-dashboard-csp-1-file)
  - [Category 9: CDK Context Cache Files (DELETE)](#category-9-cdk-context-cache-files-delete)
  - [Category 10: Local Development Settings (lowest priority)](#category-10-local-development-settings-lowest-priority)
  - [Category 11: CI/CD Shared Templates (ticketing-platform-templates-ci-cd)](#category-11-cicd-shared-templates-ticketing-platform-templates-ci-cd)
  - [Category 12: Dashboard .env Files](#category-12-dashboard-env-files)
- [EKS/Kubernetes Deprecation Inventory](#ekskubernetes-deprecation-inventory)
  - [Terraform — Files to Remove (terraform-prod)](#terraform--files-to-remove-terraform-prod)
  - [Terraform — Already Done (terraform-dev)](#terraform--already-done-terraform-dev)
  - [EKS Artifacts Across Monorepo (Archive/Remove)](#eks-artifacts-across-monorepo-archiveremove)
- [Redis/ElastiCache \& OpenSearch Removal Inventory](#rediselasticache--opensearch-removal-inventory)
  - [Redis/ElastiCache](#rediselasticache)
  - [OpenSearch/Elasticsearch](#opensearchelasticsearch)
- [S3 Bucket Naming Strategy](#s3-bucket-naming-strategy)
- [Phase 1: Code Preparation (No Infrastructure Changes)](#phase-1-code-preparation-no-infrastructure-changes)
  - [Tasks](#tasks)
- [Phase 2: Dev+Sandbox Foundation \& Data Restore](#phase-2-devsandbox-foundation--data-restore)
  - [2.1 Service Quota Pre-Checks](#21-service-quota-pre-checks)
  - [2.2 Create Terraform State Bucket](#22-create-terraform-state-bucket)
  - [2.3 Recreate Secrets Manager Entries](#23-recreate-secrets-manager-entries)
  - [2.4 Terraform Apply](#24-terraform-apply)
  - [2.5 Populate Manual SSM Parameters](#25-populate-manual-ssm-parameters)
  - [2.6 Restore Aurora from AWS Backup](#26-restore-aurora-from-aws-backup)
  - [2.7 Restore S3 Data from AWS Backup](#27-restore-s3-data-from-aws-backup)
  - [2.8 CDK Bootstrap](#28-cdk-bootstrap)
  - [Phase 2 Verification Checklist](#phase-2-verification-checklist)
- [Phase 3: Dev+Sandbox Services \& Validation](#phase-3-devsandbox-services--validation)
  - [3.1 Create ACM Certificates](#31-create-acm-certificates)
  - [3.2 Infrastructure CDK (11 Stacks — Strict Order)](#32-infrastructure-cdk-11-stacks--strict-order)
  - [3.3 Update Connection Strings](#33-update-connection-strings)
  - [3.4 Per-Service CDK Deployment Matrix](#34-per-service-cdk-deployment-matrix)
  - [3.5 Update GitHub Secrets \& Variables](#35-update-github-secrets--variables)
  - [3.6 Merge Feature Branches \& Deploy Frontends](#36-merge-feature-branches--deploy-frontends)
  - [3.7 End-to-End Validation](#37-end-to-end-validation)
  - [Phase 3 Verification Checklist](#phase-3-verification-checklist)
- [Phase 4: Production Foundation \& Data Restore](#phase-4-production-foundation--data-restore)
  - [4.1 Service Quota Pre-Checks (Prod)](#41-service-quota-pre-checks-prod)
  - [4.2 State Bucket (Prod)](#42-state-bucket-prod)
  - [4.3 Security Remediation](#43-security-remediation)
  - [4.4 Recreate Prod Secrets](#44-recreate-prod-secrets)
  - [4.5 Terraform Apply (Prod)](#45-terraform-apply-prod)
  - [4.6 Populate Prod SSM Parameters](#46-populate-prod-ssm-parameters)
  - [4.7 Restore Aurora from AWS Backup (Prod)](#47-restore-aurora-from-aws-backup-prod)
  - [4.8 Restore S3 Data (Prod)](#48-restore-s3-data-prod)
  - [4.9 CDK Bootstrap (Prod)](#49-cdk-bootstrap-prod)
- [Phase 5: Production Services \& Go-Live](#phase-5-production-services--go-live)
  - [5.1 Create ACM Certificates (Prod)](#51-create-acm-certificates-prod)
  - [5.2 Deploy All CDK Stacks (Prod)](#52-deploy-all-cdk-stacks-prod)
  - [5.3 Update Connection Strings (Prod)](#53-update-connection-strings-prod)
  - [5.4 Per-Service CDK (Prod)](#54-per-service-cdk-prod)
  - [5.5 Update GitHub Secrets (Prod)](#55-update-github-secrets-prod)
  - [5.6 Merge to Production \& Deploy Frontends](#56-merge-to-production--deploy-frontends)
  - [5.7 End-to-End Validation (Prod)](#57-end-to-end-validation-prod)
  - [5.8 Post-Go-Live Monitoring (72 hours)](#58-post-go-live-monitoring-72-hours)
- [Post-Migration Tasks](#post-migration-tasks)
  - [Extension Lambda Redeployment](#extension-lambda-redeployment)
- [Post-Migration Cleanup](#post-migration-cleanup)
  - [Data Stores (after 7-day stability)](#data-stores-after-7-day-stability)
  - [Infrastructure (once me-south-1 recovers)](#infrastructure-once-me-south-1-recovers)
  - [EKS Deprecation Cleanup](#eks-deprecation-cleanup)
  - [Redis/OpenSearch Cleanup](#redisopensearch-cleanup)
  - [Runner Cleanup](#runner-cleanup)
  - [Configuration](#configuration)
  - [Security](#security)
  - [Documentation](#documentation)
- [Risk Matrix](#risk-matrix)


## Context

The MDLBEAST Ticketing Platform must migrate from AWS me-south-1 (Bahrain) to eu-central-1 (Frankfurt). **The me-south-1 region is currently completely down** due to regional data center failure. This changes the migration from a planned cutover to a **disaster recovery + region migration**.

**Key implications of me-south-1 being down:**
- Aurora Global Database, S3 Cross-Region Replication, and Secrets Manager replication are **impossible** (source region unavailable)
- All data must be restored from **AWS Backup cross-region copies** already stored in eu-central-1
- There is no live traffic to "cut over" — the platform is currently offline
- There is no rollback to me-south-1 — eu-central-1 is the only path forward
- Secrets must be **recreated manually** from backup or documentation

**Supporting research:** `.planning/research/ARCHITECTURE.md`, `PITFALLS.md`, `STACK.md`

**Migration order:** Dev+Sandbox (account `307824719505`) first → validate → Production (account `660748123249`)

**Migration strategy:** Greenfield infrastructure in eu-central-1 (new Terraform state, new CDK stacks), with Aurora restored from AWS Backup cross-region copies. Lambda-only deployment (EKS deprecated).

---

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| EKS/Kubernetes | **Deprecate — Lambda-only** | Services already run as Lambda functions. EKS adds operational complexity with no unique value. |
| Self-hosted runners | **Remove — use GitHub-hosted runners** | Runners only existed for kubectl/EKS deployments. Lambda CDK deploys use `ubuntu-latest`. |
| Redis/ElastiCache | **Remove — do not recreate** | Confirmed zombie infrastructure: zero connections, code uses DynamoDB + in-memory caching instead. |
| OpenSearch/Elasticsearch | **Remove — do not recreate** | Confirmed ghost config: Serilog has no Elasticsearch sink installed. Config references exist but no data flows. |
| Data migration strategy | **Restore from AWS Backup** | me-south-1 is down; live replication impossible. Cross-region backup copies exist in eu-central-1. |
| `demo` environment | **Defer** | Not critical path. Address after dev/sandbox/prod are live. |

---

## Complete "me-south-1" Reference Inventory

### Category 1: Terraform Files

| File | What to Change |
|------|---------------|
| `ticketing-platform-terraform-dev/dev/main.tf:7,14` | Backend region + provider region → `eu-central-1` |
| `ticketing-platform-terraform-dev/dev/main.tf:5` | Backend bucket → `ticketing-terraform-dev-eu` |
| `ticketing-platform-terraform-dev/dev/variables.tf:42,47,52` | AZ defaults → `eu-central-1a/b/c` |
| `ticketing-platform-terraform-dev/dev/variables.tf:64` | AMI ID → eu-central-1 equivalent |
| `ticketing-platform-terraform-dev/dev/rds.tf:162` | `availability_zones` → `["eu-central-1a","eu-central-1b","eu-central-1c"]` |
| `ticketing-platform-terraform-dev/dev/secretmanager.tf:2` | Hardcoded ARN → name-based lookup |
| `ticketing-platform-terraform-prod/prod/main.tf:9,16` | Backend region + provider region → `eu-central-1` |
| `ticketing-platform-terraform-prod/prod/main.tf:7` | Backend bucket → `ticketing-terraform-prod-eu` |
| `ticketing-platform-terraform-prod/prod/variables.tf:42,47,52` | AZ defaults → `eu-central-1a/b/c` |
| `ticketing-platform-terraform-prod/prod/variables.tf:65` | AMI ID → eu-central-1 equivalent |
| `ticketing-platform-terraform-prod/prod/rds.tf:200` | `availability_zones` → `["eu-central-1a","eu-central-1b","eu-central-1c"]` |
| `ticketing-platform-terraform-prod/prod/secretmanager.tf:4` | Hardcoded ARN → name-based lookup |

**Security remediation (prod only):**

| File | Variable | Issue |
|------|----------|-------|
| `ticketing-platform-terraform-prod/prod/variables.tf:97` | `opensearch_pass` | Plaintext → Secrets Manager |
| `ticketing-platform-terraform-prod/prod/variables.tf:117` | `rds_pass` | Plaintext → Secrets Manager |
| `ticketing-platform-terraform-prod/prod/variables.tf:125` | `rds_pass_inventory` | Plaintext → Secrets Manager |

**S3 lifecycle bug (dev):**

| File | Issue |
|------|-------|
| `ticketing-platform-terraform-dev/dev/s3.tf:246` | Lifecycle config references sandbox bucket instead of dev bucket — fix during Phase 1 |

### Category 2: CDK env-var JSON Files (~40 files)

All `env-var.{dev,sandbox,prod,demo}.json` files with `"STORAGE_REGION": "me-south-1"` across these services:

- `ticketing-platform-access-control/src/TP.AccessControl.Cdk/`
- `ticketing-platform-catalogue/src/TP.Catalogue.Cdk/`
- `ticketing-platform-distribution-portal/src/TP.DistributionPortal.Cdk/`
- `ticketing-platform-geidea/src/TP.Geidea.Cdk/`
- `ticketing-platform-integration/src/TP.Integration.Cdk/`
- `ticketing-platform-inventory/src/TP.Inventory.Cdk/`
- `ticketing-platform-loyalty/src/TP.Loyalty.Cdk/`
- `ticketing-platform-marketplace-service/src/TP.Marketplace.Cdk/`
- `ticketing-platform-media/src/TP.Media.Cdk/`
- `ticketing-platform-organizations/src/Organizations/TP.Organizations.Cdk/`
- `ticketing-platform-pricing/src/TP.Pricing.Cdk/`
- `ticketing-platform-reporting-api/src/TP.ReportingService.Cdk/`
- `ticketing-platform-sales/src/TP.Sales.Cdk/`
- `ticketing-platform-transfer/src/TP.Transfer.Cdk/`
- `ticketing-platform-tools/Debug.Cdk/`

**Bulk update script:**
```bash
find . -name "env-var.*.json" -not -path "*/node_modules/*" -not -path "*/.terraform/*" \
  -not -path "*/bin/*" -not -path "*/obj/*" -not -path "*/cdk.out/*" \
  -exec grep -l "me-south-1" {} \; | while read f; do
  sed -i '' 's/"STORAGE_REGION": "me-south-1"/"STORAGE_REGION": "eu-central-1"/g' "$f"
done
```

### Category 3: aws-lambda-tools-defaults.json (32+ files)

Every Lambda project directory with `"region": "me-south-1"`:

1. `ticketing-platform-access-control/src/TP.AccessControl.{BackgroundJobs,Consumers}/`
2. `ticketing-platform-csv-generator/TP.CSVGenerator.Consumers/`
3. `ticketing-platform-distribution-portal/src/TP.DistributionPortal.{BackgroundJobs,Consumers}/`
4. `ticketing-platform-extension-api/TP.Extensions.{BackgroundJobs,Consumers}/`
5. `ticketing-platform-extension-deployer/TP.Extensions.Deployer.Lambda/`
6. `ticketing-platform-extension-executor/TP.Extensions.Executor.Lambda/`
7. `ticketing-platform-extension-log-processor/TP.Extensions.LogsProcessor.Lambda/`
8. `ticketing-platform-gateway/src/Gateway/`
9. `ticketing-platform-geidea/src/TP.Geidea.{BackgroundJobs,Lambda.Balance}/`
10. `ticketing-platform-integration/src/TP.Integration.{BackgroundJobs,Consumers}/`
11. `ticketing-platform-inventory/src/TP.Inventory.{BackgroundJobs,Consumers}/`
12. `ticketing-platform-loyalty/src/TP.Loyalty.{BackgroundJobs,Consumers}/`
13. `ticketing-platform-marketplace-service/src/TP.Marketplace.{BackgroundJobs,Consumers}/`
14. `ticketing-platform-media/src/TP.Media.{BackgroundJobs,Consumers}/`
15. `ticketing-platform-organizations/src/Organizations/TP.Organizations.{BackgroundJobs,Consumers}/`
16. `ticketing-platform-pdf-generator/TP.PdfGenerator.Consumers/`
17. `ticketing-platform-pricing/src/TP.Pricing.Consumers/`
18. `ticketing-platform-reporting-api/src/TP.ReportingService.{BackgroundJobs,Consumers}/`
19. `ticketing-platform-sales/src/TP.Sales.{BackgroundJobs,Consumers}/`
20. `ticketing-platform-transfer/src/TP.Transfer.{BackgroundJobs,Consumers}/`

**Bulk update script:**
```bash
find . -name "aws-lambda-tools-defaults.json" \
  -not -path "*/node_modules/*" -not -path "*/.terraform/*" \
  -not -path "*/bin/*" -not -path "*/obj/*" -not -path "*/cdk.out/*" \
  -exec grep -l "me-south-1" {} \; | while read f; do
  sed -i '' 's/"region": "me-south-1"/"region": "eu-central-1"/g' "$f"
done
```

### Category 4: Infrastructure C# Code (2 files)

| File | Line | Change |
|------|------|--------|
| `ticketing-platform-infrastructure/TP.Infrastructure.SlackNotifier/Services/EnvironmentService.cs` | 24 | `?? "me-south-1"` → `?? "eu-central-1"` |
| `ticketing-platform-infrastructure/TP.Infrastructure.SlackNotifier/Services/XRayInsightSlackService.cs` | 58 | `?? "me-south-1"` → `?? "eu-central-1"` |

### Category 5: Test Files (lower priority, ~6 files)

- `ticketing-platform-media/src/Tests/TP.Media.IntegrationTests/ApplicationFactory.cs:28-29`
- `ticketing-platform-catalogue/src/Tests/TP.Catalogue.IntegrationTests/ApplicationFactory.cs:39-40`
- `ticketing-platform-organizations/src/Organizations/Tests/TP.Organizations.IntegrationTests/ApplicationFactory.cs:37-38`
- `ticketing-platform-inventory/src/Tests/TP.Inventory.IntegrationTests/ApplicationFactory.cs:58-59`
- `ticketing-platform-pricing/src/Tests/TP.Pricing.IntegrationTests/ApplicationFactory.cs:116-117`
- `ticketing-platform-infrastructure/TP.Infrastructure.Tests/SlackNotifier/` (multiple test files)
- `ticketing-platform-tools/UnitTests/Infrastructure/Consumers/LambdaUtilitiesTests.cs:252`
- `ticketing-platform-integration/src/TP.Integration.IntegrationTests/.../WhatsAppServiceTests.cs:139`

### Category 6: ConfigMap YAML Files

**Dev:**
- `ticketing-platform-configmap-dev/manifests/{access-control,integration,media,reporting,sales,transfer}-dev.yml` — `STORAGE_REGION`
- `ticketing-platform-configmap-dev/secretstore.yml` — `region: me-south-1`

**Sandbox:**
- `ticketing-platform-configmap-sandbox/manifests/{integration,media,reporting,sales,transfer}-sandbox.yml` — `STORAGE_REGION`
- `ticketing-platform-configmap-sandbox/secretstore.yml` — `region: me-south-1`

**Prod:**
- `ticketing-platform-configmap-prod/manifests-new/{integration,media,reporting,sales,transfer}.yml` — `STORAGE_REGION`
- `ticketing-platform-configmap-prod/manifests-new/sales.yml` — also has `Logging__Elasticsearch__Uri` with me-south-1 OpenSearch endpoint

**Note:** With EKS deprecated, these ConfigMap repos become archival. Update the region references for correctness, but these manifests will no longer be deployed.

### Category 7: Mobile Scanner CI/CD (1 file, 3 references)

| File | Lines | Change |
|------|-------|--------|
| `ticketing-platform-mobile-scanner/.github/workflows/release-build.yml` | 172 | `s3.me-south-1.amazonaws.com` → `s3.eu-central-1.amazonaws.com` |
| Same file | 200, 208 | `AWS_DEFAULT_REGION: me-south-1` → `AWS_DEFAULT_REGION: eu-central-1` |

### Category 8: Dashboard CSP (1 file)

`ticketing-platform-dashboard/vercel.json:24` — 6 S3 URLs in CSP `connect-src`:
- `dev-pdf-tickets.s3.me-south-1.amazonaws.com` → `.s3.eu-central-1.amazonaws.com`
- `tickets-pdf-download.s3.me-south-1.amazonaws.com` → `.s3.eu-central-1.amazonaws.com`
- `sandbox-pdf-tickets.s3.me-south-1.amazonaws.com` → `.s3.eu-central-1.amazonaws.com`
- `ticketing-sandbox-media.s3.me-south-1.amazonaws.com` → `.s3.eu-central-1.amazonaws.com`
- `ticketing-dev-media.s3.me-south-1.amazonaws.com` → `.s3.eu-central-1.amazonaws.com`
- `ticketing-prod-media.s3.me-south-1.amazonaws.com` → `.s3.eu-central-1.amazonaws.com`

**Note:** If S3 bucket names change (adding `-eu` suffix), these URLs must also reflect new bucket names.

### Category 9: CDK Context Cache Files (DELETE)

These are auto-generated caches containing me-south-1 VPC/subnet lookups. Delete them; they regenerate on `cdk synth`:
- `ticketing-platform-infrastructure/TP.Infrastructure.Cdk/cdk.context.json`
- `ticketing-platform-gateway/src/Gateway.Cdk/cdk.context.json`
- `ticketing-platform-media/src/TP.Media.Cdk/cdk.context.json`

### Category 10: Local Development Settings (lowest priority)

These contain me-south-1 RDS hosts, SQS URLs, OpenSearch URIs — update after new endpoints exist:
- `ticketing-platform-media/src/TP.Media.API/appsettings.Development.json`
- `ticketing-platform-pricing/src/TP.Pricing.API/Properties/launchSettings.json`
- `ticketing-platform-extension-api/TP.Extensions.API/Properties/launchSettings.json`
- `ticketing-platform-distribution-portal/src/TP.DistributionPortal.API/Properties/launchSettings.json`
- `ticketing-platform-gateway/src/Gateway/Properties/launchSettings.json`
- `ticketing-platform-sales/src/TP.Sales.API/Properties/launchSettings.json`

**Additional references found in review:**
- `ticketing-platform-dashboard/.env:9` — `MEDIA_HOST` with me-south-1 API Gateway URL
- `ticketing-platform-dashboard/.env.sandbox:9` — Same
- `ticketing-platform-dashboard/.env.development:10,28` — API Gateway URLs
- `ticketing-platform-distribution-portal/src/TP.DistributionPortal.API/Properties/launchSettings.json:29` — `AWS_REGION: "me-south-1"`

### Category 11: CI/CD Shared Templates (ticketing-platform-templates-ci-cd)

**Audited: 2026-03-24.** The shared template repo referenced by 22+ services as `mdlbeasts/ticketing-platform-templates-ci-cd@master`.

**CDK/Lambda workflows (NO changes needed):**
- `deploy-cdk.yml` — correctly uses `${{ secrets.AWS_DEFAULT_REGION }}`
- `build.yml` — correctly uses `${{ secrets.AWS_DEFAULT_REGION }}`
- `tests.yml` — correctly uses `${{ secrets.AWS_DEFAULT_REGION }}`
- `cloudwatch-logs-creator.yml` — correctly uses `${{ secrets.AWS_DEFAULT_REGION }}`

**EKS/Helm workflows (8 hardcoded references — dead code after EKS deprecation):**

| File | Line | Content |
|------|------|---------|
| `deploy.yml:26` | `aws ecr get-login-password --region me-south-1 \| helm registry login ... 307824719505.dkr.ecr.me-south-1.amazonaws.com` |
| `deploy.yml:28` | `helm push ... oci://307824719505.dkr.ecr.me-south-1.amazonaws.com/` |
| `deploy.yml:46` | `aws ecr get-login-password --region me-south-1 \| helm registry login ... 058264295036.dkr.ecr.me-south-1.amazonaws.com` |
| `deploy.yml:48` | `helm push ... oci://058264295036.dkr.ecr.me-south-1.amazonaws.com/` |
| `deploy.yml:67` | `aws ecr get-login-password --region me-south-1 \| helm registry login ... 660748123249.dkr.ecr.me-south-1.amazonaws.com` |
| `deploy.yml:69` | `helm push ... oci://660748123249.dkr.ecr.me-south-1.amazonaws.com/` |
| `k8s.yml:52` | `aws ecr get-login-password --region me-south-1 \| helm registry login ... ${{ inputs.ACCOUNT }}.dkr.ecr.me-south-1.amazonaws.com` |
| `k8s.yml:53` | `helm pull oci://${{ inputs.ACCOUNT }}.dkr.ecr.me-south-1.amazonaws.com/helm-chart` |

**Self-hosted runner labels:**
- `deploy.yml:35` — Branch-dependent labels: `dev`, `demo`, `prod`

**Action:** Update or remove `deploy.yml` and `k8s.yml` as part of EKS deprecation. CDK workflows are safe.

### Category 12: Dashboard .env Files

| File | Reference |
|------|-----------|
| `ticketing-platform-dashboard/.env:9` | `MEDIA_HOST=https://o5ewmhbma8.execute-api.me-south-1.amazonaws.com/sandbox/` |
| `ticketing-platform-dashboard/.env.sandbox:9` | Same pattern |
| `ticketing-platform-dashboard/.env.development:10` | API Gateway URL (commented) |
| `ticketing-platform-dashboard/.env.development:28` | `MEDIA_HOST=https://sijnsi3wg5.execute-api.me-south-1.amazonaws.com/prod` |

---

## EKS/Kubernetes Deprecation Inventory

**Decision:** All services will run exclusively on Lambda. EKS is deprecated.

### Terraform — Files to Remove (terraform-prod)

Following the pattern from terraform-dev commit `d01f7df` ("chore: attempt to disable eks"):

| File | Action | Resources |
|------|--------|-----------|
| `prod/opensearch.tf` | **DELETE entirely** | 3 subnets (`opensearch-1a/1b/1c-prod`), 1 security group (`opensearchprod`) |
| `prod/redis.tf` | **DELETE entirely** | 2 subnets (`redis-1a/1b-prod`), 1 security group (`redisprod`) |
| `prod/waf.tf` | **DELETE entirely** | WAF ACL, IP sets, rules (all reference me-south-1 ALB ARNs) |
| `prod/msk.tf` | **DELETE entirely** | Marked `/// probably delete` |
| `prod/runner.tf` | **DELETE entirely** | 2 subnets, 2 EC2 instances (`runner-1a/1b`), 1 security group, 2 route table associations |
| `prod/eks-subnet.tf` | **RENAME** → `prod/lambda-subnet.tf` | Keep 3 subnets + route table associations; update tags from `eks-subnet-*` to `lambda-subnet-*` |
| `prod/ecr.tf` | **DELETE entirely** | 2 ECR repos (`ticketing-platform-ecr`, `helm-chart`) — only used for EKS images |
| `prod/user-cicd.tf` | **Remove EKS policy** | Remove `aws_iam_policy.ci-cd-eks` and attachment; keep CICD user if needed for CDK deploys |
| `prod/iam-s3-sqs.tf` | **Remove EKS policy** | Remove `aws_iam_policy.s3-sqs-eks` — was for EKS service account S3/SQS access |

**Cross-references to update when removing EKS subnets:**

| File | Change |
|------|--------|
| `prod/rds.tf` | Remove security group ingress rules referencing `aws_subnet.eks-1a/1b/1c-prod.cidr_block` |
| `prod/group.tf` | Remove `techlead-redis` and `developer-opensearch` IAM group policy attachments |
| `prod/secretmanager.tf` | Remove `output.terraform_opensearch` |

### Terraform — Already Done (terraform-dev)

Dev terraform already removed EKS in commit `d01f7df`. Remaining cleanup:
- `dev/iam-eks.tf` — remove (orphaned IAM policy)
- `dev/iam-s3-sqs.tf` — remove `s3-sqs-eks` policy
- `dev/rds.tf` — remove ingress rules referencing `eks-*` subnet CIDRs
- `dev/nat.tf` — remove `kubernetes.io/role/elb` tags from subnets

### EKS Artifacts Across Monorepo (Archive/Remove)

| Category | Count | Action |
|----------|-------|--------|
| `helm/` directories (17 services) | 17 dirs | Archive — no longer deployed |
| ConfigMap manifests (dev/sandbox/prod) | 78 files | Archive — no longer deployed |
| ConfigMap CI/CD workflows (`ci.yml`) | 4 files | Disable or delete |
| ConfigMap `secretstore.yml` | 2 files | Archive |
| ConfigMap `sa.yml` (IRSA) | 1 file | Archive |
| ConfigMap `ingress.yml` (prod) | 1 file | Archive |
| ConfigMap `disaster.yml` (prod) | 1 file | Archive |
| Dockerfiles for K8s | 14 files | Keep (may still be useful for local dev) |
| `.svc.cluster.local` references | 41 files | No action (inside archived ConfigMaps) |
| `ticketing-platform-templates-ci-cd` `deploy.yml`, `k8s.yml` | 2 files | Remove or disable EKS workflows |

**Services with Helm charts (all deprecated):**
access-control, automations, catalogue, distribution-portal, extension-api, gateway, geidea, integration, inventory, loyalty, media, organizations, pricing, reporting-api, sales, transfer, templates-ci-cd

---

## Redis/ElastiCache & OpenSearch Removal Inventory

### Redis/ElastiCache

**Status:** Zombie infrastructure. Zero connections confirmed.
- `StackExchange.Redis` NuGet package imported in `TP.Tools.DataAccessLayer` but **never instantiated**
- All `Redis__Host` / `Redis__Password` config in all ConfigMaps is **commented out**
- Platform uses DynamoDB + in-memory caching (`DynamoDbCacheProvider.cs`, `MemoryCacheProvider.cs`)

**Terraform files:**
- `terraform-dev/dev/redis.tf` — already deleted in commit `d01f7df`
- `terraform-prod/prod/redis.tf` — delete (2 subnets, 1 security group, no actual cluster)

**ConfigMap references to clean:**
- Remove commented-out `Redis__Host` / `Redis__Password` from all manifests

### OpenSearch/Elasticsearch

**Status:** Ghost configuration. No Serilog Elasticsearch sink installed.
- `TP.Tools.Logger.csproj` has `Serilog.AspNetCore` but **no** `Serilog.Sinks.Elasticsearch`
- Config references exist in 27+ service ConfigMaps but no data flows to OpenSearch
- **Security concern:** Plaintext credentials in `configmap-prod/manifests-new/sales.yml`

**Terraform files:**
- `terraform-dev/dev/opensearch.tf` — already deleted in commit `d01f7df`
- `terraform-prod/prod/opensearch.tf` — delete (3 subnets, 1 security group, no actual domain)

**ConfigMap references to clean:**
- Remove `Logging__Elasticsearch__*` entries from all manifests
- Remove plaintext credentials from `configmap-prod/manifests-new/sales.yml`

---

## S3 Bucket Naming Strategy

S3 bucket names are globally unique. Cannot reuse names while old buckets exist.

| me-south-1 Bucket | eu-central-1 Bucket | Purpose |
|---|---|---|
| `dev-pdf-tickets` | `dev-pdf-tickets-eu` | Dev PDF tickets |
| `sandbox-pdf-tickets` | `sandbox-pdf-tickets-eu` | Sandbox PDF tickets |
| `pdf-tickets-prod` | `pdf-tickets-prod-eu` | Prod PDF tickets |
| `tickets-pdf-download` | `tickets-pdf-download-eu` | Prod PDF download |
| `pdf-tickets-download` | `pdf-tickets-download-eu` | Dev PDF download |
| `ticketing-dev-csv-reports` | `ticketing-dev-csv-reports-eu` | Dev CSV reports |
| `ticketing-sandbox-csv-reports` | `ticketing-sandbox-csv-reports-eu` | Sandbox CSV reports |
| `ticketing-csv-reports` | `ticketing-csv-reports-eu` | Prod CSV reports |
| `ticketing-{env}-media` | `ticketing-{env}-media-eu` | Media uploads |
| `ticketing-{env}-extended-message` | CDK creates with new name | Large event payloads |
| `ticketing-terraform-dev` | `ticketing-terraform-dev-eu` | Terraform state |
| `ticketing-terraform-prod` | `ticketing-terraform-prod-eu` | Terraform state |
| `ticketing-terraform-github` | `ticketing-terraform-github-eu` | Terraform CI/CD artifact sync |

**Where bucket names must be manually updated (NOT auto-propagated):**
- Terraform `s3.tf` / `variables.tf` — bucket definitions and IAM policy references
- CDK `env-var.*.json` files — `STORAGE_BUCKET_NAME`, `MEDIA_STORAGE_BUCKET_NAME` (media, integration, pdf-generator services)
- Dashboard `vercel.json` CSP — 6 hardcoded S3 URLs (both bucket name AND region)
- SSM parameter `/{env}/tp/pdf/generator/STORAGE_BUCKET_NAME` — value must match new bucket name
- CloudFront origins auto-resolve via `bucket_regional_domain_name` (no manual update needed)

---

## Phase 1: Code Preparation (No Infrastructure Changes)

**Duration:** 1-2 days | **Risk:** LOW | **Rollback:** Revert git commits

### Tasks

1. **Create feature branches** in each repo: `feature/region-migration-eu-central-1`

2. **Update all hardcoded references** (Categories 1-12 above)
   - Terraform files (both repos, including EKS/Redis/OpenSearch removal)
   - CDK env-var JSON files (bulk script for `STORAGE_REGION`; **manual update for bucket names** — see S3 Bucket Naming Strategy)
   - aws-lambda-tools-defaults.json (bulk script)
   - Infrastructure C# code
   - Mobile scanner CI/CD
   - Dashboard `vercel.json` (CSP S3 URLs: update both region AND bucket names) and `.env` files
   - Delete CDK context caches
   - CI/CD templates repo (`deploy.yml`, `k8s.yml`)
   - `ticketing-platform-terraform-prod/prod/s3.tf` — rename `ticketing-terraform-github` to `ticketing-terraform-github-eu`

3. **EKS deprecation in terraform-prod** (following terraform-dev pattern from `d01f7df`):
   - Delete `opensearch.tf`, `redis.tf`, `waf.tf`, `msk.tf`, `runner.tf`, `ecr.tf`
   - Rename `eks-subnet.tf` → `lambda-subnet.tf`, update tags
   - Remove EKS IAM policies from `user-cicd.tf`, `iam-s3-sqs.tf`
   - Remove EKS subnet references from `rds.tf` security group rules
   - Remove `techlead-redis`, `developer-opensearch` from `group.tf`
   - Remove `terraform_opensearch` output from `secretmanager.tf`

4. **EKS deprecation cleanup in terraform-dev:**
   - Remove `iam-eks.tf` (orphaned)
   - Remove `s3-sqs-eks` policy from `iam-s3-sqs.tf`
   - Remove EKS subnet CIDR references from `rds.tf`
   - Remove `kubernetes.io/role/elb` tags from `nat.tf`

5. **Security remediation:**
   - Add `.tfstate` and `.tfstate.backup` to `.gitignore` in both Terraform repos
   - Remove plaintext credentials from `configmap-prod/manifests-new/sales.yml`
   - Fix S3 lifecycle bug in `terraform-dev/dev/s3.tf:246`
   - (Prod plaintext creds in `variables.tf` — address in Phase 4.3)

6. **Disable ConfigMap CI/CD workflows:**
   - Remove or disable `ci.yml` in configmap-dev, configmap-sandbox, configmap-prod
   - Remove or disable `disaster.yml` in configmap-prod

7. **Run all tests** to verify code changes don't break anything:
   ```bash
   # .NET services
   dotnet test
   # Dashboard
   npm run test && npm run typescript
   ```

8. **Verify** zero `me-south-1` references remain in deployable code:
   ```bash
   grep -r "me-south-1" --include="*.tf" --include="*.cs" --include="*.json" \
     --include="*.yml" --include="*.yaml" \
     --exclude-dir={.terraform,node_modules,bin,obj,cdk.out,.git,helm} \
     | grep -v "configmap-" | grep -v "README"
   ```

9. **DO NOT merge yet.** Keep on feature branches until infrastructure is ready.

---

## Phase 2: Dev+Sandbox Foundation & Data Restore

**Duration:** 2-3 days | **Risk:** MEDIUM | **Account:** `307824719505`

### 2.1 Service Quota Pre-Checks

```bash
# Check eu-central-1 quotas
aws service-quotas list-service-quotas --service-code lambda --region eu-central-1 \
  --query 'Quotas[?QuotaName==`Concurrent executions`].Value'
aws service-quotas list-service-quotas --service-code vpc --region eu-central-1 \
  --query 'Quotas[?contains(QuotaName,`NAT`)].{Name:QuotaName,Value:Value}'
aws service-quotas list-service-quotas --service-code rds --region eu-central-1 \
  --query 'Quotas[?contains(QuotaName,`cluster`)].{Name:QuotaName,Value:Value}'

# Request increases if needed before proceeding
```

### 2.2 Create Terraform State Bucket

```bash
aws s3 mb s3://ticketing-terraform-dev-eu --region eu-central-1
aws s3api put-bucket-versioning --bucket ticketing-terraform-dev-eu \
  --versioning-configuration Status=Enabled --region eu-central-1
aws s3api put-bucket-encryption --bucket ticketing-terraform-dev-eu \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  --region eu-central-1
```

### 2.3 Recreate Secrets Manager Entries

Since me-south-1 is down, secrets cannot be replicated. They must be recreated from AWS Backup or documentation.

```bash
# Option A: If AWS Backup includes Secrets Manager
# List available backup recovery points for Secrets Manager in eu-central-1
aws backup list-recovery-points-by-resource-type \
  --resource-type "AWS::SecretsManager::Secret" \
  --region eu-central-1

# Option B: Recreate manually from documentation/password manager
# For each service, create the required secrets:
for env in dev sandbox; do
  # Example: create service secrets
  aws secretsmanager create-secret --name "/$env/sales" \
    --secret-string '{"CONNECTION_STRING":"...","API_KEY":"..."}' \
    --region eu-central-1
done

# Terraform bootstrap secret
aws secretsmanager create-secret --name "terraform" \
  --secret-string '{"rds_pass":"...","opensearch_pass":"..."}' \
  --region eu-central-1

# Verify all secrets exist
aws secretsmanager list-secrets --region eu-central-1 \
  --query 'SecretList[*].Name' --output table
```

### 2.4 Terraform Apply

**Important:** The Terraform configs from Phase 1 already exclude EKS, Redis, OpenSearch, WAF, MSK, and runners. This is a clean apply.

```bash
cd ticketing-platform-terraform-dev/dev
terraform init -reconfigure   # Points to new eu-central-1 state bucket
terraform plan                # Review carefully — should show all creates, zero destroys
terraform apply
```

**Creates:** VPC (10.10.0.0/16), 3x subnets per tier (Lambda subnets, RDS subnets, management), NAT Gateways, Route53 zones, S3 buckets (new `-eu` names), KMS keys, IAM roles, security groups, CloudFront distributions, OpenVPN EC2.

**Does NOT create:** EKS cluster, Redis, OpenSearch, WAF, MSK, runners.

**Route53 DNS rerouting:** Terraform creates **new** public hosted zones (`dev.tickets.mdlbeast.net`, `sandbox.tickets.mdlbeast.net`) in eu-central-1. Route53 is a global service, but since this is a fresh Terraform state, new zones are created with new NS records. After `terraform apply`:

1. Get the new zone's nameservers:
   ```bash
   aws route53 get-hosted-zone --id <new-zone-id> --query 'DelegationSet.NameServers'
   ```
2. **Update NS delegation at the parent domain** (`tickets.mdlbeast.net` or `mdlbeast.net`) to point to the new zone's nameservers. This is the step that makes public DNS resolve to eu-central-1.
3. CDK stacks (Phase 3) will create A records in these zones pointing to the new eu-central-1 API Gateway endpoints — both public records (`api.{env}.*`, `geidea.{env}.*`) and private VPC-associated records (`*.internal.{env}.*`)

**Note:** Since me-south-1 is down, the old DNS records are already broken. There is no "cutover" risk — updating NS delegation simply restores DNS resolution via the new eu-central-1 infrastructure.

**Verification:**
```bash
aws ec2 describe-vpcs --region eu-central-1 \
  --filters "Name=tag:Name,Values=ticketing" --query 'Vpcs[0].VpcId'
aws ec2 describe-subnets --region eu-central-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" --query 'Subnets | length(@)'
```

### 2.5 Populate Manual SSM Parameters

These bridge Terraform → CDK and must exist before any CDK deploy:

```bash
# VPC name (CDK's CdkStackUtilities.GetTicketingVpc reads this)
for env in dev sandbox; do
  aws ssm put-parameter --name "/$env/tp/VPC_NAME" \
    --type String --value "ticketing" --region eu-central-1
done

# RDS cluster references (after restore in 2.6)
aws ssm put-parameter --name "/rds/ticketing-cluster-identifier" \
  --type String --value "ticketing-eu" --region eu-central-1

RDS_SG=$(aws ec2 describe-security-groups --region eu-central-1 \
  --filters "Name=group-name,Values=rds-one" \
  --query 'SecurityGroups[0].GroupId' --output text)
aws ssm put-parameter --name "/rds/ticketing-cluster-sg" \
  --type String --value "$RDS_SG" --region eu-central-1

# Subnet IDs for extension deployer
SUBNET_1=$(aws ec2 describe-subnets --region eu-central-1 \
  --filters "Name=tag:Name,Values=lambda-subnet-1a-prod" \
  --query 'Subnets[0].SubnetId' --output text)
SUBNET_2=$(aws ec2 describe-subnets --region eu-central-1 \
  --filters "Name=tag:Name,Values=lambda-subnet-1b-prod" \
  --query 'Subnets[0].SubnetId' --output text)
SUBNET_3=$(aws ec2 describe-subnets --region eu-central-1 \
  --filters "Name=tag:Name,Values=lambda-subnet-1c-prod" \
  --query 'Subnets[0].SubnetId' --output text)

for env in dev sandbox; do
  aws ssm put-parameter --name "/$env/tp/SUBNET_1" --type String --value "$SUBNET_1" --region eu-central-1
  aws ssm put-parameter --name "/$env/tp/SUBNET_2" --type String --value "$SUBNET_2" --region eu-central-1
  aws ssm put-parameter --name "/$env/tp/SUBNET_3" --type String --value "$SUBNET_3" --region eu-central-1
done

# PDF Generator S3 bucket name (used by PdfGenerator ConsumersStack at CDK synth time)
aws ssm put-parameter --name "/dev/tp/pdf/generator/STORAGE_BUCKET_NAME" \
  --type String --value "dev-pdf-tickets-eu" --region eu-central-1
aws ssm put-parameter --name "/sandbox/tp/pdf/generator/STORAGE_BUCKET_NAME" \
  --type String --value "sandbox-pdf-tickets-eu" --region eu-central-1

# Slack webhook URLs (must be retrieved from Slack workspace or password manager)
for env in dev sandbox; do
  for param in ErrorsWebhookUrl OperationalErrorsWebhookUrl SuspiciousOrdersWebhookUrl; do
    aws ssm put-parameter --name "/$env/tp/SlackNotification/$param" \
      --type SecureString --value "<webhook-url>" --region eu-central-1
  done
  aws ssm put-parameter --name "/$env/tp/SlackNotification/IgnoredErrorsPatterns" \
    --type StringList --value "<patterns>" --region eu-central-1
done
```

**Verification:**
```bash
aws ssm get-parameters-by-path --path "/" --recursive --region eu-central-1 \
  --query 'Parameters[*].Name'
```

### 2.6 Restore Aurora from AWS Backup

Since me-south-1 is down, restore from the cross-region backup copy in eu-central-1.

```bash
# 1. List available Aurora backup recovery points in eu-central-1
aws backup list-recovery-points-by-resource-type \
  --resource-type "Aurora" --region eu-central-1 \
  --query 'sort_by(RecoveryPoints, &CreationDate)[-1]'

# 2. Restore the cluster from the most recent recovery point
aws backup start-restore-job \
  --recovery-point-arn "<recovery-point-arn>" \
  --iam-role-arn "arn:aws:iam::307824719505:role/AWSBackupDefaultRole" \
  --metadata '{
    "DBClusterIdentifier": "ticketing-eu",
    "Engine": "aurora-postgresql",
    "DBSubnetGroupName": "postgres",
    "VpcSecurityGroupIds": "'$RDS_SG'"
  }' \
  --region eu-central-1

# 3. Wait for restore to complete
aws backup describe-restore-job --restore-job-id "<job-id>" --region eu-central-1

# 4. Verify the engine version matches expectations
aws rds describe-db-clusters --db-cluster-identifier ticketing-eu \
  --query 'DBClusters[0].EngineVersion' --region eu-central-1

# 5. Add serverless instances (match dev instance count: 3)
for i in 0 1 2; do
  aws rds create-db-instance \
    --db-instance-identifier ticketing-eu-instance-$i \
    --db-cluster-identifier ticketing-eu \
    --engine aurora-postgresql \
    --db-instance-class db.serverless \
    --region eu-central-1
done

# 6. Set Serverless v2 scaling (dev: 0.5-3 ACU)
aws rds modify-db-cluster \
  --db-cluster-identifier ticketing-eu \
  --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=3 \
  --region eu-central-1

# 7. Verify cluster is available and writable
aws rds describe-db-clusters --db-cluster-identifier ticketing-eu \
  --query 'DBClusters[0].{Status:Status,Endpoint:Endpoint,ReaderEndpoint:ReaderEndpoint}' \
  --region eu-central-1
```

### 2.7 Restore S3 Data from AWS Backup

```bash
# 1. List S3 backup recovery points in eu-central-1
aws backup list-recovery-points-by-resource-type \
  --resource-type "S3" --region eu-central-1

# 2. For each bucket, restore to the new eu-central-1 bucket
# New buckets were created by Terraform in 2.4 with -eu suffix
# Restore backed-up data into the new buckets

aws backup start-restore-job \
  --recovery-point-arn "<recovery-point-arn>" \
  --iam-role-arn "arn:aws:iam::307824719505:role/AWSBackupDefaultRole" \
  --metadata '{
    "DestinationBucketName": "dev-pdf-tickets-eu",
    "NewBucket": "false"
  }' \
  --region eu-central-1

# Repeat for each bucket:
# - dev-pdf-tickets → dev-pdf-tickets-eu
# - sandbox-pdf-tickets → sandbox-pdf-tickets-eu
# - ticketing-dev-csv-reports → ticketing-dev-csv-reports-eu
# - ticketing-sandbox-csv-reports → ticketing-sandbox-csv-reports-eu
# - ticketing-dev-media → ticketing-dev-media-eu
# - ticketing-sandbox-media → ticketing-sandbox-media-eu

# 3. Verify object counts
for bucket in dev-pdf-tickets-eu sandbox-pdf-tickets-eu ticketing-dev-csv-reports-eu \
  ticketing-sandbox-csv-reports-eu ticketing-dev-media-eu ticketing-sandbox-media-eu; do
  echo "$bucket: $(aws s3 ls s3://$bucket --recursive --summarize --region eu-central-1 | tail -1)"
done
```

### 2.8 CDK Bootstrap

**Required before any `cdk deploy` in eu-central-1.** CDK needs its bootstrap S3 bucket and IAM roles.

```bash
CDK_DEFAULT_ACCOUNT=307824719505 CDK_DEFAULT_REGION=eu-central-1 \
  npx cdk bootstrap aws://307824719505/eu-central-1
```

**Creates:**
- S3 bucket: `cdk-hnb659fds-assets-307824719505-eu-central-1`
- IAM roles for CDK deployment
- CloudFormation stack: `CDKToolkit`

### Phase 2 Verification Checklist

- [ ] VPC exists in eu-central-1 with correct CIDR and 3 AZs
- [ ] All subnets created (Lambda, RDS, management tiers) — **no EKS, Redis, OpenSearch, runner subnets**
- [ ] NAT Gateways operational with Elastic IPs
- [ ] Route53 hosted zones created (dev, sandbox) — **update NS delegation at parent domain**
- [ ] Aurora cluster restored from backup and available with 3 instances
- [ ] Aurora Serverless v2 scaling configured (0.5-3 ACU)
- [ ] S3 data restored to new `-eu` buckets
- [ ] All SSM parameters populated
- [ ] All secrets recreated in eu-central-1
- [ ] KMS key created in eu-central-1
- [ ] Security groups configured (no EKS/Redis/OpenSearch rules)
- [ ] CDK bootstrap stack deployed

---

## Phase 3: Dev+Sandbox Services & Validation

**Duration:** 2-3 days | **Risk:** MEDIUM | **Rollback:** `cdk destroy` all stacks

### 3.1 Create ACM Certificates

Three certificates needed before CDK stack deployment:

```bash
# 1. Gateway public certificate (manual — not created by CDK)
for env in dev sandbox; do
  CERT_ARN=$(aws acm request-certificate \
    --domain-name "api.$env.tickets.mdlbeast.net" \
    --validation-method DNS \
    --region eu-central-1 \
    --query 'CertificateArn' --output text)
  # Complete DNS validation via Route53
  aws ssm put-parameter --name "/$env/tp/DomainCertificateArn" \
    --type String --value "$CERT_ARN" --region eu-central-1
done

# 2. Geidea certificate (manual — not created by CDK)
for env in dev sandbox; do
  CERT_ARN=$(aws acm request-certificate \
    --domain-name "geidea.$env.tickets.mdlbeast.net" \
    --validation-method DNS \
    --region eu-central-1 \
    --query 'CertificateArn' --output text)
  aws ssm put-parameter --name "/$env/tp/geidea/DomainCertificateArn" \
    --type String --value "$CERT_ARN" --region eu-central-1
done

# 3. Internal certificate — created by InternalCertificateStack in 3.2 (no manual action)

# Verify all certs are ISSUED
aws acm list-certificates --region eu-central-1 \
  --query 'CertificateSummaryList[*].{Domain:DomainName,Status:Status}'
```

### 3.2 Infrastructure CDK (11 Stacks — Strict Order)

```bash
cd ticketing-platform-infrastructure
export CDK_DEFAULT_ACCOUNT=307824719505
export CDK_DEFAULT_REGION=eu-central-1

# Deploy for dev (then repeat for sandbox)
export ENV_NAME=dev

# 1. EventBus (foundational — no dependencies)
cdk deploy TP-EventBusStack-dev --require-approval never

# 2. Consumer SQS queues (creates queues + stores ARNs in SSM)
cdk deploy TP-ConsumersSqsStack-dev --require-approval never

# 3. Consumer subscriptions (needs EventBus + SQS queue ARNs)
cdk deploy TP-ConsumerSubscriptionStack-dev --require-approval never

# 4. Extended message S3 bucket (no dependencies)
cdk deploy TP-ExtendedMessageS3BucketStack-dev --require-approval never

# 5. Internal hosted zone (needs VPC)
cdk deploy TP-InternalHostedZoneStack-dev --require-approval never

# 6. Internal certificate (needs hosted zone + public Route53 zone)
cdk deploy TP-InternalCertificateStack-dev --require-approval never

# 7. Monitoring (needs EventBus)
cdk deploy TP-MonitoringStack-dev --require-approval never

# 8. API Gateway VPC endpoint (needs VPC — shared for dev/sandbox)
cdk deploy TP-ApiGatewayVpcEndpointStack --require-approval never

# 9. RDS Proxy (needs VPC + RDS cluster + SSM params)
cdk deploy TP-RdsProxyStack --require-approval never

# 10. Slack notification (needs SSM webhook URLs)
cdk deploy TP-SlackNotificationStack-dev --require-approval never

# 11. XRay insight notification (needs EventBus + SSM webhooks)
cdk deploy TP-XRayInsightNotificationStack-dev --require-approval never
```

### 3.3 Update Connection Strings

After RDS Proxy deploys, get the new endpoint and update service secrets:

```bash
RDS_PROXY_ENDPOINT=$(aws rds describe-db-proxies --region eu-central-1 \
  --query 'DBProxies[0].Endpoint' --output text)

# Update each service's CONNECTION_STRINGS in Secrets Manager
# Format: Host=<endpoint>;Database=<db>;Username=<user>;Password=<pass>
```

### 3.4 Per-Service CDK Deployment Matrix

Deploy services using the validated per-service stack matrix. **Not all services follow the same pattern.**

For each service, set:
```bash
export CDK_DEFAULT_REGION=eu-central-1 ENV_NAME=dev
```

| # | Service | Stacks (deploy in order) | Has DbMigrator |
|---|---------|--------------------------|----------------|
| 1 | **gateway** | GatewayStack | NO |
| 2 | **catalogue** | DbMigratorStack → ServerlessBackendStack | YES |
| 3 | **organizations** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 4 | **inventory** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 5 | **pricing** | DbMigratorStack → ConsumersStack → ServerlessBackendStack | YES |
| 6 | **sales** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 7 | **access-control** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 8 | **media** | DbMigratorStack → MediaStorageStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 9 | **reporting-api** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 10 | **transfer** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 11 | **loyalty** | ConsumersStack → BackgroundJobsStack | NO |
| 12 | **marketplace** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 13 | **integration** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 14 | **distribution-portal** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 15 | **geidea** | ConsumersStack → BackgroundJobsStack → ApiStack (HTTP API v2) | NO |
| 16 | **extension-api** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 17 | **extension-deployer** | ExtensionDeployerLambdaRoleStack → ExtensionDeployerStack | NO |
| 18 | **extension-executor** | ExtensionExecutorStack | NO |
| 19 | **extension-log-processor** | ExtensionLogsProcessorStack | NO |
| 20 | **csv-generator** | ConsumersStack | NO |
| 21 | **pdf-generator** | ConsumersStack | NO |
| 22 | **automations** | WeeklyTicketsSenderStack + AutomaticDataExporterStack + FinanceReportSenderStack | NO |
| 23 | **customer-service** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |

**For services with DbMigrator:**
```bash
cd ticketing-platform-<service>/src/TP.<Service>.Cdk

# 1. Deploy DbMigrator stack
cdk deploy TP-DbMigratorStack-<service>-dev --require-approval never

# 2. Run migration
aws lambda invoke --function-name "<service>-db-migrator-lambda-dev" \
  --payload '{}' --region eu-central-1 /dev/null

# 3. Create log groups
aws logs create-log-group --log-group-name "/aws/lambda/<service>-serverless-dev-function" --region eu-central-1
aws logs create-log-group --log-group-name "/aws/lambda/<service>-consumers-lambda-dev" --region eu-central-1

# 4+. Deploy remaining stacks in order per matrix above
```

### 3.5 Update GitHub Secrets & Variables

```bash
repos=(
  ticketing-platform-infrastructure ticketing-platform-access-control
  ticketing-platform-catalogue ticketing-platform-sales
  ticketing-platform-inventory ticketing-platform-reporting-api
  ticketing-platform-media ticketing-platform-pricing
  ticketing-platform-transfer ticketing-platform-loyalty
  ticketing-platform-marketplace-service ticketing-platform-organizations
  ticketing-platform-geidea ticketing-platform-csv-generator
  ticketing-platform-integration ticketing-platform-extension-api
  ticketing-platform-extension-executor ticketing-platform-extension-deployer
  ticketing-platform-extension-log-processor ticketing-platform-pdf-generator
  ticketing-platform-gateway ticketing-platform-distribution-portal
  ticketing-platform-tools ticketing-platform-dashboard
  ticketing-platform-distribution-portal-frontend
  ticketing-platform-terraform-dev ticketing-platform-terraform-prod
  ticketing-platform-mobile-scanner ticketing-platform-templates-ci-cd
  ticketing-platform-automations ticketing-platform-customer-service
  ticketing-platform-shared
  ticketing-platform-configmap-dev ticketing-platform-configmap-sandbox
)

# Update ALL region-related secrets (not just AWS_DEFAULT_REGION)
for repo in "${repos[@]}"; do
  gh secret set AWS_DEFAULT_REGION --body "eu-central-1" --repo "mdlbeasts/$repo"
done

# Additional secrets on specific repos
gh secret set AWS_DEFAULT_REGION_PROD --body "eu-central-1" --repo "mdlbeasts/ticketing-platform-terraform-dev"
gh secret set TP_AWS_DEFAULT_REGION_PROD --body "eu-central-1" --repo "mdlbeasts/ticketing-platform-configmap-prod"
gh secret set AWS_DEFAULT_REGION_PROD --body "eu-central-1" --repo "mdlbeasts/ticketing-platform-configmap-prod"
gh secret set CDK_DEFAULT_REGION --body "eu-central-1" --repo "mdlbeasts/ticketing-platform-extension-deployer"

# GitHub variables (not secrets)
gh variable set STORYBOOK_BUCKET_NAME --body "<new-eu-bucket>" --repo "mdlbeasts/ticketing-platform-dashboard"
gh variable set STORYBOOK_CLOUDFRONT_DISTRIBUTION_ID --body "<new-distro-id>" --repo "mdlbeasts/ticketing-platform-dashboard"
```

### 3.6 Merge Feature Branches & Deploy Frontends

- Merge all `feature/region-migration-eu-central-1` branches into `development`
- Dashboard: merge vercel.json + .env changes → triggers Vercel redeploy
- Distribution Portal: merge and verify
- Trigger a test CDK deployment of one service to verify CI/CD targets eu-central-1

### 3.7 End-to-End Validation

- [ ] Dashboard login works (Auth0 + API)
- [ ] Create event in catalogue
- [ ] Create tickets in inventory
- [ ] Process test order through sales
- [ ] PDF ticket generation (S3 in eu-central-1)
- [ ] CSV report generation
- [ ] Media upload/download
- [ ] Access control scanning flow
- [ ] Slack notifications arriving (check console links point to eu-central-1)
- [ ] Inter-service event flow (EventBridge → SQS → Consumer)
- [ ] CloudWatch logs populating in eu-central-1
- [ ] Geidea payment webhook test (verify API endpoint accessible)
- [ ] Extension deployer creates Lambda in eu-central-1

### Phase 3 Verification Checklist

- [ ] All 11 infrastructure stacks in CREATE_COMPLETE (both dev + sandbox)
- [ ] All 21 service stacks deployed per matrix
- [ ] All DB migrations ran successfully
- [ ] Lambda functions responding (test invoke each)
- [ ] EventBridge rules → SQS queues (18 consumers)
- [ ] Internal DNS resolving (`*.internal.dev.tickets.mdlbeast.net`)
- [ ] API Gateway endpoints accessible via VPC endpoint
- [ ] RDS Proxy connecting to Aurora
- [ ] GitHub secrets updated (all 4 region secrets)
- [ ] CI/CD deploying to eu-central-1 (verify with one test push)

---

## Phase 4: Production Foundation & Data Restore

**Duration:** 2-3 days | **Risk:** HIGH | **Account:** `660748123249`

Same pattern as Phase 2 but for production account.

### 4.1 Service Quota Pre-Checks (Prod)
Same as 2.1 but for prod account.

### 4.2 State Bucket (Prod)
```bash
aws s3 mb s3://ticketing-terraform-prod-eu --region eu-central-1 --profile prod
# Enable versioning + encryption (same as 2.2)
```

### 4.3 Security Remediation
- Move plaintext passwords from `variables.tf` to Secrets Manager (`rds_pass`, `rds_pass_inventory`, `opensearch_pass`)
- Update Terraform to use `data.aws_secretsmanager_secret_version` for credential retrieval
- Rotate any credentials that were committed to git history

### 4.4 Recreate Prod Secrets
Same as 2.3 but for `/prod/` prefix secrets.

### 4.5 Terraform Apply (Prod)
```bash
cd ticketing-platform-terraform-prod/prod
terraform init -reconfigure
terraform plan    # Verify: creates VPC, RDS, S3, IAM — NO EKS/Redis/OpenSearch/WAF/runners
terraform apply
```

### 4.6 Populate Prod SSM Parameters
Same as 2.5 but for prod account with prod values. Including:
- `/{env}/tp/pdf/generator/STORAGE_BUCKET_NAME` → `pdf-tickets-prod-eu` (or equivalent prod bucket name)

### 4.7 Restore Aurora from AWS Backup (Prod)
Same pattern as 2.6 but:
- Use prod backup recovery point
- Cluster identifier: `ticketing-prod-eu`
- **3 serverless instances** for prod
- **Scaling: MinCapacity=1.5, MaxCapacity=64** (match prod capacity)
- **Temporarily increase MinCapacity to 8+ ACU** during go-live week to handle cold-cache load

### 4.8 Restore S3 Data (Prod)
Same as 2.7 for prod buckets:
- `pdf-tickets-prod` → `pdf-tickets-prod-eu`
- `tickets-pdf-download` → `tickets-pdf-download-eu`
- `ticketing-csv-reports` → `ticketing-csv-reports-eu`
- `ticketing-prod-media` → `ticketing-prod-media-eu`

### 4.9 CDK Bootstrap (Prod)
```bash
CDK_DEFAULT_ACCOUNT=660748123249 CDK_DEFAULT_REGION=eu-central-1 \
  npx cdk bootstrap aws://660748123249/eu-central-1 --profile prod
```

---

## Phase 5: Production Services & Go-Live

**Duration:** 1-2 days | **Risk:** CRITICAL

### 5.1 Create ACM Certificates (Prod)
Same as 3.1 but for prod domains (`api.tickets.mdlbeast.net`, `geidea.tickets.mdlbeast.net`).

### 5.2 Deploy All CDK Stacks (Prod)
Same as 3.2 with `ENV_NAME=prod`.

### 5.3 Update Connection Strings (Prod)
Same as 3.3 for prod secrets.

### 5.4 Per-Service CDK (Prod)
Same matrix as 3.4 with `ENV_NAME=prod`.

### 5.5 Update GitHub Secrets (Prod)
```bash
# Prod-specific secrets (if separate from dev)
gh secret set AWS_DEFAULT_REGION_PROD --body "eu-central-1" --repo "mdlbeasts/ticketing-platform-terraform-prod"
```

### 5.6 Merge to Production & Deploy Frontends
- Merge feature branches to `master`/`production`
- Dashboard: Vercel auto-deploys
- Distribution Portal: verify deployment
- Mobile Scanner: trigger release build

### 5.7 End-to-End Validation (Prod)
Full ticket lifecycle test:
- [ ] Dashboard login (prod Auth0)
- [ ] Create event → create tickets → process order → generate PDF → scan ticket
- [ ] Payment flow (Geidea webhook delivery to new endpoint)
- [ ] CSV report generation
- [ ] Media upload/download
- [ ] Inter-service event flow
- [ ] Slack error notifications (verify console links)
- [ ] CloudWatch logs + X-Ray traces in eu-central-1
- [ ] DNS resolution for all public endpoints

### 5.8 Post-Go-Live Monitoring (72 hours)

- CloudWatch dashboards for all services
- Slack error channel for elevated error rates
- Sentry for new error patterns
- RDS metrics (connections, latency, CPU, ACU utilization)
- S3 access patterns
- Lambda cold start frequency

**After 72 hours stable:** Reduce Aurora min ACU back to normal production levels.

---

## Post-Migration Tasks

### Extension Lambda Redeployment

Existing extension Lambdas from me-south-1 no longer exist. Extension metadata survives in the restored Aurora database. Redeploy all active extensions to eu-central-1:

```bash
# 1. Verify extension-deployer SSM parameter exists
aws ssm get-parameter --name "/{env}/tp/extensions/EXTENSION_DEFAULT_ROLE" --region eu-central-1

# 2. Query extension-api for all deployed extensions
# (via API or direct DB query against restored Aurora)
# Look for extensions with deploymentStatus = Deployed

# 3. For each extension, trigger redeployment:
# Option A: Call extension-api update endpoint for each extension
# Option B: Publish ExtensionChangeEvent to SQS for each extension
# The deployer Lambda (now in eu-central-1) will recreate Extension_{id} Lambdas
```

Do this after Phase 3.7 (dev/sandbox) and Phase 5.7 (prod).

---

## Post-Migration Cleanup

### Data Stores (after 7-day stability)
- [ ] Schedule me-south-1 KMS key deletion (7-day minimum wait) — once region recovers
- [ ] Verify all S3 data restored completely (compare object counts if possible)
- [ ] Import Aurora cluster into Terraform state

### Infrastructure (once me-south-1 recovers)
- [ ] Delete any remaining me-south-1 resources via Terraform/CDK
- [ ] Delete me-south-1 Terraform state buckets
- [ ] Clean up IAM roles/policies specific to me-south-1

### EKS Deprecation Cleanup
- [ ] Delete EKS cluster in me-south-1 (once region recovers)
- [ ] Delete ECR repositories (no longer needed)
- [ ] Archive ConfigMap repos (add README noting EKS deprecation)
- [ ] Remove `deploy.yml` and `k8s.yml` from `ticketing-platform-templates-ci-cd`
- [ ] Remove Helm charts from all service repos (or add deprecation notice)
- [ ] Remove Dockerfiles that were EKS-only (keep if useful for local dev)

### Redis/OpenSearch Cleanup
- [ ] Delete Redis clusters in me-south-1 (once region recovers)
- [ ] Delete OpenSearch domains in me-south-1 (once region recovers)
- [ ] Remove all `Redis__Host`, `Redis__Password` commented config from ConfigMaps
- [ ] Remove all `Logging__Elasticsearch__*` config from ConfigMaps
- [ ] Remove `StackExchange.Redis` NuGet package from `TP.Tools.DataAccessLayer` if unused
- [ ] Remove Redis health check code from `HealthCheckExtensions.cs`

### Runner Cleanup
- [ ] Deregister me-south-1 GitHub Actions runners (once region recovers)
- [ ] Terminate runner EC2 instances
- [ ] Update ConfigMap CI/CD workflows to use `ubuntu-latest` (or delete workflows entirely)

### Configuration
- [ ] Promote any Secrets Manager replicas to standalone in eu-central-1 (if applicable)
- [ ] Verify no remaining GitHub secret references to me-south-1
- [ ] Restore DNS TTLs to normal values (300-3600s) — if they were lowered before outage

### Security
- [ ] Rotate all credentials (new RDS passwords, API keys for eu-central-1)
- [ ] Audit IAM policies for region-specific ARNs
- [ ] Remove committed `.tfstate` files from git history (consider BFG Repo-Cleaner)

### Documentation
- [ ] Update CLAUDE.md with new region references
- [ ] Update `.personal/DEPLOYMENT.md` and `.personal/ARCHITECTURE.md`
- [ ] Document the EKS deprecation decision and Lambda-only architecture

---

## Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **AWS Backup restore fails or data is stale** | LOW | CRITICAL | Verify backup recency; test restore on dev first; check RPO of backup schedule |
| **Secrets cannot be reconstructed** | MEDIUM | CRITICAL | Maintain offline credential documentation; check AWS Backup for Secrets Manager |
| CDK deploy fails (missing bootstrap) | ~~HIGH~~ RESOLVED | CRITICAL | CDK bootstrap added as Phase 2.8 and 4.9 |
| Gateway/Geidea CDK fails (missing cert SSM) | ~~HIGH~~ RESOLVED | HIGH | ACM cert creation added as Phase 3.1 and 5.1 |
| CI/CD deploys to wrong region (missed secrets) | ~~MEDIUM~~ RESOLVED | HIGH | All 4 GitHub secrets updated in Phase 3.5 |
| CDK stack deployment fails (wrong pattern) | ~~HIGH~~ RESOLVED | MEDIUM | Per-service matrix replaces generic template |
| Missing SSM parameter | MEDIUM | HIGH | Comprehensive param list in 2.5; verify all exist before CDK |
| Cold Aurora with prod load | MEDIUM | HIGH | Increase min ACU during go-live week; restore gives warm data |
| Extension Lambdas orphaned in me-south-1 | MEDIUM | MEDIUM | Document redeployment requirement; verify deployer uses `AWS_REGION` env var |
| S3 bucket naming collision | LOW | MEDIUM | Using `-eu` suffix strategy; old buckets in down region don't conflict |
| DNS propagation delay | LOW | MEDIUM | Lower TTL if possible; use weighted routing |
| eu-central-1 service limits | LOW | HIGH | Pre-check quotas in 2.1 and 4.1 |
| Cold Lambda performance post-go-live | MEDIUM | MEDIUM | Consider provisioned concurrency for gateway/sales |
| Storybook deployment broken | MEDIUM | LOW | Migrate S3 + CloudFront; update GitHub vars |
| S3 lifecycle on wrong bucket (dev) | LOW | LOW | Fixed in Phase 1 |

---

*Plan created: 2026-03-05*
*Revised: 2026-03-24 — me-south-1 down (disaster recovery), EKS deprecated, Redis/OpenSearch removed, CDK bootstrap added, per-service CDK matrix, CI/CD templates audited*
*Based on research in: `.planning/research/{ARCHITECTURE,PITFALLS,STACK}.md`*
*Review document: `.personal/tasks/2026-03-05_aws-region-migration/review.md`*
