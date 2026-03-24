# AWS Region Migration Plan Review

**Plan:** `.personal/tasks/2026-03-05_aws-region-migration/plan.md`
**Reviewed:** 2026-03-24 (Round 5+)
**Method:** 5 review rounds with 30+ parallel agents validating Terraform, CDK stacks, SSM parameters, CI/CD workflows, S3 buckets, Route53 DNS, and me-south-1 reference completeness

- [Executive Summary](#executive-summary)
  - [Verdict by Phase](#verdict-by-phase)
  - [Open Item Summary](#open-item-summary)
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

The migration plan is comprehensive and addresses ~98% of the migration scope. All critical and high-severity gaps have been resolved through 5 review rounds. The plan's core structure — greenfield infrastructure in eu-central-1 via Terraform + CDK, Aurora restored from AWS Backup, Lambda-only (EKS deprecated) — is sound.

### Verdict by Phase

| Phase | Status | Remaining Blockers |
|-------|--------|----------|
| Phase 1 (Code Prep) | ~98% Complete | Update env-var JSON bucket names for `-eu` suffix |
| Phase 2 (Dev Foundation) | ~98% Complete | Verify NS delegation at parent domain after Terraform |
| Phase 3 (Dev Services) | ~98% Complete | None |
| Phase 4 (Prod Foundation) | ~98% Complete | Same as Phase 2 |
| Phase 5 (Prod Services) | ~98% Complete | None |
| Post-Migration | ~98% Complete | None |

### Open Item Summary

| Severity | Count | IDs |
|----------|-------|-----|
| MEDIUM | 2 | ISSUE-9 (provisioned concurrency), ISSUE-11 (demo env) |

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

### Architecture
- Greenfield infrastructure approach (new Terraform state) avoids state conflicts ✓
- EventBridge/SQS naming is region-agnostic ✓
- 18 consumer services confirmed via `ConsumersServices` enum ✓
- CDK infrastructure stack list (11 stacks) matches codebase exactly ✓
- CloudFront distributions use dynamic bucket references — auto-resolve ✓
- CloudFront uses default certificates — no custom domain cert needed ✓
- No VPC peering or Transit Gateway — CIDR overlap is safe ✓
- Route53 is global — CDK `HostedZone.FromLookup` finds zones by domain name ✓
- Private hosted zones are VPC-associated — same domain in new VPC = new zone ✓

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

### Terraform
- AWS provider version 4.67.0 is region-agnostic ✓
- No Terraform modules with region assumptions ✓
- Account ID hardcoding in IAM policies is correct (account-level, not region-specific) ✓

### Third-Party Integrations
- Auth0, Checkout.com, SendGrid, Sentry, Seats.io — all SaaS, region-agnostic ✓

---

## Recommendations Summary

### Before Starting Phase 1

1. **Run `aws s3 ls`** in both accounts to verify exact bucket names
2. **Check eu-central-1 service quotas** and request increases
3. **Clarify `demo` environment** inclusion/deferral

### Remaining Manual Work (not yet in plan)

All major gaps have been resolved in the plan. The only remaining items:

1. **Update env-var JSON bucket names** for the `-eu` suffix — media, integration, and pdf-generator services have hardcoded bucket names like `ticketing-dev-media`, `dev-pdf-tickets` in their env-var files. These need manual updates alongside the `STORAGE_REGION` bulk script.
2. **Verify NS delegation** at the parent domain (`tickets.mdlbeast.net` or `mdlbeast.net`) after Terraform creates new Route53 zones in eu-central-1. The plan now documents this but the actual delegation update depends on where the parent zone is managed.
3. **CSV generator runtime SSM params** — the CSV generator reads all parameters under `/{env}/tp/csv/generator/*` at Lambda runtime. Verify these exist or are populated from env-var JSON files.

---

## Risk Matrix

| Risk | Likelihood | Impact | Mitigation | Status |
|------|-----------|--------|------------|--------|
| **NS delegation at parent domain** | **MEDIUM** | **HIGH** | **Update parent zone NS records after Terraform creates new zones** | **OPEN** |
| **S3 bucket names in env-var JSON** | **MEDIUM** | **MEDIUM** | **Manual update needed for `-eu` suffix in ~7 env-var files** | **OPEN** |
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

*Review completed: 2026-03-24 (Round 5+)*
*Validated against: 30+ service repositories, Terraform configs, CDK stacks, CI/CD workflows, ConfigMaps*
*Round 5: 6 parallel agents — missing services CDK audit, Terraform cross-references, uncovered me-south-1 references, SSM parameters, GitHub secrets, S3 buckets*
*Round 5+: 3 parallel agents — comprehensive SSM audit, S3 bucket naming propagation, Route53 DNS rerouting analysis*
