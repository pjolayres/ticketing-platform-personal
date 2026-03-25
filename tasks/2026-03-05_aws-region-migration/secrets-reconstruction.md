# Secrets & SSM Parameters Reconstruction Reference

*Generated: 2026-03-24 — Updated: 2026-03-25 — Based on codebase analysis and verified backup files*

- [Backup Status: All 24 Secrets Recovered](#backup-status-all-24-secrets-recovered)
- [How Secrets Work](#how-secrets-work)
- [CONNECTION_STRINGS Format](#connection_strings-format)
- [Shared Keys (from TP.Tools)](#shared-keys-from-tptools)
- [Per-Service Secret Reconstruction](#per-service-secret-reconstruction)
  - [Partial Backup — Missing Some Keys](#partial-backup--missing-some-keys)
  - [Full Backup — Copy and Update](#full-backup--copy-and-update)
- [SSM Parameters](#ssm-parameters)
- [Dead Keys to Remove](#dead-keys-to-remove)

---

## Backup Status: All 24 Secrets Recovered

**As of 2026-03-25, all 24 production secrets have been successfully backed up.** The previous version of this document listed 6 secrets as "truly failed." Subsequent backup retrieval succeeded for all of them.

| Secret | Previous Status | Current Status | Keys Backed Up |
|--------|----------------|----------------|----------------|
| `/{env}/access-control` | FAILED | **RECOVERED** | 11 keys — includes `ENCRYPTION_KEY` and `ENCRYPTION_IV` |
| `/{env}/automations` | FAILED → HAS DATA | **FULL BACKUP** | 8 keys |
| `/{env}/catalogue` | FAILED | **RECOVERED** | 8 keys — includes `SEATSIO_API_KEY` |
| `/{env}/customers` | FAILED | **RECOVERED** | 7 keys — includes `HyperPayConfigId`, `HyperPay_AccountEmail`, `HyperPay_AccountPassword` |
| `/{env}/dp` | FAILED | **RECOVERED** | 7 keys |
| `/{env}/ecwid` | FAILED | **PARTIAL** | 9 keys — missing `CONNECTION_STRINGS`, `ECWID_STORE_ID`, `ECWID_BASE_ADDRESS`, `ANCHANTO_STORE_ID`, `ANCHANTO_MARKETPLACE_CODE`, `ANCHANTO_BASE_ADDRESS`, `ANCHANTO_BASE_CATEGORY_CODE`, `ANCHANTO_BASE_CATEGORY_NAME` |
| `/{env}/geidea` | FAILED → HAS DATA | **FULL BACKUP** | 4 keys |
| `/{env}/media` | FAILED → HAS DATA | **FULL BACKUP** | 15 keys |
| `/{env}/organizations` | FAILED → HAS DATA | **FULL BACKUP** | 13 keys (note: 14 previously reported, actual count is 13) |
| `/{env}/reporting` | FAILED → HAS DATA | **FULL BACKUP** | 8 keys |
| `/{env}/transfer` | FAILED → HAS DATA | **FULL BACKUP** | 9 keys — includes `SHARED_CODE_SECRET_KEY` |
| `devops` | FAILED → HAS DATA | **FULL BACKUP** | 1 key (SSH public key) |
| `terraform` | FAILED | **RECOVERED** | 3 keys — `rds`, `redis`, `opensearch` |

**Impact:** Zero secrets need full reconstruction from scratch. Only ecwid has a partial backup (missing 8 keys that must come from vendor dashboards). All other secrets can be fully restored from backup files with region-dependent values updated.

**Critical preservation:**
- `ENCRYPTION_KEY` and `ENCRYPTION_IV` (access-control) — **PRESERVED.** Previously-encrypted PII in the access-control database will remain readable. No need to generate new keys.
- `SHARED_CODE_SECRET_KEY` (transfer) — **PRESERVED.** Existing transfer share codes remain valid.
- `HyperPay*` credentials (customers) — **MOSTLY PRESERVED.** `HyperPay_BaseUrl` is missing from backup but can be reconstructed from vendor docs (standard API endpoint URL).
- `terraform` secret — **PRESERVED.** Contains `rds` password, `redis` password, `opensearch` password. Only `rds` is needed going forward.

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

### Partial Backup — Missing Some Keys

#### 1. `/{env}/ecwid` — PARTIAL BACKUP

Ecwid-integration loads this secret via custom `GetSecretValueAsync("/{env}/ecwid")` calls in each Lambda's `Startup.cs` (PaymentCallback, PaymentCreate, WebHooks.Ecwid, WebHooks.Anchanto) and `ServiceProviderBuilder.ReadSecrets()` for BackgroundJobs. It does NOT use the shared `SecretManagerHelper`.

**Backed-up keys (9):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `Checkout__SecretKey` | No | Copy as-is (Checkout.com) |
| `Checkout__PublicKey` | No | Copy as-is (Checkout.com) |
| `EcwidClientSecret` | No | Copy as-is |
| `EcwidClientId` | No | Copy as-is (value: `custom-app-106974757-1`) |
| `ECWID_API_SECRET` | No | Copy as-is |
| `ECWID_WEBHOOK_SECRET` | No | Copy as-is |
| `ANCHANTO_API_SECRET` | No | Copy as-is |
| `ANCHANTO_INVENTORY_WEBHOOK_SECRET` | No | Copy as-is |
| `ANCHANTO_ORDER_WEBHOOK_SECRET` | No | Copy as-is |

**Keys NOT in backup — must reconstruct from vendor dashboards/password manager:**
| Key | Type | Source for Reconstruction | Critical |
|-----|------|---------------------------|----------|
| `CONNECTION_STRINGS` | JSON string | Generate from new Aurora endpoints. Database name: `ecwid` | YES |
| `ECWID_STORE_ID` | String | Ecwid dashboard | YES |
| `ECWID_BASE_ADDRESS` | URL | Ecwid API base URL (e.g., `https://app.ecwid.com/api/v3`) | YES |
| `ANCHANTO_STORE_ID` | String | Anchanto dashboard | YES |
| `ANCHANTO_MARKETPLACE_CODE` | String | Anchanto dashboard | YES |
| `ANCHANTO_BASE_ADDRESS` | URL | Anchanto API base URL | YES |
| `ANCHANTO_BASE_CATEGORY_CODE` | String | Anchanto config | YES |
| `ANCHANTO_BASE_CATEGORY_NAME` | String | Anchanto config | YES |

**Note:** The backup has all *secret* credentials (API secrets, webhook secrets) but is missing *configuration* values (store IDs, base URLs, category codes). These are non-sensitive and should be retrievable from vendor dashboards.

---

### Full Backup — Copy and Update

All remaining secrets have complete backup data. Region-dependent values must be updated.

#### 2. `/{env}/access-control` — FULL BACKUP (previously reported as FAILED)

**Backed-up keys (11):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `access` |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `SQS_QUEUE_URL` | **YES** | Update region in URL |
| `ENCRYPTION_KEY` | No | **Copy as-is — CRITICAL** (AES-256 key for PII encryption). Preserving this means existing encrypted data remains readable. |
| `ENCRYPTION_IV` | No | **Copy as-is — CRITICAL** (paired with ENCRYPTION_KEY) |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |
| `SEATSIO_API_KEY` | No | Copy as-is |

**Note:** The backup also reveals access-control has a `SEATSIO_API_KEY`, previously not documented. It also has `SQS_QUEUE_URL` pointing to the CSV generator queue — same pattern as other services.

#### 3. `/{env}/catalogue` — FULL BACKUP (previously reported as FAILED)

**Backed-up keys (8):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `catalogue`. Note: PgSql uses `User ID=catalogue` (not `devops`). |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |
| `SEATSIO_API_KEY` | No | Copy as-is |

**Note:** The previous version stated "No `SEATSIO_API_KEY` in code" — the backup confirms it IS present (same UUID as inventory/sales). Also, `MediaSettings:BaseUrl` was listed as required but is NOT in the backup, suggesting it comes from CDK env-var JSON, not the secret.

#### 4. `/{env}/customers` — FULL BACKUP (previously reported as FAILED)

**Backed-up keys (7):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `customers` |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `SQS_QUEUE_URL` | **YES** | Update region in URL |
| `HyperPayConfigId` | No | Copy as-is |
| `HyperPay_AccountEmail` | No | Copy as-is (value: `mdlbeast@mdlbeast.com`) |
| `HyperPay_AccountPassword` | No | Copy as-is |

**Key NOT in backup:**
- `HyperPay_BaseUrl` — Not present in the backup file. Must be reconstructed from vendor documentation (standard HyperPay API endpoint URL). Check if code has a fallback default.

**Note:** Previous version listed 5 keys to reconstruct; now only `HyperPay_BaseUrl` needs manual reconstruction (if the code requires it — verify whether this is set via CDK env-var JSON instead).

#### 5. `/{env}/dp` (distribution-portal) — FULL BACKUP (previously reported as FAILED)

**Backed-up keys (7):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `dp` |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |

#### 6. `/{env}/extensions` — FULL BACKUP

**Backed-up keys (9):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `extension` |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `EXTENSION_DEPLOYER_SQS_QUEUE_URL` | **YES** | Update region in URL |
| `EXTENSION_EXECUTOR_SQS_QUEUE_URL` | **YES** | Update region in URL |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |

#### 7. `/{env}/gateway` — FULL BACKUP

**Backed-up keys (10):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `UNSECURE_TEST_CODE` | No | Copy as-is |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `BasicAuthKey` | No | Copy as-is |
| `TabbyAuthKey` | No | Copy as-is |
| `ChekoutAuthKey` | No | Copy as-is |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |

#### 8. `/{env}/integration` — FULL BACKUP

**Backed-up keys (22):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `integration` |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `CheckoutComAuthorizationKey` | No | Copy as-is |
| `MDLBEAST_ACCESS_TOKEN` | No | Copy as-is |
| `MDLBEAST_ORDER_COMPLETE_WEBHOOK_EVENTS` | No | Copy as-is (JSON array of UUIDs) |
| `EMAIL_SERVICE_API_KEY` | No | Copy as-is (SendGrid) |
| `WRSTBND_URL` | No | Copy as-is (`https://core.wrstbnd.io/rest/core/v1`) |
| `WRSTBND_API_KEY` | No | Copy as-is |
| `WRSTBND_TICKET_MAPPINGS` | No | Copy as-is (complex JSON mapping) |
| `STORAGE_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `STORAGE_SECRET_KEY` | **YES** | Update to new IAM user credentials |
| `KMS_KEY_ID` | **YES** | Update to new KMS key ID from Terraform |
| `DISTRIBUTION_PORTAL_LINK` | No | Copy as-is (`https://portal.tickets.mdlbeast.net/`) |
| `WHATSAPP_API_KEY` | No | Copy as-is |
| `WHATSAPP_PASSWORD` | No | Copy as-is |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `EMAIL_SERVICE_REPLYTO_ADDRESS` | No | Copy as-is (`contact@nofomo.com`) |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |
| `WHATSAPP_BOT_TEMPLATE_ID` | No | Copy as-is (`7171442`) |

#### 9. `/{env}/inventory` — FULL BACKUP

**Backed-up keys (9):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `inventoryprod`. Note: uses `Maximum Pool Size=500`. |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `SEATSIO_API_KEY` | No | Copy as-is |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |
| `WEBOOK_API_TOKEN` | No | Copy as-is |

**Note:** Database name is `inventoryprod` (not `inventory`). Preserve the `Maximum Pool Size=500` in CONNECTION_STRINGS.

#### 10. `/{env}/loyalty` — FULL BACKUP

**Backed-up keys (8):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `TALON_API_KEY` | No | Copy as-is (TalonOne) |
| `TALON_MANAGEMENT_API_KEY` | No | Copy as-is (TalonOne) |
| `TICKETING_AUTH_CLIENT_SECRET` | No | Copy as-is |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead — empty values) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead — empty values) |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead — empty values) |
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `loyalty` |

#### 11. `/{env}/marketplace` — FULL BACKUP

**Backed-up keys (5):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `marketplace` |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `SQS_QUEUE_URL` | **YES** | Update region in URL |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |

#### 12. `/{env}/pricing` — FULL BACKUP

**Backed-up keys (12):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `pricing` |
| `DiscountServiceBaseRoute` | No | Copy as-is (`https://mdlbeast.vouchery.io/api/v2.0/`) |
| `DiscountServiceToken` | No | Copy as-is |
| `Redis__Host` | — | **DELETE** (dead — zombie infrastructure) |
| `Redis__Password` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |
| `TALON_API_KEY` | No | Copy as-is (TalonOne) |

#### 13. `/{env}/sales` — FULL BACKUP

**Backed-up keys (28):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `sales` |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `SQS_QUEUE_URL` | **YES** | Update region in URL |
| `Tabby__PublicKey` | No | Copy as-is |
| `Tabby__SecretKey` | No | Copy as-is |
| `CONNECTION_STRINGS_Sales` | **YES** | Update RDS host (legacy — no code reads this, safe to omit) |
| `Checkout__SecretKey` | No | Copy as-is |
| `Checkout__PublicKey` | No | Copy as-is |
| `Checkout__PreviousSecretKey` | No | Copy as-is |
| `Checkout__PreviousPublicKey` | No | Copy as-is |
| `Checkout__MigrationDateTime` | No | Copy as-is (`2023-10-25T07:08:00Z`) |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |
| `SEATSIO_API_KEY` | No | Copy as-is |
| `RestrictedViewJob__OrganizationId` | No | Copy as-is |
| `RestrictedViewJob__EventId` | No | Copy as-is |
| `Tabby__SA__PublicKey` | No | Copy as-is |
| `Tabby__SA__SecretKey` | No | Copy as-is |
| `Tabby__SA__MerchantCode` | No | Copy as-is (`MDL_KSA`) |
| `Tabby__AE__PublicKey` | No | Copy as-is |
| `Tabby__AE__SecretKey` | No | Copy as-is |
| `Tabby__AE__MerchantCode` | No | Copy as-is (`MDL_UAE`) |
| `EXCHANGE_RATE_SAR_TO_AED` | No | Copy as-is (`1.021703`) |
| `EXCHANGE_RATE_AED_TO_SAR` | No | Copy as-is (`0.978757`) |
| `ENABLE_PERFORMANCE_METRICS` | No | Copy as-is (`true`) |

#### 14. `/{env}/automations` — FULL BACKUP

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

#### 15. `/{env}/geidea` — FULL BACKUP

**Backed-up keys (4):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `geidea` |
| `GEIDEA_CONFIG` | No | Copy as-is (Geidea tenant configs — JSON array with 3 tenants) |
| `GCP_AUTH` | No | Copy as-is (GCP service account) |

**Keys from CDK (NOT from secret):**
- `TICKETING_AUTH_SERVER_URL`, `TICKETING_AUTH_CLIENT_ID`, `TICKETING_AUTH_CLIENT_SECRET`, `TICKETING_AUTH_API_IDENTIFIER` — from CDK env-var JSON
- `TICKETING_ORG_ID`, `TICKETING_BRANCH_ID`, `TICKETING_CHANNEL_ID` — from CDK env-var JSON

#### 16. `/{env}/media` — FULL BACKUP

**Backed-up keys (15):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `media` |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `PDF_SERVICE_URL` | No | Copy as-is (`https://mdlbeast.pdfgeneratorapi.com/api/v3`) — also copy to PDF generator SSM params |
| `PDF_SERVICE_WORKSPACE_ID` | No | Copy as-is (`ilyas.assainov@mdlbeast.com`) |
| `PDF_SERVICE_API_KEY` | No | Copy as-is |
| `PDF_SERVICE_API_SECRET` | No | Copy as-is |
| `STORAGE_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `STORAGE_SECRET_KEY` | **YES** | Update to new IAM user credentials |
| `PDF_FUNCTION_URL` | **YES** | Backup value is an SQS URL (not a Lambda function URL as previously documented): `sqs.me-south-1.amazonaws.com/.../TP_PDF_Generator_Service_Queue_prod`. Update region. |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `SQS_QUEUE_URL` | **YES** | Update to new SQS queue URL (same queue as `PDF_FUNCTION_URL`) |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |

**Note:** `PDF_FUNCTION_URL` and `SQS_QUEUE_URL` in the backup both point to the same SQS queue (`TP_PDF_Generator_Service_Queue_prod`). The previous version incorrectly described `PDF_FUNCTION_URL` as a Lambda function URL.

#### 17. `/{env}/organizations` — FULL BACKUP

**Backed-up keys (13):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `organizations` |
| `AUTH_CLIENT_ID` | No | Copy as-is (Auth0) |
| `AUTH_CLIENT_SECRET` | No | Copy as-is (Auth0) |
| `AUTH_DOMAIN` | No | Copy as-is (`https://ticketing-platform.eu.auth0.com`) |
| `AUTH_DB_CONNECTION` | No | Copy as-is (`con_INeA0J7GBtP6KvY5`) |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `EMAIL_SERVICE_API_KEY` | No | Copy as-is (SendGrid) |
| `AUTH_CLIENT_AUDIENCE` | No | Copy as-is (`https://ticketing-platform.eu.auth0.com`) |
| `AUTH_AUDIENCES__0` | No | Copy as-is (`https://ticketing-platform`) |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |

#### 18. `/{env}/reporting` — FULL BACKUP

**Backed-up keys (8):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `reporting` |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `SQS_QUEUE_URL` | **YES** | Update region in URL |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |

#### 19. `/{env}/transfer` — FULL BACKUP

**Backed-up keys (9):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `CONNECTION_STRINGS` | **YES** | Update RDS host. Database name: `transfer` |
| `Logging__Elasticsearch__Uri` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Username` | — | **DELETE** (dead) |
| `Logging__Elasticsearch__Password` | — | **DELETE** (dead) |
| `AWS_ACCESS_KEY` | **YES** | Update to new IAM user credentials |
| `AWS_ACCESS_SECRET` | **YES** | Update to new IAM user credentials |
| `SQS_QUEUE_URL` | **YES** | Update region in URL |
| `SHARED_CODE_SECRET_KEY` | No | **Copy as-is — CRITICAL** (HMAC key for transfer share codes) |
| `LUMIGO_TRACER_TOKEN` | No | Copy as-is |

#### 20. `/{env}/xp-badges` — FULL BACKUP

**Backed-up keys (1):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `GOOGLE_SHEETS_PRIVATE_KEY` | No | Copy as-is (RSA private key — region-independent). Note: xp-badges is excluded from migration per Decisions table. |

#### 21. `devops` — FULL BACKUP

**Backed-up keys (1):**
| Key | Value Type | Action |
|-----|-----------|--------|
| `devops` | SSH public key | Used by Terraform for EC2 key pairs (`aws_key_pair.devops`). Copy as-is. |

#### 22. `/rds/ticketing-cluster` — FULL BACKUP

**Backed-up keys (6):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `username` | No | Copy as-is (`devops`) |
| `password` | No | Copy as-is — **CRITICAL** (RDS master password, also needed for `terraform` secret) |
| `engine` | No | Copy as-is (`postgres`) |
| `host` | **YES** | Update to new Aurora cluster endpoint after restore |
| `port` | No | Copy as-is (`5432`) |
| `dbClusterIdentifier` | No | Copy as-is (`ticketing`) |

#### 23. `prod/data` — FULL BACKUP

**Backed-up keys (12):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `type` | No | Copy as-is (`service_account`) |
| `project_id` | No | Copy as-is |
| `private_key_id` | No | Copy as-is |
| `private_key` | No | Copy as-is (RSA private key) |
| `client_email` | No | Copy as-is (`mdlbeast-pg-data-sync@...`) |
| `client_id` | No | Copy as-is |
| `auth_uri` | No | Copy as-is |
| `token_uri` | No | Copy as-is |
| `auth_provider_x509_cert_url` | No | Copy as-is |
| `client_x509_cert_url` | No | Copy as-is |
| `universe_domain` | No | Copy as-is |
| `credentials` | No | Copy as-is (base64-encoded GCP service account) |

**Entire secret is region-independent.** Copy as-is.

#### 24. `terraform` — FULL BACKUP (previously reported as FAILED)

**Backed-up keys (3):**
| Key | Region-Dependent | Action |
|-----|-----------------|--------|
| `rds` | No | Copy as-is — this is the RDS master password. **CRITICAL** for Terraform `secretmanager.tf`. |
| `redis` | — | **OMIT** (Redis deprecated — do not recreate) |
| `opensearch` | — | **OMIT** (OpenSearch deprecated — do not recreate) |

**Note:** The Terraform secret key is `rds` (not `rds_pass` — that's the Terraform *variable* name). The plan's Phase 2.3 Step 1 script correctly extracts the password from `/rds/ticketing-cluster` backup, but the `terraform` secret backup itself is now available as an alternative source. Reconstruct as:

```json
{"rds": "<password-from-backup>"}
```

---

## SSM Parameters

### Manual — Must Exist Before CDK Deploy

**Updated 2026-03-25:** All 3 Slack webhook URLs and SUBNET_1 are now backed up. ticketing-cluster-sg is also backed up.

| Parameter Path | Value | Source | Backup Status | Notes |
|---|---|---|---|---|
| `/{env}/tp/VPC_NAME` | `ticketing` | Static | **BACKED UP** | CDK's `CdkStackUtilities.GetTicketingVpc` reads this |
| `/{env}/tp/SUBNET_1` | Subnet ID | Terraform output | **BACKED UP** (me-south-1 value: `06aa0798b2b9008fc`) | New value from Terraform |
| `/{env}/tp/SUBNET_2` | Subnet ID | Terraform output | **BACKED UP** (me-south-1 value: `027eaf2f55be58e82`) | New value from Terraform |
| `/{env}/tp/SUBNET_3` | Subnet ID | Terraform output | **BACKED UP** (me-south-1 value: `0b62e26a6ef8bb536`) | New value from Terraform |
| `/rds/ticketing-cluster-identifier` | `ticketing` | Aurora restore | **BACKED UP** | Reuse original name (region-scoped) |
| `/rds/ticketing-cluster-sg` | Security group ID | Terraform output | **BACKED UP** (me-south-1 value: `sg-0955697f31d92d787`) | New value from Terraform |
| `/{env}/tp/DomainCertificateArn` | ACM ARN | ACM request | Not backed up — new cert | Main gateway API cert |
| `/{env}/tp/geidea/DomainCertificateArn` | ACM ARN | ACM request | **BACKED UP** (me-south-1 ARN — not usable) | New cert needed |
| `/{env}/tp/SlackNotification/ErrorsWebhookUrl` | Webhook URL | Slack workspace | **BACKED UP** — value available in `backup-ssm/` | Copy as-is (Slack webhooks are region-independent) |
| `/{env}/tp/SlackNotification/OperationalErrorsWebhookUrl` | Webhook URL | Slack workspace | **BACKED UP** — value available in `backup-ssm/` | Copy as-is |
| `/{env}/tp/SlackNotification/SuspiciousOrdersWebhookUrl` | Webhook URL | Slack workspace | **BACKED UP** — value available in `backup-ssm/` | Copy as-is |
| `/{env}/tp/SlackNotification/IgnoredErrorsPatterns` | `info:,Information` | Config | **BACKED UP** | StringList — copy as-is |
| `/{env}/tp/pdf/generator/STORAGE_BUCKET_NAME` | Bucket name | S3 bucket name | Not backed up — new bucket | e.g., `tickets-pdf-download-eu` |

**PDF Generator additional SSM params** (under `/{env}/tp/pdf/generator/`):

| Parameter | Value | Notes |
|---|---|---|
| `STORAGE_BUCKET_NAME` | `tickets-pdf-download-eu` | S3 bucket for PDFs |
| `PDF_SERVICE_URL` | `https://mdlbeast.pdfgeneratorapi.com/api/v3` | From media secret backup |
| `PDF_SERVICE_API_KEY` | API key | From media secret backup |
| `PDF_SERVICE_API_SECRET` | API secret | From media secret backup |
| `PDF_SERVICE_WORKSPACE_ID` | `ilyas.assainov@mdlbeast.com` | From media secret backup |
| `STORAGE_EXPIRATION_HOURS` | Hours | Configuration value — check with team, default `48` |

**CSV Generator additional SSM params** (under `/{env}/tp/csv/generator/`):

| Parameter | Value | Notes |
|---|---|---|
| `STORAGE_BUCKET_NAME` | `ticketing-csv-reports-eu` | S3 bucket for CSVs |
| `EMAIL_SERVICE_API_KEY` | SendGrid key | Same key as organizations secret backup (`EMAIL_SERVICE_API_KEY`) |
| `EMAIL_SERVICE_FROM` | `tickets@mdlbeast.com` | Sender address |
| `STORAGE_EXPIRATION_HOURS` | Hours | Configuration value — check with team, default `48` |

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
| `CONNECTION_STRINGS_Sales` | Legacy artifact in sales secret — no code reads this key |

---

## Critical Reconstruction Warnings

1. **`ENCRYPTION_KEY` and `ENCRYPTION_IV` are PRESERVED.** ~~The original values are lost.~~ The access-control backup succeeded — both keys are in `__prod__access-control.json`. Copy them exactly to preserve decryption of existing PII data. **Do NOT generate new keys.**

2. **`SHARED_CODE_SECRET_KEY` (transfer service) is PRESERVED.** The transfer backup contains this HMAC key. Copy it exactly to the new secret.

3. **`CONNECTION_STRINGS` are ALL backed up** and contain the exact database names, user IDs, and connection parameters for each service. Update only the `Host=` values to the new Aurora endpoints. Preserve per-service differences:
   - `access` database uses database name `access` (not `access_control`)
   - `catalogue` uses `User ID=catalogue` (not `devops`)
   - `inventory` uses database name `inventoryprod` and `Maximum Pool Size=500`
   - All other services use `User ID=devops`

4. **Only ecwid has missing keys.** 8 non-sensitive configuration values (store IDs, base URLs, category codes) must come from vendor dashboards. All actual secrets/credentials are backed up. Additionally, `customers` is missing `HyperPay_BaseUrl` (verify if this comes from CDK env-var JSON instead).

5. **`PDF_FUNCTION_URL` in media secret** is actually an SQS queue URL (not a Lambda function URL as previously documented). It points to `TP_PDF_Generator_Service_Queue_prod` — same as `SQS_QUEUE_URL`. Both need region update.

6. **`terraform` secret has the RDS password directly.** No need to cross-reference with `/rds/ticketing-cluster` backup — both sources have the password. Use either.

7. **Slack webhook URLs are now backed up** from SSM. These are region-independent and can be copied directly to the new region — no need to retrieve from Slack workspace.
