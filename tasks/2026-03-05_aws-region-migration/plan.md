# AWS Region Migration Plan: me-south-1 to eu-central-1

- [Context](#context)
- [Decisions](#decisions)
- [Complete "me-south-1" Reference Inventory](#complete-me-south-1-reference-inventory)
  - [Category 1: Terraform Files](#category-1-terraform-files)
  - [Category 2: CDK env-var JSON Files (~40 files)](#category-2-cdk-env-var-json-files-40-files)
  - [Category 3: aws-lambda-tools-defaults.json (42 files)](#category-3-aws-lambda-tools-defaultsjson-42-files)
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
  - [Repositories Requiring Branch `hotfix/region-migration-eu-central-1`](#repositories-requiring-branch-hotfixregion-migration-eu-central-1)
  - [Task 1: Update Terraform Region References](#task-1-update-terraform-region-references)
  - [Task 2: EKS Deprecation in terraform-prod](#task-2-eks-deprecation-in-terraform-prod)
  - [Task 3: EKS Deprecation Cleanup in terraform-dev](#task-3-eks-deprecation-cleanup-in-terraform-dev)
  - [Task 4: Update CDK env-var JSON Files (STORAGE\_REGION)](#task-4-update-cdk-env-var-json-files-storage_region)
  - [Task 5: Update aws-lambda-tools-defaults.json](#task-5-update-aws-lambda-tools-defaultsjson)
  - [Task 6: Update Infrastructure C# Code](#task-6-update-infrastructure-c-code)
  - [Task 7: Update Test Files (lower priority)](#task-7-update-test-files-lower-priority)
  - [Task 8: Update ConfigMap YAML Files](#task-8-update-configmap-yaml-files)
  - [Task 9: Update Mobile Scanner CI/CD](#task-9-update-mobile-scanner-cicd)
  - [Task 10: Update Dashboard CSP and .env Files](#task-10-update-dashboard-csp-and-env-files)
  - [Task 11: Delete CDK Context Caches](#task-11-delete-cdk-context-caches)
  - [Task 12: Update CI/CD Templates and ConfigMap Workflows](#task-12-update-cicd-templates-and-configmap-workflows)
  - [Task 13: Update Local Development Settings (lowest priority)](#task-13-update-local-development-settings-lowest-priority)
  - [Task 14: Security Remediation](#task-14-security-remediation)
  - [Task 15: Temporarily Exclude RDS Cluster from Terraform](#task-15-temporarily-exclude-rds-cluster-from-terraform)
  - [Task 16: Set Temporary `production-eu` Domain Mapping in CDK](#task-16-set-temporary-production-eu-domain-mapping-in-cdk)
  - [Task 17: Run Tests](#task-17-run-tests)
  - [Task 18: Verify Zero me-south-1 References](#task-18-verify-zero-me-south-1-references)
  - [Task 19: Merge and Publish `ticketing-platform-tools` NuGet Package](#task-19-merge-and-publish-ticketing-platform-tools-nuget-package)
  - [Task 20: DO NOT Merge Other Repos Yet](#task-20-do-not-merge-other-repos-yet)
- [Phase 2: Production Foundation \& Data Restore](#phase-2-production-foundation--data-restore)
  - [2.1 Service Quota Pre-Checks](#21-service-quota-pre-checks)
  - [2.2 Create Terraform State Bucket](#22-create-terraform-state-bucket)
  - [2.3 Recreate Secrets Manager Entries](#23-recreate-secrets-manager-entries)
  - [2.4 Terraform Apply (WITHOUT RDS Cluster)](#24-terraform-apply-without-rds-cluster)
  - [2.5 Populate Manual SSM Parameters](#25-populate-manual-ssm-parameters)
  - [2.5.1 Create DynamoDB Cache Table](#251-create-dynamodb-cache-table)
  - [2.6 Restore Aurora from AWS Backup](#26-restore-aurora-from-aws-backup)
  - [2.7 Restore S3 Data from AWS Backup](#27-restore-s3-data-from-aws-backup)
  - [2.8 CDK Bootstrap](#28-cdk-bootstrap)
  - [Phase 2 Verification Checklist](#phase-2-verification-checklist)
- [Phase 3: Production Services under Temporary Domain](#phase-3-production-services-under-temporary-domain)
  - [3.1 Create Temporary Route53 Hosted Zone](#31-create-temporary-route53-hosted-zone)
  - [3.2 Create ACM Certificates](#32-create-acm-certificates)
  - [3.3 Infrastructure CDK (11 Stacks — Strict Order)](#33-infrastructure-cdk-11-stacks--strict-order)
  - [3.4 Update Connection Strings \& Region-Dependent Secrets](#34-update-connection-strings--region-dependent-secrets)
  - [3.5 Per-Service CDK Deployment Matrix](#35-per-service-cdk-deployment-matrix)
  - [3.6 End-to-End Validation (Temporary Domain)](#36-end-to-end-validation-temporary-domain)
  - [Phase 3 Verification Checklist](#phase-3-verification-checklist)
- [Phase 4: DNS Cutover to Production Domain](#phase-4-dns-cutover-to-production-domain)
  - [4.1 Revert Temporary Domain Mapping in CDK](#41-revert-temporary-domain-mapping-in-cdk)
  - [4.1.1 Publish Updated `ticketing-platform-tools` NuGet Package](#411-publish-updated-ticketing-platform-tools-nuget-package)
  - [4.2 Create ACM Certificates for Real Domain](#42-create-acm-certificates-for-real-domain)
  - [4.3 Redeploy Public-Facing Stacks](#43-redeploy-public-facing-stacks)
  - [4.4 Update GitHub Secrets \& Variables](#44-update-github-secrets--variables)
  - [4.5 Merge to Production \& Deploy Frontends](#45-merge-to-production--deploy-frontends)
  - [4.6 End-to-End Validation (Production Domain)](#46-end-to-end-validation-production-domain)
  - [4.7 Post-Go-Live Monitoring (72 hours)](#47-post-go-live-monitoring-72-hours)
- [Phase 5: Dev+Sandbox Rebuild (Fresh)](#phase-5-devsandbox-rebuild-fresh)
  - [5.1 Overview](#51-overview)
  - [5.2 Foundation (Account 307824719505)](#52-foundation-account-307824719505)
  - [5.3 Services \& Validation](#53-services--validation)
- [Post-Migration Tasks](#post-migration-tasks)
  - [Temporary Domain Cleanup](#temporary-domain-cleanup)
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

**Migration order:** Production (account `660748123249`) first → validate under temporary domain → DNS cutover → Dev+Sandbox rebuild

**Migration strategy:** Greenfield infrastructure in eu-central-1 (new Terraform state, new CDK stacks), with Aurora and S3 restored from AWS Backup cross-region copies. Lambda-only deployment (EKS deprecated). Production deploys under temporary subdomain `production-eu.tickets.mdlbeast.net` for safe testing before DNS cutover.

---

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Migration order | **Production first** | Only prod has AWS Backup enabled (Aurora + S3). Dev/sandbox have no backups — must be rebuilt from scratch. Prod is the revenue-generating environment. |
| Temporary domain | **`production-eu.tickets.mdlbeast.net`** | Deploy prod under temporary subdomain for full E2E testing. Cutover to real `production.tickets.mdlbeast.net` domain only after validation. Avoids touching live DNS until ready. |
| EKS/Kubernetes | **Deprecate — Lambda-only** | Services already run as Lambda functions. EKS adds operational complexity with no unique value. |
| Self-hosted runners | **Remove — use GitHub-hosted runners** | Runners only existed for kubectl/EKS deployments. Lambda CDK deploys use `ubuntu-latest`. |
| Redis/ElastiCache | **Remove — do not recreate** | Confirmed zombie infrastructure: zero connections, code uses DynamoDB + in-memory caching instead. |
| OpenSearch/Elasticsearch | **Remove — do not recreate** | Confirmed ghost config: Serilog has no Elasticsearch sink installed. Config references exist but no data flows. |
| Data migration strategy | **Restore from AWS Backup** | me-south-1 is down; live replication impossible. Cross-region backup copies exist in eu-central-1. |
| `demo` environment | **Defer** | Not critical path. Address after prod and dev/sandbox are live. |
| XP Badges, Bandsintown, Marketing Feeds | **Exclude from migration** | Unused services due for deprecation. Do not migrate — remove from all migration tasks. |

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

All `env-var.{dev,sandbox,prod,demo}.json` files with `"STORAGE_REGION": "me-south-1"` across these services (14 total):

- `ticketing-platform-access-control/src/TP.AccessControl.Cdk/`
- `ticketing-platform-automations/src/TP.Automations.Cdk/`
- `ticketing-platform-customer-service/src/TP.Customers.Cdk/`
- `ticketing-platform-geidea/src/TP.Geidea.Cdk/`
- `ticketing-platform-integration/src/TP.Integration.Cdk/`
- `ticketing-platform-loyalty/src/TP.Loyalty.Cdk/`
- `ticketing-platform-marketplace-service/src/TP.Marketplace.Cdk/`
- `ticketing-platform-media/src/TP.Media.Cdk/`
- `ticketing-platform-pricing/src/TP.Pricing.Cdk/`
- `ticketing-platform-reporting-api/src/TP.ReportingService.Cdk/`
- `ticketing-platform-sales/src/TP.Sales.Cdk/`
- `ticketing-platform-transfer/src/TP.Transfer.Cdk/`
- `ticketing-platform-tools/Debug.Cdk/`
- `ecwid-integration/src/TP.Ecwid.Cdk/`

**Note:** `catalogue`, `organizations`, `distribution-portal`, and `inventory` do NOT have `STORAGE_REGION` in their env-var files.

**S3 bucket name variables that also need updating (not covered by bulk STORAGE_REGION script):**

| File | Variable | Old Value | New Value |
|------|----------|-----------|-----------|
| `ticketing-platform-media/src/TP.Media.Cdk/env-var.prod.json` | `MEDIA_STORAGE_BUCKET_NAME` | `ticketing-prod-media` | `ticketing-prod-media-eu` |
| `ticketing-platform-media/src/TP.Media.Cdk/env-var.prod.json` | `STORAGE_BUCKET_NAME` | `tickets-pdf-download` | `tickets-pdf-download-eu` |
| `ticketing-platform-media/src/TP.Media.Cdk/env-var.prod.json` | `STORAGE_BUCKET_NAME_PDF` | `tickets-pdf-download` | `tickets-pdf-download-eu` |
| `ticketing-platform-integration/src/TP.Integration.Cdk/env-var.prod.json` | `STORAGE_BUCKET_NAME` | `tickets-pdf-download` | `tickets-pdf-download-eu` |

**Bulk update script:**
```bash
find . -name "env-var.*.json" -not -path "*/node_modules/*" -not -path "*/.terraform/*" \
  -not -path "*/bin/*" -not -path "*/obj/*" -not -path "*/cdk.out/*" \
  -exec grep -l "me-south-1" {} \; | while read f; do
  sed -i '' 's/"STORAGE_REGION": "me-south-1"/"STORAGE_REGION": "eu-central-1"/g' "$f"
done
```

### Category 3: aws-lambda-tools-defaults.json (42 files)

Every Lambda project directory with `"region": "me-south-1"`:

1. `ticketing-platform-access-control/src/TP.AccessControl.{BackgroundJobs,Consumers}/`
2. `ticketing-platform-csv-generator/TP.CSVGenerator.Consumers/`
3. `ticketing-platform-customer-service/src/TP.Customers.{BackgroundJobs,Consumers}/`
4. `ticketing-platform-distribution-portal/src/TP.DistributionPortal.{BackgroundJobs,Consumers}/`
5. `ticketing-platform-extension-api/TP.Extensions.{BackgroundJobs,Consumers}/`
6. `ticketing-platform-extension-deployer/TP.Extensions.Deployer.Lambda/`
7. `ticketing-platform-extension-executor/TP.Extensions.Executor.Lambda/`
8. `ticketing-platform-extension-log-processor/TP.Extensions.LogsProcessor.Lambda/`
9. `ticketing-platform-gateway/src/Gateway/`
10. `ticketing-platform-geidea/src/TP.Geidea.{BackgroundJobs,Lambda.Balance}/`
11. `ticketing-platform-integration/src/TP.Integration.{BackgroundJobs,Consumers}/`
12. `ticketing-platform-inventory/src/TP.Inventory.{BackgroundJobs,Consumers}/`
13. `ticketing-platform-loyalty/src/TP.Loyalty.{BackgroundJobs,Consumers}/`
14. `ticketing-platform-marketplace-service/src/TP.Marketplace.{BackgroundJobs,Consumers}/`
15. `ticketing-platform-media/src/TP.Media.{BackgroundJobs,Consumers}/`
16. `ticketing-platform-organizations/src/Organizations/TP.Organizations.{BackgroundJobs,Consumers}/`
17. `ticketing-platform-pdf-generator/TP.PdfGenerator.Consumers/`
18. `ticketing-platform-pricing/src/TP.Pricing.Consumers/`
19. `ticketing-platform-reporting-api/src/TP.ReportingService.{BackgroundJobs,Consumers}/`
20. `ticketing-platform-sales/src/TP.Sales.{BackgroundJobs,Consumers}/`
21. `ticketing-platform-transfer/src/TP.Transfer.{BackgroundJobs,Consumers}/`
22. `ecwid-integration/src/TP.Ecwid.{BackgroundJobs,Lambda.PaymentCallback,Lambda.PaymentCreate,Lambda.WebHooks.Anchanto,Lambda.WebHooks.Ecwid}/`

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
| `deploy.yml:26` | `aws ecr get-login-password --region me-south-1 \| helm registry login ... 660748123249.dkr.ecr.me-south-1.amazonaws.com` |
| `deploy.yml:28` | `helm push ... oci://660748123249.dkr.ecr.me-south-1.amazonaws.com/` |
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
| `tickets-pdf-download` | `tickets-pdf-download-eu` | Prod PDF download (CloudFront origin) |
| `pdf-tickets-download` | `pdf-tickets-download-eu` | Dev PDF download |
| `ticketing-dev-csv-reports` | `ticketing-dev-csv-reports-eu` | Dev CSV reports |
| `ticketing-sandbox-csv-reports` | `ticketing-sandbox-csv-reports-eu` | Sandbox CSV reports |
| `ticketing-csv-reports` | `ticketing-csv-reports-eu` | Prod CSV reports |
| `ticketing-{env}-media` | `ticketing-{env}-media-eu` | Media uploads |
| `ticketing-{env}-extended-message` | `ticketing-{env}-extended-message-eu` | Large event payloads (CDK code change required) |
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

### Repositories Requiring Branch `hotfix/region-migration-eu-central-1`

34 repositories require code changes. Create the branch from each repo's **current branch** (typically `master` for production services, but may vary):

```bash
# Script to create branches in all affected repos
# Branches from the current HEAD of whatever branch is checked out (usually master/production)
for repo in \
  ticketing-platform-access-control \
  ticketing-platform-automations \
  ticketing-platform-catalogue \
  ticketing-platform-configmap-dev \
  ticketing-platform-configmap-prod \
  ticketing-platform-configmap-sandbox \
  ticketing-platform-csv-generator \
  ticketing-platform-customer-service \
  ticketing-platform-dashboard \
  ticketing-platform-distribution-portal \
  ticketing-platform-extension-api \
  ticketing-platform-extension-deployer \
  ticketing-platform-extension-executor \
  ticketing-platform-extension-log-processor \
  ticketing-platform-gateway \
  ticketing-platform-geidea \
  ticketing-platform-infrastructure \
  ticketing-platform-integration \
  ticketing-platform-inventory \
  ticketing-platform-loyalty \
  ticketing-platform-marketplace-service \
  ticketing-platform-media \
  ticketing-platform-mobile-scanner \
  ticketing-platform-organizations \
  ticketing-platform-pdf-generator \
  ticketing-platform-pricing \
  ticketing-platform-reporting-api \
  ticketing-platform-sales \
  ticketing-platform-templates-ci-cd \
  ticketing-platform-terraform-dev \
  ticketing-platform-terraform-prod \
  ticketing-platform-tools \
  ticketing-platform-transfer \
  ecwid-integration; do
  (cd "$repo" && git pull && git checkout -b hotfix/region-migration-eu-central-1)
done
```

**Repos NOT changed (no branch needed):**
- `ticketing-platform-distribution-portal-frontend` — deploys via Vercel, no region references
- `ticketing-platform-mobile-libraries` — shared native modules, no region references
- `ticketing-platform-shared` — no region references
- `ticketing-work-smart-scripts` — not a service
- `ticketing-platform-xp-badges` — excluded from migration (deprecated)
- `ticketing-platform-bandsintown-integration` — excluded from migration (deprecated)
- `ticketing-platform-marketing-feeds` — excluded from migration (deprecated)

---

### Task 1: Update Terraform Region References

**Repos:** `ticketing-platform-terraform-prod`, `ticketing-platform-terraform-dev`

| File | What to Change |
|------|---------------|
| `ticketing-platform-terraform-prod/prod/main.tf:7` | Backend bucket → `ticketing-terraform-prod-eu` |
| `ticketing-platform-terraform-prod/prod/main.tf:9,16` | Backend region + provider region → `eu-central-1` |
| `ticketing-platform-terraform-prod/prod/variables.tf:42,47,52` | AZ defaults → `eu-central-1a/b/c` |
| `ticketing-platform-terraform-prod/prod/variables.tf:65` | AMI ID → eu-central-1 equivalent |
| `ticketing-platform-terraform-prod/prod/rds.tf:200` | `availability_zones` → `["eu-central-1a","eu-central-1b","eu-central-1c"]` |
| `ticketing-platform-terraform-prod/prod/secretmanager.tf:4` | Hardcoded ARN → name-based lookup |
| `ticketing-platform-terraform-prod/prod/s3.tf` | Rename `ticketing-terraform-github` bucket to `ticketing-terraform-github-eu` |
| `ticketing-platform-terraform-dev/dev/main.tf:5` | Backend bucket → `ticketing-terraform-dev-eu` |
| `ticketing-platform-terraform-dev/dev/main.tf:7,14` | Backend region + provider region → `eu-central-1` |
| `ticketing-platform-terraform-dev/dev/variables.tf:42,47,52` | AZ defaults → `eu-central-1a/b/c` |
| `ticketing-platform-terraform-dev/dev/variables.tf:64` | AMI ID → eu-central-1 equivalent |
| `ticketing-platform-terraform-dev/dev/rds.tf:162` | `availability_zones` → `["eu-central-1a","eu-central-1b","eu-central-1c"]` |
| `ticketing-platform-terraform-dev/dev/secretmanager.tf:2` | Hardcoded ARN → name-based lookup |

---

### Task 2: EKS Deprecation in terraform-prod

**Repo:** `ticketing-platform-terraform-prod`

Following the pattern from terraform-dev commit `d01f7df` ("chore: attempt to disable eks"):

**Files to DELETE entirely:**

| File | Resources Removed |
|------|-------------------|
| `prod/opensearch.tf` | 3 subnets (`opensearch-1a/1b/1c-prod`), 1 security group (`opensearchprod`) |
| `prod/redis.tf` | 2 subnets (`redis-1a/1b-prod`), 1 security group (`redisprod`) |
| `prod/waf.tf` | WAF ACL, IP sets, rules (all reference me-south-1 ALB ARNs) |
| `prod/msk.tf` | MSK subnets + security group (marked `/// probably delete`) |
| `prod/runner.tf` | 2 subnets, 2 EC2 instances (`runner-1a/1b`), 1 security group |
| `prod/ecr.tf` | 2 ECR repos (`ticketing-platform-ecr`, `helm-chart`) |

**Files to MODIFY:**

| File | Change |
|------|--------|
| `prod/eks-subnet.tf` | **RENAME** → `prod/lambda-subnet.tf`. Keep 3 subnets + route table associations; update resource names and tags from `eks-subnet-*` to `lambda-subnet-*` |
| `prod/user-cicd.tf` | Remove `aws_iam_policy.ci-cd-eks` resource and its attachment. Keep CICD user (needed for CDK deploys) |
| `prod/iam-s3-sqs.tf` | Remove `aws_iam_policy.s3-sqs-eks` — was for EKS service account S3/SQS access |
| `prod/rds.tf:57,64,71` | Remove 3 security group ingress rules referencing `aws_subnet.eks-1a/1b/1c-prod.cidr_block` |
| `prod/group.tf:33-35` | Remove `techlead-redis` IAM group policy attachment |
| `prod/group.tf:81-84` | Remove `developer-opensearch` IAM group policy attachment |
| `prod/secretmanager.tf:19-27` | Remove `output.terraform_opensearch` and `output.terraform_redis` |

---

### Task 3: EKS Deprecation Cleanup in terraform-dev

**Repo:** `ticketing-platform-terraform-dev`

| File | Change |
|------|--------|
| `dev/iam-eks.tf` | **DELETE** entirely (orphaned IAM policy from incomplete EKS removal) |
| `dev/iam-s3-sqs.tf` | Remove `s3-sqs-eks` policy resource and data source |
| `dev/rds.tf:33,47,54` | Remove security group ingress rules referencing `eks-*` subnet CIDRs |
| `dev/nat.tf:8,75,126` | Remove `"kubernetes.io/role/elb" = "1"` tags from all 3 NAT subnets |

---

### Task 4: Update CDK env-var JSON Files (STORAGE_REGION)

**Repos (14):** `ticketing-platform-access-control`, `ticketing-platform-automations`, `ticketing-platform-customer-service`, `ticketing-platform-geidea`, `ticketing-platform-integration`, `ticketing-platform-loyalty`, `ticketing-platform-marketplace-service`, `ticketing-platform-media`, `ticketing-platform-pricing`, `ticketing-platform-reporting-api`, `ticketing-platform-sales`, `ticketing-platform-transfer`, `ticketing-platform-tools`, `ecwid-integration`

**Bulk script** (run from monorepo root):
```bash
find . -name "env-var.*.json" -not -path "*/node_modules/*" -not -path "*/.terraform/*" \
  -not -path "*/bin/*" -not -path "*/obj/*" -not -path "*/cdk.out/*" \
  -exec grep -l "me-south-1" {} \; | while read f; do
  sed -i '' 's/"STORAGE_REGION": "me-south-1"/"STORAGE_REGION": "eu-central-1"/g' "$f"
done
```

**Manual bucket name updates** (NOT covered by the bulk script above):

| File | Variable | Old Value | New Value |
|------|----------|-----------|-----------|
| `ticketing-platform-media/src/TP.Media.Cdk/env-var.prod.json` | `MEDIA_STORAGE_BUCKET_NAME` | `ticketing-prod-media` | `ticketing-prod-media-eu` |
| `ticketing-platform-media/src/TP.Media.Cdk/env-var.prod.json` | `STORAGE_BUCKET_NAME` | `tickets-pdf-download` | `tickets-pdf-download-eu` |
| `ticketing-platform-media/src/TP.Media.Cdk/env-var.prod.json` | `STORAGE_BUCKET_NAME_PDF` | `tickets-pdf-download` | `tickets-pdf-download-eu` |
| `ticketing-platform-integration/src/TP.Integration.Cdk/env-var.prod.json` | `STORAGE_BUCKET_NAME` | `tickets-pdf-download` | `tickets-pdf-download-eu` |

---

### Task 5: Update aws-lambda-tools-defaults.json

**Repos (22):** `ticketing-platform-access-control`, `ticketing-platform-csv-generator`, `ticketing-platform-customer-service`, `ticketing-platform-distribution-portal`, `ticketing-platform-extension-api`, `ticketing-platform-extension-deployer`, `ticketing-platform-extension-executor`, `ticketing-platform-extension-log-processor`, `ticketing-platform-gateway`, `ticketing-platform-geidea`, `ticketing-platform-integration`, `ticketing-platform-inventory`, `ticketing-platform-loyalty`, `ticketing-platform-marketplace-service`, `ticketing-platform-media`, `ticketing-platform-organizations`, `ticketing-platform-pdf-generator`, `ticketing-platform-pricing`, `ticketing-platform-reporting-api`, `ticketing-platform-sales`, `ticketing-platform-transfer`, `ecwid-integration`

**Bulk script** (run from monorepo root):
```bash
find . -name "aws-lambda-tools-defaults.json" \
  -not -path "*/node_modules/*" -not -path "*/.terraform/*" \
  -not -path "*/bin/*" -not -path "*/obj/*" -not -path "*/cdk.out/*" \
  -exec grep -l "me-south-1" {} \; | while read f; do
  sed -i '' 's/"region": "me-south-1"/"region": "eu-central-1"/g' "$f"
done

# Fix PDF generator anomaly — has eu-west-1 instead of me-south-1 (skipped by bulk script above)
sed -i '' 's/"region": "eu-west-1"/"region": "eu-central-1"/g' \
  ticketing-platform-pdf-generator/TP.PdfGenerator.Consumers/aws-lambda-tools-defaults.json
```

---

### Task 6: Update Infrastructure C# Code

**Repo:** `ticketing-platform-infrastructure`

| File | Line | Change |
|------|------|--------|
| `TP.Infrastructure.SlackNotifier/Services/EnvironmentService.cs` | 24 | `?? "me-south-1"` → `?? "eu-central-1"` |
| `TP.Infrastructure.SlackNotifier/Services/XRayInsightSlackService.cs` | 58 | `?? "me-south-1"` → `?? "eu-central-1"` |
| `TP.Infrastructure.Cdk/Stacks/ExtendedMessageS3BucketStack.cs` | 17 | `BucketName = $"ticketing-{env}-extended-message"` → `BucketName = $"ticketing-{env}-extended-message-eu"` |

**Why the ExtendedMessage bucket name change:** S3 bucket names are globally unique. The me-south-1 bucket `ticketing-prod-extended-message` still exists, so CDK would fail trying to create a bucket with the same name in eu-central-1. Adding the `-eu` suffix avoids the collision.

**Runtime references that also need updating** (in `ticketing-platform-tools` — published via NuGet, consumed by all services):

| File | Line | Change |
|------|------|--------|
| `TP.Tools.MessageBroker/Implementations/SqsQueueService.cs` | 190 | `$"ticketing-{_envName}-extended-message"` → `$"ticketing-{_envName}-extended-message-eu"` |
| `TP.Tools.MessageBroker/Implementations/MessageProducer.cs` | 210 | `$"ticketing-{_envName}-extended-message"` → `$"ticketing-{_envName}-extended-message-eu"` |

The IAM policy in `LambdaS3ExtendedMessagePolicyStatement.cs:26-27` uses wildcard `ticketing-*-extended-message` which does **NOT** match `ticketing-prod-extended-message-eu` (the `-eu` comes after the literal `message` ending). This must also be updated:

| File | Line | Change |
|------|------|--------|
| `TP.Tools.Infrastructure/Consumers/Policies/LambdaS3ExtendedMessagePolicyStatement.cs` | 26 | `ticketing-*-extended-message` → `ticketing-*-extended-message-eu` |
| Same file | 27 | `ticketing-*-extended-message/*` → `ticketing-*-extended-message-eu/*` |

**Note:** These changes are in `ticketing-platform-tools` and will be published as part of Task 19 (NuGet publish). All services pick up the new bucket name via the updated NuGet package.

---

### Task 7: Update Test Files (lower priority)

**Repos (6):** `ticketing-platform-media`, `ticketing-platform-catalogue`, `ticketing-platform-organizations`, `ticketing-platform-inventory`, `ticketing-platform-pricing`, `ticketing-platform-infrastructure`, `ticketing-platform-tools`, `ticketing-platform-integration`

| File | Lines |
|------|-------|
| `ticketing-platform-media/src/Tests/TP.Media.IntegrationTests/ApplicationFactory.cs` | 28-29 |
| `ticketing-platform-catalogue/src/Tests/TP.Catalogue.IntegrationTests/ApplicationFactory.cs` | 39-40 |
| `ticketing-platform-organizations/src/Organizations/Tests/TP.Organizations.IntegrationTests/ApplicationFactory.cs` | 37-38 |
| `ticketing-platform-inventory/src/Tests/TP.Inventory.IntegrationTests/ApplicationFactory.cs` | 58-59 |
| `ticketing-platform-pricing/src/Tests/TP.Pricing.IntegrationTests/ApplicationFactory.cs` | 116-117 |
| `ticketing-platform-infrastructure/TP.Infrastructure.Tests/SlackNotifier/` | Multiple test files |
| `ticketing-platform-tools/UnitTests/Infrastructure/Consumers/LambdaUtilitiesTests.cs` | 252 |
| `ticketing-platform-integration/src/TP.Integration.IntegrationTests/.../WhatsAppServiceTests.cs` | 139 |

---

### Task 8: Update ConfigMap YAML Files

**Repos:** `ticketing-platform-configmap-dev`, `ticketing-platform-configmap-sandbox`, `ticketing-platform-configmap-prod`

**Dev — `ticketing-platform-configmap-dev`:**
- `manifests/{access-control,integration,media,reporting,sales,transfer}-dev.yml` — `STORAGE_REGION: me-south-1` → `eu-central-1`
- `secretstore.yml` — `region: me-south-1` → `eu-central-1`

**Sandbox — `ticketing-platform-configmap-sandbox`:**
- `manifests/{integration,media,reporting,sales,transfer}-sandbox.yml` — `STORAGE_REGION: me-south-1` → `eu-central-1`
- `secretstore.yml` — `region: me-south-1` → `eu-central-1`

**Prod — `ticketing-platform-configmap-prod`:**
- `manifests-new/{integration,media,reporting,sales,transfer}.yml` — `STORAGE_REGION: me-south-1` → `eu-central-1`
- `manifests-new/sales.yml` — also has `Logging__Elasticsearch__Uri` with me-south-1 OpenSearch endpoint (remove — see Task 12)

**Note:** With EKS deprecated, these ConfigMap repos become archival. Update for correctness, but these manifests will no longer be deployed.

---

### Task 9: Update Mobile Scanner CI/CD

**Repo:** `ticketing-platform-mobile-scanner`

| File | Lines | Change |
|------|-------|--------|
| `.github/workflows/release-build.yml` | 172 | `s3.me-south-1.amazonaws.com` → `s3.eu-central-1.amazonaws.com` |
| `.github/workflows/release-build.yml` | 200 | `AWS_DEFAULT_REGION: me-south-1` → `AWS_DEFAULT_REGION: eu-central-1` |
| `.github/workflows/release-build.yml` | 208 | `AWS_DEFAULT_REGION: me-south-1` → `AWS_DEFAULT_REGION: eu-central-1` |

---

### Task 10: Update Dashboard CSP and .env Files

**Repo:** `ticketing-platform-dashboard`

**`vercel.json:24`** — 6 S3 URLs in CSP `connect-src` (update both region AND bucket names):
- `dev-pdf-tickets.s3.me-south-1.amazonaws.com` → `dev-pdf-tickets-eu.s3.eu-central-1.amazonaws.com`
- `tickets-pdf-download.s3.me-south-1.amazonaws.com` → `tickets-pdf-download-eu.s3.eu-central-1.amazonaws.com`
- `sandbox-pdf-tickets.s3.me-south-1.amazonaws.com` → `sandbox-pdf-tickets-eu.s3.eu-central-1.amazonaws.com`
- `ticketing-sandbox-media.s3.me-south-1.amazonaws.com` → `ticketing-sandbox-media-eu.s3.eu-central-1.amazonaws.com`
- `ticketing-dev-media.s3.me-south-1.amazonaws.com` → `ticketing-dev-media-eu.s3.eu-central-1.amazonaws.com`
- `ticketing-prod-media.s3.me-south-1.amazonaws.com` → `ticketing-prod-media-eu.s3.eu-central-1.amazonaws.com`

**`.env:9`** — `MEDIA_HOST` with me-south-1 API Gateway URL → update after new endpoints exist
**`.env.sandbox:9`** — same
**`.env.development:10,28`** — API Gateway URLs → update after new endpoints exist

---

### Task 11: Delete CDK Context Caches

**Repos:** `ticketing-platform-infrastructure`, `ticketing-platform-gateway`, `ticketing-platform-media`

Delete these auto-generated cache files (they contain me-south-1 VPC/subnet lookups and regenerate on `cdk synth`):
- `ticketing-platform-infrastructure/TP.Infrastructure.Cdk/cdk.context.json`
- `ticketing-platform-gateway/src/Gateway.Cdk/cdk.context.json`
- `ticketing-platform-media/src/TP.Media.Cdk/cdk.context.json`

---

### Task 12: Update CI/CD Templates and ConfigMap Workflows

**Repo (templates):** `ticketing-platform-templates-ci-cd`

| Action | Files |
|--------|-------|
| Update or remove (EKS dead code) | `.github/workflows/deploy.yml` — 8 hardcoded me-south-1 references in ECR/Helm commands |
| Update or remove (EKS dead code) | `.github/workflows/k8s.yml` — 2 hardcoded me-south-1 references |

**Repos (ConfigMap CI/CD):** `ticketing-platform-configmap-dev`, `ticketing-platform-configmap-sandbox`, `ticketing-platform-configmap-prod`

| Action | Files |
|--------|-------|
| Remove or disable | `ticketing-platform-configmap-dev/.github/workflows/ci.yml` |
| Remove or disable | `ticketing-platform-configmap-sandbox/.github/workflows/ci.yml` |
| Remove or disable | `ticketing-platform-configmap-prod/.github/workflows/ci.yml` |
| Remove or disable | `ticketing-platform-configmap-prod/.github/workflows/disaster.yml` |

---

### Task 13: Update Local Development Settings (lowest priority)

**Repos:** `ticketing-platform-media`, `ticketing-platform-pricing`, `ticketing-platform-extension-api`, `ticketing-platform-distribution-portal`, `ticketing-platform-gateway`, `ticketing-platform-sales`

These contain me-south-1 RDS hosts, SQS URLs, OpenSearch URIs — update after new endpoints exist in eu-central-1:
- `ticketing-platform-media/src/TP.Media.API/appsettings.Development.json`
- `ticketing-platform-pricing/src/TP.Pricing.API/Properties/launchSettings.json`
- `ticketing-platform-extension-api/TP.Extensions.API/Properties/launchSettings.json`
- `ticketing-platform-distribution-portal/src/TP.DistributionPortal.API/Properties/launchSettings.json`
- `ticketing-platform-gateway/src/Gateway/Properties/launchSettings.json`
- `ticketing-platform-sales/src/TP.Sales.API/Properties/launchSettings.json`

---

### Task 14: Security Remediation

**Repos:** `ticketing-platform-terraform-dev`, `ticketing-platform-terraform-prod`, `ticketing-platform-configmap-prod`

| Repo | File | Change |
|------|------|--------|
| `ticketing-platform-terraform-dev` | `.gitignore` | Add `*.tfstate` and `*.tfstate.backup` |
| `ticketing-platform-terraform-prod` | `.gitignore` | Add `*.tfstate` and `*.tfstate.backup` |
| `ticketing-platform-terraform-dev` | `dev/s3.tf:246` | Fix lifecycle config bucket reference from sandbox to dev |
| `ticketing-platform-configmap-prod` | `manifests-new/sales.yml` | Remove plaintext Elasticsearch credentials |

**Deferred to Phase 4:** Prod plaintext creds in `ticketing-platform-terraform-prod/prod/variables.tf:97,117,125` (opensearch_pass, rds_pass, rds_pass_inventory) — move to Secrets Manager.

---

### Task 15: Temporarily Exclude RDS Cluster from Terraform

**Repos:** `ticketing-platform-terraform-dev`, `ticketing-platform-terraform-prod`

Comment out `aws_rds_cluster` and `aws_rds_cluster_instance` resource blocks to prevent Terraform from creating an empty database cluster. AWS Backup restore creates a *separate* cluster (you cannot restore into an existing cluster).

| File | Action |
|------|--------|
| `ticketing-platform-terraform-prod/prod/rds.tf` | Comment out `aws_rds_cluster "ticketing"` + `aws_rds_cluster_instance "ticketing"` blocks. **Keep** `aws_db_subnet_group`, `aws_security_group`, and `aws_security_group_rule` resources (needed for backup restore) |
| `ticketing-platform-terraform-dev/dev/rds.tf` | Same — comment out cluster + instance blocks, keep subnet group + security group |

**Why:** `terraform apply` would create an empty RDS cluster. After backup restore in Phase 2.6, we `terraform import` the restored cluster, then uncomment the resources.

---

### Task 16: Set Temporary `production-eu` Domain Mapping in CDK

**Repos:** `ticketing-platform-tools`, `ticketing-platform-gateway`, `ticketing-platform-infrastructure`, `ticketing-platform-geidea`, `ecwid-integration`

Change `"production"` to `"production-eu"` in the env-to-domain mapping in these 7 files:

| File | Current | Change to |
|------|---------|-----------|
| `ticketing-platform-tools/TP.Tools.Infrastructure/Helpers/ServerlessApiStackHelper.cs:47` | `env == "prod" ? "production" : env` | `env == "prod" ? "production-eu" : env` |
| `ticketing-platform-gateway/src/Gateway.Cdk/Stacks/GatewayStack.cs:32` | `env == "prod" ? "production" : env` | `env == "prod" ? "production-eu" : env` |
| `ticketing-platform-gateway/src/Gateway.Cdk/Stacks/GatewayStack.cs:107` | `env == "prod" ? "production" : env` | `env == "prod" ? "production-eu" : env` |
| `ticketing-platform-infrastructure/TP.Infrastructure.Cdk/Stacks/InternalHostedZoneStack.cs:15` | `env == "prod" ? "production" : env` | `env == "prod" ? "production-eu" : env` |
| `ticketing-platform-infrastructure/TP.Infrastructure.Cdk/Stacks/InternalCertificateStack.cs:15` | `env == "prod" ? "production" : env` | `env == "prod" ? "production-eu" : env` |
| `ticketing-platform-geidea/src/TP.Geidea.Cdk/Stacks/ApiStack.cs:32` | `env == "prod" ? "production" : env` | `env == "prod" ? "production-eu" : env` |
| `ecwid-integration/src/TP.Ecwid.Cdk/Stacks/ApiStack.cs:32` | `env == "prod" ? "production" : env` | `env == "prod" ? "production-eu" : env` |

**Note:** GatewayStack has two occurrences of the domain conditional (lines 32 and 107). Line 107 is in `CreateCustomDomain()` where it derives the SSM path for the certificate ARN. Both must be updated.

**Note:** `xp-badges`, `bandsintown-integration`, and `marketing-feeds` are excluded from migration (deprecated services).

**What this changes:** Only the domain names used for API Gateway custom domains, Route53 records, and ACM certificates. All other identifiers (secret paths `/prod/*`, SSM paths `/prod/tp/*`, stack names, Lambda names, queue names) remain unchanged.

**Important:** GatewayStack uses the **mapped** env name (e.g., `production-eu`) for its SSM certificate path: `/{envName}/tp/DomainCertificateArn`. This means the Gateway certificate SSM parameter must be stored at `/production-eu/tp/DomainCertificateArn` (not `/prod/tp/...`). All other services (Geidea, Ecwid) use the raw env for their SSM paths (`/prod/tp/{service}/DomainCertificateArn`).

**What this produces:**
- `api.production-eu.tickets.mdlbeast.net` (gateway)
- `geidea.production-eu.tickets.mdlbeast.net` (geidea)
- `ecwid.production-eu.tickets.mdlbeast.net` (ecwid — via `ecwid-integration`)
- `*.internal.production-eu.tickets.mdlbeast.net` (all internal services)

---

### Task 17: Run Tests

Run all tests to verify code changes don't break anything:
```bash
# .NET services (in each repo with test projects)
dotnet test
# Dashboard
cd ticketing-platform-dashboard && npm run test && npm run typescript
```

---

### Task 18: Verify Zero me-south-1 References

```bash
grep -r "me-south-1" --include="*.tf" --include="*.cs" --include="*.json" \
  --include="*.yml" --include="*.yaml" \
  --exclude-dir={.terraform,node_modules,bin,obj,cdk.out,.git,helm} \
  | grep -v "configmap-" | grep -v "README" | grep -v ".idea/"
```

Expected: zero results in deployable code. ConfigMap files (archival), README docs, and IDE workspace files are excluded.

---

### Task 19: Merge and Publish `ticketing-platform-tools` NuGet Package

**Repo:** `ticketing-platform-tools`

**Why this must happen before any CDK deploy:** All backend services consume `TP.Tools.Infrastructure` as a NuGet package from GitHub Packages (not a local project reference). The domain mapping change in `ServerlessApiStackHelper.cs` (Task 16) must be published as a new NuGet version BEFORE services can use it. Without this, CDK deploys in Phase 3 would use the OLD `ServerlessApiStackHelper` — creating domains under `production.tickets.mdlbeast.net` instead of the temporary `production-eu.tickets.mdlbeast.net`.

**Steps:**

```bash
cd ticketing-platform-tools

# 1. Merge hotfix branch to master (triggers nuget.yml publish workflow)
git checkout master && git pull
git merge hotfix/region-migration-eu-central-1
git push origin master

# 2. Wait for GitHub Actions nuget.yml to complete
#    Monitor: https://github.com/mdlbeasts/ticketing-platform-tools/actions/workflows/nuget.yml
#    This publishes ALL 12 TP.Tools.* packages with the same version 1.0.{run_number}:
#      TP.Tools.BackgroundJobs, TP.Tools.DataAccessLayer, TP.Tools.Helpers,
#      TP.Tools.Infrastructure, TP.Tools.Libs.Entities, TP.Tools.Logger,
#      TP.Tools.MessageBroker, TP.Tools.PhoneNumbers, TP.Tools.RestVersioning,
#      TP.Tools.SharedEntities, TP.Tools.Swagger, TP.Tools.Validator
#    Note the new version number from the workflow output.
#
#    Migration changes span TP.Tools.Infrastructure (domain mapping, IAM policy)
#    AND TP.Tools.MessageBroker (extended-message bucket name). Per standard practice,
#    all TP.Tools.* references are bumped together to keep shared libraries in sync.

# 3. Update ALL TP.Tools.* package versions in service .csproj files
#    Run from monorepo root:
NEW_VERSION="1.0.XXXX"  # Replace with actual version from step 2
find . -name "*.csproj" -not -path "*/ticketing-platform-tools/*" \
  -not -path "*/bin/*" -not -path "*/obj/*" \
  -exec grep -l "TP\.Tools\." {} \; | while read f; do
  sed -i '' "s/\"TP\.Tools\.\([^\"]*\)\" Version=\"[^\"]*\"/\"TP.Tools.\1\" Version=\"$NEW_VERSION\"/g" "$f"
  echo "Updated: $f"
done

# 4. Commit the version bump in each affected service repo
for repo in \
  ticketing-platform-access-control ticketing-platform-automations \
  ticketing-platform-catalogue ticketing-platform-csv-generator \
  ticketing-platform-customer-service ticketing-platform-distribution-portal \
  ticketing-platform-extension-api ticketing-platform-extension-deployer \
  ticketing-platform-extension-executor ticketing-platform-extension-log-processor \
  ticketing-platform-gateway ticketing-platform-geidea \
  ticketing-platform-infrastructure ticketing-platform-integration \
  ticketing-platform-inventory ticketing-platform-loyalty \
  ticketing-platform-marketplace-service ticketing-platform-media \
  ticketing-platform-organizations ticketing-platform-pdf-generator \
  ticketing-platform-pricing ticketing-platform-reporting-api \
  ticketing-platform-sales ticketing-platform-transfer \
  ecwid-integration; do
  (cd "$repo" && git add -A && git diff --cached --quiet || \
    git commit -m "chore: bump TP.Tools.* to $NEW_VERSION for region migration")
done

# 5. Verify: build one service to confirm NuGet restore works
cd ticketing-platform-sales/src/TP.Sales.Cdk && dotnet build
```

**This is the ONLY repo merged to `master` before Phase 3.** All other repos stay on `hotfix/region-migration-eu-central-1`.

---

### Task 20: DO NOT Merge Other Repos Yet

Keep all repos (except `ticketing-platform-tools`, already merged) on `hotfix/region-migration-eu-central-1` branches until Phase 3 validation passes. Merging triggers CI/CD deployments — infrastructure must be ready first.

---

## Phase 2: Production Foundation & Data Restore

**Duration:** 2-3 days | **Risk:** HIGH | **Account:** `660748123249`

**AWS CLI profile for all commands in this phase:**
```bash
export AWS_PROFILE=AdministratorAccess-660748123249
export AWS_REGION=eu-central-1
```

### 2.1 Service Quota Pre-Checks

```bash
aws service-quotas list-service-quotas --service-code lambda \
  --profile AdministratorAccess-660748123249 --region eu-central-1 \
  --query 'Quotas[?QuotaName==`Concurrent executions`].Value'
aws service-quotas list-service-quotas --service-code vpc \
  --profile AdministratorAccess-660748123249 --region eu-central-1 \
  --query 'Quotas[?contains(QuotaName,`NAT`)].{Name:QuotaName,Value:Value}'
aws service-quotas list-service-quotas --service-code rds \
  --profile AdministratorAccess-660748123249 --region eu-central-1 \
  --query 'Quotas[?contains(QuotaName,`cluster`)].{Name:QuotaName,Value:Value}'

# Request increases if needed before proceeding
```

### 2.2 Create Terraform State Bucket

```bash
aws s3 mb s3://ticketing-terraform-prod-eu \
  --profile AdministratorAccess-660748123249 --region eu-central-1
aws s3api put-bucket-versioning --bucket ticketing-terraform-prod-eu \
  --versioning-configuration Status=Enabled \
  --profile AdministratorAccess-660748123249 --region eu-central-1
aws s3api put-bucket-encryption --bucket ticketing-terraform-prod-eu \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  --profile AdministratorAccess-660748123249 --region eu-central-1
```

### 2.3 Recreate Secrets Manager Entries

Since me-south-1 is down, secrets cannot be replicated. Local backups exist in `backup-secrets/` — **all 24 production secrets have been successfully backed up** (updated 2026-03-25; previous version reported 6 failures). Each service loads its secret at Lambda cold-start via `SecretManagerHelper.LoadSecretsToEnvironmentAsync("/{env}/{service}")` (ecwid-integration uses a custom `GetSecretValueAsync` call instead).

**Detailed reconstruction reference:** `secrets-reconstruction.md` — per-key breakdown with sources for every secret.

**Secret backup status and required actions:**

| Secret Path | Backup Status | Keys | Action |
|-------------|--------------|------|--------|
| `/{env}/access-control` | OK | 11 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds; **preserve `ENCRYPTION_KEY`/`ENCRYPTION_IV`**; delete Elasticsearch keys |
| `/{env}/catalogue` | OK | 8 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds; delete Elasticsearch keys |
| `/{env}/customers` | OK | 7 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds; add `HyperPay_BaseUrl` (missing from backup) |
| `/{env}/dp` | OK | 7 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds; delete Elasticsearch keys |
| `/{env}/ecwid` | **PARTIAL** | 9 | Copy backed-up keys — **must add:** `CONNECTION_STRINGS`, `ECWID_STORE_ID`, `ECWID_BASE_ADDRESS`, `ANCHANTO_STORE_ID`, `ANCHANTO_MARKETPLACE_CODE`, `ANCHANTO_BASE_ADDRESS`, `ANCHANTO_BASE_CATEGORY_CODE`, `ANCHANTO_BASE_CATEGORY_NAME` (from vendor dashboards) |
| `terraform` | OK | 3 | Copy `rds` key as-is; omit `redis`/`opensearch` (deprecated) |
| `/{env}/automations` | OK | 8 | Copy from backup — update `S3Region`, `S3Bucket`, RDS hosts in config JSONs |
| `/{env}/geidea` | OK | 4 | Copy from backup — update `CONNECTION_STRINGS` RDS host |
| `/{env}/media` | OK | 15 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds, `SQS_QUEUE_URL`, `PDF_FUNCTION_URL`; delete Elasticsearch keys |
| `/{env}/organizations` | OK | 13 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds; delete Elasticsearch keys |
| `/{env}/reporting` | OK | 8 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds; delete Elasticsearch keys |
| `/{env}/transfer` | OK | 9 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds; **preserve `SHARED_CODE_SECRET_KEY`**; delete Elasticsearch keys |
| `devops` | OK | 1 | Copy as-is (SSH public key for EC2 key pairs) |
| `/{env}/extensions` | OK | 9 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds, SQS queue URLs; delete Elasticsearch keys |
| `/{env}/gateway` | OK | 10 | Copy from backup — update IAM creds; delete Elasticsearch keys |
| `/{env}/integration` | OK | 22 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds, `KMS_KEY_ID`; delete Elasticsearch keys |
| `/{env}/inventory` | OK | 9 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds; delete Elasticsearch keys |
| `/{env}/loyalty` | OK | 8 | Copy from backup — update `CONNECTION_STRINGS`; delete Elasticsearch keys |
| `/{env}/marketplace` | OK | 5 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds |
| `/{env}/pricing` | OK | 12 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds; delete Redis/Elasticsearch keys |
| `/{env}/sales` | OK | 28 | Copy from backup — update `CONNECTION_STRINGS`, IAM creds; delete Elasticsearch keys |
| `/{env}/xp-badges` | OK | 1 | Copy as-is (`GOOGLE_SHEETS_PRIVATE_KEY` — region-independent). Excluded from migration. |
| `/rds/ticketing-cluster` | OK | 6 | Update `host` to new Aurora endpoint |
| `prod/data` | OK | 12 | Copy as-is (Google service account — region-independent) |

**Keys that MUST change** in backed-up secrets (new region = new resources):
- `CONNECTION_STRINGS` / `CONNECTION_STRINGS_Sales` — new RDS Proxy endpoint (set in Phase 3.3)
- `SQS_QUEUE_URL` / `EXTENSION_DEPLOYER_SQS_QUEUE_URL` / `EXTENSION_EXECUTOR_SQS_QUEUE_URL` — new queue URLs (set in Phase 3.3)
- `KMS_KEY_ID` — new KMS key ARN from Terraform output
- `AWS_ACCESS_KEY` / `AWS_ACCESS_SECRET` / `STORAGE_ACCESS_KEY` / `STORAGE_SECRET_KEY` — new IAM user credentials from Terraform CICD user

**Keys to DELETE** from all secrets (dead infrastructure):
- `Logging__Elasticsearch__Uri` / `Logging__Elasticsearch__Username` / `Logging__Elasticsearch__Password`
- `Redis__Host` / `Redis__Password`

**Keys that are region-independent** (copy as-is from backup):
- Third-party API keys: `Tabby__*`, `Checkout__*`, `SEATSIO_API_KEY`, `TALON_*`, `CheckoutComAuthorizationKey`, `WHATSAPP_*`, `EMAIL_SERVICE_*`, `WRSTBND_*`, `DiscountServiceToken`, `BasicAuthKey`, `TabbyAuthKey`, `ChekoutAuthKey`
- Config values: `UNSECURE_TEST_CODE`, `DISTRIBUTION_PORTAL_LINK`, `EXCHANGE_RATE_*`, `ENABLE_PERFORMANCE_METRICS`, `RestrictedViewJob__*`, `MDLBEAST_*`, `WHATSAPP_BOT_TEMPLATE_ID`

**Step 1: Create the `terraform` secret FIRST** (required before `terraform apply` in Phase 2.4 — Terraform reads `rds_pass` from this secret at plan time):
```bash
# Get RDS password — available from EITHER source (both are backed up):
#   Option A: /rds/ticketing-cluster backup → password field
#   Option B: terraform backup → rds field (directly available now)
RDS_PASS=$(python3 -c "
import json
with open('backup-secrets/terraform.json') as f:
    d = json.load(f)
inner = json.loads(d['SecretString'])
print(inner['rds'])
")

aws secretsmanager create-secret --name "terraform" \
  --secret-string "{\"rds\":\"${RDS_PASS}\"}" \
  --profile AdministratorAccess-660748123249 --region eu-central-1
```

**Note:** The Terraform secret key is `rds` (matching the backup). Terraform's `secretmanager.tf` reads `local.terraform.rds` for the master password. The `redis` and `opensearch` keys from the backup are omitted (deprecated infrastructure).

**Step 2: Create RDS cluster secret** (host is placeholder — updated after Aurora restore in 2.6):
```bash
# Extract username/password from backup
RDS_USER=$(python3 -c "
import json
with open('backup-secrets/__rds__ticketing-cluster.json') as f:
    d = json.load(f)
print(json.loads(d['SecretString'])['username'])
")

aws secretsmanager create-secret --name "/rds/ticketing-cluster" \
  --secret-string "{
    \"username\": \"${RDS_USER}\",
    \"password\": \"${RDS_PASS}\",
    \"engine\": \"aurora-postgresql\",
    \"host\": \"PLACEHOLDER_UPDATE_AFTER_RESTORE\",
    \"port\": \"5432\",
    \"dbClusterIdentifier\": \"ticketing\"
  }" --profile AdministratorAccess-660748123249 --region eu-central-1
```

**Step 3: Create secrets from backups** (placeholder values for region-dependent keys):
```bash
for env in prod; do
  # All services with backups (22 services — all except ecwid which needs special handling)
  for svc in access-control automations catalogue customers dp extensions gateway geidea \
    integration inventory loyalty marketplace media organizations pricing reporting \
    sales transfer xp-badges; do
    # Read backed-up secret, strip Elasticsearch/Redis keys
    SECRET_JSON=$(python3 -c "
import json
with open('backup-secrets/__prod__${svc}.json') as f:
    d = json.load(f)
inner = json.loads(d['SecretString'])
for k in list(inner.keys()):
    if 'Elasticsearch' in k or 'Redis' in k:
        del inner[k]
# Mark region-dependent keys as needing update
for k in ['CONNECTION_STRINGS','CONNECTION_STRINGS_Sales','SQS_QUEUE_URL',
          'EXTENSION_DEPLOYER_SQS_QUEUE_URL','EXTENSION_EXECUTOR_SQS_QUEUE_URL']:
    if k in inner:
        inner[k] = 'PLACEHOLDER_UPDATE_IN_PHASE_3.4'
print(json.dumps(inner))
")
    aws secretsmanager create-secret --name "/$env/$svc" \
      --secret-string "$SECRET_JSON" \
      --profile AdministratorAccess-660748123249 --region eu-central-1
  done
done

# Devops secret (SSH public key — copy as-is)
python3 -c "
import json
with open('backup-secrets/devops.json') as f:
    d = json.load(f)
print(d['SecretString'])
" | aws secretsmanager create-secret --name "devops" \
  --secret-string file:///dev/stdin \
  --profile AdministratorAccess-660748123249 --region eu-central-1

# Google service account (region-independent)
python3 -c "
import json
with open('backup-secrets/prod__data.json') as f:
    d = json.load(f)
print(d['SecretString'])
" | aws secretsmanager create-secret --name "prod/data" \
  --secret-string file:///dev/stdin \
  --profile AdministratorAccess-660748123249 --region eu-central-1
```

**Step 4: Create ecwid secret (partial backup — needs missing keys from vendor dashboards):**

Ecwid is the only secret with a partial backup. The backup has 9 credential keys but is missing `CONNECTION_STRINGS` and 7 configuration values.

See `secrets-reconstruction.md` for the full per-key breakdown.

```bash
# Create ecwid secret from partial backup + placeholders for missing keys
python3 -c "
import json
with open('backup-secrets/__prod__ecwid.json') as f:
    d = json.load(f)
inner = json.loads(d['SecretString'])

# Add placeholder CONNECTION_STRINGS (updated in Phase 3.4)
inner['CONNECTION_STRINGS'] = json.dumps({
    'PgSql': 'User ID=devops;Password=PLACEHOLDER;Host=PLACEHOLDER;Database=ecwid;Timeout=10;Pooling=true;Application Name=ecwid;',
    'ReadonlyPgSql': 'User ID=devops;Password=PLACEHOLDER;Host=PLACEHOLDER;Database=ecwid;Timeout=10;Pooling=true;Application Name=ecwid;'
})

# Add placeholders for missing config keys (retrieve from vendor dashboards)
inner['ECWID_STORE_ID'] = 'TODO_FROM_ECWID_DASHBOARD'
inner['ECWID_BASE_ADDRESS'] = 'https://app.ecwid.com/api/v3'
inner['ANCHANTO_STORE_ID'] = 'TODO_FROM_ANCHANTO_DASHBOARD'
inner['ANCHANTO_MARKETPLACE_CODE'] = 'TODO_FROM_ANCHANTO_DASHBOARD'
inner['ANCHANTO_BASE_ADDRESS'] = 'TODO_FROM_ANCHANTO_DASHBOARD'
inner['ANCHANTO_BASE_CATEGORY_CODE'] = 'TODO_FROM_ANCHANTO_DASHBOARD'
inner['ANCHANTO_BASE_CATEGORY_NAME'] = 'TODO_FROM_ANCHANTO_DASHBOARD'

print(json.dumps(inner))
" | aws secretsmanager create-secret --name "/prod/ecwid" \
  --secret-string file:///dev/stdin \
  --profile AdministratorAccess-660748123249 --region eu-central-1

# After creating: update ecwid secret with actual values from vendor dashboards:
# - ECWID_STORE_ID, ECWID_BASE_ADDRESS (from Ecwid dashboard)
# - ANCHANTO_STORE_ID, ANCHANTO_MARKETPLACE_CODE, ANCHANTO_BASE_ADDRESS,
#   ANCHANTO_BASE_CATEGORY_CODE, ANCHANTO_BASE_CATEGORY_NAME (from Anchanto dashboard)
# - HyperPay_BaseUrl for customers secret (if not set via CDK env-var JSON)
```

**Note on previously "failed" secrets:** access-control, catalogue, customers, dp, and terraform backups have all been recovered (as of 2026-03-25). They are now included in Step 3's bulk copy loop. Key preservation:
- **`ENCRYPTION_KEY`/`ENCRYPTION_IV`** (access-control) — preserved from backup, existing encrypted PII remains readable
- **`HyperPay*`** (customers) — `HyperPayConfigId`, `HyperPay_AccountEmail`, `HyperPay_AccountPassword` are backed up; only `HyperPay_BaseUrl` may need manual addition
- **`terraform`** — `rds` password is backed up directly; `redis`/`opensearch` keys omitted (deprecated)

**Step 5: Verify all secrets exist:**
```bash
aws secretsmanager list-secrets \
  --profile AdministratorAccess-660748123249 --region eu-central-1 \
  --query 'SecretList[*].Name' --output table
# Expected: 22 service secrets + /rds/ticketing-cluster + prod/data + terraform + devops = 26
# (22 services = 20 from Step 3 + ecwid from Step 4 + xp-badges)
# Note: xp-badges is excluded from migration but secret is created for completeness
```

### 2.4 Terraform Apply (WITHOUT RDS Cluster)

**Important:** The Terraform configs from Phase 1 already exclude EKS, Redis, OpenSearch, WAF, MSK, and runners. Additionally, Phase 1 Task 9 commented out the `aws_rds_cluster` and `aws_rds_cluster_instance` resource blocks — this prevents Terraform from creating an empty database cluster that would conflict with the backup restore in Phase 2.6.

**Prerequisite:** The `terraform` secret must exist in eu-central-1 (created in Phase 2.3 Step 1) because `secretmanager.tf` reads `rds_pass` from it at plan time.

```bash
cd ticketing-platform-terraform-prod/prod

# 1. Import existing Route53 hosted zones BEFORE apply
#    Route53 zones are global — they still exist even though me-south-1 is down.
#    Without import, Terraform would create DUPLICATE zones with different NS records.
aws route53 list-hosted-zones \
  --profile AdministratorAccess-660748123249 \
  --query 'HostedZones[*].{Name:Name,Id:Id}' --output table

# 2. Init and import
AWS_PROFILE=AdministratorAccess-660748123249 terraform init -reconfigure
AWS_PROFILE=AdministratorAccess-660748123249 terraform import \
  'module.zones.aws_route53_zone.this["production.tickets.mdlbeast.net"]' <prod-zone-id>
AWS_PROFILE=AdministratorAccess-660748123249 terraform import \
  'module.zones.aws_route53_zone.this["tickets.mdlbeast.net"]' <root-zone-id>

# 3. Plan and apply
AWS_PROFILE=AdministratorAccess-660748123249 terraform plan
# Expected: Route53 zones = "no changes"
# Expected: Creates VPC, subnets, S3 buckets, KMS, IAM, security groups, CloudFront, NAT, etc.
# Expected: NO aws_rds_cluster, NO aws_rds_cluster_instance (commented out)
# Expected: YES aws_db_subnet_group, YES aws_security_group for RDS (needed for backup restore)

AWS_PROFILE=AdministratorAccess-660748123249 terraform apply
```

**Creates:** VPC (10.10.0.0/16), 3x subnets per tier (Lambda, RDS, management), NAT Gateways, S3 buckets (new `-eu` names), KMS keys, IAM CICD user, security groups (incl. RDS security group), RDS DB subnet group, CloudFront distributions, OpenVPN EC2, Route53 zones (imported, not duplicated).

**Does NOT create:** RDS cluster (commented out — restored from backup in 2.6), EKS, Redis, OpenSearch, WAF, MSK, runners.

**S3 buckets** are created empty by Terraform. Backup data is restored into them in Phase 2.7 using `"NewBucket": "false"` — no conflict.

**Route53 DNS:** After Terraform apply, the existing zones are managed by the new state. CDK stacks (Phase 3) will use `HostedZone.FromLookup` to find these zones and create/update A records pointing to new eu-central-1 API Gateway endpoints:
- Public: `api.{env}.tickets.mdlbeast.net`, `geidea.{env}.tickets.mdlbeast.net`, `xp-badges.{env}.*`, `bandsintown.{env}.*`, `marketingfeed.{env}.*`
- Private: `*.internal.{env}.tickets.mdlbeast.net` (new private hosted zone created by CDK, VPC-associated)

**No parent domain NS delegation changes needed.** Old dead A records are overwritten when CDK deploys service stacks.

**Verification:**
```bash
aws ec2 describe-vpcs \
  --profile AdministratorAccess-660748123249 --region eu-central-1 \
  --filters "Name=tag:Name,Values=ticketing" --query 'Vpcs[0].VpcId'
aws ec2 describe-subnets \
  --profile AdministratorAccess-660748123249 --region eu-central-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" --query 'Subnets | length(@)'
# Also verify S3 buckets created:
aws s3 ls --profile AdministratorAccess-660748123249 | grep -E "(pdf-tickets|csv-reports|media)-eu"
```

### 2.5 Populate Manual SSM Parameters

These bridge Terraform → CDK and must exist before any CDK deploy. The full SSM inventory is split into **manual** (must pre-exist) and **auto-created** (CDK writes during deploy).

**Complete SSM parameter inventory:**

| Parameter | Source | Manual? | Notes |
|-----------|--------|---------|-------|
| `/{env}/tp/VPC_NAME` | Static value `ticketing` | **YES** | CDK's `CdkStackUtilities.GetTicketingVpc` reads this |
| `/{env}/tp/SUBNET_1` | Terraform output | **YES** | Lambda subnet IDs from `terraform output` |
| `/{env}/tp/SUBNET_2` | Terraform output | **YES** | |
| `/{env}/tp/SUBNET_3` | Terraform output | **YES** | |
| `/rds/ticketing-cluster-identifier` | Aurora restore | **YES** | Set to restored cluster identifier (`ticketing`) — same as original, RDS identifiers are region-scoped |
| `/rds/ticketing-cluster-sg` | Terraform output | **YES** | RDS security group ID |
| `/production-eu/tp/DomainCertificateArn` | ACM (Phase 3.2) | **YES** | Gateway API certificate. **Note:** GatewayStack maps `prod` → `production-eu` in its SSM path — this is NOT `/{env}/tp/...` |
| `/{env}/tp/geidea/DomainCertificateArn` | ACM (Phase 3.2) | **YES** | Geidea API certificate |
| `/{env}/tp/ecwid/DomainCertificateArn` | ACM (Phase 3.2) | **YES** | Ecwid API certificate |
| `/{env}/tp/pdf/generator/STORAGE_BUCKET_NAME` | S3 bucket name | **YES** | Must match new `-eu` bucket name |
| `/{env}/tp/SlackNotification/ErrorsWebhookUrl` | Slack workspace | **YES** | SecureString — retrieve from Slack |
| `/{env}/tp/SlackNotification/OperationalErrorsWebhookUrl` | Slack workspace | **YES** | SecureString |
| `/{env}/tp/SlackNotification/SuspiciousOrdersWebhookUrl` | Slack workspace | **YES** | SecureString |
| `/{env}/tp/SlackNotification/IgnoredErrorsPatterns` | Config | **YES** | StringList |
| `/{env}/tp/InternalDomainCertificateArn` | CDK InternalCertificateStack | NO | Auto-created |
| `/{env}/tp/ApiGatewayVpcEndpointId` | CDK ApiGatewayVpcEndpointStack | NO | Auto-created (shared dev/sandbox) |
| `/{env}/tp/consumers/{service}/queue-arn` (×18) | CDK ConsumersSqsStack | NO | Auto-created per consumer |
| `/rds/RdsProxyEndpoint` | CDK RdsProxyStack | NO | Auto-created |
| `/rds/RdsProxyReadOnlyEndpoint` | CDK RdsProxyStack | NO | Auto-created |
| `/{env}/tp/InternalServices/{service}` | CDK per service stack | NO | Auto-created per service |

**Create manual parameters:**

```bash
P="--profile AdministratorAccess-660748123249 --region eu-central-1"

# VPC name
for env in prod; do
  aws ssm put-parameter --name "/$env/tp/VPC_NAME" \
    --type String --value "ticketing" $P
done

# RDS cluster references (cluster identifier for CDK RdsProxyStack)
aws ssm put-parameter --name "/rds/ticketing-cluster-identifier" \
  --type String --value "ticketing" $P

# RDS security group ID (created by Terraform in 2.4 — still in rds.tf)
RDS_SG=$(aws ec2 describe-security-groups $P \
  --filters "Name=group-name,Values=rds-one" \
  --query 'SecurityGroups[0].GroupId' --output text)
aws ssm put-parameter --name "/rds/ticketing-cluster-sg" \
  --type String --value "$RDS_SG" $P

# Subnet IDs (from Terraform output — verify tag names match your Terraform config)
SUBNET_1=$(aws ec2 describe-subnets $P \
  --filters "Name=tag:Name,Values=lambda-subnet-1a-prod" \
  --query 'Subnets[0].SubnetId' --output text)
SUBNET_2=$(aws ec2 describe-subnets $P \
  --filters "Name=tag:Name,Values=lambda-subnet-1b-prod" \
  --query 'Subnets[0].SubnetId' --output text)
SUBNET_3=$(aws ec2 describe-subnets $P \
  --filters "Name=tag:Name,Values=lambda-subnet-1c-prod" \
  --query 'Subnets[0].SubnetId' --output text)

for env in prod; do
  aws ssm put-parameter --name "/$env/tp/SUBNET_1" --type String --value "$SUBNET_1" $P
  aws ssm put-parameter --name "/$env/tp/SUBNET_2" --type String --value "$SUBNET_2" $P
  aws ssm put-parameter --name "/$env/tp/SUBNET_3" --type String --value "$SUBNET_3" $P
done

# PDF Generator S3 bucket name (actual prod bucket is tickets-pdf-download, not pdf-tickets-prod)
aws ssm put-parameter --name "/prod/tp/pdf/generator/STORAGE_BUCKET_NAME" \
  --type String --value "tickets-pdf-download-eu" $P

# Slack webhook URLs (now available from backup-ssm/ — no need to retrieve from Slack workspace)
for env in prod; do
  # Extract webhook URLs from backup files
  ERRORS_URL=$(python3 -c "
import json
with open('backup-ssm/__prod__tp__SlackNotification__ErrorsWebhookUrl.json') as f:
    print(json.load(f)['Parameter']['Value'])
")
  OPS_ERRORS_URL=$(python3 -c "
import json
with open('backup-ssm/__prod__tp__SlackNotification__OperationalErrorsWebhookUrl.json') as f:
    print(json.load(f)['Parameter']['Value'])
")
  SUSPICIOUS_URL=$(python3 -c "
import json
with open('backup-ssm/__prod__tp__SlackNotification__SuspiciousOrdersWebhookUrl.json') as f:
    print(json.load(f)['Parameter']['Value'])
")

  aws ssm put-parameter --name "/$env/tp/SlackNotification/ErrorsWebhookUrl" \
    --type SecureString --value "$ERRORS_URL" $P
  aws ssm put-parameter --name "/$env/tp/SlackNotification/OperationalErrorsWebhookUrl" \
    --type SecureString --value "$OPS_ERRORS_URL" $P
  aws ssm put-parameter --name "/$env/tp/SlackNotification/SuspiciousOrdersWebhookUrl" \
    --type SecureString --value "$SUSPICIOUS_URL" $P
  aws ssm put-parameter --name "/$env/tp/SlackNotification/IgnoredErrorsPatterns" \
    --type StringList --value "info:,Information" $P  # Backed-up value from me-south-1
done

# NOTE: Certificate ARN parameters (DomainCertificateArn, geidea, ecwid)
# are created in Phase 3.2 after ACM issuance.
# NOTE: xp-badges, bandsintown-integration, marketing-feeds are EXCLUDED from migration.

# Runtime SSM params for CSV/PDF generators (must exist before Lambda invocation, not CDK deploy)
# These are loaded at cold start via ReadSsmParametersAndAddToEnvVars — not CDK-blocking but
# Lambda functions will crash without them.

# CSV Generator (4 params)
aws ssm put-parameter --name "/prod/tp/csv/generator/STORAGE_BUCKET_NAME" \
  --type String --value "ticketing-csv-reports-eu" $P
aws ssm put-parameter --name "/prod/tp/csv/generator/EMAIL_SERVICE_API_KEY" \
  --type SecureString --value "<sendgrid-api-key>" $P
aws ssm put-parameter --name "/prod/tp/csv/generator/EMAIL_SERVICE_FROM" \
  --type String --value "tickets@mdlbeast.com" $P
aws ssm put-parameter --name "/prod/tp/csv/generator/STORAGE_EXPIRATION_HOURS" \
  --type String --value "48" $P

# PDF Generator (5 params — STORAGE_BUCKET_NAME already created above)
# Cross-reference: PDF_SERVICE_* values extracted from media secret backup
PDF_SERVICE_URL=$(python3 -c "
import json
with open('backup-secrets/__prod__media.json') as f:
    d = json.load(f)
inner = json.loads(d['SecretString'])
print(inner['PDF_SERVICE_URL'])
")
PDF_SERVICE_API_KEY=$(python3 -c "
import json
with open('backup-secrets/__prod__media.json') as f:
    d = json.load(f)
inner = json.loads(d['SecretString'])
print(inner['PDF_SERVICE_API_KEY'])
")
PDF_SERVICE_API_SECRET=$(python3 -c "
import json
with open('backup-secrets/__prod__media.json') as f:
    d = json.load(f)
inner = json.loads(d['SecretString'])
print(inner['PDF_SERVICE_API_SECRET'])
")
PDF_SERVICE_WORKSPACE_ID=$(python3 -c "
import json
with open('backup-secrets/__prod__media.json') as f:
    d = json.load(f)
inner = json.loads(d['SecretString'])
print(inner['PDF_SERVICE_WORKSPACE_ID'])
")

aws ssm put-parameter --name "/prod/tp/pdf/generator/PDF_SERVICE_URL" \
  --type String --value "$PDF_SERVICE_URL" $P
aws ssm put-parameter --name "/prod/tp/pdf/generator/PDF_SERVICE_API_KEY" \
  --type SecureString --value "$PDF_SERVICE_API_KEY" $P
aws ssm put-parameter --name "/prod/tp/pdf/generator/PDF_SERVICE_API_SECRET" \
  --type SecureString --value "$PDF_SERVICE_API_SECRET" $P
aws ssm put-parameter --name "/prod/tp/pdf/generator/PDF_SERVICE_WORKSPACE_ID" \
  --type String --value "$PDF_SERVICE_WORKSPACE_ID" $P
aws ssm put-parameter --name "/prod/tp/pdf/generator/STORAGE_EXPIRATION_HOURS" \
  --type String --value "48" $P

```

**Full SSM reconstruction reference:** `ssm-reconstruction.md` — complete inventory of all parameters with sources and backup status.

### 2.5.1 Create DynamoDB Cache Table

**Required before Phase 3.5 service deployment.** 7 services use a manually-provisioned DynamoDB table `"Cache"` for distributed caching. This table is NOT created by Terraform or CDK — it must be created manually.

**Affected services:** access-control, catalogue, customer-service, inventory, marketplace, media, organizations

```bash
P="--profile AdministratorAccess-660748123249 --region eu-central-1"

# Create the Cache table (PAY_PER_REQUEST = no capacity planning needed)
aws dynamodb create-table --table-name Cache \
  --attribute-definitions AttributeName=CacheKey,AttributeType=S \
  --key-schema AttributeName=CacheKey,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST $P

# Enable TTL for automatic cache expiry
aws dynamodb update-time-to-live --table-name Cache \
  --time-to-live-specification "Enabled=true,AttributeName=ExpirationTime" $P

# Verify table is ACTIVE
aws dynamodb describe-table --table-name Cache $P \
  --query 'Table.TableStatus'
```

**No data migration needed** — cache is ephemeral and rebuilds on demand. The table schema matches `DynamoDbCacheProvider` in `TP.Tools.Helpers`:
- `CacheKey` (String) — partition key
- `CacheValue` (String) — serialized cached data
- `ExpirationTime` (Number) — Unix timestamp for TTL

**IAM is already covered:** `DynamoDbPolicyStatement` in `TP.Tools.Infrastructure` grants `dynamodb:GetItem/PutItem/DeleteItem` on `"*"` — no policy changes needed.

**Verification (manual params expected for prod — cert params created later in Phase 3.2):**
```bash
aws ssm get-parameters-by-path --path "/" --recursive \
  --profile AdministratorAccess-660748123249 --region eu-central-1 \
  --query 'Parameters[*].Name' --output table
```

### 2.6 Restore Aurora from AWS Backup

Since me-south-1 is down, restore from the cross-region backup copy in eu-central-1. The RDS cluster/instance resources were commented out in Phase 1 Task 9 so Terraform did NOT create an empty cluster. The DB subnet group and security group WERE created by Terraform and are used here.

```bash
P="--profile AdministratorAccess-660748123249 --region eu-central-1"

# 1. List available Aurora backup recovery points in eu-central-1
#    Backups are stored in vault "backup-vault-prod"
#    Latest confirmed: 2026-03-23 19:40 UTC+8, engine aurora-postgresql 15.12
aws backup list-recovery-points-by-resource \
  --resource-arn "arn:aws:rds:me-south-1:660748123249:cluster:ticketing" $P \
  --query 'sort_by(RecoveryPoints, &CreationDate)[-1]'

# 2. Get the RDS security group ID (created by Terraform in 2.4)
RDS_SG=$(aws ec2 describe-security-groups $P \
  --filters "Name=group-name,Values=rds-one" \
  --query 'SecurityGroups[0].GroupId' --output text)

# 3. Restore the cluster from the most recent recovery point
#    Uses VPC subnets + security group created by Terraform
aws backup start-restore-job \
  --recovery-point-arn "<recovery-point-arn>" \
  --iam-role-arn "arn:aws:iam::660748123249:role/AWSBackupDefaultRole" \
  --metadata '{
    "DBClusterIdentifier": "ticketing",
    "Engine": "aurora-postgresql",
    "DBSubnetGroupName": "postgres",
    "VpcSecurityGroupIds": "'$RDS_SG'"
  }' $P

# 4. Wait for restore to complete (can take 15-60 minutes)
aws backup describe-restore-job --restore-job-id "<job-id>" $P
# Poll until Status = "COMPLETED"

# 4a. Apply security group to restored cluster
#     The VpcSecurityGroupIds metadata in the restore command MAY be silently ignored
#     by the AWS Backup API (it's not in the documented required/optional metadata fields).
#     If the restored cluster doesn't have the correct security group, apply it now.
#     Without this, the cluster uses the VPC's default security group (no DB ingress rules)
#     and all connection attempts will fail.
CURRENT_SG=$(aws rds describe-db-clusters --db-cluster-identifier ticketing $P \
  --query 'DBClusters[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
if [ "$CURRENT_SG" != "$RDS_SG" ]; then
  echo "Security group mismatch — applying correct SG: $RDS_SG (current: $CURRENT_SG)"
  aws rds modify-db-cluster \
    --db-cluster-identifier ticketing \
    --vpc-security-group-ids $RDS_SG \
    --apply-immediately $P
  echo "Waiting for cluster modification..."
  sleep 30
fi

# 5. Verify the engine version matches expectations
aws rds describe-db-clusters --db-cluster-identifier ticketing $P \
  --query 'DBClusters[0].EngineVersion'

# 6. Add serverless instances (the restore only creates the cluster, not instances)
#    Instance identifiers match Terraform's naming: "aurora-cluster-demo-${count.index}"
#    RDS identifiers are region-scoped (not globally unique), so we reuse the original names.
for i in 0 1 2; do
  aws rds create-db-instance \
    --db-instance-identifier aurora-cluster-demo-$i \
    --db-cluster-identifier ticketing \
    --engine aurora-postgresql \
    --db-instance-class db.serverless $P
done

# 7. Set Serverless v2 scaling (prod: 8-64 ACU — elevated min during go-live)
aws rds modify-db-cluster \
  --db-cluster-identifier ticketing \
  --serverless-v2-scaling-configuration MinCapacity=8,MaxCapacity=64 $P
# NOTE: MinCapacity elevated to 8 ACU during go-live to handle cold-cache load.
# Reduce to normal 1.5 ACU after 72 hours stable (Phase 4.7).

# 8. Wait for all instances to be available
aws rds wait db-instance-available --db-instance-identifier aurora-cluster-demo-0 $P
aws rds wait db-instance-available --db-instance-identifier aurora-cluster-demo-1 $P
aws rds wait db-instance-available --db-instance-identifier aurora-cluster-demo-2 $P

# 9. Verify cluster is available and writable
aws rds describe-db-clusters --db-cluster-identifier ticketing $P \
  --query 'DBClusters[0].{Status:Status,Endpoint:Endpoint,ReaderEndpoint:ReaderEndpoint}'

# 10. Import Aurora into Terraform state
#     First: UNCOMMENT the aws_rds_cluster and aws_rds_cluster_instance blocks in rds.tf
#     No identifier changes needed — we used the original Terraform names during restore
#     (RDS identifiers are region-scoped, not globally unique, so no conflict with me-south-1)
cd ticketing-platform-terraform-prod/prod
AWS_PROFILE=AdministratorAccess-660748123249 terraform import aws_rds_cluster.ticketing ticketing
AWS_PROFILE=AdministratorAccess-660748123249 terraform import 'aws_rds_cluster_instance.ticketing[0]' aurora-cluster-demo-0
AWS_PROFILE=AdministratorAccess-660748123249 terraform import 'aws_rds_cluster_instance.ticketing[1]' aurora-cluster-demo-1
AWS_PROFILE=AdministratorAccess-660748123249 terraform import 'aws_rds_cluster_instance.ticketing[2]' aurora-cluster-demo-2
AWS_PROFILE=AdministratorAccess-660748123249 terraform plan
# Review: should show no changes or minor drift. Fix any drift in rds.tf before proceeding.

# 11. Update /rds/ticketing-cluster secret with the new endpoint
AURORA_ENDPOINT=$(aws rds describe-db-clusters --db-cluster-identifier ticketing $P \
  --query 'DBClusters[0].Endpoint' --output text)

# Read credentials from backup file
RDS_USER=$(python3 -c "
import json
with open('backup-secrets/__rds__ticketing-cluster.json') as f:
    d = json.load(f)
print(json.loads(d['SecretString'])['username'])
")
RDS_PASS=$(python3 -c "
import json
with open('backup-secrets/__rds__ticketing-cluster.json') as f:
    d = json.load(f)
print(json.loads(d['SecretString'])['password'])
")

aws secretsmanager update-secret --secret-id "/rds/ticketing-cluster" \
  --secret-string "{
    \"username\": \"${RDS_USER}\",
    \"password\": \"${RDS_PASS}\",
    \"engine\": \"aurora-postgresql\",
    \"host\": \"${AURORA_ENDPOINT}\",
    \"port\": \"5432\",
    \"dbClusterIdentifier\": \"ticketing\"
  }" $P
```

**Sequence summary for RDS:**
1. Phase 1 Task 9: Comment out `aws_rds_cluster` + `aws_rds_cluster_instance` in `rds.tf`
2. Phase 2.4: `terraform apply` creates subnet group + security group, but NOT the cluster
3. Phase 2.6 steps 3-9: Restore cluster from backup into Terraform-created subnet/sg
4. Phase 2.6 step 10: Uncomment RDS resources in `rds.tf`, adjust identifiers, `terraform import`
5. `terraform plan` should now show zero changes — Terraform manages the restored cluster

### 2.7 Restore S3 Data from AWS Backup

S3 buckets were created empty by Terraform in 2.4. Backup data is restored INTO those existing buckets.

```bash
P="--profile AdministratorAccess-660748123249 --region eu-central-1"

# 1. List S3 backup recovery points in eu-central-1
#    Backups are stored in vault "backup-vault-prod" (not "Default")
#    Latest confirmed: 2026-03-23 19:40 UTC+8 for both buckets below
aws backup list-recovery-points-by-resource \
  --resource-arn "arn:aws:s3:::tickets-pdf-download" $P
aws backup list-recovery-points-by-resource \
  --resource-arn "arn:aws:s3:::ticketing-csv-reports" $P

# 2. Restore each bucket to the new eu-central-1 bucket
# Terraform created these with -eu suffix; "NewBucket": "false" restores data into existing bucket
#
# Only 2 prod buckets have cross-region backup copies in eu-central-1:
#   tickets-pdf-download     → tickets-pdf-download-eu     (20 recovery points, latest 2026-03-23)
#   ticketing-csv-reports    → ticketing-csv-reports-eu     (20 recovery points, latest 2026-03-23)
#
# NOT restored (no backup copies in eu-central-1):
#   ticketing-prod-media     → ticketing-prod-media-eu      (0 recovery points — bucket recreated empty, acceptable)
#   ticketing-prod-extended-message → CDK-created dynamically (no restore needed)

aws backup start-restore-job \
  --recovery-point-arn "<recovery-point-arn-for-tickets-pdf-download>" \
  --iam-role-arn "arn:aws:iam::660748123249:role/AWSBackupDefaultRole" \
  --metadata '{
    "DestinationBucketName": "tickets-pdf-download-eu",
    "NewBucket": "false"
  }' $P

aws backup start-restore-job \
  --recovery-point-arn "<recovery-point-arn-for-ticketing-csv-reports>" \
  --iam-role-arn "arn:aws:iam::660748123249:role/AWSBackupDefaultRole" \
  --metadata '{
    "DestinationBucketName": "ticketing-csv-reports-eu",
    "NewBucket": "false"
  }' $P

# 3. Monitor restore jobs
aws backup list-restore-jobs $P \
  --query 'RestoreJobs[?Status!=`COMPLETED`].{Id:RestoreJobId,Status:Status,Bucket:ResourceType}'

# 4. Verify object counts after restores complete
for bucket in tickets-pdf-download-eu ticketing-csv-reports-eu; do
  echo "$bucket: $(aws s3 ls s3://$bucket --recursive --summarize $P | tail -1)"
done
```

### 2.8 CDK Bootstrap

**Required before any `cdk deploy` in eu-central-1.** CDK needs its bootstrap S3 bucket and IAM roles.

```bash
AWS_PROFILE=AdministratorAccess-660748123249 \
  CDK_DEFAULT_ACCOUNT=660748123249 CDK_DEFAULT_REGION=eu-central-1 \
  npx cdk bootstrap aws://660748123249/eu-central-1
```

**Creates:**
- S3 bucket: `cdk-hnb659fds-assets-660748123249-eu-central-1` (prod account)
- IAM roles for CDK deployment
- CloudFormation stack: `CDKToolkit`

### Phase 2 Verification Checklist

- [ ] VPC exists in eu-central-1 with correct CIDR and 3 AZs
- [ ] All subnets created (Lambda, RDS, management tiers) — **no EKS, Redis, OpenSearch, runner subnets**
- [ ] NAT Gateways operational with Elastic IPs
- [ ] Route53 hosted zones imported (dev, sandbox) — no duplicates, same NS records as before
- [ ] Aurora cluster restored from backup and available with 3 instances
- [ ] Aurora Serverless v2 scaling configured (8-64 ACU for go-live; reduce to 1.5-64 after 72 hours)
- [ ] Aurora imported into Terraform state — `terraform plan` shows no changes
- [ ] RDS cluster/instance blocks uncommented in `rds.tf`
- [ ] S3 data restored to new `-eu` buckets — object counts verified
- [ ] All 16 manual SSM parameters populated (VPC, subnets, RDS refs, PDF bucket, Slack webhooks)
- [ ] DynamoDB `Cache` table created and ACTIVE (used by 7 services for distributed caching)
- [ ] All 24 secrets created in eu-central-1 (18 from backup + 6 reconstructed = 24 total)
- [ ] `terraform` secret contains valid `rds_pass`
- [ ] `/rds/ticketing-cluster` secret has correct Aurora endpoint
- [ ] KMS key created in eu-central-1
- [ ] IAM CICD user created — access key generated (needed for Phase 3.3)
- [ ] Security groups configured (no EKS/Redis/OpenSearch rules)
- [ ] CDK bootstrap stack deployed

---

## Phase 3: Production Services under Temporary Domain

**Duration:** 2-3 days | **Risk:** HIGH | **Rollback:** `cdk destroy` all stacks (no live DNS affected)

### 3.1 Create Temporary Route53 Hosted Zone

Create the `production-eu.tickets.mdlbeast.net` hosted zone for the temporary deployment. This zone is NEW (not imported — it doesn't exist yet).

```bash
P="--profile AdministratorAccess-660748123249 --region eu-central-1"

# Create the temporary hosted zone
aws route53 create-hosted-zone \
  --name "production-eu.tickets.mdlbeast.net" \
  --caller-reference "migration-$(date +%s)" \
  --hosted-zone-config Comment="Temporary zone for eu-central-1 migration testing" \
  --profile AdministratorAccess-660748123249

# Get the new zone's NS records
ZONE_ID=$(aws route53 list-hosted-zones \
  --profile AdministratorAccess-660748123249 \
  --query "HostedZones[?Name=='production-eu.tickets.mdlbeast.net.'].Id" --output text | sed 's|/hostedzone/||')
aws route53 get-hosted-zone --id "$ZONE_ID" \
  --profile AdministratorAccess-660748123249 \
  --query 'DelegationSet.NameServers'

# Add NS delegation in the parent zone (tickets.mdlbeast.net)
# This makes production-eu.tickets.mdlbeast.net resolvable on the internet
PARENT_ZONE_ID=$(aws route53 list-hosted-zones \
  --profile AdministratorAccess-660748123249 \
  --query "HostedZones[?Name=='tickets.mdlbeast.net.'].Id" --output text | sed 's|/hostedzone/||')

# Create NS record in parent zone pointing to the new zone's nameservers
# Replace NS1-NS4 with actual values from the command above
aws route53 change-resource-record-sets --hosted-zone-id "$PARENT_ZONE_ID" \
  --profile AdministratorAccess-660748123249 \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "production-eu.tickets.mdlbeast.net",
        "Type": "NS",
        "TTL": 300,
        "ResourceRecords": [
          {"Value": "ns-XXX.awsdns-XX.org"},
          {"Value": "ns-XXX.awsdns-XX.co.uk"},
          {"Value": "ns-XXX.awsdns-XX.com"},
          {"Value": "ns-XXX.awsdns-XX.net"}
        ]
      }
    }]
  }'
```

### 3.2 Create ACM Certificates

Four certificates needed before CDK stack deployment (3 manual + 1 auto-created by CDK). All certificates use the **temporary** `production-eu` domain.

**DNS validation:** Each certificate requires a CNAME record in Route53 for validation. Create the record in the `production-eu.tickets.mdlbeast.net` zone (created in 3.1). Certificates typically validate within 5-10 minutes.

```bash
P="--profile AdministratorAccess-660748123249 --region eu-central-1"

# Helper: request cert, validate via Route53, store ARN in SSM
request_cert() {
  local domain=$1 ssm_path=$2 env=$3
  CERT_ARN=$(aws acm request-certificate \
    --domain-name "$domain" \
    --validation-method DNS $P \
    --query 'CertificateArn' --output text)
  echo "Requested cert for $domain: $CERT_ARN"

  # Get DNS validation record
  sleep 5  # Wait for ACM to generate validation record
  VALIDATION=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" $P \
    --query 'Certificate.DomainValidationOptions[0].ResourceRecord')
  echo "Add this CNAME to Route53: $VALIDATION"

  # Create validation CNAME in Route53 (get hosted zone ID first)
  # The hosted zone for {env}.tickets.mdlbeast.net was created in Phase 3.1 (production-eu) or imported in Phase 2.4 (production)
  ZONE_ID=$(aws route53 list-hosted-zones $P \
    --query "HostedZones[?Name=='${env}.tickets.mdlbeast.net.'].Id" --output text | sed 's|/hostedzone/||')
  VNAME=$(echo "$VALIDATION" | python3 -c "import json,sys; print(json.load(sys.stdin)['Name'])")
  VVALUE=$(echo "$VALIDATION" | python3 -c "import json,sys; print(json.load(sys.stdin)['Value'])")

  aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" $P \
    --change-batch "{
      \"Changes\": [{
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"$VNAME\",
          \"Type\": \"CNAME\",
          \"TTL\": 300,
          \"ResourceRecords\": [{\"Value\": \"$VVALUE\"}]
        }
      }]
    }"

  # Wait for validation
  aws acm wait certificate-validated --certificate-arn "$CERT_ARN" $P
  echo "Certificate ISSUED: $CERT_ARN"

  # Store in SSM
  aws ssm put-parameter --name "$ssm_path" \
    --type String --value "$CERT_ARN" $P
}

# 1. Gateway — NOTE: SSM path uses mapped env name "production-eu", NOT "/prod/tp/"
request_cert "api.production-eu.tickets.mdlbeast.net" "/production-eu/tp/DomainCertificateArn" "production-eu"

# 2. Geidea — uses raw env "prod" in SSM path
request_cert "geidea.production-eu.tickets.mdlbeast.net" "/prod/tp/geidea/DomainCertificateArn" "production-eu"

# 3. Ecwid — uses raw env "prod" in SSM path
request_cert "ecwid.production-eu.tickets.mdlbeast.net" "/prod/tp/ecwid/DomainCertificateArn" "production-eu"

# 4. Internal certificate — created by InternalCertificateStack in 3.3 (no manual action)
#    Covers: internal.{env}.tickets.mdlbeast.net + *.internal.{env}.tickets.mdlbeast.net

# Verify all certs are ISSUED (3 manual certs)
aws acm list-certificates $P \
  --query 'CertificateSummaryList[*].{Domain:DomainName,Status:Status}'
```

### 3.3 Infrastructure CDK (11 Stacks — Strict Order)

```bash
cd ticketing-platform-infrastructure
export AWS_PROFILE=AdministratorAccess-660748123249
export CDK_DEFAULT_ACCOUNT=660748123249
export CDK_DEFAULT_REGION=eu-central-1
export ENV_NAME=prod

# 1. EventBus (foundational — no dependencies)
cdk deploy TP-EventBusStack-prod --require-approval never

# 2. Consumer SQS queues (creates queues + stores ARNs in SSM)
cdk deploy TP-ConsumersSqsStack-prod --require-approval never

# 3. Consumer subscriptions (needs EventBus + SQS queue ARNs)
cdk deploy TP-ConsumerSubscriptionStack-prod --require-approval never

# 4. Extended message S3 bucket (no dependencies)
cdk deploy TP-ExtendedMessageS3BucketStack-prod --require-approval never

# 5. Internal hosted zone (needs VPC — creates production-eu.tickets.mdlbeast.net private zone)
cdk deploy TP-InternalHostedZoneStack-prod --require-approval never

# 6. Internal certificate (needs hosted zone — for *.internal.production-eu.tickets.mdlbeast.net)
cdk deploy TP-InternalCertificateStack-prod --require-approval never

# 7. Monitoring (needs EventBus)
cdk deploy TP-MonitoringStack-prod --require-approval never

# 8. API Gateway VPC endpoint (needs VPC)
cdk deploy TP-ApiGatewayVpcEndpointStack --require-approval never

# 9. RDS Proxy (needs VPC + RDS cluster + SSM params)
cdk deploy TP-RdsProxyStack --require-approval never

# 10. XRay insight notification (needs EventBus + SSM webhooks)
cdk deploy TP-XRayInsightNotificationStack-prod --require-approval never

# 11. Slack notification (needs SSM webhook URLs + depends on XRayInsightNotificationStack)
cdk deploy TP-SlackNotificationStack-prod --require-approval never
```

### 3.4 Update Connection Strings & Region-Dependent Secrets

**Prerequisite:** RDS Proxy deployed (step 9 of 3.3), SQS queues deployed (step 2 of 3.3). Must complete **before** Phase 3.5 — DbMigrator Lambdas load secrets at runtime to connect to the database.

**Note:** Services will connect directly to the Aurora cluster endpoint (not RDS Proxy). RDS Proxy is deployed by CDK but remains on standby — the existing architecture uses direct connections and changing to RDS Proxy would be an untested behavioral change during a critical migration. RDS Proxy may be adopted or removed in a future iteration.

**Safety note:** All secret update scripts below pipe Python JSON output to `aws secretsmanager update-secret --secret-string file:///dev/stdin`. If the Python script produces malformed JSON (e.g., from special characters or newlines in secret values), the secret will be silently corrupted. Before running each update block, consider validating the output first:
```bash
# Dry-run pattern: replace "| aws secretsmanager update-secret ..." with "| python3 -c 'import json,sys; json.load(sys.stdin); print(\"VALID\")'"
# to verify all secrets produce valid JSON before writing.
```

```bash
P="--profile AdministratorAccess-660748123249 --region eu-central-1"

# 1. Get Aurora cluster endpoints (direct connection — not RDS Proxy)
AURORA_ENDPOINT=$(aws rds describe-db-clusters --db-cluster-identifier ticketing $P \
  --query 'DBClusters[0].Endpoint' --output text)
AURORA_RO_ENDPOINT=$(aws rds describe-db-clusters --db-cluster-identifier ticketing $P \
  --query 'DBClusters[0].ReaderEndpoint' --output text)

# RDS Proxy endpoints are available in SSM if needed in the future:
#   /rds/RdsProxyEndpoint, /rds/RdsProxyReadOnlyEndpoint
RDS_PROXY_ENDPOINT=$AURORA_ENDPOINT           # Using direct Aurora endpoint
RDS_PROXY_RO_ENDPOINT=$AURORA_RO_ENDPOINT     # Using direct Aurora reader endpoint

# (RDS Proxy SSM params still created by CDK — available at /rds/RdsProxyEndpoint if needed later)

# 2. Get RDS master credentials (from /rds/ticketing-cluster secret, updated in 2.6)
RDS_CREDS=$(aws secretsmanager get-secret-value --secret-id "/rds/ticketing-cluster" $P \
  --query 'SecretString' --output text)
RDS_USER=$(echo "$RDS_CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['username'])")
RDS_PASS=$(echo "$RDS_CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['password'])")

# 3. Get new IAM CICD user credentials (created by Terraform in 2.4)
#    Go to IAM Console → Users → find the CICD user → Security credentials → Create access key
#    Or use: aws iam create-access-key --user-name <cicd-user-name> $P
NEW_AWS_KEY="<from-IAM-console-or-cli>"
NEW_AWS_SECRET="<from-IAM-console-or-cli>"

# 4. Get new KMS key ID (created by Terraform in 2.4)
NEW_KMS_KEY=$(aws kms list-aliases $P \
  --query 'Aliases[?contains(AliasName,`ticketing`)].TargetKeyId' --output text)

# 5. Update CONNECTION_STRINGS in each service secret
# Services with CONNECTION_STRINGS (15 services):
#   access-control, catalogue, customers, dp, extensions, integration,
#   inventory, loyalty, marketplace, media, organizations, pricing,
#   reporting, sales, transfer
#
# CONNECTION_STRINGS format (confirmed from backup secrets):
#   JSON dict: {"PgSql":"User ID=...;Password=...;Host=...;Database=...;...", "ReadonlyPgSql":"..."}
#   Uses "User ID=" (not "Username="), includes Timeout, Pooling, Application Name params
#   ReadonlyPgSql uses the -ro- reader endpoint
# Each service has its own database name within the shared Aurora cluster.

for env in prod; do
  for svc in access-control catalogue customers dp extensions integration \
    inventory loyalty marketplace media organizations pricing reporting sales transfer ecwid; do

    # Read current secret, update region-dependent keys
    aws secretsmanager get-secret-value --secret-id "/$env/$svc" \
      $P --query 'SecretString' --output text | \
      python3 -c "
import json, sys, os, re

secret = json.load(sys.stdin)

# New endpoint values from environment
rds_proxy = os.environ.get('RDS_PROXY_ENDPOINT', '${RDS_PROXY_ENDPOINT}')
rds_proxy_ro = os.environ.get('RDS_PROXY_RO_ENDPOINT', '${RDS_PROXY_RO_ENDPOINT}')
new_aws_key = '${NEW_AWS_KEY}'
new_aws_secret = '${NEW_AWS_SECRET}'
new_kms_key = '${NEW_KMS_KEY}'

# Update CONNECTION_STRINGS — preserve JSON dict structure, replace Host= values
for cs_key in ['CONNECTION_STRINGS', 'CONNECTION_STRINGS_Sales']:
    if cs_key not in secret:
        continue
    try:
        cs_dict = json.loads(secret[cs_key])
        for ctx_key, conn_str in cs_dict.items():
            # Replace Host= with new Aurora cluster endpoint (direct connection, not RDS Proxy)
            if 'Readonly' in ctx_key or 'readonly' in ctx_key:
                conn_str = re.sub(r'Host=[^;]+', f'Host={rds_proxy_ro}', conn_str)
            else:
                conn_str = re.sub(r'Host=[^;]+', f'Host={rds_proxy}', conn_str)
            cs_dict[ctx_key] = conn_str
        secret[cs_key] = json.dumps(cs_dict)
    except json.JSONDecodeError:
        # If not JSON dict, replace as plain connection string
        secret[cs_key] = re.sub(r'Host=[^;]+', f'Host={rds_proxy}', secret[cs_key])

# Update SQS queue URLs (replace me-south-1 with eu-central-1, account stays same)
for k in list(secret.keys()):
    if 'SQS' in k and 'me-south-1' in str(secret[k]):
        secret[k] = secret[k].replace('me-south-1', 'eu-central-1')

# Update IAM credentials
for k in ['AWS_ACCESS_KEY', 'STORAGE_ACCESS_KEY']:
    if k in secret:
        secret[k] = new_aws_key
for k in ['AWS_ACCESS_SECRET', 'STORAGE_SECRET_KEY']:
    if k in secret:
        secret[k] = new_aws_secret

# Update KMS key
if 'KMS_KEY_ID' in secret:
    secret['KMS_KEY_ID'] = new_kms_key

print(json.dumps(secret))
" | aws secretsmanager update-secret --secret-id "/$env/$svc" \
      --secret-string file:///dev/stdin $P
  done
done

# 6. Verify SQS queue URLs in secrets after region swap
#
# Step 5 already replaced me-south-1 → eu-central-1 in all SQS_QUEUE_URL values.
# CDK creates queues with the SAME names in eu-central-1, so only the region in the
# URL changes. This step verifies the queue URLs are correct by fetching them fresh.
#
# Actual queue names (confirmed from me-south-1 via `aws sqs list-queues`):
#   CDK consumer queues:  {Service}-queue-{env}  (e.g., Sales-queue-prod)
#   Extension queues:     TP_Extensions_Deployer_Queue_{env}
#                         TP_Extensions_Executor_Queue_{env}
#   CSV generator queue:  TP_CSV_Report_Generator_Service_Queue_{env}
#
for env in prod; do
  # Extensions service — deployer and executor queue URLs
  EXT_DEPLOYER_QUEUE=$(aws sqs get-queue-url --queue-name "TP_Extensions_Deployer_Queue_$env" \
    $P --query 'QueueUrl' --output text 2>/dev/null || echo "CHECK_QUEUE_NAME")
  EXT_EXECUTOR_QUEUE=$(aws sqs get-queue-url --queue-name "TP_Extensions_Executor_Queue_$env" \
    $P --query 'QueueUrl' --output text 2>/dev/null || echo "CHECK_QUEUE_NAME")

  aws secretsmanager get-secret-value --secret-id "/$env/extensions" \
    --region eu-central-1 --query 'SecretString' --output text | \
    python3 -c "
import json, sys
secret = json.load(sys.stdin)
secret['EXTENSION_DEPLOYER_SQS_QUEUE_URL'] = '${EXT_DEPLOYER_QUEUE}'
secret['EXTENSION_EXECUTOR_SQS_QUEUE_URL'] = '${EXT_EXECUTOR_QUEUE}'
print(json.dumps(secret))
" | aws secretsmanager update-secret --secret-id "/$env/extensions" \
      --secret-string file:///dev/stdin $P

  # Marketplace, Sales, Transfer, Reporting — SQS_QUEUE_URL points to CSV generator queue
  CSV_QUEUE_URL=$(aws sqs get-queue-url --queue-name "TP_CSV_Report_Generator_Service_Queue_$env" \
    $P --query 'QueueUrl' --output text 2>/dev/null || echo "CHECK_QUEUE_NAME")

  for svc in marketplace sales transfer reporting; do
    aws secretsmanager get-secret-value --secret-id "/$env/$svc" \
      $P --query 'SecretString' --output text | \
      python3 -c "
import json, sys
secret = json.load(sys.stdin)
if 'SQS_QUEUE_URL' in secret:
    secret['SQS_QUEUE_URL'] = '${CSV_QUEUE_URL}'
print(json.dumps(secret))
" | aws secretsmanager update-secret --secret-id "/$env/$svc" \
        --secret-string file:///dev/stdin $P
  done

  # Media — SQS_QUEUE_URL (verify actual queue name after CDK deploy)
  aws secretsmanager get-secret-value --secret-id "/$env/media" \
    $P --query 'SecretString' --output text | \
    python3 -c "
import json, sys
secret = json.load(sys.stdin)
if 'SQS_QUEUE_URL' in secret:
    # Media's SQS_QUEUE_URL — verify the queue name matches CDK output
    secret['SQS_QUEUE_URL'] = secret['SQS_QUEUE_URL'].replace('me-south-1', 'eu-central-1')
print(json.dumps(secret))
" | aws secretsmanager update-secret --secret-id "/$env/media" \
      --secret-string file:///dev/stdin $P
done
```

**Verification:**
```bash
# Verify CONNECTION_STRINGS point to new Aurora cluster endpoint
for env in prod; do
  echo "=== $env ==="
  for svc in access-control catalogue customers dp extensions integration \
    inventory loyalty marketplace media organizations pricing reporting sales transfer; do
    CONN=$(aws secretsmanager get-secret-value --secret-id "/$env/$svc" \
      $P --query 'SecretString' --output text | \
      python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('CONNECTION_STRINGS','N/A')[:80])")
    echo "  $svc: $CONN"
  done
done
```

**Note:** The script preserves each service's existing connection string structure (JSON dict with `PgSql`/`ReadonlyPgSql` keys) and only replaces the `Host=` value. Database names are NOT changed — they stay as-is from the backup (e.g., `inventoryprod` for inventory, `extension` for extensions). Verify database names exist in the restored Aurora cluster:
```bash
psql -h $RDS_PROXY_ENDPOINT -U $RDS_USER -c "\l" | grep -v template
# Expected databases from backup: sales, inventoryprod, extension, media, geidea,
# integration, loyalty, marketplace, organizations, pricing, plus others from failed backups
```

### 3.5 Per-Service CDK Deployment Matrix

Deploy services using the validated per-service stack matrix. **Not all services follow the same pattern.**

For each service, set:
```bash
export AWS_PROFILE=AdministratorAccess-660748123249
export CDK_DEFAULT_REGION=eu-central-1 ENV_NAME=prod
```

**Deployment notes:**
- Each service's CDK deploy + DB migration is self-contained (touches only its own database schema), so services within the same tier can be deployed **in parallel**.
- **Gateway must deploy last** — it is the reverse proxy that routes to all other services. Deploying it before backend services are up would cause health check failures.
- **IAM roles are global** — every stack's IAM role already exists from me-south-1 CDK. Must use `cdk import` before `cdk deploy`. See procedure below.
- **Stale inline policies pre-deleted** — all 63 me-south-1 inline policies were removed in P3-S5-02. Backup at `backup-iam-policies/restore-inline-policies.sh`.
- **DB migrations will return "No pending migrations"** — databases were restored from backup and already have all migrations.
- **`dotnet lambda package -c Release`** must be run from each Lambda project directory before `cdk synth` (NOT `dotnet publish` — see DIAG-001/002). For services with API projects, `dotnet publish -c Release` from the solution root also works since `Microsoft.NET.Sdk.Web` projects generate `.runtimeconfig.json`.
- **extension-deployer is a Docker image-based Lambda** — it is deployed via `dotnet lambda deploy-function` (not CDK). Follow its CI/CD workflow (`main.yml`). When deploying from Apple Silicon Macs, pass `--docker-build-options "--platform linux/amd64"` to avoid ARM64/x86_64 architecture mismatch (see DIAG-003).

| # | Tier | Service | Stacks (deploy in order) | Has DbMigrator |
|---|------|---------|--------------------------|----------------|
| 1 | 1 | **catalogue** | DbMigratorStack → ServerlessBackendStack | YES |
| 2 | 1 | **organizations** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 3 | 1 | **loyalty** | ConsumersStack → BackgroundJobsStack | NO |
| 4 | 1 | **csv-generator** | ConsumersStack | NO |
| 5 | 1 | **pdf-generator** | ConsumersStack | NO |
| 6 | 1 | **automations** | WeeklyTicketsSenderStack + AutomaticDataExporterStack + FinanceReportSenderStack | NO |
| 7 | 1 | **extension-api** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 8 | 1 | **extension-deployer** | ExtensionDeployerLambdaRoleStack → `dotnet lambda deploy-function` → ExtensionDeployerStack | NO (Docker image — see CI/CD `main.yml`) |
| 9 | 1 | **extension-executor** | ExtensionExecutorStack | NO |
| 10 | 1 | **extension-log-processor** | ExtensionLogsProcessorStack | NO |
| 11 | 1 | **customer-service** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 12 | 2 | **inventory** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 13 | 2 | **pricing** | DbMigratorStack → ConsumersStack → ServerlessBackendStack | YES |
| 14 | 2 | **media** | DbMigratorStack → MediaStorageStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 15 | 2 | **reporting-api** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 16 | 2 | **marketplace** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 17 | 2 | **integration** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 18 | 2 | **distribution-portal** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 19 | 3 | **sales** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 20 | 3 | **access-control** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 21 | 3 | **transfer** | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES |
| 22 | 3 | **geidea** | ConsumersStack → BackgroundJobsStack → ApiStack (HTTP API v2) | NO |
| 23 | 3 | **ecwid-integration** | ApiStack → BackgroundJobsStack | NO |
| 24 | **LAST** | **gateway** | GatewayStack | NO |

**CRITICAL: IAM Role Import Pattern (learned from P3-S5-01 and P3-S5-02)**

Every service CDK stack that creates an IAM role will **fail on first deploy** because IAM is global and the me-south-1 CDK stacks already created these roles. **Never attempt `cdk deploy` directly** — it will fail, create a ROLLBACK_COMPLETE stack, and waste time.

**Stale inline policies:** All 63 stale me-south-1 inline policies were bulk-deleted during P3-S5-02. Backup and restore script at `backup-iam-policies/`. No per-role policy deletion needed.

**Streamlined procedure for each stack:**
```bash
# 1. Synth to generate templates (do this once for all stacks in the service)
cdk synth

# 2. Extract IAM role logical-ID → physical-name from the template
python3 -c "
import json
with open('cdk.out/<STACK_NAME>.template.json') as f:
    t = json.load(f)
for lid, res in t['Resources'].items():
    if res['Type'] == 'AWS::IAM::Role' and 'RoleName' in res.get('Properties', {}):
        print(f'{lid} -> {res[\"Properties\"][\"RoleName\"]}')"

# 3. Create resource mapping and import
echo '{"<LOGICAL_ID>": {"RoleName": "<PHYSICAL_ROLE_NAME>"}}' > /tmp/mapping.json
cdk import <STACK_NAME> --resource-mapping /tmp/mapping.json --force

# 4. Deploy remaining resources
cdk deploy <STACK_NAME> --require-approval never
```

**Helper script:** `deploy-service-cdk.sh` automates steps 2-4 for all stacks in a service:
```bash
export AWS_PROFILE=AdministratorAccess-660748123249
export CDK_DEFAULT_REGION=eu-central-1 ENV_NAME=prod

# Example: deploy loyalty (2 stacks)
./deploy-service-cdk.sh ticketing-platform-loyalty src/TP.Loyalty.Cdk \
  TP-ConsumersStack-loyalty-prod TP-BackgroundJobsStack-loyalty-prod
```

**For services with DbMigrator — additional steps between stacks:**
```bash
P="--profile AdministratorAccess-660748123249 --region eu-central-1"

# After deploying DbMigratorStack, run the migration:
aws lambda invoke --function-name "<service>-db-migrator-lambda-prod" \
  --payload '{}' $P /dev/null

# Create log groups (avoids cold-start delay):
aws logs create-log-group --log-group-name "/aws/lambda/<service>-serverless-prod-function" $P
aws logs create-log-group --log-group-name "/aws/lambda/<service>-consumers-lambda-prod" $P

# Then continue deploying remaining stacks in order per matrix above
```

**Important: always `dotnet lambda package -c Release` from each Lambda project directory** (not `dotnet publish`) before running `cdk synth`. `dotnet publish` does NOT generate `.runtimeconfig.json` for `Microsoft.NET.Sdk` (class library) projects — only `Microsoft.NET.Sdk.Web` API projects survive `dotnet publish`. See DIAG-001/002.

**Exception — extension-deployer:** This is a Docker image-based Lambda deployed via `dotnet lambda deploy-function` following its CI/CD workflow (`main.yml`), not CDK. When deploying from Apple Silicon Macs, add `--docker-build-options "--platform linux/amd64"` (see DIAG-003).

**Post-deployment verification (after each service):**

After deploying all stacks for a service, verify it is healthy via SSM on the OpenVPN instance:
```bash
aws ssm send-command \
  --instance-ids "i-0f005875786d8cc94" \
  --document-name "AWS-RunShellScript" \
  --parameters '{"commands":["curl -sk https://<service>.internal.production-eu.tickets.mdlbeast.net/health"]}' \
  --region eu-central-1 --query 'Command.CommandId' --output text

# Then retrieve the result:
aws ssm get-command-invocation \
  --command-id "<COMMAND_ID>" \
  --instance-id "i-0f005875786d8cc94" \
  --region eu-central-1 --query 'StandardOutputContent' --output text
```

Expected response: `{"status":"Healthy",...}` with `npgsql` and `ReadonlyNpgSql` both Healthy (for services with DB). Services without a database will only show `self` as Healthy.

**Note:** API endpoints (beyond `/health`) require API versioning headers that are normally set by the gateway. Full API endpoint testing is deferred to P3-S6 (end-to-end validation) after the gateway is deployed (P3-S5-24).

### 3.6 End-to-End Validation (Temporary Domain)

Test everything via `*.production-eu.tickets.mdlbeast.net` — no live DNS is affected.

- [ ] API Gateway responds at `api.production-eu.tickets.mdlbeast.net`
- [ ] Geidea webhook endpoint responds at `geidea.production-eu.tickets.mdlbeast.net`
- [ ] Internal services resolving via private DNS (`*.internal.production-eu.tickets.mdlbeast.net`)
- [ ] Create event in catalogue
- [ ] Create tickets in inventory
- [ ] Process test order through sales
- [ ] PDF ticket generation (S3 in eu-central-1 with `-eu` buckets)
- [ ] CSV report generation
- [ ] Media upload/download
- [ ] Access control scanning flow
- [ ] Slack notifications arriving (check console links point to eu-central-1)
- [ ] Inter-service event flow (EventBridge → SQS → Consumer)
- [ ] CloudWatch logs populating in eu-central-1
- [ ] Extension deployer creates Lambda in eu-central-1

**Dashboard testing:** Run the Dashboard locally with `.env` pointing to `api.production-eu.tickets.mdlbeast.net` (the temporary domain) to test the full E2E flow against the eu-central-1 backend during this phase. This avoids waiting until Phase 4 (DNS cutover) for the first Dashboard validation.

### Phase 3 Verification Checklist

- [ ] All 11 infrastructure stacks in CREATE_COMPLETE
- [ ] All 23 service stacks deployed per matrix
- [ ] All DB migrations ran successfully
- [ ] Lambda functions responding (test invoke each)
- [ ] EventBridge rules → SQS queues (18 consumers)
- [ ] Internal DNS resolving (`*.internal.production-eu.tickets.mdlbeast.net`)
- [ ] API Gateway endpoints accessible at `api.production-eu.tickets.mdlbeast.net`
- [ ] RDS Proxy connecting to Aurora
- [ ] All 13 failed secrets reconstructed with correct third-party keys

---

## Phase 4: DNS Cutover to Production Domain

**Duration:** 0.5-1 day | **Risk:** CRITICAL | **This is the point of no return for DNS**

After Phase 3 validation passes, cut over from the temporary `production-eu` domain to the real `production` domain. Only the public-facing CDK stacks need redeployment — all backend infrastructure remains unchanged.

### 4.1 Revert Temporary Domain Mapping in CDK

Revert the 7 files changed in Phase 1 Task 16:

| File | Repo | Change back to |
|------|------|---------------|
| `ServerlessApiStackHelper.cs:47` | `ticketing-platform-tools` | `env == "prod" ? "production" : env` |
| `GatewayStack.cs:32` | `ticketing-platform-gateway` | `env == "prod" ? "production" : env` |
| `GatewayStack.cs:107` | `ticketing-platform-gateway` | `env == "prod" ? "production" : env` |
| `InternalHostedZoneStack.cs:15` | `ticketing-platform-infrastructure` | `env == "prod" ? "production" : env` |
| `InternalCertificateStack.cs:15` | `ticketing-platform-infrastructure` | `env == "prod" ? "production" : env` |
| `Geidea ApiStack.cs:32` | `ticketing-platform-geidea` | `env == "prod" ? "production" : env` |
| `Ecwid ApiStack.cs:32` | `ecwid-integration` | `env == "prod" ? "production" : env` |

### 4.1.1 Publish Updated `ticketing-platform-tools` NuGet Package

**`ServerlessApiStackHelper.cs` is consumed via NuGet** — the revert must be published before Phase 4.3 CDK deploys, otherwise stacks will still create `production-eu` domains. Same publish cycle as Phase 1 Task 19:

```bash
cd ticketing-platform-tools

# 1. The revert from 4.1 is already on the hotfix branch.
#    Merge to master to trigger NuGet publish.
git checkout master && git pull
git merge hotfix/region-migration-eu-central-1
git push origin master

# 2. Wait for nuget.yml to complete — note the new version number
#    Monitor: https://github.com/mdlbeasts/ticketing-platform-tools/actions/workflows/nuget.yml

# 3. Bump TP.Tools.* version in the service repos being redeployed in 4.3
#    Only the repos with CDK stacks redeployed in 4.3 need the bump:
NEW_VERSION="1.0.XXXX"  # Replace with actual version from step 2
for repo in \
  ticketing-platform-infrastructure ticketing-platform-gateway \
  ticketing-platform-geidea ecwid-integration \
  ticketing-platform-catalogue ticketing-platform-organizations \
  ticketing-platform-inventory ticketing-platform-pricing \
  ticketing-platform-sales ticketing-platform-access-control \
  ticketing-platform-media ticketing-platform-reporting-api \
  ticketing-platform-transfer ticketing-platform-marketplace-service \
  ticketing-platform-integration ticketing-platform-distribution-portal \
  ticketing-platform-extension-api ticketing-platform-customer-service; do
  find "$repo" -name "*.csproj" -not -path "*/bin/*" -not -path "*/obj/*" \
    -exec grep -l "TP\.Tools\." {} \; | while read f; do
    sed -i '' "s/\"TP\.Tools\.\([^\"]*\)\" Version=\"[^\"]*\"/\"TP.Tools.\1\" Version=\"$NEW_VERSION\"/g" "$f"
  done
  (cd "$repo" && git add -A && git diff --cached --quiet || \
    git commit -m "chore: bump TP.Tools.* to $NEW_VERSION for production domain cutover")
done

# 4. Verify build
cd ticketing-platform-gateway/src/Gateway.Cdk && dotnet build
```

**Note:** The remaining service repos not redeployed in 4.3 (csv-generator, pdf-generator, automations, extension-deployer, extension-executor, extension-log-processor, loyalty) will pick up the new tools version when their branches are merged in Phase 4.5. Their stacks (Consumers, BackgroundJobs) don't create DNS records, so the domain mapping change doesn't affect them.

### 4.2 Create ACM Certificates for Real Domain

```bash
P="--profile AdministratorAccess-660748123249 --region eu-central-1"

# Same request_cert helper as Phase 3.2, but with production domain
# Zone for validation: production.tickets.mdlbeast.net (imported in Phase 2.4)

# Gateway — SSM path uses mapped env name "production", NOT "/prod/tp/"
request_cert "api.production.tickets.mdlbeast.net" "/production/tp/DomainCertificateArn" "production"
request_cert "geidea.production.tickets.mdlbeast.net" "/prod/tp/geidea/DomainCertificateArn" "production"
request_cert "ecwid.production.tickets.mdlbeast.net" "/prod/tp/ecwid/DomainCertificateArn" "production"

# Verify all certs ISSUED
aws acm list-certificates $P \
  --query 'CertificateSummaryList[?contains(DomainName,`production.tickets`)].{Domain:DomainName,Status:Status}'
```

**Note:** The SSM parameters are overwritten with the new cert ARNs — CDK will pick them up on redeploy.

### 4.3 Redeploy Public-Facing Stacks

Only 6 stacks touch DNS/custom domains. The other 17+ stacks (EventBus, SQS, consumers, all service backends, RDS Proxy) are **not redeployed**.

```bash
export AWS_PROFILE=AdministratorAccess-660748123249
export CDK_DEFAULT_ACCOUNT=660748123249
export CDK_DEFAULT_REGION=eu-central-1
export ENV_NAME=prod

# 1. Internal hosted zone (updates private zone to production.tickets.mdlbeast.net)
cd ticketing-platform-infrastructure
cdk deploy TP-InternalHostedZoneStack-prod --require-approval never

# 2. Internal certificate (new wildcard cert for *.internal.production.tickets.mdlbeast.net)
cdk deploy TP-InternalCertificateStack-prod --require-approval never

# 3. Gateway (creates api.production.tickets.mdlbeast.net custom domain + A record)
cd ticketing-platform-gateway/src/Gateway.Cdk
cdk deploy GatewayStack --require-approval never

# 4. Geidea (creates geidea.production.tickets.mdlbeast.net)
cd ticketing-platform-geidea/src/TP.Geidea.Cdk
cdk deploy TP-Geidea-ApiStack-prod --require-approval never

# 5. Ecwid (creates ecwid.production.tickets.mdlbeast.net)
cd ecwid-integration/src/TP.Ecwid.Cdk
cdk deploy TP-ApiStack-ecwid-prod --require-approval never
```

**What happens:** CDK updates API Gateway custom domains from `*.production-eu.tickets.mdlbeast.net` to `*.production.tickets.mdlbeast.net` and creates A records in the existing `production.tickets.mdlbeast.net` hosted zone. DNS goes live for production.

**CRITICAL — Minimize CNAME transition gap:** When InternalHostedZoneStack redeploys above (step 1), the old private hosted zone (`internal.production-eu.tickets.mdlbeast.net`) is **deleted** and a new zone (`internal.production.tickets.mdlbeast.net`) is **created**. Until the ServerlessBackendStack stacks below are redeployed, the new zone has **no CNAME records** — inter-service HTTP calls will get NXDOMAIN errors. To minimize this gap:

1. Steps 1-5 above complete first (creates the new zones, certs, and public custom domains)
2. **Immediately** redeploy all 14 ServerlessBackendStack stacks **in parallel** (they are independent — each only touches its own CNAME record)
3. Verify internal DNS resolution after all stacks complete

```bash
# Redeploy all ServerlessBackendStack stacks IN PARALLEL to minimize CNAME gap.
# Each service creates its CNAME record in the new private hosted zone.
# These are independent — deploy all simultaneously.
# Services: catalogue, organizations, inventory, pricing, sales, access-control,
#   media, reporting-api, transfer, marketplace, integration, distribution-portal,
#   extension-api, customer-service
# Redeploy ONLY the ServerlessBackendStack (not DbMigrator, Consumers, etc.)

# Run all 14 in parallel (example with background jobs):
for service_dir in \
  "ticketing-platform-catalogue/src/TP.Catalogue.Cdk:catalogue" \
  "ticketing-platform-organizations/src/Organizations/TP.Organizations.Cdk:organizations" \
  "ticketing-platform-inventory/src/TP.Inventory.Cdk:inventory" \
  "ticketing-platform-pricing/src/TP.Pricing.Cdk:pricing" \
  "ticketing-platform-sales/src/TP.Sales.Cdk:sales" \
  "ticketing-platform-access-control/src/TP.AccessControl.Cdk:access-control" \
  "ticketing-platform-media/src/TP.Media.Cdk:media" \
  "ticketing-platform-reporting-api/src/TP.ReportingService.Cdk:reporting" \
  "ticketing-platform-transfer/src/TP.Transfer.Cdk:transfer" \
  "ticketing-platform-marketplace-service/src/TP.Marketplace.Cdk:marketplace" \
  "ticketing-platform-integration/src/TP.Integration.Cdk:integration" \
  "ticketing-platform-distribution-portal/src/TP.DistributionPortal.Cdk:dp" \
  "ticketing-platform-extension-api/TP.Extensions.Cdk:extensions" \
  "ticketing-platform-customer-service/src/TP.Customers.Cdk:customers"; do
  dir="${service_dir%%:*}"
  svc="${service_dir##*:}"
  (cd "$dir" && cdk deploy TP-ServerlessBackendStack-$svc-prod --require-approval never) &
done
wait  # Wait for all parallel deploys to finish

# Verify internal DNS resolution
dig +short catalogue.internal.production.tickets.mdlbeast.net
```

### 4.4 Update GitHub Secrets & Variables

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
  ticketing-platform-shared ecwid-integration
  ticketing-platform-configmap-dev ticketing-platform-configmap-sandbox
)
# NOTE: xp-badges, bandsintown-integration, marketing-feeds excluded (deprecated services)

for repo in "${repos[@]}"; do
  gh secret set AWS_DEFAULT_REGION --body "eu-central-1" --repo "mdlbeasts/$repo"
done

# Additional secrets on specific repos
gh secret set AWS_DEFAULT_REGION_PROD --body "eu-central-1" --repo "mdlbeasts/ticketing-platform-terraform-dev"
gh secret set TP_AWS_DEFAULT_REGION_PROD --body "eu-central-1" --repo "mdlbeasts/ticketing-platform-configmap-prod"
gh secret set AWS_DEFAULT_REGION_PROD --body "eu-central-1" --repo "mdlbeasts/ticketing-platform-configmap-prod"
gh secret set CDK_DEFAULT_REGION --body "eu-central-1" --repo "mdlbeasts/ticketing-platform-extension-deployer"

# GitHub variables
gh variable set STORYBOOK_BUCKET_NAME --body "<new-eu-bucket>" --repo "mdlbeasts/ticketing-platform-dashboard"
gh variable set STORYBOOK_CLOUDFRONT_DISTRIBUTION_ID --body "<new-distro-id>" --repo "mdlbeasts/ticketing-platform-dashboard"
```

### 4.5 Merge to Production & Deploy Frontends

- Merge `hotfix/region-migration-eu-central-1` branches to `master`/`production`
- Dashboard: merge `vercel.json` + `.env` changes → triggers Vercel redeploy
- Distribution Portal: merge and verify
- Mobile Scanner: trigger release build

### 4.6 End-to-End Validation (Production Domain)

Full ticket lifecycle test via real `production.tickets.mdlbeast.net` domain:

- [ ] Dashboard login (prod Auth0 + `api.production.tickets.mdlbeast.net`)
- [ ] Create event → create tickets → process order → generate PDF → scan ticket
- [ ] Payment flow (Geidea webhook delivery to `geidea.production.tickets.mdlbeast.net`)
- [ ] CSV report generation
- [ ] Media upload/download
- [ ] Inter-service event flow
- [ ] Slack error notifications (verify console links point to eu-central-1)
- [ ] CloudWatch logs + X-Ray traces in eu-central-1
- [ ] DNS resolution for all public endpoints (`dig api.production.tickets.mdlbeast.net`)
- [ ] Mobile scanner app connects to new backend

### 4.7 Post-Go-Live Monitoring (72 hours)

- CloudWatch dashboards for all services
- Slack error channel for elevated error rates
- Sentry for new error patterns
- RDS metrics (connections, latency, CPU, ACU utilization)
- S3 access patterns
- Lambda cold start frequency

**After 72 hours stable:** Reduce Aurora min ACU back to normal production levels.

### 4.8 Migrate `ticketing-glue-gcp` S3 Bucket

**Context:** The `ticketing-glue-gcp` bucket was missed during the S3 migration — it's not in Terraform, not in the S3 Bucket Naming Strategy table, and only referenced in the automations CDK IAM policies. The AutomaticDataExporter Lambda fails every 11 min because `S3Region` in the secret was updated to `eu-central-1` but the bucket remains in me-south-1.

**Steps:**

1. **Create `ticketing-glue-gcp-eu` bucket in eu-central-1**
   - Block public access, enable AES256 encryption
   - No bucket policy to replicate (old bucket has none — BigQuery Data Transfer uses IAM access keys)

2. **Copy data from old bucket**
   ```bash
   aws s3 sync s3://ticketing-glue-gcp s3://ticketing-glue-gcp-eu \
     --source-region me-south-1 --region eu-central-1
   ```

3. **Update `/prod/automations` secret**
   - `AUTOMATIC_DATA_EXPORTER_CONFIG`: `S3Bucket` → `ticketing-glue-gcp-eu` (`S3Region` already `eu-central-1`)
   - `GEIDEA_DATA_EXPORTER_CONFIG`: same change (Geidea stack is commented out in `Program.cs:35` but update for correctness)

4. **CDK code changes (PR → CI/CD deploys)**
   - `AutomaticDataExporterStack.cs:78-79` — IAM ARN `ticketing-glue-gcp` → `ticketing-glue-gcp-eu`
   - `GeideaDataExporterStack.cs:78-79` — same
   - `AutomaticDataExporterStack.cs` — add `Enabled = false` to `ScheduleProps` to disable scheduler

5. **GCP team handoff** — 16 BigQuery Data Transfer configs in project `127814635375` need S3 source URI updated from `s3://ticketing-glue-gcp/...` to `s3://ticketing-glue-gcp-eu/...`

6. **Re-enable scheduler** — after GCP team confirms, remove `Enabled = false` from CDK, merge new PR

**Note:** The base `LambdaS3PolicyStatement` in TP.Tools grants wildcard `s3:PutObject`/`s3:GetObject` on `*`, so the IAM ARN change is for policy correctness, not a functional blocker for S3 writes.

### 4.9 Fix Stale RDS Endpoint in `FINANCE_REPORT_SENDER_CONFIG`

**Context:** The `FinanceReportSender` Lambda fails with `SocketException: Unknown socket error` (DNS NXDOMAIN) when connecting to PostgreSQL. Root cause: the `FINANCE_REPORT_SENDER_CONFIG` in `/prod/automations` has 3 connection strings pointing to the old Aurora cluster ID (`cocuscg4fsup`) which doesn't exist in eu-central-1. The region portion was correctly updated to `eu-central-1` during the bulk secret migration (P2-S7), but the cluster ID changed because Aurora was restored from backup (new cluster = new ID `c0lac6czadei`).

**Steps:**

1. **Update `/prod/automations` secret**
   - `FINANCE_REPORT_SENDER_CONFIG`: replace `cocuscg4fsup` → `c0lac6czadei` in all 3 connection strings (`ConnectionStringSales`, `ConnectionStringCatalogue`, `ConnectionStringOrganizations`)
   - No other keys in the secret are affected

2. **Force Lambda cold start** to pick up the new secret value

**No code changes needed.** The Lambda reads the secret at startup via `ServiceProviderBuilder.ReadSecrets()`.

---

## Phase 5: Dev+Sandbox Rebuild

**Duration:** 2-3 days | **Risk:** LOW | **Account:** `307824719505` | **Profile:** `AdministratorAccess-307824719505`

Dev and sandbox share the same AWS account. The user has a local sandbox DB dump for seeding. Secrets and SSM parameters are replicated from me-south-1 (backups are last resort). No temporary domain needed — deploy directly under `dev.tickets.mdlbeast.net` and `sandbox.tickets.mdlbeast.net`. me-south-1 stays running.

**Branching strategy:** Production branch has all migration changes. Deployment flows in reverse: `production` → `sandbox` → `development`. For each repo with CDK: create `hotfix/sandbox-eu-migration` from `sandbox`, merge `production` into it, create PR (don't merge yet), do manual CDK deployment, then merge PR. Repeat for dev via `hotfix/dev-eu-migration`.

**Detailed plan:** `.personal/tasks/2026-03-05_aws-region-migration/plan-phase-5.md` — contains 13 steps (P5-S1 through P5-S13) with complete CLI commands, all 22 lessons from production incorporated, branching strategy, merge group instructions, and verification procedures.

### Summary of Steps

| Step | Description |
|------|-------------|
| P5-S1 | Pre-flight: Fix Terraform S3 bucket names (add `-eu` suffix to `s3.tf`, `variables.tf`, `mobile.tf`) |
| P5-S2 | Pre-flight: Fix VPC DNS, RDS SG ingress, CloudFront bucket policies, cicd IAM, uncomment RDS cluster |
| P5-S3 | Terraform foundation: quotas, state bucket, terraform secret, import Route53 zones + global resources, apply, set Serverless v2 scaling |
| P5-S4 | Replicate secrets from me-south-1, promote to standalone |
| P5-S5 | Replicate SSM parameters from me-south-1, override infrastructure values with eu-central-1 equivalents |
| P5-S6 | Update RDS secret with endpoint, user populates DB manually via SSM tunnel, create DynamoDB Cache table |
| P5-S7 | Update CONNECTION_STRINGS and region-dependent secrets (blanket me-south-1 → eu-central-1) |
| P5-S8 | CDK bootstrap, delete stale Route53 A records, create 6 ACM certificates (3 per env) |
| P5-S9 | Deploy infrastructure CDK (11 stacks × 2 envs), bulk-delete stale IAM inline policies first |
| P5-S10 | Deploy per-service CDK stacks: create PRs (don't merge), manual CDK deployment with IAM import, then merge |
| P5-S11 | Update GitHub environment-level secrets for dev + sandbox |
| P5-S12 | Merge PRs in 6 groups (tools → infrastructure → templates → terraform → services by tier → gateway + frontends) |
| P5-S13 | End-to-end validation for both environments |

---

## Post-Migration Tasks

### Temporary Domain Cleanup

After Phase 4 DNS cutover is validated and stable:

```bash
P="--profile AdministratorAccess-660748123249"

# 1. Delete the temporary hosted zone
TEMP_ZONE_ID=$(aws route53 list-hosted-zones $P \
  --query "HostedZones[?Name=='production-eu.tickets.mdlbeast.net.'].Id" --output text | sed 's|/hostedzone/||')

# First delete all records in the zone (except NS and SOA)
# Then delete the zone itself
aws route53 delete-hosted-zone --id "$TEMP_ZONE_ID" $P

# 2. Remove NS delegation record from parent zone (tickets.mdlbeast.net)
PARENT_ZONE_ID=$(aws route53 list-hosted-zones $P \
  --query "HostedZones[?Name=='tickets.mdlbeast.net.'].Id" --output text | sed 's|/hostedzone/||')
aws route53 change-resource-record-sets --hosted-zone-id "$PARENT_ZONE_ID" $P \
  --change-batch '{
    "Changes": [{
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "production-eu.tickets.mdlbeast.net",
        "Type": "NS",
        "TTL": 300,
        "ResourceRecords": [...]
      }
    }]
  }'

# 3. Delete temporary ACM certificates (the production-eu ones)
# List and delete certs containing "production-eu"
aws acm list-certificates --profile AdministratorAccess-660748123249 --region eu-central-1 \
  --query 'CertificateSummaryList[?contains(DomainName,`production-eu`)].CertificateArn' --output text | \
  tr '\t' '\n' | while read arn; do
    aws acm delete-certificate --certificate-arn "$arn" \
      --profile AdministratorAccess-660748123249 --region eu-central-1
  done
```

### Extension Lambda Redeployment

Existing extension Lambdas from me-south-1 no longer exist. Extension metadata survives in the restored Aurora database. Redeploy all active extensions to eu-central-1. Do this after Phase 3.6 validation (temporary domain) or Phase 4.6 (production domain).

```bash
P="--profile AdministratorAccess-660748123249 --region eu-central-1"

# 1. Verify extension-deployer SSM parameter exists
aws ssm get-parameter --name "/prod/tp/extensions/EXTENSION_DEFAULT_ROLE" $P

# 2. Query extension-api for all deployed extensions
# (via API or direct DB query against restored Aurora)
# Look for extensions with deploymentStatus = Deployed

# 3. For each extension, trigger redeployment:
# Option A: Call extension-api update endpoint for each extension
# Option B: Publish ExtensionChangeEvent to SQS for each extension
# The deployer Lambda (now in eu-central-1) will recreate Extension_{id} Lambdas
```

Do this after Phase 3.6 validation (prod) and Phase 5.3 (dev/sandbox).

---

## Post-Migration Cleanup

### Data Stores (after 7-day stability)
- [ ] Schedule me-south-1 KMS key deletion (7-day minimum wait) — once region recovers
- [ ] Verify all S3 data restored completely (compare object counts if possible)
- [ ] Configure AWS Backup cross-region policy in eu-central-1 (avoid repeating single-region risk)

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
| **6 secrets failed backup — must be reconstructed** | **MEDIUM** | **HIGH** | Only access-control, catalogue, customers, dp, ecwid, terraform truly failed. Reconstruct from password managers, vendor dashboards. See `secrets-reconstruction.md`. **Blocker for prod go-live if third-party keys (HyperPay, Ecwid, Anchanto) cannot be recovered.** |
| **AWS Backup restore fails or data is stale** | LOW | CRITICAL | Last RDS snapshot: 2026-03-23 19:40 UTC+8. Test restore on dev first. |
| **IAM credentials in secrets need regeneration** | HIGH | HIGH | Multiple services store `AWS_ACCESS_KEY`/`AWS_ACCESS_SECRET` in Secrets Manager. New Terraform creates new IAM CICD user — old credentials invalid. Must generate new keys and update all service secrets in Phase 3.3. |
| CDK deploy fails (missing bootstrap) | ~~HIGH~~ RESOLVED | CRITICAL | CDK bootstrap added as Phase 2.8 and 4.9 |
| Gateway/Geidea/XpBadges/Bandsintown/MarketingFeeds CDK fails (missing cert SSM) | ~~HIGH~~ RESOLVED | HIGH | All 5 ACM certs + SSM params added to Phase 3.1 and 5.1 |
| CI/CD deploys to wrong region (missed secrets) | ~~MEDIUM~~ RESOLVED | HIGH | All 4 GitHub secrets updated in Phase 3.5 |
| CDK stack deployment fails (wrong pattern) | ~~HIGH~~ RESOLVED | MEDIUM | Per-service matrix replaces generic template |
| Duplicate Route53 hosted zones | ~~HIGH~~ RESOLVED | HIGH | Terraform import of existing zones added to Phase 2.4 and 4.5 |
| Terraform creates empty RDS cluster conflicting with backup restore | ~~CRITICAL~~ RESOLVED | CRITICAL | RDS cluster/instance resources commented out in Phase 1 Task 9; restored from backup in 2.6/4.7; `terraform import` + uncomment after restore |
| Aurora outside Terraform state | ~~HIGH~~ RESOLVED | HIGH | Terraform import added immediately after restore in Phase 2.6 and 4.7 |
| Missing SSM parameter | MEDIUM | HIGH | Full SSM inventory table in 2.5; 16 manual params enumerated |
| Cold Aurora with prod load | MEDIUM | HIGH | Increase min ACU during go-live week; restore gives warm data |
| Extension Lambdas orphaned in me-south-1 | MEDIUM | MEDIUM | Document redeployment requirement; verify deployer uses `AWS_REGION` env var |
| S3 bucket naming collision | LOW | MEDIUM | Using `-eu` suffix strategy; old buckets in down region don't conflict |
| eu-central-1 service limits | LOW | HIGH | Pre-check quotas in 2.1 and 4.1 |
| Cold Lambda performance post-go-live | MEDIUM | MEDIUM | Consider provisioned concurrency for gateway/sales |
| Storybook deployment broken | MEDIUM | LOW | Migrate S3 + CloudFront; update GitHub vars |
| S3 lifecycle on wrong bucket (dev) | LOW | LOW | Fixed in Phase 1 |
| No AWS Backup policy in new region | MEDIUM | HIGH | Configure cross-region backup policy in eu-central-1 post-migration to avoid repeating single-region risk |

---

*Plan created: 2026-03-05*
*Revised: 2026-03-24 — me-south-1 down (disaster recovery), EKS deprecated, Redis/OpenSearch removed, CDK bootstrap added, per-service CDK matrix, CI/CD templates audited*
*Revised: 2026-03-24 — Comprehensive secrets/SSM inventory (13 failed backups identified), Route53 zone import (no duplicate zones), Aurora Terraform import, 5 ACM certificates (was 2), detailed connection string procedure, tiered service deployment order, expanded risk matrix*
*Revised: 2026-03-24 — Fixed Terraform/RDS ordering (comment out cluster → restore from backup → import), added --profile to all AWS CLI commands, added ACM DNS validation procedure, fixed dependency chain (terraform secret → terraform apply → backup restore → import), added Phase 2 IAM credential generation checkpoint*
*Revised: 2026-03-24 — Restructured to production-first with temporary `production-eu.tickets.mdlbeast.net` domain. New phase order: Phase 1 (code) → Phase 2 (prod foundation) → Phase 3 (prod services under temp domain) → Phase 4 (DNS cutover) → Phase 5 (dev/sandbox fresh rebuild). Fixed MarketingFeeds/Bandsintown domain bug (used `prod` instead of `production`). Added temp zone cleanup to post-migration.*
*Revised: 2026-03-24 — Production code validation: Fixed Gateway SSM cert path (uses `/production-eu/tp/` not `/prod/tp/`), added GatewayStack:107 to domain mapping updates, added ecwid-integration throughout, excluded xp-badges/bandsintown/marketing-feeds (deprecated), fixed CONNECTION_STRINGS format (JSON dict, not plain string), corrected database names from backup (inventoryprod, extension), updated aws-lambda-tools count to 42, added S3 bucket name vars to env-var updates, swapped Slack/XRay deployment order, fixed Phase 3.5 `-dev` → `-prod` suffix, fixed Phase 2.5 subnet tags (dev → prod), added customer-service/automations to Category 2*
*Based on research in: `.planning/research/{ARCHITECTURE,PITFALLS,STACK}.md`*
*Review document: `.personal/tasks/2026-03-05_aws-region-migration/review.md`*
