# Deployment & Operations Reference

**Last Updated:** 2026-03-04
**Platform:** MDLBEAST Ticketing Platform -- polyglot microservices monorepo (30+ services)
**AWS Region:** me-south-1 (Bahrain)

---

## Table of Contents

1. [Environment & Branching Strategy](#1-environment--branching-strategy)
2. [GitHub Actions -- Reusable Template Workflows](#2-github-actions--reusable-template-workflows)
3. [CI/CD -- .NET Backend Services (Standard Pattern)](#3-cicd--net-backend-services-standard-pattern)
4. [CI/CD -- Infrastructure Repo](#4-cicd--infrastructure-repo)
5. [CI/CD -- Dashboard (Next.js -> Vercel)](#5-cicd--dashboard-nextjs---vercel)
6. [CI/CD -- Distribution Portal Frontend (Next.js -> Vercel)](#6-cicd--distribution-portal-frontend-nextjs---vercel)
7. [CI/CD -- Mobile Scanner (Expo/EAS -> S3 + CloudFront)](#7-cicd--mobile-scanner-expoeas---s3--cloudfront)
8. [CI/CD -- Tools (NuGet Publishing)](#8-cicd--tools-nuget-publishing)
9. [CI/CD -- ConfigMaps (EKS Deployment)](#9-cicd--configmaps-eks-deployment)
10. [CI/CD -- Terraform (S3 State Sync)](#10-cicd--terraform-s3-state-sync)
11. [AWS CDK Deployment Patterns](#11-aws-cdk-deployment-patterns)
12. [Lambda Packaging & Deployment](#12-lambda-packaging--deployment)
13. [Database Migration Pattern](#13-database-migration-pattern)
14. [EKS / Kubernetes Deployment](#14-eks--kubernetes-deployment)
15. [Docker & Helm Charts](#15-docker--helm-charts)
16. [Configuration Management](#16-configuration-management)
17. [Secrets Management (AWS Secrets Manager)](#17-secrets-management-aws-secrets-manager)
18. [Parameters (AWS Parameter Store)](#18-parameters-aws-parameter-store)
19. [Terraform Infrastructure](#19-terraform-infrastructure)
20. [Monitoring & Observability](#20-monitoring--observability)
21. [Deployment Dependencies & Ordering](#21-deployment-dependencies--ordering)
22. [Operational Runbooks](#22-operational-runbooks)

---

## 1. Environment & Branching Strategy

Four environments, each with its own branch and AWS credential set:

| Git Branch    | Environment | AWS Secrets Used                                              |
|---------------|-------------|---------------------------------------------------------------|
| `development` | `dev`       | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`                 |
| `sandbox`     | `sandbox`   | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`                 |
| `demo`        | `demo`      | `AWS_ACCESS_KEY_ID_DEMO` / `AWS_SECRET_ACCESS_KEY_DEMO`       |
| `production`  | `prod`      | `AWS_ACCESS_KEY_ID_PROD` / `AWS_SECRET_ACCESS_KEY_PROD`       |

**Notes:**
- ConfigMap repos use branch name `master` (not `production`) and map to their respective environments.
- The mobile scanner uses `release/development`, `release/sandbox`, `release/production` branches instead.
- The tools repo publishes NuGet on push to `master` or `development`.

**Environment suffix resolution** used consistently across CDK stack names in CI:

```bash
github.ref == 'refs/heads/production' && 'prod'
|| github.ref == 'refs/heads/sandbox'  && 'sandbox'
|| github.ref == 'refs/heads/demo'     && 'demo'
|| 'dev'
```

**Promotion path:** `development` -> `sandbox` -> `production`

---

## 2. GitHub Actions -- Reusable Template Workflows

All backend services call shared reusable workflows from:
`mdlbeasts/ticketing-platform-templates-ci-cd/.github/workflows/` (at `@master`)

Key reusable workflows:

| Workflow                         | What It Does                                                              |
|----------------------------------|---------------------------------------------------------------------------|
| `tests.yml`                      | Restore, build, run `dotnet test` with NuGet feed configured              |
| `deploy-cdk.yml`                 | Install CDK + Lambda tools, restore, build, package Lambdas, `cdk deploy` |
| `cloudwatch-logs-creator.yml`    | Create CloudWatch Log Groups for Lambda functions before deploy            |
| `blazemeter.yml`                 | Run load tests (only on `development` branch, after deploy)               |

**Secrets passed to all CDK deploy jobs:**
- `AWS_ACCESS_KEY_ID` (env-conditional)
- `AWS_SECRET_ACCESS_KEY` (env-conditional)
- `PAT_USERNAME` -- GitHub PAT username for private NuGet feed
- `PAT_TOKEN` -- GitHub PAT token for private NuGet feed
- `AWS_DEFAULT_REGION`
- `SLACK_WEBHOOK_URL` -- Slack notification on deploy

---

## 3. CI/CD -- .NET Backend Services (Standard Pattern)

**Services using this pattern:**
`access-control`, `catalogue`, `sales`, `inventory`, `reporting-api`, `media`, `pricing`, `transfer`, `loyalty`, `marketplace-service`, `organizations`, `geidea`, `integration`, `extension-api`, `distribution-portal`

**Workflow file:** `.github/workflows/ci-cd.yml` in each service repo

### When Tests Run

Tests run on the reusable `tests.yml` only when:
- Push to `development`, OR
- PR where base is `development`, OR
- PR where head is NOT `development` or `sandbox` (i.e., feature -> sandbox/prod PRs)

Tests are **skipped** on pushes to `sandbox`, `demo`, `production` branches.

### Full Deploy Pipeline (e.g., sales)

**File:** `ticketing-platform-sales/.github/workflows/ci-cd.yml`

```
tests
  |
  v (skipped if not development push or feature PR)
deploy-db-migration       <- cdk deploy TP-DbMigratorStack-{service}-{env}
  |
  v
run-db-migration          <- aws lambda invoke {service}-db-migrator-lambda-{env}
  |
  v
create-log-groups         <- cloudwatch-logs-creator.yml (creates /aws/lambda/... log groups)
  |
  v
deploy-cdk                <- cdk deploy ConsumersStack, BackgroundJobsStack, ServerlessBackendStack
  |
  v (development only)
blazemeter                <- load tests
```

### CDK Stacks Deployed Per Service (typical full-featured service)

```bash
cdk deploy TP-DbMigratorStack-{service}-{env}         --require-approval never
cdk deploy TP-ConsumersStack-{service}-{env}          --require-approval never
cdk deploy TP-BackgroundJobsStack-{service}-{env}     --require-approval never
cdk deploy TP-ServerlessBackendStack-{service}-{env}  --require-approval never
```

### Lambda Functions Per Service (naming convention)

| Lambda Function Name                     | Purpose                    |
|------------------------------------------|----------------------------|
| `{service}-serverless-{env}-function`    | API Lambda (API Gateway)   |
| `{service}-db-migrator-lambda-{env}`     | DB migration (EF Core)     |
| `{service}-consumers-lambda-{env}`       | SQS consumer               |
| `{service}-background-jobs-lambda-{env}` | Scheduled background jobs  |

**Examples for sales/dev:**
- `sales-serverless-dev-function`
- `sales-db-migrator-lambda-dev`
- `sales-consumers-lambda-dev`
- `sales-background-jobs-lambda-dev`

### Services Without DB Migration Step

Some simple services skip the DB migration jobs and go straight to `deploy-cdk`:

| Service         | Workflow File                                                      | Stacks Deployed                                         |
|-----------------|--------------------------------------------------------------------|---------------------------------------------------------|
| `pdf-generator` | `ticketing-platform-pdf-generator/.github/workflows/main.yml`      | `TP-ConsumersStack-PdfGenerator-{env}`                  |
| `csv-generator` | `ticketing-platform-csv-generator/.github/workflows/main.yml`      | (consumer stack only)                                   |

### Services with Different Deploy Patterns

| Service              | Difference                                                                     |
|----------------------|--------------------------------------------------------------------------------|
| `catalogue`          | No `BackgroundJobsStack` or `ConsumersStack` -- only `ServerlessBackendStack`   |
| `extension-deployer` | Uses `dotnet lambda deploy-function` directly (not CDK for Lambda deploy)       |
| `extension-executor` | Uses artifact upload/download between build and deploy jobs                     |

---

## 4. CI/CD -- Infrastructure Repo

**File:** `ticketing-platform-infrastructure/.github/workflows/main.yml`

This is the foundational stack. Must be deployed before services that depend on the event bus or SQS queues.

### Stacks Deployed

```bash
cdk deploy TP-EventBusStack-{env}                    --require-approval never
cdk deploy TP-MonitoringStack-{env}                  --require-approval never
cdk deploy TP-ConsumersSqsStack-{env}                --require-approval never
cdk deploy TP-ConsumerSubscriptionStack-{env}        --require-approval never
cdk deploy TP-ExtendedMessageS3BucketStack-{env}     --require-approval never
cdk deploy TP-InternalCertificateStack-{env}         --require-approval never
cdk deploy TP-InternalHostedZoneStack-{env}          --require-approval never

# Only on sandbox, demo, prod (NOT development):
cdk deploy TP-SlackNotificationStack-{env}           --require-approval never
cdk deploy TP-XRayInsightNotificationStack-{env}     --require-approval never

# No env suffix (shared):
cdk deploy TP-ApiGatewayVpcEndpointStack             --require-approval never
cdk deploy TP-RdsProxyStack                          --require-approval never
```

### Lambda Packaged Before Deploy

```bash
cd ./TP.Infrastructure.SlackNotifier && dotnet lambda package
```

### Additional Operational Workflows

| Workflow                                                       | Trigger          | Purpose                                                          |
|----------------------------------------------------------------|------------------|------------------------------------------------------------------|
| `ticketing-platform-infrastructure/.github/workflows/serverless-restart.yml` | Manual dispatch | Restarts all Lambda functions by cycling concurrency to 0 |
| `ticketing-platform-infrastructure/.github/workflows/rdsproxy.yml`           | Manual dispatch | Toggles RDS Proxy in all service CONNECTION_STRINGS secrets |

---

## 5. CI/CD -- Dashboard (Next.js -> Vercel)

**File:** `ticketing-platform-dashboard/.github/workflows/vercel-deploy.yml`

Triggers on push to: `development`, `sandbox`, `production`

```bash
# development -> preview deploy
vercel --token ${VERCEL_TOKEN} --env ENVIRONMENT=development

# sandbox -> preview deploy
vercel --token ${VERCEL_TOKEN} --env ENVIRONMENT=sandbox

# production -> production deploy (with --force)
vercel --force --token ${VERCEL_TOKEN} --prod
```

**Secrets required:** `VERCEL_TOKEN`, `VERCEL_PROJECT_ID`, `VERCEL_TEAM_ID`

### Additional Dashboard Workflows

| Workflow                                                            | Trigger                  | Purpose                                           |
|---------------------------------------------------------------------|--------------------------|---------------------------------------------------|
| `ticketing-platform-dashboard/.github/workflows/unit-tests.yml`    | PR -> development        | Jest unit tests (`npm run test -- --ci`)           |
| `ticketing-platform-dashboard/.github/workflows/tests.yml`         | Every push               | Cypress E2E headless tests                        |
| `ticketing-platform-dashboard/.github/workflows/linter.yml`        | Every push               | TypeScript check + ESLint + `npm run build`        |
| `ticketing-platform-dashboard/.github/workflows/chromatic.yml`     | PR -> development        | Chromatic visual regression on Hue design system  |
| `ticketing-platform-dashboard/.github/workflows/storybook-deploy.yml` | Push to development/sandbox | Build Storybook -> S3 -> CloudFront invalidation |
| `ticketing-platform-dashboard/.github/workflows/create-release.yml`| Push to production       | Create GitHub release tagged `latest`             |
| `ticketing-platform-dashboard/.github/workflows/pr-title-checker.yml` | PR events             | Enforce PR title format                           |
| `ticketing-platform-dashboard/.github/workflows/jira-description-action.yml` | PR events       | Jira integration for PR descriptions              |

### Dashboard Build Configuration

```bash
NODE_OPTIONS="--max-old-space-size=6144" next build --experimental-debug-memory-usage
```

6 GB memory required. Always set `NEXT_TELEMETRY_DISABLED=1`.

The linter workflow runs on `github-hosted-runner` (custom runner label), not `ubuntu-latest`.

### Storybook Deployment (S3 + CloudFront)

Each deployment creates a timestamped folder in S3, then updates CloudFront origin path:
- Bucket: `vars.STORYBOOK_BUCKET_NAME` (env var, not secret)
- Distribution: `vars.STORYBOOK_CLOUDFRONT_DISTRIBUTION_ID`
- Invalidation path: `/*` after each deploy

---

## 6. CI/CD -- Distribution Portal Frontend (Next.js -> Vercel)

**File:** `ticketing-platform-distribution-portal-frontend/.github/workflows/vercel-deploy.yml`

Identical pattern to dashboard -- same branching (`development`, `sandbox`, `production`), same Vercel CLI approach. Production deploy uses `vercel --prod` (without `--force`).

---

## 7. CI/CD -- Mobile Scanner (Expo/EAS -> S3 + CloudFront)

**Service:** `ticketing-platform-mobile-scanner`
**Platform:** Android only (APK)

### Branching Strategy (Mobile-specific)

Mobile uses different branch names from the rest of the platform:

| Git Branch            | Profile      | EAS Channel   |
|-----------------------|--------------|---------------|
| `release/development` | development  | development   |
| `release/sandbox`     | sandbox      | sandbox       |
| `release/production`  | production   | production    |
| `testing/**`          | testing      | testing       |
| PRs to `development`  | (preview)    | testing       |

### Workflows

**`ticketing-platform-mobile-scanner/.github/workflows/release-build.yml`** -- Full native APK build + S3 upload

Triggers on push to `release/development`, `release/sandbox`, `release/production`, `testing/**`

Steps:
1. Set profile/branch variables
2. Install JDK 17, Node 18.19.x
3. Authenticate GitHub Packages (`@mdlbeasts` npm registry)
4. Setup EAS (`expo/expo-github-action@v8`)
5. Install qrencode and ImageMagick
6. Create `credentials.json` and `release.keystore` from secrets
7. `npm run prebuild` (Expo prebuild for Android)
8. `npm run local:{profile}` (EAS local build -> APK in `builds/{profile}/`)
9. Delete credential files
10. Upload APK to S3: `s3://{S3}/mdlbeast-scanner/{profile}/v{version}_runtime-{runtime}_build-{versionCode}_{timestamp}/`
11. Generate annotated QR code (qrencode + ImageMagick)
12. CloudFront invalidation for `latest.png`
13. Slack notification with QR code and download link

**S3 path structure:**
```
mdlbeast-scanner/{profile}/v{version}_runtime-{runtime}_build-{versionCode}_{timestamp}/
  |- mdlbeast-scanner_{profile}_v{version}_runtime-{runtime}_build-{versionCode}.apk
  |- {QR_CODE_FILENAME}.png
  |- {JSON_DETAILS_FILENAME}.json

mdlbeast-scanner/{profile}/
  |- latest.png     (always overwritten)
  |- latest.json    (always overwritten)
```

**`ticketing-platform-mobile-scanner/.github/workflows/release-update.yml`** -- OTA JS bundle update via EAS Update

Triggers on push to `release/development`, `release/sandbox`, `release/production`

```bash
npm run update:{profile}
# which runs: eas update --platform android --branch {profile} --non-interactive --auto
```

**`ticketing-platform-mobile-scanner/.github/workflows/preview-update.yml`** -- OTA preview on PR to development

```bash
eas update --platform android --branch testing --non-interactive --auto
```

**`ticketing-platform-mobile-scanner/.github/workflows/sentry-source-map.yml`** -- Upload source maps to Sentry

Triggers on push to `development`:
```bash
npx expo export --platform android --dump-sourcemap
npx sentry-expo-upload-sourcemaps dist
```

**`ticketing-platform-mobile-scanner/.github/workflows/code-format.yml`** -- PR quality gate (-> development)

Runs: Prettier, ESLint, TypeScript check, Jest unit tests.

### Version Management

Version info comes from `package.json` fields:
```json
{
  "version": "1.1.26",
  "metadata": {
    "runtimeVersion": "1.1.3",
    "versionCode": "160"
  }
}
```

- `version` -- human-readable semver
- `runtimeVersion` -- Expo runtime version (controls OTA update compatibility)
- `versionCode` -- Android build number (must increment for each full build)

### EAS Build Profiles (`ticketing-platform-mobile-scanner/eas.json`)

```json
{
  "build": {
    "development": {
      "channel": "development",
      "distribution": "internal",
      "android": { "credentialsSource": "local", "buildType": "apk" }
    },
    "sandbox": {
      "channel": "sandbox",
      "distribution": "internal",
      "android": { "credentialsSource": "local", "buildType": "apk" }
    },
    "production": {
      "channel": "production",
      "distribution": "internal",
      "android": { "buildType": "apk", "credentialsSource": "local" }
    }
  }
}
```

### Local Build Commands

```bash
npm run local:development   # dev profile APK
npm run local:sandbox       # sandbox profile APK
npm run local:production    # prod profile APK

# OTA updates (no full rebuild):
npm run update:development
npm run update:sandbox
npm run update:production
```

### Required Secrets (mobile)

- `GH_PACKAGES_TOKEN` -- GitHub Packages auth
- `EXPO_TOKEN` -- Expo/EAS authentication
- `CREDENTIALS_JSON` -- Android signing credentials JSON
- `RELEASE_KEYSTORE` -- Android keystore (base64-encoded)
- `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN`
- `EXPO_PUBLIC_ADVANCED_PIN`
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (region: me-south-1)
- `S3` -- S3 bucket name
- `CLOUDFRONT` -- CloudFront distribution URL
- `CLOUDFRONT_DISTRIBUTION_ID`
- `SLACK_WEBHOOK`

---

## 8. CI/CD -- Tools (NuGet Publishing)

**File:** `ticketing-platform-tools/.github/workflows/nuget.yml`
**Triggers:** Push to `master` or `development`

### NuGet Packages Published

All to `https://nuget.pkg.github.com/mdlbeasts/index.json`:

| Package                     | Version Strategy          |
|-----------------------------|---------------------------|
| `TP.Tools.DataAccessLayer`  | `x.y.{github.run_number}` |
| `TP.Tools.Helpers`          | `x.y.{github.run_number}` |
| `TP.Tools.Infrastructure`   | `x.y.{github.run_number}` |
| `TP.Tools.Logger`           | `x.y.{github.run_number}` |
| `TP.Tools.MessageBroker`    | `x.y.{github.run_number}` |
| `TP.Tools.RestVersioning`   | `x.y.{github.run_number}` |
| `TP.Tools.SharedEntities`   | `x.y.{github.run_number}` |
| `TP.Tools.Swagger`          | `x.y.{github.run_number}` |
| `TP.Tools.Validator`        | `x.y.{github.run_number}` |
| `TP.Tools.PhoneNumbers`     | `x.y.{github.run_number}` |
| `TP.Tools.BackgroundJobs`   | `x.y.{github.run_number}` |
| `TP.Tools.Libs.Entities`    | `x.y.{github.run_number}` |

**Patch version** = `github.run_number` (auto-incremented by CI). Major.minor in `.csproj` files is managed manually.

```bash
dotnet build --configuration Release
dotnet pack --no-restore --no-build --configuration Release --include-symbols --output $OUTPUT_DIR
dotnet nuget push $OUTPUT_DIR/*.nupkg --source "github" --api-key $GITHUB_TOKEN --skip-duplicate
```

**Consuming the packages in services (Dockerfile / CI):**
```bash
dotnet nuget add source \
  --username {PAT_USERNAME} \
  --password {PAT_TOKEN} \
  --store-password-in-clear-text \
  --name github \
  https://nuget.pkg.github.com/mdlbeasts/index.json
```

### Tests Workflow

**File:** `ticketing-platform-tools/.github/workflows/tests.yml`
**Triggers:** PR to `master`

```bash
dotnet restore && dotnet build --no-restore && dotnet test --no-build --verbosity normal
```

---

## 9. CI/CD -- ConfigMaps (EKS Deployment)

Three repos, each deploying to EKS via `kubectl apply`:

| Repo                                      | Branch   | Runner          | Container Image                                      | EKS Cluster |
|-------------------------------------------|----------|-----------------|------------------------------------------------------|-------------|
| `ticketing-platform-configmap-dev`        | `master` | `dev` (self-hosted) | `registry.gitlab.com/nrglv.rmn/aws-cli-helm`       | `eks`       |
| `ticketing-platform-configmap-sandbox`    | `master` | `dev` (self-hosted) | `registry.gitlab.com/nrglv.rmn/aws-cli-helm`       | `eks`       |
| `ticketing-platform-configmap-prod`       | `master` | `self-hosted`       | `matshareyourscript/aws-helm-kubectl`               | `eks`       |

**Dev/sandbox deploy** (`ticketing-platform-configmap-dev/.github/workflows/ci.yml`):
```bash
aws eks update-kubeconfig --name eks
kubectl apply -f manifests/
```

**Prod deploy** (`ticketing-platform-configmap-prod/.github/workflows/ci.yml`):
```bash
aws eks update-kubeconfig --name eks
kubectl apply -f manifests/organizations.yml
kubectl apply -f manifests/gateway.yml
kubectl apply -f manifests/inventory.yml
kubectl apply -f manifests/sales.yml
kubectl apply -f manifests/catalogue.yml
kubectl apply -f manifests/integration.yml
kubectl apply -f manifests/pricing.yml
kubectl apply -f manifests/access-control.yml
kubectl apply -f manifests/media.yml
kubectl apply -f manifests/ingress.yml
```

**Note:** Prod configmap applies manifests individually (not `kubectl apply -f manifests/`), providing selective deployment control.

**Disaster recovery** (`ticketing-platform-configmap-prod/.github/workflows/disaster.yml`):
Triggers on push to `disaster` branch. Runs on `prod` runner, uses `aws-cli-helm` image:
```bash
aws eks update-kubeconfig --name eks-prod
kubectl apply -f manifests-new/
```

### Manifest Structure

Each service has two manifest files per environment:

| File                    | Kind             | Purpose                                                              |
|-------------------------|------------------|----------------------------------------------------------------------|
| `{service}-{env}.yml`   | `ConfigMap`      | Non-secret env vars (namespace: `ticketing-dev` / `ticketing-sandbox` / `ticketing`) |
| `{service}-sm.yml`      | `ExternalSecret` | Pulls secrets from AWS Secrets Manager (refreshInterval: 1h)         |

**Namespaces:**
- Dev: `ticketing-dev`
- Sandbox: `ticketing-sandbox`
- Prod: `ticketing`

---

## 10. CI/CD -- Terraform (S3 State Sync)

Both Terraform repos sync their committed state files to S3 on push to `master`. This does NOT run `terraform apply` -- it only copies the state for backup/sharing.

| Repo                               | S3 Destination                          | AWS Creds Used                          |
|------------------------------------|------------------------------------------|-----------------------------------------|
| `ticketing-platform-terraform-dev` | `s3://ticketing-terraform-github/dev`    | `AWS_ACCESS_KEY_ID_PROD` / `AWS_SECRET_ACCESS_KEY_PROD` |
| `ticketing-platform-terraform-prod`| `s3://ticketing-terraform-github/prod`   | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` |

Both run in a `registry.gitlab.com/gitlab-org/cloud-deploy/aws-base:latest` container.

```bash
# dev: ticketing-platform-terraform-dev/.github/workflows/s3.yml
aws s3 sync dev s3://ticketing-terraform-github/dev

# prod: ticketing-platform-terraform-prod/.github/workflows/s3.yml
aws s3 sync prod s3://ticketing-terraform-github/prod
```

**To actually apply Terraform changes, run manually:**
```bash
cd ticketing-platform-terraform-dev/dev
aws configure --profile dev
terraform init
terraform plan
terraform apply
```

### Terraform State Backend

```hcl
# dev
backend "s3" {
  profile = "dev"
  bucket  = "ticketing-terraform-dev"
  key     = "terraform.tfstate"
  region  = "me-south-1"
  encrypt = true
}

# prod
backend "s3" {
  profile = "prod"
  bucket  = "ticketing-terraform-prod"
  key     = "terraform.tfstate"
  region  = "me-south-1"
  encrypt = true
}
```

---

## 11. AWS CDK Deployment Patterns

### Stack Naming Convention

```
TP-{StackClassName}-{service-slug}-{env}
```

Examples:
- `TP-ServerlessBackendStack-sales-dev`
- `TP-ConsumersStack-access-control-prod`
- `TP-DbMigratorStack-catalogue-sandbox`
- `TP-BackgroundJobsStack-extensions-demo`

**Exceptions (no env suffix):**
- `TP-ApiGatewayVpcEndpointStack` (shared across envs)
- `TP-RdsProxyStack` (shared across envs)

### CDK App Configuration

CDK programs read `ENV_NAME` from environment variables (set by CI) or `appsettings.json`:

```csharp
var envName = configuration["ENV_NAME"]
    ?? throw new ArgumentNullException("ENV_NAME");

var stackProps = new StackProps
{
    Env = new Amazon.CDK.Environment
    {
        Account = Environment.GetEnvironmentVariable("CDK_DEFAULT_ACCOUNT"),
        Region = Environment.GetEnvironmentVariable("CDK_DEFAULT_REGION"),
    }
};
```

### Service CDK Stack Types

| Stack Type         | Class Name              | What It Deploys                                           |
|--------------------|-------------------------|-----------------------------------------------------------|
| Serverless API     | `ServerlessBackendStack`| Lambda + API Gateway (internal, VPC endpoint) + Route53  |
| Consumers          | `ConsumersStack`        | Lambda + SQS event source mapping                         |
| Background Jobs    | `BackgroundJobsStack`   | Lambda + EventBridge Scheduler                            |
| DB Migrator        | `DbMigratorStack`       | Lambda for running EF Core migrations                     |

### Lambda Configuration (typical)

```csharp
private const int LambdaTimeoutInSeconds = 900;      // 15 minutes
private const int LambdaMemorySize = 2048;           // MB (non-prod)
private const int ProdLambdaMemorySize = 4000;       // MB (prod)
// Log retention: THREE_MONTHS
// X-Ray tracing: IS_XRAY_ENABLED env var controls it
```

### Environment Variables for Lambda

Each service CDK stack loads from `env-var.{env}.json` (JSON file committed in the Cdk project):

```csharp
new EnvironmentVariableFile($"env-var.{_environment}.json").Load(lambda);
```

### Slack Log Subscription (automatic)

After deploying, CDK subscribes Lambda logs to the Slack notifier:

```csharp
SlackNotifierStackHelper.SubscribeLogsToSlackNotifier(
    lambda, _env, this, SlackNotifierStackHelper.ServerlessPattern);
```

---

## 12. Lambda Packaging & Deployment

### Standard Packaging Command

```bash
cd ./src/TP.{Service}.API
dotnet lambda package

cd ./src/TP.{Service}.Consumers
dotnet lambda package

cd ./src/TP.{Service}.BackgroundJobs
dotnet lambda package
```

Produces a zip in `bin/Release/net8.0/`. CDK reads from `../TP.{Service}.API/bin/Release/net8.0/publish`.

### Lambda Tool Installation

```bash
dotnet tool install -g Amazon.Lambda.Tools --version 5.4.5
```

### Lambda Handler Naming Pattern

```csharp
// API
"TP.Sales.API::TP.Sales.API.LambdaEntry::FunctionHandlerAsync"

// DB Migrator
"TP.Sales.API::TP.Sales.API.DatabaseMigrationLambdaEntry::Handler"

// Consumer
"TP.Sales.Consumers::TP.Sales.Consumers.Function::Handler"
```

### Direct Lambda Deploy (Extension Deployer -- non-CDK)

`ticketing-platform-extension-deployer` deploys the function directly with `dotnet lambda deploy-function`:

```bash
cd ./TP.Extensions.Deployer.Lambda
dotnet lambda deploy-function ticketing-platform-extension-deployer-{env} \
  --function-subnets subnet-{SUBNET_1},subnet-{SUBNET_2},subnet-{SUBNET_3} \
  --function-security-groups {SG_ID} \
  --function-role extensions_deployer_lambda_role_{env} \
  --environment-variables "TP_ENVIRONMENT={env}"
```

Subnet IDs fetched from SSM at `/{env}/tp/SUBNET_1`, `/{env}/tp/SUBNET_2`, `/{env}/tp/SUBNET_3`.

### Extension Deployer Deploy Flow

**File:** `ticketing-platform-extension-deployer/.github/workflows/main.yml`

```
env_selector -> tests -> build -> deploy
```

Deploy steps:
1. CDK deploy `TP-ExtensionDeployerLambdaRoleStack-{env}` (IAM role)
2. Get subnet IDs from SSM
3. Get security group ID from AWS EC2
4. `dotnet lambda deploy-function` with VPC config
5. CDK deploy `TP-ExtensionDeployerStack-{env}` (remaining infra)

### Extension Executor Deploy Flow

**File:** `ticketing-platform-extension-executor/.github/workflows/main.yml`

```
env_selector -> tests -> build (with artifact upload) -> deploy (artifact download + cdk deploy)
```

Uses `actions/upload-artifact@v2` / `actions/download-artifact@v2` between build and deploy jobs.

---

## 13. Database Migration Pattern

DB migrations run via a dedicated Lambda per service. CI pipeline sequence:
1. Deploy migration Lambda via CDK (`DbMigratorStack`)
2. Invoke it directly via AWS CLI
3. Parse response JSON for `Success: true`

### Migration Lambda Invocation

```bash
RESPONSE=$(aws lambda invoke \
  --function-name "{service}-db-migrator-lambda-{env}" \
  --payload '{}' \
  --log-type Tail \
  output.json)

echo $RESPONSE | jq -r '.LogResult' | base64 -d   # base64-encoded CloudWatch logs

SUCCESS=$(cat output.json | jq -r '.Success')
if [ "$SUCCESS" != "true" ]; then
  echo "Migration failed!"
  exit 1
fi
```

### Migration Response Format

```json
{
  "Success": true,
  "Message": "...",
  "Timestamp": "...",
  "AppliedMigrations": ["Migration1", "Migration2"]
}
```

### EF Core Migration Commands (local)

```bash
dotnet ef migrations add MigrationName \
  --project src/TP.{Service}.Infrastructure \
  --startup-project src/TP.{Service}.API

dotnet ef database update \
  --project src/TP.{Service}.Infrastructure \
  --startup-project src/TP.{Service}.API
```

### Services with DB Migrations

Based on CI/CD workflows, these services have `DbMigratorStack`:
- access-control, catalogue, sales, inventory, organizations, pricing, media, transfer, loyalty, marketplace-service, geidea, integration, extension-api, distribution-portal, reporting-api

---

## 14. EKS / Kubernetes Deployment

Some services run as **long-lived containers in EKS** alongside Lambda. The platform uses a dual-deployment model where services can run both as Lambda (serverless) and as EKS pods.

### EKS Cluster Topology

| Environment     | Cluster Name | Runner Label  | Namespace          |
|-----------------|-------------|---------------|--------------------|
| Dev + Sandbox   | `eks`       | `dev`         | `ticketing-dev` / `ticketing-sandbox` |
| Prod (normal)   | `eks`       | `self-hosted` | `ticketing`        |
| Prod (disaster) | `eks-prod`  | `prod`        | (via `manifests-new/`) |

### Services with EKS Deployment

From configmap manifests: `gateway`, `organizations`, `inventory`, `sales`, `catalogue`, `integration`, `pricing`, `access-control`, `media`, `extensions`, `distribution-portal`, `reporting`, `transfer`

### Service-to-Service Communication (Kubernetes DNS)

```
http://{service}.{namespace}.svc.cluster.local:5000
```

Examples from configmap:
```yaml
SalesClusterAddress: "http://sales.ticketing-dev.svc.cluster.local:5000"
InventoryClusterAddress: "http://inventory.ticketing-dev.svc.cluster.local:5000"
OrganizationsClusterAddress: "http://organizations.ticketing-dev.svc.cluster.local:5000"
```

### Prod Ingress (`ticketing-platform-configmap-prod/ingress.yml`)

- External host: `api.production.tickets.mdlbeast.net`
- ALB scheme: `internet-facing`
- HTTPS 443 only (HTTP redirected)
- Health check path: `/` with 404 as success code
- Internal: `grafana.dev.tickets.mdlbeast.net` (kube-prometheus-stack-grafana)

### IAM Service Account (EKS -> Secrets Manager)

Creates IRSA (IAM Role for Service Account) so pods can access Secrets Manager:
```bash
eksctl create iamserviceaccount \
  --name eks-secret-manager-sandbox \
  --namespace ticketing-sandbox \
  --cluster eks \
  --role-name "eks-secret-manager-sandbox" \
  --attach-policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite \
  --approve \
  --override-existing-serviceaccounts
```

---

## 15. Docker & Helm Charts

### Dockerfile Pattern (.NET services)

All .NET services follow the same multi-stage Docker build pattern.

**Standard service Dockerfile** (`ticketing-platform-sales/Dockerfile`):
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/TP.Sales.API/TP.Sales.API.csproj", "src/TP.Sales.API/"]
COPY ["src/TP.Sales.Domain/TP.Sales.Domain.csproj", "src/TP.Sales.Domain/"]
COPY ["src/TP.Sales.Infrastructure/TP.Sales.Infrastructure.csproj", "src/TP.Sales.Infrastructure/"]

ARG PACKAGE_SOURCE="https://nuget.pkg.github.com/mdlbeasts/index.json"
RUN dotnet nuget add source --username {PAT_USERNAME} --password {PAT_TOKEN} \
    --store-password-in-clear-text --name github $PACKAGE_SOURCE
RUN dotnet restore "src/TP.Sales.API/TP.Sales.API.csproj"
COPY . .
WORKDIR "/src/src/TP.Sales.API"
RUN dotnet build "TP.Sales.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "TP.Sales.API.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
EXPOSE 5000
ENV ASPNETCORE_HTTP_PORTS=5000
ENV ASPNETCORE_URLS=http://*:5000
ENTRYPOINT ["dotnet", "TP.Sales.API.dll"]
```

**Gateway Dockerfile** (`ticketing-platform-gateway/Dockerfile`) -- exposes port 80 instead of 5000:
```dockerfile
ENV ASPNETCORE_HTTP_PORTS=80
ENTRYPOINT ["dotnet", "Gateway.dll"]
```

### Helm Chart Structure

Each service with EKS deployment has a `helm/` directory:

```
{service}/helm/
  Chart.yaml          # name: {service}, version: 0.1.0
  .helmignore
  values-dev.yaml     # dev-specific values
  values-prod.yaml    # prod-specific values
  templates/
    deployment.yml    # Deployment with RollingUpdate strategy
    service.yml       # ClusterIP Service
```

### Helm Values Pattern

**Dev** (`ticketing-platform-sales/helm/values-dev.yaml`):
```yaml
nameOverride: sales
fullnameOverride: sales
replicaCount: 1
pullPolicy: "Always"
imagePullSecrets: "regcred"
image:
  repository: ""
containerPort: 5000
type: ClusterIP
terminationGracePeriodSeconds: 60
limitsMemory: 1024Mi
limitsCPU: 1000m
requestsMemory: 512Mi
requestsCPU: 500m
envSecrets:
  CONNECTION_STRINGS: sales
  # ... (secret key -> secret name mapping)
```

**Prod** -- doubles resource limits:
```yaml
limitsMemory: 2048Mi
limitsCPU: 2048m
requestsMemory: 1024Mi
requestsCPU: 1024m
```

### Deployment Template Features

From `ticketing-platform-gateway/helm/templates/deployment.yml`:
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 25%
    maxSurge: 75%
```

- Rolling update strategy for zero-downtime deployments
- ConfigMap mounted via `envFrom.configMapRef`
- Secrets mounted via individual `env.valueFrom.secretKeyRef`
- Image pull secret: `regcred` (ECR credentials)

### ECR Repositories

From Terraform (`ticketing-platform-terraform-dev/dev/ecr.tf`):
- `ticketing-platform-ecr` -- service Docker images
- `helm-chart` -- Helm chart storage

---

## 16. Configuration Management

### Architecture: ConfigMap + ExternalSecret

Each EKS service gets two Kubernetes resources:

1. **ConfigMap** (`{service}-{env}.yml`) -- non-secret configuration:
   - Log levels, feature flags, Serilog settings
   - Service URLs (cluster-local DNS)
   - Payment settings, environment identifiers
   - `IS_SWAGGER_ENABLED: "true"` in dev, `"false"` in prod

2. **ExternalSecret** (`{service}-sm.yml`) -- sensitive values pulled from AWS Secrets Manager:
   - `refreshInterval: 1h` -- secrets sync every hour
   - Pulls from `/{env}/{service}` secret by property name

### ExternalSecret Example

From `ticketing-platform-configmap-dev/manifests/sales-sm.yml`:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: sales
  namespace: ticketing-dev
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: secretsmanager
    kind: SecretStore
  target:
    name: sales
    creationPolicy: Owner
  data:
  - secretKey: CONNECTION_STRINGS
    remoteRef:
      key: /dev/sales
      property: CONNECTION_STRINGS
  - secretKey: Checkout__SecretKey
    remoteRef:
      key: /dev/sales
      property: Checkout__SecretKey
```

### SecretStore Configuration

Each namespace has a SecretStore pointing to AWS Secrets Manager:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: secretsmanager
  namespace: ticketing-sandbox
spec:
  provider:
    aws:
      service: SecretsManager
      region: me-south-1
      auth:
        jwt:
          serviceAccountRef:
            name: eks-secret-manager-sandbox
```

### Lambda Configuration (CDK services)

Lambda env vars loaded from JSON file per environment, inside the Cdk project directory (committed, non-secret):
```
TP.{Service}.Cdk/
  env-var.dev.json
  env-var.sandbox.json
  env-var.prod.json
```

### ConfigMap Typical Contents

From `ticketing-platform-configmap-dev/manifests/sales-dev.yml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sales
  namespace: ticketing-dev
data:
  IS_SWAGGER_ENABLED: 'true'
  InventoryServiceBaseRoute: 'http://inventory.ticketing-dev.svc.cluster.local:5000'
  PricingServiceBaseRoute: 'http://pricing.ticketing-dev.svc.cluster.local:5000'
  CatalogueServiceBaseRoute: 'http://catalogue.ticketing-dev.svc.cluster.local:5000'
  OrganizationServiceBaseRoute: 'http://organizations.ticketing-dev.svc.cluster.local:5000'
  Checkout__Environment: 'Sandbox'
  TP_ENVIRONMENT: 'dev'
  ApplicationName: 'sales'
  Serilog__MinimumLevel__Default: 'Information'
  STORAGE_REGION: 'me-south-1'
```

---

## 17. Secrets Management (AWS Secrets Manager)

### Naming Convention

```
/{env}/{service}
```

Examples:
- `/dev/sales`
- `/sandbox/inventory`
- `/prod/access-control`
- `/prod/gateway`

**Special paths:**
- `/rds/ticketing-cluster` -- RDS master credentials (JSON with `host`, `password`)
- `/rds/ticketing-cluster-ro-endpoint` -- RDS read-only endpoint (in SSM, not Secrets Manager)

### Secret Structure (JSON)

Each secret at `/{env}/{service}` is a JSON object. Common keys:
```json
{
  "CONNECTION_STRINGS": "Host=...;Database=...;Username=...;Password=...;",
  "Logging__Elasticsearch__Uri": "https://...",
  "Logging__Elasticsearch__Username": "devops",
  "Logging__Elasticsearch__Password": "...",
  "Checkout__SecretKey": "...",
  "AWS_ACCESS_KEY": "...",
  "AWS_ACCESS_SECRET": "...",
  "SQS_QUEUE_URL": "https://sqs.me-south-1.amazonaws.com/..."
}
```

### RDS Proxy Toggle

Manual workflow at `ticketing-platform-infrastructure/.github/workflows/rdsproxy.yml`.

Actions: `enable_rds_proxy` or `disable_rds_proxy`

The workflow:
1. Fetches RDS Proxy endpoint from SSM (`/rds/RdsProxyEndpoint`)
2. Fetches RDS Proxy RO endpoint from SSM (`/rds/RdsProxyReadOnlyEndpoint`)
3. Fetches current RDS cluster host from Secrets Manager (`/rds/ticketing-cluster`)
4. Fetches RO host from SSM (`/rds/ticketing-cluster-ro-endpoint`)
5. Lists all secrets with prefix `/{env}/`
6. For each secret with a `CONNECTION_STRINGS` key, replaces RDS host with proxy endpoint (or vice versa)
7. Updates each secret via `aws secretsmanager update-secret`

### Cross-Service Secret References

Some ExternalSecrets reference other services' secrets. Example from `ticketing-platform-configmap-dev/manifests/sales-sm.yml`:
```yaml
- secretKey: SEATSIO_API_KEY
  remoteRef:
    key: /dev/inventory        # references inventory's secret, not sales'
    property: SEATSIO_API_KEY
```

---

## 18. Parameters (AWS Parameter Store)

### Naming Convention

```
/{env}/tp/{resource}/{parameter}
```

### Known SSM Parameters

| Path                                                   | Used By                       | Purpose                                |
|--------------------------------------------------------|-------------------------------|----------------------------------------|
| `/{env}/tp/consumers/{Service}/queue-arn`              | ConsumersStack, services      | SQS queue ARN per consumer             |
| `/{env}/tp/SUBNET_1`                                   | Extension Deployer            | Lambda subnet ID 1                     |
| `/{env}/tp/SUBNET_2`                                   | Extension Deployer            | Lambda subnet ID 2                     |
| `/{env}/tp/SUBNET_3`                                   | Extension Deployer            | Lambda subnet ID 3                     |
| `/{env}/tp/SlackNotification/ErrorsWebhookUrl`         | SlackNotificationStack        | Main error channel webhook             |
| `/{env}/tp/SlackNotification/OperationalErrorsWebhookUrl` | SlackNotificationStack     | Ops errors channel webhook             |
| `/{env}/tp/SlackNotification/SuspiciousOrdersWebhookUrl`  | SlackNotificationStack     | Suspicious orders channel webhook      |
| `/{env}/tp/SlackNotification/IgnoredErrorsPatterns`    | ErrorFilterService            | Patterns for filtering false alerts    |
| `/rds/RdsProxyEndpoint`                                | rdsproxy.yml workflow         | RDS Proxy endpoint hostname            |
| `/rds/RdsProxyReadOnlyEndpoint`                        | rdsproxy.yml workflow         | RDS Proxy RO endpoint hostname         |
| `/rds/ticketing-cluster-ro-endpoint`                   | rdsproxy.yml workflow         | Aurora cluster RO endpoint             |

### Reading SSM in CDK

```csharp
// TP.Tools.Infrastructure NuGet
CdkStackUtilities.GetTicketingVpc(scope, env)               // reads VPC from SSM
SlackWebhookParameters.ErrorsWebhookUrl(this, env)          // SSM SecureString lookup
```

---

## 19. Terraform Infrastructure

### Repos

| Repo                               | Backend S3 Bucket           | State Key           | AWS Profile |
|------------------------------------|-----------------------------|--------------------|-------------|
| `ticketing-platform-terraform-dev` | `ticketing-terraform-dev`   | `terraform.tfstate` | `dev`       |
| `ticketing-platform-terraform-prod`| `ticketing-terraform-prod`  | `terraform.tfstate` | `prod`      |

Both backends in region `me-south-1`.

### Resources Managed

| Terraform File                 | Resources                                                      |
|--------------------------------|----------------------------------------------------------------|
| `vpc.tf`                       | VPC `10.10.0.0/16`, Internet Gateway                           |
| `nat.tf`                       | 3 NAT Gateways + Elastic IPs (me-south-1a/1b/1c)              |
| `route-table.tf`               | Public and private route tables                                |
| `rds.tf`                       | Aurora PostgreSQL Serverless v2, 3 instances, engine 15.12     |
| `s3.tf`                        | S3 buckets (PDFs, CSV reports), KMS encryption, lifecycle rules|
| `cloudfront.tf`                | CloudFront distributions (PDF, mobile APK)                     |
| `mobile.tf`                    | S3 + CloudFront for mobile APK distribution                    |
| `ecr.tf`                       | ECR repos: `ticketing-platform-ecr`, `helm-chart`              |
| `eventbridge.tf`               | EventBridge + SQS                                              |
| `lambda-subnet.tf` / `eks-subnet.tf` | EKS/Lambda subnets                                      |
| `msk.tf`                       | 3 MSK (Kafka) subnets                                          |
| `runner.tf`                    | Self-hosted GitHub runner EC2 instances                        |
| `openvpn.tf`                   | OpenVPN server (SSH port 4080, VPN port 6969)                  |
| `managment.tf`                 | Management EC2 instance                                        |
| `route53.tf`                   | DNS zones                                                      |
| `secretmanager.tf`             | Secrets Manager resource references                            |
| `iam-eks.tf`                   | IAM roles/policies for EKS                                     |
| `iam-s3-sqs.tf`                | IAM policies for S3 and SQS access                             |
| `group.tf`                     | Developer IAM group                                            |
| `variables.tf`                 | All variable definitions                                       |

**Prod-only files:**
| `waf.tf`                       | WAF rules (Web Application Firewall)                           |
| `redis.tf`                     | ElastiCache Redis                                              |
| `opensearch.tf`                | OpenSearch/Elasticsearch cluster                               |
| `prometheus.tf`                | Prometheus monitoring infrastructure                           |
| `user-cicd.tf`                 | CI/CD IAM user                                                 |

### Aurora PostgreSQL Serverless v2 Cluster

```hcl
resource "aws_rds_cluster" "ticketing" {
  cluster_identifier  = "ticketing"
  engine              = "aurora-postgresql"
  engine_version      = "15.12"
  engine_mode         = "provisioned"
  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 3.0
  }
  backup_retention_period = 30
  storage_encrypted       = true
  availability_zones      = ["me-south-1a", "me-south-1b", "me-south-1c"]
  preferred_backup_window = "07:00-09:00"
}

# 3 serverless instances
resource "aws_rds_cluster_instance" "ticketing" {
  count          = 3
  instance_class = "db.serverless"
}
```

### S3 Lifecycle (PDF/media buckets)

```hcl
transition { days = 30;  storage_class = "STANDARD_IA" }
transition { days = 60;  storage_class = "GLACIER" }
```

### Network Layout

- **VPC CIDR:** `10.10.0.0/16`
- **OpenVPN CIDR:** `10.8.0.0/24`
- **RDS subnets:** `10.10.50.0/24`, `10.10.51.0/24`, `10.10.52.0/24`
- **AZs:** `me-south-1a`, `me-south-1b`, `me-south-1c`
- **SSH port:** 4080 (non-standard)
- **VPN port:** 6969 (UDP)

---

## 20. Monitoring & Observability

### Sentry

**Dashboard (Next.js):** `@sentry/nextjs` v9+
- Error tracking and performance monitoring
- Configured via `SENTRY_DSN` env var in Vercel

**Mobile Scanner:** `@sentry/react-native` via `sentry-expo`
- Source maps uploaded on every push to `development` via `ticketing-platform-mobile-scanner/.github/workflows/sentry-source-map.yml`

### CloudWatch Logs

Every Lambda function has a corresponding CloudWatch Log Group created by CI before deployment.

**Log group naming:**
```
/aws/lambda/{service}-serverless-{env}-function
/aws/lambda/{service}-db-migrator-lambda-{env}
/aws/lambda/{service}-consumers-lambda-{env}
/aws/lambda/{service}-background-jobs-lambda-{env}
```

**Log retention:** 3 months (`RetentionDays.THREE_MONTHS`)

**Log subscription to Slack notifier:** All serverless and consumer Lambdas auto-subscribe their CloudWatch logs to the Slack notifier Lambda via CDK.

### Slack Notifications (Error Routing)

Three Slack channels, with routing logic in `TP.Infrastructure.SlackNotifier`:

| Channel              | SSM Parameter                                           | Trigger                              |
|----------------------|---------------------------------------------------------|--------------------------------------|
| Errors               | `/{env}/tp/SlackNotification/ErrorsWebhookUrl`          | Default -- all Lambda exceptions      |
| Operational Errors   | `/{env}/tp/SlackNotification/OperationalErrorsWebhookUrl` | Log contains `"operational_error"` |
| Suspicious Orders    | `/{env}/tp/SlackNotification/SuspiciousOrdersWebhookUrl` | Log contains `"suspicious_order"`  |

**Slack notifications are only deployed to sandbox, demo, prod -- NOT development.**

### X-Ray Tracing

Optional per service, controlled via `IS_XRAY_ENABLED` env var in CDK.

**XRay Insight Notifications:**
- EventBridge -> `XRayInsightFunction` Lambda
- DynamoDB dedup table (24h TTL per insight ID) prevents repeated Slack alerts
- Only deployed on sandbox, demo, prod

### Elasticsearch / OpenSearch Logging

Services log structured JSON via Serilog to an OpenSearch cluster inside the VPC:
```yaml
Logging__Elasticsearch__Uri: "https://vpc-ticketing-...me-south-1.es.amazonaws.com"
Logging__Elasticsearch__Index: "sales"       # per-service index
```

### Grafana

Deployed to EKS via Helm (`kube-prometheus-stack-grafana`):
- Internal URL: `grafana.dev.tickets.mdlbeast.net`

### CI/CD Notifications

- All CDK deploy jobs send Slack notification on success/failure via `SLACK_WEBHOOK_URL`
- Mobile builds notify `ticketing-mobile-apps` channel with version info and download QR code
- Extension deployer/executor use `8398a7/action-slack@v3` for structured Slack alerts

### BlazeMeter Load Tests

Run after every successful deploy to `development` branch:
```yaml
blazemeter:
  if: github.ref == 'refs/heads/development'
  needs: [deploy-cdk]
  uses: mdlbeasts/ticketing-platform-templates-ci-cd/.github/workflows/blazemeter.yml@master
```

---

## 21. Deployment Dependencies & Ordering

### First-Time Platform Setup Order

When deploying the entire platform from scratch, resources must be deployed in this order:

```
1. Terraform (VPC, RDS, S3, ECR, Route53, NAT, OpenVPN, MSK)
   -> ticketing-platform-terraform-dev/dev/  (terraform apply)
   -> ticketing-platform-terraform-prod/prod/ (terraform apply)

2. EKS Cluster (created via eksctl, not Terraform)
   -> Create IRSA service accounts for Secrets Manager access

3. NuGet Packages (required by all .NET services)
   -> ticketing-platform-tools (push to master -> nuget.yml publishes)

4. Infrastructure Stacks (EventBridge, SQS, monitoring)
   -> ticketing-platform-infrastructure
   -> Stacks in order:
      a. TP-EventBusStack-{env}
      b. TP-MonitoringStack-{env}
      c. TP-ConsumersSqsStack-{env}
      d. TP-ConsumerSubscriptionStack-{env}
      e. TP-ExtendedMessageS3BucketStack-{env}
      f. TP-InternalHostedZoneStack-{env}
      g. TP-InternalCertificateStack-{env}
      h. TP-ApiGatewayVpcEndpointStack
      i. TP-RdsProxyStack
      j. TP-SlackNotificationStack-{env} (non-dev only)
      k. TP-XRayInsightNotificationStack-{env} (non-dev only)

5. Gateway
   -> ticketing-platform-gateway (Lambda + EKS)

6. Backend Services (can be deployed in parallel)
   -> Each service: DbMigratorStack -> run migration -> log groups -> ConsumersStack + BackgroundJobsStack + ServerlessBackendStack

7. ConfigMaps (EKS configuration)
   -> ticketing-platform-configmap-{env}

8. Frontend
   -> ticketing-platform-dashboard (Vercel)
   -> ticketing-platform-distribution-portal-frontend (Vercel)

9. Mobile
   -> ticketing-platform-mobile-scanner (EAS build + S3)
```

### Per-Service Deploy Dependencies

Each .NET service deployment is self-contained once infrastructure is in place:

```
NuGet packages (TP.Tools.*) must be published first
  -> EventBus + SQS queues must exist (infrastructure repo)
    -> Service can deploy independently
```

### Cross-Service Event Dependencies

If service A publishes events consumed by service B:
1. Service A's event type must exist in shared entities
2. Service B's subscription must be registered in `ticketing-platform-infrastructure`
3. Infrastructure repo must be redeployed to create the EventBridge rule
4. Both services can then be deployed independently

---

## 22. Operational Runbooks

### Restart All Lambda Functions in an Environment

Manual dispatch in GitHub UI:

1. Go to `ticketing-platform-infrastructure` repo -> Actions -> "Restart Serverless Lambdas"
2. Select branch (`development`, `sandbox`, or `production`)
3. Click "Run workflow"

Finds all functions matching `*-serverless-{env}-function`, sets reserved concurrency to 0, waits 3s, removes limit.

### Enable / Disable RDS Proxy

Manual dispatch in GitHub UI:

1. Go to `ticketing-platform-infrastructure` repo -> Actions -> "RDS Proxy Pipeline"
2. Choose action: `enable_rds_proxy` or `disable_rds_proxy`
3. Select branch (determines environment)

Updates `CONNECTION_STRINGS` in all `/{env}/*` Secrets Manager secrets.

### Deploy Service to Production

Standard promotion flow:
1. Merge feature branch -> `development` -> tests run, deploy to dev + BlazeMeter
2. Merge/PR `development` -> `sandbox` -> tests skipped on push, CDK deploy to sandbox
3. Merge/PR `sandbox` -> `production` -> CDK deploy to prod
4. If configmap changed: push to `ticketing-platform-configmap-prod` master

### Update a ConfigMap

1. Edit the relevant `{service}.yml` file in `ticketing-platform-configmap-{env}`
2. Commit and push to `master`
3. CI auto-deploys via `kubectl apply`

### Roll Back a Lambda Deployment

Option 1: Re-run previous CI from GitHub Actions UI -> select the previous commit -> "Re-run jobs"

Option 2: Manual Lambda rollback via AWS CLI:
```bash
# List recent versions
aws lambda list-versions-by-function --function-name {function-name}

# Update to previous code
aws lambda update-function-code \
  --function-name {function-name} \
  --s3-bucket {deployment-bucket} \
  --s3-key {previous-package-key}
```

### Disaster Recovery (EKS)

Push to `disaster` branch in `ticketing-platform-configmap-prod`:
- Switches to `eks-prod` cluster
- Applies `manifests-new/` directory (separate from normal `manifests/`)

### Add a New .NET Service to the Platform

1. Create service repo with standard Clean Architecture structure
2. Add `.github/workflows/ci-cd.yml` following the standard pattern (copy from `ticketing-platform-sales/.github/workflows/ci-cd.yml`)
3. Register consumer in `ticketing-platform-infrastructure`:
   - Add enum entry in `TP.Infrastructure.MessageBroker/Entities/ConsumersServices.cs`
   - Create subscription file in `TP.Infrastructure.MessageBroker/Consumers/Subscriptions/{Service}Subscriptions.cs`
4. Deploy infrastructure repo to create the SQS queue (`ConsumersSqsStack` and `ConsumerSubscriptionStack`)
5. Create `/{env}/{service}` secrets in AWS Secrets Manager (for all environments)
6. Add ConfigMap + ExternalSecret files to all three configmap repos
7. Create Docker image and Helm chart if deploying to EKS
8. Create CDK env-var files (`env-var.dev.json`, etc.) in the Cdk project

### Update NuGet Package Major/Minor Version

Edit the `.csproj` file in `ticketing-platform-tools`:
```xml
<Version>2.1.0</Version>
```

The `0` (patch) is auto-replaced by `github.run_number` on CI publish.

### Subscribe to a New EventBridge Event

In `ticketing-platform-infrastructure/TP.Infrastructure.MessageBroker/Consumers/Subscriptions/{Service}Subscriptions.cs`:

```csharp
yield return new ConsumerSubscription(current)
    .AddEvent<NewEventType>()           // type-safe generic
    .AddEvent(nameof(OtherEvent));      // string-based
```

Then push to `development` to deploy updated `ConsumerSubscriptionStack`.

### Force Rebuild Mobile APK

Push to the appropriate `release/{env}` branch in `ticketing-platform-mobile-scanner`. The CI pipeline will:
1. Build a new APK
2. Upload to S3 with versioned path
3. Update `latest.png` and `latest.json`
4. Send Slack notification with QR code

### OTA Update Mobile Scanner (No Full Rebuild)

Push to the `release/{env}` branch. The `release-update.yml` workflow publishes a JS bundle update via EAS Update:
```bash
eas update --platform android --branch {profile} --non-interactive --auto
```

This does NOT require a new APK -- existing installations will receive the update automatically if `runtimeVersion` matches.

---

*Reference document -- MDLBEAST Ticketing Platform -- AWS Bahrain (me-south-1) -- 2026-03-04*
