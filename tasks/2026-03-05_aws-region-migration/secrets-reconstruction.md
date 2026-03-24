# Secrets & SSM Parameters Reconstruction Reference

*Generated: 2026-03-24 — Based on codebase analysis of secret consumption patterns*

- [Correction: Actual Backup Failures](#correction-actual-backup-failures)
- [How Secrets Work](#how-secrets-work)
- [CONNECTION_STRINGS Format](#connection_strings-format)
- [Shared Keys (from TP.Tools)](#shared-keys-from-tptools)
- [Per-Service Secret Reconstruction](#per-service-secret-reconstruction)
  - [Truly Failed — Must Reconstruct From Scratch](#truly-failed--must-reconstruct-from-scratch)
  - [Backup Available — Copy and Update](#backup-available--copy-and-update)
- [SSM Parameters](#ssm-parameters)
- [Dead Keys to Remove](#dead-keys-to-remove)

---

## Correction: Actual Backup Failures

The migration plan lists 13 secrets as FAILED. **Only 8 truly failed.** Five listed as "FAILED" actually have complete data in the backup files:

| Secret | Plan Says | Actual Status |
|--------|-----------|---------------|
| `/{env}/access-control` | FAILED | **CONFIRMED FAILED** — `InternalServiceError: Data dependency failure` |
| `/{env}/automations` | FAILED | **HAS DATA** — 8 keys backed up |
| `/{env}/catalogue` | FAILED | **CONFIRMED FAILED** |
| `/{env}/customers` | FAILED | **CONFIRMED FAILED** |
| `/{env}/dp` | FAILED | **CONFIRMED FAILED** |
| `/{env}/ecwid` | FAILED | **CONFIRMED FAILED** |
| `/{env}/geidea` | FAILED | **HAS DATA** — 4 keys backed up |
| `/{env}/media` | FAILED | **HAS DATA** — 15 keys backed up |
| `/{env}/organizations` | FAILED | **HAS DATA** — 13 keys backed up |
| `/{env}/reporting` | FAILED | **CONFIRMED FAILED** |
| `/{env}/transfer` | FAILED | **CONFIRMED FAILED** |
| `devops` | FAILED | **HAS DATA** — 1 key (`devops`: SSH public key) |
| `terraform` | FAILED | **CONFIRMED FAILED** |

**Impact:** 5 fewer secrets to reconstruct from scratch. Automations, geidea, media, and organizations can be restored from backup files.

---

## How Secrets Work

### Loading Flow

Every Lambda (API, Consumer, BackgroundJob) follows this pattern at cold start:

```
Function() constructor / LambdaEntry.Init()
  → TPEnvironmentDiscovery().Environment  // reads TP_ENVIRONMENT env var
  → SecretManagerHelper.LoadSecretsToEnvironmentAsync($"/{env}/{service-name}")
  → ParameterStoreHelper.LoadParametersToEnvironmentAsync($"/{env}/tp/InternalServices")
```

`SecretManagerHelper` fetches the secret JSON from Secrets Manager and sets **each key-value pair as an environment variable** via `Environment.SetEnvironmentVariable()`.

`ParameterStoreHelper` fetches all parameters under the given SSM path and converts the last path segment to an env var name (e.g., `/dev/tp/InternalServices/Sales` → `SalesServiceBaseRoute`).

### Two Sources of Environment Variables

Each Lambda gets env vars from two sources:
1. **CDK env-var JSON** — baked into Lambda configuration at deploy time (static, from `env-var.{env}.json`)
2. **Secrets Manager** — loaded at runtime during cold start (dynamic, from `/{env}/{service}`)

Keys from CDK do NOT need to be in the secret. The tables below list **only keys that must come from the secret**.

---

## CONNECTION_STRINGS Format

`CONNECTION_STRINGS` is a **JSON-encoded dictionary**, not a raw connection string:

```json
{
  "PgSql": "User ID=devops;Password=<pass>;Host=<rds-proxy-endpoint>;Port=5432;Database=<db_name>;Timeout=10;Pooling=true;",
  "ReadonlyPgSql": "User ID=devops;Password=<pass>;Host=<rds-proxy-ro-endpoint>;Port=5432;Database=<db_name>;Timeout=10;Pooling=true;",
  "ReportingPgSql": "User ID=devops;Password=<pass>;Host=<rds-proxy-ro-endpoint>;Port=5432;Database=<db_name>;Timeout=10;Pooling=true;"
}
```

**Parsing:** `DbAutoConfigureHelper.GetConnectionStrings()` deserializes this into `Dictionary<string, string>` and matches keys to DbContext classes by suffix stripping (`ReadonlyPgSql` → `PgSql` context, `ReportingPgSql` → `PgSql` context, with NoTracking query behavior).

**Which services use which keys:**

| Database Key | Services That Use It |
|---|---|
| `PgSql` | ALL services with a database |
| `ReadonlyPgSql` | access-control, catalogue, customer-service, distribution-portal, integration, inventory, marketplace, media, organizations, pricing, reporting-api, sales, transfer |
| `ReportingPgSql` | access-control, catalogue, customer-service, integration, marketplace, organizations, reporting-api, transfer |

**Note:** `CONNECTION_STRINGS_Sales` exists in the prod sales backup but **no code reads this key**. It appears to be a legacy artifact. Safe to omit from reconstruction.

---

## Shared Keys (from TP.Tools)

These keys are consumed by `TP.Tools.*` libraries and are therefore common across all services that use the respective library:

### TP.Tools.DataAccessLayer
| Key | Source | Required |
|-----|--------|----------|
| `CONNECTION_STRINGS` | Secret | YES — for all services with a database |

### TP.Tools.Helpers
| Key | Source | Required |
|-----|--------|----------|
| `EMAIL_SERVICE_API_KEY` | Secret | Only services that send email (organizations, csv-generator, integration) |
| `EMAIL_SERVICE_FROM` | Secret | Optional — defaults to `tickets@mdlbeast.com` |
| `Redis__Host` | Secret | **DEAD** — Redis is zombie infrastructure, remove |
| `Redis__Password` | Secret | **DEAD** — remove |
| `{Service}ServiceBaseRoute` | SSM Parameter Store | Auto-loaded from `/{env}/tp/InternalServices/*` |

### TP.Tools.MessageBroker
| Key | Source | Required |
|-----|--------|----------|
| `TP_ENVIRONMENT` | CDK | YES — used to construct event bus name `event-bus-{env}` |
| `EXTENDED_MESSAGE_SIZE_ENABLED` | CDK | Optional — defaults to `true` |

### TP.Tools.Logger
| Key | Source | Required |
|-----|--------|----------|
| `ASPNETCORE_ENVIRONMENT` | CDK | YES |
| `TP_ENVIRONMENT` | CDK | YES |
| `Logging__Elasticsearch__*` | Secret | **DEAD** — no Serilog Elasticsearch sink installed, remove |

---

## Per-Service Secret Reconstruction

### Truly Failed — Must Reconstruct From Scratch

#### 1. `/{env}/access-control`

| Key | Type | Source for Reconstruction | Critical |
|-----|------|---------------------------|----------|
| `CONNECTION_STRINGS` | JSON string | Generate from new RDS Proxy endpoints (see format above). Database name: `access_control` | YES |
| `ENCRYPTION_KEY` | AES-256 key | **Must recover from password manager or team**. Used for PII encryption in DB — data is unreadable without the original key | CRITICAL |
| `ENCRYPTION_IV` | Base64 IV | Same as above — must be the ORIGINAL value, not a new one | CRITICAL |

**Note:** The agent research suggested `OrganizationServiceBaseRoute` and `MediaServiceBaseRoute` come from the secret, but these are actually loaded from SSM Parameter Store via `ParameterStoreHelper`, not from the secret.

#### 2. `/{env}/catalogue`

| Key | Type | Source for Reconstruction | Critical |
|-----|------|---------------------------|----------|
| `CONNECTION_STRINGS` | JSON string | Database name: `catalogue` | YES |
| `MediaSettings:BaseUrl` | URL string | CloudFront CDN URL for media (e.g., `https://media.tickets.mdlbeast.net`). Check current CDN distribution | YES |

**Note:** No `ENCRYPTION_KEY`/`ENCRYPTION_IV` found in catalogue code. No `SEATSIO_API_KEY` in code despite agent suggestion — the inventory backup confirms SeatsIO is only in inventory and sales.

#### 3. `/{env}/customers`

| Key | Type | Source for Reconstruction | Critical |
|-----|------|---------------------------|----------|
| `CONNECTION_STRINGS` | JSON string | Database name: `customers` | YES |
| `HyperPayConfigId` | String | HyperPay dashboard — payment gateway config ID | YES |
| `HyperPay_BaseUrl` | URL | HyperPay API endpoint URL | YES |
| `HyperPay_AccountEmail` | String | HyperPay account email | YES |
| `HyperPay_AccountPassword` | String | HyperPay account password | YES |

#### 4. `/{env}/dp` (distribution-portal)

| Key | Type | Source for Reconstruction | Critical |
|-----|------|---------------------------|----------|
| `CONNECTION_STRINGS` | JSON string | Database name: `distribution_portal` | YES |

**Note:** This service reads `CatalogueServiceBaseRoute`, `SalesServiceBaseRoute`, `MediaServiceBaseRoute` from SSM Parameter Store (not from the secret). No service-specific secret keys beyond CONNECTION_STRINGS found in code.

#### 5. `/{env}/reporting`

| Key | Type | Source for Reconstruction | Critical |
|-----|------|---------------------------|----------|
| `CONNECTION_STRINGS` | JSON string | Database name: `reporting`. Needs PgSql, ReadonlyPgSql, AND ReportingPgSql | YES |

**Note:** Minimal secret — only database connections. All other config comes from CDK env vars or SSM.

#### 6. `/{env}/transfer`

| Key | Type | Source for Reconstruction | Critical |
|-----|------|---------------------------|----------|
| `CONNECTION_STRINGS` | JSON string | Database name: `transfer` | YES |
| `SHARED_CODE_SECRET_KEY` | HMAC key | **Must recover from password manager or team**. Used for transfer share code generation — existing share codes won't validate without the original key | CRITICAL |

#### 7. `/{env}/ecwid`

**This secret has NO code references.** No service loads `/{env}/ecwid` via `SecretManagerHelper`. The only "ecwid" references in the codebase are:
- A log message in `ticketing-platform-geidea/src/TP.Geidea.Lambda.Balance/Function.cs:82` (historical naming)
- An entry in `ticketing-platform-tools/ToolsNugetUpgrader/appsettings.json` repo list (repo: `ecwid-integration`)

**Recommendation:** This appears to be a legacy/deprecated secret. Do NOT recreate unless a specific need is identified. The `ecwid-integration` repo doesn't exist in the monorepo.

#### 8. `terraform`

Terraform reads this secret via `secretmanager.tf` → `local.terraform = jsondecode(...)` and accesses `local.terraform.rds` for `master_password` in `rds.tf`.

The original secret had keys: `rds`, `opensearch`, `redis`. Only `rds` is still needed (opensearch/redis are deprecated).

| Key | Type | Source for Reconstruction | Critical |
|-----|------|---------------------------|----------|
| `rds` | String | The RDS master password. Available from: (1) `/rds/ticketing-cluster` backup → `password` field, (2) `terraform-prod/prod/variables.tf:116` hardcoded default, (3) `terraform.tfstate.backup` | YES |

**Note:** The plan refers to this as `rds_pass` — that's the Terraform *variable* name (`var.rds_pass`), not the secret key. The secret key is just `rds`. Reconstruct as:

```json
{"rds": "<password-from-rds-ticketing-cluster-backup>"}
```

The `opensearch` and `redis` keys are no longer needed and should be omitted.

---

### Backup Available — Copy and Update

These secrets were listed as FAILED in the plan but **actually have backup data**.

#### 9. `/{env}/automations` — BACKUP EXISTS

**Backed-up keys (8):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |
| `TOKEN_CLIENT_ID` | No | Copy as-is (Auth0 client) |
| `TOKEN_CLIENT_SECRET` | No | Copy as-is (Auth0 secret) |
| `AUTOMATIC_DATA_EXPORTER_CONFIG` | **YES** — contains `S3Region`, `S3Bucket` | Update region + bucket name |
| `AUTOMATIC_DATA_EXPORTER_CONNECTION_STRING` | **YES** — contains RDS host | Update host to new RDS endpoint |
| `FINANCE_REPORT_SENDER_CONFIG` | **YES** — contains DB connection strings | Update hosts to new RDS endpoint |
| `GEIDEA_DATA_EXPORTER_CONFIG` | **YES** — contains `S3Region`, `S3Bucket` | Update region + bucket name |
| `AUTOMATIC_DATA_EXPORTER_GOOGLE_CREDENTIALS` | No | Copy as-is (GCP service account) |

**Keys NOT in backup that code expects (from CDK env-var, not secret):**
- `TOKEN_URL`, `TOKEN_AUDIENCE`, `API_URL` — come from CDK env-var JSON, not the secret
- `WEEKLY_TICKETS_SENDER` — from CDK env-var JSON, not the secret

#### 10. `/{env}/geidea` — BACKUP EXISTS

**Backed-up keys (4):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |
| `CONNECTION_STRINGS` | **YES** | Update RDS host |
| `GEIDEA_CONFIG` | No | Copy as-is (Geidea tenant configs) |
| `GCP_AUTH` | No | Copy as-is (GCP service account) |

**Keys from CDK (NOT from secret):**
- `TICKETING_AUTH_SERVER_URL`, `TICKETING_AUTH_CLIENT_ID`, `TICKETING_AUTH_CLIENT_SECRET`, `TICKETING_AUTH_API_IDENTIFIER` — from CDK env-var JSON
- `TICKETING_ORG_ID`, `TICKETING_BRANCH_ID`, `TICKETING_CHANNEL_ID` — from CDK env-var JSON

#### 11. `/{env}/media` — BACKUP EXISTS

**Backed-up keys (15):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `PDF_SERVICE_URL` | No | Copy as-is (external PDF service URL) |
| `PDF_SERVICE_WORKSPACE_ID` | No | Copy as-is |
| `PDF_SERVICE_API_KEY` | No | Copy as-is |
| `PDF_SERVICE_API_SECRET` | No | Copy as-is |
| `STORAGE_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `STORAGE_SECRET_KEY` | **YES** | Update to new IAM user credentials |
| `PDF_FUNCTION_URL` | **Possibly** | Lambda function URL — will change in new region |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `SQS_QUEUE_URL` | **YES** | Update to new SQS queue URL |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |

#### 12. `/{env}/organizations` — BACKUP EXISTS

**Backed-up keys (13):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host |
| `AUTH_CLIENT_ID` | No | Copy as-is (Auth0) |
| `AUTH_CLIENT_SECRET` | No | Copy as-is (Auth0) |
| `AUTH_DOMAIN` | No | Copy as-is (Auth0 domain) |
| `AUTH_DB_CONNECTION` | No | Copy as-is (Auth0 DB connection) |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `EMAIL_SERVICE_API_KEY` | No | Copy as-is (SendGrid) |
| `AUTH_CLIENT_AUDIENCE` | No | Copy as-is |
| `AUTH_AUDIENCES__0` | No | Copy as-is |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |

#### 13. `devops` — BACKUP EXISTS

**Backed-up keys (1):**
| Key | Value Type | Action |
|-----|-----------|--------|
| `devops` | SSH public key | Used by Terraform for EC2 key pairs (`aws_key_pair.devops`). Copy as-is. |

---

## SSM Parameters

### Manual — Must Exist Before CDK Deploy

| Parameter Path | Value | Source | Notes |
|---|---|---|---|
| `/{env}/tp/VPC_NAME` | `ticketing` | Static | CDK's `CdkStackUtilities.GetTicketingVpc` reads this |
| `/{env}/tp/SUBNET_1` | Subnet ID | Terraform output | Lambda subnet 1a |
| `/{env}/tp/SUBNET_2` | Subnet ID | Terraform output | Lambda subnet 1b |
| `/{env}/tp/SUBNET_3` | Subnet ID | Terraform output | Lambda subnet 1c |
| `/rds/ticketing-cluster-identifier` | `ticketing-eu` | Aurora restore | Set after restore confirms identifier |
| `/rds/ticketing-cluster-sg` | Security group ID | Terraform output | RDS security group |
| `/{env}/tp/DomainCertificateArn` | ACM ARN | ACM request | Main gateway API cert |
| `/{env}/tp/geidea/DomainCertificateArn` | ACM ARN | ACM request | Geidea API cert |
| `/{env}/tp/xp-badges/DomainCertificateArn` | ACM ARN | ACM request | XP Badges API cert |
| `/{env}/tp/bandsintown-integration/DomainCertificateArn` | ACM ARN | ACM request | Bandsintown API cert |
| `/{env}/tp/marketing-feeds/DomainCertificateArn` | ACM ARN | ACM request | Marketing Feeds API cert |
| `/{env}/tp/SlackNotification/ErrorsWebhookUrl` | Webhook URL | Slack workspace | SecureString |
| `/{env}/tp/SlackNotification/OperationalErrorsWebhookUrl` | Webhook URL | Slack workspace | SecureString |
| `/{env}/tp/SlackNotification/SuspiciousOrdersWebhookUrl` | Webhook URL | Slack workspace | SecureString |
| `/{env}/tp/SlackNotification/IgnoredErrorsPatterns` | Pattern list | Config | StringList |
| `/{env}/tp/pdf/generator/STORAGE_BUCKET_NAME` | Bucket name | S3 bucket name | e.g., `dev-pdf-tickets-eu` |

**PDF Generator additional SSM params** (under `/{env}/tp/pdf/generator/`):

| Parameter | Value | Notes |
|---|---|---|
| `STORAGE_BUCKET_NAME` | `{env}-pdf-tickets-eu` | S3 bucket for PDFs |
| `PDF_SERVICE_URL` | External URL | PDF generation API URL |
| `PDF_SERVICE_API_KEY` | API key | PDF service credentials |
| `PDF_SERVICE_API_SECRET` | API secret | PDF service credentials |
| `PDF_SERVICE_WORKSPACE_ID` | Workspace ID | PDF service workspace |
| `STORAGE_EXPIRATION_HOURS` | Hours | Pre-signed URL expiration |

**CSV Generator additional SSM params** (under `/{env}/tp/csv/generator/`):

| Parameter | Value | Notes |
|---|---|---|
| `STORAGE_BUCKET_NAME` | `ticketing-{env}-csv-reports-eu` | S3 bucket for CSVs |
| `EMAIL_SERVICE_API_KEY` | SendGrid key | For sending CSV download links |
| `EMAIL_SERVICE_FROM` | Email address | Sender address |
| `STORAGE_EXPIRATION_HOURS` | Hours | Pre-signed URL expiration |

### Auto-Created by CDK — No Manual Action

| Parameter Pattern | Created By | Count |
|---|---|---|
| `/{env}/tp/InternalDomainCertificateArn` | InternalCertificateStack | 1 per env |
| `/{env}/tp/ApiGatewayVpcEndpointId` | ApiGatewayVpcEndpointStack | 1 (shared dev/sandbox) |
| `/{env}/tp/consumers/{service}/queue-arn` | ConsumersSqsStack | 18 per env |
| `/rds/RdsProxyEndpoint` | RdsProxyStack | 1 |
| `/rds/RdsProxyReadOnlyEndpoint` | RdsProxyStack | 1 |
| `/{env}/tp/InfrastructureAlarmsTopicArn` | XRayInsightNotificationStack | 1 per env |
| `/{env}/tp/InternalServices/{service}` | ServerlessApiStackHelper | ~15 per env |
| `/{env}/tp/media/bucket-name` | MediaStorageStack | 1 per env |
| `/{env}/tp/extensions/EXTENSION_DEFAULT_ROLE` | ExtensionDeployerStack | 1 per env |
| `/{env}/tp/extensions/EXTENSION_LOGS_QUEUE_URL` | ExtensionLogsProcessorStack | 1 per env |

---

## Dead Keys to Remove

Remove from ALL secrets during reconstruction:

| Key Pattern | Reason |
|---|---|
| `Logging__Elasticsearch__Uri` | No Serilog Elasticsearch sink installed |
| `Logging__Elasticsearch__Username` | Same |
| `Logging__Elasticsearch__Password` | Same |
| `Redis__Host` | Zero connections — uses DynamoDB + in-memory cache instead |
| `Redis__Password` | Same |
| `LUMIGO_TRACER_TOKEN` | Evaluate whether Lumigo is still used; if not, remove |

---

## Critical Reconstruction Warnings

1. **`ENCRYPTION_KEY` and `ENCRYPTION_IV` are IRREPLACEABLE.** These AES keys encrypt PII in the database. If the original values are lost, encrypted data in access-control (and any other service using them via the shared TP.Tools pattern) becomes permanently unreadable. These MUST be recovered from a password manager, team memory, or alternative backup — generating new values will NOT work.

2. **`SHARED_CODE_SECRET_KEY` (transfer service) is IRREPLACEABLE.** Used for HMAC-based transfer share codes. Existing share codes in the database won't validate with a different key.

3. **`CONNECTION_STRINGS` can be regenerated** — they only contain the RDS Proxy endpoint, database name, and credentials. All of these are known after Aurora restore.

4. **Third-party API keys** (HyperPay, Auth0, SendGrid, TalonOne, etc.) can be recovered from vendor dashboards or password managers. They are not AWS-specific.

5. **`PDF_FUNCTION_URL` in media secret** points to a Lambda function URL that will change in the new region. This must be updated after the PDF generator Lambda is deployed.
