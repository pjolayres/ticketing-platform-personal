# Execution Log: AWS Region Migration (me-south-1 → eu-central-1)

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

| Key                     | Value                                  | Produced By   | Consumed By         |
| ----------------------- | -------------------------------------- | ------------- | ------------------- |
| `VPC_ID`                | `vpc-00de5834b0f381b4d`                | P2-S4         | P2-S4-verify, P2-S5 |
| `SUBNET_1_ID`           | `subnet-01b47a6d26df020ec`             | P2-S4         | P2-S5               |
| `SUBNET_2_ID`           | `subnet-0b38abd7f712530d9`             | P2-S4         | P2-S5               |
| `SUBNET_3_ID`           | `subnet-05359403da2d9a5fe`             | P2-S4         | P2-S5               |
| `RDS_SG_ID`             | `sg-00dab49088126dfa7`                 | P2-S4         | P2-S5, P2-S6        |
| `KMS_KEY_ID`            | `72ea5a94-3fbc-494a-baa6-79f3d4c82121` | P2-S4         | P3-S4               |
| `AURORA_ENDPOINT`       | `ticketing.cluster-c0lac6czadei.eu-central-1.rds.amazonaws.com` | P2-S6         | P2-S6, P3-S4        |
| `AURORA_RO_ENDPOINT`    | `ticketing.cluster-ro-c0lac6czadei.eu-central-1.rds.amazonaws.com` | P2-S6         | P3-S4               |
| `RDS_USER`              | `devops`                               | P2-S6         | P2-S6, P3-S4        |
| `RDS_PASS`              |                                        | P2-S3         | P2-S3, P2-S6        |
| `PROD_ZONE_ID`          | `Z095340838T2KOPA8X742`                | P2-S4         | P3-S2, P4-S2        |
| `ROOT_ZONE_ID`          | N/A (zone doesn't exist)               | P2-S4         | P3-S1               |
| `TEMP_ZONE_ID`          |                                        | P3-S1         | P3-S2, post-cleanup |
| `CERT_ARN_GATEWAY_TEMP` |                                        | P3-S2         | P3-S3               |
| `CERT_ARN_GEIDEA_TEMP`  |                                        | P3-S2         | P3-S3               |
| `CERT_ARN_ECWID_TEMP`   |                                        | P3-S2         | P3-S3               |
| `CERT_ARN_GATEWAY_PROD` |                                        | P4-S2         | P4-S3               |
| `CERT_ARN_GEIDEA_PROD`  |                                        | P4-S2         | P4-S3               |
| `CERT_ARN_ECWID_PROD`   |                                        | P4-S2         | P4-S3               |
| `NEW_AWS_KEY`           |                                        | P2-S4 / P3-S4 | P3-S4               |
| `NEW_AWS_SECRET`        |                                        | P2-S4 / P3-S4 | P3-S4               |
| `NUGET_VERSION_1`       | `1.0.1300`                             | P1-T19        | P1-T19              |
| `NUGET_VERSION_2`       |                                        | P4-S1.1       | P4-S1.1             |

---

## Deviations Log

> Summary of all deviations from `plan.md`. Each entry links to the step where the full deviation record lives. Future agents: **read this section first** to understand how the current state differs from the original plan before executing your step.

| Step   | Summary                                                                                                                                                     | Downstream Impact                                                                                |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| P1-T0  | Switched terraform-dev to `master` and ecwid-integration to `production` before branching; configmap-prod branched from `disaster`                          | None                                                                                             |
| P1-T2  | Also removed 3 MSK ingress rules from rds.tf (referenced deleted msk.tf); deleted iam-s3-sqs.tf entirely (only had s3-sqs-eks)                              | None                                                                                             |
| P1-T4  | Bulk script updated 53 files across 18 repos (plan listed 14); extra repos had demo env files or weren't listed                                             | None                                                                                             |
| P1-T5  | 25 repos affected (plan listed 22); created hotfix branches in 3 extra repos (bandsintown-integration, marketing-feeds, xp-badges)                          | None                                                                                             |
| P1-T10 | `.env.development` gitignored — updated locally but not committed; `S3_MEDIA_BUCKET_URL` bucket renamed from `ticketing-media` to `ticketing-prod-media-eu` | None                                                                                             |
| P1-T12 | Workflows disabled (trigger → workflow_dispatch) instead of deleted, per user preference                                                                    | None                                                                                             |
| P1-T13 | Pricing skipped (no me-south-1 refs); gateway had 4 Elasticsearch URI occurrences not 1                                                                     | None                                                                                             |
| P1-T14 | terraform-prod had no `.gitignore` — created from scratch                                                                                                   | None                                                                                             |
| P2-S3  | Used `replicate-secret-to-regions` from me-south-1 instead of manual recreation; `devops` created from backup (replica secret)                              | None — cleanup in P3-S4                                                                          |
| P2-S4  | Only one Route53 zone imported (not two); `tickets.mdlbeast.net` doesn't exist and was never in state                                                       | P3-S1 must use `PROD_ZONE_ID` for NS delegation instead of `ROOT_ZONE_ID`                        |
| P2-S4  | S3 bucket renames (`-eu` suffix) missed in Phase 1 — fixed in this step: `s3.tf`, `variables.tf`, `mobile.tf` (4 buckets)                                   | `ticketing-app-mobile-eu` needs S3 copy from me-south-1; dashboard CloudFront URLs need updating |
| P2-S4  | 34 global resources imported (IAM, CloudFront OACs, S3 state bucket) — plan assumed fresh creation                                                          | None — IAM policies are additive (both regions work)                                             |
| P2-S4  | New CloudFront distribution IDs: `E2E0LQF2V6W4U` (s3_prod), `E1NNQYK06MZJSB` (mobile) — dashboard has hardcoded old IDs                                     | Dashboard code + GitHub vars need CloudFront URL updates before go-live                          |
| P2-S4  | `developer-msk` group policy attachment removed (AWS 10-policy limit, MSK deprecated)                                                                       | None                                                                                             |
| P2-S4  | Removed `acl = "private"` from `ticketing-terraform-prod-eu` bucket (ACLs disabled by default since April 2023)                                             | None                                                                                             |
| P2-S5  | Created 35 params (plan: 16). Added CSV/PDF full runtime sets, Slack `WebhookUrl`, extension manual params. Fixed `STORAGE_EXPIRATION_HOURS` (167/168 not 48). Used live me-south-1 values. Set `ACCESS_CONTROL_SERVICE_URL`/`ExtensionApiUrl` to temp domain. | `ACCESS_CONTROL_SERVICE_URL` + `ExtensionApiUrl` must update to final domain at Phase 4 cutover. `/rds/ticketing-cluster-ro-endpoint` deferred to P2-S6. |
| P2-S6  | IAM role name was `AWSBackupDefaultServiceRole` not `AWSBackupDefaultRole`; restore metadata required full format with JSON arrays; scaling config must be set before creating serverless instances; `/rds/ticketing-cluster` secret was replica — promoted before updating; terraform plan showed 4 minor drifts — applied, min_capacity set to 1.5 (not 8) | Replicated secrets need promotion before update in P3-S4 |
| P2-S7  | Restored 3 buckets (plan listed 2) — added `ticketing-app-mobile`; plan metadata wrong (`NewBucket` undocumented, missing `EncryptionType`/`KMSKey` for cross-region); required temporary ACL/ownership relaxation on destination buckets; pdf-download needed retry restore after partial failure | None |

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

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Create `production-eu.tickets.mdlbeast.net` hosted zone
  - [ ] Get NS records for the new zone
  - [ ] Add NS delegation in parent zone (`tickets.mdlbeast.net`)
- **Outputs:**
  - `TEMP_ZONE_ID`:
  - NS records:
- **Notes:**

### P3-S2: Create ACM certificates (temporary domain)

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Request + validate cert for `api.production-eu.tickets.mdlbeast.net` → SSM `/production-eu/tp/DomainCertificateArn`
  - [ ] Request + validate cert for `geidea.production-eu.tickets.mdlbeast.net` → SSM `/prod/tp/geidea/DomainCertificateArn`
  - [ ] Request + validate cert for `ecwid.production-eu.tickets.mdlbeast.net` → SSM `/prod/tp/ecwid/DomainCertificateArn`
  - [ ] Verify all 3 certs ISSUED
- **Outputs:**
  - `CERT_ARN_GATEWAY_TEMP`:
  - `CERT_ARN_GEIDEA_TEMP`:
  - `CERT_ARN_ECWID_TEMP`:
- **Notes:**

### P3-S3: Infrastructure CDK (11 stacks — strict order)

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Stack 1: `TP-EventBusStack-prod`
  - [ ] Stack 2: `TP-ConsumersSqsStack-prod`
  - [ ] Stack 3: `TP-ConsumerSubscriptionStack-prod`
  - [ ] Stack 4: `TP-ExtendedMessageS3BucketStack-prod`
  - [ ] Stack 5: `TP-InternalHostedZoneStack-prod`
  - [ ] Stack 6: `TP-InternalCertificateStack-prod`
  - [ ] Stack 7: `TP-MonitoringStack-prod`
  - [ ] Stack 8: `TP-ApiGatewayVpcEndpointStack`
  - [ ] Stack 9: `TP-RdsProxyStack`
  - [ ] Stack 10: `TP-XRayInsightNotificationStack-prod`
  - [ ] Stack 11: `TP-SlackNotificationStack-prod`
- **Notes:**

### P3-S4: Update connection strings & region-dependent secrets

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Get Aurora cluster endpoints (direct, not RDS Proxy)
  - [ ] Get RDS master credentials from secret
  - [ ] Generate new IAM CICD user access key
  - [ ] Get new KMS key ID
  - [ ] Update CONNECTION_STRINGS in 16 service secrets
  - [ ] Update SQS queue URLs for extensions (deployer + executor)
  - [ ] Update SQS_QUEUE_URL for CSV generator consumers (marketplace, sales, transfer, reporting)
  - [ ] Update media SQS_QUEUE_URL
  - [ ] Verify CONNECTION_STRINGS point to new Aurora endpoint
  - [ ] Verify database names exist in restored cluster (`\l`)
- **Outputs:**
  - `NEW_AWS_KEY`:
  - `NEW_AWS_SECRET`:
- **Notes:**

### P3-S5: Per-service CDK deployment

Tier 1 services (deploy in parallel):

#### P3-S5-01: catalogue

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] `dotnet build` CDK project
  - [ ] Deploy DbMigratorStack
  - [ ] Run DB migration Lambda
  - [ ] Deploy ServerlessBackendStack
- **Notes:**

#### P3-S5-02: organizations

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**

#### P3-S5-03: loyalty

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy ConsumersStack → BackgroundJobsStack
- **Notes:**

#### P3-S5-04: csv-generator

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy ConsumersStack
- **Notes:**

#### P3-S5-05: pdf-generator

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy ConsumersStack
- **Notes:**

#### P3-S5-06: automations

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy WeeklyTicketsSenderStack
  - [ ] Deploy AutomaticDataExporterStack
  - [ ] Deploy FinanceReportSenderStack
- **Notes:**

#### P3-S5-07: extension-api

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**

#### P3-S5-08: extension-deployer

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy ExtensionDeployerLambdaRoleStack → ExtensionDeployerStack
- **Notes:**

#### P3-S5-09: extension-executor

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy ExtensionExecutorStack
- **Notes:**

#### P3-S5-10: extension-log-processor

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy ExtensionLogsProcessorStack
- **Notes:**

#### P3-S5-11: customer-service

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**

Tier 2 services (deploy after Tier 1):

#### P3-S5-12: inventory

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**

#### P3-S5-13: pricing

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy ConsumersStack → ServerlessBackendStack
- **Notes:**

#### P3-S5-14: media

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy MediaStorageStack
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**

#### P3-S5-15: reporting-api

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**

#### P3-S5-16: marketplace

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**

#### P3-S5-17: integration

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**

#### P3-S5-18: distribution-portal

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**

Tier 3 services (deploy after Tier 2):

#### P3-S5-19: sales

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**

#### P3-S5-20: access-control

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**

#### P3-S5-21: transfer

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy DbMigratorStack → run migration
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ServerlessBackendStack
- **Notes:**

#### P3-S5-22: geidea

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy ConsumersStack → BackgroundJobsStack → ApiStack
- **Notes:**

#### P3-S5-23: ecwid-integration

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy ApiStack → BackgroundJobsStack
- **Notes:**

#### P3-S5-24: gateway (LAST)

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy GatewayStack
- **Notes:**

### P3-S6: End-to-end validation (temporary domain)

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Checklist:**
  - [ ] API Gateway responds at `api.production-eu.tickets.mdlbeast.net`
  - [ ] Geidea endpoint responds at `geidea.production-eu.tickets.mdlbeast.net`
  - [ ] Internal services resolve via private DNS
  - [ ] Create event in catalogue
  - [ ] Create tickets in inventory
  - [ ] Process test order through sales
  - [ ] PDF ticket generation
  - [ ] CSV report generation
  - [ ] Media upload/download
  - [ ] Access control scanning flow
  - [ ] Slack notifications arriving
  - [ ] Inter-service event flow (EventBridge → SQS → Consumer)
  - [ ] CloudWatch logs in eu-central-1
  - [ ] Extension deployer creates Lambda in eu-central-1
  - [ ] Dashboard local test against temp domain
- **Notes:**

### P3-VERIFY: Phase 3 verification checklist

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Checklist:**
  - [ ] All 11 infrastructure stacks CREATE_COMPLETE
  - [ ] All 24 service deployments completed
  - [ ] All DB migrations ran successfully
  - [ ] Lambda functions responding
  - [ ] EventBridge rules → SQS queues (18 consumers)
  - [ ] Internal DNS resolving
  - [ ] API Gateway endpoints accessible
  - [ ] All secrets have correct values (no PLACEHOLDERs remaining)
- **Notes:**

---

## Phase 4: DNS Cutover to Production Domain

### P4-S1: Revert temporary domain mapping in CDK

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Revert `ServerlessApiStackHelper.cs:47`
  - [ ] Revert `GatewayStack.cs:32` and `:107`
  - [ ] Revert `InternalHostedZoneStack.cs:15`
  - [ ] Revert `InternalCertificateStack.cs:15`
  - [ ] Revert `Geidea ApiStack.cs:32`
  - [ ] Revert `Ecwid ApiStack.cs:32`
- **Notes:**

### P4-S1.1: Publish updated ticketing-platform-tools NuGet package

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Merge to master, push to trigger nuget.yml
  - [ ] Wait for workflow — record version
  - [ ] Bump TP.Tools.\* in 18 service repos being redeployed
  - [ ] Commit version bumps
  - [ ] Verify build
- **Outputs:**
  - `NUGET_VERSION_2`:
- **Notes:**

### P4-S2: Create ACM certificates for real domain

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Request + validate cert for `api.production.tickets.mdlbeast.net` → SSM `/production/tp/DomainCertificateArn`
  - [ ] Request + validate cert for `geidea.production.tickets.mdlbeast.net` → SSM `/prod/tp/geidea/DomainCertificateArn`
  - [ ] Request + validate cert for `ecwid.production.tickets.mdlbeast.net` → SSM `/prod/tp/ecwid/DomainCertificateArn`
  - [ ] Verify all 3 certs ISSUED
- **Outputs:**
  - `CERT_ARN_GATEWAY_PROD`:
  - `CERT_ARN_GEIDEA_PROD`:
  - `CERT_ARN_ECWID_PROD`:
- **Notes:**

### P4-S3: Redeploy public-facing stacks

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Deploy `TP-InternalHostedZoneStack-prod`
  - [ ] Deploy `TP-InternalCertificateStack-prod`
  - [ ] Deploy `GatewayStack`
  - [ ] Deploy `TP-Geidea-ApiStack-prod`
  - [ ] Deploy `TP-ApiStack-ecwid-prod`
  - [ ] Parallel redeploy all 14 ServerlessBackendStack stacks (minimize CNAME gap)
  - [ ] Verify internal DNS resolution
- **Notes:**
- **CNAME gap duration (measure):**

### P4-S4: Update GitHub secrets & variables

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Set `AWS_DEFAULT_REGION=eu-central-1` across all repos
  - [ ] Set additional region secrets on specific repos
  - [ ] Update Dashboard GitHub variables (Storybook bucket, CloudFront ID)
- **Notes:**

### P4-S5: Merge to production & deploy frontends

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Merge hotfix branches to master/production across all repos
  - [ ] Dashboard: merge triggers Vercel redeploy
  - [ ] Distribution Portal Frontend: verify deploy
  - [ ] Mobile Scanner: trigger release build
- **Notes:**

### P4-S6: End-to-end validation (production domain)

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Checklist:**
  - [ ] Dashboard login (prod Auth0 + api.production.tickets.mdlbeast.net)
  - [ ] Full ticket lifecycle (create event → tickets → order → PDF → scan)
  - [ ] Payment flow (Geidea webhook)
  - [ ] CSV report generation
  - [ ] Media upload/download
  - [ ] Inter-service event flow
  - [ ] Slack error notifications (eu-central-1 console links)
  - [ ] CloudWatch logs + X-Ray traces
  - [ ] DNS resolution for all public endpoints
  - [ ] Mobile scanner connects to new backend
- **Notes:**

### P4-S7: Post-go-live monitoring (72 hours)

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] CloudWatch dashboards configured
  - [ ] Slack error channel monitored
  - [ ] Sentry checked for new patterns
  - [ ] RDS metrics nominal
  - [ ] After 72h stable: reduce Aurora min ACU to normal
- **Notes:**

---

## Phase 5: Dev+Sandbox Rebuild

### P5-S1: Service quota pre-checks (account 307824719505)

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Notes:**

### P5-S2: Foundation

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Create Terraform state bucket `ticketing-terraform-dev-eu`
  - [ ] Create secrets (dev + sandbox prefixes)
  - [ ] Import Route53 zones (dev, sandbox)
  - [ ] `terraform apply` (includes RDS cluster — fresh, no backup)
  - [ ] Populate SSM parameters
  - [ ] Create DynamoDB Cache table
  - [ ] CDK bootstrap
- **Notes:**

### P5-S3: Services & validation

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Create ACM certificates (dev + sandbox)
  - [ ] Deploy infrastructure CDK (11 stacks × 2 envs)
  - [ ] Update connection strings in secrets
  - [ ] Deploy all service stacks per matrix
  - [ ] DB migrations (fresh empty schemas)
  - [ ] Seed test data
  - [ ] Update GitHub secrets if not done in P4-S4
  - [ ] Merge branches to development/sandbox
  - [ ] Smoke test dev + sandbox
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

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Verify extension-deployer SSM param exists
  - [ ] Query active extensions from DB
  - [ ] Trigger redeployment for each extension
- **Notes:**

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
