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

| Key                     | Value | Produced By   | Consumed By         |
| ----------------------- | ----- | ------------- | ------------------- |
| `VPC_ID`                |       | P2-S4         | P2-S4-verify, P2-S5 |
| `SUBNET_1_ID`           |       | P2-S4         | P2-S5               |
| `SUBNET_2_ID`           |       | P2-S4         | P2-S5               |
| `SUBNET_3_ID`           |       | P2-S4         | P2-S5               |
| `RDS_SG_ID`             |       | P2-S4         | P2-S5, P2-S6        |
| `KMS_KEY_ID`            |       | P2-S4         | P3-S4               |
| `AURORA_ENDPOINT`       |       | P2-S6         | P2-S6, P3-S4        |
| `AURORA_RO_ENDPOINT`    |       | P2-S6         | P3-S4               |
| `RDS_USER`              |       | P2-S6         | P2-S6, P3-S4        |
| `RDS_PASS`              |       | P2-S3         | P2-S3, P2-S6        |
| `PROD_ZONE_ID`          |       | P2-S4         | P3-S2, P4-S2        |
| `ROOT_ZONE_ID`          |       | P2-S4         | P3-S1               |
| `TEMP_ZONE_ID`          |       | P3-S1         | P3-S2, post-cleanup |
| `CERT_ARN_GATEWAY_TEMP` |       | P3-S2         | P3-S3               |
| `CERT_ARN_GEIDEA_TEMP`  |       | P3-S2         | P3-S3               |
| `CERT_ARN_ECWID_TEMP`   |       | P3-S2         | P3-S3               |
| `CERT_ARN_GATEWAY_PROD` |       | P4-S2         | P4-S3               |
| `CERT_ARN_GEIDEA_PROD`  |       | P4-S2         | P4-S3               |
| `CERT_ARN_ECWID_PROD`   |       | P4-S2         | P4-S3               |
| `NEW_AWS_KEY`           |       | P2-S4 / P3-S4 | P3-S4               |
| `NEW_AWS_SECRET`        |       | P2-S4 / P3-S4 | P3-S4               |
| `NUGET_VERSION_1`       |       | P1-T19        | P1-T19              |
| `NUGET_VERSION_2`       |       | P4-S1.1       | P4-S1.1             |

---

## Deviations Log

> Summary of all deviations from `plan.md`. Each entry links to the step where the full deviation record lives. Future agents: **read this section first** to understand how the current state differs from the original plan before executing your step.

| Step         | Summary | Downstream Impact |
| ------------ | ------- | ----------------- |
| _(none yet)_ |         |                   |

---

## Phase 1: Code Preparation

### P1-T0: Create branches in all 34 repos

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Notes:**

### P1-T1: Update Terraform region references

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Repos:** `terraform-prod`, `terraform-dev`
- **Notes:**

### P1-T2: EKS deprecation in terraform-prod

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Repo:** `terraform-prod`
- **Substeps:**
  - [ ] Delete `opensearch.tf`, `redis.tf`, `waf.tf`, `msk.tf`, `runner.tf`, `ecr.tf`
  - [ ] Rename `eks-subnet.tf` → `lambda-subnet.tf`, update resource names/tags
  - [ ] Modify `user-cicd.tf` — remove EKS policy + attachment
  - [ ] Modify `iam-s3-sqs.tf` — remove `s3-sqs-eks` policy
  - [ ] Modify `rds.tf` — remove 3 EKS subnet ingress rules
  - [ ] Modify `group.tf` — remove `techlead-redis`, `developer-opensearch` attachments
  - [ ] Modify `secretmanager.tf` — remove opensearch/redis outputs
- **Notes:**

### P1-T3: EKS deprecation cleanup in terraform-dev

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Repo:** `terraform-dev`
- **Substeps:**
  - [ ] Delete `iam-eks.tf`
  - [ ] Modify `iam-s3-sqs.tf` — remove `s3-sqs-eks`
  - [ ] Modify `rds.tf` — remove EKS subnet ingress rules
  - [ ] Modify `nat.tf` — remove `kubernetes.io/role/elb` tags
- **Notes:**

### P1-T4: Update CDK env-var JSON files (STORAGE_REGION)

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Run bulk `STORAGE_REGION` sed script across 14 services
  - [ ] Manually update 4 S3 bucket name vars (media + integration prod env-vars)
- **Notes:**

### P1-T5: Update aws-lambda-tools-defaults.json

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Run bulk sed script across 42 files
  - [ ] Fix pdf-generator anomaly (`eu-west-1` → `eu-central-1`)
- **Notes:**

### P1-T6: Update infrastructure C# code

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Update `EnvironmentService.cs:24` fallback region
  - [ ] Update `XRayInsightSlackService.cs:58` fallback region
  - [ ] Update `ExtendedMessageS3BucketStack.cs:17` bucket name (add `-eu`)
  - [ ] Update `SqsQueueService.cs:190` bucket name (add `-eu`)
  - [ ] Update `MessageProducer.cs:210` bucket name (add `-eu`)
  - [ ] Update `LambdaS3ExtendedMessagePolicyStatement.cs:26-27` wildcard pattern
- **Notes:**

### P1-T7: Update test files

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Notes:**

### P1-T8: Update ConfigMap YAML files

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Update dev manifests (6 files + secretstore.yml)
  - [ ] Update sandbox manifests (5 files + secretstore.yml)
  - [ ] Update prod manifests (5 files), remove Elasticsearch URI from sales.yml
- **Notes:**

### P1-T9: Update Mobile Scanner CI/CD

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Notes:**

### P1-T10: Update Dashboard CSP and .env files

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Update 6 S3 URLs in `vercel.json` CSP (region + bucket names)
  - [ ] Update `.env`, `.env.sandbox`, `.env.development` MEDIA_HOST URLs
- **Notes:**

### P1-T11: Delete CDK context caches

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Notes:**

### P1-T12: Update CI/CD templates and ConfigMap workflows

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Update/remove `deploy.yml` EKS references in templates-ci-cd
  - [ ] Update/remove `k8s.yml` EKS references in templates-ci-cd
  - [ ] Disable/delete ConfigMap CI/CD workflows (dev, sandbox, prod ci.yml + disaster.yml)
- **Notes:**

### P1-T13: Update local development settings

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Notes:**

### P1-T14: Security remediation

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Add `*.tfstate` to `.gitignore` in terraform-dev and terraform-prod
  - [ ] Fix `s3.tf:246` lifecycle bucket reference (dev)
  - [ ] Remove plaintext Elasticsearch credentials from configmap-prod `sales.yml`
- **Notes:**

### P1-T15: Temporarily exclude RDS cluster from Terraform

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Comment out `aws_rds_cluster` + `aws_rds_cluster_instance` in terraform-prod `rds.tf`
  - [ ] Comment out same in terraform-dev `rds.tf`
- **Notes:**

### P1-T16: Set temporary `production-eu` domain mapping in CDK

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] `ServerlessApiStackHelper.cs:47` (ticketing-platform-tools)
  - [ ] `GatewayStack.cs:32` (gateway)
  - [ ] `GatewayStack.cs:107` (gateway)
  - [ ] `InternalHostedZoneStack.cs:15` (infrastructure)
  - [ ] `InternalCertificateStack.cs:15` (infrastructure)
  - [ ] `Geidea ApiStack.cs:32` (geidea)
  - [ ] `Ecwid ApiStack.cs:32` (ecwid-integration)
- **Notes:**

### P1-T17: Run tests

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] `dotnet test` in each .NET repo with changes
  - [ ] `npm run test && npm run typescript` in dashboard
- **Notes:**

### P1-T18: Verify zero me-south-1 references

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Notes:**
- **Grep output (should be empty):**

### P1-T19: Merge and publish ticketing-platform-tools NuGet package

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Substeps:**
  - [ ] Merge hotfix branch to master in ticketing-platform-tools
  - [ ] Push to trigger nuget.yml workflow
  - [ ] Wait for workflow completion — record version number
  - [ ] Bump TP.Tools.\* version in all 25 service repos
  - [ ] Commit version bump in each repo
  - [ ] Verify build with one service (`dotnet build`)
- **Outputs:**
  - `NUGET_VERSION_1`:
- **Notes:**

### P1-T20: Confirm no other repos merged yet

- **Status:** `PENDING`
- **Started:**
- **Completed:**
- **Notes:**

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
