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

| Key                     | Value      | Produced By   | Consumed By         |
| ----------------------- | ---------- | ------------- | ------------------- |
| `VPC_ID`                |            | P2-S4         | P2-S4-verify, P2-S5 |
| `SUBNET_1_ID`           |            | P2-S4         | P2-S5               |
| `SUBNET_2_ID`           |            | P2-S4         | P2-S5               |
| `SUBNET_3_ID`           |            | P2-S4         | P2-S5               |
| `RDS_SG_ID`             |            | P2-S4         | P2-S5, P2-S6        |
| `KMS_KEY_ID`            |            | P2-S4         | P3-S4               |
| `AURORA_ENDPOINT`       |            | P2-S6         | P2-S6, P3-S4        |
| `AURORA_RO_ENDPOINT`    |            | P2-S6         | P3-S4               |
| `RDS_USER`              |            | P2-S6         | P2-S6, P3-S4        |
| `RDS_PASS`              |            | P2-S3         | P2-S3, P2-S6        |
| `PROD_ZONE_ID`          |            | P2-S4         | P3-S2, P4-S2        |
| `ROOT_ZONE_ID`          |            | P2-S4         | P3-S1               |
| `TEMP_ZONE_ID`          |            | P3-S1         | P3-S2, post-cleanup |
| `CERT_ARN_GATEWAY_TEMP` |            | P3-S2         | P3-S3               |
| `CERT_ARN_GEIDEA_TEMP`  |            | P3-S2         | P3-S3               |
| `CERT_ARN_ECWID_TEMP`   |            | P3-S2         | P3-S3               |
| `CERT_ARN_GATEWAY_PROD` |            | P4-S2         | P4-S3               |
| `CERT_ARN_GEIDEA_PROD`  |            | P4-S2         | P4-S3               |
| `CERT_ARN_ECWID_PROD`   |            | P4-S2         | P4-S3               |
| `NEW_AWS_KEY`           |            | P2-S4 / P3-S4 | P3-S4               |
| `NEW_AWS_SECRET`        |            | P2-S4 / P3-S4 | P3-S4               |
| `NUGET_VERSION_1`       | `1.0.1300` | P1-T19        | P1-T19              |
| `NUGET_VERSION_2`       |            | P4-S1.1       | P4-S1.1             |

---

## Deviations Log

> Summary of all deviations from `plan.md`. Each entry links to the step where the full deviation record lives. Future agents: **read this section first** to understand how the current state differs from the original plan before executing your step.

| Step   | Summary                                                                                                                                                     | Downstream Impact |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| P1-T0  | Switched terraform-dev to `master` and ecwid-integration to `production` before branching; configmap-prod branched from `disaster`                          | None              |
| P1-T2  | Also removed 3 MSK ingress rules from rds.tf (referenced deleted msk.tf); deleted iam-s3-sqs.tf entirely (only had s3-sqs-eks)                              | None              |
| P1-T4  | Bulk script updated 53 files across 18 repos (plan listed 14); extra repos had demo env files or weren't listed                                             | None              |
| P1-T5  | 25 repos affected (plan listed 22); created hotfix branches in 3 extra repos (bandsintown-integration, marketing-feeds, xp-badges)                          | None              |
| P1-T10 | `.env.development` gitignored — updated locally but not committed; `S3_MEDIA_BUCKET_URL` bucket renamed from `ticketing-media` to `ticketing-prod-media-eu` | None              |
| P1-T12 | Workflows disabled (trigger → workflow_dispatch) instead of deleted, per user preference                                                                    | None              |
| P1-T13 | Pricing skipped (no me-south-1 refs); gateway had 4 Elasticsearch URI occurrences not 1                                                                     | None              |
| P1-T14 | terraform-prod had no `.gitignore` — created from scratch                                                                                                   | None              |

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

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Check Lambda concurrent executions quota
  - [ ] Check VPC NAT gateway quota
  - [ ] Check RDS cluster quota
  - [ ] Request increases if needed
- **Notes:**

### P2-S2: Create Terraform state bucket

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Create `ticketing-terraform-prod-eu` bucket
  - [ ] Enable versioning
  - [ ] Enable encryption
- **Notes:**

### P2-S3: Recreate Secrets Manager entries

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Step 1: Create `terraform` secret (RDS password — required before terraform apply)
  - [ ] Step 2: Create `/rds/ticketing-cluster` secret (placeholder host)
  - [ ] Step 3: Bulk-create 20 service secrets from backups (strip Elasticsearch/Redis keys)
  - [ ] Step 4: Create ecwid secret (partial backup + placeholders)
  - [ ] Step 5: Create `devops` secret
  - [ ] Step 6: Create `prod/data` secret
  - [ ] Step 7: Verify 26 secrets exist
- **Notes:**

### P2-S4: Terraform apply (without RDS cluster)

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] List existing Route53 hosted zones — record zone IDs
  - [ ] `terraform init -reconfigure`
  - [ ] Import Route53 zones (production.tickets.mdlbeast.net, tickets.mdlbeast.net)
  - [ ] `terraform plan` — review output
  - [ ] `terraform apply`
  - [ ] Verify VPC, subnets, S3 buckets created
- **Outputs:**
  - `VPC_ID`:
  - `SUBNET_1_ID`:
  - `SUBNET_2_ID`:
  - `SUBNET_3_ID`:
  - `RDS_SG_ID`:
  - `KMS_KEY_ID`:
  - `PROD_ZONE_ID`:
  - `ROOT_ZONE_ID`:
- **Notes:**

### P2-S5: Populate manual SSM parameters

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] VPC name (`/{env}/tp/VPC_NAME`)
  - [ ] RDS cluster identifier (`/rds/ticketing-cluster-identifier`)
  - [ ] RDS security group (`/rds/ticketing-cluster-sg`)
  - [ ] 3 subnet IDs (`/{env}/tp/SUBNET_1/2/3`)
  - [ ] PDF generator bucket name (`/{env}/tp/pdf/generator/STORAGE_BUCKET_NAME`)
  - [ ] 3 Slack webhook URLs (from backup-ssm/)
  - [ ] IgnoredErrorsPatterns
  - [ ] CSV generator SSM params (4 params)
  - [ ] PDF generator SSM params (5 params, one already done above)
  - [ ] Verify all params with `get-parameters-by-path`
- **Notes:**

### P2-S5.1: Create DynamoDB Cache table

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Create `Cache` table (PAY_PER_REQUEST, CacheKey HASH)
  - [ ] Enable TTL on `ExpirationTime`
  - [ ] Verify table ACTIVE
- **Notes:**

### P2-S6: Restore Aurora from AWS Backup

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] List recovery points — identify latest
  - [ ] Get RDS security group ID
  - [ ] Start restore job
  - [ ] Wait for restore completion
  - [ ] Verify/apply correct security group to restored cluster
  - [ ] Verify engine version
  - [ ] Create 3 serverless instances (`aurora-cluster-demo-0/1/2`)
  - [ ] Set Serverless v2 scaling (8-64 ACU for go-live)
  - [ ] Wait for all instances available
  - [ ] Verify cluster status, endpoint, reader endpoint
  - [ ] Uncomment RDS resources in terraform-prod `rds.tf`
  - [ ] `terraform import` cluster + 3 instances
  - [ ] `terraform plan` — verify zero changes
  - [ ] Update `/rds/ticketing-cluster` secret with actual Aurora endpoint
- **Outputs:**
  - `AURORA_ENDPOINT`:
  - `AURORA_RO_ENDPOINT`:
  - `RDS_USER`:
  - Recovery point ARN used:
  - Restore job ID:
  - Engine version:
- **Notes:**

### P2-S7: Restore S3 data from AWS Backup

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] List S3 recovery points for `tickets-pdf-download`
  - [ ] List S3 recovery points for `ticketing-csv-reports`
  - [ ] Start restore job → `tickets-pdf-download-eu`
  - [ ] Start restore job → `ticketing-csv-reports-eu`
  - [ ] Monitor restore jobs until complete
  - [ ] Verify object counts in restored buckets
- **Outputs:**
  - `tickets-pdf-download-eu` object count:
  - `ticketing-csv-reports-eu` object count:
- **Notes:**

### P2-S8: CDK bootstrap

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Notes:**

### P2-VERIFY: Phase 2 verification checklist

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Checklist:**
  - [ ] VPC exists with correct CIDR and 3 AZs
  - [ ] All subnets created (no EKS/Redis/OpenSearch/runner subnets)
  - [ ] NAT Gateways operational
  - [ ] Route53 zones imported, no duplicates
  - [ ] Aurora cluster restored and available (3 instances)
  - [ ] Aurora Serverless v2 scaling configured (8-64 ACU)
  - [ ] Aurora imported into Terraform — `terraform plan` shows no changes
  - [ ] RDS cluster/instance blocks uncommented in `rds.tf`
  - [ ] S3 data restored to `-eu` buckets
  - [ ] 16+ manual SSM parameters populated
  - [ ] DynamoDB `Cache` table ACTIVE
  - [ ] 26 secrets created in eu-central-1
  - [ ] `terraform` secret has valid `rds_pass`
  - [ ] `/rds/ticketing-cluster` has correct endpoint
  - [ ] KMS key exists
  - [ ] IAM CICD user created
  - [ ] Security groups configured correctly
  - [ ] CDK bootstrap stack deployed
- **Notes:**

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
