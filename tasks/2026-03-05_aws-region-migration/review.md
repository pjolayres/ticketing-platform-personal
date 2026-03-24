# AWS Region Migration Plan Review

**Plan:** `.personal/tasks/2026-03-05_aws-region-migration/plan.md`
**Reviewed:** 2026-03-25 (Round 9)
**Method:** 9 review rounds with 53+ parallel agents + AWS CLI live verification against me-south-1 prod account (660748123249). Round 8 validated: S3 buckets, Lambda functions, RDS cluster, SQS queues, Secrets Manager, Route53 zones, DNS records, CloudFront distributions, EventBridge buses, KMS keys, IAM users, and AWS Backup recovery points in eu-central-1. Round 9: 7 parallel agents cross-referencing CDK domain mappings, Terraform EKS deprecation, me-south-1 full sweep, CDK stack verification, secrets/SSM tracing, S3 bucket naming propagation, CI/CD workflows, and connection string/SQS update procedures.

- [Executive Summary](#executive-summary)
  - [Verdict by Phase](#verdict-by-phase)
  - [Open Item Summary](#open-item-summary)
- [Critical Issues (Round 7)](#critical-issues-round-7)
  - [ISSUE-31: Ecwid CDK Domain Mapping Missing from Phase 1 Task 10](#issue-31-ecwid-cdk-domain-mapping-missing-from-phase-1-task-10)
  - [ISSUE-32: Aurora Cluster/Instance Identifier Mismatch with Terraform](#issue-32-aurora-clusterinstance-identifier-mismatch-with-terraform)
  - [ISSUE-33: SQS Queue Name Mismatch in Phase 3.4 Step 6](#issue-33-sqs-queue-name-mismatch-in-phase-34-step-6)
  - [ISSUE-34: Missing SQS\_QUEUE\_URL Updates for transfer/reporting/media](#issue-34-missing-sqs_queue_url-updates-for-transferreportingmedia)
- [High-Priority Issues (Round 7)](#high-priority-issues-round-7)
  - [ISSUE-35: Phase 4 DNS Cutover Window — CNAME Transition Gap](#issue-35-phase-4-dns-cutover-window--cname-transition-gap)
  - [ISSUE-36: RDS Proxy Behavioral Change Not Documented](#issue-36-rds-proxy-behavioral-change-not-documented)
  - [ISSUE-37: AWS Backup Restore Metadata — VpcSecurityGroupIds May Not Be Supported](#issue-37-aws-backup-restore-metadata--vpcsecuritygroupids-may-not-be-supported)
- [Low-Priority Issues (Round 7)](#low-priority-issues-round-7)
  - [ISSUE-38: JetBrains .idea Workspace Files with me-south-1](#issue-38-jetbrains-idea-workspace-files-with-me-south-1)
- [Low-Priority Issues (Round 6)](#low-priority-issues-round-6)
  - [ISSUE-26: Category 2 Inventory Listing Incorrect](#issue-26-category-2-inventory-listing-incorrect)
  - [ISSUE-27: Terraform secretmanager.tf Missing terraform\_redis Output Removal](#issue-27-terraform-secretmanagertf-missing-terraform_redis-output-removal)
  - [ISSUE-28: Documentation Files With me-south-1 Not In Plan](#issue-28-documentation-files-with-me-south-1-not-in-plan)
  - [ISSUE-29: Exposed AWS Access Key in launchSettings.json](#issue-29-exposed-aws-access-key-in-launchsettingsjson)
  - [ISSUE-30: InfrastructureAlarmsTopicArn Missing from SSM Inventory](#issue-30-infrastructurealarmstopicarn-missing-from-ssm-inventory)
- [Medium-Priority Issues](#medium-priority-issues)
  - [ISSUE-9: Lambda Provisioned Concurrency](#issue-9-lambda-provisioned-concurrency)
  - [ISSUE-11: demo Environment Not Addressed](#issue-11-demo-environment-not-addressed)
- [Resolved Gaps \& Issues](#resolved-gaps--issues)
- [Confirmed Items (Plan Is Correct)](#confirmed-items-plan-is-correct)
  - [Reference Inventory](#reference-inventory)
  - [Architecture](#architecture)
  - [Lambda \& Runtime](#lambda--runtime)
  - [CI/CD](#cicd)
  - [Terraform](#terraform)
  - [Third-Party Integrations](#third-party-integrations)
- [Recommendations Summary](#recommendations-summary)
  - [Before Starting Phase 1](#before-starting-phase-1)
  - [Remaining Manual Work (not yet in plan)](#remaining-manual-work-not-yet-in-plan)
- [Risk Matrix](#risk-matrix)
- [Appendix A: Added Services — CDK Audit](#appendix-a-added-services--cdk-audit)
  - [automations](#automations)
  - [customer-service](#customer-service)
  - [Excluded Services (not migrated)](#excluded-services-not-migrated)
- [Appendix B: Per-Service CDK Deployment Matrix](#appendix-b-per-service-cdk-deployment-matrix)
- [Appendix C: Complete SSM Parameter Inventory](#appendix-c-complete-ssm-parameter-inventory)

---

## Executive Summary

The migration plan is comprehensive and addresses ~98% of the migration scope. **Round 9** performed comprehensive codebase cross-referencing with 7 parallel agents verifying CDK domain mappings, Terraform EKS deprecation, me-south-1 reference sweep, CDK stack names/order, secrets/SSM parameters, S3 bucket naming propagation, CI/CD workflows, and connection string/SQS procedures. **Round 9 found 1 high-priority issue** (Phase 3 temporary domain breaks inter-service calls for loyalty/automations/ecwid/geidea services that don't load SSM InternalServices overrides) and **3 medium-priority corrections** (CONNECTION_STRINGS_Sales key doesn't exist, SQS_QUEUE_URL updates for non-extension services are harmless but unnecessary, automations TicketSender has hardcoded gateway URL). The plan's core structure remains sound. All prior critical/high issues from Rounds 7-8 remain resolved.

### Verdict by Phase

| Phase | Status | Remaining Blockers |
|-------|--------|----------|
| Phase 1 (Code Prep) | ~99% Complete | None — tools NuGet publish ordering addressed in Task 19 |
| Phase 2 (Prod Foundation) | ~99% Complete | None |
| Phase 3 (Prod Services) | ~99% Complete | None |
| Phase 4 (DNS Cutover) | ~99% Complete | None |
| Phase 5 (Dev+Sandbox) | ~98% Complete | Mirrors Phase 2/3 |
| Post-Migration | ~98% Complete | None |

### Open Item Summary

| Severity | Count | IDs |
|----------|-------|-----|
| CRITICAL | 0 | All resolved |
| HIGH | 1 | ISSUE-39 (Phase 3 inter-service calls broken for loyalty/automations/ecwid/geidea) |
| MEDIUM | 5 | ISSUE-9, ISSUE-11, ISSUE-40, ISSUE-41, ISSUE-42 |
| LOW | 1 | ISSUE-38 (IDE workspace files) |

---

## High-Priority Issues (Round 9)

### ISSUE-39: Phase 3 Temporary Domain Breaks Inter-Service Calls for 4 Services

**Severity:** HIGH | **Phase:** 3.6 | **Status:** OPEN

During Phase 3 (temporary `production-eu` domain), inter-service HTTP calls will fail for **loyalty, automations, ecwid-integration, and geidea (GatewayServiceBaseRoute only)** because these services rely on hardcoded env-var.prod.json base routes that won't resolve under the temporary domain.

**Root cause:** Most services call `ParameterStoreHelper.LoadParametersToEnvironmentAsync("/{env}/tp/InternalServices")` at Lambda cold start, which overwrites env-var base routes with SSM-stored URLs containing the correct `production-eu` domain. However:

| Service | Calls LoadParametersToEnvironmentAsync? | Env-var base routes used | Impact |
|---------|----------------------------------------|--------------------------|--------|
| **loyalty** | NO | PricingServiceBaseRoute, CatalogueServiceBaseRoute, SalesServiceBaseRoute, AccessControlServiceBaseRoute, OrganizationServiceBaseRoute, GatewayServiceBaseRoute | All inter-service calls fail |
| **automations** | NO | API_URL (`api.production.tickets.mdlbeast.net`) | Scheduled Lambda API calls fail |
| **ecwid-integration** | NO | CatalogueServiceBaseRoute, SalesServiceBaseRoute, AccessControlServiceBaseRoute, OrganizationServiceBaseRoute, ApiUrl | All inter-service calls fail |
| **geidea** | YES (consumers/background jobs) | GatewayServiceBaseRoute only (`api.production.tickets.mdlbeast.net`) | Gateway is NOT in SSM InternalServices — this env-var is NOT overridden |

**Why it fails:** During Phase 3, `*.internal.production.tickets.mdlbeast.net` has no private hosted zone in the new VPC (only `production-eu` exists). The public `api.production.tickets.mdlbeast.net` still has dead DNS pointing to me-south-1 API Gateways.

**After Phase 4 DNS cutover:** All env-var base routes become correct again (`production.tickets.mdlbeast.net` resolves to eu-central-1 endpoints). This is strictly a Phase 3 testing limitation.

**Recommendation:** Accept this as a known limitation of Phase 3 E2E testing. Document that loyalty, automations, ecwid, and geidea gateway calls can only be fully validated after Phase 4 DNS cutover. Phase 3.6 validation checklist should note these services are expected to have partial failures.

---

## Medium-Priority Issues (Round 9)

### ISSUE-40: CONNECTION_STRINGS_Sales Key Does Not Exist in Codebase

**Severity:** MEDIUM | **Phase:** 3.4 | **Status:** OPEN

The plan's Phase 3.4 Step 5 Python script iterates over `['CONNECTION_STRINGS', 'CONNECTION_STRINGS_Sales']`. A codebase-wide search confirms `CONNECTION_STRINGS_Sales` does not exist in any `.cs` or `.json` file. All services (including Sales) use the standard `CONNECTION_STRINGS` key with `PgSql` and `ReadonlyPgSql` dict keys.

**Impact:** Harmless — the Python script's `if cs_key not in secret: continue` skips it. No action required, but the plan should remove this reference for clarity.

### ISSUE-41: SQS_QUEUE_URL Updates for Non-Extension Services Are Unnecessary

**Severity:** MEDIUM | **Phase:** 3.4 | **Status:** OPEN

Phase 3.4 Step 6 updates `SQS_QUEUE_URL` in secrets for marketplace, sales, transfer, reporting, and media. However:
- No C# code reads `Environment.GetEnvironmentVariable("SQS_QUEUE_URL")`
- These services publish CSV/PDF requests to **EventBridge** (not SQS directly)
- Consumer Lambdas receive messages via CDK-configured SQS event source mappings (no URL needed)
- Only `EXTENSION_DEPLOYER_SQS_QUEUE_URL` and `EXTENSION_EXECUTOR_SQS_QUEUE_URL` are actually read by code

**Impact:** Harmless — updating a phantom key in Secrets Manager causes no issues. The `me-south-1` → `eu-central-1` replacement in SQS URLs (Step 5) is still correct for any queue URLs that happen to exist in secrets. No action required.

### ISSUE-42: Automations TicketSender Hardcoded Gateway URL

**Severity:** MEDIUM | **Phase:** Post-migration | **Status:** OPEN

`ticketing-platform-automations/src/TP.Automations.TicketSender/Program.cs:302` contains:
```csharp
{ "apiUrl", "https://api.production.tickets.mdlbeast.net" },
```

This is a console utility app (not a deployed Lambda), so it has no operational impact during migration. After Phase 4 DNS cutover, the URL resolves correctly. Update post-migration as part of local dev settings cleanup (Category 10).

---

## Critical Issues (Round 7)

### ISSUE-31: Ecwid CDK Domain Mapping Missing from Phase 1 Task 10 — RESOLVED

**Severity:** CRITICAL | **Phase:** 1 | **Task:** 10 | **Status:** RESOLVED — added to Phase 1 Task 10 and Phase 4.1 revert table

Phase 1 Task 10 lists 6 files for the `production` → `production-eu` temporary domain mapping. **Ecwid-integration is missing.**

| File | Line | Pattern |
|------|------|---------|
| `ecwid-integration/src/TP.Ecwid.Cdk/Stacks/ApiStack.cs` | 32 | `$"{(env == "prod" ? "production" : env)}.tickets.mdlbeast.net"` |

This file follows the identical pattern as the 6 listed files. Without this change, the ecwid CDK deploy in Phase 3.5 will attempt to create `ecwid.production.tickets.mdlbeast.net` (the real domain) instead of `ecwid.production-eu.tickets.mdlbeast.net` (the temporary domain), breaking the safe-testing strategy.

**Also affects Phase 4.1:** The revert table must include this file.

**Action:** Add as 7th entry in Phase 1 Task 10 and Phase 4.1 revert table. Also add ecwid-integration to the Phase 4.4 GitHub secrets repo list (it has `.github/workflows/ci-cd.yml` using `AWS_DEFAULT_REGION`).

**Note:** `ticketing-platform-xp-badges/src/TP.XpBadges.Cdk/Stacks/ApiStack.cs:29` also has the pattern but xp-badges is excluded from migration — no action needed.

---

### ISSUE-32: Aurora Cluster/Instance Identifier Mismatch with Terraform — RESOLVED

**Severity:** CRITICAL | **Phase:** 2.6 | **Task:** 10 (Terraform import) | **Status:** RESOLVED — restored to original identifiers (`ticketing` / `aurora-cluster-demo-{0,1,2}`). RDS identifiers are region-scoped, not globally unique, so no conflict with me-south-1. No Terraform code changes needed.

The plan creates a restored Aurora cluster with identifier `ticketing-eu` and instances `ticketing-eu-instance-{0,1,2}`. But the Terraform resource definitions use **different** identifiers:

| Resource | Plan Creates | Terraform Expects |
|----------|-------------|-------------------|
| `aws_rds_cluster.ticketing` | `cluster_identifier = "ticketing-eu"` | `cluster_identifier = var.domain_prod` → defaults to `"ticketing"` |
| `aws_rds_cluster_instance.ticketing[N]` | `ticketing-eu-instance-{0,1,2}` | `identifier = "aurora-cluster-demo-${count.index}"` → `aurora-cluster-demo-{0,1,2}` |

**Evidence:** `ticketing-platform-terraform-prod/prod/rds.tf` line 185 uses `var.domain_prod` (default: `"ticketing"`), line 224 uses `"aurora-cluster-demo-${count.index}"`.

**Impact:** After `terraform import`, `terraform plan` will show drift on both cluster_identifier and instance identifiers. Running `terraform apply` without fixing this could trigger cluster replacement, causing **data loss**.

**Action:** Before Phase 2.6 step 10, update `rds.tf`:
1. Change `cluster_identifier` to `"ticketing-eu"` (or override `var.domain_prod`)
2. Change instance `identifier` to `"ticketing-eu-instance-${count.index}"`

---

### ISSUE-33: SQS Queue Name Mismatch in Phase 3.4 Step 6 — RESOLVED

**Severity:** CRITICAL | **Phase:** 3.4 | **Task:** 6 | **Status:** RESOLVED — queue names corrected from AWS CLI output (`TP_Extensions_Deployer_Queue_prod`, `TP_CSV_Report_Generator_Service_Queue_prod`, etc.)

Phase 3.4 Step 6 attempts to get SQS queue URLs using names like:
- `tp-extensions-deployer-consumer-prod`
- `tp-marketplace-consumer-prod`
- `tp-sales-consumer-prod`

**None of these match the actual CDK naming convention.** The `ConsumersSqsStack.cs:70` uses:
```csharp
QueueName = $"{consumer}-queue-{env}"
```

Where `consumer` comes from the `ConsumersServices` enum (e.g., `Extensions`, `Marketplace`, `Sales`).

| Plan Assumes | CDK Actually Creates |
|-------------|---------------------|
| `tp-extensions-deployer-consumer-prod` | `Extensions-queue-prod` |
| `tp-marketplace-consumer-prod` | `Marketplace-queue-prod` |
| `tp-sales-consumer-prod` | `Sales-queue-prod` |

**Impact:** All `aws sqs get-queue-url` commands in Step 6 will fail. SQS_QUEUE_URL secrets won't be updated. Consumer services will reference non-existent me-south-1 queue URLs.

**Action:** Update Phase 3.4 Step 6 queue names to match CDK pattern: `{ConsumerServiceEnumName}-queue-{env}`. Also verify the exact SQS queue names from secrets backups — the backed-up secrets show names like `TP_CSV_Report_Generator_Service_Queue_prod` and `TP_Extensions_Deployer_Queue_prod`, which differ from both the plan's assumption AND the CDK naming. These may be legacy queue names from pre-CDK infrastructure — verify whether the CDK-created queues use the `{Consumer}-queue-{env}` pattern or a different one.

---

### ISSUE-34: Missing SQS_QUEUE_URL Updates for transfer/reporting/media — RESOLVED

**Severity:** CRITICAL | **Phase:** 3.4 | **Task:** 6 | **Status:** RESOLVED — transfer, reporting, media added to Phase 3.4 Step 6 SQS update loop

Phase 3.4 Step 6 only updates SQS_QUEUE_URL for `extensions`, `marketplace`, and `sales`. But backed-up secrets show **3 additional services** with SQS_QUEUE_URL:

| Service | Secret Key | Backed-up Value |
|---------|-----------|-----------------|
| transfer | `SQS_QUEUE_URL` | `TP_CSV_Report_Generator_Service_Queue_prod` |
| reporting | `SQS_QUEUE_URL` | `TP_CSV_Report_Generator_Service_Queue_prod` |
| media | `SQS_QUEUE_URL` | `TP_PDF_Generator_Service_Queue_prod` |

**Impact:** These 3 services will retain stale me-south-1 queue URLs. Any code path that uses `SQS_QUEUE_URL` from secrets will fail.

**Action:** Add transfer, reporting, and media to the Phase 3.4 Step 6 SQS update loop.

---

## High-Priority Issues (Round 7)

### ISSUE-35: Phase 4 DNS Cutover Window — CNAME Transition Gap — RESOLVED

**Severity:** HIGH | **Phase:** 4.3 | **Status:** RESOLVED — added parallel ServerlessBackendStack deployment guidance and DNS verification to Phase 4.3

When Phase 4.3 redeploys `InternalHostedZoneStack`, the private hosted zone changes from `internal.production-eu.tickets.mdlbeast.net` to `internal.production.tickets.mdlbeast.net`. The old zone is **deleted** and a new one is **created**.

Between the InternalHostedZoneStack redeploy and the ServerlessBackendStack redeployments (14 services), internal DNS CNAME records won't exist in the new zone. Services making inter-service HTTP calls during this window will get NXDOMAIN errors.

**Mitigation recommendations:**
1. Deploy InternalHostedZoneStack + InternalCertificateStack first
2. Immediately deploy all 14 ServerlessBackendStack stacks in parallel (they're independent)
3. Deploy Gateway last (as the plan already specifies)
4. Add `cdk diff` dry-run before each Phase 4.3 deploy
5. Add DNS resolution verification (`dig`) after each stack completes

---

### ISSUE-36: RDS Proxy Behavioral Change Not Documented — RESOLVED

**Severity:** HIGH | **Phase:** 3.4 | **Status:** RESOLVED — plan updated to use direct Aurora endpoints instead of RDS Proxy. RDS Proxy remains deployed on standby, may be removed in future.

Phase 3.4 Step 5 replaces `CONNECTION_STRINGS` Host values with RDS Proxy endpoints. However, **services currently connect directly to the Aurora cluster** (not through RDS Proxy). All backed-up secrets contain direct RDS cluster endpoints like `ticketing.cluster-cocuscg4fsup.me-south-1.rds.amazonaws.com`.

This is a **behavioral change** — moving from direct RDS to proxied connections — that introduces potential compatibility risks:
- Connection pooling behavior differences (RDS Proxy manages its own pool)
- Connection pinning for certain PostgreSQL features
- Potential latency increase (additional network hop)

**Action:** Document this as an intentional upgrade. Consider testing one service (e.g., catalogue) with the RDS Proxy endpoint during Phase 3.6 validation before updating all services. If issues arise, fall back to using the direct Aurora cluster endpoint (`ticketing-eu.cluster-*.eu-central-1.rds.amazonaws.com`).

---

### ISSUE-37: AWS Backup Restore Metadata — VpcSecurityGroupIds May Not Be Supported — RESOLVED

**Severity:** HIGH | **Phase:** 2.6 | **Task:** 3 | **Status:** RESOLVED — post-restore security group verification and fallback step added to Phase 2.6

Phase 2.6 Step 3 passes `VpcSecurityGroupIds` in the AWS Backup `start-restore-job` metadata. This parameter may not be supported by the Aurora restore API — AWS documentation lists `DBClusterIdentifier`, `Engine`, `DBSubnetGroupName`, and optionally `DBClusterParameterGroupName` as the accepted metadata fields.

**Impact:** The restore may either fail with a validation error, or silently ignore the security group. If ignored, the restored cluster will use the VPC's default security group with no database ingress rules — making the database unreachable.

**Action:** Add a post-restore verification step:
```bash
# After restore completes, verify and apply security group:
aws rds modify-db-cluster \
  --db-cluster-identifier ticketing-eu \
  --vpc-security-group-ids $RDS_SG \
  --apply-immediately $P
```
Test this on dev/sandbox first before prod.

---

## Low-Priority Issues (Round 7)

### ISSUE-38: JetBrains .idea Workspace Files with me-south-1

7 services have `.idea/workspace.xml` files containing `me-south-1` in IDE run configurations (access-control, catalogue, inventory, loyalty, pricing, sales, transfer). These are developer-local settings with no operational impact. Developers should reconfigure their IDEs post-migration.

---

## Low-Priority Issues (Round 6)

All resolved or ignored.

| ID | Issue | Resolution |
|---|---|---|
| ISSUE-26 | Category 2 incorrectly listed `inventory` (no STORAGE_REGION in env-var files) | **RESOLVED** — removed inventory from Category 2, updated count to 14, added to "does NOT have" note |
| ISSUE-27 | `secretmanager.tf` also has `terraform_redis` output to remove | **RESOLVED** — added `terraform_redis` to Phase 1 Task 3 alongside `terraform_opensearch` |
| ISSUE-28 | 4 documentation/README files have me-south-1 references | **IGNORED** — informational only, no operational impact |
| ISSUE-29 | Exposed AWS access key in media launchSettings.json | **IGNORED** — Category 10 file, updated during migration |
| ISSUE-30 | InfrastructureAlarmsTopicArn missing from SSM inventory | **IGNORED** — auto-created by CDK, no manual action needed |

---

## Medium-Priority Issues

### ISSUE-9: Lambda Provisioned Concurrency

Consider provisioned concurrency for gateway and sales Lambda functions during the first week post-cutover to mitigate cold starts under production load.

### ISSUE-11: demo Environment Not Addressed

The plan defers `demo` to post-migration. Note: `env-var.demo.json` files exist in multiple services (transfer, reporting-api, pricing, integration, marketplace-service, customer-service) and contain `STORAGE_REGION: me-south-1`. These will be updated by the bulk scripts but no `demo` infrastructure will be created.

---

## Resolved Gaps & Issues

All items below were identified across 5 review rounds and are now fully addressed in the plan:

| ID | Issue | Resolution |
|---|---|---|
| GAP-1 | EKS cluster migration | EKS deprecated — Lambda-only architecture |
| GAP-2 | Redis/ElastiCache migration | Confirmed zombie — removed from scope |
| GAP-3 | OpenSearch/Elasticsearch migration | Confirmed ghost config — removed from scope |
| GAP-4 | Self-hosted GitHub runners | Deprecated with EKS |
| GAP-5 | Template CI/CD repo unaudited | Audited and included in plan Category 11 |
| GAP-6 | CDK bootstrap missing | Added as Phase 2.8 and Phase 4.9 |
| GAP-7 | 5 services missing from matrix | automations + customer-service added; xp-badges, marketing-feeds, bandsintown excluded from scope |
| GAP-8 | 3 additional cert SSMs | Excluded services don't need certs |
| GAP-9 | PDF generator SSM param | `STORAGE_BUCKET_NAME` added to Phase 2.5 and 4.6 |
| ISSUE-1 | Incomplete reference inventory | Dashboard `.env` files added as Category 12 |
| ISSUE-2 | Per-service CDK variations | Full deployment matrix added as Phase 3.4 |
| ISSUE-3 | ACM certificates region-specific | Certificate creation added as Phase 3.1 |
| ISSUE-4 | Dev RDS instance count | Fixed to 3 instances |
| ISSUE-5 | S3 bucket name verification | Addressed in plan |
| ISSUE-6 | VPC CIDR overlap | No peering — confirmed safe |
| ISSUE-7 | KMS key migration | Handled by Terraform |
| ISSUE-8 | CloudFront distribution origins | Dynamic references auto-resolve |
| ISSUE-10 | Service quota pre-checks | Added as Phase 2.1 |
| ISSUE-12 | WAF hardcoded ARNs | WAF deleted with EKS deprecation |
| ISSUE-13 | Security concerns | `.tfstate` gitignore + credential remediation in plan |
| ISSUE-14 | S3 lifecycle bug in dev | Fixed in Phase 1 |
| ISSUE-15 | Geidea custom domain cert | Added to Phase 3.1 |
| ISSUE-16 | Gateway public cert SSM | Added to Phase 3.1 |
| ISSUE-17 | Storybook S3/CloudFront | Storybook migration added |
| ISSUE-18 | GitHub secret update incomplete | All 4 secret types now covered |
| ISSUE-19 | Terraform state files in git | `.gitignore` addition in Phase 1 |
| ISSUE-20 | Extension deployer runtime Lambdas | Confirmed safe (uses AWS_REGION env var) |
| ISSUE-21 | EXTENSION_DEFAULT_ROLE SSM | Auto-created by ExtensionDeployerStack |
| ISSUE-22 | Terraform deletion ordering | N/A — greenfield deploy, no existing state to reconcile |
| ISSUE-23 | ticketing-terraform-github bucket | Added to S3 naming strategy and Phase 1 code prep |
| ISSUE-24 | 9 repos missing from secrets update | Added to Phase 3.5 script (incl. configmap-prod `TP_AWS_DEFAULT_REGION_PROD`) |
| ISSUE-25 | Extension redeployment | Added as post-migration task |

---

## Confirmed Items (Plan Is Correct)

### Reference Inventory
- All 142 files confirmed covered by plan's 12 categories and bulk scripts ✓
- Infrastructure C# fallback values (Category 4) confirmed ✓
- Test files (Category 5) — 6+ files confirmed, lower priority ✓
- Bulk update scripts are correct and safe ✓
- 53 env-var JSON files with STORAGE_REGION confirmed across 15 services (Round 6) ✓
- 42 aws-lambda-tools-defaults.json files confirmed (39 migrated + 3 excluded services) (Round 6) ✓
- No uncovered me-south-1 references in source code outside 12 categories (Round 6) ✓
- Phase 1 Task 10: 6 of 7 domain mapping locations verified at exact line numbers (Round 7) ✓
- Full me-south-1 sweep: 958 references found, all accounted for in 12 categories + IDE/doc files (Round 7) ✓
- Round 9 me-south-1 sweep (184 files): all covered by plan's 12 categories — no new uncovered references found ✓
- Round 9 domain mapping verification: all 7 files confirmed at exact line numbers with correct patterns ✓
- Excluded services (xp-badges, bandsintown, marketing-feeds) correctly have the domain pattern but are out of scope ✓

### Architecture
- Greenfield infrastructure approach (new Terraform state) avoids state conflicts ✓
- EventBridge/SQS naming is region-agnostic ✓
- 18 consumer services confirmed via `ConsumersServices` enum ✓
- CDK infrastructure stack list (11 stacks) matches codebase exactly — verified via Program.cs (Round 6) ✓
- All service CDK stack names and deployment order match plan's matrix (Round 6) ✓
- All 24 service Program.cs files verified: stack names and counts match exactly (Round 7) ✓
- Infrastructure CDK Program.cs verified: 11 stacks match exactly (Round 7) ✓
- CloudFront distributions use dynamic bucket references — auto-resolve ✓
- CloudFront uses default certificates — no custom domain cert needed ✓
- No VPC peering or Transit Gateway — CIDR overlap is safe ✓
- Route53 is global — CDK `HostedZone.FromLookup` finds zones by domain name ✓
- Private hosted zones are VPC-associated — same domain in new VPC = new zone ✓
- InternalCertificateStack case difference (`Internal.` vs `internal.`) is harmless — DNS is case-insensitive (Round 6) ✓
- Round 9 CDK stack verification: all 11 infrastructure stacks and 23 service CDK entries confirmed, no undocumented stacks ✓
- GeideaDataExporterStack (automations) confirmed commented out — plan's Appendix A already notes this ✓
- CONNECTION_STRINGS parsing confirmed standardized: all services use `JsonSerializer.Deserialize<Dictionary<string, string>>()` via DbAutoConfigureHelper — regex `Host=[^;]+` replacement is safe ✓
- Inter-service calls use SSM InternalServices params loaded at cold start via `ParameterStoreHelper.LoadParametersToEnvironmentAsync` — overrides env-var base routes for services that call it ✓

### Lambda & Runtime
- No Lambda layers used ✓
- No Lambda@Edge functions ✓
- All services use Runtime.DOTNET_8 ✓
- No Docker-based Lambda functions (all zip packaging) ✓
- CDK region config exclusively uses `CDK_DEFAULT_REGION` env var ✓
- Lambda permissions use `Stack.Region` property (dynamic) ✓

### CI/CD
- All .NET service workflows use `AWS_DEFAULT_REGION` via GitHub secrets (never hardcoded) ✓
- Template workflows pin to `@master` — auto-propagate changes ✓
- Dashboard and Distribution Portal Frontend deploy via Vercel (region-agnostic) ✓
- No ECR login/push or Docker build/push in any workflow ✓
- deploy-cdk.yml, build.yml, tests.yml, cloudwatch-logs-creator.yml all use secrets correctly (Round 6) ✓
- Extension deployer CDK_DEFAULT_REGION secret usage confirmed (Round 6) ✓
- Mobile scanner release-build.yml 3 hardcoded references confirmed (Round 6) ✓
- 36 repos with AWS workflows identified; plan's 35-repo list is accurate (Round 6) ✓
- Round 9 CI/CD audit: 35 repos confirmed needing AWS_DEFAULT_REGION secret update; CDK templates (deploy-cdk.yml, build.yml, tests.yml) all use secret variables correctly ✓
- EKS workflows (deploy.yml, k8s.yml) confirmed dead code with hardcoded me-south-1 — plan correctly marks for removal ✓
- Special secrets (AWS_DEFAULT_REGION_PROD, TP_AWS_DEFAULT_REGION_PROD, CDK_DEFAULT_REGION) confirmed in correct repos ✓

### Terraform
- AWS provider version 4.67.0 is region-agnostic ✓
- No Terraform modules with region assumptions ✓
- Account ID hardcoding in IAM policies is correct (account-level, not region-specific) ✓
- All files listed for EKS deprecation (deletion/modification) confirmed present with correct content (Round 6) ✓
- Plaintext credentials in variables.tf confirmed at expected line numbers (Round 6) ✓
- S3 lifecycle bug in dev/s3.tf confirmed (Round 6) ✓
- All EKS deprecation files verified with exact content and cross-references (Round 7) ✓
- prod/rds.tf security group ingress rules referencing eks subnet CIDRs confirmed at lines 57, 64, 71 (Round 7) ✓
- prod/group.tf techlead-redis (line 33) and developer-opensearch (line 81) confirmed (Round 7) ✓
- DB subnet group name confirmed as `"postgres"` at rds.tf:160 (Round 7) ✓
- Prod instance count = 3 confirmed at rds.tf:223 (Round 7) ✓
- Round 9 Terraform EKS deprecation: all 6 files to delete confirmed present with expected resources ✓
- Round 9 Terraform modifications: all cross-references (rds.tf ingress rules, group.tf IAM attachments, secretmanager.tf outputs) confirmed at exact line numbers ✓
- `iam-s3-sqs.tf` `s3-sqs-eks` policy confirmed EKS-only (comment says "iam for eks serviceaccount"), no other references — safe to delete ✓
- `user-cicd.tf` EKS policy attachment confirmed isolated — safe to delete ✓

### SSM Parameters & Secrets
- Secret path pattern `/{env}/{service}` confirmed via SecretManagerHelper code (Round 6) ✓
- CSV/PDF generator SSM paths `/{env}/tp/{service}/*` confirmed via Function.cs (Round 6) ✓
- VPC_NAME, SUBNET_1/2/3 SSM paths confirmed via CdkStackUtilities.cs (Round 6) ✓
- DomainCertificateArn paths for Gateway, Geidea, Ecwid confirmed (Round 6) ✓
- Gateway SSM cert path uses mapped env name (`/production-eu/tp/...`) confirmed via GatewayStack.cs:108 (Round 6) ✓
- All auto-created SSM parameters (InternalServices, VPC Endpoint, Consumer Queue ARNs, RDS Proxy endpoints) confirmed (Round 6) ✓
- 3 Slack webhook params + IgnoredErrorsPatterns confirmed via SlackWebhookParameters.cs (Round 6) ✓

### S3 Buckets
- All 17 bucket names from plan's naming strategy found in codebase (Round 6) ✓
- No additional bucket names discovered outside plan scope (Round 6) ✓
- Dashboard vercel.json 6 CSP URLs confirmed (Round 6) ✓
- Extended message buckets use dynamic naming — no manual update needed (Round 6) ✓
- `pdf-tickets-prod` confirmed unused (dead `var.s3_prod` variable) — removed from plan (Round 8) ✓
- `tickets-pdf-download` confirmed as actual prod PDF bucket via Terraform `s3.tf` + CloudFront origin (Round 8) ✓
- `ticketing-prod-media` confirmed 0 backup recovery points in eu-central-1 — acceptable, recreated empty (Round 8) ✓
- S3 backup vault confirmed: `backup-vault-prod` in eu-central-1 (Round 8) ✓
- S3 backup dates confirmed: latest 2026-03-23 19:40 UTC+8 for both restorable buckets (Round 8) ✓
- Round 9 S3 bucket naming: all hardcoded bucket references verified covered by plan's env-var updates, Terraform definitions, and vercel.json CSP ✓
- Round 9 LambdaS3ExtendedMessagePolicyStatement wildcard pattern confirmed — plan's update from `ticketing-*-extended-message` to `ticketing-*-extended-message-eu` is correct ✓

### AWS Infrastructure (Live Verification — Round 8)
- RDS cluster `ticketing`: aurora-postgresql 15.12, 3x `db.serverless` instances, scaling 1.5-64 ACU, subnet group `postgres`, KMS encrypted ✓
- RDS instance identifiers: `aurora-cluster-demo-{0,1,2}` — matches plan (after ISSUE-32 fix) ✓
- Aurora backup: 21 daily cross-region copies in eu-central-1 `backup-vault-prod`, all COMPLETED ✓
- 24 Secrets Manager secrets confirmed, all `/{env}/{service}` pattern ✓
- 45 SQS queues: 18 CDK consumer pairs + 4 extension/legacy pairs + 1 xray DLQ ✓
- EventBridge bus: `event-bus-prod` ✓
- Route53: 2 zones (public `production.tickets.mdlbeast.net`, private `internal.production.tickets.mdlbeast.net`) ✓
- 116 Lambda functions: 81 core + 32 extension runtime + 3 LogRetention ✓
- CloudFront: 3 distributions (pdf-download, mobile-scanner, grafana) ✓
- KMS: 1 custom alias `alias/rds` ✓
- IAM: `cicd` user confirmed ✓
- eu-central-1 is clean: 0 Lambda functions, 0 SQS queues, no CDK bootstrap ✓

### SSM Parameters & Secrets (Round 9 Reconfirmation)
- All 16 service secret paths verified via `SecretManagerHelper.LoadSecretsToEnvironmentAsync` — 100% match with plan ✓
- CSV generator SSM path `/{env}/tp/csv/generator/*` confirmed in Function.cs:102 ✓
- PDF generator SSM path `/{env}/tp/pdf/generator/*` confirmed in Function.cs:102 ✓
- All 16 manual SSM parameters in plan's Phase 2.5 confirmed required by CDK code reads ✓
- Secret names match code exactly (e.g., `/prod/customers` not `/prod/customer-service`) ✓
- Only extension services read SQS queue URLs from env vars (`EXTENSION_DEPLOYER_SQS_QUEUE_URL`, `EXTENSION_EXECUTOR_SQS_QUEUE_URL`) — other services use EventBridge ✓

### Third-Party Integrations
- Auth0, Checkout.com, SendGrid, Sentry, Seats.io — all SaaS, region-agnostic ✓

---

## Recommendations Summary

### All Round 7 Issues — RESOLVED

All 7 issues from Round 7 have been resolved in the plan. See individual issue entries above for details.

### Round 8 — AWS CLI Live Verification (2026-03-25)

Verified prod account `660748123249` via AWS CLI. Corrections applied:

| Finding | Action |
|---|---|
| `pdf-tickets-prod` bucket does not exist — dead variable `var.s3_prod` in Terraform, never referenced | Removed from S3 naming table; PDF generator SSM corrected to `tickets-pdf-download-eu` |
| `ticketing-prod-media` has 0 backup recovery points in eu-central-1 | Removed from Phase 2.7 restore — bucket recreated empty (acceptable) |
| Aurora backup in `backup-vault-prod` vault, latest 2026-03-23 19:40 UTC+8, engine 15.12 | Vault name and confirmed dates added to Phase 2.6 and 2.7 |
| S3 backups confirmed: `tickets-pdf-download` (20 points), `ticketing-csv-reports` (20 points) | Phase 2.7 updated to restore only these 2 buckets |
| RDS cluster `ticketing`, instances `aurora-cluster-demo-{0,1,2}`, `db.serverless`, scaling 1.5-64 ACU | Matches plan exactly (after ISSUE-32 fix) |
| 24 secrets confirmed, all `/{env}/{service}` pattern | Matches plan |
| 45 SQS queues: 36 CDK consumer + 8 extension/legacy + 1 xray | Queue names match plan (after ISSUE-33 fix) |
| EventBridge bus name: `event-bus-prod` | Noted — CDK uses this naming |
| Route53: 2 zones (public + private), 25 DNS records including dead EKS CNAMEs | CDK will overwrite; confirmed |
| 116 Lambda functions (81 core + 32 extensions + 3 LogRetention) | All 23 services + monitoring confirmed deployed |
| CloudFront: 3 distributions (pdf-download, mobile-scanner, grafana) | `tickets-pdf-download` origin confirmed |
| KMS: 1 custom alias `alias/rds` → `mrk-fa75a489...` | Terraform creates new key in eu-central-1 |

### Remaining Manual Work (carried from earlier rounds)

1. **Update env-var JSON bucket names** for the `-eu` suffix — media, integration services
2. **Verify NS delegation** at the parent domain after Terraform creates Route53 zones
3. **CSV generator runtime SSM params** — verify `/{env}/tp/csv/generator/*` parameters are populated
4. **Run `aws s3 ls`** in both accounts to verify exact bucket names
5. **Check eu-central-1 service quotas** and request increases
6. **Clarify `demo` environment** inclusion/deferral

---

## Risk Matrix

| Risk | Likelihood | Impact | Mitigation | Status |
|------|-----------|--------|------------|--------|
| ~~Terraform import causes cluster replacement~~ | ~~HIGH~~ | ~~CRITICAL~~ | Use original identifiers (`ticketing` / `aurora-cluster-demo-N`) — ISSUE-32 | RESOLVED |
| ~~SQS queue names wrong in Phase 3.4 scripts~~ | ~~HIGH~~ | ~~CRITICAL~~ | Queue names corrected from AWS CLI output — ISSUE-33 | RESOLVED |
| ~~Ecwid deploys to real domain during Phase 3~~ | ~~HIGH~~ | ~~HIGH~~ | Ecwid domain mapping added to Phase 1 Task 10 — ISSUE-31 | RESOLVED |
| ~~3 services retain stale SQS URLs~~ | ~~HIGH~~ | ~~HIGH~~ | transfer/reporting/media added to SQS update — ISSUE-34 | RESOLVED |
| ~~Phase 4 CNAME gap causes inter-service failures~~ | ~~MEDIUM~~ | ~~HIGH~~ | Parallel ServerlessBackendStack deploys added — ISSUE-35 | RESOLVED |
| ~~RDS Proxy incompatibility (untested)~~ | ~~MEDIUM~~ | ~~HIGH~~ | Using direct Aurora endpoints; RDS Proxy on standby — ISSUE-36 | RESOLVED |
| ~~Restore metadata ignores security group~~ | ~~MEDIUM~~ | ~~HIGH~~ | Post-restore SG verification step added — ISSUE-37 | RESOLVED |
| Phase 3 inter-service calls fail for 4 services | HIGH | MEDIUM | loyalty/automations/ecwid/geidea don't load SSM InternalServices; accept as Phase 3 limitation — ISSUE-39 | OPEN |
| NS delegation at parent domain | MEDIUM | HIGH | Update parent zone NS records after Terraform creates new zones | OPEN |
| S3 bucket names in env-var JSON | MEDIUM | MEDIUM | Manual update needed for `-eu` suffix in ~7 env-var files | OPEN |
| AWS Backup restore fails or data stale | LOW | CRITICAL | Verify backup recency; test on dev first | OPEN |
| Secrets cannot be reconstructed | MEDIUM | CRITICAL | Offline credential docs; check AWS Backup | OPEN |
| Missing SSM parameter | MEDIUM | HIGH | Comprehensive param list in 2.5; verify before CDK | OPEN |
| Cold Aurora with prod load | MEDIUM | HIGH | Increase min ACU during go-live week | OPEN |
| Cold Lambda performance post-go-live | MEDIUM | MEDIUM | Provisioned concurrency for gateway/sales | OPEN |
| S3 bucket naming collision | LOW | MEDIUM | `-eu` suffix; old buckets in down region | OPEN |
| DNS propagation delay | LOW | MEDIUM | Lower TTL; use weighted routing | OPEN |
| eu-central-1 service limits | LOW | HIGH | Pre-check quotas in Phase 2.1 and 4.1 | OPEN |
| ACM certificate validation delays | MEDIUM | MEDIUM | Create early; verify Route53 zones first | OPEN |

---

## Appendix A: Added Services — CDK Audit

### automations

**CDK Entry:** `ticketing-platform-automations/src/TP.Automations.Cdk/Program.cs`

| Stack | Purpose |
|-------|---------|
| `TP-WeeklyTicketsSenderStack-automations-{env}` | Scheduled Lambda |
| `TP-AutomaticDataExporterStack-automations-{env}` | Scheduled Lambda |
| `TP-FinanceReportSenderStack-automations-{env}` | Scheduled Lambda |

- **DbMigrator:** NO — stateless Lambda functions
- **SSM Dependencies:** None
- **VPC:** Yes
- **me-south-1 refs:** env-var.dev/sandbox/prod.json (`STORAGE_REGION`)
- **Note:** GeideaDataExporterStack exists but is commented out

### customer-service

**CDK Entry:** `ticketing-platform-customer-service/src/TP.Customers.Cdk/Program.cs`

| Stack | Purpose |
|-------|---------|
| `TP-DbMigratorStack-customers-{env}` | Database migrator |
| `TP-ConsumersStack-customers-{env}` | SQS consumer |
| `TP-BackgroundJobsStack-customers-{env}` | Scheduled jobs |
| `TP-ServerlessBackendStack-customers-{env}` | API |

- **DbMigrator:** YES — EF Core migrations in `TP.Customers.Infrastructure/Migrations`
- **SSM Dependencies:** Internal certificate (via ServerlessApiStackHelper)
- **VPC:** Yes
- **me-south-1 refs:** env-var.dev/demo/sandbox/prod.json + 2 aws-lambda-tools-defaults.json
- **Note:** Has `Customers` entry in `ConsumersServices` enum (SQS queue auto-created)

### Excluded Services (not migrated)

- **xp-badges** — requires custom domain cert SSM; lower priority
- **marketing-feeds** — requires custom domain cert SSM; lower priority
- **bandsintown-integration** — requires custom domain cert SSM; lower priority

---

## Appendix B: Per-Service CDK Deployment Matrix

Complete matrix for Phase 3.4 and Phase 5.4. **All 23 services.**

| # | Service | Stacks (deploy in order) | DbMigrator | Cert SSM |
|---|---------|--------------------------|------------|----------|
| 1 | gateway | GatewayStack | NO | `DomainCertificateArn` |
| 2 | catalogue | DbMigratorStack → ServerlessBackendStack | YES | Internal |
| 3 | organizations | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES | Internal |
| 4 | inventory | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES | Internal |
| 5 | pricing | DbMigratorStack → ConsumersStack → ServerlessBackendStack | YES | Internal |
| 6 | sales | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES | Internal |
| 7 | access-control | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES | Internal |
| 8 | media | DbMigratorStack → MediaStorageStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES | Internal |
| 9 | reporting-api | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES | Internal |
| 10 | transfer | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES | Internal |
| 11 | loyalty | ConsumersStack → BackgroundJobsStack | NO | None |
| 12 | marketplace | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES | Internal |
| 13 | integration | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES | Internal |
| 14 | distribution-portal | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES | Internal |
| 15 | geidea | ConsumersStack → BackgroundJobsStack → ApiStack | NO | `geidea/DomainCertificateArn` |
| 16 | extension-api | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES | Internal |
| 17 | extension-deployer | ExtensionDeployerLambdaRoleStack → ExtensionDeployerStack | NO | None |
| 18 | extension-executor | ExtensionExecutorStack | NO | None |
| 19 | extension-log-processor | ExtensionLogsProcessorStack | NO | None |
| 20 | csv-generator | ConsumersStack | NO | None |
| 21 | pdf-generator | ConsumersStack | NO | None |
| 22 | automations | WeeklyTicketsSenderStack + AutomaticDataExporterStack + FinanceReportSenderStack | NO | None |
| 23 | customer-service | DbMigratorStack → ConsumersStack → BackgroundJobsStack → ServerlessBackendStack | YES | Internal |

---

## Appendix C: Complete SSM Parameter Inventory

**Pre-populated manually (Phase 2.5):**

| Parameter | Source | Required Before |
|---|---|---|
| `/{env}/tp/VPC_NAME` | Terraform VPC name | All CDK stacks using VPC |
| `/rds/ticketing-cluster-identifier` | Aurora restore | RdsProxyStack |
| `/rds/ticketing-cluster-sg` | Terraform SG | RdsProxyStack |
| `/{env}/tp/SUBNET_1,2,3` | Terraform subnets | All service stacks |
| `/{env}/tp/SlackNotification/ErrorsWebhookUrl` | Slack workspace | SlackNotificationStack |
| `/{env}/tp/SlackNotification/OperationalErrorsWebhookUrl` | Slack workspace | SlackNotificationStack |
| `/{env}/tp/SlackNotification/SuspiciousOrdersWebhookUrl` | Slack workspace | SlackNotificationStack |
| `/{env}/tp/SlackNotification/IgnoredErrorsPatterns` | Config | Runtime (ErrorFilterService) |
| `/{env}/tp/pdf/generator/STORAGE_BUCKET_NAME` | S3 bucket name | PdfGenerator ConsumersStack |

**Created by ACM + manual SSM put (Phase 3.1):**

| Parameter | Domain | Required Before |
|---|---|---|
| `/{env}/tp/DomainCertificateArn` | `api.{env}.tickets.mdlbeast.net` | GatewayStack |
| `/{env}/tp/geidea/DomainCertificateArn` | `geidea.{env}.tickets.mdlbeast.net` | Geidea ApiStack |

**Auto-created by CDK stacks (no manual action):**

| Parameter | Created By | Used By |
|---|---|---|
| `/{env}/tp/InternalDomainCertificateArn` | InternalCertificateStack | All ServerlessApiStackHelper services |
| `/{env}/tp/ApiGatewayVpcEndpointId` | ApiGatewayVpcEndpointStack | All private serverless APIs |
| `/{env}/tp/consumers/{service}/queue-arn` (x18) | ConsumersSqsStack | Each service's ConsumersStack |
| `/{env}/tp/media/bucket-name` | MediaStorageStack | Media ConsumersStack |
| `/rds/RdsProxyEndpoint` | RdsProxyStack | Service connection strings |
| `/rds/RdsProxyReadOnlyEndpoint` | RdsProxyStack | Service connection strings |
| `/{env}/tp/InternalServices/{ServiceName}` | ServerlessApiStackHelper | Cross-service calls (12 services) |
| `/{env}/tp/extensions/EXTENSION_DEFAULT_ROLE` | ExtensionDeployerStack | Runtime Lambda creation |
| `/{env}/tp/extensions/EXTENSION_LOGS_QUEUE_URL` | ExtensionLogsProcessorStack | Extension executor Lambda |

**Runtime-loaded (not CDK blocking — fail at Lambda invocation if missing):**

| Parameter Path | Loaded By | Notes |
|---|---|---|
| `/{env}/tp/csv/generator/*` | CSV generator Lambda (`Function.ReadSsmParametersAndAddToEnvVars`) | All params under path loaded as env vars |
| `/{env}/tp/pdf/generator/*` | PDF generator Lambda (`Function.ReadSsmParametersAndAddToEnvVars`) | Includes STORAGE_BUCKET_NAME (also CDK blocking) |
| `/{env}/tp/InternalServices/*` | Most service Lambdas (`ParameterStoreHelper.LoadParametersToEnvironmentAsync`) | Used for inter-service HTTP calls. **EXCEPTION:** loyalty, automations, ecwid do NOT call this — rely on env-var base routes (ISSUE-39) |

---

*Review completed: 2026-03-25 (Round 9)*
*Validated against: 30+ service repositories, Terraform configs, CDK stacks, CI/CD workflows, ConfigMaps*
*Round 5: 6 parallel agents — missing services CDK audit, Terraform cross-references, uncovered me-south-1 references, SSM parameters, GitHub secrets, S3 buckets*
*Round 5+: 3 parallel agents — comprehensive SSM audit, S3 bucket naming propagation, Route53 DNS rerouting analysis*
*Round 6: 8 parallel agents — env-var JSON coverage (53 files verified), aws-lambda-tools-defaults count (42 confirmed), uncovered me-south-1 sweep (all source code covered), CDK stack verification (11 infra + 23 service stacks match), Terraform EKS deprecation scope (all files confirmed), secrets/SSM parameter tracing (paths verified via code), CI/CD workflow audit (36 repos, all secrets correct), S3 bucket reference audit (17 buckets, all covered)*
*Round 7: 8 parallel agents — CDK domain mapping verification (6/7 correct, ecwid missing), Terraform EKS cross-references (all files confirmed with line numbers), me-south-1 full sweep (958 refs, all covered by 12 categories), CDK Program.cs stack verification (24 services + infrastructure all match), S3 bucket + secrets path verification (17 buckets, all secret paths confirmed), connection strings + SQS queue naming analysis (3 critical issues found), CI/CD workflow audit (36 repos + ecwid confirmed), DNS cutover logic analysis (CNAME transition gap identified), Aurora restore procedure verification (identifier mismatch and metadata concerns found)*
*Round 9: 7 parallel agents — CDK domain mapping re-verification (all 7 files confirmed, excluded services correctly out of scope), Terraform EKS deprecation (all files verified with cross-references, iam-s3-sqs.tf confirmed safe to delete), me-south-1 sweep (184 files, all covered by 12 categories), CDK stack names (11 infra + 23 service stacks confirmed), secrets/SSM tracing (16 secret paths verified, 16 manual SSM params confirmed), S3 bucket naming (all references covered), CI/CD workflows (35 repos + 3 special secrets confirmed), connection strings (standardized parsing confirmed, regex safe) + SQS (only extension services read queue URLs). New finding: Phase 3 inter-service call failure for loyalty/automations/ecwid/geidea (ISSUE-39)*
