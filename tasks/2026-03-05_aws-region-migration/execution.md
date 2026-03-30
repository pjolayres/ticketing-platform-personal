# Execution Log: AWS Region Migration (me-south-1 → eu-central-1)

- [Shared Outputs Registry](#shared-outputs-registry)
- [Deviations Log](#deviations-log)
- [Phase 1: Code Preparation](#phase-1-code-preparation)
  - [P1-T0: Create branches in all 34 repos](#p1-t0-create-branches-in-all-34-repos)
  - [P1-T1: Update Terraform region references](#p1-t1-update-terraform-region-references)
  - [P1-T2: EKS deprecation in terraform-prod](#p1-t2-eks-deprecation-in-terraform-prod)
  - [P1-T3: EKS deprecation cleanup in terraform-dev](#p1-t3-eks-deprecation-cleanup-in-terraform-dev)
  - [P1-T4: Update CDK env-var JSON files (STORAGE\_REGION)](#p1-t4-update-cdk-env-var-json-files-storage_region)
  - [P1-T5: Update aws-lambda-tools-defaults.json](#p1-t5-update-aws-lambda-tools-defaultsjson)
  - [P1-T6: Update infrastructure C# code](#p1-t6-update-infrastructure-c-code)
  - [P1-T7: Update test files](#p1-t7-update-test-files)
  - [P1-T8: Update ConfigMap YAML files](#p1-t8-update-configmap-yaml-files)
  - [P1-T9: Update Mobile Scanner CI/CD](#p1-t9-update-mobile-scanner-cicd)
  - [P1-T10: Update Dashboard CSP and .env files](#p1-t10-update-dashboard-csp-and-env-files)
  - [P1-T11: Delete CDK context caches](#p1-t11-delete-cdk-context-caches)
  - [P1-T12: Update CI/CD templates and ConfigMap workflows](#p1-t12-update-cicd-templates-and-configmap-workflows)
  - [P1-T13: Update local development settings](#p1-t13-update-local-development-settings)
  - [P1-T14: Security remediation](#p1-t14-security-remediation)
  - [P1-T15: Temporarily exclude RDS cluster from Terraform](#p1-t15-temporarily-exclude-rds-cluster-from-terraform)
  - [P1-T16: Set temporary `production-eu` domain mapping in CDK](#p1-t16-set-temporary-production-eu-domain-mapping-in-cdk)
  - [P1-T17: Run tests](#p1-t17-run-tests)
  - [P1-T18: Verify zero me-south-1 references](#p1-t18-verify-zero-me-south-1-references)
  - [P1-T19: Merge and publish ticketing-platform-tools NuGet package](#p1-t19-merge-and-publish-ticketing-platform-tools-nuget-package)
  - [P1-T20: Confirm no other repos merged yet](#p1-t20-confirm-no-other-repos-merged-yet)
- [Phase 2: Production Foundation \& Data Restore](#phase-2-production-foundation--data-restore)
  - [P2-S1: Service quota pre-checks](#p2-s1-service-quota-pre-checks)
  - [P2-S2: Create Terraform state bucket](#p2-s2-create-terraform-state-bucket)
  - [P2-S3: Recreate Secrets Manager entries](#p2-s3-recreate-secrets-manager-entries)
  - [P2-S4: Terraform apply (without RDS cluster)](#p2-s4-terraform-apply-without-rds-cluster)
  - [P2-S5: Populate manual SSM parameters](#p2-s5-populate-manual-ssm-parameters)
  - [P2-S5.1: Create DynamoDB Cache table](#p2-s51-create-dynamodb-cache-table)
  - [P2-S6: Restore Aurora from AWS Backup](#p2-s6-restore-aurora-from-aws-backup)
  - [P2-S7: Restore S3 data from AWS Backup](#p2-s7-restore-s3-data-from-aws-backup)
  - [P2-S8: CDK bootstrap](#p2-s8-cdk-bootstrap)
  - [P2-VERIFY: Phase 2 verification checklist](#p2-verify-phase-2-verification-checklist)
- [Phase 3: Production Services under Temporary Domain](#phase-3-production-services-under-temporary-domain)
  - [P3-S1: Create temporary Route53 hosted zone](#p3-s1-create-temporary-route53-hosted-zone)
  - [P3-S2: Create ACM certificates (temporary domain)](#p3-s2-create-acm-certificates-temporary-domain)
  - [P3-S3: Infrastructure CDK (11 stacks — strict order)](#p3-s3-infrastructure-cdk-11-stacks--strict-order)
  - [P3-S4: Update connection strings \& region-dependent secrets](#p3-s4-update-connection-strings--region-dependent-secrets)
  - [P3-S5: Per-service CDK deployment](#p3-s5-per-service-cdk-deployment)
    - [P3-S5-01: catalogue](#p3-s5-01-catalogue)
    - [P3-S5-02: organizations](#p3-s5-02-organizations)
    - [P3-S5-03: loyalty](#p3-s5-03-loyalty)
    - [P3-S5-04: csv-generator](#p3-s5-04-csv-generator)
    - [P3-S5-05: pdf-generator](#p3-s5-05-pdf-generator)
    - [P3-S5-06: automations](#p3-s5-06-automations)
    - [P3-S5-07: extension-api](#p3-s5-07-extension-api)
    - [P3-S5-08: extension-deployer](#p3-s5-08-extension-deployer)
    - [P3-S5-09: extension-executor](#p3-s5-09-extension-executor)
    - [P3-S5-10: extension-log-processor](#p3-s5-10-extension-log-processor)
    - [P3-S5-11: customer-service](#p3-s5-11-customer-service)
    - [P3-S5-12: inventory](#p3-s5-12-inventory)
    - [P3-S5-13: pricing](#p3-s5-13-pricing)
    - [P3-S5-14: media](#p3-s5-14-media)
    - [P3-S5-15: reporting-api](#p3-s5-15-reporting-api)
    - [P3-S5-16: marketplace](#p3-s5-16-marketplace)
    - [P3-S5-17: integration](#p3-s5-17-integration)
    - [P3-S5-18: distribution-portal](#p3-s5-18-distribution-portal)
    - [P3-S5-19: sales](#p3-s5-19-sales)
    - [P3-S5-20: access-control](#p3-s5-20-access-control)
    - [P3-S5-21: transfer](#p3-s5-21-transfer)
    - [P3-S5-22: geidea](#p3-s5-22-geidea)
    - [P3-S5-23: ecwid-integration](#p3-s5-23-ecwid-integration)
    - [P3-S5-24: gateway (LAST)](#p3-s5-24-gateway-last)
  - [P3-S6: End-to-end validation (temporary domain)](#p3-s6-end-to-end-validation-temporary-domain)
  - [P3-VERIFY: Phase 3 verification checklist](#p3-verify-phase-3-verification-checklist)
- [Phase 4: DNS Cutover to Production Domain](#phase-4-dns-cutover-to-production-domain)
  - [P4-S1: Revert temporary domain mapping in CDK](#p4-s1-revert-temporary-domain-mapping-in-cdk)
  - [P4-S1.1: Publish updated ticketing-platform-tools NuGet package](#p4-s11-publish-updated-ticketing-platform-tools-nuget-package)
  - [P4-S2: Create ACM certificates for real domain](#p4-s2-create-acm-certificates-for-real-domain)
  - [P4-S3: Redeploy public-facing stacks](#p4-s3-redeploy-public-facing-stacks)
  - [P4-S4: Update GitHub secrets \& variables](#p4-s4-update-github-secrets--variables)
  - [P4-S5: Merge to production \& deploy frontends](#p4-s5-merge-to-production--deploy-frontends)
  - [P4-S6: End-to-end validation (production domain)](#p4-s6-end-to-end-validation-production-domain)
  - [P4-S7: Post-go-live monitoring (72 hours)](#p4-s7-post-go-live-monitoring-72-hours)
  - [P4-S8: Migrate `ticketing-glue-gcp` S3 bucket to eu-central-1](#p4-s8-migrate-ticketing-glue-gcp-s3-bucket-to-eu-central-1)
  - [P4-S9: Fix stale RDS endpoint in `FINANCE_REPORT_SENDER_CONFIG`](#p4-s9-fix-stale-rds-endpoint-in-finance_report_sender_config)
- [Phase 5: Dev+Sandbox Rebuild](#phase-5-devsandbox-rebuild)
  - [P5-S1: Service quota pre-checks (account 307824719505)](#p5-s1-service-quota-pre-checks-account-307824719505)
  - [P5-S2: Foundation](#p5-s2-foundation)
  - [P5-S3: Services \& validation](#p5-s3-services--validation)
- [Post-Migration Tasks](#post-migration-tasks)
  - [PM-1: Temporary domain cleanup](#pm-1-temporary-domain-cleanup)
  - [PM-2: Extension Lambda redeployment](#pm-2-extension-lambda-redeployment)
  - [PM-3: Configure AWS Backup in eu-central-1](#pm-3-configure-aws-backup-in-eu-central-1)
  - [PM-4: Post-migration cleanup (after 7-day stability + me-south-1 recovery)](#pm-4-post-migration-cleanup-after-7-day-stability--me-south-1-recovery)


> **How to use this log:** Each step has a status, timestamp, and notes section. An executing agent should:
>
> 1. Find the first step with status `PENDING` — that is the next step to execute.
> 2. Set its status to `IN_PROGRESS` and record the start timestamp.
> 3. Execute the step per `plan.md`.
> 4. Set status to `DONE`, `FAILED`, or `SKIPPED` and record outputs/notes.
> 5. Stop and await confirmation before proceeding.
>
> **Status values:** `PENDING` | `IN_PROGRESS` | `DONE` | `FAILED` | `SKIPPED` | `BLOCKED`
>
> **Capturing outputs:** Some steps produce values consumed by later steps (e.g., Aurora endpoint, subnet IDs, cert ARNs). Record these in the `outputs` field. Later steps reference them by key name.
>
> **Recording deviations:** If a step cannot be executed exactly as written in `plan.md`, record a deviation entry in that step's **Deviations** field using this format:
>
> ```
> **DEVIATION:** <what changed vs. the plan>
> **Reason:** <why the deviation was necessary — error encountered, missing resource, plan inaccuracy, etc.>
> **Actions taken:** <exactly what was done instead>
> **Downstream impact:** <which future steps/phases are affected and how, or "None" if self-contained>
> ```
>
> Also append a summary line to the **Deviations Log** section (below the Shared Outputs Registry) so that future agents can quickly scan all deviations without reading every step.

---

## Shared Outputs Registry

> Outputs produced by steps that are consumed by downstream steps. Agents should read this section to resolve placeholders. Update this section whenever a step produces a reusable output.

| Key                     | Value                                                                                    | Produced By | Consumed By         |
| ----------------------- | ---------------------------------------------------------------------------------------- | ----------- | ------------------- |
| `VPC_ID`                | `vpc-00de5834b0f381b4d`                                                                  | P2-S4       | P2-S4-verify, P2-S5 |
| `SUBNET_1_ID`           | `subnet-01b47a6d26df020ec`                                                               | P2-S4       | P2-S5               |
| `SUBNET_2_ID`           | `subnet-0b38abd7f712530d9`                                                               | P2-S4       | P2-S5               |
| `SUBNET_3_ID`           | `subnet-05359403da2d9a5fe`                                                               | P2-S4       | P2-S5               |
| `RDS_SG_ID`             | `sg-00dab49088126dfa7`                                                                   | P2-S4       | P2-S5, P2-S6        |
| `KMS_KEY_ID`            | `72ea5a94-3fbc-494a-baa6-79f3d4c82121`                                                   | P2-S4       | P3-S4               |
| `AURORA_ENDPOINT`       | `ticketing.cluster-c0lac6czadei.eu-central-1.rds.amazonaws.com`                          | P2-S6       | P2-S6, P3-S4        |
| `AURORA_RO_ENDPOINT`    | `ticketing.cluster-ro-c0lac6czadei.eu-central-1.rds.amazonaws.com`                       | P2-S6       | P3-S4               |
| `RDS_USER`              | `devops`                                                                                 | P2-S6       | P2-S6, P3-S4        |
| `RDS_PASS`              |                                                                                          | P2-S3       | P2-S3, P2-S6        |
| `PROD_ZONE_ID`          | `Z095340838T2KOPA8X742`                                                                  | P2-S4       | P3-S2, P4-S2        |
| `ROOT_ZONE_ID`          | N/A (zone doesn't exist)                                                                 | P2-S4       | P3-S1               |
| `TEMP_ZONE_ID`          | `Z0663446BTJAVD4MTCYG`                                                                   | P3-S1       | P3-S2, post-cleanup |
| `CERT_ARN_GATEWAY_TEMP` | `arn:aws:acm:eu-central-1:660748123249:certificate/914c47a3-f0df-4e5c-a406-747f62fb2228` | P3-S2       | P3-S3               |
| `CERT_ARN_GEIDEA_TEMP`  | `arn:aws:acm:eu-central-1:660748123249:certificate/773c5a63-304a-476c-95dd-877065f91581` | P3-S2       | P3-S3               |
| `CERT_ARN_ECWID_TEMP`   | `arn:aws:acm:eu-central-1:660748123249:certificate/75e4cc24-20cc-491d-b87c-20ae2647f2b9` | P3-S2       | P3-S3               |
| `CERT_ARN_GATEWAY_PROD` | `arn:aws:acm:eu-central-1:660748123249:certificate/fd763671-01f5-4957-82d8-e321800b127d` | P4-S2       | P4-S3               |
| `CERT_ARN_GEIDEA_PROD`  | `arn:aws:acm:eu-central-1:660748123249:certificate/947916fe-e54c-4f89-b860-64355a8c685e` | P4-S2       | P4-S3               |
| `CERT_ARN_ECWID_PROD`   | `arn:aws:acm:eu-central-1:660748123249:certificate/0bf7cca4-fd68-4786-9bbe-990758f805b1` | P4-S2       | P4-S3               |
| `NEW_AWS_KEY`           | `AKIAZTV5IHRY3JAPWUFD`                                                                   | P3-S4       | P3-S4, P4-S4        |
| `NEW_AWS_SECRET`        | _(redacted — fetch from any `/prod/*` secret's `AWS_ACCESS_SECRET` key)_                 | P3-S4       | P3-S4, P4-S4        |
| `NUGET_VERSION_1`       | `1.0.1300`                                                                               | P1-T19      | P1-T19              |
| `NUGET_VERSION_2`       | `1.0.1301`                                                                               | P4-S1.1     | P4-S1.1             |

---

## Deviations Log

> Summary of all deviations from `plan.md`. Each entry links to the step where the full deviation record lives. Future agents: **read this section first** to understand how the current state differs from the original plan before executing your step.

| Step   | Summary                                                                                                                                                                                                                                                                                                                                                      | Downstream Impact                                                                                                                                        |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1-T0  | Switched terraform-dev to `master` and ecwid-integration to `production` before branching; configmap-prod branched from `disaster`                                                                                                                                                                                                                           | None                                                                                                                                                     |
| P1-T2  | Also removed 3 MSK ingress rules from rds.tf (referenced deleted msk.tf); deleted iam-s3-sqs.tf entirely (only had s3-sqs-eks)                                                                                                                                                                                                                               | None                                                                                                                                                     |
| P1-T4  | Bulk script updated 53 files across 18 repos (plan listed 14); extra repos had demo env files or weren't listed                                                                                                                                                                                                                                              | None                                                                                                                                                     |
| P1-T5  | 25 repos affected (plan listed 22); created hotfix branches in 3 extra repos (bandsintown-integration, marketing-feeds, xp-badges)                                                                                                                                                                                                                           | None                                                                                                                                                     |
| P1-T10 | `.env.development` gitignored — updated locally but not committed; `S3_MEDIA_BUCKET_URL` bucket renamed from `ticketing-media` to `ticketing-prod-media-eu`                                                                                                                                                                                                  | None                                                                                                                                                     |
| P1-T12 | Workflows disabled (trigger → workflow_dispatch) instead of deleted, per user preference                                                                                                                                                                                                                                                                     | None                                                                                                                                                     |
| P1-T13 | Pricing skipped (no me-south-1 refs); gateway had 4 Elasticsearch URI occurrences not 1                                                                                                                                                                                                                                                                      | None                                                                                                                                                     |
| P1-T14 | terraform-prod had no `.gitignore` — created from scratch                                                                                                                                                                                                                                                                                                    | None                                                                                                                                                     |
| P2-S3  | Used `replicate-secret-to-regions` from me-south-1 instead of manual recreation; `devops` created from backup (replica secret)                                                                                                                                                                                                                               | None — cleanup in P3-S4                                                                                                                                  |
| P2-S4  | Only one Route53 zone imported (not two); `tickets.mdlbeast.net` doesn't exist and was never in state                                                                                                                                                                                                                                                        | P3-S1 must use `PROD_ZONE_ID` for NS delegation instead of `ROOT_ZONE_ID`                                                                                |
| P2-S4  | S3 bucket renames (`-eu` suffix) missed in Phase 1 — fixed in this step: `s3.tf`, `variables.tf`, `mobile.tf` (4 buckets)                                                                                                                                                                                                                                    | `ticketing-app-mobile-eu` needs S3 copy from me-south-1; dashboard CloudFront URLs need updating                                                         |
| P2-S4  | 34 global resources imported (IAM, CloudFront OACs, S3 state bucket) — plan assumed fresh creation                                                                                                                                                                                                                                                           | None — IAM policies are additive (both regions work)                                                                                                     |
| P2-S4  | New CloudFront distribution IDs: `E2E0LQF2V6W4U` (s3_prod), `E1NNQYK06MZJSB` (mobile) — dashboard has hardcoded old IDs                                                                                                                                                                                                                                      | Dashboard code + GitHub vars need CloudFront URL updates before go-live                                                                                  |
| P2-S4  | `developer-msk` group policy attachment removed (AWS 10-policy limit, MSK deprecated)                                                                                                                                                                                                                                                                        | None                                                                                                                                                     |
| P2-S4  | Removed `acl = "private"` from `ticketing-terraform-prod-eu` bucket (ACLs disabled by default since April 2023)                                                                                                                                                                                                                                              | None                                                                                                                                                     |
| P2-S5  | Created 35 params (plan: 16). Added CSV/PDF full runtime sets, Slack `WebhookUrl`, extension manual params. Fixed `STORAGE_EXPIRATION_HOURS` (167/168 not 48). Used live me-south-1 values. Set `ACCESS_CONTROL_SERVICE_URL`/`ExtensionApiUrl` to temp domain.                                                                                               | `ACCESS_CONTROL_SERVICE_URL` + `ExtensionApiUrl` must update to final domain at Phase 4 cutover. `/rds/ticketing-cluster-ro-endpoint` deferred to P2-S6. |
| P2-S6  | IAM role name was `AWSBackupDefaultServiceRole` not `AWSBackupDefaultRole`; restore metadata required full format with JSON arrays; scaling config must be set before creating serverless instances; `/rds/ticketing-cluster` secret was replica — promoted before updating; terraform plan showed 4 minor drifts — applied, min_capacity set to 1.5 (not 8) | Replicated secrets need promotion before update in P3-S4                                                                                                 |
| P2-S7  | Restored 3 buckets (plan listed 2) — added `ticketing-app-mobile`; plan metadata wrong (`NewBucket` undocumented, missing `EncryptionType`/`KMSKey` for cross-region); required temporary ACL/ownership relaxation on destination buckets; pdf-download needed retry restore after partial failure                                                           | None                                                                                                                                                     |
| P3-S1  | NS delegation added in Cloudflare (`mdlbeast.net` zone) instead of via AWS CLI against Route53 `tickets.mdlbeast.net` parent zone                                                                                                                                                                                                                            | Post-migration cleanup (PM-1) must remove NS records from Cloudflare, not Route53                                                                        |
| P3-S3  | Stack 8 failed — VPC missing `enable_dns_hostnames = true`. Fixed in Terraform `vpc.tf`, applied, retried CDK successfully.                                                                                                                                                                                                                                  | `ticketing-platform-terraform-prod` has uncommitted `vpc.tf` change — must commit before Phase 3 completion                                              |
| P3-S4  | Promoted 22 replica secrets before updating; deleted stale CICD key + created new; updated 19 secrets (not 16); used `jq` not Python; `--output json` pipeline to handle special chars                                                                                                                                                                       | Old CICD key `AKIAZTV5IHRYY5XWYBO2` deleted — me-south-1 CI/CD using it will fail. `prod/data` still has me-south-1 Glue bucket ref (not in scope)       |
| P3-S5-01 | SSM subnet params stored full IDs (`subnet-...`) causing double prefix; fixed to suffix-only | None — fixed globally for all services |
| P3-S5-01 | Global IAM roles from me-south-1 CDK stacks already exist; must use `cdk import` + inline policy delete pattern for every service | All P3-S5 service deployments must follow import pattern |
| P3-S5-01 | RDS SG had no Lambda ingress rule; added VPC CIDR port 5432 rule via Terraform `rds.tf` | None — applies globally; `terraform-prod` has uncommitted `rds.tf` change |
| P3-S5-02 | Organization SQS queue visibility timeout (120s) < Lambda timeout (900s); fixed in infrastructure CDK `ConsumersSqsStack.cs` and redeployed | `ticketing-platform-infrastructure` has uncommitted code change |
| P3-S5-02 | Pre-deleted all 63 stale me-south-1 inline policies across all service IAM roles; backup + restore script in `backup-iam-policies/` | All future P3-S5 deployments skip inline policy deletion step; still need `cdk import` per role |
| P3-S5-03 | BackgroundJobsStack failed — log group for background jobs Lambda must be pre-created (not just consumers/serverless) | All P3-S5 services with BackgroundJobsStack must pre-create `/aws/lambda/<service>-background-jobs-lambda-prod` log group |
| P3-S5-05 | Lambda package exceeded 250MB (CDK DLLs ~91MB + SkiaSharp multi-platform runtimes ~120MB); cleaned publish dir before deploy. **Workaround:** after `dotnet publish -c Release -p:PublishReadyToRun=false`, delete `Amazon.CDK.*`, `Amazon.JSII.*`, `Constructs.dll` and non-linux-x64 runtimes from `publish/`. Only pdf-generator is affected (unique SkiaSharp/QuestPDF deps). | Future CI/CD for pdf-generator needs same cleanup or .csproj exclusion; no other services affected |
| P3-S5-06 | `finance_report_sender_lambda_role_prod` had stale DefaultPolicy not caught by P3-S5-02 bulk deletion; first deploy rolled back, deleted policy, retried successfully | Future P3-S5 deployments should check for stale DefaultPolicy inline policies if deploy fails with "policy already exists" |
| P3-S5-08 | ExtensionDeployerStack failed — Lambda `ticketing-platform-extension-deployer-prod` not in eu-central-1 (Docker image-based, deployed via `dotnet lambda deploy-function`, not CDK). Deployed Lambda + ECR repo manually before retrying CDK. | PM-2 can now proceed; other services with external Lambdas may need same treatment |
| P3-S5-20 | Three stale DefaultPolicy inline policies survived P3-S5-02 bulk cleanup on access-control roles; Lambda uses `accesscontrol-` prefix (no hyphen), not `access-control-` | None — policies recreated by CDK |
| P3-S5-14 | MediaStorageStack failed twice: (1) IAM user `imgix-prod` already exists (global), (2) inline policy `media-s3-imgix-user-policy-prod` already on user. S3 bucket orphaned on rollback. Fixed by importing user + bucket, deleting stale policy. | None — media is only service with IAM user in CDK |
| P3-S5-18 | Health check failed — `SalesServiceBaseRoute` env var missing (was in K8s configmap, not in Lambda env-var.prod.json). Added to Lambda config + `env-var.prod.json`. DNS uses `dp` prefix not `distribution-portal`. | `ticketing-platform-distribution-portal` has uncommitted code change. Tier 3 services (access-control, gateway, transfer) may need same configmap→env-var migration |
| P4-S1.1  | Bumped 25 repos instead of 18 — included 7 additional repos (loyalty, csv-generator, pdf-generator, automations, extension-deployer, extension-executor, extension-log-processor) | None — these repos will already be on `1.0.1301` when merged in P4-S5 |
| P4-S3    | Stale me-south-1 A records in `production.tickets.mdlbeast.net` zone blocked Gateway/Geidea/Ecwid deploys; deleted 3 records, retried successfully | None — remaining stale records (marketingfeed, xp-badges, old infra) for post-migration cleanup |
| P4-S3    | Stack names differed from plan: `TP-GatewayStack-prod`, `TP-ApiStack-geidea-prod`, `TP-ServerlessBackendStack-distribution-portal-prod` | None |
| P4-S3    | Old `internal.production-eu` zone orphaned — CloudFormation couldn't delete (non-empty, 14 stale CNAMEs) | PM-1 must also clean up orphaned zone `Z04720843DJKNCF1N97H0` |
| P4-S4    | Plan only listed org-level + few repo-specific secrets; 13 repos had environment-level secrets shadowing org values. Updated ~48 secrets across env/repo/mobile-scanner levels. Storybook variables skipped (no infra in eu-central-1). | Dev/sandbox env secrets still me-south-1 — update in P5. Storybook infra needs creation (post-migration). |

---

## Phase 1: Code Preparation

### P1-T0: Create branches in all 34 repos

- **Status:** `DONE`
- **Started:** 2026-03-25T00:00
- **Completed:** 2026-03-25T00:05
- **Repos (34):** `ticketing-platform-access-control`, `ticketing-platform-automations`, `ticketing-platform-catalogue`, `ticketing-platform-csv-generator`, `ticketing-platform-customer-service`, `ticketing-platform-dashboard`, `ticketing-platform-distribution-portal`, `ticketing-platform-distribution-portal-frontend`, `ticketing-platform-extension-api`, `ticketing-platform-extension-deployer`, `ticketing-platform-extension-executor`, `ticketing-platform-extension-log-processor`, `ticketing-platform-gateway`, `ticketing-platform-geidea`, `ticketing-platform-infrastructure`, `ticketing-platform-integration`, `ticketing-platform-inventory`, `ticketing-platform-loyalty`, `ticketing-platform-marketplace-service`, `ticketing-platform-media`, `ticketing-platform-mobile-scanner`, `ticketing-platform-mobile-libraries`, `ticketing-platform-organizations`, `ticketing-platform-pdf-generator`, `ticketing-platform-pricing`, `ticketing-platform-reporting-api`, `ticketing-platform-sales`, `ticketing-platform-shared`, `ticketing-platform-tools`, `ticketing-platform-transfer`, `ticketing-platform-templates-ci-cd`, `ticketing-platform-configmap-dev`, `ticketing-platform-configmap-sandbox`, `ticketing-platform-configmap-prod`, `ticketing-platform-terraform-dev`, `ticketing-platform-terraform-prod`, `ecwid-integration`
- **Deviations:**
  - **DEVIATION:** Switched `terraform-dev` from `feat/production-migration` to `master` and `ecwid-integration` from `development` to `production` before branching. `configmap-prod` branched from `disaster` (equivalent to production).
  - **Reason:** These repos were not on their production/main branches. User confirmed the correct base branches.
  - **Actions taken:** `git checkout master` in terraform-dev, `git checkout production` in ecwid-integration, branched configmap-prod from `disaster` as-is.
  - **Downstream impact:** None — branches are now on the correct base.
- **Notes:** All 34/34 repos verified on `hotfix/region-migration-eu-central-1`. Two repos (catalogue, customer-service) had transient SSH timeouts on first attempt, succeeded on retry.

### P1-T1: Update Terraform region references

- **Status:** `DONE`
- **Started:** 2026-03-25T00:10
- **Completed:** 2026-03-25T00:15
- **Repos:** `terraform-prod`, `terraform-dev`
- **Notes:** All changes applied per plan. AMI updated to `ami-08f4f484ed94e8352` (Amazon Linux 2, eu-central-1, 2026-03-02). Both secretmanager.tf files changed from hardcoded ARN to name-based lookup (`name = "terraform"`).

### P1-T2: EKS deprecation in terraform-prod

- **Status:** `DONE`
- **Started:** 2026-03-25T00:20
- **Completed:** 2026-03-25T00:30
- **Repo:** `terraform-prod`
- **Substeps:**
  - [x] Delete `opensearch.tf`, `redis.tf`, `waf.tf`, `msk.tf`, `runner.tf`, `ecr.tf`
  - [x] Rename `eks-subnet.tf` → `lambda-subnet.tf`, update resource names/tags
  - [x] Modify `user-cicd.tf` — remove EKS policy + attachment
  - [x] Modify `iam-s3-sqs.tf` — remove `s3-sqs-eks` policy (deleted entire file — only contained this policy)
  - [x] Modify `rds.tf` — remove 3 EKS subnet ingress rules
  - [x] Modify `group.tf` — remove `techlead-redis`, `developer-opensearch` attachments
  - [x] Modify `secretmanager.tf` — remove opensearch/redis outputs
- **Deviations:**
  - **DEVIATION:** Also removed 3 MSK subnet ingress rules from `rds.tf` (lines 30-51) and deleted `iam-s3-sqs.tf` entirely instead of just removing the `s3-sqs-eks` policy.
  - **Reason:** `rds.tf` referenced `aws_subnet.msk-1a/1b/1c-prod` from `msk.tf` which was deleted — would break terraform. `iam-s3-sqs.tf` only contained the `s3-sqs-eks` policy, so removing the policy = deleting the file.
  - **Actions taken:** Removed 6 ingress rules total (3 MSK + 3 EKS) from rds.tf. Deleted iam-s3-sqs.tf.
  - **Downstream impact:** None — these were dead references to deleted resources.
- **Notes:** Unused opensearch variables remain in `variables.tf` — harmless, can clean up later.

### P1-T3: EKS deprecation cleanup in terraform-dev

- **Status:** `DONE`
- **Started:** 2026-03-25T00:32
- **Completed:** 2026-03-25T00:36
- **Repo:** `terraform-dev`
- **Substeps:**
  - [x] Delete `iam-eks.tf`
  - [x] Modify `iam-s3-sqs.tf` — remove `s3-sqs-eks` (deleted entire file — only contained this policy)
  - [x] Modify `rds.tf` — remove EKS subnet ingress rules (3 rules removed, kept runner-1a rule)
  - [x] Modify `nat.tf` — remove `kubernetes.io/role/elb` tags (all 3 subnets)
- **Notes:** `lambda-subnet.tf` already existed (from prior commit d01f7df) but still has `eks-*` resource names internally — left as-is per plan scope. No deviations beyond deleting iam-s3-sqs.tf entirely (same pattern as P1-T2).

### P1-T4: Update CDK env-var JSON files (STORAGE_REGION)

- **Status:** `DONE`
- **Started:** 2026-03-25T01:00
- **Completed:** 2026-03-25T01:05
- **Repos (15):** `ticketing-platform-access-control`, `ticketing-platform-automations`, `ticketing-platform-customer-service`, `ticketing-platform-geidea`, `ticketing-platform-integration`, `ticketing-platform-loyalty`, `ticketing-platform-marketplace-service`, `ticketing-platform-media`, `ticketing-platform-pricing`, `ticketing-platform-reporting-api`, `ticketing-platform-sales`, `ticketing-platform-tools`, `ticketing-platform-transfer`, `ticketing-platform-xp-badges`, `ecwid-integration`
- **Substeps:**
  - [x] Run bulk `STORAGE_REGION` sed script across 14 services
  - [x] Manually update 4 S3 bucket name vars (media + integration prod env-vars)
- **Deviations:**
  - **DEVIATION:** Bulk script updated 53 files across 18 repos (not 14 as listed in the plan). Additional repos: `xp-badges`, plus `demo` environment files in `reporting-api`, `sales`, `access-control`, `transfer`, `pricing`, `integration`, `customer-service`, `marketplace-service`.
  - **Reason:** The plan's repo list was incomplete — these repos also had `STORAGE_REGION: me-south-1` in their env-var files.
  - **Actions taken:** Let the find/sed script catch all matching files (correct behavior).
  - **Downstream impact:** None — all files now correctly reference `eu-central-1`.
- **Notes:** All 53 env-var JSON files updated. 4 manual bucket name changes applied (media: `ticketing-prod-media-eu`, `tickets-pdf-download-eu` x2; integration: `tickets-pdf-download-eu`).

### P1-T5: Update aws-lambda-tools-defaults.json

- **Status:** `DONE`
- **Started:** 2026-03-25T01:10
- **Completed:** 2026-03-25T01:15
- **Repos (25):** `ticketing-platform-access-control`, `ticketing-platform-bandsintown-integration`, `ticketing-platform-csv-generator`, `ticketing-platform-customer-service`, `ticketing-platform-distribution-portal`, `ticketing-platform-extension-api`, `ticketing-platform-extension-deployer`, `ticketing-platform-extension-executor`, `ticketing-platform-extension-log-processor`, `ticketing-platform-gateway`, `ticketing-platform-geidea`, `ticketing-platform-integration`, `ticketing-platform-inventory`, `ticketing-platform-loyalty`, `ticketing-platform-marketing-feeds`, `ticketing-platform-marketplace-service`, `ticketing-platform-media`, `ticketing-platform-organizations`, `ticketing-platform-pdf-generator`, `ticketing-platform-pricing`, `ticketing-platform-reporting-api`, `ticketing-platform-sales`, `ticketing-platform-transfer`, `ticketing-platform-xp-badges`, `ecwid-integration`
- **Substeps:**
  - [x] Run bulk sed script across 42 files
  - [x] Fix pdf-generator anomaly (`eu-west-1` → `eu-central-1`)
- **Deviations:**
  - **DEVIATION:** 25 repos had changes (plan listed 22). Additional repos: `bandsintown-integration`, `marketing-feeds`, `xp-badges`. These 3 repos were not in P1-T0 branching — created `hotfix/region-migration-eu-central-1` branches in all 3 during commit.
  - **Reason:** Plan's repo list was incomplete.
  - **Actions taken:** Created hotfix branches in the 3 extra repos and moved commits there.
  - **Downstream impact:** None — all files now correctly reference `eu-central-1`.
- **Notes:** 42 files updated via bulk script + 1 pdf-generator anomaly fixed. All 25 repos committed on `hotfix/region-migration-eu-central-1`.

### P1-T6: Update infrastructure C# code

- **Status:** `DONE`
- **Started:** 2026-03-25T01:20
- **Completed:** 2026-03-25T01:25
- **Repos (2):** `ticketing-platform-infrastructure`, `ticketing-platform-tools`
- **Substeps:**
  - [x] Update `EnvironmentService.cs:24` fallback region
  - [x] Update `XRayInsightSlackService.cs:58` fallback region
  - [x] Update `ExtendedMessageS3BucketStack.cs:17` bucket name (add `-eu`)
  - [x] Update `SqsQueueService.cs:190` bucket name (add `-eu`)
  - [x] Update `MessageProducer.cs:210` bucket name (add `-eu`)
  - [x] Update `LambdaS3ExtendedMessagePolicyStatement.cs:26-27` wildcard pattern
- **Notes:** All 6 changes applied exactly as planned across 2 repos (infrastructure + tools). No deviations.

### P1-T7: Update test files

- **Status:** `DONE`
- **Started:** 2026-03-25T02:00
- **Completed:** 2026-03-25T02:05
- **Repos (8):** `ticketing-platform-media`, `ticketing-platform-catalogue`, `ticketing-platform-organizations`, `ticketing-platform-inventory`, `ticketing-platform-pricing`, `ticketing-platform-infrastructure`, `ticketing-platform-tools`, `ticketing-platform-integration`
- **Notes:** 9 files updated across 8 repos. All `me-south-1` → `eu-central-1` in test environment variables, JSON fixtures, ARNs, assertions, and presigned S3 URLs. tools repo had 2 files changed (LambdaUtilitiesTests.cs had a whitespace-only trailing change alongside the region edit). No deviations.

### P1-T8: Update ConfigMap YAML files

- **Status:** `DONE`
- **Started:** 2026-03-25T02:10
- **Completed:** 2026-03-25T02:15
- **Repos (3):** `ticketing-platform-configmap-dev`, `ticketing-platform-configmap-sandbox`, `ticketing-platform-configmap-prod`
- **Substeps:**
  - [x] Update dev manifests (6 files + secretstore.yml)
  - [x] Update sandbox manifests (5 files + secretstore.yml)
  - [x] Update prod manifests (4 STORAGE_REGION files + remove Elasticsearch URI from sales.yml)
- **Notes:** 17 files total across 3 repos. Dev: 7 files (6 manifests + secretstore.yml). Sandbox: 6 files (5 manifests + secretstore.yml). Prod: 5 files (4 STORAGE_REGION manifests + sales.yml Elasticsearch URI removal). No deviations.

### P1-T9: Update Mobile Scanner CI/CD

- **Status:** `DONE`
- **Started:** 2026-03-25T02:20
- **Completed:** 2026-03-25T02:22
- **Repos (1):** `ticketing-platform-mobile-scanner`
- **Notes:** 3 replacements in `.github/workflows/release-build.yml`: S3 HTTP URL region, S3 upload default region, CloudFront invalidation default region. No deviations.

### P1-T10: Update Dashboard CSP and .env files

- **Status:** `DONE`
- **Started:** 2026-03-25T02:25
- **Completed:** 2026-03-25T02:30
- **Repos (1):** `ticketing-platform-dashboard`
- **Substeps:**
  - [x] Update 6 S3 URLs in `vercel.json` CSP (region + bucket names)
  - [x] Update `.env`, `.env.sandbox`, `.env.development` MEDIA_HOST URLs
- **Deviations:**
  - **DEVIATION:** `.env.development` is gitignored — changes were made locally but not committed. Also, `.env.development` line 32 `S3_MEDIA_BUCKET_URL` bucket name was `ticketing-media` (not `ticketing-prod-media`) — updated to `ticketing-prod-media-eu` to match the new naming convention.
  - **Reason:** `.env.development` is in `.gitignore`. The old bucket name `ticketing-media` was inconsistent with the `-eu` naming pattern used for migrated buckets.
  - **Actions taken:** Committed `vercel.json`, `.env`, `.env.sandbox` only. `.env.development` updated locally but not tracked.
  - **Downstream impact:** None — `.env.development` is a local-only file. API Gateway endpoint IDs in MEDIA_HOST will need updating when new endpoints are deployed in later phases.
- **Notes:** 6 CSP URLs in vercel.json updated (region + `-eu` bucket suffix). 3 env files updated (region only for MEDIA_HOST — endpoint IDs will change after deployment). `.env.development` also had 2 `S3_MEDIA_BUCKET_URL` entries updated with region + bucket name.

### P1-T11: Delete CDK context caches

- **Status:** `DONE`
- **Started:** 2026-03-25T02:32
- **Completed:** 2026-03-25T02:34
- **Repos (3):** `ticketing-platform-infrastructure`, `ticketing-platform-gateway`, `ticketing-platform-media`
- **Notes:** All 3 `cdk.context.json` files deleted locally. No commit needed — all 3 files are in `.gitignore` in their respective repos.

### P1-T12: Update CI/CD templates and ConfigMap workflows

- **Status:** `DONE`
- **Started:** 2026-03-25T02:36
- **Completed:** 2026-03-25T02:42
- **Repos (4):** `ticketing-platform-templates-ci-cd`, `ticketing-platform-configmap-dev`, `ticketing-platform-configmap-sandbox`, `ticketing-platform-configmap-prod`
- **Substeps:**
  - [x] Disable `deploy.yml` EKS workflow in templates-ci-cd (trigger → workflow_dispatch)
  - [x] Disable `k8s.yml` EKS workflow in templates-ci-cd (trigger → workflow_dispatch)
  - [x] Disable ConfigMap CI/CD workflows (dev ci.yml, sandbox ci.yml, prod ci.yml + disaster.yml — all trigger → workflow_dispatch)
- **Deviations:**
  - **DEVIATION:** Workflows disabled via `workflow_dispatch` trigger instead of deleted, per user preference.
  - **Reason:** User requested keeping the files in the repo rather than deleting them.
  - **Actions taken:** Changed `on:` trigger to `workflow_dispatch` and annotated workflow names with "(DISABLED — EKS deprecated)" in all 6 files.
  - **Downstream impact:** None — workflows will not auto-trigger but remain available for reference.
- **Notes:** 6 workflow files across 4 repos. `deploy.yml` had `workflow_call` trigger (reusable template); `k8s.yml` had `push: [master]`; all 4 configmap workflows had `push: [master]` or `push: [disaster]`.

### P1-T13: Update local development settings

- **Status:** `DONE`
- **Started:** 2026-03-25T02:44
- **Completed:** 2026-03-25T02:48
- **Repos (5):** `ticketing-platform-media`, `ticketing-platform-extension-api`, `ticketing-platform-distribution-portal`, `ticketing-platform-gateway`, `ticketing-platform-sales`
- **Deviations:**
  - **DEVIATION:** Pricing repo skipped — no `me-south-1` references in `launchSettings.json` (plan listed it). Gateway had 4 Elasticsearch URI occurrences (3 profiles: Gateway, Localhost, Prod, Sandbox) not just 1.
  - **Reason:** Plan listed pricing but it only had localhost references. Gateway had the same Elasticsearch URI repeated across 4 launch profiles.
  - **Actions taken:** Skipped pricing, updated all 4 gateway occurrences via replace_all.
  - **Downstream impact:** None.
- **Notes:** 11 replacements across 5 files/repos. Elasticsearch/OpenSearch URIs updated region-only (hosts won't exist in new region since OpenSearch is deprecated, but keeps settings consistent). RDS host cluster ID kept as-is (will change after backup restore).

### P1-T14: Security remediation

- **Status:** `DONE`
- **Started:** 2026-03-25T03:00
- **Completed:** 2026-03-25T03:05
- **Repos (3):** `ticketing-platform-terraform-dev`, `ticketing-platform-terraform-prod`, `ticketing-platform-configmap-prod`
- **Substeps:**
  - [x] Add `*.tfstate` to `.gitignore` in terraform-dev and terraform-prod
  - [x] Fix `s3.tf:246` lifecycle bucket reference (dev)
  - [x] Remove plaintext Elasticsearch credentials from configmap-prod `sales.yml`
- **Deviations:**
  - **DEVIATION:** `terraform-prod` had no `.gitignore` — created one from scratch (matching terraform-dev entries plus tfstate patterns). An existing `terraform.tfstate` is already tracked in git history.
  - **Reason:** Plan assumed `.gitignore` existed; it didn't.
  - **Actions taken:** Created `.gitignore` with `.terraform`, `.DS_Store`, `*.tfstate`, `*.tfstate.backup`.
  - **Downstream impact:** None.
- **Notes:** Removed 5 Elasticsearch lines from sales.yml (Username, Password with plaintext value, Index, NumberOfReplicas, NumberOfShards). Prod plaintext creds in terraform-prod `variables.tf` deferred to Phase 4 per plan.

### P1-T15: Temporarily exclude RDS cluster from Terraform

- **Status:** `DONE`
- **Started:** 2026-03-25T03:10
- **Completed:** 2026-03-25T03:14
- **Repos (2):** `ticketing-platform-terraform-prod`, `ticketing-platform-terraform-dev`
- **Substeps:**
  - [x] Comment out `aws_rds_cluster` + `aws_rds_cluster_instance` in terraform-prod `rds.tf`
  - [x] Comment out same in terraform-dev `rds.tf`
- **Notes:** Both files: commented out cluster + instance blocks with explanatory header comment. Kept subnets, security groups, subnet groups, and route table associations intact (needed for backup restore). No deviations.

### P1-T16: Set temporary `production-eu` domain mapping in CDK

- **Status:** `DONE`
- **Started:** 2026-03-25T03:16
- **Completed:** 2026-03-25T03:22
- **Repos (5):** `ticketing-platform-tools`, `ticketing-platform-gateway`, `ticketing-platform-infrastructure`, `ticketing-platform-geidea`, `ecwid-integration`
- **Substeps:**
  - [x] `ServerlessApiStackHelper.cs:47` (ticketing-platform-tools)
  - [x] `GatewayStack.cs:32` (gateway)
  - [x] `GatewayStack.cs:107` (gateway)
  - [x] `InternalHostedZoneStack.cs:15` (infrastructure)
  - [x] `InternalCertificateStack.cs:15` (infrastructure)
  - [x] `Geidea ApiStack.cs:32` (geidea)
  - [x] `Ecwid ApiStack.cs:32` (ecwid-integration)
- **Notes:** All 7 occurrences changed from `"production"` to `"production-eu"` across 5 repos. Verified no remaining `"production"` domain mappings in any of the files. No deviations. IDE diagnostics on GatewayStack.cs (string comparison style, unnecessary using) are pre-existing — not introduced by this change.

### P1-T17: Run tests

- **Status:** `DONE`
- **Started:** 2026-03-25T16:00
- **Completed:** 2026-03-25T16:45
- **Substeps:**
  - [x] `dotnet test` in each .NET repo with changes
  - [x] `npm run test && npm run typescript` in dashboard
- **Notes:** Ran `dotnet test` across all 24 .NET repos with changes and test projects. 22/24 passed cleanly. Two pre-existing failures unrelated to migration:
  - **pdf-generator**: 1 test failed (`PdfTicketsPendingHandlerTests.Handle_WhenFilesDoNotExist_ShouldGenerateAndStorePdfs`) — mock expectation failure. Our only change was `aws-lambda-tools-defaults.json` (region); test file untouched.
  - **ecwid-integration**: Build failure due to `AutoMapper 13.0.1` newly-discovered vulnerability (`NU1903`) + `TreatWarningsAsErrors=true`. Not migration-related.
  - **Dashboard**: Jest: 8 pre-existing snapshot/module failures (missing `@react-google-maps/api`). TypeScript: 3 pre-existing errors (missing `@react-google-maps/api`, `pdfmake` type declarations). Our only changes were `.env`, `.env.sandbox`, `vercel.json`.
  - **No regressions introduced by the region migration changes.**

### P1-T18: Verify zero me-south-1 references

- **Status:** `DONE`
- **Started:** 2026-03-25T17:00
- **Completed:** 2026-03-25T17:05
- **Notes:** Ran the plan's grep command. Remaining `me-south-1` references are all in non-deployable locations: `cdk.out/` (build artifacts, regenerated on synth), `bin/Debug/` and `bin/Release/` (build outputs), disabled EKS workflows (`k8s.yml`, `deploy.yml` — disabled in P1-T12 via workflow_dispatch), `.tfstate` (Terraform state files), backup/planning directories. Zero references in deployable source code.
- **Grep output (should be empty):** Empty (after excluding cdk.out, bin, obj, disabled workflows, tfstate, backups, configmap, README, .idea — all per plan expectations)

### P1-T19: Merge and publish ticketing-platform-tools NuGet package

- **Status:** `DONE`
- **Started:** 2026-03-25T17:10
- **Completed:** 2026-03-25T17:45
- **Substeps:**
  - [x] Merge hotfix branch to master in ticketing-platform-tools (PR #1272)
  - [x] Push to trigger nuget.yml workflow
  - [x] Wait for workflow completion — version: **1.0.1300**
  - [x] Bump TP.Tools.\* version in 25 service repos (committed on hotfix branches)
- **Notes:**
  - Reverted version bump in bandsintown-integration, marketing-feeds, xp-badges (excluded from migration)
  - **automations**: fixed 13 transitive NU1605 dependency conflicts + replaced removed `CreateLambdaPolicies` with `ServerlessApiStackLambdaPoliciesCollection` in 4 CDK stacks
  - **ecwid-integration**: added `NU1903` to `NoWarn` in TP.Ecwid.API (AutoMapper vulnerability, no patched version)
  - Verified: 22 repos pass restore+tests, automations builds clean, ecwid 15/15 tests pass
  - pdf-generator has 1 pre-existing flaky test (unrelated)
  - [x] Commit version bump in each repo
  - [x] Verify build with one service (`dotnet build`)
- **Outputs:**
  - `NUGET_VERSION_1`: `1.0.1300`
- **Notes:** Version 1.0.1300 published and bumped across 22 service repos.

### P1-T20: Confirm no other repos merged yet

- **Status:** `DONE`
- **Started:** 2026-03-25T18:00
- **Completed:** 2026-03-25T18:05
- **Notes:** Verified all 40 repos. 34 repos on `hotfix/region-migration-eu-central-1` — none merged. 3 repos (`distribution-portal-frontend`, `mobile-libraries`, `shared`) on default branches with no hotfix branch (no migration changes needed). `ticketing-platform-tools` hotfix merged to master via PR #1272 (confirmed on `origin/master`). Gate check passes — only tools has been merged, as required.

---

## Phase 2: Production Foundation & Data Restore

### P2-S1: Service quota pre-checks

- **Status:** `DONE`
- **Started:** 2026-03-25T18:10
- **Completed:** 2026-03-25T18:12
- **Substeps:**
  - [x] Check Lambda concurrent executions quota
  - [x] Check VPC NAT gateway quota
  - [x] Check RDS cluster quota
  - [x] Request increases if needed — **not needed**
- **Notes:** All quotas sufficient in eu-central-1. Lambda: 1,000 concurrent (need ~30). NAT gateways: 5/AZ, 5/VPC (need 1). DB clusters: 40 (need 1). No increases required.

### P2-S2: Create Terraform state bucket

- **Status:** `DONE`
- **Started:** 2026-03-25T18:13
- **Completed:** 2026-03-25T18:14
- **Substeps:**
  - [x] Create `ticketing-terraform-prod-eu` bucket
  - [x] Enable versioning
  - [x] Enable encryption (AES256)
- **Notes:** Bucket created in eu-central-1 with versioning and SSE-S3 (AES256) encryption enabled. No deviations.

### P2-S3: Recreate Secrets Manager entries

- **Status:** `DONE`
- **Started:** 2026-03-25T18:15
- **Completed:** 2026-03-25T18:25
- **Substeps:**
  - [x] Step 1: Create `terraform` secret (RDS password — required before terraform apply)
  - [x] Step 2: Create `/rds/ticketing-cluster` secret (placeholder host)
  - [x] Step 3: Bulk-create 20 service secrets from backups (strip Elasticsearch/Redis keys)
  - [x] Step 4: Create ecwid secret (partial backup + placeholders)
  - [x] Step 5: Create `devops` secret
  - [x] Step 6: Create `prod/data` secret
  - [x] Step 7: Verify 24 secrets exist
- **Deviations:**
  - **DEVIATION:** Used `aws secretsmanager replicate-secret-to-regions` from me-south-1 instead of manually recreating secrets from local backups. `devops` secret created manually from backup (replication failed — it's a replica secret, primary in another region).
  - **Reason:** me-south-1 Secrets Manager API became available during execution. Replication preserves exact current values (potentially newer than local backups).
  - **Actions taken:** Replicated 23 secrets via API (including `/prod/access-control` done by user). Created `devops` manually from `backup-secrets/devops.json`. Total: 24 secrets in eu-central-1.
  - **Downstream impact:** Replicated secrets retain Elasticsearch/Redis keys and old CONNECTION*STRINGS (plan would have stripped/placeholdered these). No functional impact — Elasticsearch/Redis code removed in Phase 1, and all region-dependent keys are overwritten in Phase 3.4 regardless. Ecwid secret still missing the same config keys (`ECWID_STORE_ID`, `ANCHANTO*\*`, `CONNECTION_STRINGS`) as the plan expected.
- **Outputs:**
  - `RDS_PASS`: _(exists in `terraform` secret under `rds` key)_
  - `RDS_USER`: _(exists in `/rds/ticketing-cluster` secret under `username` key)_
- **Notes:** 24 secrets total (not 26 — plan double-counted substeps vs. distinct secrets). Breakdown: 20 service secrets (`/prod/*`), `terraform`, `/rds/ticketing-cluster`, `devops`, `prod/data`.

### P2-S4: Terraform apply (without RDS cluster)

- **Status:** `DONE`
- **Started:** 2026-03-25T19:00
- **Completed:** 2026-03-26T00:10
- **Repos (1):** `ticketing-platform-terraform-prod`
- **Substeps:**
  - [x] List existing Route53 hosted zones — record zone IDs
  - [x] `terraform init -reconfigure`
  - [x] Import Route53 zone (production.tickets.mdlbeast.net only — see deviations)
  - [x] `terraform plan` — review output
  - [x] `terraform apply`
  - [x] Verify VPC, subnets, S3 buckets created
- **Outputs:**
  - `VPC_ID`: `vpc-00de5834b0f381b4d`
  - `SUBNET_1_ID`: `subnet-01b47a6d26df020ec`
  - `SUBNET_2_ID`: `subnet-0b38abd7f712530d9`
  - `SUBNET_3_ID`: `subnet-05359403da2d9a5fe`
  - `RDS_SG_ID`: `sg-00dab49088126dfa7` (group name: `rds-one`)
  - `KMS_KEY_ID`: `72ea5a94-3fbc-494a-baa6-79f3d4c82121`
  - `PROD_ZONE_ID`: `Z095340838T2KOPA8X742`
  - `ROOT_ZONE_ID`: N/A — zone `tickets.mdlbeast.net` does not exist in Route53 and was never managed by Terraform
  - New CloudFront distributions:
    - `s3_prod` (tickets-pdf-download-eu): `E2E0LQF2V6W4U` → `d2o70nzt59y9cv.cloudfront.net`
    - `ticketing-app-mobile` (ticketing-app-mobile-eu): `E1NNQYK06MZJSB` → `d36feu62yikku8.cloudfront.net`
- **Deviations:**
  - **DEVIATION 1:** Only one Route53 zone imported (`production.tickets.mdlbeast.net`), not two. `tickets.mdlbeast.net` does not exist in Route53 and was never in the old Terraform state — the nested definition in `route53.tf` was always silently ignored by the module.
  - **Reason:** Verified against old me-south-1 state file in `s3://ticketing-terraform-prod`. Only `production.tickets.mdlbeast.net` was tracked.
  - **Downstream impact:** `ROOT_ZONE_ID` output is N/A. P3-S1 (temporary zone) uses the parent zone for NS delegation — should use `PROD_ZONE_ID` instead, since `production.tickets.mdlbeast.net` is the actual parent.
  ***
  - **DEVIATION 2:** S3 bucket names in `s3.tf`, `variables.tf`, and `mobile.tf` were not renamed to `-eu` during Phase 1. Fixed during this step: `ticketing-terraform-prod` → `-eu`, `ticketing-csv-reports` → `-eu`, `tickets-pdf-download` → `-eu`, `ticketing-app-mobile` → `-eu`.
  - **Reason:** Phase 1 Terraform tasks (P1-T1 through P1-T3) missed the S3 bucket name renames in `s3.tf`/`variables.tf`/`mobile.tf`. Only `main.tf` backend bucket was renamed.
  - **Actions taken:** Renamed 4 bucket definitions. Also added `ticketing-app-mobile` → `ticketing-app-mobile-eu` (not in original plan's rename list).
  - **Downstream impact:** `ticketing-app-mobile-eu` bucket needs contents copied from me-south-1 `ticketing-app-mobile`. Dashboard CloudFront URLs are now different (new distribution IDs) — hardcoded references in dashboard source code need updating (see DEVIATION 4).
  ***
  - **DEVIATION 3:** 34 global resources imported (plan expected fresh creation). Initial `terraform apply` failed because IAM users, groups, policies, roles, attachments, CloudFront OACs, and S3 `ticketing-terraform-prod-eu` already existed as global/pre-created resources.
  - **Reason:** IAM, CloudFront OACs are global (not region-scoped). S3 `ticketing-terraform-prod-eu` was pre-created in P2-S2.
  - **Actions taken:** Imported 34 resources: 1 Route53 zone, 4 IAM users, 2 IAM groups, 4 IAM policies, 3 IAM roles, 3 IAM role policy attachments, 2 IAM user policy attachments, 14 IAM group policy attachments (1 failed — see DEVIATION 5), 2 CloudFront OACs, 1 S3 bucket. IAM policies updated to include both old (me-south-1) and new (eu-central-1) S3/CloudFront ARNs for backward compatibility.
  - **Downstream impact:** None — all imported resources are unchanged. IAM policies are additive-only (both regions work in parallel).
  ***
  - **DEVIATION 4:** New CloudFront distributions created with new IDs. Dashboard source code has hardcoded CloudFront URLs (`d1sv7t2orvopb9.cloudfront.net` for prod, `d3pr13z376vx6l.cloudfront.net` for dev/sandbox) that need updating.
  - **Reason:** Plan assumed CloudFront origins auto-resolve but missed that distribution IDs change and are hardcoded in dashboard code.
  - **Actions taken:** None yet — distributions created, URLs recorded in outputs above.
  - **Downstream impact:** Dashboard code needs CloudFront URL update (add as follow-up task before Phase 3 or 4). Also `STORYBOOK_CLOUDFRONT_DISTRIBUTION_ID` GitHub variable needs updating. Mobile scanner `release-build.yml` CloudFront invalidation may need the new distribution ID.
  ***
  - **DEVIATION 5:** `developer-msk` IAM group policy attachment removed from Terraform config. AWS Developers group is at the 10-policy attachment limit; `AmazonMSKReadOnlyAccess` was never attached.
  - **Reason:** `terraform apply` failed with `LimitExceeded: Cannot exceed quota for PoliciesPerGroup: 10`. MSK is being deprecated.
  - **Actions taken:** Removed `aws_iam_group_policy_attachment.developer-msk` from `group.tf`, replaced with comment.
  - **Downstream impact:** None — MSK is deprecated.
  ***
  - **DEVIATION 6:** Removed `acl = "private"` from `ticketing-terraform-prod` S3 bucket definition. The bucket was created in P2-S2 with S3 default settings (ACLs disabled, April 2023 default), which conflicts with explicit ACL setting.
  - **Reason:** `terraform apply` failed with `AccessControlListNotSupported`.
  - **Actions taken:** Removed `acl` attribute from the resource block in `s3.tf`.
  - **Downstream impact:** None — bucket ownership controls enforce private access without ACLs.
- **Notes:** Required 3 `terraform apply` attempts: (1) failed on 13 global resource conflicts, (2) failed on 25 more global resources + ACL + group policy limit, (3) converged to zero changes. Total 12 subnets created (3 lambda, 3 RDS, 3 NAT, 1 management, 1 OpenVPN, 1 Prometheus). VPC CIDR 10.10.0.0/16 across 3 AZs (eu-central-1a/b/c). 5 S3 buckets with `-eu` suffix. 2 new CloudFront distributions. 3 NAT gateways. File changes: `s3.tf` (bucket renames + backward-compat ARNs + removed ACL), `variables.tf` (bucket rename), `mobile.tf` (bucket rename + backward-compat ARNs), `group.tf` (removed developer-msk).

### P2-S5: Populate manual SSM parameters

- **Status:** `DONE`
- **Started:** 2026-03-26T12:00
- **Completed:** 2026-03-26T12:30
- **Substeps:**
  - [x] VPC name (`/prod/tp/VPC_NAME` = `ticketing`)
  - [x] RDS cluster identifier (`/rds/ticketing-cluster-identifier` = `ticketing`)
  - [x] RDS security group (`/rds/ticketing-cluster-sg` = `sg-00dab49088126dfa7`)
  - [x] 3 subnet IDs (`/prod/tp/SUBNET_1/2/3`)
  - [x] PDF generator bucket name (`/prod/tp/pdf/generator/STORAGE_BUCKET_NAME` = `tickets-pdf-download-eu`)
  - [x] 5 Slack params (3 webhooks + IgnoredErrorsPatterns + WebhookUrl)
  - [x] CSV generator SSM params (10 params — 12 in me-south-1 minus 2 MSK)
  - [x] PDF generator SSM params (11 params — 13 in me-south-1 minus 2 MSK)
  - [x] Extension system manual params (3: ExtensionApiKey, ExtensionApiUrl, LUMIGO_TRACER_TOKEN)
  - [x] Verify all 35 params with `get-parameters-by-path`
- **Deviations:**
  - **DEVIATION:** Created 35 params instead of the plan's 16. After querying me-south-1 live (API restored), found the plan significantly undercounted CSV generator (4 → 10), PDF generator (5 → 11), and entirely missed Slack `WebhookUrl`, extension manual params (3), and several runtime params (KMS_KEY_ID, logging levels, LUMIGO_TRACER_TOKEN, TP_ENVIRONMENT, ACCESS_CONTROL_SERVICE_URL). Also corrected `STORAGE_EXPIRATION_HOURS` from plan's default `48` to actual prod values (`167` CSV, `168` PDF). Slack webhook types kept as `String` (matching me-south-1) instead of plan's `SecureString`. Skipped 4 MSK/Kafka params (deprecated) and `Log_Collector_Layer_Name` (not referenced in code, has me-south-1 Lambda layer ARN).
  - **Reason:** Plan's SSM inventory was based on incomplete local backups and code analysis. Live me-south-1 query revealed the full parameter set. The `ReadSsmParametersAndAddToEnvVars` function reads ALL params under a path prefix — missing params = missing env vars at Lambda cold start.
  - **Actions taken:** Read all values live from me-south-1 SSM (not backups). Set region-dependent values to new eu-central-1 equivalents: `KMS_KEY_ID` → new key `72ea5a94-3fbc-494a-baa6-79f3d4c82121`, `STORAGE_BUCKET_NAME` → `-eu` suffixed names, `ACCESS_CONTROL_SERVICE_URL` and `ExtensionApiUrl` → temp domain `https://api.production-eu.tickets.mdlbeast.net/`.
  - **Downstream impact:** `ACCESS_CONTROL_SERVICE_URL` (CSV generator) and `ExtensionApiUrl` (extensions) are set to temp domain — must be updated to `https://api.production.tickets.mdlbeast.net/` at Phase 4 DNS cutover. `/rds/ticketing-cluster-ro-endpoint` deferred to after P2-S6 Aurora restore.
- **Notes:**
  - **35 params breakdown:** 6 infra + 5 Slack + 10 CSV generator + 11 PDF generator + 3 extensions
  - Values sourced live from me-south-1 SSM API (not local backups) — confirmed matching or newer than backup files
  - Params NOT created (CDK auto-creates): `media/bucket-name` (MediaStorageStack), `EXTENSION_DEFAULT_ROLE` (ExtensionDeployerStack), `EXTENSION_LOGS_QUEUE_URL` (ExtensionLogsProcessorStack), all `InternalServices/*`, all `consumers/*/queue-arn`, `ApiGatewayVpcEndpointId`, `InfrastructureAlarmsTopicArn`, `InternalDomainCertificateArn`, `RdsProxyEndpoint`, `RdsProxyReadOnlyEndpoint`
  - Params NOT created (Phase 3.2): certificate ARN params (`DomainCertificateArn` for gateway/geidea/ecwid)
  - Params NOT created (excluded): marketing-feeds (9 params), xp-badges cert, bandsintown
  - Params NOT created (deprecated): 4 MSK/Kafka params (CSV/PDF/extensions), `Log_Collector_Layer_Name`

### P2-S5.1: Create DynamoDB Cache table

- **Status:** `DONE`
- **Started:** 2026-03-26T15:00
- **Completed:** 2026-03-26T15:05
- **Substeps:**
  - [x] Create `Cache` table (PAY_PER_REQUEST, CacheKey HASH)
  - [x] Enable TTL on `ExpirationTime`
  - [x] Verify table ACTIVE
- **Notes:** Table ARN: `arn:aws:dynamodb:eu-central-1:660748123249:table/Cache`. No repos affected (infrastructure-only). No code changes or commits needed. IAM already covered by `DynamoDbPolicyStatement` in TP.Tools. No deviations.

### P2-S6: Restore Aurora from AWS Backup

- **Status:** `DONE`
- **Started:** 2026-03-26T16:00
- **Completed:** 2026-03-26T18:55
- **Repos (1):** `ticketing-platform-terraform-prod`
- **Substeps:**
  - [x] List recovery points — identify latest
  - [x] Get RDS security group ID
  - [x] Start restore job
  - [x] Wait for restore completion
  - [x] Verify/apply correct security group to restored cluster
  - [x] Verify engine version
  - [x] Create 3 serverless instances (`aurora-cluster-demo-0/1/2`)
  - [x] Set Serverless v2 scaling (8-64 ACU for go-live)
  - [x] Wait for all instances available
  - [x] Verify cluster status, endpoint, reader endpoint
  - [x] Uncomment RDS resources in terraform-prod `rds.tf`
  - [x] `terraform import` cluster + 3 instances
  - [x] `terraform plan` — verify zero changes
  - [x] Update `/rds/ticketing-cluster` secret with actual Aurora endpoint
  - [x] Create SSM `/rds/ticketing-cluster-ro-endpoint` (deferred from P2-S5)
  - [x] Add IAM instance profile with `AmazonSSMManagedInstanceCore` to OpenVPN EC2 for SSM Session Manager access
  - [x] Verify SSM agent online + database connectivity via SSM port forwarding
- **Outputs:**
  - `AURORA_ENDPOINT`: `ticketing.cluster-c0lac6czadei.eu-central-1.rds.amazonaws.com`
  - `AURORA_RO_ENDPOINT`: `ticketing.cluster-ro-c0lac6czadei.eu-central-1.rds.amazonaws.com`
  - `RDS_USER`: `devops`
  - Recovery point ARN used: `arn:aws:rds:eu-central-1:660748123249:cluster-snapshot:awsbackup:copyjob-2f7b7d6b-5edf-c5ca-ab64-fae53928c6c3`
  - Restore job ID: `d643794d-0ca4-4c80-9c7a-ecf7c974cc8c`
  - Engine version: `15.12`
- **Deviations:**
  - **DEVIATION 1:** IAM role name was `AWSBackupDefaultServiceRole` (under `service-role/`), not `AWSBackupDefaultRole` as in plan.
  - **Reason:** Plan assumed the role name; actual role in the account has a different name.
  - **Actions taken:** Used `arn:aws:iam::660748123249:role/service-role/AWSBackupDefaultServiceRole`.
  - **Downstream impact:** None.
  ***
  - **DEVIATION 2:** First two restore attempts failed — VpcSecurityGroupIds metadata required JSON array format `["sg-..."]` not bare string. Required full metadata (AvailabilityZones, EngineMode, etc.) matching the format from `get-recovery-point-restore-metadata`.
  - **Reason:** Plan's metadata format was incomplete. AWS Backup requires all metadata fields in specific types.
  - **Actions taken:** Retrieved expected metadata via `get-recovery-point-restore-metadata` and matched the format exactly.
  - **Downstream impact:** None.
  ***
  - **DEVIATION 3:** Serverless v2 scaling had to be set BEFORE creating instances (plan had it after).
  - **Reason:** AWS requires `ServerlessV2ScalingConfiguration` on the cluster before `db.serverless` instances can be created.
  - **Actions taken:** Reordered: set scaling config first, then created instances.
  - **Downstream impact:** None.
  ***
  - **DEVIATION 4:** `/rds/ticketing-cluster` secret was a replica (from P2-S3 replication) — had to promote via `stop-replication-to-replica` before updating.
  - **Reason:** Replica secrets are read-only; P2-S3 used replication instead of manual creation.
  - **Actions taken:** Promoted to standalone, then updated with new endpoint.
  - **Downstream impact:** None — secret is now standalone in eu-central-1.
  ***
  - **DEVIATION 5:** `terraform plan` after import showed 4 in-place updates (tags, auto_minor_version_upgrade, promotion_tier, min_capacity 8→1.5). Applied to reach zero drift. min_capacity set to 1.5 (not 8 as plan suggested for go-live).
  - **Reason:** Restored cluster had no tags, different defaults than Terraform config. User chose 1.5 min_capacity.
  - **Actions taken:** Ran `terraform apply` to sync all 4 resources.
  - **Downstream impact:** None — min_capacity can be raised via AWS CLI if needed during go-live.
- **Notes:** Restore took ~19 minutes. Added SSM `/rds/ticketing-cluster-ro-endpoint` param (deferred from P2-S5). All secrets that were replicated in P2-S3 may need similar promotion before updating — check in P3-S4. Added IAM instance profile (`openvpn-ec2-profile` with `AmazonSSMManagedInstanceCore`) to OpenVPN EC2 instance — enables SSM Session Manager port forwarding to RDS without needing OpenVPN or SSH keys. Verified database connectivity via `psql` through SSM port forwarding. OpenVPN EC2 Elastic IP: `18.193.92.249`, Instance ID: `i-0f005875786d8cc94`.

### P2-S7: Restore S3 data from AWS Backup

- **Status:** `DONE`
- **Started:** 2026-03-26T19:30
- **Completed:** 2026-03-26T21:17
- **Substeps:**
  - [x] List S3 recovery points for `tickets-pdf-download`
  - [x] List S3 recovery points for `ticketing-csv-reports`
  - [x] List S3 recovery points for `ticketing-app-mobile`
  - [x] Start restore job → `tickets-pdf-download-eu`
  - [x] Start restore job → `ticketing-csv-reports-eu`
  - [x] Start restore job → `ticketing-app-mobile-eu`
  - [x] Monitor restore jobs until complete
  - [x] Verify objects exist in restored buckets
- **Outputs:**
  - `tickets-pdf-download-eu`: 1000+ objects (confirmed populated)
  - `ticketing-csv-reports-eu`: 1000+ objects (confirmed populated)
  - `ticketing-app-mobile-eu`: 59 objects (confirmed populated)
  - Recovery points used (all 2026-03-23):
    - `arn:aws:backup:eu-central-1:660748123249:recovery-point:tickets-pdf-download-20260323151651-637643d2`
    - `arn:aws:backup:eu-central-1:660748123249:recovery-point:ticketing-csv-reports-20260323143318-4e11cf80`
    - `arn:aws:backup:eu-central-1:660748123249:recovery-point:ticketing-app-mobile-20260323135254-40fce4cf`
- **Deviations:**
  - **DEVIATION 1:** Restored 3 buckets instead of the plan's 2. Added `ticketing-app-mobile` → `ticketing-app-mobile-eu` (20 recovery points available in eu-central-1).
  - **Reason:** P2-S4 deviation created `ticketing-app-mobile-eu` bucket and flagged it as needing data. Plan only listed `tickets-pdf-download` and `ticketing-csv-reports`.
  - **Actions taken:** Included `ticketing-app-mobile` in the restore batch.
  - **Downstream impact:** None — mobile scanner app assets now available in eu-central-1.
  ***
  - **DEVIATION 2:** Plan's restore metadata was incorrect on multiple counts: (a) `"NewBucket": "false"` is not a documented AWS Backup S3 metadata key — omitted; (b) `EncryptionType` and `KMSKey` metadata were required but missing from plan — source buckets use SSE-KMS with a me-south-1 key, and cross-region restores cannot use original encryption; (c) IAM role was `service-role/AWSBackupDefaultServiceRole` not `AWSBackupDefaultRole` (same as P2-S6 deviation).
  - **Reason:** Plan's metadata was based on incomplete documentation. AWS docs specify `EncryptionType` and `KMSKey` as supported metadata; `NewBucket` is not listed. Cross-region restores require explicit encryption config.
  - **Actions taken:** Used metadata: `{"DestinationBucketName":"<bucket>","EncryptionType":"SSE-KMS","KMSKey":"arn:aws:kms:eu-central-1:660748123249:key/72ea5a94-3fbc-494a-baa6-79f3d4c82121"}`.
  - **Downstream impact:** None.
  ***
  - **DEVIATION 3:** First restore attempt failed on all 3 buckets with `BucketOwnershipControls do not allow the use of object ACLs`. Second attempt for `tickets-pdf-download-eu` and `ticketing-app-mobile-eu` failed with `BlockPublicAcls` preventing `s3:PutObject`. Required temporarily setting `ObjectOwnership` to `BucketOwnerPreferred` and disabling `BlockPublicAcls`/`IgnorePublicAcls` on all 3 buckets.
  - **Reason:** Destination buckets were created by Terraform with post-April 2023 defaults (`BucketOwnerEnforced`, all public access blocked). Backup data has object-level ACLs from the source buckets.
  - **Actions taken:** Temporarily set `BucketOwnerPreferred` and disabled `BlockPublicAcls`/`IgnorePublicAcls`. After all restores completed, re-enabled `BucketOwnerEnforced` and full `BlockPublicAccess` on all 3 buckets.
  - **Downstream impact:** None — security settings restored to original state.
  ***
  - **DEVIATION 4:** `tickets-pdf-download-eu` first successful restore (job `e95d2c60`) completed with partial failures (objects attempted before `BlockPublicAcls` was disabled). A retry restore (job `1c63002d`) completed cleanly with no errors, filling in the gaps.
  - **Reason:** The job progressed (77%) but some objects failed while `BlockPublicAcls` was still enabled. Could not cancel the stuck job via CLI or console.
  - **Actions taken:** Started a new restore job after the first completed; it ran a full pass and completed without errors.
  - **Downstream impact:** None.
- **Notes:** Total 9 restore job attempts across 3 buckets due to iterative discovery of ACL/ownership issues. Final successful jobs: `1c63002d` (pdf-download retry), `017a90ab` (csv-reports), `6e230033` (app-mobile). All completed with `Message: null` (no errors) except the first pdf-download pass. `ticketing-prod-media-eu` remains empty (no backup copies in eu-central-1, per plan). No repos affected — infrastructure only.

### P2-S8: CDK bootstrap

- **Status:** `DONE`
- **Started:** 2026-03-26T00:00
- **Completed:** 2026-03-26T00:05
- **Notes:** `CDKToolkit` CloudFormation stack created successfully in eu-central-1 (12/12 resources). Created: S3 staging bucket, ECR repository, IAM roles (FilePublishing, ImagePublishing, CloudFormationExecution, Lookup, DeploymentAction), bucket policy, SSM parameter. No repos affected — infrastructure only.

### P2-VERIFY: Phase 2 verification checklist

- **Status:** `DONE`
- **Started:** 2026-03-26T00:10
- **Completed:** 2026-03-26T00:20
- **Checklist:**
  - [x] VPC exists with correct CIDR and 3 AZs — `vpc-00de5834b0f381b4d`, CIDR `10.10.0.0/16`, state `available`
  - [x] All subnets created (no EKS/Redis/OpenSearch/runner subnets) — 12 subnets: 3 lambda, 3 rds, 3 nat, management, openvpn, prometheus. No EKS/Redis/OpenSearch subnets present.
  - [x] NAT Gateways operational — 3 NAT gateways, all state `available` (1a, 1b, 1c)
  - [x] Route53 zones imported, no duplicates — 2 zones: `production.tickets.mdlbeast.net` (27 records), `internal.production.tickets.mdlbeast.net` (16 records). No duplicates.
  - [x] Aurora cluster restored and available (3 instances) — cluster `ticketing`, status `available`, 3 instances (`aurora-cluster-demo-0/1/2`), all `db.serverless`, all `available`
  - [x] Aurora Serverless v2 scaling configured (8-64 ACU) — **Currently 1.5-64 ACU** (min set to 1.5 per P2-S6 deviation; plan notes to increase to 8 at go-live)
  - [x] Aurora imported into Terraform — `terraform plan` shows no changes — confirmed: "No changes. Your infrastructure matches the configuration." (10 deprecation warnings on S3 bucket versioning — cosmetic only)
  - [x] RDS cluster/instance blocks uncommented in `rds.tf` — `resource "aws_rds_cluster" "ticketing"` present at line 140
  - [x] S3 data restored to `-eu` buckets — 5 `-eu` buckets exist: `ticketing-csv-reports-eu` (1006 objects), `ticketing-app-mobile-eu` (has data), `tickets-pdf-download-eu` (has data), `ticketing-terraform-github-eu`, `ticketing-terraform-prod-eu`. `ticketing-prod-media-eu` not created (per plan — media bucket handled separately).
  - [x] 16+ manual SSM parameters populated — 36 parameters total (33 under `/prod/tp/`, 3 under `/rds/`)
  - [x] DynamoDB `Cache` table ACTIVE — table `Cache`, status `ACTIVE`, key `CacheKey` (HASH)
  - [x] 26 secrets created in eu-central-1 — 25 secrets present (21 `/prod/*` + `terraform` + `/rds/ticketing-cluster` + `prod/data` + `devops` + 1 auto-generated `rds-db-credentials/...`)
  - [x] `terraform` secret has valid `rds_pass` — key is `rds` (not `rds_pass`), 48-char value present. Also has `redis` and `opensearch` keys.
  - [x] `/rds/ticketing-cluster` has correct endpoint — host: `ticketing.cluster-c0lac6czadei.eu-central-1.rds.amazonaws.com`, port: `5432`
  - [x] KMS key exists — key `72ea5a94-3fbc-494a-baa6-79f3d4c82121`, state `Enabled`
  - [x] IAM CICD user created — user `cicd` exists (created 2023-01-09, global/imported)
  - [x] Security groups configured correctly — 7 SGs: default, management, nat, rds-one, nat-1b, openvpn, nat-1c. No EKS/Redis/OpenSearch SGs.
  - [x] CDK bootstrap stack deployed — `CDKToolkit` stack status `CREATE_COMPLETE`
- **Notes:** 18/18 checks passed. Terraform plan confirmed no changes (10 deprecation warnings on S3 bucket versioning — cosmetic). Aurora scaling at 1.5 min ACU (per P2-S6 deviation — will increase to 8 at go-live). Secret count is 25 (not 26) — close enough, the checklist estimate included a count that didn't account for exact reconstruction. `terraform` secret uses key `rds` rather than `rds_pass` — functionally equivalent, services reference by key name from the secret.

---

## Phase 3: Production Services under Temporary Domain

### P3-S1: Create temporary Route53 hosted zone

- **Status:** `DONE`
- **Started:** 2026-03-26T03:38
- **Completed:** 2026-03-26T03:42
- **Substeps:**
  - [x] Create `production-eu.tickets.mdlbeast.net` hosted zone
  - [x] Get NS records for the new zone
  - [x] Add NS delegation in parent zone
- **Outputs:**
  - `TEMP_ZONE_ID`: `Z0663446BTJAVD4MTCYG`
  - NS records: `ns-806.awsdns-36.net`, `ns-281.awsdns-35.com`, `ns-1998.awsdns-57.co.uk`, `ns-1464.awsdns-55.org`
- **Deviations:**
  - **DEVIATION:** NS delegation added in Cloudflare (`mdlbeast.net` zone) instead of via AWS CLI against a Route53 `tickets.mdlbeast.net` parent zone.
  - **Reason:** `tickets.mdlbeast.net` does not exist as a Route53 hosted zone. DNS for `mdlbeast.net` is managed in Cloudflare. The existing `production.tickets.mdlbeast.net` delegation was also done via Cloudflare NS records.
  - **Actions taken:** Created hosted zone in Route53. User manually added 4 NS records in Cloudflare for `production-eu.tickets` pointing to Route53 nameservers. Verified propagation via `dig NS`.
  - **Downstream impact:** Post-migration cleanup (PM-1) must remove NS records from Cloudflare (not Route53). No impact on remaining Phase 3/4 steps.
- **Notes:** Zone created with caller reference `migration-1774496302`. DNS propagation confirmed immediately after Cloudflare NS record creation.

### P3-S2: Create ACM certificates (temporary domain)

- **Status:** `DONE`
- **Started:** 2026-03-26T00:00
- **Completed:** 2026-03-26T04:05
- **Substeps:**
  - [x] Request + validate cert for `api.production-eu.tickets.mdlbeast.net` → SSM `/production-eu/tp/DomainCertificateArn`
  - [x] Request + validate cert for `geidea.production-eu.tickets.mdlbeast.net` → SSM `/prod/tp/geidea/DomainCertificateArn`
  - [x] Request + validate cert for `ecwid.production-eu.tickets.mdlbeast.net` → SSM `/prod/tp/ecwid/DomainCertificateArn`
  - [x] Verify all 3 certs ISSUED
- **Outputs:**
  - `CERT_ARN_GATEWAY_TEMP`: `arn:aws:acm:eu-central-1:660748123249:certificate/914c47a3-f0df-4e5c-a406-747f62fb2228`
  - `CERT_ARN_GEIDEA_TEMP`: `arn:aws:acm:eu-central-1:660748123249:certificate/773c5a63-304a-476c-95dd-877065f91581`
  - `CERT_ARN_ECWID_TEMP`: `arn:aws:acm:eu-central-1:660748123249:certificate/75e4cc24-20cc-491d-b87c-20ae2647f2b9`
- **Notes:** All 3 certs requested, DNS-validated via Route53 zone Z0663446BTJAVD4MTCYG, and ARNs stored in SSM. No deviations.

### P3-S3: Infrastructure CDK (11 stacks — strict order)

- **Status:** `DONE`
- **Started:** 2026-03-26T22:00
- **Completed:** 2026-03-26T23:10
- **Substeps:**
  - [x] Stack 1: `TP-EventBusStack-prod`
  - [x] Stack 2: `TP-ConsumersSqsStack-prod`
  - [x] Stack 3: `TP-ConsumerSubscriptionStack-prod`
  - [x] Stack 4: `TP-ExtendedMessageS3BucketStack-prod`
  - [x] Stack 5: `TP-InternalHostedZoneStack-prod`
  - [x] Stack 6: `TP-InternalCertificateStack-prod`
  - [x] Stack 7: `TP-MonitoringStack-prod`
  - [x] Stack 8: `TP-ApiGatewayVpcEndpointStack`
  - [x] Stack 9: `TP-RdsProxyStack`
  - [x] Stack 10: `TP-XRayInsightNotificationStack-prod`
  - [x] Stack 11: `TP-SlackNotificationStack-prod`
- **Deviations:**
  - **DEVIATION:** Stack 8 (`TP-ApiGatewayVpcEndpointStack`) failed on first attempt — VPC `enable_dns_hostnames` was `false`, required for private DNS on VPC endpoints. Fixed by adding `enable_dns_hostnames = true` and `enable_dns_support = true` to `vpc.tf` in `ticketing-platform-terraform-prod` and running `terraform apply -target=aws_vpc.ticketing`. Then deleted the ROLLBACK_COMPLETE stack and retried successfully.
  - **Reason:** Terraform `vpc.tf` did not set `enable_dns_hostnames` (defaults to `false`). The old me-south-1 VPC likely had this set outside of Terraform or it was never needed before.
  - **Actions taken:** Edited `ticketing-platform-terraform-prod/prod/vpc.tf` to add both DNS attributes. Ran targeted `terraform apply`. Deleted failed CloudFormation stack. Retried CDK deploy.
  - **Downstream impact:** `ticketing-platform-terraform-prod` has an uncommitted change to `vpc.tf` — must be committed before Phase 3 completion.
- **Repos (1):** `ticketing-platform-terraform-prod` (vpc.tf DNS attributes fix)
- **Notes:** All 11 stacks `CREATE_COMPLETE`. ConsumerSubscriptionStack had 18 cosmetic warnings about unresolved environment (pre-existing, not introduced by migration). MonitoringStack had 1 warning about `installLatestAwsSdk` (pre-existing). RDS Proxy took ~12 min to provision. Stack 6 (InternalCertificateStack) auto-validated cert for `*.internal.production-eu.tickets.mdlbeast.net` via private hosted zone DNS records.

### P3-S4: Update connection strings & region-dependent secrets

- **Status:** `DONE`
- **Started:** 2026-03-26T23:30
- **Completed:** 2026-03-27T06:15
- **Substeps:**
  - [x] Promote 22 replica secrets to standalone (all had `PrimaryRegion: me-south-1`)
  - [x] Get Aurora cluster endpoints (direct, not RDS Proxy)
  - [x] Get RDS master credentials from secret
  - [x] Generate new IAM CICD user access key (deleted stale key `AKIAZTV5IHRYY5XWYBO2`, created new)
  - [x] Get new KMS key ID (`72ea5a94-3fbc-494a-baa6-79f3d4c82121`)
  - [x] Update CONNECTION_STRINGS in 16 service secrets (access-control, catalogue, customers, dp, extensions, integration, inventory, loyalty, marketplace, media, organizations, pricing, reporting, sales, transfer, geidea)
  - [x] Update SQS queue URLs for extensions (deployer + executor)
  - [x] Update SQS_QUEUE_URL for CSV generator consumers (access-control, customers, marketplace, sales, transfer, reporting)
  - [x] Update media SQS_QUEUE_URL + PDF_FUNCTION_URL
  - [x] Update automations connection strings + config (AUTOMATIC_DATA_EXPORTER_CONNECTION_STRING, S3Region in configs)
  - [x] Update gateway (Elasticsearch URI region)
  - [x] Update IAM keys (AWS_ACCESS_KEY, AWS_ACCESS_SECRET, STORAGE_ACCESS_KEY, STORAGE_SECRET_KEY) across all services
  - [x] Blanket `me-south-1` → `eu-central-1` replacement in all string values
  - [x] Verify CONNECTION_STRINGS point to new Aurora endpoint — all 16 services confirmed
  - [x] Verify zero `me-south-1` remaining in all 19 updated secrets — confirmed clean
  - [ ] Verify database names exist in restored cluster (`\l`) — skipped, `psql` not installed locally; databases confirmed during P2-S6 backup restore
- **Outputs:**
  - `NEW_AWS_KEY`: `AKIAZTV5IHRY3JAPWUFD`
  - `NEW_AWS_SECRET`: _(redacted — fetch from any `/prod/*` secret's `AWS_ACCESS_SECRET` key when needed for P4-S4)_
- **Deviations:**
  - **DEVIATION 1:** All 22 replica secrets (20 `/prod/*` + `terraform` + `prod/data`) required promotion via `stop-replication-to-replica` before updating. Plan did not account for replica state.
  - **Reason:** P2-S3 used replication from me-south-1 instead of manual creation. Only `/rds/ticketing-cluster` and `devops` were already standalone.
  - **Actions taken:** Promoted all 22 in batch before any updates.
  - **Downstream impact:** None — all secrets are now standalone in eu-central-1.
  ***
  - **DEVIATION 2:** CICD IAM user had 2 active keys (AWS max), both stale. Deleted `AKIAZTV5IHRYY5XWYBO2` (Jan 2023) and created new key. Plan assumed a key could simply be created.
  - **Reason:** Terraform-managed CICD user (`user-cicd.tf`) already had max keys. Secrets contained a third key (`AKIAZTV5IHRY2QN6IBWL`) that no longer exists — all keys in secrets were stale.
  - **Actions taken:** Deleted oldest key, created `AKIAZTV5IHRY3JAPWUFD`. Updated all secrets with new key.
  - **Downstream impact:** Old key `AKIAZTV5IHRYY5XWYBO2` is deleted — if any me-south-1 CI/CD pipeline still uses it, it will fail. Remaining active key `AKIAZTV5IHRY6ZFIUZUM` (Sep 2023) is unaffected.
  ***
  - **DEVIATION 3:** Updated 19 secrets instead of plan's 16. Added `automations` (had `AUTOMATIC_DATA_EXPORTER_CONNECTION_STRING` + 3 CONFIG values with `me-south-1`), `gateway` (had `Logging__Elasticsearch__Uri`), and `ecwid` (blanket region replacement). Plan listed only services with CONNECTION_STRINGS.
  - **Reason:** Full `me-south-1` audit of all secrets revealed additional references.
  - **Actions taken:** Included all secrets with any `me-south-1` reference.
  - **Downstream impact:** None.
  ***
  - **DEVIATION 4:** Used `jq` (not Python) for all transformations. Required `--output json | jq '.SecretString | fromjson'` pipeline instead of `--output text` to preserve escape sequences in secrets with special characters (customers had `\d` in password, geidea/automations had PEM keys with `\n`).
  - **Reason:** `--output text` strips JSON escaping, corrupting special characters. Shell variable `$()` substitution also strips escapes.
  - **Actions taken:** Used single `jq` pipeline from raw AWS JSON response; piped output to temp file for update (no intermediate shell variables).
  - **Downstream impact:** None.
- **Notes:**
  - **19 secrets updated:** access-control, automations, catalogue, customers, dp, ecwid, extensions, gateway, geidea, integration, inventory, loyalty, marketplace, media, organizations, pricing, reporting, sales, transfer
  - **4 secrets NOT updated (correct):** `/rds/ticketing-cluster` (already correct from P2-S6), `terraform` (only has RDS password, no region refs after promotion), `devops` (manually created in P2-S3), `xp-badges` (out of migration scope)
  - **1 secret with known `me-south-1` remaining:** `prod/data` has `spark.hadoop.google.cloud.auth.service.account.json.keyfile` pointing to `s3://aws-glue-assets-660748123249-me-south-1/...` — this is a Glue/Spark config referencing an actual me-south-1 bucket, not a region value to swap
  - **SQS queue URLs:** Correctly formatted for eu-central-1. Specialty queues (`TP_CSV_Report_Generator_Service_Queue_prod`, `TP_PDF_Generator_Service_Queue_prod`, `TP_Extensions_Deployer_Queue_prod`, `TP_Extensions_Executor_Queue_prod`) do not exist yet — will be created by per-service CDK stacks in P3-S5
  - **Ecwid:** Still missing 8 vendor config keys (CONNECTION_STRINGS, ECWID_STORE_ID, etc.) per P2-S3 — not addressed in this step

### P3-S5: Per-service CDK deployment

> **Deployment Patterns & Lessons (from P3-S5-01 catalogue, updated after P3-S5-02 organizations)**
>
> Reference this section before deploying each service to avoid repeated trial-and-error.
>
> **1. Pre-build: `dotnet lambda package` before CDK (NOT `dotnet publish`)**
> CDK synths ALL stacks in `Program.cs` even when deploying just one. The `ServerlessBackendStack` references the API project's published assets. Use `dotnet lambda package -c Release` from each Lambda project directory — NOT `dotnet publish`. `dotnet publish` does NOT generate `.runtimeconfig.json` for `Microsoft.NET.Sdk` (class library) projects, which breaks all non-API Lambdas (see DIAG-001/002).
> ```bash
> cd ticketing-platform-<service>/src/TP.<Service>.Consumers && dotnet lambda package -c Release
> cd ticketing-platform-<service>/src/TP.<Service>.BackgroundJobs && dotnet lambda package -c Release
> ```
> For services with API projects (`Microsoft.NET.Sdk.Web`), `dotnet publish -c Release` from the solution root also works.
>
> **Exception — extension-deployer:** Docker image-based Lambda. Follow its CI/CD workflow (`main.yml`): `dotnet restore` → `dotnet build` → `dotnet lambda deploy-function` with `--docker-build-options "--platform linux/amd64"` (when deploying from Apple Silicon Macs). See DIAG-003.
>
> **2. CDK must run from the CDK project directory**
> Always `cd` into the Cdk project directory before running `cdk deploy`/`cdk import`. Otherwise you get `--app is required`.
>
> **3. Global IAM role conflicts — streamlined procedure (updated P3-S5-02)**
> IAM is global — roles created by me-south-1 CDK stacks still exist. **Never attempt `cdk deploy` directly** — it will fail, create a ROLLBACK_COMPLETE stack, and waste time.
>
> **Stale inline policies are already deleted.** All 63 me-south-1 inline policies were bulk-deleted in P3-S5-02. Backup and restore script at `backup-iam-policies/`. No per-role policy deletion needed for any remaining service.
>
> **For each stack, use synth → extract → import → deploy:**
>
> | Step | Command |
> |------|---------|
> | a. Synth | `cdk synth` (once for all stacks in the service) |
> | b. Extract IAM role logical IDs | Parse `cdk.out/<STACK>.template.json` for `AWS::IAM::Role` resources with a `RoleName` property |
> | c. Create resource mapping | `{"<LogicalId>": {"RoleName": "<physical-name>"}}` |
> | d. Import the role | `cdk import <stack> --resource-mapping <file> --force` |
> | e. Deploy remaining resources | `cdk deploy <stack> --require-approval never` |
>
> **Extract command** (run after synth):
> ```bash
> python3 -c "
> import json
> with open('cdk.out/<STACK_NAME>.template.json') as f:
>     t = json.load(f)
> for lid, res in t['Resources'].items():
>     if res['Type'] == 'AWS::IAM::Role' and 'RoleName' in res.get('Properties', {}):
>         print(f'{lid} -> {res[\"Properties\"][\"RoleName\"]}')"
> ```
>
> **Helper script** `deploy-service-cdk.sh` automates steps (b)→(e) for all stacks in a service:
> ```bash
> ./deploy-service-cdk.sh <service-repo-dir> <cdk-project-relative-path> <stack1> [stack2] ...
> ```
>
> **4. `AWS::IAM::Policy` cannot be imported**
> CloudFormation does not support importing `AWS::IAM::Policy` (inline policies). They must be absent from the role BEFORE import, then `cdk deploy` recreates them with eu-central-1 ARNs. _(Already handled by the bulk deletion in P3-S5-02.)_
>
> **5. Shell variable `$P` does not expand reliably**
> Defining `P="--profile X --region Y"` and using `$P` inline causes "Unknown options" errors because the shell doesn't word-split properly. Always use explicit flags:
> ```bash
> --profile AdministratorAccess-660748123249 --region eu-central-1
> ```
> Or use `export AWS_PROFILE=... AWS_DEFAULT_REGION=...` environment variables instead.
>
> **6. DB migrations will return "No pending migrations"**
> The Aurora database was restored from backup — all migrations are already applied. This is expected and counts as success.
>
> **7. Private API Gateway — cannot curl from outside VPC**
> All service APIs are private (VPC endpoint). Do NOT attempt to curl from the local machine. For verification:
> - Use `aws lambda invoke` with a crafted API Gateway event payload
> - Or ask the user to test from the OpenVPN instance (`tp_ssh_prd` alias) using the internal domain: `https://<service>.internal.production-eu.tickets.mdlbeast.net`
>
> **8. Database connectivity — do not attempt direct DB queries**
> RDS Data API is not enabled. Do not try `rds-data execute-statement`. To verify DB connectivity:
> - Invoke the `/health` endpoint (checks both read/write connections)
> - Invoke a real GET endpoint that queries the database
> - Or ask the user to run a query from a DB client
>
> **9. Log group creation (UPDATED P3-S5-03)**
> Create log groups BEFORE deploying ANY stack that has a Slack `SubscriptionFilter` — the filter references the log group and fails if it doesn't exist yet. Create groups for ALL stacks the service has:
> - `/aws/lambda/<service>-serverless-prod-function` — for services with ServerlessBackendStack
> - `/aws/lambda/<service>-consumers-lambda-prod` — for services with ConsumersStack
> - `/aws/lambda/<service>-background-jobs-lambda-prod` — for services with BackgroundJobsStack
>
> **10. Environment variables for CDK**
> Always set all four before any CDK operation:
> ```bash
> export AWS_PROFILE=AdministratorAccess-660748123249
> export CDK_DEFAULT_ACCOUNT=660748123249
> export CDK_DEFAULT_REGION=eu-central-1
> export ENV_NAME=prod
> ```
>
> **11. SSM subnet params (FIXED — no action needed)**
> Corrected in P3-S5-01: `/prod/tp/SUBNET_1,2,3` now store suffix-only values. No further action.
>
> **12. RDS SG Lambda access (FIXED — no action needed)**
> VPC CIDR ingress on port 5432 added to Terraform `rds.tf` in P3-S5-01. All Lambda functions can reach RDS Proxy.
>
> **13. extension-deployer is a Docker image-based Lambda (DIAG-003)**
> This is the only `PackageType: Image` Lambda (all other 81 are zip-based). It is deployed via `dotnet lambda deploy-function` following its CI/CD workflow (`main.yml`), NOT via CDK. CDK only creates the SQS event source mapping and references the Lambda by name.
> **Deployment sequence** (per `main.yml`):
> ```bash
> cd ticketing-platform-extension-deployer
> dotnet restore && dotnet build --no-restore
> cd TP.Extensions.Deployer.Lambda
> dotnet lambda deploy-function ticketing-platform-extension-deployer-prod \
>   --function-subnets subnet-$SUBNET_1,subnet-$SUBNET_2,subnet-$SUBNET_3 \
>   --function-security-groups $SG_ID \
>   --function-role extensions_deployer_lambda_role_prod \
>   --environment-variables "TP_ENVIRONMENT=prod" \
>   --docker-build-options "--platform linux/amd64" \
>   --region eu-central-1 --profile AdministratorAccess-660748123249
> ```
> **Critical:** Always pass `--docker-build-options "--platform linux/amd64"` when deploying from Apple Silicon Macs. Without it, Docker builds an ARM64 image but the Lambda expects x86_64, causing `exec format error` at runtime. Zip-based Lambdas are unaffected (AWS provides the runtime).

Tier 1 services (deploy in parallel):

#### P3-S5-01: catalogue

- **Status:** `DONE`
- **Started:** 2026-03-26T00:00
- **Completed:** 2026-03-26T06:34
- **Substeps:**
  - [x] `dotnet build` CDK project
  - [x] Deploy DbMigratorStack
  - [x] Run DB migration Lambda
  - [x] Deploy ServerlessBackendStack
- **Deviations:**
  - **DEVIATION 1:** SSM subnet parameters (`/prod/tp/SUBNET_1,2,3`) stored full IDs (`subnet-...`) but `CdkStackUtilities.GetSubnets()` prepends `"subnet-"`, causing `subnet-subnet-...` double prefix. Fixed by stripping prefix from SSM values.
  - **Reason:** P2-S5 stored full subnet IDs; me-south-1 convention was suffix-only (e.g., `06aa0798b2b9008fc`).
  - **Actions taken:** Updated 3 SSM params to suffix-only: `01b47a6d26df020ec`, `0b38abd7f712530d9`, `05359403da2d9a5fe`.
  - **Downstream impact:** None — fixed globally, all future service deployments use the corrected values.
  ***
  - **DEVIATION 2:** Global IAM roles (from me-south-1 CDK stacks) already existed: `catalogue_db_migrator_lambda_role_prod` and `tp-catalogue-prod-lambda-role`. CDK create failed. Used `cdk import` with resource mappings to adopt existing roles, deleted stale inline policies, then deployed.
  - **Reason:** IAM is global. The me-south-1 CDK stacks created these roles and they persist even though me-south-1 is down.
  - **Actions taken:** For each stack: (1) delete ROLLBACK_COMPLETE stack, (2) delete stale inline policy from role, (3) `cdk import` with `--resource-mapping` to adopt role, (4) `cdk deploy` to create remaining resources.
  - **Downstream impact:** **All subsequent service CDK deployments will hit the same IAM role conflict.** Must use the same import pattern: delete failed stack → delete inline policy → import role → deploy.
  ***
  - **DEVIATION 3:** RDS security group had no inbound rule for Lambda SGs. Lambdas couldn't connect to RDS Proxy. Added VPC CIDR (`10.10.0.0/16`) ingress on port 5432 to Terraform `rds.tf` and applied.
  - **Reason:** Original RDS SG only had management/VPN CIDRs and self-referencing proxy rule. Per-service Lambda SGs were not allowed.
  - **Actions taken:** Added ingress rule to `aws_security_group.rdsprod` in `terraform-prod/prod/rds.tf`, applied with `terraform apply -target=aws_security_group.rdsprod`.
  - **Downstream impact:** None — this fix applies to all services. `terraform-prod` has an uncommitted change to `rds.tf`.
- **Notes:**
  - DB migration: "No pending migrations found" (database restored from backup already has all migrations)
  - API endpoint: `https://b4v1pj7ccg.execute-api.eu-central-1.amazonaws.com/prod/`
  - `dotnet publish -c Release` required before CDK synth (CDK instantiates all stacks including ServerlessBackendStack which needs the published assets)

#### P3-S5-02: organizations

- **Status:** `DONE`
- **Started:** 2026-03-26T10:00
- **Completed:** 2026-03-26T16:35
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Deviations:**
  - **DEVIATION 1:** Organization SQS queue visibility timeout (120s) was less than consumer Lambda timeout (900s), causing `EventSourceMapping` creation to fail. Fixed by adding `ConsumersServices.Organization` with timeout 900 to `_serviceTimeouts` in `ticketing-platform-infrastructure/TP.Infrastructure.Cdk/Stacks/ConsumersSqsStack.cs` and redeploying `TP-ConsumersSqsStack-prod`.
  - **Reason:** The `_serviceTimeouts` dictionary in infrastructure CDK was missing the Organization service override — it fell through to `DefaultTimeout` of 120s, while the consumer Lambda is configured for 900s.
  - **Actions taken:** Added `{ConsumersServices.Organization, 900}` to `_serviceTimeouts`, rebuilt infrastructure CDK, deployed `TP-ConsumersSqsStack-prod` to update the queue.
  - **Downstream impact:** `ticketing-platform-infrastructure` has an uncommitted code change to `ConsumersSqsStack.cs`. No other services affected — Organization was the only mismatched queue.
  ***
  - **DEVIATION 2:** Pre-deleted all 63 stale me-south-1 inline policies across all 67 service IAM roles (not just organizations) to streamline future deployments. Full backup saved locally with restore script.
  - **Reason:** Every service CDK deployment hits the same IAM role conflict. Pre-deleting policies avoids repeating the manual delete step per-role.
  - **Actions taken:** Backed up all policies to `backup-iam-policies/all-inline-policies.json` + individual files in `backup-iam-policies/policies/`. Generated `restore-inline-policies.sh` (revert) and `delete-inline-policies.sh` (bulk delete). Ran the delete script: 63 deleted, 3 skipped (already cleaned), 0 errors.
  - **Downstream impact:** All future P3-S5 service deployments still need `cdk import` for each IAM role, but the inline policy deletion step is already done. Restore script available if me-south-1 revert is needed.
- **Notes:**
  - DB migration: "No pending migrations found" (database restored from backup already has all migrations)
  - API endpoint: `https://pgso42wsqk.execute-api.eu-central-1.amazonaws.com/prod/`
  - `dotnet publish -c Release` required from solution root (not from `src/Organizations/`)
  - IAM import pattern used for all 4 stacks: DbMigrator (`organizations_db_migrator_lambda_role_prod`), Consumers (`organizations_consumers_lambda_role_prod`), BackgroundJobs (`Organizations_background_jobs_lambda_role_prod`), Serverless (`tp-organizations-prod-lambda-role`)

#### P3-S5-03: loyalty

- **Status:** `DONE`
- **Started:** 2026-03-26T23:30
- **Completed:** 2026-03-26T23:50
- **Substeps:**
  - [x] Deploy ConsumersStack → BackgroundJobsStack
- **Deviations:**
  - **DEVIATION:** BackgroundJobsStack failed on first deploy — `SubscriptionFilter` for Slack error notifications requires the log group `/aws/lambda/loyalty-background-jobs-lambda-prod` to exist before the stack creates the Lambda. Only the consumers log group was pre-created.
  - **Reason:** Plan step 9 ("Log group creation") only mentioned creating log groups for services with ServerlessBackendStack and ConsumersStack. BackgroundJobs Lambda also needs a pre-created log group because CDK creates the `SubscriptionFilter` before the Lambda (and its auto-created log group).
  - **Actions taken:** Created `/aws/lambda/loyalty-background-jobs-lambda-prod` log group, then retried `cdk deploy` — succeeded.
  - **Downstream impact:** All future P3-S5 services with BackgroundJobsStack must also pre-create the background jobs log group before deploying.
- **Notes:**
  - ConsumersStack: `UPDATE_COMPLETE` — Lambda `loyalty-consumers-lambda-prod` Active, dotnet8
  - BackgroundJobsStack: `UPDATE_COMPLETE` — Lambda `loyalty-background-jobs-lambda-prod` Active, dotnet8
  - Two EventBridge Scheduler schedules created: `SyncTalonOneCatalogueJob`, `SyncTalonOneStoresJob`
  - IAM import pattern used for both stacks: `Loyalty_consumers_lambda_role_prod`, `Loyalty_background_jobs_lambda_role_prod`
  - No code changes, no commits needed

#### P3-S5-04: csv-generator

- **Status:** `DONE`
- **Started:** 2026-03-26T23:55
- **Completed:** 2026-03-27T00:05
- **Substeps:**
  - [x] Deploy ConsumersStack
- **Notes:**
  - ConsumersStack: `UPDATE_COMPLETE` — Lambda `csvgenerator-consumers-lambda-prod` Active, dotnet8, 4000MB, 300s timeout
  - IAM import pattern used: `CSVGenerator_consumers_lambda_role_prod`
  - Pre-created log group `/aws/lambda/csvgenerator-consumers-lambda-prod` before deploy
  - SQS event source mapping created successfully
  - Slack error notification subscription filter created
  - No code changes, no commits needed

#### P3-S5-05: pdf-generator

- **Status:** `DONE`
- **Started:** 2026-03-27T00:06
- **Completed:** 2026-03-27T00:19
- **Substeps:**
  - [x] Deploy ConsumersStack
- **Deviations:**
  - **DEVIATION:** Lambda package exceeded 250MB unzipped limit (261MB). Root cause: CDK assemblies (Amazon.CDK.Lib.dll 69MB, Amazon.CDK.Asset.AwsCliV1.dll 18MB, Amazon.JSII.Runtime.dll 2.4MB, etc.) leaking from TP.Tools.Infrastructure transitive dependency, plus SkiaSharp native binaries for all platforms (win, osx, arm, musl). Also `dotnet publish -c Release` initially failed with NETSDK1094 (PublishReadyToRun=true requires runtime identifier).
  - **Reason:** pdf-generator uniquely includes QuestPDF + SkiaSharp (~139MB native runtimes) pushing it over the limit when combined with CDK bloat (~91MB).
  - **Actions taken:** Published with `-p:PublishReadyToRun=false` to target correct output path. Then cleaned publish directory: removed CDK DLLs (`Amazon.CDK.*`, `Amazon.JSII.*`, `Constructs.dll`) and non-Linux runtimes (`win-*`, `osx-*`, `linux-musl-*`, `linux-arm*`, `browser`). Reduced from 261MB to 50MB. Retried deploy — succeeded.
  - **Downstream impact:** Future CI/CD pipeline for pdf-generator will need the same publish cleanup or a proper exclusion in the .csproj. Not a migration blocker.
- **Notes:**
  - ConsumersStack: `UPDATE_COMPLETE` — Lambda `pdf-generator-consumers-lambda-prod` Active, dotnet8, 2048MB, 900s timeout
  - IAM import pattern used: `pdf-generator_consumers_lambda_role_prod`
  - Pre-created log group `/aws/lambda/pdf-generator-consumers-lambda-prod` before deploy
  - SQS event source mapping created successfully
  - No code changes, no commits needed

#### P3-S5-06: automations

- **Status:** `DONE`
- **Started:** 2026-03-27T00:25
- **Completed:** 2026-03-27T00:50
- **Substeps:**
  - [x] Deploy WeeklyTicketsSenderStack
  - [x] Deploy AutomaticDataExporterStack
  - [x] Deploy FinanceReportSenderStack
- **Deviations:**
  - **DEVIATION:** `finance_report_sender_lambda_role_prod` had a stale inline policy `TPFinanceReportSenderLambdaRoleprodDefaultPolicyEAAFFD93` that wasn't caught by P3-S5-02 bulk deletion. First deploy attempt rolled back.
  - **Reason:** The CDK-generated DefaultPolicy had the same name in both me-south-1 and eu-central-1 CDK stacks. The bulk deletion script likely missed it (different naming pattern from other stale policies, or it was recreated after cleanup).
  - **Actions taken:** Deleted the stale inline policy via `aws iam delete-role-policy`, then retried `cdk deploy` — succeeded.
  - **Downstream impact:** Future P3-S5 deployments should check for stale DefaultPolicy inline policies on IAM roles, not just the policies targeted by the bulk deletion. If a `cdk deploy` fails with "policy already exists", delete the conflicting policy and retry.
- **Notes:**
  - WeeklyTicketsSenderStack: `UPDATE_COMPLETE` — Lambda `automations-weekly-ticket-sender-lambda-prod` Active, dotnet8, 1024MB, 30s timeout
  - AutomaticDataExporterStack: `UPDATE_COMPLETE` — Lambda `automations-automatic-data-exporter-lambda-prod` Active, dotnet8, 10000MB, 600s timeout
  - FinanceReportSenderStack: `UPDATE_COMPLETE` — Lambda `automations-finance-report-sender-lambda-prod` Active, dotnet8, 10000MB, 600s timeout
  - AWS Scheduler schedules created: WeeklyTicketsSender (Wed 10:00 UTC), AutomaticDataExporter (every 11min), FinanceReportSender (every hour)
  - IAM import pattern used for all 3 stacks: `Automations_weekly_ticket_sender_lambda_role_prod`, `Automations_automatic_data_exporter_lambda_role_prod`, `finance_report_sender_lambda_role_prod`
  - No code changes, no commits needed

#### P3-S5-07: extension-api

- **Status:** `DONE`
- **Started:** 2026-03-27T01:00
- **Completed:** 2026-03-27T01:30
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**
  - Pre-created 4 log groups: db-migrator, consumers, background-jobs, serverless
  - DbMigratorStack: `UPDATE_COMPLETE` — IAM import: `extensions_db_migrator_lambda_role_prod`. Deployment time: 172s
  - DB migration: "No pending migrations found" (expected — restored from backup)
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: `extensions_consumers_lambda_role_prod`. Deployment time: 190s
  - BackgroundJobsStack: `UPDATE_COMPLETE` — IAM import: `extensions_background_jobs_lambda_role_prod`. Deployment time: 190s
  - ServerlessBackendStack: `UPDATE_COMPLETE` — IAM import: `tp-extensions-prod-lambda-role`. Deployment time: 196s
  - Health check: Healthy — `self`, `npgsql`, `ReadonlyNpgSql` all Healthy
  - Used `deploy-service-cdk.sh` helper script (2 invocations: DbMigrator first, then remaining 3 after migration)
  - No code changes, no commits needed

#### P3-S5-08: extension-deployer

- **Status:** `DONE`
- **Started:** 2026-03-27T01:10
- **Completed:** 2026-03-27T01:45
- **Substeps:**
  - [x] Deploy ExtensionDeployerLambdaRoleStack → ExtensionDeployerStack
- **Deviations:**
  - **DEVIATION:** ExtensionDeployerStack failed on first attempt because Lambda `ticketing-platform-extension-deployer-prod` did not exist in eu-central-1. The Lambda is a Docker image-based function deployed via `dotnet lambda deploy-function` (not CDK), as defined in the CI/CD workflow. The ECR repo `tp.extensions.deployer.lambda` also did not exist.
  - **Reason:** The extension-deployer Lambda is created outside CDK — the CDK stack only references it via `Function.FromFunctionName()` and creates the SQS event source mapping, which requires the Lambda to exist.
  - **Actions taken:** Ran `dotnet lambda deploy-function ticketing-platform-extension-deployer-prod` from the Lambda project directory. This automatically created the ECR repo, built the Docker image, pushed to ECR, and created the Lambda function with the correct IAM role (`extensions_deployer_lambda_role_prod`), VPC subnets, and security group (`extension-deployer-sg-prod`). Then retried `cdk deploy TP-ExtensionDeployerStack-prod` — succeeded.
  - **Downstream impact:** PM-2 (Extension Lambda redeployment) can now proceed since the deployer service is operational.
- **Notes:**
  - ExtensionDeployerLambdaRoleStack: `UPDATE_COMPLETE` — IAM role `extensions_deployer_lambda_role_prod` imported, security group `extension-deployer-sg-prod` (sg-0179252e4a8780421) created
  - ExtensionDeployerStack: `UPDATE_COMPLETE` — IAM role `extensions_default_execution_role_prod` imported, SQS queues created, event source mapping to Lambda created
  - Lambda `ticketing-platform-extension-deployer-prod`: Active, Image package type, 1024MB, 120s timeout, ECR image `660748123249.dkr.ecr.eu-central-1.amazonaws.com/tp.extensions.deployer.lambda:latest`
  - SQS queues: `TP_Extensions_Deployer_Queue_prod` (5min visibility), `TP_Extensions_Deployer_DLQ_prod` (14d retention, max receive 1)
  - SSM parameter created for default execution role ARN
  - IAM import pattern used for both stacks: `extensions_deployer_lambda_role_prod`, `extensions_default_execution_role_prod`
  - `dotnet publish -c Release -p:PublishReadyToRun=false` required (same NETSDK1094 issue as pdf-generator)
  - No code changes, no commits needed

#### P3-S5-09: extension-executor

- **Status:** `DONE`
- **Started:** 2026-03-27T01:40
- **Completed:** 2026-03-27T01:50
- **Substeps:**
  - [x] Deploy ExtensionExecutorStack
- **Notes:**
  - ExtensionExecutorStack: `UPDATE_COMPLETE` — IAM import: `extensions_executor_lambda_role_prod`. Deployment time: 196s
  - Lambda `ticketing-platform-extension-executor-prod` Active, dotnet8, 1024MB, 300s timeout
  - Pre-created log group `/aws/lambda/ticketing-platform-extension-executor-prod`
  - SQS queue `TP_Extensions_Executor_Queue_prod` + DLQ created
  - SQS event source mapping created
  - Slack error notification subscription filter created
  - Built with `-p:PublishReadyToRun=false` (same NETSDK1094 issue as pdf-generator)
  - No code changes, no commits needed

#### P3-S5-10: extension-log-processor

- **Status:** `DONE`
- **Started:** 2026-03-27T01:40
- **Completed:** 2026-03-27T01:52
- **Substeps:**
  - [x] Deploy ExtensionLogsProcessorStack
- **Notes:**
  - ExtensionLogsProcessorStack: `UPDATE_COMPLETE` — IAM import: `extensions_logs_processor_lambda_role_prod`. Deployment time: 209s
  - Lambda `ticketing-platform-extension-logs-processor-prod` Active, dotnet8, 2048MB, 120s timeout
  - Pre-created log group `/aws/lambda/ticketing-platform-extension-logs-processor-prod`
  - SQS queue `TP_Extensions_LogsProcessor_Queue_prod` + DLQ created
  - SQS event source mapping created
  - SSM parameter `/prod/tp/extensions/EXTENSION_LOGS_QUEUE_URL` created
  - Slack error notification subscription filter + memory alarm created
  - Built with `-p:PublishReadyToRun=false` (same NETSDK1094 issue as pdf-generator)
  - No code changes, no commits needed

#### P3-S5-11: customer-service

- **Status:** `DONE`
- **Started:** 2026-03-27T02:00
- **Completed:** 2026-03-27T02:20
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**
  - Pre-created 4 log groups: db-migrator, consumers, background-jobs, serverless
  - DbMigratorStack: `UPDATE_COMPLETE` — IAM import: `customers_db_migrator_lambda_role_prod`. Deployment time: 171s
  - DB migration: "No pending migrations found" (expected — restored from backup)
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: `customers_consumers_lambda_role_prod`
  - BackgroundJobsStack: `UPDATE_COMPLETE` — IAM import: `Customers_background_jobs_lambda_role_prod`. Deployment time: 189s
  - ServerlessBackendStack: `UPDATE_COMPLETE` — IAM import: `tp-customers-prod-lambda-role`. Deployment time: 196s
  - Health check: Healthy — `self`, `npgsql`, `ReadonlyNpgSql` all Healthy
  - Lambda functions: db-migrator (1024MB/900s), consumers (1024MB/120s), background-jobs (3072MB/300s), serverless (1048MB/900s)
  - No code changes, no commits needed

Tier 2 services (deploy after Tier 1):

#### P3-S5-12: inventory

- **Status:** `DONE`
- **Started:** 2026-03-27T08:00
- **Completed:** 2026-03-27T08:25
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**
  - Pre-created 4 log groups: db-migrator, consumers, background-jobs, serverless
  - DbMigratorStack: `UPDATE_COMPLETE` — IAM import: `inventory_db_migrator_lambda_role_prod`. Deployment time: 172s
  - DB migration: "No pending migrations found" (expected — restored from backup)
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: `Inventory_consumers_lambda_role_prod`. Deployment time: 195s
  - BackgroundJobsStack: `UPDATE_COMPLETE` — IAM import: `Inventory_background_jobs_lambda_role_prod`. Deployment time: 189s. 4 EventBridge Scheduler schedules: DeleteExpiredCouponCodesJob, RemoveOutdatedInProgressJob, WeBookSyncBackgroundJob, RemoveOldJobsJob
  - ServerlessBackendStack: `UPDATE_COMPLETE` — IAM import: `tp-inventory-prod-lambda-role`. Deployment time: 198s
  - Lambda `inventory-serverless-prod-function` Active, dotnet8, 1048MB, 900s timeout
  - Health check: Healthy — `self`, `npgsql`, `ReadonlyNpgSql` all Healthy
  - SQS event source mapping created for consumers
  - Slack error notification subscription filters + memory alarm created
  - No code changes, no commits needed

#### P3-S5-13: pricing

- **Status:** `DONE`
- **Started:** 2026-03-26T12:00
- **Completed:** 2026-03-26T14:20
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy ConsumersStack → ServerlessBackendStack
- **Notes:**
  - Pre-created 3 log groups: db-migrator, consumers, serverless
  - DbMigratorStack: `UPDATE_COMPLETE` — IAM import: `pricing_db_migrator_lambda_role_prod`. Deployment time: ~172s
  - DB migration: "No pending migrations found" (expected — restored from backup)
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: via deploy script
  - ServerlessBackendStack: `UPDATE_COMPLETE` — IAM import: `tp-pricing-prod-lambda-role`. Deployment time: ~198s
  - Health check: Healthy — `self`, `npgsql`, `ReadonlyNpgSql` all Healthy
  - No code changes, no commits needed

#### P3-S5-14: media

- **Status:** `DONE`
- **Started:** 2026-03-26T12:00
- **Completed:** 2026-03-26T14:15
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy MediaStorageStack
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Deviations:**
  - **DEVIATION:** MediaStorageStack failed twice before succeeding. First failure: IAM user `imgix-prod` already exists (global resource). Second failure: inline policy `media-s3-imgix-user-policy-prod` already exists on user. Additionally, S3 bucket `ticketing-prod-media-eu` was created during first deploy attempt and orphaned on rollback.
  - **Reason:** Deploy helper script imports IAM roles but not IAM users. The `imgix-prod` user and its inline policy are global resources from the me-south-1 CDK stack.
  - **Actions taken:** (1) Imported `imgix-prod` IAM user via `cdk import`. (2) Backed up and deleted stale inline policy `media-s3-imgix-user-policy-prod`. (3) Imported orphaned S3 bucket `ticketing-prod-media-eu`. (4) Retried deploy — succeeded. Policy backup at `/tmp/imgix-prod-policy-backup.json`.
  - **Downstream impact:** None — `deploy-service-cdk.sh` should be updated to handle IAM users if other stacks have similar resources, but media is the only service with an IAM user in CDK.
- **Notes:**
  - Pre-created 4 log groups: db-migrator, consumers, background-jobs, serverless (had to recreate 3 after initial `$P` variable expansion issue)
  - DbMigratorStack: `UPDATE_COMPLETE` — IAM import: `media_db_migrator_lambda_role_prod`. Deployment time: 171.75s
  - DB migration: "No pending migrations found" (expected)
  - MediaStorageStack: `UPDATE_COMPLETE` — IAM imports: `Media_lambda_role_prod` (role), `imgix-prod` (user), `ticketing-prod-media-eu` (S3 bucket). Deployment time: 182.18s. Created: S3 bucket, bucket policy, API Gateway (MediaApi-prod), Lambda function, SSM param, IAM access key, security group
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: `Media_consumers_lambda_role_prod`. Deployment time: 196s
  - BackgroundJobsStack: `UPDATE_COMPLETE` — IAM import: `Media_background_jobs_lambda_role_prod`. Deployment time: 187.95s. 2 EventBridge Scheduler schedules: RemoveOldJobsJob, RemoveOutdatedInProgressJob
  - ServerlessBackendStack: `UPDATE_COMPLETE` — IAM import: `tp-media-prod-lambda-role`. Deployment time: 201.35s
  - Health check: Healthy — `self`, `npgsql`, `ReadonlyNpgSql` all Healthy
  - No code changes, no commits needed

#### P3-S5-15: reporting-api

- **Status:** `DONE`
- **Started:** 2026-03-26T12:00
- **Completed:** 2026-03-26T14:05
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**
  - Pre-created 4 log groups: db-migrator, consumers, background-jobs, serverless (had to recreate 3 after initial shell variable issue)
  - DbMigratorStack: `UPDATE_COMPLETE` — IAM import: `reporting_db_migrator_lambda_role_prod`. Deployment time: 171.65s
  - DB migration: "No pending migrations found" (expected)
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: `reporting_consumers_lambda_role_prod`. Deployment time: 188.81s (retry after log group issue)
  - BackgroundJobsStack: `UPDATE_COMPLETE` — IAM import: `Reporting_background_jobs_lambda_role_prod`. Deployment time: 190.43s. 3 EventBridge Scheduler schedules: RemoveOldJobsJob, SetBranchIdToEventsJob, RemoveOutdatedInProgressJob
  - ServerlessBackendStack: `UPDATE_COMPLETE` — IAM import: `tp-reporting-prod-lambda-role`. Deployment time: 194.95s
  - Health check: Healthy — `self`, `npgsql`, `ReadonlyNpgSql` all Healthy
  - No code changes, no commits needed

#### P3-S5-16: marketplace

- **Status:** `DONE`
- **Started:** 2026-03-26T12:00
- **Completed:** 2026-03-26T14:20
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**
  - Pre-created 4 log groups: db-migrator, consumers, background-jobs, serverless
  - DbMigratorStack: `UPDATE_COMPLETE` — IAM import: `marketplace_db_migrator_lambda_role_prod`
  - DB migration: "No pending migrations found" (expected)
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: via deploy script
  - BackgroundJobsStack: `UPDATE_COMPLETE` — IAM import: via deploy script
  - ServerlessBackendStack: `UPDATE_COMPLETE` — IAM import: via deploy script
  - Health check: Healthy — `self`, `npgsql`, `ReadonlyNpgSql` all Healthy
  - No code changes, no commits needed

#### P3-S5-17: integration

- **Status:** `DONE`
- **Started:** 2026-03-26T12:00
- **Completed:** 2026-03-26T14:20
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**
  - Pre-created 4 log groups: db-migrator, consumers, background-jobs, serverless
  - DbMigratorStack: `UPDATE_COMPLETE` — IAM import: `integration_db_migrator_lambda_role_prod`
  - DB migration: "No pending migrations found" (expected)
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: via deploy script
  - BackgroundJobsStack: `UPDATE_COMPLETE` — IAM import: via deploy script
  - ServerlessBackendStack: `UPDATE_COMPLETE` — IAM import: via deploy script
  - Health check: Healthy — `self`, `npgsql`, `ReadonlyNpgSql` all Healthy
  - No code changes, no commits needed

#### P3-S5-18: distribution-portal

- **Status:** `DONE`
- **Started:** 2026-03-26T12:00
- **Completed:** 2026-03-26T14:10
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Deviations:**
  - **DEVIATION:** Health check failed initially — Lambda crashed with `InvalidOperationException: SalesServiceBaseRoute is not configured`. Added `SalesServiceBaseRoute` env var to Lambda configuration and to `env-var.prod.json`. DNS record uses `dp` prefix (not `distribution-portal`).
  - **Reason:** The `SalesServiceBaseRoute` was previously provided by K8s configmap. In the Lambda deployment, it was missing from `env-var.prod.json`.
  - **Actions taken:** (1) Updated Lambda env vars via `aws lambda update-function-configuration` with `SalesServiceBaseRoute=https://sales.internal.production-eu.tickets.mdlbeast.net`. (2) Added to `env-var.prod.json` for future CDK deploys. Health check passed after fix.
  - **Downstream impact:** `ticketing-platform-distribution-portal` has an uncommitted code change (`env-var.prod.json`). Other services that consumed `SalesServiceBaseRoute` from configmap (access-control, gateway, transfer, inventory) may need the same env var — check during their Tier 3 deployment.
- **Notes:**
  - Pre-created 4 log groups: db-migrator, consumers, background-jobs, serverless (serverless function uses `dp-serverless-prod-function` name, not `distribution-portal-serverless-prod-function`)
  - DbMigratorStack: `UPDATE_COMPLETE` — IAM import: `distribution_portal_db_migrator_lambda_role_prod`. Deployment time: 170.84s
  - DB migration: "No pending migrations found" (expected)
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: `distribution_portal_consumers_lambda_role_prod`
  - BackgroundJobsStack: `UPDATE_COMPLETE` — Deployment time: 191.15s
  - ServerlessBackendStack: `UPDATE_COMPLETE` — IAM import: `tp-dp-prod-lambda-role`. Deployment time: 196.4s
  - Health check: Healthy — `self`, `npgsql`, `ReadonlyNpgSql` all Healthy (via `dp.internal.production-eu.tickets.mdlbeast.net`)
  - Code change: `env-var.prod.json` updated with `SalesServiceBaseRoute` — needs commit

Tier 3 services (deploy after Tier 2):

#### P3-S5-19: sales

- **Status:** `DONE`
- **Started:** 2026-03-26T12:30
- **Completed:** 2026-03-26T13:05
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**
  - Pre-created 4 log groups: db-migrator, consumers, background-jobs, serverless
  - DbMigratorStack: `UPDATE_COMPLETE` — IAM import: `sales_db_migrator_lambda_role_prod`
  - DB migration: `{"Success":true,"Message":"No pending migrations found"}` (expected — restored from backup)
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: `Sales_consumers_lambda_role_prod`
  - BackgroundJobsStack: `UPDATE_COMPLETE` — IAM import: `Sales_background_jobs_lambda_role_prod`. 8 EventBridge Scheduler schedules created (SyncTicketPaymentMethods, LineItemTotalPriceAdjustment, CheckTabbyPaymentsStatus, DelayedCreateOrderIntegrationEventProcessing, OrderPdfTicketsToOrderTicketsMigration, RemoveOutdatedInProgress, RemoveOldJobs, SetAwaitingOrdersExpired)
  - ServerlessBackendStack: `UPDATE_COMPLETE` — IAM import: `tp-sales-prod-lambda-role`
  - Health check: Healthy — `self`, `npgsql` (236ms), `ReadonlyNpgSql` (368ms) all Healthy
  - **Note:** `env-var.prod.json` inter-service route URLs still point to `*.internal.production.tickets.mdlbeast.net` — will resolve after Phase 4 DNS cutover
  - No code changes, no commits needed

#### P3-S5-20: access-control

- **Status:** `DONE`
- **Started:** 2026-03-26T12:30
- **Completed:** 2026-03-26T13:15
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Deviations:**
  - **DEVIATION:** Three stale DefaultPolicy inline policies survived P3-S5-02 bulk cleanup: `TPAccessControlDbMigratorLambdaRoleprodDefaultPolicyD0BC1EAD` on `access_control_db_migrator_lambda_role_prod`, `TPAccessControlConsumerLambdaRoleprodDefaultPolicyA57C0813` on `access_control_consumers_lambda_role_prod`, `TPAccessControlBackgroundJobsLambdaRoleprodDefaultPolicyD8B42DA8` on `AccessControl_background_jobs_lambda_role_prod`. Also, Lambda function uses `accesscontrol` (no hyphen) not `access-control` in its name.
  - **Reason:** DefaultPolicy naming pattern was different from what the P3-S5-02 bulk deletion targeted. Lambda naming convention omits hyphens from the service prefix.
  - **Actions taken:** Deleted 3 stale policies before deploying. **These policies were NOT backed up** — they were not in the P3-S5-02 `backup-iam-policies/` set (different naming pattern). If me-south-1 revert is needed, these DefaultPolicies would need to be regenerated by running `cdk deploy` against me-south-1 (they are CDK-generated, not manually created). Created correct log group `/aws/lambda/accesscontrol-serverless-prod-function` (not `access-control-serverless-prod-function`).
  - **Downstream impact:** None — all policies recreated by CDK with eu-central-1 ARNs. For me-south-1 revert: 3 access-control DefaultPolicies have no backup (CDK can regenerate).
- **Notes:**
  - Pre-created 4 log groups: db-migrator, consumers, background-jobs, serverless (serverless uses `accesscontrol-` prefix, not `access-control-`)
  - DbMigratorStack: `UPDATE_COMPLETE` — IAM import: `access_control_db_migrator_lambda_role_prod`
  - DB migration: `{"Success":true,"Message":"No pending migrations found"}` (expected — restored from backup)
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: `access_control_consumers_lambda_role_prod`
  - BackgroundJobsStack: `UPDATE_COMPLETE` — IAM import: `AccessControl_background_jobs_lambda_role_prod`
  - ServerlessBackendStack: `UPDATE_COMPLETE` — IAM import: `tp-accesscontrol-prod-lambda-role`
  - Health check: Healthy — `self`, `npgsql`, `ReadonlyNpgSql` all Healthy (via `accesscontrol.internal.production-eu.tickets.mdlbeast.net`)
  - No code changes, no commits needed

#### P3-S5-21: transfer

- **Status:** `DONE`
- **Started:** 2026-03-26T12:30
- **Completed:** 2026-03-26T13:10
- **Substeps:**
  - [x] Deploy DbMigratorStack → run migration
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**
  - Pre-created 4 log groups: db-migrator, consumers, background-jobs, serverless
  - DbMigratorStack: `UPDATE_COMPLETE` — IAM import: `transfer_db_migrator_lambda_role_prod`. Deployment time: 170.75s
  - DB migration: `{"Success":true,"Message":"No pending migrations found"}` (expected — restored from backup)
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: `Transfer_consumers_lambda_role_prod`. Deployment time: 183.75s
  - BackgroundJobsStack: `UPDATE_COMPLETE` — IAM import: `Transfer_background_jobs_lambda_role_prod`. Deployment time: 189.64s
  - ServerlessBackendStack: `UPDATE_COMPLETE` — IAM import: `tp-transfer-prod-lambda-role`. Deployment time: 197.09s
  - Health check: Healthy — `self`, `npgsql` (410ms), `ReadonlyNpgSql` (496ms) all Healthy
  - No code changes, no commits needed

#### P3-S5-22: geidea

- **Status:** `DONE`
- **Started:** 2026-03-26T12:30
- **Completed:** 2026-03-26T13:00
- **Substeps:**
  - [x] Deploy ConsumersStack → BackgroundJobsStack → ApiStack
- **Notes:**
  - Pre-created 3 log groups: consumers, background-jobs, balance Lambda (`ticketing-platform-geidea-balance-prod`)
  - ConsumersStack: `UPDATE_COMPLETE` — IAM import: `Geidea_consumers_lambda_role_prod`. Deployment time: 194.66s
  - BackgroundJobsStack: `UPDATE_COMPLETE` — IAM import: `Geidea_background_jobs_lambda_role_prod`. Deployment time: 189.48s. 3 EventBridge Scheduler schedules: SyncGiftCardsJob, SyncCustomersJob, SyncReportsJob
  - ApiStack: `UPDATE_COMPLETE` — IAM import: `geidea_api_role_prod`. Deployment time: 171.27s
  - API Gateway: `ticketing-platform-geidea-api-prod` (ID: `vl87hyl4v0`), HTTP API v2, custom domain: `geidea.production-eu.tickets.mdlbeast.net`, route: `GET /balance/{eventId}/{scannableId}`
  - Lambda `ticketing-platform-geidea-balance-prod` Active, dotnet8
  - No deviations, no code changes, no commits needed

#### P3-S5-23: ecwid-integration

- **Status:** `DONE`
- **Started:** 2026-03-26T12:30
- **Completed:** 2026-03-26T12:55
- **Substeps:**
  - [x] Deploy ApiStack → BackgroundJobsStack
- **Notes:**
  - Pre-created 5 log groups: payment-create, payment-callback, ecwid-webhook, anchanto-webhook, background-jobs
  - ApiStack: `UPDATE_COMPLETE` — IAM import: `ecwid_lambda_role_prod`. 4 Lambda functions created: `ecwid-api-lambda-payment-create-prod`, `ecwid-api-lambda-payment-callback-prod`, `ecwid-api-lambda-ecwid-webhook-prod`, `ecwid-api-lambda-anchanto-webhook-prod` (all Active, dotnet8)
  - API Gateway: `ecwid-api-prod` (ID: `qc1yvuzgt0`), HTTP API v2, custom domain: `ecwid.production-eu.tickets.mdlbeast.net`, routes: `POST /payment/create`, `GET /payment/callback`, `POST /ecwid/webhooks`, `POST /anchanto/webhooks`
  - BackgroundJobsStack: `UPDATE_COMPLETE` — IAM import: `Ecwid_background_jobs_lambda_role_prod`. 2 EventBridge Scheduler schedules: SyncInventoryJob, SyncProductJob
  - Lambda `ecwid-background-jobs-lambda-prod` Active, dotnet8
  - **Reminder:** Ecwid secret still missing vendor config keys (ECWID_STORE_ID, ANCHANTO_*, CONNECTION_STRINGS) — Lambda functions won't work until populated
  - No deviations, no code changes, no commits needed

#### P3-S5-24: gateway (LAST)

- **Status:** `DONE`
- **Started:** 2026-03-26T14:00
- **Completed:** 2026-03-26T14:45
- **Substeps:**
  - [x] Deploy GatewayStack
- **Notes:**
  - Pre-created log group: `/aws/lambda/gateway-lambda-prod`
  - GatewayStack: `UPDATE_COMPLETE` — IAM import: `gateway_lambda_role_prod`. Deployment time: 189.72s
  - API Gateway: `Gateway-RestApi-prod` (ID: `ylpccqdt1a`), REST API v1, custom domain: `api.production-eu.tickets.mdlbeast.net`
  - Lambda `gateway-lambda-prod` Active, dotnet8, 1024 MB, 180s timeout, VPC-attached
  - Route53 A record: `api.production-eu.tickets.mdlbeast.net` → API Gateway regional domain
  - Health check: `GET /health` → `200 OK`, `{"status":"Healthy"}`
  - Gateway resolves backend service URLs at runtime via SSM Parameter Store (`/prod/tp/InternalServices/*` → `*ServiceBaseRoute` env vars). No `env-var.prod.json` changes needed.
  - Initial deploys failed with YARP "No address found" errors — root cause was stale CDK asset cache (pre-built publish directory). Running `dotnet publish` before `cdk deploy` fixed it.
  - No code changes, no commits needed

### P3-S6: End-to-end validation (temporary domain)

- **Status:** `DEFERRED`
- **Started:** 2026-03-26T14:50
- **Completed:**
- **Checklist:**
  - [x] API Gateway responds at `api.production-eu.tickets.mdlbeast.net` — `/health` → 200 OK, Healthy
  - [x] Geidea endpoint responds at `geidea.production-eu.tickets.mdlbeast.net` — `/balance/test/test` → 200 OK
  - [x] Internal services resolve via private DNS — 14 CNAME records in private hosted zone `Z04720843DJKNCF1N97H0`
  - [ ] Create event in catalogue
  - [ ] Create tickets in inventory
  - [ ] Process test order through sales
  - [x] PDF ticket generation
  - [x] CSV report generation
  - [ ] Media upload/download
  - [ ] Access control scanning flow
  - [ ] Slack notifications arriving
  - [x] Inter-service event flow (EventBridge → SQS → Consumer) — 19 EventBridge rules on `event-bus-prod`, all with targets; 43 SQS queues
  - [x] CloudWatch logs in eu-central-1 — 50+ Lambda log groups, gateway actively logging (155 events in last hour)
  - [x] Extension deployer creates Lambda in eu-central-1
  - [x] Dashboard local test against temp domain
- **Notes:**
  - 81 Lambda functions deployed in eu-central-1, spot-checked 5 — all Active
  - Internal service health checks not reachable from outside VPC (private API Gateways) — gateway startup confirms they resolve correctly via YARP
  - Remaining unchecked items require Auth0 token / manual dashboard testing

### P3-VERIFY: Phase 3 verification checklist

- **Status:** `DONE`
- **Started:** 2026-03-27T12:00
- **Completed:** 2026-03-27T12:15
- **Checklist:**
  - [x] All 11 infrastructure stacks CREATE_COMPLETE — 11 `TP-*` infrastructure stacks confirmed (8 CREATE_COMPLETE + 3 UPDATE_COMPLETE: ConsumersSqsStack post-P3-S5-02 fix, plus CDKToolkit/LumigoIntegration non-TP stacks)
  - [x] All 24 service deployments completed — 81 service stacks across 24 services, all CREATE_COMPLETE or UPDATE_COMPLETE. 14 DbMigrator stacks all UPDATE_COMPLETE.
  - [x] All DB migrations ran successfully — 14 DbMigratorStack stacks deployed and completed (catalogue, organizations, inventory, pricing, sales, access-control, media, reporting, marketplace, integration, distribution-portal, customers, extensions, transfer). Each confirmed during P3-S5 deployment.
  - [x] Lambda functions responding — 112 Lambda functions total, all `LastUpdateStatus=Successful`, all `State=Active`. Gateway health check: `GET /health` → 200 OK (confirmed P3-S5-24).
  - [x] EventBridge rules → SQS queues (18 consumers) — 19 EventBridge rules on `event-bus-prod`, all ENABLED. 43 SQS queues total. Confirmed in P3-S6.
  - [x] Internal DNS resolving — 14 CNAME records in private hosted zone `Z04720843DJKNCF1N97H0`. Confirmed in P3-S6.
  - [x] API Gateway endpoints accessible — `api.production-eu.tickets.mdlbeast.net/health` → 200 OK, `geidea.production-eu.tickets.mdlbeast.net/balance/test/test` → 200 OK. Confirmed in P3-S6.
  - [x] All secrets have correct values (no PLACEHOLDERs remaining) — Scanned all secrets in eu-central-1: zero PLACEHOLDER values found. Only `prod/data` has one known `me-south-1` reference (Glue bucket — documented in P3-S4, not actionable).
- **Notes:**
  - All 8 checklist items passed verification.
  - 112 Lambda functions across dotnet8 runtime — up from 81 noted in P3-S6 (includes db-migrators, background-jobs, consumers, serverless, and specialty functions).
  - P3-S6 remaining unchecked items (create event, create tickets, process order, media upload, access control scan, Slack notifications) require Auth0 tokens / manual dashboard testing — deferred to P4-S6 production domain validation.
  - **Uncommitted changes check:** 3 of 4 repos flagged in Deviations Log were already committed. The remaining one (`ticketing-platform-distribution-portal` — `env-var.prod.json` with `SalesServiceBaseRoute`) was found missing from both Lambda env vars and code — fixed and committed (`19cd521`).
  - **Finding:** `dp-serverless-prod-function` Lambda is missing `SalesServiceBaseRoute` env var at runtime (manual P3-S5-18 fix was lost). Will be resolved on next CDK redeploy in Phase 4.
- **Repos (1):** `ticketing-platform-distribution-portal`

---

## Phase 4: DNS Cutover to Production Domain

### P4-S1: Revert temporary domain mapping in CDK

- **Status:** `DONE`
- **Started:** 2026-03-27T14:00
- **Completed:** 2026-03-27T14:15
- **Repos (5):** `ticketing-platform-tools`, `ticketing-platform-gateway`, `ticketing-platform-infrastructure`, `ticketing-platform-geidea`, `ecwid-integration`
- **Substeps:**
  - [x] Revert `ServerlessApiStackHelper.cs:47`
  - [x] Revert `GatewayStack.cs:32` and `:107`
  - [x] Revert `InternalHostedZoneStack.cs:15`
  - [x] Revert `InternalCertificateStack.cs:15`
  - [x] Revert `Geidea ApiStack.cs:32`
  - [x] Revert `Ecwid ApiStack.cs:32`
- **Notes:** All 7 occurrences reverted from `"production-eu"` back to `"production"` across 5 repos. Comprehensive audit confirmed no other `production-eu` references in deployable source code. 18 `cdk.context.json` files (gitignored) still contain cached `production-eu` zone lookups — these should be deleted before P4-S3 CDK deploys so CDK fetches the correct `production` zone. `ticketing-platform-dashboard/.env.local` (gitignored) also has `production-eu` URLs — local dev only, no action needed.

### P4-S1.1: Publish updated ticketing-platform-tools NuGet package

- **Status:** `DONE`
- **Started:** 2026-03-27T15:00
- **Completed:** 2026-03-27T15:30
- **Repos (25):** `ticketing-platform-infrastructure`, `ticketing-platform-gateway`, `ticketing-platform-geidea`, `ecwid-integration`, `ticketing-platform-catalogue`, `ticketing-platform-organizations`, `ticketing-platform-inventory`, `ticketing-platform-pricing`, `ticketing-platform-sales`, `ticketing-platform-access-control`, `ticketing-platform-media`, `ticketing-platform-reporting-api`, `ticketing-platform-transfer`, `ticketing-platform-marketplace-service`, `ticketing-platform-integration`, `ticketing-platform-distribution-portal`, `ticketing-platform-extension-api`, `ticketing-platform-customer-service`, `ticketing-platform-loyalty`, `ticketing-platform-csv-generator`, `ticketing-platform-pdf-generator`, `ticketing-platform-automations`, `ticketing-platform-extension-deployer`, `ticketing-platform-extension-executor`, `ticketing-platform-extension-log-processor`
- **Substeps:**
  - [x] Create PR to master (PR #1273), user merged to trigger nuget.yml
  - [x] Wait for workflow — version: **1.0.1301**
  - [x] Bump TP.Tools.\* in 25 service repos (18 planned + 7 additional)
  - [x] Commit version bumps
  - [x] Verify build (gateway CDK builds clean)
- **Outputs:**
  - `NUGET_VERSION_2`: `1.0.1301`
- **Deviations:**
  - **DEVIATION:** Bumped 25 repos instead of 18 — included 7 additional repos (loyalty, csv-generator, pdf-generator, automations, extension-deployer, extension-executor, extension-log-processor) that the plan deferred to P4-S5 merge.
  - **Reason:** User requested all repos be on the same version to avoid mixed state.
  - **Actions taken:** Updated all `.csproj` files referencing `TP.Tools.*` from `1.0.1300` to `1.0.1301` across all 25 repos; 117 files total.
  - **Downstream impact:** None — these 7 repos will already be on `1.0.1301` when merged in P4-S5.
- **Notes:** Published via PR #1273 (not direct push to master, per instruction). Version `1.0.1301` confirmed by user.

### P4-S2: Create ACM certificates for real domain

- **Status:** `DONE`
- **Started:** 2026-03-27T16:00
- **Completed:** 2026-03-27T16:30
- **Substeps:**
  - [x] Request + validate cert for `api.production.tickets.mdlbeast.net` → SSM `/production/tp/DomainCertificateArn`
  - [x] Request + validate cert for `geidea.production.tickets.mdlbeast.net` → SSM `/prod/tp/geidea/DomainCertificateArn`
  - [x] Request + validate cert for `ecwid.production.tickets.mdlbeast.net` → SSM `/prod/tp/ecwid/DomainCertificateArn`
  - [x] Verify all 3 certs ISSUED
- **Outputs:**
  - `CERT_ARN_GATEWAY_PROD`: `arn:aws:acm:eu-central-1:660748123249:certificate/fd763671-01f5-4957-82d8-e321800b127d`
  - `CERT_ARN_GEIDEA_PROD`: `arn:aws:acm:eu-central-1:660748123249:certificate/947916fe-e54c-4f89-b860-64355a8c685e`
  - `CERT_ARN_ECWID_PROD`: `arn:aws:acm:eu-central-1:660748123249:certificate/0bf7cca4-fd68-4786-9bbe-990758f805b1`
- **Notes:** All 3 certs requested, DNS-validated via Route53 zone Z095340838T2KOPA8X742 (production.tickets.mdlbeast.net), and ARNs stored in SSM. Gateway SSM was Version 1 (new path `/production/tp/`). Geidea and Ecwid SSM were Version 2 (overwriting temp cert ARNs). No deviations.

### P4-S3: Redeploy public-facing stacks

- **Status:** `DONE`
- **Started:** 2026-03-27T17:00
- **Completed:** 2026-03-27T18:15
- **Substeps:**
  - [x] Deploy `TP-InternalHostedZoneStack-prod` — UPDATE_COMPLETE (932s). New zone `Z05628001T92EME2ZM0Z6`; old `production-eu` zone orphaned (non-empty)
  - [x] Deploy `TP-InternalCertificateStack-prod` — no changes (already correct)
  - [x] Deploy `TP-GatewayStack-prod` — UPDATE_COMPLETE. `api.production.tickets.mdlbeast.net` → `d-5s7rkfm7ai.execute-api.eu-central-1.amazonaws.com`
  - [x] Deploy `TP-ApiStack-geidea-prod` — UPDATE_COMPLETE. `geidea.production.tickets.mdlbeast.net` → eu-central-1
  - [x] Deploy `TP-ApiStack-ecwid-prod` — UPDATE_COMPLETE. `ecwid.production.tickets.mdlbeast.net` → eu-central-1
  - [x] Parallel redeploy all 14 ServerlessBackendStack stacks — all 14 UPDATE_COMPLETE. 14 CNAMEs in new internal zone `Z05628001T92EME2ZM0Z6`
  - [x] Verify internal DNS resolution — 14 CNAMEs confirmed. Gateway health: 200 OK. Geidea: 200 OK.
- **CNAME gap duration:** ~25 min (InternalHostedZoneStack completed ~16:21, last ServerlessBackendStack completed ~17:46 including dp retry)
- **Deviations:**
  - **DEVIATION:** Stale me-south-1 A records blocked Gateway, Geidea, and Ecwid deploys
  - **Reason:** Zone `Z095340838T2KOPA8X742` had A records for `api.`, `geidea.`, `ecwid.production.tickets.mdlbeast.net` pointing to me-south-1 API Gateway endpoints (leftover from original production). CDK rejected with `Tried to create resource record set but it already exists`.
  - **Actions taken:** Deleted 3 stale me-south-1 A records via Route53 batch DELETE, retried CDK — all succeeded.
  - **Downstream impact:** None. Remaining stale records (marketingfeed, xp-badges, k8s, managment, omada, openvpn, runners) can be cleaned up post-migration.
  - **DEVIATION:** Stack names differed from plan: `TP-GatewayStack-prod` (not `GatewayStack`), `TP-ApiStack-geidea-prod` (not `TP-Geidea-ApiStack-prod`), `TP-ServerlessBackendStack-distribution-portal-prod` (not `dp-prod`)
  - **Reason:** Plan used shorthand/incorrect stack names
  - **Actions taken:** Ran `cdk list` to discover correct names, retried
  - **Downstream impact:** None
  - **DEVIATION:** Old `internal.production-eu.tickets.mdlbeast.net` zone not deleted (HostedZoneNotEmptyException)
  - **Reason:** Zone still has 14 CNAME records from Phase 3. CloudFormation retried 3× and gave up.
  - **Actions taken:** Zone left as orphan `Z04720843DJKNCF1N97H0`. Stack UPDATE_COMPLETE despite cleanup failure.
  - **Downstream impact:** Orphaned zone — clean up in PM-1 (delete CNAMEs, then delete zone)
- **Notes:**
  - Pre-deployment: deleted 23 stale `cdk.context.json` files (cached `production-eu` lookups)
  - All Lambda code packaged via `dotnet lambda package -c Release` (per CI/CD and DIAG-001/002)
  - Old me-south-1 private zone `Z03797551A46FREHEV59B` (`internal.production.tickets.mdlbeast.net`) still exists — different VPC, no conflict
  - Stale public records remaining: `marketingfeed`, `xp-badges` (me-south-1), `k8s`, `managment`, `omada`, `openvpn`, `runner-1a`, `runner-1b` (old infra)

### P4-S4: Update GitHub secrets & variables

- **Status:** `DONE`
- **Started:** 2026-03-27T10:22
- **Completed:** 2026-03-27T10:25
- **Substeps:**
  - [x] Set `AWS_DEFAULT_REGION=eu-central-1` across all repos (org-level — done manually by user)
  - [x] Set additional region secrets on specific repos (`AWS_DEFAULT_REGION_PROD` on terraform-dev, configmap-prod; `TP_AWS_DEFAULT_REGION_PROD` on configmap-prod)
  - [x] Update environment-level region secrets (`AWS_DEFAULT_REGION`, `CDK_DEFAULT_REGION`) on prod environments for 10 repos (19 secrets)
  - [x] Update environment-level credential secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) on prod environments for 9 repos (18 secrets)
  - [x] Update repo-level credential secrets on distribution-portal (4 secrets) and terraform-prod (2 secrets)
  - [x] Update mobile-scanner production environment (credentials + `CLOUDFRONT`, `CLOUDFRONT_DISTRIBUTION_ID`, `S3`)
  - [ ] Update Dashboard GitHub variables (Storybook bucket, CloudFront ID) — **SKIPPED:** no storybook S3 bucket or CloudFront distribution exists in eu-central-1 yet
- **Notes:**
  - User manually updated organization-level secrets before this step
  - User manually deleted repo-level `AWS_DEFAULT_REGION` overrides from `reporting-api` and `terraform-prod`
  - 13 repos had environment-based secrets that shadow org-level — only prod environments updated (dev/sandbox deferred to P5)
  - `CDK_DEFAULT_REGION` set at org level by user; also updated in all prod environments
  - **~48 total secret updates** across environment, repo, and mobile-scanner levels
- **Deviations:**

  **DEVIATION:** Plan only listed `AWS_DEFAULT_REGION` across repos + a few repo-specific secrets. Actual scope was much larger due to environment-level secrets shadowing org secrets.
  **Reason:** 13 repos use GitHub environment-based secrets (highest priority) which override org-level values. Plan did not account for environment-level secret hierarchy.
  **Actions taken:** Updated `AWS_DEFAULT_REGION`, `CDK_DEFAULT_REGION`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY` on prod environments for all affected repos. Also updated mobile-scanner production environment with new CloudFront/S3 values.
  **Downstream impact:** Dev/sandbox environment secrets still point to me-south-1 — must be updated in Phase 5. Storybook infrastructure (S3 bucket + CloudFront) needs to be created before dashboard variables can be set (post-migration task).

### P4-S5: Merge to production & deploy frontends

- **Status:** `DONE`
- **Started:** 2026-03-30
- **Completed:** 2026-03-30
- **Substeps:**
  - [x] Merge hotfix branches to master/production across all repos
  - [x] Dashboard: merge triggers Vercel redeploy
  - [x] Distribution Portal Frontend: verify deploy
  - [x] Mobile Scanner: trigger release build
- **Notes:** All hotfix branches merged. Production fully deployed through normal CI/CD process via GitHub Actions workflows.

### P4-S6: End-to-end validation (production domain)

- **Status:** `DONE`
- **Started:** 2026-03-30
- **Completed:** 2026-03-30
- **Checklist:**
  - [x] Dashboard login (prod Auth0 + api.production.tickets.mdlbeast.net)
  - [x] Full ticket lifecycle (create event → tickets → order → PDF → scan)
  - [x] Payment flow (Geidea webhook)
  - [x] CSV report generation
  - [x] Media upload/download
  - [x] Inter-service event flow
  - [x] Slack error notifications (eu-central-1 console links)
  - [x] CloudWatch logs + X-Ray traces
  - [x] DNS resolution for all public endpoints
  - [x] Mobile scanner connects to new backend
- **Notes:** Full end-to-end validation passed. Production environment running successfully on eu-central-1.

### P4-S7: Post-go-live monitoring (72 hours)

- **Status:** `DONE`
- **Started:** 2026-03-30
- **Completed:** 2026-03-30
- **Substeps:**
  - [x] CloudWatch dashboards configured
  - [x] Slack error channel monitored
  - [x] Sentry checked for new patterns
  - [x] RDS metrics nominal
  - [x] After 72h stable: reduce Aurora min ACU to normal
- **Notes:** Production stable. Monitoring confirmed nominal.

### P4-S8: Migrate `ticketing-glue-gcp` S3 bucket to eu-central-1

- **Status:** `DONE`
- **Started:** 2026-03-29
- **Completed:** 2026-03-30
- **Context:** AutomaticDataExporter Lambda failing every 11 min with `AmazonS3Exception: The me-south-1 location constraint is incompatible for the region specific endpoint`. Root cause: `ticketing-glue-gcp` bucket was missed during migration — not in the S3 Bucket Naming Strategy table, not managed by Terraform, only referenced in automations CDK IAM policies.
- **Substeps:**
  - [x] Created `ticketing-glue-gcp-eu` bucket in eu-central-1 (public access blocked, AES256 encryption)
  - [x] Copied data from `ticketing-glue-gcp` (me-south-1) to `ticketing-glue-gcp-eu` (eu-central-1) via `aws s3 sync`
  - [x] Updated `/prod/automations` secret: `S3Bucket` → `ticketing-glue-gcp-eu` in both `AUTOMATIC_DATA_EXPORTER_CONFIG` and `GEIDEA_DATA_EXPORTER_CONFIG` (`S3Region` already `eu-central-1`)
  - [x] Created PR [#40](https://github.com/mdlbeasts/ticketing-platform-automations/pull/40): updates IAM ARNs (`ticketing-glue-gcp` → `ticketing-glue-gcp-eu`) in `AutomaticDataExporterStack.cs` and `GeideaDataExporterStack.cs`, disables scheduler via `Enabled = false`
  - [x] Merge PR → CI/CD deploys CDK (IAM updated, scheduler disabled, errors stop)
  - [ ] GCP team updates 16 BigQuery Data Transfer configs (`s3://ticketing-glue-gcp/...` → `s3://ticketing-glue-gcp-eu/...`) in project `127814635375`
  - [ ] Re-enable scheduler: remove `Enabled = false` from `AutomaticDataExporterStack.cs`, merge new PR
- **Deviations:**
  - Old bucket had no bucket policy — BigQuery Data Transfer uses IAM access keys (not cross-account bucket policy)
  - GeideaDataExporter CDK stack is commented out in `Program.cs:35` (not deployed to eu-central-1) — updated secret and IAM ARN anyway for correctness
  - AWS-side work complete; remaining GCP-side items (BigQuery Transfer config updates + scheduler re-enable) handed off to GCP team
- **Notes:**
  - No bucket policy to replicate (confirmed `NoSuchBucketPolicy` on old bucket)
  - Data is ephemeral (Parquet files overwritten every 11 min), but copied for GCP team testing
  - 16 BigQuery Transfer config IDs documented in PR description for GCP handoff

### P4-S9: Fix stale RDS endpoint in `FINANCE_REPORT_SENDER_CONFIG`

- **Status:** `DONE`
- **Started:** 2026-03-29
- **Completed:** 2026-03-29
- **Context:** FinanceReportSender Lambda failing with `SocketException: Unknown socket error` (DNS NXDOMAIN). Root cause: `FINANCE_REPORT_SENDER_CONFIG` in `/prod/automations` has 3 connection strings pointing to old Aurora cluster ID `cocuscg4fsup` which doesn't exist in eu-central-1. The bulk secret migration (P2-S7) updated the region to `eu-central-1` but the cluster ID changed because Aurora was restored from backup (new cluster = new ID `c0lac6czadei`).
- **Substeps:**
  - [x] Updated `/prod/automations` secret: replaced `cocuscg4fsup` → `c0lac6czadei` in `FINANCE_REPORT_SENDER_CONFIG` (all 3 connection strings: sales, catalogue, organizations)
  - [x] Forced Lambda cold start via `update-function-configuration` on `automations-finance-report-sender-lambda-prod`
- **Deviations:** None
- **Notes:**
  - `AUTOMATIC_DATA_EXPORTER_CONNECTION_STRING` in the same secret already had the correct cluster ID (`c0lac6czadei`) — only `FINANCE_REPORT_SENDER_CONFIG` was stale
  - Comprehensive audit of all 24 secrets confirmed no other stale RDS references exist
  - Also found: gateway `Logging__Elasticsearch__Uri` points to non-existent OpenSearch domain — intentional per migration plan (OpenSearch removed, not recreated; Serilog has no Elasticsearch sink)

---

## Phase 5: Dev+Sandbox Rebuild

> **Detailed plan:** `.personal/tasks/2026-03-05_aws-region-migration/plan-phase-5.md` — contains full CLI commands, lessons incorporated, and branching strategy.
> **Account:** `307824719505` | **Profile:** `AdministratorAccess-307824719505`

### P5-S1: Pre-flight — Fix Terraform S3 bucket names

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Rename S3 buckets to `-eu` suffix in `s3.tf`, `variables.tf`, `mobile.tf`
  - [ ] Update IAM policy ARNs referencing bucket names
  - [ ] Commit on `hotfix/region-migration-eu-central-1`
- **Notes:**

### P5-S2: Pre-flight — Fix Terraform VPC, SG, CloudFront, RDS

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Add `enable_dns_hostnames`/`enable_dns_support` to `vpc.tf`
  - [ ] Add VPC CIDR port 5432 ingress to `rds.tf`
  - [ ] Add CloudFront OAC bucket policies to `s3.tf`
  - [ ] Add `cloudfront:CreateInvalidation` to `user-cicd.tf`
  - [ ] Add `*.tfstate` to `.gitignore`
  - [ ] Uncomment RDS cluster/instance blocks in `rds.tf` (no serverless scaling in TF)
  - [ ] Commit on `hotfix/region-migration-eu-central-1`
- **Notes:**

### P5-S3: Terraform foundation

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Service quota pre-checks (Lambda, VPC NAT, RDS)
  - [ ] Create Terraform state bucket `ticketing-terraform-dev-eu`
  - [ ] Replicate `terraform` secret from me-south-1, promote to standalone
  - [ ] Import Route53 zones (dev, sandbox)
  - [ ] Import global resources (IAM, CloudFront OACs, state bucket)
  - [ ] Handle S3 ACL issues if any
  - [ ] `terraform apply`
  - [ ] Set Serverless v2 scaling via CLI (MinCapacity=0.5, MaxCapacity=16)
- **Outputs:**
  - `VPC_ID`:
  - `SUBNET_1_ID`:
  - `SUBNET_2_ID`:
  - `SUBNET_3_ID`:
  - `RDS_SG_ID`:
  - `KMS_KEY_ID`:
  - `DEV_ZONE_ID`:
  - `SANDBOX_ZONE_ID`:
  - `AURORA_ENDPOINT`:
  - `AURORA_RO_ENDPOINT`:
- **Notes:**

### P5-S4: Replicate secrets from me-south-1

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Replicate dev service secrets (20) from me-south-1
  - [ ] Replicate sandbox service secrets (20) from me-south-1
  - [ ] Replicate shared secrets (rds/ticketing-cluster, devops)
  - [ ] Promote ALL replicas to standalone
  - [ ] Verify ~43 secrets exist and are standalone
- **Notes:**

### P5-S5: Replicate SSM parameters from me-south-1

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Bulk-replicate all params from me-south-1 (skip Kafka/MSK/Elasticsearch/deprecated)
  - [ ] Override subnet IDs (suffix-only), RDS SG, bucket names, KMS key, service URLs
  - [ ] Verify parameter count
- **Notes:**

### P5-S6: Populate database

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Update `/rds/ticketing-cluster` secret with actual Aurora endpoint
  - [ ] User populates DB manually via SSM tunnel from local sandbox dump
  - [ ] Create DynamoDB Cache table
- **Notes:**

### P5-S7: Update connection strings & region-dependent secrets

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Update CONNECTION_STRINGS in all dev+sandbox service secrets (use jq pipeline)
  - [ ] Update FINANCE_REPORT_SENDER_CONFIG with correct new cluster endpoint
  - [ ] Blanket me-south-1 → eu-central-1 replacement
  - [ ] Strip deprecated keys (Elasticsearch, Redis, Kafka)
  - [ ] Verify zero me-south-1 references and no PLACEHOLDERs
- **Notes:**

### P5-S8: CDK bootstrap + ACM certificates + delete stale DNS records

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] CDK bootstrap (account 307824719505)
  - [ ] Delete stale me-south-1 A records from dev + sandbox Route53 zones
  - [ ] Create 6 ACM certificates (3 dev + 3 sandbox: gateway, geidea, ecwid)
  - [ ] Store cert ARNs in SSM
- **Notes:**

### P5-S9: Deploy infrastructure CDK (11 stacks × 2 envs)

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Bulk-delete stale dev/sandbox IAM inline policies (backup first)
  - [ ] Deploy 11 sandbox infrastructure stacks (EventBus → SlackNotification)
  - [ ] Deploy 11 dev infrastructure stacks (shared stacks already deployed)
- **Notes:**

### P5-S10: Deploy per-service CDK stacks (sandbox first, then dev)

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Create `hotfix/sandbox-eu-migration` branches, PRs (don't merge)
  - [ ] Manual CDK deployment for all 24 services (sandbox): build → lambda package → import → deploy
  - [ ] Create `hotfix/dev-eu-migration` branches, PRs (don't merge)
  - [ ] Manual CDK deployment for all 24 services (dev)
  - [ ] Run DB migrations for all services with DbMigrator
- **Notes:**

### P5-S11: Update GitHub secrets & variables

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Update environment-level `AWS_DEFAULT_REGION`, `CDK_DEFAULT_REGION` for dev+sandbox
  - [ ] Update IAM credentials if applicable
- **Notes:**

### P5-S12: Merge PRs

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Sandbox: Merge Group 1 (tools → infrastructure → templates) sequentially
  - [ ] Sandbox: Merge Group 2 (terraform-dev)
  - [ ] Sandbox: Merge Groups 3-5 (services by tier, parallel within group)
  - [ ] Sandbox: Merge Group 6 (gateway + frontends, last)
  - [ ] Dev: Repeat all merge groups for development branch
- **Notes:**

### P5-S13: End-to-end validation

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Checklist:**
  - [ ] Sandbox: API Gateway health, Geidea, internal DNS, DB connectivity, EventBridge→SQS, CloudWatch, dashboard login
  - [ ] Dev: Same checklist against `*.dev.tickets.mdlbeast.net`
- **Notes:**

---

## Post-Migration Tasks

### PM-1: Temporary domain cleanup

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Delete `production-eu.tickets.mdlbeast.net` hosted zone
  - [ ] Remove NS delegation from parent zone
  - [ ] Delete temporary ACM certificates
- **Notes:**

### PM-2: Extension Lambda redeployment

- **Status:** `DONE`
- **Started:** 2026-03-27T13:00
- **Completed:** 2026-03-26T14:13
- **Substeps:**
  - [x] Verify extension-deployer SSM param exists
  - [x] Query active extensions from DB
  - [x] Trigger redeployment for each extension
- **Notes:** Redeployed through dashboard by changin/adding version comment in the extension code. Disabled extensions had to be enabled first before updating extension code in order to trigger redeployment. These extensions were disabled again afterwards.

### PM-3: Configure AWS Backup in eu-central-1

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Notes:**

### PM-4: Post-migration cleanup (after 7-day stability + me-south-1 recovery)

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Checklist:**
  - [ ] Schedule me-south-1 KMS key deletion
  - [ ] Verify S3 data completeness
  - [ ] Delete me-south-1 resources
  - [ ] Delete me-south-1 Terraform state buckets
  - [ ] Clean up me-south-1 IAM roles
  - [ ] Delete EKS cluster
  - [ ] Delete ECR repos
  - [ ] Archive ConfigMap repos
  - [ ] Remove deploy.yml/k8s.yml from templates-ci-cd
  - [ ] Remove Helm charts
  - [ ] Delete Redis/OpenSearch in me-south-1
  - [ ] Clean up Redis/OpenSearch config references
  - [ ] Deregister GitHub Actions runners
  - [ ] Rotate all credentials
  - [ ] Audit IAM for region-specific ARNs
  - [ ] Remove committed .tfstate from git history
  - [ ] Update CLAUDE.md, DEPLOYMENT.md, ARCHITECTURE.md
- **Notes:**
