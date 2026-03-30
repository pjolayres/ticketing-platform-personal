# AWS Region Migration Summary (me-south-1 → eu-central-1)

This document combines the migration plan and execution log into a single context-efficient reference for agents. Read this instead of `plan.md` + `execution.md` to get full context on what was planned, what actually happened, and what remains. Pointers like `→ plan.md §4.3` or `→ execution.md §P3-S5-01` direct you to deeper detail in the source documents.

---

## Context

The MDLBEAST Ticketing Platform is migrating from AWS **me-south-1** (Bahrain) to **eu-central-1** (Frankfurt). This is a **disaster recovery + region migration** — me-south-1 suffered a regional data center failure and is completely down. There is no live traffic to cut over and no rollback path to me-south-1.

**Strategy:** Greenfield infrastructure in eu-central-1 with Aurora and S3 restored from AWS Backup cross-region copies. Lambda-only deployment (EKS deprecated). Production deploys under temporary subdomain `production-eu.tickets.mdlbeast.net` for safe testing before DNS cutover to `production.tickets.mdlbeast.net`. → plan.md §Context

**Migration order:** Production (account `660748123249`) first → validate under temporary domain → DNS cutover → Dev+Sandbox rebuild (account `307824719505`)

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Migration order | Production first | Only prod has AWS Backup (Aurora + S3). Dev/sandbox must be rebuilt fresh. |
| Temporary domain | `production-eu.tickets.mdlbeast.net` | Full E2E testing before touching live DNS |
| EKS/Kubernetes | Deprecated — Lambda-only | Services already run as Lambda; EKS adds complexity with no value |
| Self-hosted runners | Removed — GitHub-hosted | Runners only existed for kubectl/EKS |
| Redis/ElastiCache | Removed | Zombie infra: zero connections, code uses DynamoDB + in-memory |
| OpenSearch/Elasticsearch | Removed | Ghost config: no Serilog Elasticsearch sink installed |
| Data migration | Restore from AWS Backup | me-south-1 is down; live replication impossible |
| `demo` environment | Deferred | Not critical path |
| XP Badges, Bandsintown, Marketing Feeds | Excluded | Unused services due for deprecation |

→ plan.md §Decisions

---

## Phase Overview and Current Status

| Phase | Description | Status | Dates |
|-------|-------------|--------|-------|
| **Phase 1** | Code preparation (no infra changes) | **DONE** | 2026-03-25 |
| **Phase 2** | Production foundation & data restore | **DONE** | 2026-03-25 to 2026-03-26 |
| **Phase 3** | Production services under temporary domain | **DONE** | 2026-03-26 to 2026-03-27 |
| **Phase 4** | DNS cutover to production domain | **DONE** | 2026-03-27 to 2026-03-30 |
| **Phase 5** | Dev+Sandbox rebuild (fresh) | PENDING | — |
| **Post-Migration** | Cleanup, backup config, monitoring | PARTIAL (PM-2 done) | — |

---

## Phase 1: Code Preparation — COMPLETED

All 20 tasks completed on 2026-03-25. Branch `hotfix/region-migration-eu-central-1` created in 34+ repos. → execution.md §P1-T0 through §P1-T20

**What was done:**
- Updated all `me-south-1` references to `eu-central-1` across Terraform, CDK env-var JSON, `aws-lambda-tools-defaults.json`, C# code, test files, ConfigMaps, CI/CD, dashboard CSP/env files, mobile scanner workflows, and local dev settings
- Removed EKS/Redis/OpenSearch/WAF/MSK/runner resources from Terraform (prod + dev)
- Renamed S3 buckets to `-eu` suffix in CDK env-var files (bucket names are globally unique)
- Set temporary `production-eu` domain mapping in 7 CDK files across 5 repos
- Disabled EKS-related CI/CD workflows (changed trigger to `workflow_dispatch` instead of deleting)
- Security: added `.gitignore` for `.tfstate`, fixed S3 lifecycle bug, removed plaintext Elasticsearch creds
- Commented out RDS cluster from Terraform (restored from backup instead)
- Merged `ticketing-platform-tools` to master, published NuGet `1.0.1300`, bumped in 22 service repos
- Tests passed (no regressions), zero `me-south-1` in deployable source code

**Key deviation:** Plan listed 14 repos for env-var update; script found 18 (more repos had demo env files). Plan listed 22 repos for lambda-tools; found 25 (3 extra deprecated repos). → execution.md §Deviations Log (P1-T4, P1-T5)

---

## Phase 2: Production Foundation & Data Restore — COMPLETED

All steps completed 2026-03-25 to 2026-03-26. → execution.md §P2-S1 through §P2-VERIFY

### Infrastructure Created
- **VPC:** `vpc-00de5834b0f381b4d` (CIDR `10.10.0.0/16`, 3 AZs)
- **Subnets:** 12 total (3 Lambda, 3 RDS, 3 NAT, management, OpenVPN, Prometheus) — no EKS/Redis/OpenSearch subnets
- **NAT Gateways:** 3 (one per AZ)
- **S3 Buckets:** `ticketing-csv-reports-eu`, `tickets-pdf-download-eu`, `ticketing-app-mobile-eu`, `ticketing-terraform-prod-eu`, `ticketing-terraform-github-eu`
- **KMS Key:** `72ea5a94-3fbc-494a-baa6-79f3d4c82121`
- **CloudFront:** `E2E0LQF2V6W4U` (s3_prod), `E1NNQYK06MZJSB` (mobile) — new distribution IDs, dashboard code needs updating
- **Route53:** `production.tickets.mdlbeast.net` zone imported (`Z095340838T2KOPA8X742`). `tickets.mdlbeast.net` does NOT exist in Route53 (managed in Cloudflare).

### Data Restored
- **Aurora:** Cluster `ticketing` restored from AWS Backup (engine: PostgreSQL 15.12, 3 serverless instances, scaling: 1.5-64 ACU). Endpoint: `ticketing.cluster-c0lac6czadei.eu-central-1.rds.amazonaws.com`
- **S3:** 3 buckets restored from cross-region backup copies (tickets-pdf-download, ticketing-csv-reports, ticketing-app-mobile). `ticketing-prod-media-eu` is empty (no backup copies existed).

### Secrets & Parameters
- **25 Secrets Manager secrets** in eu-central-1 (21 `/prod/*` + `terraform` + `/rds/ticketing-cluster` + `prod/data` + `devops`)
- Secrets were replicated from me-south-1 (API became available during execution) rather than manually recreated from backups
- **36 SSM parameters** (33 under `/prod/tp/`, 3 under `/rds/`) — plan undercounted at 16; live me-south-1 query revealed full set
- **DynamoDB `Cache` table** created (PAY_PER_REQUEST, CacheKey HASH, TTL on ExpirationTime)
- **CDK Bootstrap** completed (CDKToolkit stack)

### Key Deviations → execution.md §Deviations Log (P2-S3 through P2-S7)
- 34 global resources (IAM, CloudFront OACs, S3 state bucket) had to be imported into Terraform — plan assumed fresh creation
- `ROOT_ZONE_ID` is N/A — `tickets.mdlbeast.net` zone doesn't exist; NS delegation is managed in Cloudflare
- S3 bucket renames in Terraform were missed in Phase 1 — fixed during terraform apply
- Aurora restore required specific metadata format; scaling config must be set before creating instances
- Replicated secrets retained old Elasticsearch/Redis keys (harmless — code already removed; all overwritten in P3-S4)
- S3 restores required temporarily relaxing ACL/ownership settings on destination buckets

---

## Phase 3: Production Services under Temporary Domain — COMPLETED

All steps completed 2026-03-26 to 2026-03-27. P3-VERIFY passed 2026-03-27. → execution.md §P3-S1 through §P3-VERIFY

### Completed Steps

**P3-S1: Temporary Route53 Zone** — `production-eu.tickets.mdlbeast.net` zone created (`Z0663446BTJAVD4MTCYG`). NS delegation added in **Cloudflare** (not Route53). Post-migration cleanup must remove NS records from Cloudflare. → execution.md §P3-S1

**P3-S2: ACM Certificates** — 3 certificates issued. → execution.md §P3-S2
- Gateway: `arn:aws:acm:eu-central-1:660748123249:certificate/914c47a3-f0df-4e5c-a406-747f62fb2228`
- Geidea: `arn:aws:acm:eu-central-1:660748123249:certificate/773c5a63-304a-476c-95dd-877065f91581`
- Ecwid: `arn:aws:acm:eu-central-1:660748123249:certificate/75e4cc24-20cc-491d-b87c-20ae2647f2b9`

**P3-S3: Infrastructure CDK (11 stacks)** — All deployed. VPC required `enable_dns_hostnames = true` fix. → execution.md §P3-S3

**P3-S4: Connection Strings & Secrets** — 22 replica secrets promoted to standalone. New CICD IAM key created (`AKIAZTV5IHRY3JAPWUFD`). 19 secrets updated with correct Aurora endpoints, SQS URLs, IAM keys. Blanket `me-south-1` → `eu-central-1` replacement. `prod/data` still has me-south-1 Glue bucket ref (not in scope). Ecwid still missing 8 vendor config keys. → execution.md §P3-S4

**P3-S5: Per-Service CDK Deployment (24 services)** — ALL 24 DONE. → execution.md §P3-S5-01 through §P3-S5-24

**P3-S5.1: Repackage & Redeploy Non-API Lambdas (DIAG-002)** — All 23 Consumer, Automations, and standalone Lambdas repackaged with `dotnet lambda package -c Release` and redeployed. All 23 stacks confirmed `UPDATE_COMPLETE`. → [diagnostics.md](diagnostics.md#diag-002)

**P3-S6: End-to-End Validation** — DEFERRED. Infrastructure-level checks passed (API Gateway responds, EventBridge/SQS wired, CloudWatch active, 112 Lambda functions all Active). Manual business-logic tests (create event, process order, PDF generation, etc.) deferred to P4-S6 on production domain. → execution.md §P3-S6

**P3-VERIFY: Phase 3 Verification** — DONE (2026-03-27). All 8 checklist items passed: 11 infrastructure stacks, 81 service stacks across 24 services, 14 DB migrators, 112 Lambda functions, 19 EventBridge rules, 43 SQS queues, 14 internal CNAME records, zero PLACEHOLDER values in secrets. → execution.md §P3-VERIFY

### Deployment Patterns Learned (Critical for Future Reference)

1. **`dotnet lambda package -c Release`** must run from each Lambda project directory (not `dotnet publish`). `dotnet publish` does NOT generate `.runtimeconfig.json` for `Microsoft.NET.Sdk` (class library) projects. Only `Microsoft.NET.Sdk.Web` API projects survive `dotnet publish`. → diagnostics.md §DIAG-001, §DIAG-002
2. **IAM roles are global** — every stack's IAM role already exists from me-south-1. Must use `cdk import` before `cdk deploy`. Never attempt `cdk deploy` directly. → execution.md §P3-S5-01
3. **63 stale inline policies** were bulk-deleted in P3-S5-02 (backup at `backup-iam-policies/`). Some DefaultPolicy policies survived and required per-service cleanup. → execution.md §P3-S5-02
4. **Log groups must be pre-created** for ALL Lambda functions (serverless, consumers, AND background-jobs) before deploying stacks with Slack SubscriptionFilters. → execution.md §P3-S5-03
5. **DB migrations return "No pending migrations"** — databases restored from backup already have all migrations.
6. **Private API Gateways** — cannot curl from outside VPC. Health checks via `aws lambda invoke` or OpenVPN instance.
7. **Helper script** `deploy-service-cdk.sh` automates synth → extract IAM roles → import → deploy pattern.
8. **CDK environment variables:** `AWS_PROFILE`, `CDK_DEFAULT_ACCOUNT=660748123249`, `CDK_DEFAULT_REGION=eu-central-1`, `ENV_NAME=prod`

### Per-Service Deployment Results → execution.md §P3-S5-01 through §P3-S5-24

| # | Service | Status | Health | Special Notes |
|---|---------|--------|--------|---------------|
| 1 | catalogue | DONE | Healthy | First deployment; discovered SSM subnet prefix bug (fixed globally), IAM import pattern, RDS SG Lambda access rule |
| 2 | organizations | DONE | Healthy | SQS visibility timeout fix in infrastructure CDK; bulk-deleted 63 stale IAM policies |
| 3 | loyalty | DONE | N/A (no API) | Discovered background-jobs log group pre-creation requirement |
| 4 | csv-generator | DONE | N/A (no API) | Consumer-only |
| 5 | pdf-generator | DONE | N/A (no API) | 250MB Lambda limit exceeded — CDK DLLs + SkiaSharp cleaned from publish dir |
| 6 | automations | DONE | N/A (no API) | Stale DefaultPolicy on finance_report_sender role not caught by bulk cleanup |
| 7 | extension-api | DONE | Healthy | Clean deployment |
| 8 | extension-deployer | DONE | N/A | Docker Lambda — deployed via `dotnet lambda deploy-function` per CI/CD `main.yml` BEFORE CDK. Must use `--docker-build-options "--platform linux/amd64"` from Apple Silicon Macs (DIAG-003). CDK only references existing Lambda. |
| 9 | extension-executor | DONE | N/A (no API) | Clean deployment |
| 10 | extension-log-processor | DONE | N/A (no API) | Clean deployment |
| 11 | customer-service | DONE | Healthy | Clean deployment |
| 12 | inventory | DONE | Healthy | Clean deployment |
| 13 | pricing | DONE | Healthy | Clean deployment |
| 14 | media | DONE | Healthy | IAM user `imgix-prod` import required (only service with IAM user in CDK); orphaned S3 bucket import |
| 15 | reporting-api | DONE | Healthy | Clean deployment |
| 16 | marketplace | DONE | Healthy | Clean deployment |
| 17 | integration | DONE | Healthy | Clean deployment |
| 18 | distribution-portal | DONE | Healthy | Missing `SalesServiceBaseRoute` env var (was in K8s configmap, not Lambda) — added to `env-var.prod.json` |
| 19 | sales | DONE | Healthy | Inter-service route URLs now point to `production.tickets.mdlbeast.net` (resolved by Phase 4) |
| 20 | access-control | DONE | Healthy | 3 stale DefaultPolicy policies survived bulk cleanup; Lambda uses `accesscontrol-` prefix (no hyphen) |
| 21 | transfer | DONE | Healthy | Clean deployment |
| 22 | geidea | DONE | N/A | Clean deployment; API at `geidea.production-eu.tickets.mdlbeast.net` |
| 23 | ecwid-integration | DONE | N/A | Ecwid secret still missing vendor config keys — functions won't work until populated |
| 24 | gateway (LAST) | DONE | Healthy | API at `api.production-eu.tickets.mdlbeast.net`; 112 Lambda functions total in eu-central-1 |

---

## Phase 4: DNS Cutover to Production Domain — COMPLETED

All steps completed 2026-03-27 to 2026-03-30. → plan.md §Phase 4 for planned steps; execution.md §P4-S1 through §P4-S9 for results

### Steps

**P4-S1: Revert Domain Mapping** — DONE (2026-03-27). Reverted 7 occurrences of `"production-eu"` → `"production"` across 5 repos (ticketing-platform-tools, gateway, infrastructure, geidea, ecwid-integration). Deleted 18 `cdk.context.json` files to clear cached lookups. → execution.md §P4-S1

**P4-S1.1: Publish NuGet v1.0.1301** — DONE (2026-03-27). Published via PR #1273. Bumped 25 repos (plan said 18 — included 7 additional: loyalty, csv-generator, pdf-generator, automations, extension-deployer, extension-executor, extension-log-processor). 117 `.csproj` files updated total. → execution.md §P4-S1.1

**P4-S2: ACM Certificates for Production Domain** — DONE (2026-03-27). 3 certificates created, DNS-validated via Route53 zone `Z095340838T2KOPA8X742`, ARNs stored in SSM. → execution.md §P4-S2
- Gateway: `arn:aws:acm:eu-central-1:660748123249:certificate/fd763671-01f5-4957-82d8-e321800b127d` → SSM `/production/tp/DomainCertificateArn`
- Geidea: `arn:aws:acm:eu-central-1:660748123249:certificate/947916fe-e54c-4f89-b860-64355a8c685e` → SSM `/prod/tp/geidea/DomainCertificateArn`
- Ecwid: `arn:aws:acm:eu-central-1:660748123249:certificate/0bf7cca4-fd68-4786-9bbe-990758f805b1` → SSM `/prod/tp/ecwid/DomainCertificateArn`

**P4-S3: Redeploy Public-Facing Stacks** — DONE (2026-03-27, ~75 min). 16 stacks redeployed total (5 public + 14 ServerlessBackendStack in parallel). CNAME gap ~25 minutes. → execution.md §P4-S3
- New internal hosted zone: `Z05628001T92EME2ZM0Z6` (`internal.production.tickets.mdlbeast.net`)
- Old `internal.production-eu` zone orphaned: `Z04720843DJKNCF1N97H0` (non-empty, CloudFormation couldn't delete — 14 stale CNAMEs)
- 3 stale me-south-1 A records had to be deleted before Gateway/Geidea/Ecwid deploys succeeded
- APIs now live at: `api.production.tickets.mdlbeast.net`, `geidea.production.tickets.mdlbeast.net`, `ecwid.production.tickets.mdlbeast.net`

**P4-S4: Update GitHub Secrets & Variables** — DONE (2026-03-27). ~48 secrets updated across org-level, environment-level (13 repos had env secrets shadowing org values), repo-level, and mobile-scanner levels. → execution.md §P4-S4
- `AWS_DEFAULT_REGION` → `eu-central-1` everywhere
- IAM credentials updated on all prod environments
- Mobile scanner production environment updated with new CloudFront/S3 values
- **Skipped:** Dashboard Storybook variables (S3 bucket + CloudFront don't exist yet in eu-central-1)
- **Deferred:** Dev/sandbox environment secrets still point to me-south-1 (Phase 5)

**P4-S5: Merge to Production & Deploy Frontends** — DONE (2026-03-30). All hotfix branches merged to `master`/`production` across all repos. Dashboard redeployed via Vercel. Distribution Portal Frontend verified. Mobile Scanner release build triggered. All CI/CD workflows executed via GitHub Actions. → execution.md §P4-S5

**P4-S6: E2E Validation (Production Domain)** — DONE (2026-03-30). Full ticket lifecycle validated: dashboard login (prod Auth0), create event → tickets → order → PDF → scan, payment flow (Geidea webhook), CSV reports, media upload/download, inter-service event flow, Slack error notifications (eu-central-1 console links), CloudWatch logs + X-Ray traces, DNS resolution for all public endpoints, mobile scanner connectivity. → execution.md §P4-S6

**P4-S7: Post-Go-Live Monitoring** — DONE (2026-03-30). CloudWatch dashboards configured, Slack error channel monitored, Sentry checked for new patterns, RDS metrics nominal. Production stable. → execution.md §P4-S7

**P4-S8: Migrate `ticketing-glue-gcp` S3 Bucket** — DONE (2026-03-29 to 2026-03-30, AWS-side complete). `ticketing-glue-gcp-eu` bucket created, data synced, `/prod/automations` secret updated. PR [#40](https://github.com/mdlbeasts/ticketing-platform-automations/pull/40) merged — CDK deployed with IAM ARN updates and scheduler disabled. → plan.md §4.8; execution.md §P4-S8
- [x] Merge PR → CI/CD deploys CDK (IAM updated, scheduler disabled, errors stop)
- [ ] GCP team updates 16 BigQuery Data Transfer configs (`s3://ticketing-glue-gcp/...` → `s3://ticketing-glue-gcp-eu/...`) in project `127814635375`
- [ ] Re-enable scheduler: remove `Enabled = false` from `AutomaticDataExporterStack.cs`, merge new PR

**P4-S9: Fix Stale RDS Endpoint in `FINANCE_REPORT_SENDER_CONFIG`** — DONE (2026-03-29). FinanceReportSender Lambda was failing with `SocketException` (DNS NXDOMAIN) because `FINANCE_REPORT_SENDER_CONFIG` in `/prod/automations` had 3 connection strings pointing to old Aurora cluster ID `cocuscg4fsup` (doesn't exist in eu-central-1). The bulk secret migration (P3-S4) updated the region but the cluster ID changed because Aurora was restored from backup (new cluster = `c0lac6czadei`). Fixed by replacing the cluster ID in all 3 connection strings (sales, catalogue, organizations) and forcing a Lambda cold start. Comprehensive audit confirmed no other stale RDS references across all 24 secrets. → plan.md §4.9; execution.md §P4-S9

### Key Deviations (Phase 4) → execution.md §Deviations Log

16. **P4-S1.1: Bumped 25 repos** instead of planned 18 — included 7 additional repos for unified versioning.
17. **P4-S3: Stale me-south-1 A records** in `production.tickets.mdlbeast.net` zone blocked Gateway/Geidea/Ecwid deploys. Deleted 3 records, retried. Old `internal.production-eu` zone orphaned (non-empty).
18. **P4-S4: ~48 secrets updated** (plan undercounted) — 13 repos had environment-level secrets shadowing org-level values. Storybook variables skipped (no infra). Dev/sandbox secrets deferred to P5.
19. **P4-S8: `ticketing-glue-gcp` bucket missed entirely** from migration plan — not in S3 Bucket Naming Strategy, not managed by Terraform, only referenced in automations CDK IAM policies. Discovered via AutomaticDataExporter Lambda errors.
20. **P4-S9: Stale RDS cluster ID in `FINANCE_REPORT_SENDER_CONFIG`** — bulk secret migration (P3-S4) updated the region but not the Aurora cluster ID, which changed from `cocuscg4fsup` to `c0lac6czadei` because Aurora was restored from backup. Only affected `FINANCE_REPORT_SENDER_CONFIG` (3 nested connection strings); all other secrets had the correct cluster ID.

---

## Phase 5: Dev+Sandbox Rebuild — PENDING

→ plan.md §Phase 5; execution.md §P5-S1 through §P5-S3

Fresh rebuild in account `307824719505`. Same pattern as Phase 2+3 but with key differences:
- RDS cluster NOT commented out — Terraform creates it fresh (no backup restore needed)
- DB migrations CREATE schemas (not "No pending migrations" like prod)
- Need seed test data — databases start empty
- Two environments in one account: `dev` + `sandbox` (11 CDK stacks × 2 envs)
- IAM role conflicts may still apply if me-south-1 CDK stacks created global roles for dev/sandbox

**Foundation:** Terraform state bucket, secrets, Route53 zone imports, `terraform apply` (includes RDS), SSM parameters, DynamoDB `Cache` table, CDK bootstrap.

**Services:** ACM certificates, 11 infrastructure CDK stacks × 2 envs, connection strings, all service stacks, DB migrations, seed data, branch merges to `development`/`sandbox`, smoke tests.

---

## Post-Migration Tasks

→ plan.md §Post-Migration Tasks; execution.md §PM-1 through §PM-4

1. **PM-1:** Delete `production-eu.tickets.mdlbeast.net` zone + remove NS from **Cloudflare** (not Route53). **Also** clean up orphaned internal zone `Z04720843DJKNCF1N97H0`. Delete 3 temporary ACM certs + SSM param `/production-eu/tp/DomainCertificateArn`. — PENDING
2. **PM-2:** Redeploy user-created extension Lambdas via extension-deployer — **DONE** (2026-03-27). Redeployed through dashboard by changing version comments. Disabled extensions had to be enabled first to trigger redeployment, then disabled again. → execution.md §PM-2
3. **PM-3:** Configure AWS Backup in eu-central-1 for new resources (Aurora + S3) — PENDING
4. **PM-4:** After 7-day stability + me-south-1 recovery: delete old resources, clean up IAM, archive ConfigMap repos, remove Helm charts, rotate credentials, update documentation — PENDING

---

## Uncommitted Changes Tracker

These repos have local changes that need to be committed:

| Repo | File(s) | Change | Introduced By | Status |
|------|---------|--------|---------------|--------|
| `ticketing-platform-terraform-prod` | `prod/vpc.tf` | Added `enable_dns_hostnames = true` | P3-S3 | Uncommitted |
| `ticketing-platform-terraform-prod` | `prod/rds.tf` | Added VPC CIDR Lambda ingress rule on port 5432 | P3-S5-01 | Uncommitted |
| `ticketing-platform-terraform-prod` | `prod/s3.tf`, `prod/variables.tf`, `prod/mobile.tf`, `prod/group.tf` | S3 bucket renames, IAM policy updates, MSK removal | P2-S4 | Uncommitted |
| `ticketing-platform-infrastructure` | `ConsumersSqsStack.cs` | Added Organization service timeout override (900s) | P3-S5-02 | Committed during P3-VERIFY |
| `ticketing-platform-distribution-portal` | `env-var.prod.json` | Added `SalesServiceBaseRoute` env var | P3-S5-18 | Committed (`19cd521`) during P3-VERIFY |

**Note:** `ticketing-platform-terraform-prod` still has multiple uncommitted changes across several files. These must be committed before any future `terraform apply` or they risk being lost.

---

## Shared Outputs Registry (Key Values)

| Key | Value |
|-----|-------|
| VPC_ID | `vpc-00de5834b0f381b4d` |
| SUBNET_1/2/3 | `subnet-01b47a6d26df020ec` / `subnet-0b38abd7f712530d9` / `subnet-05359403da2d9a5fe` |
| RDS_SG_ID | `sg-00dab49088126dfa7` |
| KMS_KEY_ID | `72ea5a94-3fbc-494a-baa6-79f3d4c82121` |
| AURORA_ENDPOINT | `ticketing.cluster-c0lac6czadei.eu-central-1.rds.amazonaws.com` |
| AURORA_RO_ENDPOINT | `ticketing.cluster-ro-c0lac6czadei.eu-central-1.rds.amazonaws.com` |
| RDS_USER | `devops` |
| PROD_ZONE_ID | `Z095340838T2KOPA8X742` |
| TEMP_ZONE_ID | `Z0663446BTJAVD4MTCYG` (to be deleted in PM-1) |
| INTERNAL_ZONE_ID_PROD | `Z05628001T92EME2ZM0Z6` (`internal.production.tickets.mdlbeast.net`) |
| ORPHANED_ZONE_ID | `Z04720843DJKNCF1N97H0` (old `internal.production-eu` — to be deleted in PM-1) |
| CERT_ARN_GATEWAY_TEMP | `arn:aws:acm:eu-central-1:660748123249:certificate/914c47a3-f0df-4e5c-a406-747f62fb2228` |
| CERT_ARN_GEIDEA_TEMP | `arn:aws:acm:eu-central-1:660748123249:certificate/773c5a63-304a-476c-95dd-877065f91581` |
| CERT_ARN_ECWID_TEMP | `arn:aws:acm:eu-central-1:660748123249:certificate/75e4cc24-20cc-491d-b87c-20ae2647f2b9` |
| CERT_ARN_GATEWAY_PROD | `arn:aws:acm:eu-central-1:660748123249:certificate/fd763671-01f5-4957-82d8-e321800b127d` |
| CERT_ARN_GEIDEA_PROD | `arn:aws:acm:eu-central-1:660748123249:certificate/947916fe-e54c-4f89-b860-64355a8c685e` |
| CERT_ARN_ECWID_PROD | `arn:aws:acm:eu-central-1:660748123249:certificate/0bf7cca4-fd68-4786-9bbe-990758f805b1` |
| NEW_AWS_KEY | `AKIAZTV5IHRY3JAPWUFD` |
| NUGET_VERSION_1 | `1.0.1300` |
| NUGET_VERSION_2 | `1.0.1301` |
| OpenVPN Instance | `i-0f005875786d8cc94` (Elastic IP: `18.193.92.249`) |
| CloudFront s3_prod | `E2E0LQF2V6W4U` → `d2o70nzt59y9cv.cloudfront.net` |
| CloudFront mobile | `E1NNQYK06MZJSB` → `d36feu62yikku8.cloudfront.net` |

→ execution.md §Shared Outputs Registry for full provenance (Produced By / Consumed By)

---

## Deviations Summary (Quick Reference)

These are the most impactful deviations from the original plan. Agents should be aware of these before executing any step. → execution.md §Deviations Log for per-step details.

**Phase 1-3 Deviations:**
1. **DNS is managed in Cloudflare**, not Route53 — `tickets.mdlbeast.net` zone doesn't exist in Route53. NS delegation for `production-eu` was added in Cloudflare. → execution.md §P3-S1
2. **Secrets were replicated** (not manually recreated) — 22 secrets required promotion from replica to standalone before updating. → execution.md §P2-S3, §P3-S4
3. **34 global resources imported** into Terraform — IAM, CloudFront OACs, S3 state bucket are global and already existed. → execution.md §P2-S4
4. **New CloudFront distribution IDs** — dashboard has hardcoded old IDs that need updating. → execution.md §P2-S4
5. **SSM params: 35 created** (plan said 16) — me-south-1 API came back, revealing the full parameter set. → execution.md §P2-S5
6. **IAM role conflicts** on every CDK deploy — solved by synth → extract → import → deploy pattern. → execution.md §P3-S5-01
7. **63 stale inline policies** bulk-deleted; some DefaultPolicy policies survived and required per-service cleanup. → execution.md §P3-S5-02
8. **Organization SQS visibility timeout** fixed in infrastructure CDK (`ConsumersSqsStack.cs`). → execution.md §P3-S5-02
9. **VPC DNS hostnames** had to be enabled (Terraform `vpc.tf` fix) for API Gateway VPC endpoints. → execution.md §P3-S3
10. **RDS SG Lambda access** — VPC CIDR ingress rule added to Terraform `rds.tf` for Lambda→RDS connectivity. → execution.md §P3-S5-01
11. **Distribution-portal** missing `SalesServiceBaseRoute` (was in K8s configmap, not Lambda env vars). → execution.md §P3-S5-18
12. **pdf-generator** 250MB Lambda limit — CDK DLLs + SkiaSharp multi-platform runtimes cleaned from publish dir. → execution.md §P3-S5-05
13. **extension-deployer** Docker Lambda — follow CI/CD `main.yml` sequence: `dotnet restore` → `dotnet build` → `dotnet lambda deploy-function` (with `--docker-build-options "--platform linux/amd64"` on Apple Silicon). Must deploy BEFORE CDK (CDK only creates SQS mapping). → execution.md §P3-S5-08, diagnostics.md §DIAG-003
14. **Ecwid secret** still missing 8 vendor config keys — functions deployed but won't work until populated. → execution.md §P3-S5-23
15. **`dotnet publish` breaks ALL non-API Lambdas** (DIAG-002) — 23 consumers, automations, and standalone Lambdas deployed with missing `.runtimeconfig.json`. Must use `dotnet lambda package` for any `Microsoft.NET.Sdk` project. → diagnostics.md §DIAG-002

**Phase 4 Deviations:**
16. **P4-S1.1: Bumped 25 repos** instead of planned 18 — included 7 additional repos for unified versioning. → execution.md §P4-S1.1
17. **P4-S3: Stale me-south-1 A records** in `production.tickets.mdlbeast.net` zone blocked Gateway/Geidea/Ecwid deploys. Deleted 3 records, retried. Old `internal.production-eu` zone orphaned (non-empty). → execution.md §P4-S3
18. **P4-S4: ~48 secrets updated** (plan undercounted) — 13 repos had environment-level secrets shadowing org-level values. Storybook variables skipped (no infra). Dev/sandbox secrets deferred to P5. → execution.md §P4-S4
19. **P4-S8: `ticketing-glue-gcp` bucket missed entirely** from migration plan — not in S3 Bucket Naming Strategy, not managed by Terraform, only referenced in automations CDK IAM policies. Discovered via AutomaticDataExporter Lambda errors. → execution.md §P4-S8
20. **P4-S9: Stale RDS cluster ID in `FINANCE_REPORT_SENDER_CONFIG`** — bulk secret migration (P3-S4) updated the region but not the Aurora cluster ID, which changed from `cocuscg4fsup` to `c0lac6czadei` because Aurora was restored from backup. Only affected `FINANCE_REPORT_SENDER_CONFIG` (3 nested connection strings); all other secrets had the correct cluster ID. → execution.md §P4-S9

---

## S3 Bucket Naming Map (Old → New)

S3 bucket names are globally unique. Cannot reuse names while me-south-1 buckets exist. All new buckets use `-eu` suffix.

| me-south-1 Bucket | eu-central-1 Bucket | Purpose | Backup Restored? |
|---|---|---|---|
| `tickets-pdf-download` | `tickets-pdf-download-eu` | Prod PDF download (CloudFront origin) | YES (1000+ objects) |
| `ticketing-csv-reports` | `ticketing-csv-reports-eu` | Prod CSV reports | YES (1000+ objects) |
| `ticketing-app-mobile` | `ticketing-app-mobile-eu` | Mobile scanner app assets | YES (59 objects) |
| `ticketing-prod-media` | `ticketing-prod-media-eu` | Prod media uploads | NO (empty — no backup copies existed) |
| `ticketing-prod-extended-message` | `ticketing-prod-extended-message-eu` | Large event payloads | N/A (CDK-created on demand) |
| `ticketing-terraform-prod` | `ticketing-terraform-prod-eu` | Terraform state | N/A (fresh) |
| `ticketing-terraform-github` | `ticketing-terraform-github-eu` | Terraform CI/CD sync | N/A (fresh) |
| `ticketing-glue-gcp` | `ticketing-glue-gcp-eu` | GCP BigQuery data export | Synced (P4-S8) |
| `dev-pdf-tickets` | `dev-pdf-tickets-eu` | Dev PDF tickets | Phase 5 |
| `sandbox-pdf-tickets` | `sandbox-pdf-tickets-eu` | Sandbox PDF tickets | Phase 5 |
| `ticketing-dev-media` | `ticketing-dev-media-eu` | Dev media | Phase 5 |
| `ticketing-sandbox-media` | `ticketing-sandbox-media-eu` | Sandbox media | Phase 5 |
| `ticketing-dev-csv-reports` | `ticketing-dev-csv-reports-eu` | Dev CSV reports | Phase 5 |
| `ticketing-sandbox-csv-reports` | `ticketing-sandbox-csv-reports-eu` | Sandbox CSV reports | Phase 5 |
| `ticketing-terraform-dev` | `ticketing-terraform-dev-eu` | Dev Terraform state | Phase 5 |

**Where bucket names are referenced (and were updated):**
- Terraform `s3.tf` / `variables.tf` / `mobile.tf` — bucket resource definitions and IAM policy ARNs
- CDK `env-var.*.json` — `STORAGE_BUCKET_NAME`, `MEDIA_STORAGE_BUCKET_NAME`, `STORAGE_BUCKET_NAME_PDF` (media + integration services)
- CDK IAM policies — `AutomaticDataExporterStack.cs`, `GeideaDataExporterStack.cs` (automations, for glue bucket)
- Dashboard `vercel.json` CSP — 6 hardcoded S3 URLs (bucket name + region)
- SSM parameters — `/{env}/tp/pdf/generator/STORAGE_BUCKET_NAME`, `/{env}/tp/csv/generator/STORAGE_BUCKET_NAME`
- C# code — `ExtendedMessageS3BucketStack.cs`, `SqsQueueService.cs`, `MessageProducer.cs`, `LambdaS3ExtendedMessagePolicyStatement.cs` (all in `ticketing-platform-tools` / `ticketing-platform-infrastructure`)
- CloudFront origins auto-resolve via `bucket_regional_domain_name` (no manual update)

---

## DNS Architecture

Understanding who manages which zone is critical for remaining Phase 4 steps and post-migration cleanup.

```
mdlbeast.net (Cloudflare)
├── NS: production-eu.tickets → Route53 Z0663446BTJAVD4MTCYG  (TEMP — to be deleted in PM-1)
└── NS: production.tickets   → Route53 Z095340838T2KOPA8X742  (permanent)

Route53: production.tickets.mdlbeast.net (Z095340838T2KOPA8X742) — ACTIVE
├── A: api.production.tickets.mdlbeast.net → API Gateway eu-central-1 (P4-S3)
├── A: geidea.production.tickets.mdlbeast.net → API Gateway eu-central-1 (P4-S3)
├── A: ecwid.production.tickets.mdlbeast.net → API Gateway eu-central-1 (P4-S3)
└── [27 records total — includes stale me-south-1 records: marketingfeed, xp-badges, k8s, managment, omada, openvpn, runner-*]

Route53: production-eu.tickets.mdlbeast.net (Z0663446BTJAVD4MTCYG) — TEMPORARY, to be deleted
├── A: api.production-eu.tickets.mdlbeast.net → API Gateway (superseded by production)
├── A: geidea.production-eu.tickets.mdlbeast.net → API Gateway (superseded)
├── A: ecwid.production-eu.tickets.mdlbeast.net → API Gateway (superseded)
└── CNAME: DNS validation records for temp ACM certs

Route53: internal.production.tickets.mdlbeast.net (Z05628001T92EME2ZM0Z6) — PRIVATE, ACTIVE
├── CNAME: catalogue.internal.production... → API Gateway execute-api
├── CNAME: sales.internal.production... → API Gateway execute-api
├── ... (14 CNAME records for internal services)
└── [VPC-associated private hosted zone — not internet-resolvable]

Route53: internal.production-eu.tickets.mdlbeast.net (Z04720843DJKNCF1N97H0) — ORPHANED
└── [14 stale CNAMEs — CloudFormation couldn't delete (non-empty). Clean up in PM-1]
```

**Key insight:** `tickets.mdlbeast.net` does NOT have its own Route53 zone. NS delegation goes directly from Cloudflare `mdlbeast.net` to each subdomain's Route53 zone. This means NS records for both `production` and `production-eu` subdomains are managed in Cloudflare.

---

## Infrastructure CDK Stacks (11 Stacks — Deployed in P3-S3)

→ plan.md §3.3; execution.md §P3-S3

All stacks are in `ticketing-platform-infrastructure` and deployed with strict ordering:

| # | Stack Name | What It Creates | Dependencies | Notes |
|---|------------|-----------------|--------------|-------|
| 1 | `TP-EventBusStack-prod` | EventBridge event bus `event-bus-prod` | None | Foundational |
| 2 | `TP-ConsumersSqsStack-prod` | 18 SQS queues + DLQs, stores ARNs in SSM | None | Queue names: `{Service}-queue-prod` |
| 3 | `TP-ConsumerSubscriptionStack-prod` | EventBridge rules routing events to SQS | EventBus + SQS | 19 rules |
| 4 | `TP-ExtendedMessageS3BucketStack-prod` | S3 bucket `ticketing-prod-extended-message-eu` | None | Large event payloads |
| 5 | `TP-InternalHostedZoneStack-prod` | Private Route53 zone `internal.production.tickets.mdlbeast.net` | VPC | VPC-associated |
| 6 | `TP-InternalCertificateStack-prod` | ACM cert for `*.internal.production.tickets.mdlbeast.net` | Hosted Zone | Auto-validates via private DNS |
| 7 | `TP-MonitoringStack-prod` | CloudWatch alarms, SNS topics | EventBus | Alarm topic ARN in SSM |
| 8 | `TP-ApiGatewayVpcEndpointStack` | VPC endpoint for API Gateway | VPC (needs `enable_dns_hostnames`) | Shared endpoint for all private APIs |
| 9 | `TP-RdsProxyStack` | RDS Proxy (read/write + read-only endpoints) | VPC, RDS, SSM params | ~12 min to provision; endpoints in SSM but services use direct Aurora |
| 10 | `TP-XRayInsightNotificationStack-prod` | X-Ray insight → SNS notification | EventBus, SSM webhooks | |
| 11 | `TP-SlackNotificationStack-prod` | Slack error notification Lambda | SSM webhooks, XRay stack | |

---

## Service Stack Composition (Exact Stack Names)

→ plan.md §3.5 for deployment matrix

Each service deploys a specific set of CDK stacks. The stack names follow a pattern but are not perfectly consistent. This table shows exact stack names as deployed.

| Service | Stacks (deploy in order) | CDK Project Path | Has DB |
|---------|--------------------------|-------------------|--------|
| catalogue | `TP-DbMigratorStack-catalogue-prod` → `TP-ServerlessBackendStack-catalogue-prod` | `src/TP.Catalogue.Cdk` | YES |
| organizations | `TP-DbMigratorStack-organizations-prod` → `TP-ConsumersStack-organizations-prod` → `TP-BackgroundJobsStack-organizations-prod` → `TP-ServerlessBackendStack-organizations-prod` | `src/Organizations/TP.Organizations.Cdk` | YES |
| loyalty | `TP-ConsumersStack-loyalty-prod` → `TP-BackgroundJobsStack-loyalty-prod` | `src/TP.Loyalty.Cdk` | NO |
| csv-generator | `TP-ConsumersStack-csvgenerator-prod` | `TP.CSVGenerator.Cdk` | NO |
| pdf-generator | `TP-ConsumersStack-pdf-generator-prod` | `TP.PdfGenerator.Cdk` | NO |
| automations | `TP-WeeklyTicketsSenderStack-prod` + `TP-AutomaticDataExporterStack-prod` + `TP-FinanceReportSenderStack-prod` | `src/TP.Automations.Cdk` | NO |
| extension-api | `TP-DbMigratorStack-extensions-prod` → `TP-ConsumersStack-extensions-prod` → `TP-BackgroundJobsStack-extensions-prod` → `TP-ServerlessBackendStack-extensions-prod` | `TP.Extensions.Cdk` | YES |
| extension-deployer | `TP-ExtensionDeployerLambdaRoleStack-prod` → `TP-ExtensionDeployerStack-prod` | `TP.Extensions.Deployer.Cdk` | NO |
| extension-executor | `TP-ExtensionExecutorStack-prod` | `TP.Extensions.Executor.Cdk` | NO |
| extension-log-processor | `TP-ExtensionLogsProcessorStack-prod` | `TP.Extensions.LogsProcessor.Cdk` | NO |
| customer-service | `TP-DbMigratorStack-customers-prod` → `TP-ConsumersStack-customers-prod` → `TP-BackgroundJobsStack-customers-prod` → `TP-ServerlessBackendStack-customers-prod` | `src/TP.Customers.Cdk` | YES |
| inventory | `TP-DbMigratorStack-inventory-prod` → `TP-ConsumersStack-inventory-prod` → `TP-BackgroundJobsStack-inventory-prod` → `TP-ServerlessBackendStack-inventory-prod` | `src/TP.Inventory.Cdk` | YES |
| pricing | `TP-DbMigratorStack-pricing-prod` → `TP-ConsumersStack-pricing-prod` → `TP-ServerlessBackendStack-pricing-prod` | `src/TP.Pricing.Cdk` | YES |
| media | `TP-DbMigratorStack-media-prod` → `TP-MediaStorageStack-prod` → `TP-ConsumersStack-media-prod` → `TP-BackgroundJobsStack-media-prod` → `TP-ServerlessBackendStack-media-prod` | `src/TP.Media.Cdk` | YES |
| reporting-api | `TP-DbMigratorStack-reporting-prod` → `TP-ConsumersStack-reporting-prod` → `TP-BackgroundJobsStack-reporting-prod` → `TP-ServerlessBackendStack-reporting-prod` | `src/TP.ReportingService.Cdk` | YES |
| marketplace | `TP-DbMigratorStack-marketplace-prod` → `TP-ConsumersStack-marketplace-prod` → `TP-BackgroundJobsStack-marketplace-prod` → `TP-ServerlessBackendStack-marketplace-prod` | `src/TP.Marketplace.Cdk` | YES |
| integration | `TP-DbMigratorStack-integration-prod` → `TP-ConsumersStack-integration-prod` → `TP-BackgroundJobsStack-integration-prod` → `TP-ServerlessBackendStack-integration-prod` | `src/TP.Integration.Cdk` | YES |
| distribution-portal | `TP-DbMigratorStack-dp-prod` → `TP-ConsumersStack-dp-prod` → `TP-BackgroundJobsStack-dp-prod` → `TP-ServerlessBackendStack-dp-prod` | `src/TP.DistributionPortal.Cdk` | YES |
| sales | `TP-DbMigratorStack-sales-prod` → `TP-ConsumersStack-sales-prod` → `TP-BackgroundJobsStack-sales-prod` → `TP-ServerlessBackendStack-sales-prod` | `src/TP.Sales.Cdk` | YES |
| access-control | `TP-DbMigratorStack-accesscontrol-prod` → `TP-ConsumersStack-accesscontrol-prod` → `TP-BackgroundJobsStack-accesscontrol-prod` → `TP-ServerlessBackendStack-accesscontrol-prod` | `src/TP.AccessControl.Cdk` | YES |
| transfer | `TP-DbMigratorStack-transfer-prod` → `TP-ConsumersStack-transfer-prod` → `TP-BackgroundJobsStack-transfer-prod` → `TP-ServerlessBackendStack-transfer-prod` | `src/TP.Transfer.Cdk` | YES |
| geidea | `TP-ConsumersStack-geidea-prod` → `TP-BackgroundJobsStack-geidea-prod` → `TP-Geidea-ApiStack-prod` | `src/TP.Geidea.Cdk` | NO |
| ecwid-integration | `TP-ApiStack-ecwid-prod` → `TP-BackgroundJobsStack-ecwid-prod` | `src/TP.Ecwid.Cdk` | NO |
| gateway | `GatewayStack` | `src/Gateway.Cdk` | NO |

**Lambda naming conventions** (non-obvious):
- Most services: `{service}-serverless-prod-function`, `{service}-consumers-lambda-prod`, `{service}-background-jobs-lambda-prod`
- access-control: `accesscontrol-*` (no hyphen)
- distribution-portal: `dp-*` (abbreviated prefix)
- extension-deployer: `ticketing-platform-extension-deployer-prod` (Docker image-based, deployed via `dotnet lambda deploy-function` per CI/CD `main.yml` — use `--docker-build-options "--platform linux/amd64"` on Apple Silicon)

---

## Phase 4: DNS Cutover — Completed Procedure Reference

→ plan.md §Phase 4 for full planned procedure; execution.md §P4-S1 through §P4-S9 for results

Phase 4 is fully complete (2026-03-30). All hotfix branches merged, E2E validation passed, production stable. Below are reference notes from the cutover.

### SSM Params Updated at Cutover

These SSM params were updated from `production-eu` temp domain to `production`:
- `/prod/tp/csv/generator/ACCESS_CONTROL_SERVICE_URL` → `https://api.production.tickets.mdlbeast.net/`
- `/prod/tp/extensions/ExtensionApiUrl` → `https://api.production.tickets.mdlbeast.net/`

---

## Phase 5: Dev+Sandbox Rebuild — Detailed Procedure

→ plan.md §Phase 5

**Account:** `307824719505` | **Risk:** LOW | No data to restore — fresh empty databases

### Key Differences from Production (Phases 2+3)

1. **RDS cluster NOT commented out** — Terraform creates it fresh (no backup restore needed)
2. **No `terraform import` for RDS** — cluster is brand new
3. **DB migrations CREATE schemas** (not "No pending migrations" like prod)
4. **Need seed test data** — databases start empty
5. **Two environments** in one account: `dev` + `sandbox` (11 CDK stacks × 2 envs)
6. **IAM role conflicts may still apply** — if me-south-1 CDK stacks created global roles for dev/sandbox

### Foundation Steps (Account 307824719505)

1. Service quota pre-checks (same checks, different profile: `AdministratorAccess-307824719505`)
2. Create Terraform state bucket: `ticketing-terraform-dev-eu`
3. Create secrets: same structure as prod with `/dev/` and `/sandbox/` prefixes
4. `terraform init -reconfigure` + import Route53 zones (`dev.tickets.mdlbeast.net`, `sandbox.tickets.mdlbeast.net`)
5. `terraform apply` — creates everything including RDS cluster (fresh)
6. Populate SSM parameters (same pattern, dev/sandbox values)
7. Create DynamoDB `Cache` table
8. CDK bootstrap: `npx cdk bootstrap aws://307824719505/eu-central-1`

### Services & Validation

1. Create ACM certificates (dev + sandbox domains)
2. Deploy 11 infrastructure CDK stacks (× 2 environments)
3. Update connection strings in secrets (fresh RDS endpoint)
4. Deploy all service stacks per matrix
5. DB migrations → creates empty schemas
6. Seed test data as needed
7. Merge branches to `development` and `sandbox` branches
8. Smoke test dev + sandbox

---

## Secrets Inventory — Current State

→ execution.md §P3-S4 for update details

### Updated Secrets (19 total — P3-S4)

All 19 had CONNECTION_STRINGS updated to point to `ticketing.cluster-c0lac6czadei.eu-central-1.rds.amazonaws.com`, IAM keys rotated to `AKIAZTV5IHRY3JAPWUFD`, and blanket `me-south-1` → `eu-central-1` replacement.

Services: access-control, automations, catalogue, customers, dp, ecwid, extensions, gateway, geidea, integration, inventory, loyalty, marketplace, media, organizations, pricing, reporting, sales, transfer

### Secrets NOT Updated (correct)

| Secret | Reason |
|--------|--------|
| `/rds/ticketing-cluster` | Already correct from P2-S6 Aurora restore |
| `terraform` | Only has RDS password, no region refs |
| `devops` | Manually created in P2-S3 (SSH public key) |
| `xp-badges` | Out of migration scope |

### Known Issues in Secrets

| Secret | Issue | Impact |
|--------|-------|--------|
| `/prod/ecwid` | Missing 8 vendor config keys: `CONNECTION_STRINGS`, `ECWID_STORE_ID`, `ECWID_BASE_ADDRESS`, `ANCHANTO_STORE_ID`, `ANCHANTO_MARKETPLACE_CODE`, `ANCHANTO_BASE_ADDRESS`, `ANCHANTO_BASE_CATEGORY_CODE`, `ANCHANTO_BASE_CATEGORY_NAME` | Ecwid Lambda functions deployed but will crash on invocation |
| `prod/data` | Contains `me-south-1` Glue bucket ref in `spark.hadoop...keyfile` | Not in scope — Glue/Spark config references actual me-south-1 bucket |
| All SQS URLs in secrets | Point to correct eu-central-1 URLs but specialty queues (`TP_CSV_Report_Generator_Service_Queue_prod`, `TP_PDF_Generator_Service_Queue_prod`, `TP_Extensions_Deployer_Queue_prod`, `TP_Extensions_Executor_Queue_prod`) were set before CDK created them | Queue names match CDK output — verified working |

### Keys Preserved From Backup (Critical — Must Not Be Lost)

- `ENCRYPTION_KEY` / `ENCRYPTION_IV` (access-control) — existing encrypted PII depends on these
- `SHARED_CODE_SECRET_KEY` (transfer) — shared secret for transfer codes
- All third-party API keys (Tabby, Checkout.com, SEATSIO, Talon, HyperPay, WhatsApp, Wrstbnd, SendGrid, etc.)

---

## Post-Migration Cleanup — Detailed Checklist

→ plan.md §Post-Migration Tasks, §Post-Migration Cleanup; execution.md §PM-1 through §PM-4

### PM-1: Temporary Domain Cleanup (after Phase 4 validation)

- [ ] Delete all records (except NS/SOA) from `production-eu.tickets.mdlbeast.net` zone
- [ ] Delete Route53 hosted zone `Z0663446BTJAVD4MTCYG`
- [ ] Delete orphaned internal zone `Z04720843DJKNCF1N97H0` (old `internal.production-eu`, 14 stale CNAMEs)
- [ ] Remove 4 NS records from **Cloudflare** `mdlbeast.net` zone for `production-eu.tickets`
- [ ] Delete 3 temporary ACM certificates (the `production-eu` ones)
- [ ] Delete SSM parameter `/production-eu/tp/DomainCertificateArn` (temp gateway cert)

### PM-2: Extension Lambda Redeployment — DONE (2026-03-27)

Extension metadata survives in Aurora, but extension Lambdas (created by extension-deployer in me-south-1) did not exist in eu-central-1. Redeployed through dashboard by changing version comments. Disabled extensions had to be enabled first to trigger redeployment, then disabled again. → execution.md §PM-2

### PM-3: Configure AWS Backup in eu-central-1

Critical to avoid repeating the single-region risk that caused this migration. Set up cross-region backup policy for:
- Aurora cluster → backup vault with cross-region copy
- S3 buckets (tickets-pdf-download-eu, ticketing-csv-reports-eu, ticketing-app-mobile-eu)

### PM-4: Full Cleanup (after 7-day stability + me-south-1 recovery)

**Data stores:**
- [ ] Schedule me-south-1 KMS key deletion (7-day minimum wait)
- [ ] Verify S3 data restored completely (compare object counts)

**Infrastructure (once me-south-1 recovers):**
- [ ] Delete remaining me-south-1 resources (Terraform/CDK)
- [ ] Delete me-south-1 Terraform state buckets
- [ ] Clean up IAM roles/policies specific to me-south-1

**EKS deprecation:**
- [ ] Delete EKS cluster in me-south-1
- [ ] Delete ECR repositories
- [ ] Archive ConfigMap repos (add README noting EKS deprecation)
- [ ] Remove `deploy.yml` and `k8s.yml` from `ticketing-platform-templates-ci-cd` (currently disabled via `workflow_dispatch`)
- [ ] Remove Helm charts from 17 service repos
- [ ] Remove EKS-only Dockerfiles (keep if useful for local dev)

**Redis/OpenSearch:**
- [ ] Delete Redis clusters and OpenSearch domains in me-south-1
- [ ] Remove commented-out `Redis__Host`/`Redis__Password` from ConfigMaps
- [ ] Remove `Logging__Elasticsearch__*` from ConfigMaps
- [ ] Consider removing `StackExchange.Redis` NuGet from `TP.Tools.DataAccessLayer`

**Runners:**
- [ ] Deregister me-south-1 GitHub Actions runners
- [ ] Terminate runner EC2 instances

**Security:**
- [ ] Rotate all credentials (RDS passwords, API keys)
- [ ] Audit IAM policies for region-specific ARNs
- [ ] Remove committed `.tfstate` files from git history (consider BFG Repo-Cleaner)

**Configuration:**
- [ ] Verify no GitHub secrets still reference me-south-1
- [ ] Restore DNS TTLs to normal values if lowered
- [ ] Clean up stale Route53 records in production zone (marketingfeed, xp-badges, k8s, managment, omada, openvpn, runner-*)

**Documentation:**
- [ ] Update `CLAUDE.md` with new region references
- [ ] Update `.personal/DEPLOYMENT.md` and `.personal/ARCHITECTURE.md`
- [ ] Document EKS deprecation decision and Lambda-only architecture

---

## Active Risks

| Risk | Likelihood | Impact | Status/Mitigation |
|------|-----------|--------|-------------------|
| Ecwid secret missing vendor keys | HIGH | MEDIUM | Functions deployed but will crash. Need ECWID_STORE_ID etc. from vendor dashboards. Not a blocker for other services. |
| `ticketing-prod-media-eu` bucket is empty | MEDIUM | MEDIUM | No backup copies existed. Historical media assets unavailable until me-south-1 recovers or assets are re-uploaded. |
| No AWS Backup in eu-central-1 yet | HIGH | HIGH | PM-3 must be done promptly. If eu-central-1 has a failure before backup is configured, data since last me-south-1 backup (2026-03-23) could be lost. |
| Uncommitted Terraform changes | LOW | HIGH | `ticketing-platform-terraform-prod` has uncommitted changes across vpc.tf, rds.tf, s3.tf, variables.tf, mobile.tf, group.tf. Must commit or changes will be lost. |
| P4-S8 glue bucket — GCP handoff pending | LOW | LOW | AWS-side complete. GCP team must update 16 BigQuery Transfer configs + scheduler re-enabled after. |
| Storybook infra missing | LOW | LOW | Dashboard Storybook S3 bucket + CloudFront don't exist yet in eu-central-1. Variables skipped in P4-S4. Post-migration task. |
| ~~Cold Lambda performance post-go-live~~ | ~~MEDIUM~~ | ~~MEDIUM~~ | **RESOLVED.** P4-S6 + P4-S7 confirmed production stable, no cold-start issues. |
| ~~Aurora min ACU at 1.5 (not 8)~~ | ~~LOW~~ | ~~MEDIUM~~ | **RESOLVED.** P4-S7 monitoring confirmed RDS metrics nominal at current scaling. |
| ~~Dashboard CloudFront IDs not yet updated~~ | ~~MEDIUM~~ | ~~LOW~~ | **RESOLVED.** Updated in hotfix branch, merged to master in P4-S5. |
| ~~P4-S5 branch merges pending~~ | ~~MEDIUM~~ | ~~MEDIUM~~ | **RESOLVED 2026-03-30.** All hotfix branches merged to master/production. |
| ~~P4-S8 glue bucket partially migrated~~ | ~~MEDIUM~~ | ~~LOW~~ | **RESOLVED 2026-03-30.** PR #40 merged, CDK deployed, errors stopped. GCP handoff remaining. |
| ~~CNAME gap during Phase 4 internal DNS cutover~~ | ~~HIGH~~ | ~~HIGH~~ | **RESOLVED.** ~25 min gap during P4-S3, all 14 CNAMEs recreated. |
| ~~23 non-API Lambdas crash on startup (DIAG-002)~~ | ~~CONFIRMED~~ | ~~CRITICAL~~ | **RESOLVED 2026-03-27.** All 23 repackaged + redeployed in P3-S5.1. |
