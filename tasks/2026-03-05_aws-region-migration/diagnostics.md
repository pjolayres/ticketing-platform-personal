# Diagnostics Log: AWS Region Migration E2E Testing

- [Pre-Production (production-eu) Issues](#pre-production-production-eu-issues)
- [Production Issues](#production-issues)
- [Resolved Issues](#resolved-issues)

> **How to use this log:**
>
> 1. When an issue is discovered during E2E testing, add a new entry under the appropriate environment section.
> 2. Assign a sequential ID (`DIAG-001`, `DIAG-002`, ...) and set status to `OPEN`.
> 3. Fill in as much detail as available — incomplete entries are fine; update them as investigation progresses.
> 4. When resolved, update the status to `RESOLVED`, fill in the resolution fields, and move the entry to the **Resolved Issues** section.
>
> **Status values:** `OPEN` | `INVESTIGATING` | `BLOCKED` | `RESOLVED` | `WONT_FIX`

---

## Pre-Production (production-eu) Issues

_Issues found during P3-S6 E2E validation against `*.production-eu.tickets.mdlbeast.net`._

### DIAG-001: All BackgroundJobs Lambdas crash on startup — missing .runtimeconfig.json

- **Status:** `RESOLVED`
- **Severity:** HIGH
- **Reported:** 2026-03-26T15:00
- **Service(s):** All 13 services with BackgroundJobs Lambdas: access-control, customers, distribution-portal, ecwid, extensions, geidea, integration, inventory, loyalty, marketplace, media, organizations, reporting, sales, transfer
- **Reporter:** Paulo

**Symptoms:**
Every BackgroundJobs Lambda in eu-central-1 fails immediately on cold start with:
```
Error: .NET binaries for Lambda function are not correctly installed in the /var/task directory
of the image when the image was built. The /var/task directory is missing the required
.runtimeconfig.json file.
```
Init duration is ~21ms (instant failure). EventBridge Scheduler schedules trigger the Lambdas on their configured intervals, and every invocation fails. Consumers and ServerlessBackend Lambdas for the same services work fine.

**Reproduction Steps:**
1. Invoke any BackgroundJobs Lambda (e.g., `aws lambda invoke --function-name sales-background-jobs-lambda-prod --payload '{}' /dev/null`)
2. Check CloudWatch log group `/aws/lambda/sales-background-jobs-lambda-prod`
3. Observe `INIT_REPORT` with `Status: error, Error Type: Runtime.ExitError`

**Expected Behavior:**
Lambda initializes .NET 8 runtime, loads the handler assembly, and executes the scheduled job.

**Context:**
- Verified in me-south-1 logs: BackgroundJobs **were working** (last successful invocation 2025-12-26 — `LineItemTotalPriceAdjustmentJob` ran successfully in sales)
- All BackgroundJobs `.csproj` files use `Microsoft.NET.Sdk` (class library SDK), not `Microsoft.NET.Sdk.Web`
- None of the BackgroundJobs projects reference the API project — unlike Consumers, which reference `TP.{Service}.API.csproj` and inherit its `.runtimeconfig.json`
- Lambda config looks correct: handler `TP.Sales.BackgroundJobs::TP.Sales.BackgroundJobs.Function::Handler`, runtime `dotnet8`, code size ~82MB

**Root Cause:**
Packaging mismatch between CI/CD pipeline and manual CDK deployment during migration.

**CI/CD pipeline** (me-south-1, working): Uses `dotnet lambda package` per project (from `Amazon.Lambda.Tools`). This tool generates `.runtimeconfig.json` automatically for class library projects, even when using `Microsoft.NET.Sdk`.

**Migration deployment** (eu-central-1, broken): Used `dotnet publish -c Release` from the solution root, then `cdk deploy` with `Code.FromAsset()` pointing to the `bin/Release/net8.0/publish/` directory. `dotnet publish` does NOT generate `.runtimeconfig.json` for `Microsoft.NET.Sdk` projects by default — only for `Microsoft.NET.Sdk.Web` or executable projects.

Evidence:
- `ticketing-platform-sales/src/TP.Sales.BackgroundJobs/bin/Release/net8.0/publish/` — has `.deps.json` but NO `.runtimeconfig.json`
- `ticketing-platform-sales/src/TP.Sales.Consumers/bin/Release/net8.0/publish/` — has `TP.Sales.API.runtimeconfig.json` (inherited from API project reference)
- CI/CD workflow (`ci-cd.yml` lines 26-27): `cd ../TP.Sales.BackgroundJobs && dotnet lambda package`
- Locally verified: `dotnet publish -p:GenerateRuntimeConfigurationFiles=true` produces the missing file

**Action Taken:**
Ran `dotnet lambda package -c Release` from each of the 15 BackgroundJobs project directories. This populates the `bin/Release/net8.0/publish/` directory with the correct `.runtimeconfig.json` (matching CI/CD behavior). Then ran `cdk deploy` for each BackgroundJobsStack, which uploaded the corrected code and updated the Lambda functions via CloudFormation.

All 15 BackgroundJobsStacks confirmed `UPDATE_COMPLETE` in CloudFormation. Post-fix verification: zero `runtimeconfig` errors in CloudWatch logs. Test invocation of `sales-background-jobs-lambda-prod` confirmed .NET runtime initializes successfully (StatusCode 200).

**Consequences:**
- All 15 BackgroundJobs Lambdas now start correctly
- No code changes or commits required — fix was purely a repackaging with the correct tooling (`dotnet lambda package` vs `dotnet publish`)
- CloudFormation state is clean (deployed via CDK, no drift)
- Background jobs that were failing will resume on their next scheduled invocation
- For future manual deployments: always use `dotnet lambda package` for **all** Lambda projects, not `dotnet publish` from the solution root
- **Note:** DIAG-001 originally stated "Consumers and ServerlessBackend Lambdas work fine." This was incorrect for consumers — see DIAG-002.

**Resolved:** 2026-03-27T00:32Z

### DIAG-002: All Consumer + Automations Lambdas crash on startup — same root cause as DIAG-001

- **Status:** `RESOLVED`
- **Severity:** CRITICAL
- **Reported:** 2026-03-27T10:00
- **Service(s):** All 17 services with Consumer Lambdas, all 3 Automations Lambdas, Extension Executor, Extension Log Processor, Media Functions (23 Lambdas total)
- **Reporter:** Paulo

**Symptoms:**
Same as DIAG-001 — `.runtimeconfig.json` missing, Lambda crashes on cold start with:
```
Error: .NET binaries for Lambda function are not correctly installed in the /var/task directory
of the image when the image was built. The /var/task directory is missing the required
.runtimeconfig.json file.
```

Confirmed in CloudWatch for:
- `*-consumer-lambda-prod` (all consumer Lambdas)
- `automations-automatic-data-exporter-lambda-prod`
- `automations-finance-report-sender-lambda-prod`

All event-driven processing (SQS consumers, EventBridge schedulers) is non-functional. ServerlessBackend (API) Lambdas and Gateway are **unaffected** (they use `Microsoft.NET.Sdk.Web`).

**Root Cause:**
Identical to DIAG-001. All affected projects use `Microsoft.NET.Sdk` (class library SDK). The migration deployment used `dotnet publish -c Release` from the solution root, which does not generate `.runtimeconfig.json` for class library projects.

DIAG-001's assumption that consumers were unaffected ("Consumers reference `TP.{Service}.API.csproj` and inherit its `.runtimeconfig.json`") was **incorrect** — the API project reference does not cause `dotnet publish` to generate a `.runtimeconfig.json` for the consumer project itself.

Only `Microsoft.NET.Sdk.Web` projects (the 17 API/ServerlessBackend projects + Gateway) produce `.runtimeconfig.json` via `dotnet publish`. Everything else requires `dotnet lambda package`.

**Affected Lambdas — Full List (23):**

Consumer Lambdas (17):
| # | Service | CDK Stack | Lambda Function |
|---|---------|-----------|-----------------|
| 1 | access-control | `TP-ConsumersStack-access-control-prod` | `accesscontrol-consumers-lambda-prod` |
| 2 | csv-generator | `TP-ConsumersStack-CsvGenerator-prod` | `csvgenerator-consumers-lambda-prod` |
| 3 | customer-service | `TP-ConsumersStack-customers-prod` | `customers-consumers-lambda-prod` |
| 4 | distribution-portal | `TP-ConsumersStack-distribution-portal-prod` | `dp-consumers-lambda-prod` |
| 5 | extension-api | `TP-ConsumersStack-extensions-prod` | `extensions-consumers-lambda-prod` |
| 6 | geidea | `TP-ConsumersStack-geidea-prod` | `geidea-consumers-lambda-prod` |
| 7 | integration | `TP-ConsumersStack-integration-prod` | `integration-consumers-lambda-prod` |
| 8 | inventory | `TP-ConsumersStack-inventory-prod` | `inventory-consumers-lambda-prod` |
| 9 | loyalty | `TP-ConsumersStack-loyalty-prod` | `loyalty-consumers-lambda-prod` |
| 10 | marketplace | `TP-ConsumersStack-marketplace-prod` | `marketplace-consumers-lambda-prod` |
| 11 | media | `TP-ConsumersStack-media-prod` | `media-consumers-lambda-prod` |
| 12 | organizations | `TP-ConsumersStack-organizations-prod` | `organizations-consumers-lambda-prod` |
| 13 | pdf-generator | `TP-ConsumersStack-PdfGenerator-prod` | `pdf-generator-consumers-lambda-prod` |
| 14 | pricing | `TP-ConsumersStack-pricing-prod` | `pricing-consumers-lambda-prod` |
| 15 | reporting-api | `TP-ConsumersStack-reporting-prod` | `reporting-consumers-lambda-prod` |
| 16 | sales | `TP-ConsumersStack-sales-prod` | `sales-consumers-lambda-prod` |
| 17 | transfer | `TP-ConsumersStack-transfer-prod` | `transfer-consumers-lambda-prod` |

Automations Lambdas (3):
| # | CDK Stack | Lambda Function | Source Project |
|---|-----------|-----------------|----------------|
| 1 | `TP-WeeklyTicketsSenderStack-automations-prod` | `automations-weekly-ticket-sender-lambda-prod` | `TP.Automations.WeeklyTicketsSender` |
| 2 | `TP-AutomaticDataExporterStack-automations-prod` | `automations-automatic-data-exporter-lambda-prod` | `TP.Automations.AutomaticDataExporter` |
| 3 | `TP-FinanceReportSenderStack-automations-prod` | `automations-finance-report-sender-lambda-prod` | `TP.Automations.FinanceReportSender` |

Standalone Lambdas (3):
| # | CDK Stack | Lambda Function | Source Project |
|---|-----------|-----------------|----------------|
| 1 | `TP-ExtensionExecutorStack-prod` | extension executor | `TP.Extensions.Executor.Lambda` |
| 2 | `TP-ExtensionLogsProcessorStack-prod` | extension log processor | `TP.Extensions.LogsProcessor.Lambda` |
| 3 | `TP-MediaStorageStack-prod` | `Media-lambda-prod` | `TP.Media.Functions` |

**Action Plan:**

Fix is identical to DIAG-001: run `dotnet lambda package -c Release` from each project directory, then `cdk deploy` the corresponding stack.

**IMPORTANT:** Before running `dotnet lambda package`, delete the existing `bin/Release/net8.0/publish/` directory to clear stale artifacts from the prior `dotnet publish` run.

_Step 1 — Clean + Repackage all 23 projects:_

For each project below, delete `bin/Release/net8.0/publish/`, then run `dotnet lambda package -c Release`. This creates a clean publish with the correct `.runtimeconfig.json`.

Consumer projects (run from each service's solution root first: `dotnet restore`, then per-project):
```
# Services with consumers (cd into each Consumers project dir)
ticketing-platform-access-control/src/TP.AccessControl.Consumers/
ticketing-platform-csv-generator/TP.CSVGenerator.Consumers/
ticketing-platform-customer-service/src/TP.Customers.Consumers/
ticketing-platform-distribution-portal/src/TP.DistributionPortal.Consumers/
ticketing-platform-extension-api/TP.Extensions.Consumers/
ticketing-platform-geidea/src/TP.Geidea.Consumers/
ticketing-platform-integration/src/TP.Integration.Consumers/
ticketing-platform-inventory/src/TP.Inventory.Consumers/
ticketing-platform-loyalty/src/TP.Loyalty.Consumers/
ticketing-platform-marketplace-service/src/TP.Marketplace.Consumers/
ticketing-platform-media/src/TP.Media.Consumers/
ticketing-platform-organizations/src/Organizations/TP.Organizations.Consumers/
ticketing-platform-pdf-generator/TP.PdfGenerator.Consumers/
ticketing-platform-pricing/src/TP.Pricing.Consumers/
ticketing-platform-reporting-api/src/TP.ReportingService.Consumers/
ticketing-platform-sales/src/TP.Sales.Consumers/
ticketing-platform-transfer/src/TP.Transfer.Consumers/
```

Automations projects:
```
ticketing-platform-automations/src/TP.Automations.WeeklyTicketsSender/
ticketing-platform-automations/src/TP.Automations.AutomaticDataExporter/
ticketing-platform-automations/src/TP.Automations.FinanceReportSender/
```

Standalone projects:
```
ticketing-platform-extension-executor/TP.Extensions.Executor.Lambda/
ticketing-platform-extension-log-processor/TP.Extensions.LogsProcessor.Lambda/
ticketing-platform-media/src/TP.Media.Functions/
```

_Step 2 — CDK deploy all 21 stacks (some services share a CDK project):_

Consumer stacks can be deployed in parallel (independent). Automations and standalone stacks are also independent.

```bash
# Set CDK env vars
export AWS_PROFILE=AdministratorAccess-660748123249
export CDK_DEFAULT_ACCOUNT=660748123249
export CDK_DEFAULT_REGION=eu-central-1
export ENV_NAME=prod

# Deploy all affected stacks (no imports needed — stacks already exist)
# cd into each service's CDK project dir before deploying
# Consumer stacks (17):
cdk deploy TP-ConsumersStack-access-control-prod --require-approval never
cdk deploy TP-ConsumersStack-CsvGenerator-prod --require-approval never
cdk deploy TP-ConsumersStack-customers-prod --require-approval never
cdk deploy TP-ConsumersStack-distribution-portal-prod --require-approval never
cdk deploy TP-ConsumersStack-extensions-prod --require-approval never
cdk deploy TP-ConsumersStack-geidea-prod --require-approval never
cdk deploy TP-ConsumersStack-integration-prod --require-approval never
cdk deploy TP-ConsumersStack-inventory-prod --require-approval never
cdk deploy TP-ConsumersStack-loyalty-prod --require-approval never
cdk deploy TP-ConsumersStack-marketplace-prod --require-approval never
cdk deploy TP-ConsumersStack-media-prod --require-approval never
cdk deploy TP-ConsumersStack-organizations-prod --require-approval never
cdk deploy TP-ConsumersStack-PdfGenerator-prod --require-approval never
cdk deploy TP-ConsumersStack-pricing-prod --require-approval never
cdk deploy TP-ConsumersStack-reporting-prod --require-approval never
cdk deploy TP-ConsumersStack-sales-prod --require-approval never
cdk deploy TP-ConsumersStack-transfer-prod --require-approval never

# Automations stacks (3 — same CDK project, deploy sequentially):
cdk deploy TP-WeeklyTicketsSenderStack-automations-prod --require-approval never
cdk deploy TP-AutomaticDataExporterStack-automations-prod --require-approval never
cdk deploy TP-FinanceReportSenderStack-automations-prod --require-approval never

# Standalone stacks (3):
cdk deploy TP-ExtensionExecutorStack-prod --require-approval never
cdk deploy TP-ExtensionLogsProcessorStack-prod --require-approval never
cdk deploy TP-MediaStorageStack-prod --require-approval never  # media's storage stack, not consumers
```

_Step 3 — Verify:_
- Check CloudWatch for each Lambda: zero `runtimeconfig` errors
- Test-invoke one consumer per service category
- Confirm SQS messages are being consumed (DLQ depth should stop growing)

**Expected Behavior:**
All 23 Lambdas initialize .NET 8 runtime successfully and process events.

**Action Taken:**
1. Deleted `bin/Release/net8.0/publish/` in all 23 project directories (clean slate)
2. Ran `dotnet lambda package -c Release` in all 23 project directories — all succeeded, `.runtimeconfig.json` verified present in every publish directory
3. Ran `cdk deploy` for all 23 stacks (4 parallel at a time) — all 23 confirmed `UPDATE_COMPLETE` in CloudFormation

**Consequences:**
- All 23 Lambdas now have correct `.runtimeconfig.json` and initialize successfully
- No code changes or commits required — fix was purely repackaging + redeployment
- CloudFormation state is clean (deployed via CDK, no drift)
- Consumers will process backlogged SQS messages automatically
- Automations scheduled jobs will resume on next EventBridge trigger

**Resolved:** 2026-03-27T09:53Z

### DIAG-003: Extension Deployer Lambda crashes on startup — ARM64/x86_64 architecture mismatch

- **Status:** `RESOLVED`
- **Severity:** HIGH
- **Reported:** 2026-03-27T14:00
- **Service(s):** `ticketing-platform-extension-deployer-prod`
- **Reporter:** Paulo

**Symptoms:**
Extension deployer Lambda fails immediately on every cold start with:
```
INIT_REPORT Init Duration: 4.59 ms  Phase: init  Status: error  Error Type: Runtime.InvalidEntrypoint
Error: fork/exec /lambda-entrypoint.sh: exec format error
Runtime.InvalidEntrypoint
```
Init duration is ~4ms (instant failure). The Lambda never initializes the .NET runtime. SQS messages from `TP_Extensions_Deployer_Queue_prod` are never processed, blocking all extension deployments (PM-2).

**Reproduction Steps:**
1. `aws lambda invoke --function-name ticketing-platform-extension-deployer-prod --payload '{}' --profile AdministratorAccess-660748123249 --region eu-central-1 /tmp/out.json`
2. Check CloudWatch log group `/aws/lambda/ticketing-platform-extension-deployer-prod`
3. Observe `INIT_REPORT` with `Status: error, Error Type: Runtime.InvalidEntrypoint` and `exec format error`

**Expected Behavior:**
Lambda initializes .NET 8 runtime via the Docker entrypoint and processes SQS events.

**Context:**
- This is the **only** Docker image-based Lambda (`PackageType: Image`) in eu-central-1. All other 81 Lambdas are zip-based and unaffected.
- During P3-S5-08, `dotnet lambda deploy-function` was run from a Mac (Apple Silicon/ARM64). Docker pulled the `arm64` variant of the multi-arch base image `public.ecr.aws/lambda/dotnet:8-preview`, built an ARM64 image, and pushed it to ECR.
- The Lambda is configured for `x86_64` architecture → binary incompatibility at the OS/kernel level.
- Confirmed via ECR image inspection: image config showed `"architecture": "arm64"` while Lambda expected `x86_64`.
- The CI/CD pipeline (`main.yml`) runs on `ubuntu-latest` (x86_64) where Docker naturally pulls the amd64 variant — this issue only manifests when deploying from ARM-based machines.

**Root Cause:**
Architecture mismatch between the Docker image pushed to ECR (`arm64`, built on Apple Silicon Mac) and the Lambda execution environment (`x86_64`). The `dotnet lambda deploy-function` command builds the Docker image using the host machine's default platform. On Apple Silicon, Docker defaults to `linux/arm64`. The `exec format error` occurs because the Linux kernel in the Lambda execution environment cannot execute ARM64 binaries.

**Action Taken:**
1. Followed the CI/CD deployment sequence from `ticketing-platform-extension-deployer/.github/workflows/main.yml`
2. Rebuilt with `--docker-build-options "--platform linux/amd64"` to force x86_64:
   ```bash
   cd ticketing-platform-extension-deployer
   dotnet restore && dotnet build --no-restore
   cd TP.Extensions.Deployer.Lambda
   dotnet lambda deploy-function ticketing-platform-extension-deployer-prod \
     --function-subnets subnet-01b47a6d26df020ec,subnet-0b38abd7f712530d9,subnet-05359403da2d9a5fe \
     --function-security-groups sg-0179252e4a8780421 \
     --function-role extensions_deployer_lambda_role_prod \
     --environment-variables "TP_ENVIRONMENT=prod" \
     --docker-build-options "--platform linux/amd64" \
     --region eu-central-1 --profile AdministratorAccess-660748123249
   ```
3. Verified ECR image architecture changed from `arm64` to `amd64`
4. Test invoke returned `StatusCode: 200` with expected `ArgumentNullException` (empty SQS payload) — runtime initialized successfully
5. Confirmed all 82 Lambda functions in eu-central-1: only 1 is image-based (this one), remaining 81 are zip-based — no other functions affected

**Consequences:**
- Extension deployer Lambda is now operational in eu-central-1
- PM-2 (Extension Lambda redeployment) is unblocked
- **Lesson learned:** When deploying Docker image-based Lambdas from Apple Silicon Macs, always pass `--docker-build-options "--platform linux/amd64"` to `dotnet lambda` commands. Zip-based Lambdas are unaffected because AWS provides the runtime.
- No code changes or commits required — fix was purely a rebuild + redeploy with correct platform target

**Resolved:** 2026-03-27T14:30

<!--
### DIAG-XXX: [Short title]

- **Status:** `OPEN`
- **Severity:** CRITICAL | HIGH | MEDIUM | LOW
- **Reported:** YYYY-MM-DDThh:mm
- **Service(s):**
- **Reporter:**

**Symptoms:**
What was observed — error messages, HTTP status codes, unexpected behavior.

**Reproduction Steps:**
1. Step one
2. Step two
3. ...

**Expected Behavior:**
What should have happened.

**Context:**
Relevant logs, CloudWatch excerpts, stack traces, screenshots, related deviations from execution.md.

**Root Cause:**
_(Fill in after investigation.)_

**Action Taken:**
_(Fill in after fix.)_

**Consequences:**
Downstream impact — affected services, config changes, code changes, commits, secrets updated, SSM params changed, etc.

**Resolved:** YYYY-MM-DDThh:mm
-->

---

## Production Issues

_Issues found during P4-S6 E2E validation against `*.production.tickets.mdlbeast.net` and P4-S7 post-go-live monitoring._

_(No issues logged yet.)_

---

## Resolved Issues

_Issues moved here after resolution, grouped by environment._

### Pre-Production

_(None yet.)_

### Production

_(None yet.)_
