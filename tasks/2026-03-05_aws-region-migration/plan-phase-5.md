# Phase 5: Dev+Sandbox Migration Plan (eu-central-1)

## Context

Production migration to eu-central-1 completed successfully (Phases 1-4). Dev and sandbox environments remain in me-south-1 and must be rebuilt in eu-central-1. Both environments share AWS account `307824719505`. The user has a local sandbox DB dump that will serve as the starting point for both dev and sandbox databases.

**Key differences from production migration:**
- No temporary domain needed — deploy directly under `dev.tickets.mdlbeast.net` and `sandbox.tickets.mdlbeast.net`
- No AWS Backup restore — user populates DB manually via SSM tunnel from local dump
- Single Terraform apply covers both dev and sandbox (one state file)
- No S3 data restore — fresh empty buckets (acceptable for non-prod)
- me-south-1 dev/sandbox stays running (no decommission)
- Secrets and SSM parameters replicated from me-south-1 (not created from backup files). Backups are last resort only.

**Backup assets (last resort only — prefer live replication from me-south-1):**
- `backup-secrets-dev/` — 23 files (20 service secrets + rds/ticketing-cluster + terraform + devops)
- `backup-secrets-sandbox/` — 21 files (20 service secrets + rds/ticketing-cluster + terraform, no devops)
- `backup-ssm-dev/` — 201 parameter files + `all-params-me-south-1.json`
- `backup-ssm-sandbox/` — 100 parameter files + `all-params-me-south-1.json`

**Branching strategy for deployment:**

Production branch already has all migration changes (merged in Phase 4). The deployment flow must go in reverse: `production` → `sandbox` → `development`. For repos with CDK projects, the approach is:

1. Pull latest `sandbox` branch (or `release/sandbox` if that's the naming)
2. Create `hotfix/sandbox-eu-migration` from `sandbox`
3. Merge `production` (or `master`) into this hotfix branch
4. PR the hotfix into `sandbox` — merge triggers CI/CD deployment to sandbox environment
5. Repeat for `development` branch: create `hotfix/dev-eu-migration`, merge `sandbox` into it, PR into `development`

**CI/CD standard deployment sequence** (from repo workflows):
1. `dotnet restore`
2. `dotnet build --no-restore`
3. `dotnet lambda package` from each Lambda project directory
4. `cdk synth` (validation)
5. `cdk deploy TP-{Stack}-{env} --require-approval never`

**AWS CLI profile:** `--profile AdministratorAccess-307824719505`

---

## Lessons Incorporated from Production Migration

Each item below caused a failure, delay, or deviation during Phases 2-4. The step where each is addressed is noted.

| # | Production Issue | Root Cause | Fix in This Plan |
|---|-----------------|------------|------------------|
| 1 | S3 bucket names not renamed to `-eu` in Terraform (P2-S4) | Phase 1 missed `s3.tf`/`variables.tf`/`mobile.tf` renames | **P5-S1**: Rename all bucket definitions before `terraform apply` |
| 2 | VPC missing `enable_dns_hostnames` (P3-S3) | `vpc.tf` didn't set it explicitly | **P5-S2**: Add to `vpc.tf` before apply |
| 3 | RDS SG missing VPC CIDR ingress on port 5432 (P3-S5-01) | Only had self-referencing rule | **P5-S2**: Add ingress rule to `rds.tf` before apply |
| 4 | SSM subnet params stored full IDs causing double prefix (P3-S5-01) | `CdkStackUtilities.GetSubnets()` prepends `subnet-` | **P5-S5**: Store suffix-only values |
| 5 | Global IAM roles conflict on CDK deploy (P3-S5-01) | IAM is global; me-south-1 roles still exist | **P5-S10**: Use `cdk import` pattern for every stack |
| 6 | Stale IAM inline policies block CDK import (P3-S5-02) | me-south-1 CDK created policies with region-specific ARNs | **P5-S10**: Bulk-delete stale policies before any CDK deploy |
| 7 | Organization SQS queue visibility timeout < Lambda timeout (P3-S5-02) | `_serviceTimeouts` missing Organization entry | Already fixed in infra CDK during prod migration |
| 8 | Log groups must exist before stack deploy (P3-S5-03) | `SubscriptionFilter` references log group at create time | **P5-S10**: Pre-create ALL log groups (serverless + consumers + background-jobs) |
| 9 | pdf-generator Lambda exceeds 250MB (P3-S5-05) | CDK DLLs + SkiaSharp multi-platform runtimes | **P5-S10**: Clean publish dir before deploy |
| 10 | Stale DefaultPolicy inline policies (P3-S5-06, P3-S5-20) | Not caught by bulk deletion | **P5-S10**: Check for DefaultPolicy if deploy fails |
| 11 | extension-deployer is Docker image-based (P3-S5-08) | Not deployable via CDK alone | **P5-S10**: Deploy via `dotnet lambda deploy-function` |
| 12 | ARM64/x86_64 mismatch on Apple Silicon (DIAG-003) | Docker defaults to host arch | **P5-S10**: Always pass `--docker-build-options "--platform linux/amd64"` |
| 13 | `.runtimeconfig.json` missing for non-Web SDK projects (DIAG-001/002) | `dotnet publish` doesn't generate it for class libraries | **P5-S10**: Always use `dotnet lambda package -c Release` |
| 14 | media CDK has IAM user `imgix` (P3-S5-14) | Global IAM user, not just roles | **P5-S10**: Import IAM user in media stack |
| 15 | distribution-portal missing `SalesServiceBaseRoute` (P3-S5-18) | Was in K8s configmap, not Lambda env-var | Already fixed in code during prod migration |
| 16 | CloudFront OAC missing S3 bucket policies (DIAG-005) | Buckets created without policies for CloudFront | **P5-S2**: Add bucket policies in Terraform |
| 17 | `cicd` IAM user missing `cloudfront:CreateInvalidation` (DIAG-004) | Policy not expanded for new CloudFront distributions | **P5-S2**: Add CloudFront policy to `user-cicd.tf` |
| 18 | Stale me-south-1 A records block CDK deploy (P4-S3) | Old DNS records in Route53 zones | **P5-S8**: Delete stale A records before CDK deploy |
| 19 | Secrets had replica status blocking updates (P2-S6, P3-S4) | Replication creates read-only replicas | **P5-S4**: Replicate then immediately promote to standalone |
| 20 | `FINANCE_REPORT_SENDER_CONFIG` had stale RDS cluster ID (P4-S9) | Cluster ID changes on restore/create | **P5-S7**: Use correct cluster ID from the start |
| 21 | Environment-level GitHub secrets shadow org-level (P4-S4) | 13 repos use environment-based secrets | **P5-S11**: Update environment-level secrets for dev+sandbox |

---

## Step-by-Step Execution Plan

### P5-S1: Pre-flight — Fix Terraform S3 Bucket Names

**Why first:** In production, this was missed in Phase 1 and caught mid-`terraform apply` (P2-S4 deviation 2). Fix it before any infrastructure work.

**Repo:** `ticketing-platform-terraform-dev`

**Files to update:**

| File | Current Name | New Name |
|------|-------------|----------|
| `dev/s3.tf` | `ticketing-terraform-dev` (state backup bucket) | `ticketing-terraform-dev-eu` |
| `dev/s3.tf` | `ticketing-dev-csv-reports` | `ticketing-dev-csv-reports-eu` |
| `dev/s3.tf` | `ticketing-sandbox-csv-reports` | `ticketing-sandbox-csv-reports-eu` |
| `dev/variables.tf` | `s3 = "pdf-tickets-download"` | `s3 = "pdf-tickets-download-eu"` |
| `dev/variables.tf` | `s3_dev = "dev-pdf-tickets"` | `s3_dev = "dev-pdf-tickets-eu"` |
| `dev/variables.tf` | `s3_sandbox = "sandbox-pdf-tickets"` | `s3_sandbox = "sandbox-pdf-tickets-eu"` |
| `dev/mobile.tf` | `ticketing-dev-app-mobile` | `ticketing-dev-app-mobile-eu` |

**Also update IAM policy ARNs** in `s3.tf`/`mobile.tf` that reference these bucket names (add both old and new ARNs for backward compatibility, matching prod pattern).

**Commit** on the `hotfix/region-migration-eu-central-1` branch (already exists).

---

### P5-S2: Pre-flight — Fix Terraform VPC, Security Group, and CloudFront Issues

**Why:** These caused failures at P3-S3 (VPC endpoint), P3-S5-01 (Lambda→RDS), DIAG-004, DIAG-005 in production.

**Repo:** `ticketing-platform-terraform-dev`

**Changes:**

1. **`dev/vpc.tf`** — Add DNS settings (P3-S3 lesson):
   ```hcl
   enable_dns_hostnames = true
   enable_dns_support   = true
   ```

2. **`dev/rds.tf`** — Add VPC CIDR ingress on port 5432 (P3-S5-01 lesson):
   ```hcl
   ingress {
     from_port   = 5432
     to_port     = 5432
     protocol    = "tcp"
     cidr_blocks = [var.vpc_cidr]
     description = "Lambda VPC access to RDS"
   }
   ```

3. **`dev/s3.tf`** — Add CloudFront OAC bucket policies (DIAG-005 lesson) for pdf-download and mobile buckets (use `aws_cloudfront_distribution` resource references for distribution IDs).

4. **`dev/user-cicd.tf`** — Add `cloudfront:CreateInvalidation` policy (DIAG-004 lesson).

5. **`dev/.gitignore`** — Add `*.tfstate` and `*.tfstate.backup` patterns (P1-T14 lesson).

6. **`dev/rds.tf`** — **Uncomment** `aws_rds_cluster` and `aws_rds_cluster_instance` blocks. Unlike production (where we restored from backup), here we create a fresh cluster directly via Terraform. Do **NOT** include `serverless_v2_scaling_configuration` in Terraform — this will be set manually via AWS Console/CLI so it can be dynamically adjusted without causing Terraform state drift.

**Commit** on `hotfix/region-migration-eu-central-1`.

---

### P5-S3: Terraform Foundation

**Profile:** `--profile AdministratorAccess-307824719505 --region eu-central-1`

**S3-a. Service quota pre-checks:**
```bash
aws service-quotas list-service-quotas --service-code lambda \
  --query 'Quotas[?QuotaName==`Concurrent executions`].Value'
aws service-quotas list-service-quotas --service-code vpc \
  --query 'Quotas[?contains(QuotaName,`NAT`)].{Name:QuotaName,Value:Value}'
aws service-quotas list-service-quotas --service-code rds \
  --query 'Quotas[?contains(QuotaName,`cluster`)].{Name:QuotaName,Value:Value}'
```

**S3-b. Create Terraform state bucket:**
```bash
aws s3 mb s3://ticketing-terraform-dev-eu --region eu-central-1
aws s3api put-bucket-versioning --bucket ticketing-terraform-dev-eu \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket ticketing-terraform-dev-eu \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

**S3-c. Create `terraform` secret (required before `terraform apply` — reads `rds` password):**

Replicate from me-south-1, then promote:
```bash
# Replicate from me-south-1
aws secretsmanager replicate-secret-to-regions \
  --secret-id "terraform" \
  --add-replica-regions Region=eu-central-1 \
  --region me-south-1

# Wait for replication, then promote to standalone
aws secretsmanager stop-replication-to-replica \
  --secret-id "terraform" \
  --region eu-central-1
```

If me-south-1 Secrets Manager is unavailable, fall back to local backup:
```bash
RDS_PASS=$(python3 -c "
import json
with open('backup-secrets-dev/terraform.json') as f:
    d = json.load(f)
inner = json.loads(d['SecretString'])
print(inner['rds'])")
aws secretsmanager create-secret --name "terraform" \
  --secret-string "{\"rds\":\"${RDS_PASS}\"}" --region eu-central-1
```

**S3-d. Import Route53 hosted zones** (global — already exist from me-south-1):
```bash
cd ticketing-platform-terraform-dev/dev
terraform init -reconfigure

# List existing zones
aws route53 list-hosted-zones \
  --query 'HostedZones[?contains(Name,`tickets.mdlbeast.net`)].{Name:Name,Id:Id}' --output table

# Import both zones (replace IDs from output above)
terraform import 'module.zones.aws_route53_zone.this["dev.tickets.mdlbeast.net"]' <dev-zone-id>
terraform import 'module.zones.aws_route53_zone.this["sandbox.tickets.mdlbeast.net"]' <sandbox-zone-id>
```

**S3-e. Import global resources** (lesson from P2-S4 deviation 3):

IAM users, groups, policies, roles, attachments, CloudFront OACs, and the pre-created state bucket are global and already exist. Run `terraform plan` first and import each resource that reports "already exists":
```bash
terraform plan 2>&1 | grep "already exists"
# Import each conflicting resource — expect 20-30 imports similar to prod
```

Handle S3 ACL issue if any bucket has `acl = "private"` (remove it — P2-S4 deviation 6).

**S3-f. Terraform apply:**
```bash
terraform plan   # Review — expect RDS cluster + instances to be CREATED (uncommented in P5-S2)
terraform apply
```

**S3-g-post. Set Serverless v2 scaling** (not managed by Terraform — avoids drift when adjusting dynamically):
```bash
aws rds modify-db-cluster --db-cluster-identifier ticketing \
  --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=16 \
  --region eu-central-1 --profile AdministratorAccess-307824719505
```

**Expected resources created:** VPC (with DNS hostnames enabled), subnets, NAT gateways, S3 buckets (with `-eu` suffix and CloudFront bucket policies), KMS key, IAM resources (with CloudFront policy), security groups (with VPC CIDR port 5432 rule), CloudFront distributions, RDS cluster + instances (fresh), Route53 zones (imported).

**Record outputs:**
- `VPC_ID`, `SUBNET_1_ID`, `SUBNET_2_ID`, `SUBNET_3_ID`
- `RDS_SG_ID`, `KMS_KEY_ID`
- `DEV_ZONE_ID`, `SANDBOX_ZONE_ID`
- `AURORA_ENDPOINT`, `AURORA_RO_ENDPOINT`
- CloudFront distribution IDs

---

### P5-S4: Replicate Secrets from me-south-1

**Strategy:** Replicate secrets from me-south-1 (live source of truth), then immediately promote each to standalone to allow updates. Fall back to local backups only if me-south-1 Secrets Manager is unavailable.

**S4-a. Replicate all dev and sandbox secrets:**
```bash
# Dev service secrets (20)
for svc in access-control automations catalogue customers dp ecwid extensions gateway \
  geidea integration inventory loyalty marketplace media organizations pricing \
  reporting sales transfer xp-badges; do
  aws secretsmanager replicate-secret-to-regions \
    --secret-id "/dev/$svc" \
    --add-replica-regions Region=eu-central-1 \
    --region me-south-1
done

# Sandbox service secrets (20)
for svc in access-control automations catalogue customers dp ecwid extensions gateway \
  geidea integration inventory loyalty marketplace media organizations pricing \
  reporting sales transfer; do
  aws secretsmanager replicate-secret-to-regions \
    --secret-id "/sandbox/$svc" \
    --add-replica-regions Region=eu-central-1 \
    --region me-south-1
done

# Shared secrets
aws secretsmanager replicate-secret-to-regions \
  --secret-id "/rds/ticketing-cluster" \
  --add-replica-regions Region=eu-central-1 --region me-south-1
aws secretsmanager replicate-secret-to-regions \
  --secret-id "devops" \
  --add-replica-regions Region=eu-central-1 --region me-south-1
```

**S4-b. Promote ALL replicas to standalone** (lesson from P3-S4 deviation 1 — replicas are read-only):
```bash
# Wait for replication to complete, then promote each
for secret_name in $(aws secretsmanager list-secrets --region eu-central-1 \
  --query 'SecretList[?ReplicationStatus].Name' --output text); do
  aws secretsmanager stop-replication-to-replica \
    --secret-id "$secret_name" --region eu-central-1
done
```

**S4-c. Verify all secrets exist and are standalone:**
```bash
aws secretsmanager list-secrets --region eu-central-1 \
  --query 'SecretList[*].{Name:Name,Primary:PrimaryRegion}' --output table
# All should show PrimaryRegion=eu-central-1 (standalone) or null
# Expected: ~43 secrets (20 dev + 20 sandbox + terraform + /rds/ticketing-cluster + devops)
```

---

### P5-S5: Replicate SSM Parameters from me-south-1

**Strategy:** Read parameters directly from me-south-1 and create in eu-central-1. SSM doesn't have a built-in replication feature, so we script it. Fall back to local backups if me-south-1 is unavailable.

**S5-a. Bulk-replicate all parameters from me-south-1:**
```bash
# Read all dev params from me-south-1 and create in eu-central-1
# Use the aggregated backup file as reference for what exists
python3 -c "
import json, subprocess

for prefix in ['/dev/tp/', '/sandbox/tp/', '/rds/']:
    result = subprocess.run([
        'aws', 'ssm', 'get-parameters-by-path',
        '--path', prefix, '--recursive', '--with-decryption',
        '--region', 'me-south-1',
        '--profile', 'AdministratorAccess-307824719505',
        '--output', 'json'
    ], capture_output=True, text=True)
    params = json.loads(result.stdout).get('Parameters', [])
    for p in params:
        name = p['Name']
        value = p['Value']
        ptype = p['Type']
        # Skip deprecated params (Kafka, MSK, Elasticsearch, Log_Collector)
        skip_patterns = ['Kafka', 'MSK', 'Elasticsearch', 'Log_Collector', 'marketing-feeds', 'xp-badges', 'bandsintown']
        if any(pat in name for pat in skip_patterns):
            continue
        print(f'Creating: {name} (type={ptype})')
        subprocess.run([
            'aws', 'ssm', 'put-parameter',
            '--name', name, '--type', ptype, '--value', value,
            '--region', 'eu-central-1',
            '--profile', 'AdministratorAccess-307824719505',
            '--overwrite'
        ])
"
```

**S5-b. Override infrastructure parameters with new values:**

These params were replicated with me-south-1 values and must be overwritten with eu-central-1 values:

```bash
P="--region eu-central-1 --profile AdministratorAccess-307824719505"

# Subnet IDs — SUFFIX ONLY (lesson from P3-S5-01: strip "subnet-" prefix)
SUBNET_1_SUFFIX="${SUBNET_1_ID#subnet-}"
SUBNET_2_SUFFIX="${SUBNET_2_ID#subnet-}"
SUBNET_3_SUFFIX="${SUBNET_3_ID#subnet-}"

for env in dev sandbox; do
  aws ssm put-parameter --name "/$env/tp/SUBNET_1" --type String --value "$SUBNET_1_SUFFIX" --overwrite $P
  aws ssm put-parameter --name "/$env/tp/SUBNET_2" --type String --value "$SUBNET_2_SUFFIX" --overwrite $P
  aws ssm put-parameter --name "/$env/tp/SUBNET_3" --type String --value "$SUBNET_3_SUFFIX" --overwrite $P
done

# RDS security group
aws ssm put-parameter --name "/rds/ticketing-cluster-sg" --type String --value "$RDS_SG_ID" --overwrite $P

# RDS endpoints (from P5-S3 terraform output)
aws ssm put-parameter --name "/rds/ticketing-cluster-ro-endpoint" --type String --value "$AURORA_RO_ENDPOINT" --overwrite $P

# PDF generator bucket names (new -eu suffix)
aws ssm put-parameter --name "/dev/tp/pdf/generator/STORAGE_BUCKET_NAME" --type String --value "dev-pdf-tickets-eu" --overwrite $P
aws ssm put-parameter --name "/sandbox/tp/pdf/generator/STORAGE_BUCKET_NAME" --type String --value "sandbox-pdf-tickets-eu" --overwrite $P

# CSV generator bucket names
aws ssm put-parameter --name "/dev/tp/csv/generator/STORAGE_BUCKET_NAME" --type String --value "ticketing-dev-csv-reports-eu" --overwrite $P
aws ssm put-parameter --name "/sandbox/tp/csv/generator/STORAGE_BUCKET_NAME" --type String --value "ticketing-sandbox-csv-reports-eu" --overwrite $P

# ACCESS_CONTROL_SERVICE_URL (use final domain, not temp)
aws ssm put-parameter --name "/dev/tp/csv/generator/ACCESS_CONTROL_SERVICE_URL" --type String --value "https://api.dev.tickets.mdlbeast.net/" --overwrite $P
aws ssm put-parameter --name "/sandbox/tp/csv/generator/ACCESS_CONTROL_SERVICE_URL" --type String --value "https://api.sandbox.tickets.mdlbeast.net/" --overwrite $P

# Extension API URL
aws ssm put-parameter --name "/dev/tp/extensions/ExtensionApiUrl" --type String --value "https://api.dev.tickets.mdlbeast.net/" --overwrite $P
aws ssm put-parameter --name "/sandbox/tp/extensions/ExtensionApiUrl" --type String --value "https://api.sandbox.tickets.mdlbeast.net/" --overwrite $P

# KMS key ID (new eu-central-1 key)
aws ssm put-parameter --name "/dev/tp/csv/generator/KMS_KEY_ID" --type String --value "$KMS_KEY_ID" --overwrite $P
aws ssm put-parameter --name "/sandbox/tp/csv/generator/KMS_KEY_ID" --type String --value "$KMS_KEY_ID" --overwrite $P
aws ssm put-parameter --name "/dev/tp/pdf/generator/KMS_KEY_ID" --type String --value "$KMS_KEY_ID" --overwrite $P
aws ssm put-parameter --name "/sandbox/tp/pdf/generator/KMS_KEY_ID" --type String --value "$KMS_KEY_ID" --overwrite $P
```

**S5-c. Verify parameter count:**
```bash
aws ssm get-parameters-by-path --path "/" --recursive --region eu-central-1 \
  --profile AdministratorAccess-307824719505 --query 'Parameters | length(@)'
```

---

### P5-S6: Populate Database

**S6-a. Update `/rds/ticketing-cluster` secret with actual endpoint:**
```bash
AURORA_ENDPOINT=$(aws rds describe-db-clusters --db-cluster-identifier ticketing \
  --region eu-central-1 --profile AdministratorAccess-307824719505 \
  --query 'DBClusters[0].Endpoint' --output text)

# Read current secret, update host
aws secretsmanager get-secret-value --secret-id "/rds/ticketing-cluster" \
  --region eu-central-1 --profile AdministratorAccess-307824719505 --output json | \
  jq -r '.SecretString' | jq --arg host "$AURORA_ENDPOINT" '.host = $host' | \
  aws secretsmanager update-secret --secret-id "/rds/ticketing-cluster" \
    --secret-string file:///dev/stdin --region eu-central-1 --profile AdministratorAccess-307824719505
```

**S6-b. User populates database manually via SSM tunnel:**

User connects to the bastion/OpenVPN EC2 instance via SSM Session Manager, then restores the local sandbox DB dump. This creates all database schemas and seed data.

```bash
# SSM port forwarding (user runs this)
aws ssm start-session --target <openvpn-instance-id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["'$AURORA_ENDPOINT'"],"portNumber":["5432"],"localPortNumber":["5433"]}' \
  --region eu-central-1 --profile AdministratorAccess-307824719505

# Then in another terminal:
psql -h localhost -p 5433 -U devops < sandbox-dump.sql
```

**S6-c. Create DynamoDB Cache table:**
```bash
aws dynamodb create-table --table-name Cache \
  --attribute-definitions AttributeName=CacheKey,AttributeType=S \
  --key-schema AttributeName=CacheKey,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region eu-central-1 --profile AdministratorAccess-307824719505
aws dynamodb update-time-to-live --table-name Cache \
  --time-to-live-specification "Enabled=true,AttributeName=ExpirationTime" \
  --region eu-central-1 --profile AdministratorAccess-307824719505
```

---

### P5-S7: Update Connection Strings & Region-Dependent Secrets

**Why before CDK:** Services load secrets at Lambda cold start. CONNECTION_STRINGS must point to the new Aurora endpoint.

**Lessons applied:** Use `jq` pipeline to preserve special chars (P3-S4 deviation 4). Use correct cluster ID from the start (avoid P4-S9 stale endpoint issue). Update automations-specific configs (`FINANCE_REPORT_SENDER_CONFIG`, `AUTOMATIC_DATA_EXPORTER_CONNECTION_STRING`) with correct new cluster endpoint.

```bash
AURORA_ENDPOINT=<from P5-S3 terraform output>
AURORA_RO_ENDPOINT=<from P5-S3 terraform output>
KMS_KEY_ID=<from P5-S3 terraform output>
RDS_PASS=<from terraform secret>

for env in dev sandbox; do
  for svc in access-control catalogue customers dp extensions integration \
    inventory loyalty marketplace media organizations pricing reporting sales \
    transfer geidea ecwid automations gateway; do

    aws secretsmanager get-secret-value --secret-id "/$env/$svc" \
      --region eu-central-1 --profile AdministratorAccess-307824719505 --output json | \
    jq -r '.SecretString' | \
    python3 -c "
import json, sys, re
secret = json.load(sys.stdin)
endpoint = '$AURORA_ENDPOINT'
ro_endpoint = '$AURORA_RO_ENDPOINT'
kms_key = '$KMS_KEY_ID'
rds_pass = '$RDS_PASS'

# Update CONNECTION_STRINGS
for cs_key in ['CONNECTION_STRINGS', 'CONNECTION_STRINGS_Sales',
               'AUTOMATIC_DATA_EXPORTER_CONNECTION_STRING']:
    if cs_key not in secret: continue
    try:
        cs_dict = json.loads(secret[cs_key])
        for ctx_key, conn_str in cs_dict.items():
            if 'Readonly' in ctx_key or 'readonly' in ctx_key:
                conn_str = re.sub(r'Host=[^;]+', f'Host={ro_endpoint}', conn_str)
            else:
                conn_str = re.sub(r'Host=[^;]+', f'Host={endpoint}', conn_str)
            conn_str = re.sub(r'Password=[^;]+', f'Password={rds_pass}', conn_str)
            cs_dict[ctx_key] = conn_str
        secret[cs_key] = json.dumps(cs_dict)
    except json.JSONDecodeError:
        secret[cs_key] = re.sub(r'Host=[^;]+', f'Host={endpoint}', secret[cs_key])

# Update FINANCE_REPORT_SENDER_CONFIG (automations — avoid P4-S9 stale cluster ID)
if 'FINANCE_REPORT_SENDER_CONFIG' in secret:
    val = secret['FINANCE_REPORT_SENDER_CONFIG']
    # Replace any old cluster ID patterns with new endpoint
    val = re.sub(r'Host=[^;]+\.rds\.amazonaws\.com', f'Host={endpoint}', val)
    val = val.replace('me-south-1', 'eu-central-1')
    secret['FINANCE_REPORT_SENDER_CONFIG'] = val

# Blanket me-south-1 → eu-central-1 in all string values
for k in list(secret.keys()):
    if isinstance(secret[k], str) and 'me-south-1' in secret[k]:
        secret[k] = secret[k].replace('me-south-1', 'eu-central-1')

# Update KMS key
if 'KMS_KEY_ID' in secret: secret['KMS_KEY_ID'] = kms_key

# Strip deprecated keys
for k in list(secret.keys()):
    if 'Elasticsearch' in k or 'Redis' in k or 'Kafka' in k:
        del secret[k]

print(json.dumps(secret))
" > /tmp/secret_update.json

    aws secretsmanager update-secret --secret-id "/$env/$svc" \
      --secret-string file:///tmp/secret_update.json \
      --region eu-central-1 --profile AdministratorAccess-307824719505
  done
done
```

**Verify zero `me-south-1` remaining and no PLACEHOLDERs:**
```bash
for env in dev sandbox; do
  for svc in catalogue sales access-control automations; do
    echo "=== $env/$svc ==="
    aws secretsmanager get-secret-value --secret-id "/$env/$svc" \
      --region eu-central-1 --profile AdministratorAccess-307824719505 --output json | \
      jq -r '.SecretString' | grep -oE '(me-south-1|PLACEHOLDER)' || echo "CLEAN"
  done
done
```

---

### P5-S8: CDK Bootstrap + ACM Certificates + Delete Stale DNS Records

**S8-a. CDK Bootstrap:**
```bash
CDK_DEFAULT_ACCOUNT=307824719505 CDK_DEFAULT_REGION=eu-central-1 \
  AWS_PROFILE=AdministratorAccess-307824719505 \
  npx cdk bootstrap aws://307824719505/eu-central-1
```

**S8-b. Delete stale me-south-1 A records** (lesson from P4-S3):
```bash
# List A records in both zones
aws route53 list-resource-record-sets --hosted-zone-id $DEV_ZONE_ID \
  --query 'ResourceRecordSets[?Type==`A`]' --output table
aws route53 list-resource-record-sets --hosted-zone-id $SANDBOX_ZONE_ID \
  --query 'ResourceRecordSets[?Type==`A`]' --output table

# Delete stale A records pointing to me-south-1 API Gateway endpoints
# (api.dev, geidea.dev, ecwid.dev, api.sandbox, geidea.sandbox, ecwid.sandbox, etc.)
```

**S8-c. Create ACM certificates** (6 total — 3 per environment):
```bash
# Dev
request_cert "api.dev.tickets.mdlbeast.net" "/dev/tp/DomainCertificateArn" "dev"
request_cert "geidea.dev.tickets.mdlbeast.net" "/dev/tp/geidea/DomainCertificateArn" "dev"
request_cert "ecwid.dev.tickets.mdlbeast.net" "/dev/tp/ecwid/DomainCertificateArn" "dev"

# Sandbox
request_cert "api.sandbox.tickets.mdlbeast.net" "/sandbox/tp/DomainCertificateArn" "sandbox"
request_cert "geidea.sandbox.tickets.mdlbeast.net" "/sandbox/tp/geidea/DomainCertificateArn" "sandbox"
request_cert "ecwid.sandbox.tickets.mdlbeast.net" "/sandbox/tp/ecwid/DomainCertificateArn" "sandbox"
```

**Note:** For dev/sandbox, the Gateway SSM path mapping is identity (`dev` → `dev`, `sandbox` → `sandbox`), unlike prod where `prod` → `production`. So paths are `/{env}/tp/DomainCertificateArn` — no special handling.

---

### P5-S9: Deploy Infrastructure CDK (11 Stacks x 2 Envs)

**Pre-work: Bulk-delete stale IAM inline policies** (lesson from P3-S5-02):

Dev/sandbox IAM roles (suffixed `-dev` / `-sandbox`) may have stale inline policies from me-south-1 CDK. Delete them before any CDK deploy:

```bash
# List all IAM roles matching dev/sandbox service patterns
# Back up policies first (same script pattern as prod P3-S5-02)
# Then delete all stale inline policies
```

**Deploy sandbox first** (since `production` → `sandbox` is the next merge target):

```bash
export AWS_PROFILE=AdministratorAccess-307824719505
export CDK_DEFAULT_ACCOUNT=307824719505
export CDK_DEFAULT_REGION=eu-central-1

# ===== SANDBOX ENVIRONMENT =====
export ENV_NAME=sandbox
cd ticketing-platform-infrastructure

cdk deploy TP-EventBusStack-sandbox --require-approval never
cdk deploy TP-ConsumersSqsStack-sandbox --require-approval never
cdk deploy TP-ConsumerSubscriptionStack-sandbox --require-approval never
cdk deploy TP-ExtendedMessageS3BucketStack-sandbox --require-approval never
cdk deploy TP-InternalHostedZoneStack-sandbox --require-approval never
cdk deploy TP-InternalCertificateStack-sandbox --require-approval never
cdk deploy TP-MonitoringStack-sandbox --require-approval never
cdk deploy TP-ApiGatewayVpcEndpointStack --require-approval never     # shared (no env suffix)
cdk deploy TP-RdsProxyStack --require-approval never                   # shared
cdk deploy TP-XRayInsightNotificationStack-sandbox --require-approval never
cdk deploy TP-SlackNotificationStack-sandbox --require-approval never

# ===== DEV ENVIRONMENT =====
export ENV_NAME=dev

cdk deploy TP-EventBusStack-dev --require-approval never
cdk deploy TP-ConsumersSqsStack-dev --require-approval never
cdk deploy TP-ConsumerSubscriptionStack-dev --require-approval never
cdk deploy TP-ExtendedMessageS3BucketStack-dev --require-approval never
cdk deploy TP-InternalHostedZoneStack-dev --require-approval never
cdk deploy TP-InternalCertificateStack-dev --require-approval never
cdk deploy TP-MonitoringStack-dev --require-approval never
# ApiGatewayVpcEndpointStack + RdsProxyStack already deployed (shared)
cdk deploy TP-XRayInsightNotificationStack-dev --require-approval never
cdk deploy TP-SlackNotificationStack-dev --require-approval never
```

---

### P5-S10: Deploy Per-Service CDK Stacks (Sandbox First, Then Dev)

**Branching and deployment strategy:**

The first CDK deploy for each service will fail via CI/CD because of global IAM role conflicts (lesson #5). The approach is: **create the PR first (don't merge yet), do manual CDK deployment from the hotfix branch to import IAM roles and create stacks, then merge the PR** — CI/CD sees stacks already exist and performs a clean update.

**For sandbox (first):**
1. For each repo with a CDK project, `git fetch origin` then `git checkout sandbox && git pull origin sandbox` (or `release/sandbox` — check branch names). **Must be on latest remote HEAD.**
2. Create `hotfix/sandbox-eu-migration` from `sandbox`
3. Merge `production` (or `master`) into `hotfix/sandbox-eu-migration` (brings in all migration changes)
4. Push and **create PR**: `hotfix/sandbox-eu-migration` → `sandbox` — **DO NOT MERGE YET**
5. Checkout `hotfix/sandbox-eu-migration` locally and run the **manual CDK deployment** (below) — this imports IAM roles and creates all stacks
6. After manual deployment succeeds for all services, **user merges the PR** — CI/CD triggers but stacks already exist, so it performs a clean update

**For dev (after sandbox is validated):**
1. For each repo, `git fetch origin` then `git checkout development && git pull origin development` (or `release/development`). **Must be on latest remote HEAD.**
2. Create `hotfix/dev-eu-migration` from `development`
3. Merge `sandbox` into `hotfix/dev-eu-migration`
4. Push and **create PR**: `hotfix/dev-eu-migration` → `development` — **DO NOT MERGE YET**
5. Checkout `hotfix/dev-eu-migration` locally and run the **manual CDK deployment**
6. After manual deployment succeeds, **user merges the PR**

**Manual first-time deployment procedure (per service, per env):**

Run from the `hotfix/*-eu-migration` branch locally. Follow the standard CI/CD build sequence, but add the `cdk import` step before `cdk deploy`:

```bash
export AWS_PROFILE=AdministratorAccess-307824719505
export CDK_DEFAULT_ACCOUNT=307824719505
export CDK_DEFAULT_REGION=eu-central-1
export ENV_NAME=<env>  # sandbox or dev

cd <service-repo>

# 1. Clean publish directories
find . -path "*/bin/Release/net8.0/publish" -type d -exec rm -rf {} + 2>/dev/null

# 2. Build
dotnet restore && dotnet build --no-restore

# 3. Package each Lambda (MUST use dotnet lambda package, NOT dotnet publish)
cd src/TP.<Service>.Consumers && dotnet lambda package -c Release && cd -
cd src/TP.<Service>.BackgroundJobs && dotnet lambda package -c Release && cd -
# API project: dotnet publish -c Release from solution root (Web SDK generates .runtimeconfig.json)

# 4. Pre-create ALL log groups
aws logs create-log-group --log-group-name "/aws/lambda/<service>-serverless-<env>-function" $P 2>/dev/null
aws logs create-log-group --log-group-name "/aws/lambda/<service>-consumers-lambda-<env>" $P 2>/dev/null
aws logs create-log-group --log-group-name "/aws/lambda/<service>-background-jobs-lambda-<env>" $P 2>/dev/null

# 5. CDK synth + import IAM roles + deploy (use deploy-service-cdk.sh helper)
cd src/TP.<Service>.Cdk
cdk synth
# For each stack: extract IAM role logical IDs, create resource mapping, cdk import, cdk deploy
./deploy-service-cdk.sh <service-repo> <cdk-path> <stack1> [stack2] ...

# 6. For services with DbMigrator — run migration
aws lambda invoke --function-name "<service>-db-migrator-lambda-<env>" --payload '{}' /dev/null
```

**Service-specific exceptions:**

- **pdf-generator:** After `dotnet lambda package`, clean CDK DLLs + non-linux runtimes from publish dir (lesson #9)
- **extension-deployer:** Docker image-based. Deploy via `dotnet lambda deploy-function` with `--docker-build-options "--platform linux/amd64"` (lessons #11, #12)
- **media:** Import `imgix-<env>` IAM user in addition to roles (lesson #14)

**Deployment order** (same tiers as production, sandbox first then dev):

| Tier | Services |
|------|----------|
| 1 | catalogue, organizations, loyalty, csv-generator, pdf-generator, automations, extension-api, extension-deployer, extension-executor, extension-log-processor, customer-service |
| 2 | inventory, pricing, media, reporting-api, marketplace, integration, distribution-portal |
| 3 | sales, access-control, transfer, geidea, ecwid-integration |
| LAST | gateway |

**DB migrations:** If the user populated the database from the sandbox dump, migrations return "No pending migrations found". If databases are missing, the migration Lambda creates schemas from scratch.

**After initial manual deployment succeeds:** Subsequent deployments via CI/CD (branch merges) will work normally since the CDK stacks already exist and updates don't hit the IAM import issue.

---

### P5-S11: Update GitHub Secrets & Variables

**Lesson from P4-S4:** Environment-level secrets override org-level. Org-level `AWS_DEFAULT_REGION` was already set to `eu-central-1` in Phase 4, but repos with environment-based secrets for `dev` and `sandbox` still point to me-south-1.

```bash
# Repos with environment-level secrets (from P4-S4 deviation)
for repo in \
  ticketing-platform-infrastructure ticketing-platform-access-control \
  ticketing-platform-catalogue ticketing-platform-sales \
  ticketing-platform-inventory ticketing-platform-reporting-api \
  ticketing-platform-media ticketing-platform-pricing \
  ticketing-platform-organizations ticketing-platform-geidea \
  ticketing-platform-distribution-portal ticketing-platform-extension-deployer \
  ticketing-platform-customer-service; do

  for ghenv in dev sandbox; do
    gh secret set AWS_DEFAULT_REGION --body "eu-central-1" \
      --repo "mdlbeasts/$repo" --env "$ghenv"
    gh secret set CDK_DEFAULT_REGION --body "eu-central-1" \
      --repo "mdlbeasts/$repo" --env "$ghenv"
    # Update IAM credentials if applicable
    # gh secret set AWS_ACCESS_KEY_ID --body "$KEY" --repo "mdlbeasts/$repo" --env "$ghenv"
    # gh secret set AWS_SECRET_ACCESS_KEY --body "$SECRET" --repo "mdlbeasts/$repo" --env "$ghenv"
  done
done
```

---

### P5-S12: Merge PRs (After Manual CDK Deployment Succeeds)

After all manual Terraform + CDK + service deployments are complete, merge the open PRs to bring the `sandbox` (and later `development`) branches up to date. CI/CD will trigger and perform clean updates against the existing stacks.

**The same merge instructions apply to both sandbox and development** — just replace the branch/PR targets.

#### Merge Group 1 — Merge FIRST (dependencies for other services)

Merge these **sequentially, one at a time**, waiting for each CI/CD to complete before merging the next:

| # | Repo | Why First |
|---|------|-----------|
| 1 | `ticketing-platform-tools` | NuGet packages consumed by all .NET services. Must publish first. |
| 2 | `ticketing-platform-infrastructure` | Infrastructure CDK stacks (EventBus, SQS, RDS Proxy, etc.) referenced by all services. |
| 3 | `ticketing-platform-templates-ci-cd` | Shared CI/CD workflow templates used by all repos. |

#### Merge Group 2 — Merge SECOND (Terraform)

| # | Repo | Notes |
|---|------|-------|
| 4 | `ticketing-platform-terraform-dev` | No CI/CD auto-deploy (Terraform is applied manually). Safe to merge anytime after Group 1. |

#### Merge Group 3 — Merge in PARALLEL (backend services, Tier 1)

These are independent — merge all at the same time:

| # | Repo |
|---|------|
| 5 | `ticketing-platform-catalogue` |
| 6 | `ticketing-platform-organizations` |
| 7 | `ticketing-platform-loyalty` |
| 8 | `ticketing-platform-csv-generator` |
| 9 | `ticketing-platform-pdf-generator` |
| 10 | `ticketing-platform-automations` |
| 11 | `ticketing-platform-extension-api` |
| 12 | `ticketing-platform-extension-deployer` |
| 13 | `ticketing-platform-extension-executor` |
| 14 | `ticketing-platform-extension-log-processor` |
| 15 | `ticketing-platform-customer-service` |

#### Merge Group 4 — Merge in PARALLEL (backend services, Tier 2)

Wait for Group 3 CI/CD to finish (some Tier 2 services consume events from Tier 1), then merge all:

| # | Repo |
|---|------|
| 16 | `ticketing-platform-inventory` |
| 17 | `ticketing-platform-pricing` |
| 18 | `ticketing-platform-media` |
| 19 | `ticketing-platform-reporting-api` |
| 20 | `ticketing-platform-marketplace-service` |
| 21 | `ticketing-platform-integration` |
| 22 | `ticketing-platform-distribution-portal` |

#### Merge Group 5 — Merge in PARALLEL (backend services, Tier 3)

| # | Repo |
|---|------|
| 23 | `ticketing-platform-sales` |
| 24 | `ticketing-platform-access-control` |
| 25 | `ticketing-platform-transfer` |
| 26 | `ticketing-platform-geidea` |
| 27 | `ecwid-integration` |

#### Merge Group 6 — Merge LAST (gateway + frontends)

| # | Repo | Notes |
|---|------|-------|
| 28 | `ticketing-platform-gateway` | Must be after all backend services (it routes to them). |
| 29 | `ticketing-platform-dashboard` | Merge triggers Vercel redeploy. |
| 30 | `ticketing-platform-distribution-portal-frontend` | Verify Vercel deployment. |
| 31 | `ticketing-platform-mobile-scanner` | Trigger release build after merge. |

#### Merge Anytime (no CDK, no deployment order dependency)

These can be merged at any point — they have no CDK projects and no CI/CD deployment dependencies:

| Repo | Notes |
|------|-------|
| `ticketing-platform-configmap-dev` | Archival (EKS deprecated) |
| `ticketing-platform-configmap-sandbox` | Archival |
| `ticketing-platform-configmap-prod` | Archival |
| `ticketing-platform-shared` | No region references |
| `ticketing-platform-mobile-libraries` | No region references |

---

### P5-S13: End-to-End Validation

**Sandbox environment:**
- [ ] API Gateway health: `curl -sk https://api.sandbox.tickets.mdlbeast.net/health`
- [ ] Geidea endpoint responds
- [ ] Internal DNS resolution (private hosted zone CNAMEs)
- [ ] Database connectivity (health endpoints show npgsql Healthy)
- [ ] EventBridge → SQS → Consumer flow
- [ ] CloudWatch logs in eu-central-1
- [ ] Dashboard login (sandbox Auth0)

**Dev environment:**
- [ ] Same checklist against `*.dev.tickets.mdlbeast.net`

---

## Files Modified by This Plan

| File | Changes |
|------|---------|
| `ticketing-platform-terraform-dev/dev/s3.tf` | Rename buckets to `-eu`, add CloudFront bucket policies |
| `ticketing-platform-terraform-dev/dev/variables.tf` | Rename S3 variable defaults to `-eu` |
| `ticketing-platform-terraform-dev/dev/mobile.tf` | Rename mobile bucket to `-eu` |
| `ticketing-platform-terraform-dev/dev/vpc.tf` | Add `enable_dns_hostnames`, `enable_dns_support` |
| `ticketing-platform-terraform-dev/dev/rds.tf` | Add VPC CIDR port 5432 ingress, uncomment RDS cluster, add Serverless v2 scaling config |
| `ticketing-platform-terraform-dev/dev/user-cicd.tf` | Add CloudFront invalidation policy |
| `ticketing-platform-terraform-dev/dev/.gitignore` | Add `*.tfstate` patterns |

## Verification

After all steps complete:
```bash
# 1. Terraform state is clean
cd ticketing-platform-terraform-dev/dev && terraform plan
# Expected: No changes

# 2. All CDK stacks deployed
aws cloudformation list-stacks --region eu-central-1 --profile AdministratorAccess-307824719505 \
  --query 'StackSummaries[?StackStatus!=`DELETE_COMPLETE`].StackName' | grep -c "TP-"

# 3. No me-south-1 references in secrets
for env in dev sandbox; do
  aws secretsmanager list-secrets --region eu-central-1 --profile AdministratorAccess-307824719505 \
    --query "SecretList[?contains(Name,'$env')].Name" --output text | tr '\t' '\n' | while read name; do
    aws secretsmanager get-secret-value --secret-id "$name" --region eu-central-1 \
      --profile AdministratorAccess-307824719505 --output json | \
      jq -r '.SecretString' | grep -q "me-south-1" && echo "me-south-1 in $name"
  done
done

# 4. Health checks
curl -sk https://api.dev.tickets.mdlbeast.net/health
curl -sk https://api.sandbox.tickets.mdlbeast.net/health
```
