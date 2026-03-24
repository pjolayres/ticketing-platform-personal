# AWS Region Migration Plan Review

**Plan:** `.personal/tasks/2026-03-05_aws-region-migration/plan.md`
**Reviewed:** 2026-03-24 (Round 7)
**Method:** 7 review rounds with 46+ parallel agents validating Terraform, CDK stacks, SSM parameters, CI/CD workflows, S3 buckets, Route53 DNS, me-south-1 reference completeness, Aurora restore procedures, DNS cutover logic, connection string patterns, and SQS queue naming

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

The migration plan is comprehensive and addresses ~97% of the migration scope. Round 7 performed deep cross-referencing with 8 parallel agents examining CDK domain mappings, Terraform EKS deprecation, Aurora restore procedures, connection string patterns, SQS queue naming, CI/CD workflows, DNS cutover logic, and a full me-south-1 sweep. **Round 7 found 4 critical issues** requiring plan updates before execution: (1) ecwid-integration CDK domain mapping missing from Phase 1 Task 10, (2) Aurora cluster/instance identifiers in the plan don't match Terraform resource definitions — `terraform import` will cause drift, (3) SQS queue names in Phase 3.4 scripts don't match CDK naming convention, and (4) three services missing from the SQS_QUEUE_URL update loop. Additionally, 3 high-priority items were identified around Phase 4 DNS cutover timing, RDS Proxy behavioral change, and AWS Backup restore metadata. The plan's core structure — greenfield infrastructure in eu-central-1 via Terraform + CDK, Aurora restored from AWS Backup, Lambda-only (EKS deprecated) — remains sound. All 24 service CDK stack names verified against Program.cs. All Terraform EKS deprecation targets confirmed present.

### Verdict by Phase

| Phase | Status | Remaining Blockers |
|-------|--------|----------|
| Phase 1 (Code Prep) | ~99% Complete | None |
| Phase 2 (Prod Foundation) | ~99% Complete | None |
| Phase 3 (Prod Services) | ~99% Complete | None |
| Phase 4 (DNS Cutover) | ~99% Complete | None |
| Phase 5 (Dev+Sandbox) | ~98% Complete | Mirrors Phase 2/3 |
| Post-Migration | ~98% Complete | None |

### Open Item Summary

| Severity | Count | IDs |
|----------|-------|-----|
| CRITICAL | 0 | All resolved |
| HIGH | 0 | All resolved |
| MEDIUM | 2 | ISSUE-9 (provisioned concurrency), ISSUE-11 (demo env) |
| LOW | 1 | ISSUE-38 (IDE workspace files) |

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

### Third-Party Integrations
- Auth0, Checkout.com, SendGrid, Sentry, Seats.io — all SaaS, region-agnostic ✓

---

## Recommendations Summary

### Before Starting Phase 1 (MUST FIX — Round 7)

1. **Add ecwid domain mapping** to Phase 1 Task 10 and Phase 4.1 revert table (ISSUE-31)
2. **Fix Terraform RDS identifiers** — update `rds.tf` cluster_identifier to `"ticketing-eu"` and instance identifier pattern to `"ticketing-eu-instance-${count.index}"` (ISSUE-32)
3. **Correct SQS queue names** in Phase 3.4 Step 6 to match CDK naming convention: `{ConsumerEnumName}-queue-{env}` (ISSUE-33)
4. **Add transfer, reporting, media** to Phase 3.4 Step 6 SQS update loop (ISSUE-34)
5. **Add post-restore security group step** to Phase 2.6 as fallback (ISSUE-37)

### Before Starting Phase 1 (SHOULD FIX)

6. **Document RDS Proxy behavioral change** in Phase 3.4 — note this is intentional upgrade from direct RDS to proxied connections (ISSUE-36)
7. **Add Phase 4.3 deployment guidance** — minimize gap between InternalHostedZoneStack and ServerlessBackendStack redeployments; add `cdk diff` dry-runs and DNS verification steps (ISSUE-35)
8. **Add ecwid-integration** to Phase 4.4 GitHub secrets repo list

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
| `/{env}/tp/InternalServices/*` | All service Lambdas (`ParameterStoreHelper.LoadParametersToEnvironmentAsync`) | Used for inter-service HTTP calls |

---

*Review completed: 2026-03-24 (Round 7)*
*Validated against: 30+ service repositories, Terraform configs, CDK stacks, CI/CD workflows, ConfigMaps*
*Round 5: 6 parallel agents — missing services CDK audit, Terraform cross-references, uncovered me-south-1 references, SSM parameters, GitHub secrets, S3 buckets*
*Round 5+: 3 parallel agents — comprehensive SSM audit, S3 bucket naming propagation, Route53 DNS rerouting analysis*
*Round 6: 8 parallel agents — env-var JSON coverage (53 files verified), aws-lambda-tools-defaults count (42 confirmed), uncovered me-south-1 sweep (all source code covered), CDK stack verification (11 infra + 23 service stacks match), Terraform EKS deprecation scope (all files confirmed), secrets/SSM parameter tracing (paths verified via code), CI/CD workflow audit (36 repos, all secrets correct), S3 bucket reference audit (17 buckets, all covered)*
*Round 7: 8 parallel agents — CDK domain mapping verification (6/7 correct, ecwid missing), Terraform EKS cross-references (all files confirmed with line numbers), me-south-1 full sweep (958 refs, all covered by 12 categories), CDK Program.cs stack verification (24 services + infrastructure all match), S3 bucket + secrets path verification (17 buckets, all secret paths confirmed), connection strings + SQS queue naming analysis (3 critical issues found), CI/CD workflow audit (36 repos + ecwid confirmed), DNS cutover logic analysis (CNAME transition gap identified), Aurora restore procedure verification (identifier mismatch and metadata concerns found)*
