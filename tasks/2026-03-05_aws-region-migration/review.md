# AWS Region Migration Plan Review

**Plan:** `.personal/tasks/2026-03-05_aws-region-migration/plan.md`
**Reviewed:** 2026-03-05 (Round 3 — deep infrastructure validation)
**Method:** 12 parallel exploration agents across 30+ service repositories covering CDK bootstrap, SQS/ARNs, CI/CD workflows, Lambda runtimes, Route53/DNS, and Terraform deep analysis

---

## Executive Summary

The migration plan is **well-structured and approximately 70-75% complete**. The reference inventory (Categories 1-10), phased approach, and Aurora Global Database strategy are solid. However, Round 3 uncovered **1 additional critical gap** (CDK bootstrap), **4 new high-priority issues**, and **3 new medium-priority issues** beyond the Round 2 findings. The plan still **does not address the EKS/Kubernetes deployment path**, which remains the single largest gap.

Round 2 corrections (Redis/OpenSearch downgraded to zombie infrastructure) remain valid. Round 3 confirmed several positive findings: no Lambda layers, no Lambda@Edge, all .NET 8 runtime, and CDK code uses environment variables throughout (no hardcoded regions in CDK stacks).

### Verdict by Phase

| Phase | Status | Blockers |
|-------|--------|----------|
| Phase 1 (Code Prep) | ~85% Complete | Dashboard `.env` files, per-service CDK matrix, S3 lifecycle bug |
| Phase 2 (Dev Foundation) | Needs Amendment | **CDK bootstrap missing**, EKS cluster, runners, KMS ordering, certificate SSM params |
| Phase 3 (Dev Services) | Needs Amendment | 8 of 21 services deviate from assumed CDK pattern, Geidea certificate |
| Phase 4 (Dev Cutover) | Needs Amendment | EKS/K8s cutover, runner cutover, ConfigMap updates, extra GitHub secrets |
| Phase 5 (Prod Foundation) | Needs Amendment | CDK bootstrap, EKS, runners, WAF hardcoded ARNs |
| Phase 6 (Prod Cutover) | Needs Amendment | Same as Phase 4 for production |
| Post-Migration | Incomplete | EKS cleanup, runner decommission, Terraform state in git |

### Gap Severity Summary

| Severity | Count | IDs |
|----------|-------|-----|
| CRITICAL | 4 | GAP-1 (EKS), GAP-4 (Runners), GAP-5 (CI/CD Templates), **GAP-6 (CDK Bootstrap)** |
| HIGH | 6 | GAP-2 (Redis), GAP-3 (OpenSearch), **ISSUE-15 (Geidea cert)**, **ISSUE-16 (Gateway cert SSM)**, **ISSUE-17 (Storybook deploy)**, **ISSUE-18 (Extra GitHub secrets)** |
| Medium-High | 4 | ISSUE-1 through ISSUE-4 |
| Medium | 10 | ISSUE-5 through ISSUE-11, **ISSUE-14 (S3 lifecycle bug)**, **ISSUE-19 (tfstate in git)**, **ISSUE-20 (Extension deployer runtime Lambdas)** |

---

## Critical Gaps (Migration Blockers)

### GAP-1: EKS Cluster & Kubernetes Migration Not Addressed

**Severity:** CRITICAL | **Phases Affected:** 2, 3, 4, 5, 6 | **Validated:** YES (confirmed via codebase exploration)

The plan focuses exclusively on Lambda/serverless migration but **completely omits the EKS/Kubernetes deployment path**. The platform operates a **hybrid deployment model** — services run as both Lambda functions AND EKS pods simultaneously.

**15 services confirmed running on EKS** (via Helm charts + ConfigMap manifests):
access-control, catalogue, distribution-portal, extensions/extension-api, gateway, geidea, integration, inventory, loyalty, media, organizations, pricing, reporting-api, sales, transfer

**Evidence — Helm charts present in:**
- `ticketing-platform-gateway/helm/`
- `ticketing-platform-inventory/helm/`
- `ticketing-platform-access-control/helm/`
- (12 more service directories with `helm/` subdirectories)

**Evidence — Active Kubernetes networking via `.svc.cluster.local`:**
```yaml
# ticketing-platform-configmap-prod/manifests-new/gateway.yml
OrganizationServiceBaseRoute: "http://organizations.ticketing.svc.cluster.local:5000"
CatalogueServiceBaseRoute: "http://catalogue.ticketing.svc.cluster.local:5000"
InventoryServiceBaseRoute: "http://inventory.ticketing.svc.cluster.local:5000"
```

**15 hardcoded region references across Kubernetes manifests:**

| Environment | Files with `me-south-1` |
|---|---|
| Dev | `manifests/access-control-dev.yml:23`, `integration-dev.yml:38`, `media-dev.yml:17`, `reporting-dev.yml:18`, `sales-dev.yml:29`, `transfer-dev.yml:18`, `secretstore.yml:9` |
| Sandbox | `manifests/integration-sandbox.yml:32`, `media-sandbox.yml:18`, `reporting-sandbox.yml:18`, `sales-sandbox.yml:29`, `transfer-sandbox.yml:18`, `secretstore.yml:10` |
| Prod | `manifests-new/integration.yml:36`, `media.yml:20`, `reporting.yml:18`, `transfer.yml:18` |

**External Secrets Operator (ESO) — region-bound:**
```yaml
# ticketing-platform-configmap-dev/secretstore.yml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
spec:
  provider:
    aws:
      service: SecretsManager
      region: me-south-1  # ESO will pull secrets from wrong region post-migration
```

**IRSA (IAM Roles for Service Accounts) — not Terraform-managed:**
```bash
# ticketing-platform-configmap-dev/sa.yml
eksctl create iamserviceaccount \
  --name eks-secret-manager-sandbox \
  --namespace ticketing-sandbox \
  --cluster eks \
  --role-name "eks-secret-manager-sandbox" \
  --attach-policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
```

**ALB Ingress Controller (prod):**
```yaml
# ticketing-platform-configmap-prod/ingress.yml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    kubernetes.io/ingress.class: alb
```

**Missing from the plan:**
- EKS cluster creation in eu-central-1 (current cluster: `eks` / `eks-prod`)
- Helm chart deployments to new cluster
- ECR image migration or rebuild
- IRSA setup for Secrets Manager access (not Terraform-managed, uses `eksctl`)
- Ingress controller and ALB configuration
- Kubernetes namespace creation (`ticketing-dev`, `ticketing-sandbox`, `ticketing`)
- ExternalSecret operator installation and `SecretStore` region update
- OIDC provider endpoints (region-specific)

**Critical note:** EKS cluster resource (`aws_eks_cluster`) is **not defined in Terraform** — likely created outside Terraform or via a different tool. Only subnets, IAM policies, and networking exist in Terraform.

**Impact:** If only Lambda migration is done, EKS pods will continue pointing to me-south-1 infrastructure, causing split-brain data inconsistency.

**Recommendation:** This is a binary decision point:
1. **If EKS is retained:** Add a full EKS migration sub-phase (cluster creation, Helm deploys, IRSA, ingress, ESO, ConfigMap updates)
2. **If EKS is being deprecated:** Explicitly document this decision, plan the cutover to Lambda-only, and clean up ConfigMap repos

---

### GAP-4: Self-Hosted GitHub Runners Migration

**Severity:** CRITICAL | **Phases Affected:** 4, 6 | **Validated:** YES

ConfigMap CI/CD workflows run on **self-hosted runners** deployed as EC2 instances in me-south-1. These runners execute `aws eks update-kubeconfig --name eks` and `kubectl apply`.

**Runner infrastructure confirmed in Terraform:**

| File | EC2 Instances | Instance Type |
|---|---|---|
| `terraform-dev/dev/runner.tf` | `runner-1a`, `runner-1b`, `runner-mobile` | t3.micro, t3.micro, t3.medium |
| `terraform-prod/prod/runner.tf` | `runner-1a`, `runner-1b`, `runner-mobile` | t3.micro, t3.micro, t3.medium |

Runner subnets: `10.10.242.0/24` (1a), `10.10.241.0/24` (1b), routed via NAT Gateway.

**Workflow-to-runner mapping:**

| Workflow | Runner Label | Purpose |
|---|---|---|
| `configmap-dev/.github/workflows/ci.yml` | `dev` | EKS deployment (dev) |
| `configmap-sandbox/.github/workflows/ci.yml` | `dev` | EKS deployment (sandbox) |
| `configmap-prod/.github/workflows/ci.yml` | `self-hosted` | EKS deployment (prod) |
| `configmap-prod/.github/workflows/disaster.yml` | `prod` | Disaster recovery EKS |

**All other services (54+ workflows)** use `ubuntu-latest` (GitHub-hosted) — no migration needed for those.

**Impact:** All ConfigMap/EKS deployments will break post-cutover.

**Recommendation:** Add runner migration as prerequisite:
1. Provision new EC2 runner instances in eu-central-1 VPC (via Terraform)
2. Install GitHub Actions Runner with matching labels (`dev`, `self-hosted`, `prod`)
3. Configure IAM role for EKS access in eu-central-1
4. Test runner connectivity to eu-central-1 EKS cluster
5. Deregister me-south-1 runners after cutover

---

### GAP-5: Template CI/CD Repository Not Audited

**Severity:** CRITICAL | **Phases Affected:** All | **Validated:** YES — dependency scope confirmed, repo does NOT exist locally

**Round 3 confirmation:** `ticketing-platform-templates-ci-cd` does **not exist as a cloned directory** in the monorepo. It is referenced exclusively as `mdlbeasts/ticketing-platform-templates-ci-cd@master` from 30+ service workflows.

**22 services** reference reusable workflows:

| Template Workflow | Used By | Count |
|---|---|---|
| `tests.yml@master` | 18 backend services | Test runner |
| `deploy-cdk.yml@master` | 18+ services | CDK deployment orchestrator |
| `cloudwatch-logs-creator.yml@master` | 19 services | Log group creation |
| `blazemeter.yml@master` | 14 services | Performance testing |

**Good news:** All consuming workflows properly use `${{ secrets.AWS_DEFAULT_REGION }}` (never hardcoded). However, the templates themselves remain unaudited and could contain:
- Hardcoded region references
- Region-specific S3 bucket paths for Lambda artifact staging
- CDK synthesis commands with embedded region

**Impact:** Even after updating all service repos, the shared template could override region settings.

**Recommendation:** Clone and audit `ticketing-platform-templates-ci-cd` before Phase 1. Include it in the migration scope.

---

### GAP-6 (NEW): CDK Bootstrap Missing from Plan

**Severity:** CRITICAL | **Phases Affected:** 3, 5 | **Validated:** YES — all 23 CDK services confirmed

The migration plan **does not mention `cdk bootstrap` anywhere**. CDK bootstrap is **required** before any `cdk deploy` can succeed in eu-central-1.

**Why bootstrap is required:**
- All 23 services use `Code.FromAsset()` to package .NET 8 Lambda functions as zip files
- CDK uploads these assets to the bootstrap S3 bucket: `cdk-hnb659fds-assets-{account}-{region}`
- Without bootstrap, `cdk deploy` fails with: `"S3 bucket does not exist: cdk-hnb659fds-assets-..."`

**Evidence:**
- `TP.Tools.Infrastructure/Helpers/AwsFunctionBuilder.cs:93` — `Code.FromAsset()`
- `TP.Tools.BackgroundJobs/Stacks/BackgroundJobsStackBase.cs:217` — `Code.FromAsset()`
- All service CDK stacks inherit from these helpers

**No custom synthesizer settings found** — all `cdk.json` files use default configuration. No Docker-based Lambda functions (all zip-based).

**Required commands (must be added before Phase 3):**
```bash
# Dev/Sandbox account
CDK_DEFAULT_ACCOUNT=307824719505 CDK_DEFAULT_REGION=eu-central-1 cdk bootstrap

# Production account (Phase 5)
CDK_DEFAULT_ACCOUNT=660748123249 CDK_DEFAULT_REGION=eu-central-1 cdk bootstrap --profile prod
```

**Bootstrap creates:**
- S3 bucket: `cdk-hnb659fds-assets-{account}-eu-central-1`
- IAM roles for CDK deployment
- CloudFormation stack: `CDKToolkit`

**Recommendation:** Add as Phase 2.8 (between "DynamoDB Tables" and Phase 3 CDK deployments). Also add to Phase 5 before Phase 5.8.

---

## High-Priority Gaps (Revised Severity)

### GAP-2: Redis/ElastiCache — Zombie Infrastructure

**Severity:** ~~CRITICAL~~ -> **HIGH (decision required)** | **Phases Affected:** 5, 6

**Round 2 finding:** Redis infrastructure exists but is **not actively used by any service**.

**Evidence of non-use:**
- `redis.tf` in both dev and prod Terraform is marked with `/// delete` comment
- All `Redis__Host` / `Redis__Password` configuration in ConfigMaps is **commented out** (dev, sandbox, prod)
- `StackExchange.Redis` NuGet package is imported in `TP.Tools.DataAccessLayer` but **never instantiated**
- Redis health check code exists in `HealthCheckExtensions.cs` but is **not called** (not added to the health check builder)
- Platform uses **DynamoDB + in-memory caching** instead (`DynamoDbCacheProvider.cs`, `MemoryCacheProvider.cs`)

**ElastiCache endpoints that DO exist:**
- Dev: `master.ticketing-redis.yxfina.mes1.cache.amazonaws.com`
- Prod: `master.ticketing-redis.azhqp9.mes1.cache.amazonaws.com`

**Impact:** Low for migration — Redis is a zombie resource consuming costs with zero traffic. However:
- If any future feature relies on Redis, it won't exist in eu-central-1
- The Terraform code still references Redis subnets and security groups

**Recommendation:**
1. **Verify via CloudWatch** that Redis has zero connections (check `CurrConnections` metric)
2. If confirmed unused: skip Redis migration, add to post-migration cleanup (delete clusters)
3. If unexpectedly used: create new cluster in eu-central-1 Terraform (fresh, no data migration — it's a cache)

---

### GAP-3: OpenSearch/Elasticsearch — Ghost Configuration

**Severity:** ~~CRITICAL~~ -> **HIGH (verification required)** | **Phases Affected:** 5, 6

**Round 2 finding:** OpenSearch domains exist and configuration is present in 27+ service ConfigMaps, but **no Serilog Elasticsearch sink NuGet package is installed**.

**Evidence:**
- `opensearch.tf` in prod Terraform is marked with `/// delete` comment
- `TP.Tools.Logger/TP.Tools.Logger.csproj` contains `Serilog.AspNetCore` but **no** `Serilog.Sinks.Elasticsearch` or `Serilog.Sinks.OpenSearch`
- `LoggerSetupHelper.cs` uses `.ReadFrom.Configuration(configuration)` which reads the Elasticsearch config but has **no sink to send to**
- Serilog only uses Console and conditional Debug sinks (verified in code)

**Configuration that references OpenSearch (27+ services in prod ConfigMaps):**
```yaml
Logging__Elasticsearch__Uri: "https://vpc-ticketing-rubur2nvxa2a5leqnxodllwnhq.me-south-1.es.amazonaws.com"
Logging__Elasticsearch__Username: "devops"
Logging__Elasticsearch__Password: "Fr1B.h45B2%0egEBph,t"  # SECURITY: plaintext in sales.yml
Logging__Elasticsearch__Index: "sales"
```

**Region mismatch discovered:** Dev debug settings point to `eu-west-1` (not `me-south-1`):
```json
// ticketing-platform-tools/Debug.Api/appsettings.json
"Uri": "https://search-ticketing-dev-f6dabpbzw4c54xxhabtzdpkh4m.eu-west-1.es.amazonaws.com"
```

**OpenSearch URL is NOT in Dashboard CSP** (`vercel.json`) — correcting the initial review's claim.

**Impact:** Likely low for migration (logs aren't actually going to OpenSearch). But:
- ConfigMap references still need updating to avoid confusion
- If OpenSearch is re-enabled later, wrong endpoints would cause failures
- **Security concern:** Plaintext credentials in `sales.yml` ConfigMap

**Recommendation:**
1. **Verify via CloudWatch** that OpenSearch has zero requests (check `SearchableDocuments`, `IndexingRate`)
2. If confirmed unused: skip OpenSearch migration, add to cleanup phase, remove stale configuration
3. If unexpectedly used: create new domain, snapshot/restore indices, update all endpoints
4. **Immediate:** Remove plaintext credentials from `configmap-prod/manifests-new/sales.yml`

---

## High-Priority Issues

### ISSUE-1: Incomplete Reference Inventory

**Dashboard `.env` files** — Not in the plan. Contain hardcoded API Gateway URLs:

| File | Reference |
|---|---|
| `ticketing-platform-dashboard/.env:9` | `MEDIA_HOST=https://o5ewmhbma8.execute-api.me-south-1.amazonaws.com/sandbox/` |
| `ticketing-platform-dashboard/.env.sandbox:9` | Same `MEDIA_HOST` pattern |
| `ticketing-platform-dashboard/.env.development:10` | API Gateway URL (commented) |
| `ticketing-platform-dashboard/.env.development:28` | `MEDIA_HOST=https://sijnsi3wg5.execute-api.me-south-1.amazonaws.com/prod` |

**Additional launchSettings with RDS, Elasticsearch, and SQS endpoints:**

| File | Reference Type |
|---|---|
| `pricing/launchSettings.json:19` | RDS primary + read-only endpoints |
| `media/appsettings.Development.json:8` | OpenSearch endpoint |
| `media/appsettings.Development.json:17` | RDS endpoint |
| `gateway/launchSettings.json:36,76,114,149` | OpenSearch endpoint (4 profiles) |
| `sales/launchSettings.json:42` | `STORAGE_REGION: me-south-1` |
| `sales/launchSettings.json:43` | SQS queue URL with account ID |
| `extension-api/launchSettings.json:26-27` | 2 SQS queue URLs with account ID |

**Distribution Portal hardcoded region:**
- `distribution-portal/src/TP.DistributionPortal.API/Properties/launchSettings.json:29` — `AWS_REGION: "me-south-1"`

**Additional uncaptured references:**
- `ticketing-platform-tools/UnitTests/Infrastructure/Consumers/LambdaUtilitiesTests.cs:252` — test fixtures with `me-south-1`
- `ticketing-platform-integration/src/TP.Integration.IntegrationTests/.../WhatsAppServiceTests.cs:139` — S3 pre-signed URL
- 3 README.md files in terraform repos (documentation)

**Plan Category 8 correction:** The OpenSearch URL (`vpc-ticketing-...me-south-1.es.amazonaws.com`) is **NOT** in the Dashboard CSP `vercel.json` — initial review was incorrect on this point.

---

### ISSUE-2: Phase 3 Service CDK Variations — Full Deployment Matrix

The plan's generic 4-stack deployment template does not fit **8 of 21 services**. Complete validated matrix:

#### Standard Pattern (13 services — plan is correct)

| Service | Stacks | Has DbMigrator |
|---------|--------|----------------|
| access-control | DbMigrator + Consumers + BackgroundJobs + ServerlessBackend | YES |
| sales | DbMigrator + Consumers + BackgroundJobs + ServerlessBackend | YES |
| inventory | DbMigrator + Consumers + BackgroundJobs + ServerlessBackend | YES |
| reporting-api | DbMigrator + Consumers + BackgroundJobs + ServerlessBackend | YES |
| transfer | DbMigrator + Consumers + BackgroundJobs + ServerlessBackend | YES |
| marketplace-service | DbMigrator + Consumers + BackgroundJobs + ServerlessBackend | YES |
| organizations | DbMigrator + Consumers + BackgroundJobs + ServerlessBackend | YES |
| integration | DbMigrator + Consumers + BackgroundJobs + ServerlessBackend | YES |
| distribution-portal | DbMigrator + Consumers + BackgroundJobs + ServerlessBackend | YES |
| extension-api | DbMigrator + Consumers + BackgroundJobs + ServerlessBackend | YES |
| catalogue | DbMigrator + ServerlessBackend (NO Consumers, NO BackgroundJobs) | YES |
| pricing | DbMigrator + Consumers + ServerlessBackend (NO BackgroundJobs) | YES |
| media | DbMigrator + **MediaStorageStack** + Consumers + BackgroundJobs + ServerlessBackend (5 stacks) | YES |

#### Non-Standard Pattern (8 services — plan needs correction)

| Service | Actual Stacks | Plan Assumption | DbMigrator |
|---------|--------------|-----------------|------------|
| **loyalty** | Consumers + BackgroundJobs ONLY | All 4 stacks | NO |
| **geidea** | Consumers + BackgroundJobs + custom **ApiStack** (HTTP API v2) | All 4 stacks | NO |
| **csv-generator** | **ConsumersStack** ONLY | All 4 stacks | NO |
| **pdf-generator** | **ConsumersStack** ONLY | All 4 stacks | NO |
| **extension-deployer** | **ExtensionDeployerLambdaRoleStack** + **ExtensionDeployerStack** | CDK standard | NO |
| **extension-executor** | **ExtensionExecutorStack** ONLY | CDK standard | NO |
| **extension-log-processor** | **ExtensionLogsProcessorStack** ONLY | CDK standard | NO |
| **gateway** | **GatewayStack** ONLY (REST API + Lambda proxy + Route53 + cert) | CDK standard | NO |

**Impact:** Deploying non-existent stacks will cause CDK errors. Missing stacks (e.g., Media's `MediaStorageStack`) will leave services incomplete.

**Recommendation:** Replace the generic deployment instructions in Phase 3.3 with the above matrix.

---

### ISSUE-3: ACM Certificates Are Region-Specific

**Validated.** Three certificate types need recreation (updated from 2 in Round 2):

1. **Internal certificate** — created by `InternalCertificateStack`:
   - Domain: `internal.{env}.tickets.mdlbeast.net` + `*.internal.{env}.tickets.mdlbeast.net`
   - Stored in SSM: `/{env}/tp/InternalDomainCertificateArn`
   - Used by all services via `ServerlessApiStackHelper.cs:137`

2. **Public/Gateway certificate** — referenced by `GatewayStack`:
   - Domain: `api.{env}.tickets.mdlbeast.net`
   - Read from SSM: `/{env}/tp/DomainCertificateArn`
   - **This SSM parameter must be populated BEFORE GatewayStack deployment** (see ISSUE-16)

3. **Geidea certificate** — referenced by `ApiStack` (see ISSUE-15):
   - Domain: `geidea.{env}.tickets.mdlbeast.net`
   - Read from SSM: `/{env}/tp/geidea/DomainCertificateArn`

**Dependency chain:** VPC -> Private Hosted Zone -> Certificate (DNS validation) -> Service stacks

**Recommendation:** Ensure Phase 3.1 deploys `InternalHostedZoneStack` -> `InternalCertificateStack` in strict order. Verify public hosted zones exist from Phase 2 Terraform before certificate validation. Pre-populate Gateway and Geidea certificate SSM parameters.

---

### ISSUE-4: Dev RDS Has 3 Instances, Plan Says 1

**Validated.** Terraform shows `count = 3` for dev cluster instances. Plan creates only 1 for the Global Database secondary.

**Recommendation:** Create 3 instances for dev, 3 for prod to match current configuration.

---

## Medium-Priority Issues

### ISSUE-5: S3 Bucket Name Verification Needed

**Unchanged.** Run `aws s3 ls --region me-south-1` in both accounts before Phase 2.6.

---

### ISSUE-6: VPC CIDR Overlap During Parallel Operation

**Validated.** Both environments use `10.10.0.0/16`. No VPC peering or Transit Gateway exists in either Terraform configuration. Aurora Global Database handles cross-region replication at the storage level.

**Recommendation:** Document the no-peering constraint. No action needed unless cross-region debugging is required.

---

### ISSUE-7: KMS Key Migration

**Unchanged.** Ensure Terraform creates KMS keys in eu-central-1 (Phase 2.3) before S3 CRR setup (Phase 2.6).

---

### ISSUE-8: CloudFront Distribution Origins

**Severity downgraded** after validation. CloudFront distributions use `bucket_regional_domain_name` (dynamic reference), which auto-resolves to the new region when Terraform recreates the S3 bucket resource.

**Dev:** `cloudfront.tf` -> origin = `aws_s3_bucket.pdf-tickets-sandbox.bucket_regional_domain_name`
**Prod:** `cloudfront.tf` -> origin = `aws_s3_bucket.ticketing.bucket_regional_domain_name`

Both use Origin Access Control (OAC) with SigV4 signing. CloudFront uses **default certificates** — no custom domain certificate migration needed. **No manual CloudFront updates required** — Terraform handles this automatically.

---

### ISSUE-9: Lambda Provisioned Concurrency

**Unchanged.** Consider provisioned concurrency for gateway and sales during first week post-cutover.

---

### ISSUE-10: Service Quota Pre-Checks

**Unchanged.** Add as first step of Phase 2.

---

### ISSUE-11: `demo` Environment Not Addressed

**Unchanged.** Clarify inclusion. Note: `env-var.demo.json` files exist in multiple services (transfer, reporting-api, pricing, integration, marketplace-service) and contain `STORAGE_REGION: me-south-1`.

---

### ISSUE-12: WAF Hardcoded ARNs in Production

**File:** `ticketing-platform-terraform-prod/prod/waf.tf`

Two hardcoded ARNs contain `me-south-1`:
```hcl
alb_arn = "arn:aws:elasticloadbalancing:me-south-1:660748123249:loadbalancer/app/k8s-ticketin-gateway-e8256fe572/a99b2f9b05652280"
# IP set ARN (line 73):
"arn:aws:wafv2:me-south-1:660748123249:regional/ipset/soundstorm/80b4a1ce-1c4c-4c6c-8a56-c86c8afd926f"
```

WAF is regional. ALB must be migrated first, then WAF ACL + IP sets recreated. These ARNs must be replaced with new eu-central-1 resource IDs — they **cannot be simple string replacements**.

**The plan's Category 1 table does list `waf.tf:8,73`** but doesn't detail that the ARNs cannot simply be string-replaced — they reference resources that must exist in eu-central-1 first.

---

### ISSUE-13: Security Concerns Found During Review

| Finding | File | Severity |
|---|---|---|
| Plaintext OpenSearch credentials in prod ConfigMap | `configmap-prod/manifests-new/sales.yml` | HIGH |
| Plaintext OpenSearch credentials in debug settings | `tools/Debug.Api/appsettings.json` | MEDIUM |
| Region mismatch (dev OpenSearch points to `eu-west-1`, not `me-south-1`) | `tools/Debug.Api/appsettings.json` | LOW (informational) |
| **Terraform state files committed to git** (see ISSUE-19) | `terraform-dev/dev/terraform.tfstate`, `terraform-prod/prod/terraform.tfstate` | HIGH |

These should be addressed as part of Phase 1 security remediation.

---

### ISSUE-14 (NEW -- Round 3): S3 Lifecycle Configuration Bug in Dev Terraform

**Severity:** MEDIUM | **Found by:** Terraform deep analysis agent

**File:** `ticketing-platform-terraform-dev/dev/s3.tf:246`

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "bucket-config-dev" {
  bucket = aws_s3_bucket.pdf-tickets-sandbox.bucket  # BUG: References SANDBOX, not DEV
}
```

The dev lifecycle configuration is applied to the **sandbox bucket**, not the dev bucket. The `pdf-tickets-dev` bucket has **no lifecycle configuration**.

**Impact:** Not a migration blocker, but this bug will be carried into eu-central-1 unless fixed. Should be corrected in Phase 1 alongside other Terraform changes.

**Recommendation:** Fix the bucket reference to `aws_s3_bucket.pdf-tickets-dev.bucket` during Phase 1 code preparation.

---

### ISSUE-15 (NEW -- Round 3): Geidea Custom Domain Certificate

**Severity:** HIGH | **Found by:** Route53/DNS agent

**File:** `ticketing-platform-geidea/src/TP.Geidea.Cdk/Stacks/ApiStack.cs`

Geidea has its **own custom domain** separate from the main Gateway:
- Domain: `geidea.{env}.tickets.mdlbeast.net` (line 182)
- Base domain: `{env}.tickets.mdlbeast.net` (line 32)
- Certificate lookup from SSM: `/{env}/tp/geidea/DomainCertificateArn` (line 177)
- Route53 A record created by CDK (lines 196-201)

**The plan does not mention this certificate at all.** It must be:
1. Created in eu-central-1 (ACM certificate for `geidea.{env}.tickets.mdlbeast.net`)
2. Its ARN stored in SSM at `/{env}/tp/geidea/DomainCertificateArn`
3. Completed **before** deploying Geidea's ApiStack

**Impact:** Geidea's CDK deployment will fail if this SSM parameter doesn't exist.

**Recommendation:** Add Geidea certificate creation to Phase 2.4 (SSM parameter population) or as a pre-step before Geidea deployment in Phase 3.3.

---

### ISSUE-16 (NEW -- Round 3): Gateway Public Certificate SSM Parameter

**Severity:** HIGH | **Found by:** Route53/DNS agent

**File:** `ticketing-platform-gateway/src/Gateway.Cdk/Stacks/GatewayStack.cs:108`

The Gateway reads its public certificate ARN from SSM: `/{env}/tp/DomainCertificateArn`. This is the certificate for `api.{env}.tickets.mdlbeast.net`.

**This is NOT created by any CDK stack** — it appears to be created manually or by a process outside the current codebase. The plan's Phase 2.4 (SSM parameter population) lists VPC, RDS, subnet, and Slack webhook parameters but **does not include certificate ARNs**.

**Required SSM parameters for certificates:**

| SSM Path | Purpose | Used By |
|---|---|---|
| `/{env}/tp/DomainCertificateArn` | Public API cert (`api.{env}.tickets.mdlbeast.net`) | GatewayStack |
| `/{env}/tp/InternalDomainCertificateArn` | Internal cert (created by CDK InternalCertificateStack) | All service ServerlessApiStackHelper |
| `/{env}/tp/geidea/DomainCertificateArn` | Geidea cert (`geidea.{env}.tickets.mdlbeast.net`) | Geidea ApiStack |

**Impact:** Gateway CDK deployment will fail without this SSM parameter.

**Recommendation:** Add manual ACM certificate creation + SSM parameter population for both the Gateway public cert and Geidea cert to Phase 2.4. The internal cert is handled by CDK (Phase 3.1), but the other two must be pre-created.

---

### ISSUE-17 (NEW -- Round 3): Storybook S3/CloudFront Deployment

**Severity:** HIGH | **Found by:** CI/CD workflow agent

**File:** `ticketing-platform-dashboard/.github/workflows/storybook-deploy.yml`

The dashboard Storybook is deployed to S3 + CloudFront, **not Vercel**:
- S3 bucket name: `${{ vars.STORYBOOK_BUCKET_NAME }}` (line 35)
- CloudFront distribution ID: `${{ vars.STORYBOOK_CLOUDFRONT_DISTRIBUTION_ID }}` (lines 43, 54, 61)
- Uses `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets

**Not mentioned in the migration plan.** After migration:
1. A new S3 bucket must be created in eu-central-1 for Storybook
2. A new CloudFront distribution must be created (or existing one updated)
3. GitHub repository **variables** (not secrets) must be updated: `STORYBOOK_BUCKET_NAME`, `STORYBOOK_CLOUDFRONT_DISTRIBUTION_ID`

**Impact:** Storybook deployments will fail post-migration until these resources are migrated.

**Recommendation:** Add Storybook infrastructure to Phase 2 Terraform or Phase 3 as a separate step. Update GitHub variables in Phase 4.5.

---

### ISSUE-18 (NEW -- Round 3): Plan's GitHub Secret Update Incomplete

**Severity:** HIGH | **Found by:** CI/CD workflow agent

The plan's Phase 4.5 only updates `AWS_DEFAULT_REGION` across repos. However, multiple **additional GitHub secrets** contain region information:

| Secret Name | Used By | Current Value |
|---|---|---|
| `AWS_DEFAULT_REGION` | 34+ services | `me-south-1` |
| `AWS_DEFAULT_REGION_PROD` | terraform-dev workflows | `me-south-1` |
| `TP_AWS_DEFAULT_REGION_PROD` | configmap-prod workflows | `me-south-1` |
| `CDK_DEFAULT_REGION` | extension-deployer | `me-south-1` |

**The plan's Phase 4.5 script only updates `AWS_DEFAULT_REGION`** — missing the other 3 secrets.

Additionally, GitHub repository **variables** (not secrets) need updating:
- `STORYBOOK_BUCKET_NAME` (dashboard)
- `STORYBOOK_CLOUDFRONT_DISTRIBUTION_ID` (dashboard)

**Impact:** ConfigMap prod deployments and extension-deployer CDK deployments will target the wrong region.

**Recommendation:** Expand Phase 4.5 script to include all 4 secrets. Add a separate step for GitHub variables.

---

### ISSUE-19 (NEW -- Round 3): Terraform State Files Committed to Git

**Severity:** MEDIUM (security concern) | **Found by:** Terraform agent

**Files found:**
- `ticketing-platform-terraform-dev/dev/terraform.tfstate`
- `ticketing-platform-terraform-dev/dev/terraform.tfstate.backup`
- `ticketing-platform-terraform-prod/prod/terraform.tfstate`
- `ticketing-platform-terraform-prod/prod/terraform.tfstate.backup`
- `ticketing-platform-terraform-prod/terraform.tfstate` (root level)

Terraform state files contain **sensitive data** (database passwords, API keys from Secrets Manager). These should NOT be committed to git — they should be stored only in the S3 backend.

**Impact:** Not a migration blocker, but these files may contain me-south-1 state that could cause confusion. More importantly, they expose secrets in git history.

**Recommendation:** Add `.tfstate` and `.tfstate.backup` to `.gitignore` in both Terraform repos during Phase 1.

---

### ISSUE-20 (NEW -- Round 3): Extension Deployer Creates Runtime Lambdas

**Severity:** MEDIUM | **Found by:** Lambda layers agent

**File:** `ticketing-platform-extension-deployer/TP.Extensions.Deployer/Services/Lambda/LambdaService.cs:155`

The Extension Deployer creates **Node.js 18 Lambda functions at runtime** (not via CDK). These are user-defined extension functions deployed dynamically.

**Concern:** The region for these runtime-created Lambdas likely comes from the AWS SDK default region (set via `AWS_REGION` environment variable on the deployer Lambda). If the deployer Lambda is correctly deployed to eu-central-1, the runtime-created Lambdas should also go to eu-central-1.

**However:** Any **existing** extension Lambdas created in me-south-1 will remain there unless explicitly migrated or recreated.

**Recommendation:** Verify that extension deployer uses `AWS_REGION` from environment (not hardcoded). Document that existing user extensions in me-south-1 will need to be redeployed post-migration.

---

## Confirmed Items (Plan Is Correct)

### Reference Inventory
- All Terraform file references and line numbers verified
- All ~40 CDK env-var JSON files confirmed (56 files total across all envs)
- All 33 aws-lambda-tools-defaults.json files confirmed
- Infrastructure C# fallback values confirmed (`EnvironmentService.cs:24`, `XRayInsightSlackService.cs:58`)
- ConfigMap YAML files confirmed (but Kubernetes manifests have additional references -- see GAP-1)
- Mobile Scanner CI (3 references in `release-build.yml`) confirmed
- Dashboard CSP (`vercel.json`) -- 6 S3 URLs confirmed; OpenSearch URL is NOT present (correcting initial review)
- CDK context cache files (3 files) confirmed
- Bulk update scripts are correct and safe

### Architecture
- Aurora Global Database approach is sound for zero-data-loss migration
- S3 Cross-Region Replication strategy is correct
- Greenfield infrastructure approach (new Terraform state) avoids state conflicts
- EventBridge/SQS naming is region-agnostic -- no hardcoded region in CDK event constructs
- Extended message S3 bucket naming is environment-based, not region-based
- 18 consumer services confirmed via `ConsumersServices` enum
- CDK infrastructure stack list (11 stacks) matches codebase exactly
- SSM parameter population list is comprehensive (but needs certificate additions -- see ISSUE-16)
- Secrets Manager replication approach is correct
- DynamoDB tables are indeed CDK-managed/ephemeral
- **CloudFront distributions use dynamic bucket references** -- auto-resolve to new region (low risk)
- **CloudFront uses default certificates** -- no custom domain certificate migration needed
- **API Gateway VPC Endpoint** stored in SSM -- auto-updated by CDK (low risk)
- **No VPC peering or Transit Gateway** -- CIDR overlap is safe

### Lambda & Runtime (NEW -- Round 3 Confirmations)
- **No Lambda layers used** across any service -- simplifies migration significantly
- **No Lambda@Edge functions** -- no us-east-1 constraint
- **All services use Runtime.DOTNET_8** -- consistent, no legacy runtime concerns
- **No Docker-based Lambda functions** -- all use zip packaging via `Code.FromAsset()`
- **CDK region config exclusively uses `CDK_DEFAULT_REGION` env var** -- no hardcoded regions in any CDK C# code
- **Lambda permissions use `Stack.Region` property** -- dynamically resolves to target region
- **CloudWatch subscription filters use dynamic references** -- no region hardcoding
- **SNS topic** (XRay insight alarm) is CDK-managed with dynamic naming -- no migration concern
- **EventBridge rules use dynamic patterns** -- no region-specific matching

### CI/CD
- All .NET service workflows properly use `AWS_DEFAULT_REGION` via GitHub secrets (never hardcoded)
- CDK programs read `CDK_DEFAULT_REGION` from environment variables
- GitHub secret update script (Phase 4.5) repo list is complete (but missing 3 additional secrets -- see ISSUE-18)
- Deployment freeze during transition is correctly identified as necessary
- **No ECR login/push commands** found in any workflow files
- **No Docker build/push in any workflow** -- all Lambda packaging is via `dotnet lambda package`
- Template workflows pin to `@master` -- will auto-propagate changes
- Dashboard and Distribution Portal Frontend deploy via **Vercel** (region-agnostic)
- **Dashboard Storybook deploys via S3 + CloudFront** (region-dependent -- see ISSUE-17)

### Third-Party Integrations
- Auth0 is SaaS and region-agnostic (no changes needed)
- Checkout.com, SendGrid, Sentry, Seats.io -- all SaaS, no region dependency
- Internal service URLs use environment-specific domain names (not IP/region-specific)

### Terraform (NEW -- Round 3 Confirmations)
- AWS provider version 4.67.0 is region-agnostic -- works in eu-central-1
- Terraform modules (eventbridge, route53, waf) are region-agnostic
- Account ID hardcoding in IAM policies (dev `group.tf:49`, prod `user-cicd.tf:29-33`) is correct -- account-level, not region-specific
- No `data "aws_availability_zones"` lookups -- AZs are hardcoded (already in plan)
- No Terraform modules with region assumptions
- Dev and prod have different resource footprints (prod has OpenSearch, Redis, WAF, EKS subnets that dev lacks)

---

## Recommendations Summary

### Before Starting Phase 1 (Decision Points)

1. **DECISION: EKS migration strategy** -- retain (full migration) or deprecate (Lambda-only)? This is the single largest scope question.
2. **Audit `ticketing-platform-templates-ci-cd`** -- clone, search for region references, include in migration scope
3. **Verify Redis/OpenSearch usage** -- check CloudWatch metrics (`CurrConnections`, `SearchableDocuments`) to confirm zombie status
4. **Run `aws s3 ls`** in both accounts to verify exact bucket names
5. **Check eu-central-1 service quotas** and request increases
6. **Clarify `demo` environment** inclusion

### Amendments to Each Phase

**Phase 1:**
- Add Dashboard `.env`, `.env.sandbox`, `.env.development` to reference inventory
- Add `ticketing-platform-templates-ci-cd` repo to scope
- Add `sales/launchSettings.json`, `distribution-portal/launchSettings.json` to Category 10
- Add `gateway/launchSettings.json` Elasticsearch endpoints (4 profiles) to Category 10
- Add security remediation: remove plaintext credentials from `configmap-prod/manifests-new/sales.yml`
- Add `.tfstate` files to `.gitignore` in both Terraform repos
- Fix S3 lifecycle bug in `dev/s3.tf:246` (references sandbox bucket instead of dev)
- Replace generic Phase 3.3 instructions with per-service deployment matrix

**Phase 2:**
- **Add CDK bootstrap as Phase 2.8** -- `cdk bootstrap` in eu-central-1 for dev/sandbox account
- **Add manual ACM certificate creation** for Gateway (`api.{env}`) and Geidea (`geidea.{env}`) domains + SSM parameters (`/{env}/tp/DomainCertificateArn`, `/{env}/tp/geidea/DomainCertificateArn`)
- Add EKS cluster creation (if retained) -- cluster, node groups, IRSA, ESO, namespaces
- Add self-hosted runner EC2 provisioning in eu-central-1
- Add explicit KMS key creation verification before S3 CRR (Phase 2.6)
- Match dev RDS instance count to 3
- Add service quota pre-check as first step
- Add Storybook S3 bucket + CloudFront distribution creation

**Phase 3:**
- Use per-service CDK deployment matrix (see ISSUE-2)
- Handle Media's additional `MediaStorageStack`
- Handle Geidea's custom `ApiStack` (HTTP API v2, not ServerlessBackend) -- requires Geidea certificate
- Handle Loyalty (no API, no DB), CSV/PDF generators (ConsumersStack only)
- Handle Extension services (custom stack patterns)
- Handle Gateway (single GatewayStack with REST API + Route53) -- requires Gateway certificate
- Note ACM certificate timing: `InternalHostedZoneStack` -> `InternalCertificateStack` strict order

**Phase 4:**
- Add EKS cluster cutover (if retained): Helm deploys, ConfigMap updates, Ingress/ALB
- Add self-hosted runner cutover: deregister me-south-1 runners, verify eu-central-1 runners
- Add ConfigMap `secretstore.yml` region update (all 3 environments)
- Add ConfigMap manifest `STORAGE_REGION` updates (15 files)
- **Expand GitHub secrets update to include all 4 secrets:** `AWS_DEFAULT_REGION`, `AWS_DEFAULT_REGION_PROD`, `TP_AWS_DEFAULT_REGION_PROD`, `CDK_DEFAULT_REGION`
- **Add GitHub variables update:** `STORYBOOK_BUCKET_NAME`, `STORYBOOK_CLOUDFRONT_DISTRIBUTION_ID`
- Document that existing user extension Lambdas in me-south-1 need redeployment

**Phase 5:**
- **Add CDK bootstrap** for production account in eu-central-1
- Add EKS cluster creation for prod
- Add runner provisioning for prod
- Expand WAF section: note that ALB ARN and IP set ARN are hardcoded, must be replaced with new resource IDs
- Document Redis/OpenSearch as zombie infrastructure (skip migration, add to cleanup)
- Add manual ACM certificates for prod Gateway and Geidea domains

**Phase 6:**
- Same as Phase 4 additions, applied to production
- Add prod-specific EKS Ingress/ALB validation

**Post-Migration:**
- Add EKS old cluster cleanup (if migrated) or full deprecation (if Lambda-only)
- Add self-hosted runner decommission in me-south-1
- Add Redis cluster deletion (both accounts -- unused)
- Add OpenSearch domain deletion (both accounts -- likely unused)
- Add stale ConfigMap configuration cleanup (commented Redis refs, unused Elasticsearch config)
- Add CloudFront origin verification (should be automatic but verify)
- Add Storybook verification (S3 + CloudFront)
- Remove committed `.tfstate` files from git history (consider `git filter-branch` or BFG)

---

## Risk Matrix (Updated -- Round 3)

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **CDK deploy fails (no bootstrap)** | **HIGH** | **CRITICAL** | **Add `cdk bootstrap` to Phase 2.8 and Phase 5** |
| EKS pods still pointing to me-south-1 | HIGH | CRITICAL | Include EKS migration in plan; update all ConfigMaps + secretstore.yml |
| Self-hosted runners offline | HIGH | HIGH | Pre-provision runners in eu-central-1; verify EKS connectivity |
| Template CI/CD has region hardcoding | MEDIUM | HIGH | Audit template repo before Phase 1 |
| **Gateway/Geidea CDK fails (missing cert SSM)** | **HIGH** | **HIGH** | **Pre-create ACM certs + SSM params before CDK deploy** |
| CDK stack deployment fails (wrong pattern) | HIGH | MEDIUM | Use per-service deployment matrix instead of generic template |
| **CI/CD deploys to wrong region (missed secrets)** | **MEDIUM** | **HIGH** | **Update all 4 GitHub secrets, not just AWS_DEFAULT_REGION** |
| ACM certificate validation delays | MEDIUM | MEDIUM | Create certificates early; verify Route53 zone exists first |
| Cold Lambda performance post-cutover | MEDIUM | MEDIUM | Provisioned concurrency for gateway/sales |
| WAF ARN references stale | HIGH | MEDIUM | Replace hardcoded ARNs after ALB migration |
| Redis unused but migrated (wasted effort) | MEDIUM | LOW | Verify CloudWatch metrics; skip if unused |
| OpenSearch ghost config causes confusion | MEDIUM | LOW | Clean up stale config; verify metrics before deciding |
| Data loss during Aurora switchover | LOW | CRITICAL | Managed switchover; verify replication lag = 0 |
| S3 objects not replicated | LOW | HIGH | CRR + Batch Replication; verify object counts |
| CI/CD deploys to wrong region | LOW | HIGH | Freeze deployments during transition; atomic secret update |
| DNS propagation delay | LOW | MEDIUM | Lower TTL to 60s, 48h before cutover |
| CIDR overlap blocks cross-region debug | LOW | LOW | No peering needed; document constraint |
| eu-central-1 service limits | LOW | HIGH | Pre-check quotas before starting |
| **Storybook deployment broken** | **MEDIUM** | **LOW** | **Migrate S3 + CloudFront; update GitHub vars** |
| **Existing user extensions orphaned** | **MEDIUM** | **MEDIUM** | **Document redeployment requirement; verify deployer region handling** |
| **S3 lifecycle on wrong bucket (dev)** | **LOW** | **LOW** | **Fix in Phase 1 Terraform changes** |

---

## Appendix: Per-Service CDK Deployment Matrix

For use in Phase 3.3 and Phase 5.8:

| # | Service | Stack 1 | Stack 2 | Stack 3 | Stack 4 | Stack 5 | DbMigrator |
|---|---------|---------|---------|---------|---------|---------|------------|
| 1 | gateway | GatewayStack | -- | -- | -- | -- | NO |
| 2 | catalogue | DbMigratorStack | ServerlessBackendStack | -- | -- | -- | YES |
| 3 | organizations | DbMigratorStack | ConsumersStack | BackgroundJobsStack | ServerlessBackendStack | -- | YES |
| 4 | inventory | DbMigratorStack | ConsumersStack | BackgroundJobsStack | ServerlessBackendStack | -- | YES |
| 5 | pricing | DbMigratorStack | ConsumersStack | ServerlessBackendStack | -- | -- | YES |
| 6 | sales | DbMigratorStack | ConsumersStack | BackgroundJobsStack | ServerlessBackendStack | -- | YES |
| 7 | access-control | DbMigratorStack | ConsumersStack | BackgroundJobsStack | ServerlessBackendStack | -- | YES |
| 8 | media | DbMigratorStack | MediaStorageStack | ConsumersStack | BackgroundJobsStack | ServerlessBackendStack | YES |
| 9 | reporting-api | DbMigratorStack | ConsumersStack | BackgroundJobsStack | ServerlessBackendStack | -- | YES |
| 10 | transfer | DbMigratorStack | ConsumersStack | BackgroundJobsStack | ServerlessBackendStack | -- | YES |
| 11 | loyalty | ConsumersStack | BackgroundJobsStack | -- | -- | -- | NO |
| 12 | marketplace | DbMigratorStack | ConsumersStack | BackgroundJobsStack | ServerlessBackendStack | -- | YES |
| 13 | integration | DbMigratorStack | ConsumersStack | BackgroundJobsStack | ServerlessBackendStack | -- | YES |
| 14 | distribution-portal | DbMigratorStack | ConsumersStack | BackgroundJobsStack | ServerlessBackendStack | -- | YES |
| 15 | geidea | ConsumersStack | BackgroundJobsStack | ApiStack | -- | -- | NO |
| 16 | extension-api | DbMigratorStack | ConsumersStack | BackgroundJobsStack | ServerlessBackendStack | -- | YES |
| 17 | extension-deployer | ExtensionDeployerLambdaRoleStack | ExtensionDeployerStack | -- | -- | -- | NO |
| 18 | extension-executor | ExtensionExecutorStack | -- | -- | -- | -- | NO |
| 19 | extension-log-processor | ExtensionLogsProcessorStack | -- | -- | -- | -- | NO |
| 20 | csv-generator | ConsumersStack | -- | -- | -- | -- | NO |
| 21 | pdf-generator | ConsumersStack | -- | -- | -- | -- | NO |

---

*Review completed: 2026-03-05 (Round 3)*
*Validated against: 30+ service repositories, Terraform configs, CDK stacks, CI/CD workflows, ConfigMaps, Helm charts*
*Round 3: 12 parallel exploration agents -- CDK bootstrap, SQS/ARNs, CI/CD templates, Lambda runtimes/layers, Route53/DNS/certificates, Terraform deep analysis*
