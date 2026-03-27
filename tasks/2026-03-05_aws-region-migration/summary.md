# AWS Region Migration Summary (me-south-1 → eu-central-1)

This document combines the migration plan and execution log into a single context-efficient reference for agents. Read this instead of `plan.md` + `execution.md` to get full context on what was planned, what actually happened, and what remains.

---

## Context

The MDLBEAST Ticketing Platform is migrating from AWS **me-south-1** (Bahrain) to **eu-central-1** (Frankfurt). This is a **disaster recovery + region migration** — me-south-1 suffered a regional data center failure and is completely down. There is no live traffic to cut over and no rollback path to me-south-1.

**Strategy:** Greenfield infrastructure in eu-central-1 with Aurora and S3 restored from AWS Backup cross-region copies. Lambda-only deployment (EKS deprecated). Production deploys under temporary subdomain `production-eu.tickets.mdlbeast.net` for safe testing before DNS cutover to `production.tickets.mdlbeast.net`.

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

---

## Phase Overview and Current Status

| Phase | Description | Status | Dates |
|-------|-------------|--------|-------|
| **Phase 1** | Code preparation (no infra changes) | **DONE** | 2026-03-25 |
| **Phase 2** | Production foundation & data restore | **DONE** | 2026-03-25 to 2026-03-26 |
| **Phase 3** | Production services under temporary domain | **IN PROGRESS** (P3-S6 E2E validation in progress) | 2026-03-26 to present |
| **Phase 4** | DNS cutover to production domain | PENDING | — |
| **Phase 5** | Dev+Sandbox rebuild (fresh) | PENDING | — |
| **Post-Migration** | Cleanup, backup config, monitoring | PENDING | — |

---

## Phase 1: Code Preparation — COMPLETED

All 20 tasks completed on 2026-03-25. Branch `hotfix/region-migration-eu-central-1` created in 34+ repos.

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

**Key deviation:** Plan listed 14 repos for env-var update; script found 18 (more repos had demo env files). Plan listed 22 repos for lambda-tools; found 25 (3 extra deprecated repos).

---

## Phase 2: Production Foundation & Data Restore — COMPLETED

All steps completed 2026-03-25 to 2026-03-26.

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

### Key Deviations
- 34 global resources (IAM, CloudFront OACs, S3 state bucket) had to be imported into Terraform — plan assumed fresh creation
- `ROOT_ZONE_ID` is N/A — `tickets.mdlbeast.net` zone doesn't exist; NS delegation is managed in Cloudflare
- S3 bucket renames in Terraform were missed in Phase 1 — fixed during terraform apply
- Aurora restore required specific metadata format; scaling config must be set before creating instances
- Replicated secrets retained old Elasticsearch/Redis keys (harmless — code already removed; all overwritten in P3-S4)
- S3 restores required temporarily relaxing ACL/ownership settings on destination buckets

---

## Phase 3: Production Services under Temporary Domain — IN PROGRESS

### Completed Steps

**P3-S1: Temporary Route53 Zone** — `production-eu.tickets.mdlbeast.net` zone created (`Z0663446BTJAVD4MTCYG`). NS delegation added in **Cloudflare** (not Route53). Post-migration cleanup must remove NS records from Cloudflare.

**P3-S2: ACM Certificates** — 3 certificates issued:
- Gateway: `arn:aws:acm:eu-central-1:660748123249:certificate/914c47a3-f0df-4e5c-a406-747f62fb2228`
- Geidea: `arn:aws:acm:eu-central-1:660748123249:certificate/773c5a63-304a-476c-95dd-877065f91581`
- Ecwid: `arn:aws:acm:eu-central-1:660748123249:certificate/75e4cc24-20cc-491d-b87c-20ae2647f2b9`

**P3-S3: Infrastructure CDK (11 stacks)** — All deployed. VPC required `enable_dns_hostnames = true` fix (uncommitted in terraform-prod `vpc.tf`).

**P3-S4: Connection Strings & Secrets** — 22 replica secrets promoted to standalone. New CICD IAM key created (`AKIAZTV5IHRY3JAPWUFD`). 19 secrets updated with correct Aurora endpoints, SQS URLs, IAM keys. Blanket `me-south-1` → `eu-central-1` replacement. `prod/data` still has me-south-1 Glue bucket ref (not in scope). Ecwid still missing 8 vendor config keys.

**P3-S5: Per-Service CDK Deployment (24 services)** — ALL 24 DONE.

### Deployment Patterns Learned (Critical for Future Reference)

1. **`dotnet lambda package -c Release`** must run from each Lambda project directory (not `dotnet publish`). `dotnet publish` does NOT generate `.runtimeconfig.json` for `Microsoft.NET.Sdk` (class library) projects. Only `Microsoft.NET.Sdk.Web` API projects survive `dotnet publish`. See DIAG-001 + DIAG-002.
2. **IAM roles are global** — every stack's IAM role already exists from me-south-1. Must use `cdk import` before `cdk deploy`. Never attempt `cdk deploy` directly.
3. **63 stale inline policies** were bulk-deleted in P3-S5-02 (backup at `backup-iam-policies/`). Some DefaultPolicy policies survived and required per-service cleanup.
4. **Log groups must be pre-created** for ALL Lambda functions (serverless, consumers, AND background-jobs) before deploying stacks with Slack SubscriptionFilters.
5. **DB migrations return "No pending migrations"** — databases restored from backup already have all migrations.
6. **Private API Gateways** — cannot curl from outside VPC. Health checks via `aws lambda invoke` or OpenVPN instance.
7. **Helper script** `deploy-service-cdk.sh` automates synth → extract IAM roles → import → deploy pattern.
8. **CDK environment variables:** `AWS_PROFILE`, `CDK_DEFAULT_ACCOUNT=660748123249`, `CDK_DEFAULT_REGION=eu-central-1`, `ENV_NAME=prod`

### Per-Service Deployment Results

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
| 19 | sales | DONE | Healthy | Inter-service route URLs still point to `production.tickets.mdlbeast.net` — will resolve after Phase 4 |
| 20 | access-control | DONE | Healthy | 3 stale DefaultPolicy policies survived bulk cleanup; Lambda uses `accesscontrol-` prefix (no hyphen) |
| 21 | transfer | DONE | Healthy | Clean deployment |
| 22 | geidea | DONE | N/A | Clean deployment; API at `geidea.production-eu.tickets.mdlbeast.net` |
| 23 | ecwid-integration | DONE | N/A | Ecwid secret still missing vendor config keys — functions won't work until populated |
| 24 | gateway (LAST) | DONE | Healthy | API at `api.production-eu.tickets.mdlbeast.net`; 81 Lambda functions total in eu-central-1 |

### P3-S5.1: Repackage & Redeploy Non-API Lambdas (DIAG-002) — DONE

All 23 Consumer, Automations, and standalone Lambdas repackaged with `dotnet lambda package -c Release` (clean publish directories) and redeployed via CDK. All 23 stacks confirmed `UPDATE_COMPLETE`. See [diagnostics.md](diagnostics.md#diag-002) for details.

### Current Step: P3-S6 End-to-End Validation (IN PROGRESS)

**Completed checks:**
- API Gateway responds at `api.production-eu.tickets.mdlbeast.net` — 200 OK
- Geidea endpoint responds at `geidea.production-eu.tickets.mdlbeast.net` — 200 OK
- 14 CNAME records in private hosted zone for internal services
- 19 EventBridge rules, 43 SQS queues — all wired
- CloudWatch logs actively populating (155 events/hour from gateway)
- 81 Lambda functions deployed, spot-checked 5 — all Active

**Remaining checks (require P3-S5.1 fix + Auth0 token / manual dashboard testing):**
- [ ] Create event in catalogue
- [ ] Create tickets in inventory
- [ ] Process test order through sales
- [ ] PDF ticket generation
- [ ] CSV report generation
- [ ] Media upload/download
- [ ] Access control scanning flow
- [ ] Slack notifications arriving
- [ ] Extension deployer creates Lambda in eu-central-1
- [ ] Dashboard local test against temp domain

**P3-VERIFY: Phase 3 Verification Checklist** — PENDING (after P3-S6 completes)

---

## Phase 4: DNS Cutover to Production Domain — PENDING

### Steps Overview
1. **P4-S1:** Revert `production-eu` → `production` in 7 CDK files (5 repos)
2. **P4-S1.1:** Publish updated NuGet package (second publish), bump in 18 service repos
3. **P4-S2:** Create 3 ACM certificates for `*.production.tickets.mdlbeast.net`
4. **P4-S3:** Redeploy 5 public-facing stacks (InternalHostedZone, InternalCertificate, Gateway, Geidea, Ecwid) + 14 ServerlessBackendStack stacks in parallel (minimize CNAME gap)
5. **P4-S4:** Update GitHub secrets (`AWS_DEFAULT_REGION=eu-central-1`) across all repos + dashboard variables (CloudFront IDs)
6. **P4-S5:** Merge hotfix branches to master/production across all repos; dashboard/mobile scanner deploys
7. **P4-S6:** Full E2E validation on production domain
8. **P4-S7:** 72-hour post-go-live monitoring; reduce Aurora min ACU after stable

### Critical Notes for Phase 4
- SSM params to update at cutover: `ACCESS_CONTROL_SERVICE_URL` (CSV generator) and `ExtensionApiUrl` (extensions) from `production-eu` → `production`
- Dashboard needs CloudFront URL updates (new distribution IDs: `E2E0LQF2V6W4U`, `E1NNQYK06MZJSB`)
- CNAME gap when InternalHostedZoneStack redeploys — old zone deleted before CNAME records are recreated. Minimize by deploying all 14 ServerlessBackendStack stacks in parallel immediately after.
- Old CICD IAM key `AKIAZTV5IHRYY5XWYBO2` was deleted in P3-S4 — me-south-1 CI/CD will fail if it references it

---

## Phase 5: Dev+Sandbox Rebuild — PENDING

Fresh rebuild in account `307824719505`. Same pattern as Phase 2+3 but with empty databases (no backup restore). Terraform state bucket, secrets, CDK bootstrap, all stacks, DB migrations with seed data.

---

## Post-Migration Tasks — PENDING

1. **PM-1:** Delete `production-eu.tickets.mdlbeast.net` zone + remove NS from **Cloudflare** (not Route53)
2. **PM-2:** Redeploy user-created extension Lambdas via extension-deployer
3. **PM-3:** Configure AWS Backup in eu-central-1 for new resources
4. **PM-4:** After 7-day stability + me-south-1 recovery: delete old resources, clean up IAM, archive ConfigMap repos, remove Helm charts, rotate credentials, update documentation

---

## Uncommitted Changes Tracker

These repos have local changes that need to be committed:

| Repo | File | Change | Introduced By |
|------|------|--------|---------------|
| `ticketing-platform-terraform-prod` | `prod/vpc.tf` | Added `enable_dns_hostnames = true` | P3-S3 |
| `ticketing-platform-terraform-prod` | `prod/rds.tf` | Added VPC CIDR Lambda ingress rule on port 5432 | P3-S5-01 |
| `ticketing-platform-terraform-prod` | `prod/s3.tf`, `prod/variables.tf`, `prod/mobile.tf`, `prod/group.tf` | S3 bucket renames, IAM policy updates, MSK removal | P2-S4 |
| `ticketing-platform-infrastructure` | `ConsumersSqsStack.cs` | Added Organization service timeout override (900s) | P3-S5-02 |
| `ticketing-platform-distribution-portal` | `env-var.prod.json` | Added `SalesServiceBaseRoute` env var | P3-S5-18 |

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
| TEMP_ZONE_ID | `Z0663446BTJAVD4MTCYG` |
| CERT_ARN_GATEWAY_TEMP | `arn:aws:acm:eu-central-1:660748123249:certificate/914c47a3-f0df-4e5c-a406-747f62fb2228` |
| CERT_ARN_GEIDEA_TEMP | `arn:aws:acm:eu-central-1:660748123249:certificate/773c5a63-304a-476c-95dd-877065f91581` |
| CERT_ARN_ECWID_TEMP | `arn:aws:acm:eu-central-1:660748123249:certificate/75e4cc24-20cc-491d-b87c-20ae2647f2b9` |
| NEW_AWS_KEY | `AKIAZTV5IHRY3JAPWUFD` |
| NUGET_VERSION_1 | `1.0.1300` |
| OpenVPN Instance | `i-0f005875786d8cc94` (Elastic IP: `18.193.92.249`) |
| CloudFront s3_prod | `E2E0LQF2V6W4U` → `d2o70nzt59y9cv.cloudfront.net` |
| CloudFront mobile | `E1NNQYK06MZJSB` → `d36feu62yikku8.cloudfront.net` |

---

## Deviations Summary (Quick Reference)

These are the most impactful deviations from the original plan. Agents should be aware of these before executing any step:

1. **DNS is managed in Cloudflare**, not Route53 — `tickets.mdlbeast.net` zone doesn't exist in Route53. NS delegation for `production-eu` was added in Cloudflare.
2. **Secrets were replicated** (not manually recreated) — 22 secrets required promotion from replica to standalone before updating.
3. **34 global resources imported** into Terraform — IAM, CloudFront OACs, S3 state bucket are global and already existed.
4. **New CloudFront distribution IDs** — dashboard has hardcoded old IDs that need updating.
5. **SSM params: 35 created** (plan said 16) — me-south-1 API came back, revealing the full parameter set.
6. **IAM role conflicts** on every CDK deploy — solved by synth → extract → import → deploy pattern.
7. **63 stale inline policies** bulk-deleted; some DefaultPolicy policies survived and required per-service cleanup.
8. **Organization SQS visibility timeout** fixed in infrastructure CDK (`ConsumersSqsStack.cs`).
9. **VPC DNS hostnames** had to be enabled (Terraform `vpc.tf` fix) for API Gateway VPC endpoints.
10. **RDS SG Lambda access** — VPC CIDR ingress rule added to Terraform `rds.tf` for Lambda→RDS connectivity.
11. **Distribution-portal** missing `SalesServiceBaseRoute` (was in K8s configmap, not Lambda env vars).
12. **pdf-generator** 250MB Lambda limit — CDK DLLs + SkiaSharp multi-platform runtimes cleaned from publish dir.
13. **extension-deployer** Docker Lambda — follow CI/CD `main.yml` sequence: `dotnet restore` → `dotnet build` → `dotnet lambda deploy-function` (with `--docker-build-options "--platform linux/amd64"` on Apple Silicon). Must deploy BEFORE CDK (CDK only creates SQS mapping). Initial deployment built ARM64 image causing `exec format error` (DIAG-003).
14. **Ecwid secret** still missing 8 vendor config keys — functions deployed but won't work until populated.
15. **`dotnet publish` breaks ALL non-API Lambdas** (DIAG-002) — 23 consumers, automations, and standalone Lambdas deployed with missing `.runtimeconfig.json`. Must use `dotnet lambda package` for any `Microsoft.NET.Sdk` project. Only `Microsoft.NET.Sdk.Web` (API) projects work with `dotnet publish`.

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
- Dashboard `vercel.json` CSP — 6 hardcoded S3 URLs (bucket name + region)
- SSM parameters — `/{env}/tp/pdf/generator/STORAGE_BUCKET_NAME`, `/{env}/tp/csv/generator/STORAGE_BUCKET_NAME`
- C# code — `ExtendedMessageS3BucketStack.cs`, `SqsQueueService.cs`, `MessageProducer.cs`, `LambdaS3ExtendedMessagePolicyStatement.cs` (all in `ticketing-platform-tools` / `ticketing-platform-infrastructure`)
- CloudFront origins auto-resolve via `bucket_regional_domain_name` (no manual update)

---

## DNS Architecture

Understanding who manages which zone is critical for Phase 4 and post-migration cleanup.

```
mdlbeast.net (Cloudflare)
├── NS: production-eu.tickets → Route53 Z0663446BTJAVD4MTCYG  (TEMP — to be deleted in PM-1)
└── NS: production.tickets   → Route53 Z095340838T2KOPA8X742  (permanent)

Route53: production.tickets.mdlbeast.net (Z095340838T2KOPA8X742)
├── A: api.production.tickets.mdlbeast.net → API Gateway (Phase 4)
├── A: geidea.production.tickets.mdlbeast.net → API Gateway (Phase 4)
├── A: ecwid.production.tickets.mdlbeast.net → API Gateway (Phase 4)
└── [27 records total — includes old me-south-1 A records that will be overwritten]

Route53: production-eu.tickets.mdlbeast.net (Z0663446BTJAVD4MTCYG) — TEMPORARY
├── A: api.production-eu.tickets.mdlbeast.net → API Gateway (current)
├── A: geidea.production-eu.tickets.mdlbeast.net → API Gateway (current)
├── A: ecwid.production-eu.tickets.mdlbeast.net → API Gateway (current)
└── CNAME: DNS validation records for ACM certs

Route53: internal.production-eu.tickets.mdlbeast.net (Z04720843DJKNCF1N97H0) — PRIVATE
├── CNAME: catalogue.internal.production-eu... → API Gateway execute-api
├── CNAME: sales.internal.production-eu... → API Gateway execute-api
├── ... (14 CNAME records for internal services)
└── [VPC-associated private hosted zone — not internet-resolvable]
```

**Key insight:** `tickets.mdlbeast.net` does NOT have its own Route53 zone. NS delegation goes directly from Cloudflare `mdlbeast.net` to each subdomain's Route53 zone. This means NS records for both `production` and `production-eu` subdomains are managed in Cloudflare.

---

## Infrastructure CDK Stacks (11 Stacks — Deployed in P3-S3)

All stacks are in `ticketing-platform-infrastructure` and deployed with strict ordering:

| # | Stack Name | What It Creates | Dependencies | Notes |
|---|------------|-----------------|--------------|-------|
| 1 | `TP-EventBusStack-prod` | EventBridge event bus `event-bus-prod` | None | Foundational |
| 2 | `TP-ConsumersSqsStack-prod` | 18 SQS queues + DLQs, stores ARNs in SSM | None | Queue names: `{Service}-queue-prod` |
| 3 | `TP-ConsumerSubscriptionStack-prod` | EventBridge rules routing events to SQS | EventBus + SQS | 19 rules |
| 4 | `TP-ExtendedMessageS3BucketStack-prod` | S3 bucket `ticketing-prod-extended-message-eu` | None | Large event payloads |
| 5 | `TP-InternalHostedZoneStack-prod` | Private Route53 zone `internal.production-eu.tickets.mdlbeast.net` | VPC | VPC-associated |
| 6 | `TP-InternalCertificateStack-prod` | ACM cert for `*.internal.production-eu.tickets.mdlbeast.net` | Hosted Zone | Auto-validates via private DNS |
| 7 | `TP-MonitoringStack-prod` | CloudWatch alarms, SNS topics | EventBus | Alarm topic ARN in SSM |
| 8 | `TP-ApiGatewayVpcEndpointStack` | VPC endpoint for API Gateway | VPC (needs `enable_dns_hostnames`) | Shared endpoint for all private APIs |
| 9 | `TP-RdsProxyStack` | RDS Proxy (read/write + read-only endpoints) | VPC, RDS, SSM params | ~12 min to provision; endpoints in SSM but services use direct Aurora |
| 10 | `TP-XRayInsightNotificationStack-prod` | X-Ray insight → SNS notification | EventBus, SSM webhooks | |
| 11 | `TP-SlackNotificationStack-prod` | Slack error notification Lambda | SSM webhooks, XRay stack | |

---

## Service Stack Composition (Exact Stack Names)

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

## Phase 4: DNS Cutover — Detailed Procedure

### P4-S1: Revert Domain Mapping (Exact Files)

Change `"production-eu"` back to `"production"` in these 7 locations:

| File Path | Repo | Line |
|-----------|------|------|
| `TP.Tools.Infrastructure/Helpers/ServerlessApiStackHelper.cs` | `ticketing-platform-tools` | :47 |
| `src/Gateway.Cdk/Stacks/GatewayStack.cs` | `ticketing-platform-gateway` | :32 |
| `src/Gateway.Cdk/Stacks/GatewayStack.cs` | `ticketing-platform-gateway` | :107 |
| `TP.Infrastructure.Cdk/Stacks/InternalHostedZoneStack.cs` | `ticketing-platform-infrastructure` | :15 |
| `TP.Infrastructure.Cdk/Stacks/InternalCertificateStack.cs` | `ticketing-platform-infrastructure` | :15 |
| `src/TP.Geidea.Cdk/Stacks/ApiStack.cs` | `ticketing-platform-geidea` | :32 |
| `src/TP.Ecwid.Cdk/Stacks/ApiStack.cs` | `ecwid-integration` | :32 |

Each file has `env == "prod" ? "production-eu" : env` → revert to `env == "prod" ? "production" : env`.

**GatewayStack note:** Line 107 is in `CreateCustomDomain()` where it derives the SSM path for the certificate ARN. The Gateway cert SSM path uses the **mapped** env name — so it looks up `/production/tp/DomainCertificateArn` (not `/prod/tp/...`). All other services use raw env for SSM paths.

### P4-S1.1: Second NuGet Publish

Must happen before P4-S3 CDK deploys. `ServerlessApiStackHelper.cs` is consumed via NuGet — the revert must be published first.

1. Merge to master in `ticketing-platform-tools` → triggers `nuget.yml` → record `NUGET_VERSION_2`
2. Bump `TP.Tools.*` in the 18 repos being redeployed in P4-S3:
   - `ticketing-platform-infrastructure`, `ticketing-platform-gateway`, `ticketing-platform-geidea`, `ecwid-integration`
   - `ticketing-platform-catalogue`, `ticketing-platform-organizations`, `ticketing-platform-inventory`, `ticketing-platform-pricing`
   - `ticketing-platform-sales`, `ticketing-platform-access-control`, `ticketing-platform-media`, `ticketing-platform-reporting-api`
   - `ticketing-platform-transfer`, `ticketing-platform-marketplace-service`, `ticketing-platform-integration`, `ticketing-platform-distribution-portal`
   - `ticketing-platform-extension-api`, `ticketing-platform-customer-service`
3. Repos NOT redeployed in P4-S3 (csv-generator, pdf-generator, automations, extension-deployer/executor/log-processor, loyalty) pick up the new version when branches are merged in P4-S5

### P4-S2: ACM Certificates for Production Domain

3 certificates, validated against Route53 zone `Z095340838T2KOPA8X742` (`production.tickets.mdlbeast.net`):
- `api.production.tickets.mdlbeast.net` → SSM `/production/tp/DomainCertificateArn` (note: `/production/` not `/prod/`)
- `geidea.production.tickets.mdlbeast.net` → SSM `/prod/tp/geidea/DomainCertificateArn`
- `ecwid.production.tickets.mdlbeast.net` → SSM `/prod/tp/ecwid/DomainCertificateArn`

The SSM parameters are **overwritten** — CDK picks up the new cert ARNs on redeploy.

### P4-S3: CNAME Gap Mitigation (Critical)

When `TP-InternalHostedZoneStack-prod` redeploys, the old private zone (`internal.production-eu.tickets.mdlbeast.net`) is **deleted** and a new zone (`internal.production.tickets.mdlbeast.net`) is **created** — but with **no CNAME records**. Until ServerlessBackendStack stacks redeploy, inter-service HTTP calls get NXDOMAIN.

**Procedure to minimize gap:**
1. Deploy 5 public stacks first: InternalHostedZone → InternalCertificate → Gateway → Geidea → Ecwid
2. **Immediately** redeploy all 14 ServerlessBackendStack stacks **in parallel** (they are independent):
   ```
   TP-ServerlessBackendStack-{catalogue,organizations,inventory,pricing,sales,
   accesscontrol,media,reporting,transfer,marketplace,integration,dp,extensions,customers}-prod
   ```
3. Verify internal DNS resolution after all complete

### P4-S4: GitHub Secrets & Variables

**Region secret** (`AWS_DEFAULT_REGION=eu-central-1`) must be set on **35 repos** (all except xp-badges, bandsintown, marketing-feeds).

**Additional per-repo secrets:**
| Repo | Secret | Value |
|------|--------|-------|
| `ticketing-platform-terraform-dev` | `AWS_DEFAULT_REGION_PROD` | `eu-central-1` |
| `ticketing-platform-configmap-prod` | `TP_AWS_DEFAULT_REGION_PROD` | `eu-central-1` |
| `ticketing-platform-configmap-prod` | `AWS_DEFAULT_REGION_PROD` | `eu-central-1` |
| `ticketing-platform-extension-deployer` | `CDK_DEFAULT_REGION` | `eu-central-1` |

**GitHub variables to update:**
| Repo | Variable | New Value |
|------|----------|-----------|
| `ticketing-platform-dashboard` | `STORYBOOK_BUCKET_NAME` | TBD (new `-eu` bucket) |
| `ticketing-platform-dashboard` | `STORYBOOK_CLOUDFRONT_DISTRIBUTION_ID` | TBD (new distribution ID) |

### P4-S5: Branch Merge Checklist

Merge `hotfix/region-migration-eu-central-1` → `master`/`production` across all repos. This triggers CI/CD deployments.

**Frontend-specific:**
- Dashboard: merge triggers Vercel redeploy (`.env`, `.env.sandbox`, `vercel.json` changes)
- Distribution Portal Frontend: verify deploy
- Mobile Scanner: trigger release build workflow

### P4 SSM Params to Update at Cutover

These SSM params were set to `production-eu` temp domain during P2-S5 and must be updated:
- `/prod/tp/csv/generator/ACCESS_CONTROL_SERVICE_URL` → `https://api.production.tickets.mdlbeast.net/`
- `/prod/tp/extensions/ExtensionApiUrl` → `https://api.production.tickets.mdlbeast.net/`

---

## Phase 5: Dev+Sandbox Rebuild — Detailed Procedure

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

### PM-1: Temporary Domain Cleanup (after Phase 4 validation)

- [ ] Delete all records (except NS/SOA) from `production-eu.tickets.mdlbeast.net` zone
- [ ] Delete Route53 hosted zone `Z0663446BTJAVD4MTCYG`
- [ ] Remove 4 NS records from **Cloudflare** `mdlbeast.net` zone for `production-eu.tickets`
- [ ] Delete 3 temporary ACM certificates (the `production-eu` ones)
- [ ] Delete SSM parameter `/production-eu/tp/DomainCertificateArn` (temp gateway cert)

### PM-2: Extension Lambda Redeployment

Extension metadata survives in Aurora, but extension Lambdas (created by extension-deployer in me-south-1) do not exist in eu-central-1.

1. Verify `/prod/tp/extensions/EXTENSION_DEFAULT_ROLE` SSM parameter exists
2. Query extension-api for all extensions with `deploymentStatus = Deployed`
3. Trigger redeployment for each via extension-api update endpoint or `ExtensionChangeEvent` to SQS
4. Deployer Lambda (now in eu-central-1) recreates `Extension_{id}` Lambdas

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

**Documentation:**
- [ ] Update `CLAUDE.md` with new region references
- [ ] Update `.personal/DEPLOYMENT.md` and `.personal/ARCHITECTURE.md`
- [ ] Document EKS deprecation decision and Lambda-only architecture

---

## Active Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| ~~23 non-API Lambdas crash on startup (DIAG-002)~~ | ~~CONFIRMED~~ | ~~CRITICAL~~ | **RESOLVED 2026-03-27.** All 23 repackaged + redeployed. |
| Ecwid secret missing vendor keys | HIGH | MEDIUM | Functions deployed but will crash. Need ECWID_STORE_ID etc. from vendor dashboards. Not a blocker for other services. |
| CNAME gap during Phase 4 internal DNS cutover | HIGH | HIGH | Deploy 14 ServerlessBackendStack stacks in parallel immediately after InternalHostedZoneStack. Brief NXDOMAIN window for inter-service calls. |
| `ticketing-prod-media-eu` bucket is empty | MEDIUM | MEDIUM | No backup copies existed. Historical media assets (images, PDFs) are unavailable until me-south-1 recovers or assets are re-uploaded. |
| Cold Lambda performance post-go-live | MEDIUM | MEDIUM | Consider provisioned concurrency for gateway/sales. All 81 Lambdas will cold-start simultaneously when traffic arrives. |
| No AWS Backup in eu-central-1 yet | HIGH | HIGH | PM-3 must be done promptly. If eu-central-1 has a failure before backup is configured, data since last me-south-1 backup (2026-03-23) could be lost. |
| Aurora min ACU at 1.5 (not 8) | LOW | MEDIUM | User chose 1.5 during P2-S6. Can increase via `aws rds modify-db-cluster` before go-live. Plan recommended 8 for cold-cache load. |
| Dashboard CloudFront IDs not yet updated | MEDIUM | LOW | Old IDs (`d1sv7t2orvopb9`, `d3pr13z376vx6l`) hardcoded in dashboard. Must update to new IDs before Phase 4 go-live. |
| Uncommitted Terraform changes | LOW | HIGH | 5 repos have uncommitted changes (see tracker above). Must commit before Phase 4 or changes will be lost. |
