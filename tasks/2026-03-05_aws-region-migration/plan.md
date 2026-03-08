# AWS Region Migration Plan: me-south-1 to eu-central-1

- [Context](#context)
- [Complete "me-south-1" Reference Inventory](#complete-me-south-1-reference-inventory)
  - [Category 1: Terraform Files](#category-1-terraform-files)
  - [Category 2: CDK env-var JSON Files (~40 files)](#category-2-cdk-env-var-json-files-40-files)
  - [Category 3: aws-lambda-tools-defaults.json (32+ files)](#category-3-aws-lambda-tools-defaultsjson-32-files)
  - [Category 4: Infrastructure C# Code (2 files)](#category-4-infrastructure-c-code-2-files)
  - [Category 5: Test Files (lower priority, ~6 files)](#category-5-test-files-lower-priority-6-files)
  - [Category 6: ConfigMap YAML Files](#category-6-configmap-yaml-files)
  - [Category 7: Mobile Scanner CI/CD (1 file, 3 references)](#category-7-mobile-scanner-cicd-1-file-3-references)
  - [Category 8: Dashboard CSP (1 file)](#category-8-dashboard-csp-1-file)
  - [Category 9: CDK Context Cache Files (DELETE)](#category-9-cdk-context-cache-files-delete)
  - [Category 10: Local Development Settings (lowest priority)](#category-10-local-development-settings-lowest-priority)
- [S3 Bucket Naming Strategy](#s3-bucket-naming-strategy)
- [Phase 1: Code Preparation (No Infrastructure Changes)](#phase-1-code-preparation-no-infrastructure-changes)
  - [Tasks](#tasks)
- [Phase 2: Dev+Sandbox Foundation](#phase-2-devsandbox-foundation)
  - [2.1 Create Terraform State Bucket](#21-create-terraform-state-bucket)
  - [2.2 Replicate Secrets Manager](#22-replicate-secrets-manager)
  - [2.3 Terraform Apply](#23-terraform-apply)
  - [2.4 Populate Manual SSM Parameters](#24-populate-manual-ssm-parameters)
  - [2.5 Aurora Global Database](#25-aurora-global-database)
  - [2.6 S3 Cross-Region Replication](#26-s3-cross-region-replication)
  - [2.7 DynamoDB Tables](#27-dynamodb-tables)
  - [Phase 2 Verification Checklist](#phase-2-verification-checklist)
- [Phase 3: Dev+Sandbox Services](#phase-3-devsandbox-services)
  - [3.1 Infrastructure CDK (11 Stacks — Strict Order)](#31-infrastructure-cdk-11-stacks--strict-order)
  - [3.2 Update Connection Strings](#32-update-connection-strings)
  - [3.3 Per-Service CDK (20 Services)](#33-per-service-cdk-20-services)
  - [3.4 Event Flow Validation](#34-event-flow-validation)
  - [Phase 3 Verification Checklist](#phase-3-verification-checklist)
- [Phase 4: Dev+Sandbox Cutover (Maintenance Window)](#phase-4-devsandbox-cutover-maintenance-window)
  - [4.1 Pre-Cutover Checks](#41-pre-cutover-checks)
  - [4.2 Stop me-south-1 Traffic](#42-stop-me-south-1-traffic)
  - [4.3 Aurora Switchover](#43-aurora-switchover)
  - [4.4 DNS Cutover](#44-dns-cutover)
  - [4.5 Update GitHub Secrets](#45-update-github-secrets)
  - [4.6 Merge Feature Branches \& Deploy Frontends](#46-merge-feature-branches--deploy-frontends)
  - [4.7 End-to-End Validation](#47-end-to-end-validation)
  - [4.8 Rollback Procedure](#48-rollback-procedure)
  - [4.9 Post-Cutover](#49-post-cutover)
- [Phase 5: Production Foundation](#phase-5-production-foundation)
  - [5.1 State Bucket](#51-state-bucket)
  - [5.2 Complete Security Remediation](#52-complete-security-remediation)
  - [5.3 Replicate Prod Secrets](#53-replicate-prod-secrets)
  - [5.4 Terraform Apply (Prod)](#54-terraform-apply-prod)
  - [5.5 Aurora Global Database (Prod)](#55-aurora-global-database-prod)
  - [5.6 S3 CRR (Prod Buckets)](#56-s3-crr-prod-buckets)
  - [5.7 Populate Prod SSM Parameters](#57-populate-prod-ssm-parameters)
  - [5.8 Deploy All CDK Stacks (Prod)](#58-deploy-all-cdk-stacks-prod)
  - [5.9 Pre-Cutover Validation](#59-pre-cutover-validation)
- [Phase 6: Production Cutover (Scheduled Maintenance Window)](#phase-6-production-cutover-scheduled-maintenance-window)
  - [Additional Prod Safety](#additional-prod-safety)
  - [Cutover Steps](#cutover-steps)
  - [Post-Cutover Monitoring (72 hours)](#post-cutover-monitoring-72-hours)
- [Post-Migration Cleanup (After 7-Day Stability Window)](#post-migration-cleanup-after-7-day-stability-window)
  - [Data Stores](#data-stores)
  - [Infrastructure](#infrastructure)
  - [Configuration](#configuration)
  - [Security](#security)
  - [Documentation](#documentation)
- [Risk Matrix](#risk-matrix)


## Context

The MDLBEAST Ticketing Platform must migrate from AWS me-south-1 (Bahrain) to eu-central-1 (Frankfurt) due to infrastructure instability caused by regional military conflicts. This is a full cutover of a 30+ service serverless microservices platform across two AWS accounts (dev/sandbox: `307824719505`, production: `660748123249`).

**Supporting research:** `.planning/research/ARCHITECTURE.md`, `PITFALLS.md`, `STACK.md`

**Migration order:** Dev+Sandbox (same account) first → validate → Production (separate account)

**Migration strategy:** Greenfield infrastructure in eu-central-1 (new Terraform state, new CDK stacks), with Aurora Global Database for zero-data-loss database cutover and S3 CRR for object replication.

---

## Complete "me-south-1" Reference Inventory

### Category 1: Terraform Files

| File | What to Change |
|------|---------------|
| `ticketing-platform-terraform-dev/dev/main.tf:7,14` | Backend region + provider region → `eu-central-1` |
| `ticketing-platform-terraform-dev/dev/main.tf:5` | Backend bucket → `ticketing-terraform-dev-eu` |
| `ticketing-platform-terraform-dev/dev/variables.tf:42,47,52` | AZ defaults → `eu-central-1a/b/c` |
| `ticketing-platform-terraform-dev/dev/variables.tf:64` | AMI ID → eu-central-1 equivalent |
| `ticketing-platform-terraform-dev/dev/rds.tf:162` | `availability_zones` → `["eu-central-1a","eu-central-1b","eu-central-1c"]` |
| `ticketing-platform-terraform-dev/dev/secretmanager.tf:2` | Hardcoded ARN → name-based lookup |
| `ticketing-platform-terraform-prod/prod/main.tf:9,16` | Backend region + provider region → `eu-central-1` |
| `ticketing-platform-terraform-prod/prod/main.tf:7` | Backend bucket → `ticketing-terraform-prod-eu` |
| `ticketing-platform-terraform-prod/prod/variables.tf:42,47,52` | AZ defaults → `eu-central-1a/b/c` |
| `ticketing-platform-terraform-prod/prod/variables.tf:65` | AMI ID → eu-central-1 equivalent |
| `ticketing-platform-terraform-prod/prod/rds.tf:200` | `availability_zones` → `["eu-central-1a","eu-central-1b","eu-central-1c"]` |
| `ticketing-platform-terraform-prod/prod/secretmanager.tf:4` | Hardcoded ARN → name-based lookup |
| `ticketing-platform-terraform-prod/prod/waf.tf:8,73` | ALB ARN + IP set ARN with `me-south-1` → new eu-central-1 ARNs |

**Security remediation (prod only):**

| File | Variable | Issue |
|------|----------|-------|
| `ticketing-platform-terraform-prod/prod/variables.tf:97` | `opensearch_pass` | Plaintext → Secrets Manager |
| `ticketing-platform-terraform-prod/prod/variables.tf:117` | `rds_pass` | Plaintext → Secrets Manager |
| `ticketing-platform-terraform-prod/prod/variables.tf:125` | `rds_pass_inventory` | Plaintext → Secrets Manager |

**EKS remnants to clean up:**

| File | Action |
|------|--------|
| `terraform-dev/dev/iam-eks.tf` | Remove or rename IAM policies |
| `terraform-prod/prod/eks-subnet.tf` | Remove |
| `terraform-prod/prod/msk.tf` | Remove (marked `/// probably delete`) |
| `terraform-dev/dev/lambda-subnet.tf` | Rename `eks-*` tags to `lambda-*` |

### Category 2: CDK env-var JSON Files (~40 files)

All `env-var.{dev,sandbox,prod,demo}.json` files with `"STORAGE_REGION": "me-south-1"` across these services:

- `ticketing-platform-access-control/src/TP.AccessControl.Cdk/`
- `ticketing-platform-catalogue/src/TP.Catalogue.Cdk/`
- `ticketing-platform-distribution-portal/src/TP.DistributionPortal.Cdk/`
- `ticketing-platform-geidea/src/TP.Geidea.Cdk/`
- `ticketing-platform-integration/src/TP.Integration.Cdk/`
- `ticketing-platform-inventory/src/TP.Inventory.Cdk/`
- `ticketing-platform-loyalty/src/TP.Loyalty.Cdk/`
- `ticketing-platform-marketplace-service/src/TP.Marketplace.Cdk/`
- `ticketing-platform-media/src/TP.Media.Cdk/`
- `ticketing-platform-organizations/src/Organizations/TP.Organizations.Cdk/`
- `ticketing-platform-pricing/src/TP.Pricing.Cdk/`
- `ticketing-platform-reporting-api/src/TP.ReportingService.Cdk/`
- `ticketing-platform-sales/src/TP.Sales.Cdk/`
- `ticketing-platform-transfer/src/TP.Transfer.Cdk/`
- `ticketing-platform-tools/Debug.Cdk/`

**Bulk update script:**
```bash
find . -name "env-var.*.json" -not -path "*/node_modules/*" -not -path "*/.terraform/*" \
  -not -path "*/bin/*" -not -path "*/obj/*" -not -path "*/cdk.out/*" \
  -exec grep -l "me-south-1" {} \; | while read f; do
  sed -i '' 's/"STORAGE_REGION": "me-south-1"/"STORAGE_REGION": "eu-central-1"/g' "$f"
done
```

### Category 3: aws-lambda-tools-defaults.json (32+ files)

Every Lambda project directory with `"region": "me-south-1"`:

1. `ticketing-platform-access-control/src/TP.AccessControl.{BackgroundJobs,Consumers}/`
2. `ticketing-platform-csv-generator/TP.CSVGenerator.Consumers/`
3. `ticketing-platform-distribution-portal/src/TP.DistributionPortal.{BackgroundJobs,Consumers}/`
4. `ticketing-platform-extension-api/TP.Extensions.{BackgroundJobs,Consumers}/`
5. `ticketing-platform-extension-deployer/TP.Extensions.Deployer.Lambda/`
6. `ticketing-platform-extension-executor/TP.Extensions.Executor.Lambda/`
7. `ticketing-platform-extension-log-processor/TP.Extensions.LogsProcessor.Lambda/`
8. `ticketing-platform-gateway/src/Gateway/`
9. `ticketing-platform-geidea/src/TP.Geidea.{BackgroundJobs,Lambda.Balance}/`
10. `ticketing-platform-integration/src/TP.Integration.{BackgroundJobs,Consumers}/`
11. `ticketing-platform-inventory/src/TP.Inventory.{BackgroundJobs,Consumers}/`
12. `ticketing-platform-loyalty/src/TP.Loyalty.{BackgroundJobs,Consumers}/`
13. `ticketing-platform-marketplace-service/src/TP.Marketplace.{BackgroundJobs,Consumers}/`
14. `ticketing-platform-media/src/TP.Media.{BackgroundJobs,Consumers}/`
15. `ticketing-platform-organizations/src/Organizations/TP.Organizations.{BackgroundJobs,Consumers}/`
16. `ticketing-platform-pdf-generator/TP.PdfGenerator.Consumers/`
17. `ticketing-platform-pricing/src/TP.Pricing.Consumers/`
18. `ticketing-platform-reporting-api/src/TP.ReportingService.{BackgroundJobs,Consumers}/`
19. `ticketing-platform-sales/src/TP.Sales.{BackgroundJobs,Consumers}/`
20. `ticketing-platform-transfer/src/TP.Transfer.{BackgroundJobs,Consumers}/`

**Bulk update script:**
```bash
find . -name "aws-lambda-tools-defaults.json" \
  -not -path "*/node_modules/*" -not -path "*/.terraform/*" \
  -not -path "*/bin/*" -not -path "*/obj/*" -not -path "*/cdk.out/*" \
  -exec grep -l "me-south-1" {} \; | while read f; do
  sed -i '' 's/"region": "me-south-1"/"region": "eu-central-1"/g' "$f"
done
```

### Category 4: Infrastructure C# Code (2 files)

| File | Line | Change |
|------|------|--------|
| `ticketing-platform-infrastructure/TP.Infrastructure.SlackNotifier/Services/EnvironmentService.cs` | 24 | `?? "me-south-1"` → `?? "eu-central-1"` |
| `ticketing-platform-infrastructure/TP.Infrastructure.SlackNotifier/Services/XRayInsightSlackService.cs` | 58 | `?? "me-south-1"` → `?? "eu-central-1"` |

### Category 5: Test Files (lower priority, ~6 files)

- `ticketing-platform-media/src/Tests/TP.Media.IntegrationTests/ApplicationFactory.cs:28-29`
- `ticketing-platform-catalogue/src/Tests/TP.Catalogue.IntegrationTests/ApplicationFactory.cs:39-40`
- `ticketing-platform-organizations/src/Organizations/Tests/TP.Organizations.IntegrationTests/ApplicationFactory.cs:37-38`
- `ticketing-platform-inventory/src/Tests/TP.Inventory.IntegrationTests/ApplicationFactory.cs:58-59`
- `ticketing-platform-pricing/src/Tests/TP.Pricing.IntegrationTests/ApplicationFactory.cs:116-117`
- `ticketing-platform-infrastructure/TP.Infrastructure.Tests/SlackNotifier/` (multiple test files)

### Category 6: ConfigMap YAML Files

**Dev:**
- `ticketing-platform-configmap-dev/manifests/{access-control,integration,media,reporting,sales,transfer}-dev.yml` — `STORAGE_REGION`
- `ticketing-platform-configmap-dev/secretstore.yml` — `region: me-south-1`

**Sandbox:**
- `ticketing-platform-configmap-sandbox/manifests/{integration,media,reporting,sales,transfer}-sandbox.yml` — `STORAGE_REGION`
- `ticketing-platform-configmap-sandbox/secretstore.yml` — `region: me-south-1`

**Prod:**
- `ticketing-platform-configmap-prod/manifests-new/{integration,media,reporting,sales,transfer}.yml` — `STORAGE_REGION`
- `ticketing-platform-configmap-prod/manifests-new/sales.yml` — also has `Logging__Elasticsearch__Uri` with me-south-1 OpenSearch endpoint

### Category 7: Mobile Scanner CI/CD (1 file, 3 references)

| File | Lines | Change |
|------|-------|--------|
| `ticketing-platform-mobile-scanner/.github/workflows/release-build.yml` | 172 | `s3.me-south-1.amazonaws.com` → `s3.eu-central-1.amazonaws.com` |
| Same file | 200, 208 | `AWS_DEFAULT_REGION: me-south-1` → `AWS_DEFAULT_REGION: eu-central-1` |

### Category 8: Dashboard CSP (1 file)

`ticketing-platform-dashboard/vercel.json:24` — 6 S3 URLs in CSP `connect-src`:
- `dev-pdf-tickets.s3.me-south-1.amazonaws.com` → `.s3.eu-central-1.amazonaws.com`
- `tickets-pdf-download.s3.me-south-1.amazonaws.com` → `.s3.eu-central-1.amazonaws.com`
- `sandbox-pdf-tickets.s3.me-south-1.amazonaws.com` → `.s3.eu-central-1.amazonaws.com`
- `ticketing-sandbox-media.s3.me-south-1.amazonaws.com` → `.s3.eu-central-1.amazonaws.com`
- `ticketing-dev-media.s3.me-south-1.amazonaws.com` → `.s3.eu-central-1.amazonaws.com`
- `ticketing-prod-media.s3.me-south-1.amazonaws.com` → `.s3.eu-central-1.amazonaws.com`

**Note:** If S3 bucket names change (adding `-eu` suffix), these URLs must also reflect new bucket names.

### Category 9: CDK Context Cache Files (DELETE)

These are auto-generated caches containing me-south-1 VPC/subnet lookups. Delete them; they regenerate on `cdk synth`:
- `ticketing-platform-infrastructure/TP.Infrastructure.Cdk/cdk.context.json`
- `ticketing-platform-gateway/src/Gateway.Cdk/cdk.context.json`
- `ticketing-platform-media/src/TP.Media.Cdk/cdk.context.json`

### Category 10: Local Development Settings (lowest priority)

These contain me-south-1 RDS hosts, SQS URLs, OpenSearch URIs — update after new endpoints exist:
- `ticketing-platform-media/src/TP.Media.API/appsettings.Development.json`
- `ticketing-platform-pricing/src/TP.Pricing.API/Properties/launchSettings.json`
- `ticketing-platform-extension-api/TP.Extensions.API/Properties/launchSettings.json`
- `ticketing-platform-distribution-portal/src/TP.DistributionPortal.API/Properties/launchSettings.json`
- `ticketing-platform-gateway/src/Gateway/Properties/launchSettings.json`
- `ticketing-platform-sales/src/TP.Sales.API/Properties/launchSettings.json`

---

## S3 Bucket Naming Strategy

S3 bucket names are globally unique. Cannot reuse names while old buckets exist.

| me-south-1 Bucket | eu-central-1 Bucket | Purpose |
|---|---|---|
| `dev-pdf-tickets` | `dev-pdf-tickets-eu` | Dev PDF tickets |
| `sandbox-pdf-tickets` | `sandbox-pdf-tickets-eu` | Sandbox PDF tickets |
| `pdf-tickets-prod` | `pdf-tickets-prod-eu` | Prod PDF tickets |
| `tickets-pdf-download` | `tickets-pdf-download-eu` | Prod PDF download |
| `pdf-tickets-download` | `pdf-tickets-download-eu` | Dev PDF download |
| `ticketing-dev-csv-reports` | `ticketing-dev-csv-reports-eu` | Dev CSV reports |
| `ticketing-sandbox-csv-reports` | `ticketing-sandbox-csv-reports-eu` | Sandbox CSV reports |
| `ticketing-csv-reports` | `ticketing-csv-reports-eu` | Prod CSV reports |
| `ticketing-{env}-media` | `ticketing-{env}-media-eu` | Media uploads |
| `ticketing-{env}-extended-message` | CDK creates with new name | Large event payloads |
| `ticketing-terraform-dev` | `ticketing-terraform-dev-eu` | Terraform state |
| `ticketing-terraform-prod` | `ticketing-terraform-prod-eu` | Terraform state |

Update all references: Terraform `s3.tf`/`variables.tf`, CDK env-var files, `vercel.json` CSP, CloudFront origins.

---

## Phase 1: Code Preparation (No Infrastructure Changes)

**Duration:** 1-2 days | **Risk:** LOW | **Rollback:** Revert git commits

### Tasks

1. **Create feature branches** in each repo: `feature/region-migration-eu-central-1`

2. **Update all hardcoded references** (Categories 1-10 above)
   - Terraform files (both repos)
   - CDK env-var JSON files (bulk script)
   - aws-lambda-tools-defaults.json (bulk script)
   - Infrastructure C# code
   - Mobile scanner CI/CD
   - Dashboard vercel.json
   - ConfigMap YAMLs
   - Delete CDK context caches

3. **Security remediation** — Move prod plaintext creds to Secrets Manager

4. **Terraform cleanup** — Remove/rename EKS remnants

5. **Lower DNS TTLs** to 60s, 48+ hours before cutover:
   ```bash
   # List current TTLs for each hosted zone
   aws route53 list-resource-record-sets --hosted-zone-id <zone-id> \
     --query 'ResourceRecordSets[?TTL > `60`]'
   ```

6. **Run all tests** to verify code changes don't break anything:
   ```bash
   # .NET services
   dotnet test
   # Dashboard
   npm run test && npm run typescript
   ```

7. **Verify** zero `me-south-1` references remain:
   ```bash
   grep -r "me-south-1" --include="*.tf" --include="*.cs" --include="*.json" \
     --include="*.yml" --include="*.yaml" --exclude-dir={.terraform,node_modules,bin,obj,cdk.out,.git}
   ```

8. **DO NOT merge yet.** Keep on feature branches until infrastructure is ready.

---

## Phase 2: Dev+Sandbox Foundation

**Duration:** 2-3 days | **Risk:** MEDIUM | **Account:** `307824719505` | **Rollback:** Delete eu-central-1 resources

### 2.1 Create Terraform State Bucket

```bash
aws s3 mb s3://ticketing-terraform-dev-eu --region eu-central-1
aws s3api put-bucket-versioning --bucket ticketing-terraform-dev-eu \
  --versioning-configuration Status=Enabled --region eu-central-1
aws s3api put-bucket-encryption --bucket ticketing-terraform-dev-eu \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  --region eu-central-1
```

### 2.2 Replicate Secrets Manager

```bash
# Terraform bootstrap secret
aws secretsmanager replicate-secret-to-regions \
  --secret-id "terraform" \
  --add-replica-regions Region=eu-central-1 \
  --region me-south-1

# All service secrets (script loop)
aws secretsmanager list-secrets --filters Key=name,Values="/dev/" \
  --query 'SecretList[].Name' --output text --region me-south-1 | \
  tr '\t' '\n' | while read secret; do
  aws secretsmanager replicate-secret-to-regions \
    --secret-id "$secret" \
    --add-replica-regions Region=eu-central-1 \
    --region me-south-1
done

# Repeat for /sandbox/ and /rds/ prefixes

# Verify
aws secretsmanager list-secrets --region eu-central-1 \
  --query 'SecretList[*].Name'
```

### 2.3 Terraform Apply

**Important:** Comment out RDS cluster/instance resources before applying. Aurora Global Database (step 2.5) will manage data migration. Import into Terraform state after cutover.

```bash
cd ticketing-platform-terraform-dev/dev
terraform init -reconfigure   # Points to new eu-central-1 state bucket
terraform plan                # Review carefully — should show all creates, zero destroys
terraform apply
```

**Creates:** VPC (10.10.0.0/16), 3x subnets per tier, NAT Gateways, Route53 zones, S3 buckets (new names), KMS keys, ECR, IAM roles, security groups, CloudFront distributions, OpenVPN EC2.

**Verification:**
```bash
aws ec2 describe-vpcs --region eu-central-1 \
  --filters "Name=tag:Name,Values=ticketing" --query 'Vpcs[0].VpcId'
aws ec2 describe-subnets --region eu-central-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" --query 'Subnets | length(@)'
```

### 2.4 Populate Manual SSM Parameters

These bridge Terraform → CDK and must exist before any CDK deploy:

```bash
# VPC name (CDK's CdkStackUtilities.GetTicketingVpc reads this)
for env in dev sandbox; do
  aws ssm put-parameter --name "/$env/tp/VPC_NAME" \
    --type String --value "ticketing" --region eu-central-1
done

# RDS cluster references (after Global Database is set up in 2.5)
aws ssm put-parameter --name "/rds/ticketing-cluster-identifier" \
  --type String --value "ticketing-eu" --region eu-central-1

RDS_SG=$(aws ec2 describe-security-groups --region eu-central-1 \
  --filters "Name=group-name,Values=rds-one" \
  --query 'SecurityGroups[0].GroupId' --output text)
aws ssm put-parameter --name "/rds/ticketing-cluster-sg" \
  --type String --value "$RDS_SG" --region eu-central-1

# Subnet IDs for extension deployer
SUBNET_1=$(aws ec2 describe-subnets --region eu-central-1 \
  --filters "Name=tag:Name,Values=eks-subnet-1a-prod" \
  --query 'Subnets[0].SubnetId' --output text)
SUBNET_2=$(aws ec2 describe-subnets --region eu-central-1 \
  --filters "Name=tag:Name,Values=eks-subnet-1b-prod" \
  --query 'Subnets[0].SubnetId' --output text)
SUBNET_3=$(aws ec2 describe-subnets --region eu-central-1 \
  --filters "Name=tag:Name,Values=eks-subnet-1c-prod" \
  --query 'Subnets[0].SubnetId' --output text)

for env in dev sandbox; do
  aws ssm put-parameter --name "/$env/tp/SUBNET_1" --type String --value "$SUBNET_1" --region eu-central-1
  aws ssm put-parameter --name "/$env/tp/SUBNET_2" --type String --value "$SUBNET_2" --region eu-central-1
  aws ssm put-parameter --name "/$env/tp/SUBNET_3" --type String --value "$SUBNET_3" --region eu-central-1
done

# Slack webhook URLs (copy from me-south-1)
for env in dev sandbox; do
  for param in ErrorsWebhookUrl OperationalErrorsWebhookUrl SuspiciousOrdersWebhookUrl; do
    VALUE=$(aws ssm get-parameter --name "/$env/tp/SlackNotification/$param" \
      --with-decryption --region me-south-1 --query 'Parameter.Value' --output text)
    aws ssm put-parameter --name "/$env/tp/SlackNotification/$param" \
      --type SecureString --value "$VALUE" --region eu-central-1
  done
  # Ignored error patterns
  VALUE=$(aws ssm get-parameter --name "/$env/tp/SlackNotification/IgnoredErrorsPatterns" \
    --region me-south-1 --query 'Parameter.Value' --output text)
  aws ssm put-parameter --name "/$env/tp/SlackNotification/IgnoredErrorsPatterns" \
    --type StringList --value "$VALUE" --region eu-central-1
done
```

**Verification:**
```bash
aws ssm get-parameters-by-path --path "/" --recursive --region eu-central-1 \
  --query 'Parameters[*].Name'
```

### 2.5 Aurora Global Database

```bash
# 1. Convert existing me-south-1 cluster to Global Database
aws rds create-global-cluster \
  --global-cluster-identifier ticketing-global \
  --source-db-cluster-identifier arn:aws:rds:me-south-1:307824719505:cluster:ticketing \
  --region me-south-1

# 2. Add eu-central-1 as secondary
aws rds create-db-cluster \
  --db-cluster-identifier ticketing-eu \
  --global-cluster-identifier ticketing-global \
  --engine aurora-postgresql \
  --engine-version 15.12 \
  --region eu-central-1 \
  --db-subnet-group-name postgres \
  --vpc-security-group-ids $RDS_SG

# 3. Add serverless instance(s)
aws rds create-db-instance \
  --db-instance-identifier ticketing-eu-instance-0 \
  --db-cluster-identifier ticketing-eu \
  --engine aurora-postgresql \
  --db-instance-class db.serverless \
  --region eu-central-1

# 4. Monitor replication lag until it reaches ~0
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS --metric-name AuroraGlobalDBReplicationLag \
  --dimensions Name=DBClusterIdentifier,Value=ticketing-eu \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 --statistics Average --region eu-central-1
```

Replication is continuous at the storage level. Zero data loss at cutover.

### 2.6 S3 Cross-Region Replication

```bash
# 1. Enable versioning on source buckets (if not already)
for bucket in dev-pdf-tickets sandbox-pdf-tickets ticketing-dev-csv-reports \
  ticketing-sandbox-csv-reports ticketing-dev-media ticketing-sandbox-media; do
  aws s3api put-bucket-versioning --bucket $bucket \
    --versioning-configuration Status=Enabled --region me-south-1
done

# 2. Create replication IAM role (or use Terraform to create it)

# 3. Configure CRR per bucket (example for dev-pdf-tickets)
aws s3api put-bucket-replication --bucket dev-pdf-tickets \
  --replication-configuration '{
    "Role": "arn:aws:iam::307824719505:role/s3-replication-role",
    "Rules": [{
      "ID": "replicate-to-eu",
      "Status": "Enabled",
      "Filter": {"Prefix": ""},
      "Destination": {
        "Bucket": "arn:aws:s3:::dev-pdf-tickets-eu",
        "StorageClass": "STANDARD",
        "EncryptionConfiguration": {
          "ReplicaKmsKeyID": "<eu-central-1-kms-key-arn>"
        }
      },
      "SourceSelectionCriteria": {
        "SseKmsEncryptedObjects": {"Status": "Enabled"}
      }
    }]
  }' --region me-south-1

# 4. Batch Replication for existing objects (CRR only handles new objects)
# Use S3 Batch Replication job via AWS Console or CLI
```

### 2.7 DynamoDB Tables

DynamoDB tables in this platform are CDK-managed (XRay dedup, cache tables) and are ephemeral. They'll be created fresh by CDK in Phase 3. **No Global Tables replication needed.**

### Phase 2 Verification Checklist

- [ ] VPC exists in eu-central-1 with correct CIDR and 3 AZs
- [ ] All subnets created (RDS, Lambda, management tiers)
- [ ] NAT Gateways operational with Elastic IPs
- [ ] Route53 hosted zones created (dev, sandbox)
- [ ] Aurora Global Database secondary replicating (lag <1s)
- [ ] S3 CRR active — new objects replicating, batch job running for existing
- [ ] All SSM parameters populated
- [ ] All secrets replicated in eu-central-1
- [ ] KMS key created in eu-central-1
- [ ] Security groups configured

---

## Phase 3: Dev+Sandbox Services

**Duration:** 1-2 days | **Risk:** MEDIUM | **Rollback:** `cdk destroy` all stacks

### 3.1 Infrastructure CDK (11 Stacks — Strict Order)

```bash
cd ticketing-platform-infrastructure
export CDK_DEFAULT_ACCOUNT=307824719505
export CDK_DEFAULT_REGION=eu-central-1

# Deploy for dev (then repeat for sandbox)
export ENV_NAME=dev

# 1. EventBus (foundational — no dependencies)
cdk deploy TP-EventBusStack-dev --require-approval never

# 2. Consumer SQS queues (creates queues + stores ARNs in SSM)
cdk deploy TP-ConsumersSqsStack-dev --require-approval never

# 3. Consumer subscriptions (needs EventBus + SQS queue ARNs)
cdk deploy TP-ConsumerSubscriptionStack-dev --require-approval never

# 4. Extended message S3 bucket (no dependencies)
cdk deploy TP-ExtendedMessageS3BucketStack-dev --require-approval never

# 5. Internal hosted zone (needs VPC)
cdk deploy TP-InternalHostedZoneStack-dev --require-approval never

# 6. Internal certificate (needs hosted zone + public Route53 zone)
cdk deploy TP-InternalCertificateStack-dev --require-approval never

# 7. Monitoring (needs EventBus)
cdk deploy TP-MonitoringStack-dev --require-approval never

# 8. API Gateway VPC endpoint (needs VPC — shared for dev/sandbox)
cdk deploy TP-ApiGatewayVpcEndpointStack --require-approval never

# 9. RDS Proxy (needs VPC + RDS cluster + SSM params)
cdk deploy TP-RdsProxyStack --require-approval never

# 10. Slack notification (needs SSM webhook URLs)
cdk deploy TP-SlackNotificationStack-dev --require-approval never

# 11. XRay insight notification (needs EventBus + SSM webhooks)
cdk deploy TP-XRayInsightNotificationStack-dev --require-approval never
```

### 3.2 Update Connection Strings

After RDS Proxy deploys, get the new endpoint and update service secrets:

```bash
RDS_PROXY_ENDPOINT=$(aws rds describe-db-proxies --region eu-central-1 \
  --query 'DBProxies[0].Endpoint' --output text)

# Update each service's CONNECTION_STRINGS in Secrets Manager
# Format: Host=<endpoint>;Database=<db>;Username=<user>;Password=<pass>
```

### 3.3 Per-Service CDK (20 Services)

Deploy services in this order (gateway first, then by dependency):

```
 1. Gateway              11. Loyalty
 2. Catalogue            12. Marketplace
 3. Organizations        13. Integration
 4. Inventory            14. Distribution Portal
 5. Pricing              15. Geidea
 6. Sales                16. Extension API
 7. Access Control       17. Extension Deployer
 8. Media                18. Extension Executor
 9. Reporting API        19. Extension Log Processor
10. Transfer             20. CSV Generator / PDF Generator
```

For each service:
```bash
cd ticketing-platform-<service>/src/TP.<Service>.Cdk
export CDK_DEFAULT_REGION=eu-central-1 ENV_NAME=dev

# 1. DB Migrator
cdk deploy TP-DbMigratorStack-<service>-dev --require-approval never

# 2. Run migration
aws lambda invoke --function-name "<service>-db-migrator-lambda-dev" \
  --payload '{}' --region eu-central-1 /dev/null

# 3. Create log groups
aws logs create-log-group --log-group-name "/aws/lambda/<service>-serverless-dev-function" --region eu-central-1
aws logs create-log-group --log-group-name "/aws/lambda/<service>-consumers-lambda-dev" --region eu-central-1

# 4-6. Deploy remaining stacks
cdk deploy TP-ConsumersStack-<service>-dev --require-approval never
cdk deploy TP-BackgroundJobsStack-<service>-dev --require-approval never
cdk deploy TP-ServerlessBackendStack-<service>-dev --require-approval never
```

### 3.4 Event Flow Validation

```bash
# Verify all components exist
aws events describe-event-bus --name "event-bus-dev" --region eu-central-1
aws sqs list-queues --region eu-central-1 --queue-name-prefix "TP-"
aws lambda list-functions --region eu-central-1 \
  --query 'Functions[?contains(FunctionName, `-dev-`)].FunctionName'

# Publish test event
aws events put-events --entries '[{
  "Source": "TicketingPlatform",
  "DetailType": "TestEvent",
  "Detail": "{\"test\": true}",
  "EventBusName": "event-bus-dev"
}]' --region eu-central-1
```

### Phase 3 Verification Checklist

- [ ] All 11 infrastructure stacks in CREATE_COMPLETE (both dev + sandbox)
- [ ] All 20 service stacks deployed
- [ ] All DB migrations ran successfully
- [ ] Lambda functions responding (test invoke each)
- [ ] EventBridge rules → SQS queues (18 consumers)
- [ ] Internal DNS resolving (`*.internal.dev.tickets.mdlbeast.net`)
- [ ] API Gateway endpoints accessible via VPC endpoint
- [ ] RDS Proxy connecting to Aurora

---

## Phase 4: Dev+Sandbox Cutover (Maintenance Window)

**Duration:** 2-4 hours | **Risk:** HIGH | **Rollback:** Revert DNS + Aurora + GitHub secrets

### 4.1 Pre-Cutover Checks

- [ ] Aurora replication lag = 0
- [ ] S3 CRR fully caught up
- [ ] All stacks deployed and healthy
- [ ] Rollback plan rehearsed

### 4.2 Stop me-south-1 Traffic

```bash
# Set Lambda reserved concurrency to 0 on all dev/sandbox functions
aws lambda list-functions --region me-south-1 \
  --query 'Functions[?contains(FunctionName,`-dev-`) || contains(FunctionName,`-sandbox-`)].FunctionName' \
  --output text | tr '\t' '\n' | while read fn; do
  aws lambda put-function-concurrency --function-name "$fn" \
    --reserved-concurrent-executions 0 --region me-south-1
done

# Wait 5 minutes for in-flight requests to drain
```

### 4.3 Aurora Switchover

```bash
aws rds switchover-global-cluster \
  --global-cluster-identifier ticketing-global \
  --target-db-cluster-identifier arn:aws:rds:eu-central-1:307824719505:cluster:ticketing-eu \
  --region me-south-1

# Wait 5-30 minutes for completion
# Verify eu-central-1 is now the writer
aws rds describe-global-clusters --global-cluster-identifier ticketing-global \
  --query 'GlobalClusters[0].GlobalClusterMembers[*].{ARN:DBClusterArn,Writer:IsWriter}' \
  --region me-south-1
```

### 4.4 DNS Cutover

Update Route53 public records to eu-central-1 API Gateway endpoints. Use weighted routing (0% me-south-1, 100% eu-central-1) for instant rollback.

### 4.5 Update GitHub Secrets

```bash
repos=(
  ticketing-platform-infrastructure ticketing-platform-access-control
  ticketing-platform-catalogue ticketing-platform-sales
  ticketing-platform-inventory ticketing-platform-reporting-api
  ticketing-platform-media ticketing-platform-pricing
  ticketing-platform-transfer ticketing-platform-loyalty
  ticketing-platform-marketplace-service ticketing-platform-organizations
  ticketing-platform-geidea ticketing-platform-csv-generator
  ticketing-platform-integration ticketing-platform-extension-api
  ticketing-platform-extension-executor ticketing-platform-extension-deployer
  ticketing-platform-extension-log-processor ticketing-platform-pdf-generator
  ticketing-platform-gateway ticketing-platform-distribution-portal
  ticketing-platform-tools ticketing-platform-dashboard
  ticketing-platform-distribution-portal-frontend
  ticketing-platform-terraform-dev ticketing-platform-terraform-prod
  ticketing-platform-mobile-scanner
)

for repo in "${repos[@]}"; do
  gh secret set AWS_DEFAULT_REGION --body "eu-central-1" --repo "mdlbeasts/$repo"
done
```

### 4.6 Merge Feature Branches & Deploy Frontends

- Merge all `feature/region-migration-eu-central-1` branches into `development`
- Dashboard: merge vercel.json changes → triggers Vercel redeploy
- Distribution Portal: merge and verify

### 4.7 End-to-End Validation

- [ ] Dashboard login works (Auth0 + API)
- [ ] Create event in catalogue
- [ ] Create tickets in inventory
- [ ] Process test order through sales
- [ ] PDF ticket generation (S3 in eu-central-1)
- [ ] CSV report generation
- [ ] Media upload/download
- [ ] Access control scanning flow
- [ ] Slack notifications arriving (check console links point to eu-central-1)
- [ ] Inter-service event flow (EventBridge → SQS → Consumer)
- [ ] CloudWatch logs populating in eu-central-1

### 4.8 Rollback Procedure

If critical issues found:
1. Revert DNS weights (100% me-south-1, 0% eu-central-1)
2. Aurora switchover back: `aws rds switchover-global-cluster` targeting me-south-1
3. Revert `AWS_DEFAULT_REGION` GitHub secrets to `me-south-1`
4. Remove Lambda concurrency limits on me-south-1 functions
5. Revert code branches

### 4.9 Post-Cutover

- Monitor for 24 hours
- Keep me-south-1 infrastructure intact for 7 days as safety net

---

## Phase 5: Production Foundation

**Duration:** 2-3 days | **Risk:** HIGH | **Account:** `660748123249`

Same as Phase 2 but for production account:

### 5.1 State Bucket
```bash
aws s3 mb s3://ticketing-terraform-prod-eu --region eu-central-1 --profile prod
# Enable versioning + encryption
```

### 5.2 Complete Security Remediation
- Move plaintext passwords from `variables.tf` to Secrets Manager
- Rotate any credentials committed to git history

### 5.3 Replicate Prod Secrets
```bash
aws secretsmanager list-secrets --filters Key=name,Values="/prod/" \
  --query 'SecretList[].Name' --output text --region me-south-1 --profile prod | \
  tr '\t' '\n' | while read secret; do
  aws secretsmanager replicate-secret-to-regions \
    --secret-id "$secret" \
    --add-replica-regions Region=eu-central-1 \
    --region me-south-1 --profile prod
done
```

### 5.4 Terraform Apply (Prod)
```bash
cd ticketing-platform-terraform-prod/prod
terraform init -reconfigure
terraform apply
```

**Additional prod resources:** WAF, Redis/ElastiCache, OpenSearch.

### 5.5 Aurora Global Database (Prod)
```bash
aws rds create-global-cluster \
  --global-cluster-identifier ticketing-prod-global \
  --source-db-cluster-identifier arn:aws:rds:me-south-1:660748123249:cluster:ticketing \
  --region me-south-1 --profile prod

aws rds create-db-cluster \
  --db-cluster-identifier ticketing-prod-eu \
  --global-cluster-identifier ticketing-prod-global \
  --engine aurora-postgresql --engine-version 15.12 \
  --region eu-central-1 --db-subnet-group-name postgres \
  --vpc-security-group-ids $PROD_RDS_SG --profile prod

# 3 serverless instances for prod
for i in 0 1 2; do
  aws rds create-db-instance \
    --db-instance-identifier ticketing-prod-eu-instance-$i \
    --db-cluster-identifier ticketing-prod-eu \
    --engine aurora-postgresql --db-instance-class db.serverless \
    --region eu-central-1 --profile prod
done
```

### 5.6 S3 CRR (Prod Buckets)
- `tickets-pdf-download` → `tickets-pdf-download-eu`
- `ticketing-csv-reports` → `ticketing-csv-reports-eu`
- `pdf-tickets-prod` → `pdf-tickets-prod-eu`
- `ticketing-prod-media` → `ticketing-prod-media-eu`

### 5.7 Populate Prod SSM Parameters
Same as Phase 2.4 but for prod account with prod values.

### 5.8 Deploy All CDK Stacks (Prod)
Same as Phase 3 but with `ENV_NAME=prod`.

### 5.9 Pre-Cutover Validation
Let prod eu-central-1 run in parallel for 24-48 hours. Validate all stacks, DB migrations, and Lambda health.

---

## Phase 6: Production Cutover (Scheduled Maintenance Window)

**Duration:** 4-6 hours | **Risk:** CRITICAL | **Rollback:** Reverse Aurora + DNS + GitHub secrets

### Additional Prod Safety

1. **Final RDS snapshot:**
   ```bash
   aws rds create-db-cluster-snapshot \
     --db-cluster-identifier ticketing \
     --db-cluster-snapshot-identifier ticketing-pre-migration-$(date +%Y%m%d) \
     --region me-south-1 --profile prod
   ```

2. **Verify replication lag = 0** via CloudWatch metrics

3. **Pre-check eu-central-1 service limits:** Lambda concurrency, VPC EIPs, RDS quotas

4. **Notify all stakeholders** with exact timeline

### Cutover Steps

Same as Phase 4:
1. Enter maintenance → stop me-south-1 traffic → drain requests (5 min)
2. Aurora switchover → verify writer in eu-central-1
3. DNS cutover (weighted routing)
4. Update `AWS_DEFAULT_REGION` GitHub secrets for prod repos
5. Merge feature branches to `production`/`master`
6. Full E2E validation (complete ticket lifecycle)
7. Exit maintenance

### Post-Cutover Monitoring (72 hours)

- CloudWatch dashboards for all services
- Slack error channel for elevated error rates
- Sentry for new error patterns
- RDS metrics (connections, latency, CPU)
- S3 access patterns

---

## Post-Migration Cleanup (After 7-Day Stability Window)

### Data Stores
- [ ] Detach me-south-1 from Aurora Global Database → delete old clusters
- [ ] Disable S3 CRR → delete me-south-1 buckets (after confirming all data replicated)
- [ ] Import new RDS cluster into Terraform state

### Infrastructure
- [ ] `cdk destroy` all CloudFormation stacks in me-south-1
- [ ] `terraform destroy` me-south-1 infrastructure (carefully, after all data confirmed)
- [ ] Delete me-south-1 Terraform state buckets
- [ ] Clean up IAM roles/policies specific to me-south-1

### Configuration
- [ ] Promote Secrets Manager replicas to standalone in eu-central-1
- [ ] Verify no remaining GitHub secret references to me-south-1
- [ ] Restore DNS TTLs to normal values (300-3600s)

### Security
- [ ] Rotate all credentials
- [ ] Audit IAM policies for region-specific ARNs
- [ ] Schedule me-south-1 KMS key deletion (7-day min wait)

### Documentation
- [ ] Update CLAUDE.md with new region references
- [ ] Update `.personal/DEPLOYMENT.md` and `.personal/ARCHITECTURE.md`
- [ ] Archive me-south-1 Terraform state for reference

---

## Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Data loss during Aurora switchover | LOW | CRITICAL | Managed switchover (not failover), verify replication lag = 0 |
| S3 objects not replicated | LOW | HIGH | CRR + Batch Replication, verify object counts match |
| CDK stack ordering failure | MEDIUM | MEDIUM | Strict sequential deploy per dependency chain |
| Missing SSM parameter | HIGH | HIGH | Comprehensive param list; verify all exist before CDK |
| CI/CD deploys to wrong region | LOW | HIGH | Freeze deployments during transition; atomic secret update |
| Event flow breaks | MEDIUM | HIGH | All services cut over simultaneously; E2E event chain test |
| DNS propagation delay | LOW | MEDIUM | Lower TTL to 60s, 48h before cutover |
| Cold Aurora with prod load | MEDIUM | HIGH | Increase min ACU during cutover week |
| Plaintext credentials exposed | HIGH | HIGH | Security remediation in Phase 1; rotate after migration |
| eu-central-1 service limits | LOW | HIGH | Pre-check quotas before starting |

---

*Plan created: 2026-03-05*
*Based on research in: `.planning/research/{ARCHITECTURE,PITFALLS,STACK}.md`*
