#!/bin/bash
# deploy-all-services.sh — Deploy all service CDK stacks for a given environment
#
# Usage: ENV=sandbox ./deploy-all-services.sh [service-name]
#   If service-name is provided, only deploy that service.
#   If omitted, deploy all services in tier order.

set -euo pipefail

export AWS_PROFILE=AdministratorAccess-307824719505
export CDK_DEFAULT_ACCOUNT=307824719505
export CDK_DEFAULT_REGION=eu-central-1

ENV="${ENV:-sandbox}"
export ENV_NAME="$ENV"

ROOT="/Users/paulo/Repositories/mdlbeasts/ticketing-platform"
DEPLOY_SCRIPT="$ROOT/.personal/tasks/2026-03-05_aws-region-migration/deploy-service-cdk.sh"

TOTAL=0
SUCCESS=0
FAILED=0
FAILED_LIST=()

log() { echo ""; echo "══════════════════════════════════════════"; echo "  $1"; echo "══════════════════════════════════════════"; }

# Pre-create log groups for a service
# Args: service_prefix env
create_log_groups() {
  local svc="$1"
  local env="$2"
  local P="--region eu-central-1"

  # Common patterns — create all, ignore if exists
  for suffix in "serverless-${env}-function" "consumers-lambda-${env}" "background-jobs-lambda-${env}" "db-migrator-lambda-${env}"; do
    aws logs create-log-group --log-group-name "/aws/lambda/${svc}-${suffix}" $P 2>/dev/null || true
  done
}

# Build, package, and deploy a service
# Args: repo_name cdk_path lambda_package_dirs publish_dirs stacks...
deploy_service() {
  local repo="$1"; shift
  local cdk_path="$1"; shift
  local lambda_dirs="$1"; shift   # comma-separated, or NONE
  local publish_dirs="$1"; shift  # comma-separated, or NONE
  local stacks=("$@")

  local service_dir="$ROOT/$repo"

  log "$repo ($ENV)"
  TOTAL=$((TOTAL+1))

  cd "$service_dir"

  # Step 1: Clean publish directories
  echo "[1] Cleaning publish dirs..."
  find . -path "*/bin/Release/net8.0/publish" -type d -exec rm -rf {} + 2>/dev/null || true

  # Step 2: Build
  echo "[2] Building..."
  if ! dotnet restore --verbosity quiet 2>&1 | tail -2; then
    echo "  RESTORE FAILED"
    FAILED=$((FAILED+1)); FAILED_LIST+=("$repo:restore"); return 1
  fi
  if ! dotnet build --no-restore --verbosity quiet 2>&1 | tail -3; then
    echo "  BUILD FAILED"
    FAILED=$((FAILED+1)); FAILED_LIST+=("$repo:build"); return 1
  fi

  # Step 3: Package Lambda projects (class libraries)
  if [[ "$lambda_dirs" != "NONE" ]]; then
    echo "[3] Packaging Lambda projects..."
    IFS=',' read -ra DIRS <<< "$lambda_dirs"
    for dir in "${DIRS[@]}"; do
      if [ -d "$service_dir/$dir" ]; then
        echo "  dotnet lambda package: $dir"
        rm -rf "$service_dir/$dir/bin/Release/net8.0/publish" 2>/dev/null || true
        cd "$service_dir/$dir"
        if ! dotnet lambda package -c Release 2>&1 | tail -2; then
          echo "  PACKAGE FAILED: $dir"
          FAILED=$((FAILED+1)); FAILED_LIST+=("$repo:package:$dir"); return 1
        fi
        cd "$service_dir"
      fi
    done
  fi

  # Step 3b: Publish Web SDK projects
  if [[ "$publish_dirs" != "NONE" ]]; then
    echo "[3b] Publishing Web SDK projects..."
    IFS=',' read -ra DIRS <<< "$publish_dirs"
    for dir in "${DIRS[@]}"; do
      if [ -d "$service_dir/$dir" ]; then
        echo "  dotnet lambda package: $dir"
        rm -rf "$service_dir/$dir/bin/Release/net8.0/publish" 2>/dev/null || true
        cd "$service_dir/$dir"
        if ! dotnet lambda package -c Release 2>&1 | tail -2; then
          echo "  PACKAGE FAILED: $dir"
          FAILED=$((FAILED+1)); FAILED_LIST+=("$repo:publish:$dir"); return 1
        fi
        cd "$service_dir"
      fi
    done
  fi

  # Step 4: CDK synth + import + deploy
  echo "[4] CDK deploy (${#stacks[@]} stacks)..."
  cd "$service_dir/$cdk_path"

  # Replace {env} in stack names
  local resolved_stacks=()
  for s in "${stacks[@]}"; do
    resolved_stacks+=("${s//\{env\}/$ENV}")
  done

  if ! bash "$DEPLOY_SCRIPT" "$repo" "$cdk_path" "${resolved_stacks[@]}"; then
    echo "  CDK DEPLOY FAILED"
    FAILED=$((FAILED+1)); FAILED_LIST+=("$repo:cdk"); return 1
  fi

  SUCCESS=$((SUCCESS+1))
  echo "✅ $repo deployed successfully"
  cd "$ROOT"
}

# ============================================================
# SERVICE DEFINITIONS
# ============================================================

deploy_catalogue() {
  create_log_groups "catalogue" "$ENV"
  deploy_service ticketing-platform-catalogue \
    "src/TP.Catalogue.Cdk" \
    "src/TP.Catalogue.Consumers" \
    "src/TP.Catalogue.API" \
    "TP-ServerlessBackendStack-catalogue-{env}" \
    "TP-DbMigratorStack-catalogue-{env}"
}

deploy_organizations() {
  create_log_groups "organizations" "$ENV"
  deploy_service ticketing-platform-organizations \
    "src/Organizations/TP.Organizations.Cdk" \
    "src/Organizations/TP.Organizations.BackgroundJobs,src/Organizations/TP.Organizations.Consumers" \
    "src/Organizations/TP.Organizations.API" \
    "TP-ServerlessBackendStack-organizations-{env}" \
    "TP-DbMigratorStack-organizations-{env}" \
    "TP-ConsumersStack-organizations-{env}" \
    "TP-BackgroundJobsStack-organizations-{env}"
}

deploy_loyalty() {
  create_log_groups "loyalty" "$ENV"
  deploy_service ticketing-platform-loyalty \
    "src/TP.Loyalty.Cdk" \
    "src/TP.Loyalty.BackgroundJobs,src/TP.Loyalty.Consumers" \
    "src/TP.Loyalty.API" \
    "TP-ConsumersStack-loyalty-{env}" \
    "TP-BackgroundJobsStack-loyalty-{env}"
}

deploy_csv_generator() {
  create_log_groups "CsvGenerator" "$ENV"
  create_log_groups "csvgenerator" "$ENV"
  deploy_service ticketing-platform-csv-generator \
    "TP.CSVGenerator.Cdk" \
    "TP.CSVGenerator.Consumers" \
    "NONE" \
    "TP-ConsumersStack-CsvGenerator-{env}"
}

deploy_pdf_generator() {
  create_log_groups "pdfgenerator" "$ENV"
  create_log_groups "PdfGenerator" "$ENV"
  deploy_service ticketing-platform-pdf-generator \
    "TP.PdfGenerator.Cdk" \
    "TP.PdfGenerator.Consumers" \
    "NONE" \
    "TP-ConsumersStack-PdfGenerator-{env}"
}

deploy_automations() {
  for fn in weekly-tickets-sender automatic-data-exporter finance-report-sender geidea-data-exporter; do
    aws logs create-log-group --log-group-name "/aws/lambda/${fn}-lambda-${ENV}" --region eu-central-1 2>/dev/null || true
  done
  deploy_service ticketing-platform-automations \
    "src/TP.Automations.Cdk" \
    "src/TP.Automations.WeeklyTicketsSender,src/TP.Automations.AutomaticDataExporter,src/TP.Automations.FinanceReportSender,src/TP.Automations.GeideaDataExporter" \
    "NONE" \
    "TP-WeeklyTicketsSenderStack-automations-{env}" \
    "TP-AutomaticDataExporterStack-automations-{env}" \
    "TP-FinanceReportSenderStack-automations-{env}" \
    "TP-GeideaDataExporterStack-automations-{env}"
}

deploy_extension_api() {
  create_log_groups "extensions" "$ENV"
  deploy_service ticketing-platform-extension-api \
    "TP.Extensions.Cdk" \
    "TP.Extensions.BackgroundJobs,TP.Extensions.Consumers" \
    "TP.Extensions.API" \
    "TP-ServerlessBackendStack-extensions-{env}" \
    "TP-DbMigratorStack-extensions-{env}" \
    "TP-ConsumersStack-extensions-{env}" \
    "TP-BackgroundJobsStack-extensions-{env}"
}

deploy_extension_deployer() {
  aws logs create-log-group --log-group-name "/aws/lambda/ticketing-platform-extension-deployer-${ENV}" --region eu-central-1 2>/dev/null || true
  deploy_service ticketing-platform-extension-deployer \
    "TP.Extensions.Deployer.Cdk" \
    "NONE" \
    "NONE" \
    "TP-ExtensionDeployerLambdaRoleStack-{env}" \
    "TP-ExtensionDeployerStack-{env}"
}

deploy_extension_executor() {
  aws logs create-log-group --log-group-name "/aws/lambda/ticketing-platform-extension-executor-${ENV}" --region eu-central-1 2>/dev/null || true
  deploy_service ticketing-platform-extension-executor \
    "TP.Extensions.Executor.Cdk" \
    "TP.Extensions.Executor" \
    "NONE" \
    "TP-ExtensionExecutorStack-{env}"
}

deploy_extension_log_processor() {
  aws logs create-log-group --log-group-name "/aws/lambda/ticketing-platform-extension-log-processor-${ENV}" --region eu-central-1 2>/dev/null || true
  deploy_service ticketing-platform-extension-log-processor \
    "TP.Extensions.LogsProcessor.Cdk" \
    "TP.Extensions.LogsProcessor.Lambda" \
    "NONE" \
    "TP-ExtensionLogsProcessorStack-{env}"
}

deploy_customer_service() {
  create_log_groups "customers" "$ENV"
  deploy_service ticketing-platform-customer-service \
    "src/TP.Customers.Cdk" \
    "src/TP.Customers.BackgroundJobs,src/TP.Customers.Consumers" \
    "src/TP.Customers.API" \
    "TP-ServerlessBackendStack-customers-{env}" \
    "TP-DbMigratorStack-customers-{env}" \
    "TP-ConsumersStack-customers-{env}" \
    "TP-BackgroundJobsStack-customers-{env}"
}

deploy_inventory() {
  create_log_groups "inventory" "$ENV"
  deploy_service ticketing-platform-inventory \
    "src/TP.Inventory.Cdk" \
    "src/TP.Inventory.BackgroundJobs,src/TP.Inventory.Consumers" \
    "src/TP.Inventory.API" \
    "TP-ServerlessBackendStack-inventory-{env}" \
    "TP-DbMigratorStack-inventory-{env}" \
    "TP-ConsumersStack-inventory-{env}" \
    "TP-BackgroundJobsStack-inventory-{env}"
}

deploy_pricing() {
  create_log_groups "pricing" "$ENV"
  deploy_service ticketing-platform-pricing \
    "src/TP.Pricing.Cdk" \
    "src/TP.Pricing.Consumers" \
    "src/TP.Pricing.API" \
    "TP-ServerlessBackendStack-pricing-{env}" \
    "TP-DbMigratorStack-pricing-{env}" \
    "TP-ConsumersStack-pricing-{env}"
}

deploy_media() {
  create_log_groups "media" "$ENV"
  deploy_service ticketing-platform-media \
    "src/TP.Media.Cdk" \
    "src/TP.Media.BackgroundJobs,src/TP.Media.Consumers,src/TP.Media.Functions" \
    "src/TP.Media.API" \
    "TP-MediaStorageStack-{env}" \
    "TP-ServerlessBackendStack-media-{env}" \
    "TP-DbMigratorStack-media-{env}" \
    "TP-ConsumersStack-media-{env}" \
    "TP-BackgroundJobsStack-media-{env}"
}

deploy_reporting_api() {
  create_log_groups "reporting" "$ENV"
  deploy_service ticketing-platform-reporting-api \
    "src/TP.ReportingService.Cdk" \
    "src/TP.ReportingService.BackgroundJobs,src/TP.ReportingService.Consumers" \
    "src/TP.ReportingService.API" \
    "TP-ServerlessBackendStack-reporting-{env}" \
    "TP-DbMigratorStack-reporting-{env}" \
    "TP-ConsumersStack-reporting-{env}" \
    "TP-BackgroundJobsStack-reporting-{env}"
}

deploy_marketplace() {
  create_log_groups "marketplace" "$ENV"
  deploy_service ticketing-platform-marketplace-service \
    "src/TP.Marketplace.Cdk" \
    "src/TP.Marketplace.BackgroundJobs,src/TP.Marketplace.Consumers" \
    "src/TP.Marketplace.API" \
    "TP-ServerlessBackendStack-marketplace-{env}" \
    "TP-DbMigratorStack-marketplace-{env}" \
    "TP-ConsumersStack-marketplace-{env}" \
    "TP-BackgroundJobsStack-marketplace-{env}"
}

deploy_integration() {
  create_log_groups "integration" "$ENV"
  deploy_service ticketing-platform-integration \
    "src/TP.Integration.Cdk" \
    "src/TP.Integration.BackgroundJobs,src/TP.Integration.Consumers" \
    "src/TP.Integration.API" \
    "TP-ServerlessBackendStack-integration-{env}" \
    "TP-DbMigratorStack-integration-{env}" \
    "TP-ConsumersStack-integration-{env}" \
    "TP-BackgroundJobsStack-integration-{env}"
}

deploy_distribution_portal() {
  create_log_groups "distribution-portal" "$ENV"
  deploy_service ticketing-platform-distribution-portal \
    "src/TP.DistributionPortal.Cdk" \
    "src/TP.DistributionPortal.BackgroundJobs,src/TP.DistributionPortal.Consumers" \
    "src/TP.DistributionPortal.API" \
    "TP-ServerlessBackendStack-distribution-portal-{env}" \
    "TP-DbMigratorStack-distribution-portal-{env}" \
    "TP-ConsumersStack-distribution-portal-{env}" \
    "TP-BackgroundJobsStack-distribution-portal-{env}"
}

deploy_sales() {
  create_log_groups "sales" "$ENV"
  deploy_service ticketing-platform-sales \
    "src/TP.Sales.Cdk" \
    "src/TP.Sales.BackgroundJobs,src/TP.Sales.Consumers" \
    "src/TP.Sales.API" \
    "TP-ServerlessBackendStack-sales-{env}" \
    "TP-DbMigratorStack-sales-{env}" \
    "TP-ConsumersStack-sales-{env}" \
    "TP-BackgroundJobsStack-sales-{env}"
}

deploy_access_control() {
  create_log_groups "accesscontrol" "$ENV"
  create_log_groups "access-control" "$ENV"
  deploy_service ticketing-platform-access-control \
    "src/TP.AccessControl.Cdk" \
    "src/TP.AccessControl.BackgroundJobs,src/TP.AccessControl.Consumers" \
    "src/TP.AccessControl.API" \
    "TP-ServerlessBackendStack-access-control-{env}" \
    "TP-DbMigratorStack-access-control-{env}" \
    "TP-ConsumersStack-access-control-{env}" \
    "TP-BackgroundJobsStack-access-control-{env}"
}

deploy_transfer() {
  create_log_groups "transfer" "$ENV"
  deploy_service ticketing-platform-transfer \
    "src/TP.Transfer.Cdk" \
    "src/TP.Transfer.BackgroundJobs,src/TP.Transfer.Consumers" \
    "src/TP.Transfer.API" \
    "TP-ServerlessBackendStack-transfer-{env}" \
    "TP-DbMigratorStack-transfer-{env}" \
    "TP-ConsumersStack-transfer-{env}" \
    "TP-BackgroundJobsStack-transfer-{env}"
}

deploy_geidea() {
  create_log_groups "geidea" "$ENV"
  deploy_service ticketing-platform-geidea \
    "src/TP.Geidea.Cdk" \
    "src/TP.Geidea.BackgroundJobs,src/TP.Geidea.Consumers,src/TP.Geidea.Lambda.Balance,src/TP.Geidea.Services" \
    "NONE" \
    "TP-ApiStack-geidea-{env}" \
    "TP-ConsumersStack-geidea-{env}" \
    "TP-BackgroundJobsStack-geidea-{env}"
}

deploy_ecwid() {
  create_log_groups "ecwid" "$ENV"
  deploy_service ecwid-integration \
    "src/TP.Ecwid.Cdk" \
    "src/TP.Ecwid.BackgroundJobs,src/TP.Ecwid.Lambda.PaymentCallback,src/TP.Ecwid.Lambda.PaymentCreate,src/TP.Ecwid.Lambda.WebHooks.Anchanto,src/TP.Ecwid.Lambda.WebHooks.Ecwid" \
    "src/TP.Ecwid.API" \
    "TP-ApiStack-ecwid-{env}" \
    "TP-BackgroundJobsStack-ecwid-{env}"
}

deploy_gateway() {
  deploy_service ticketing-platform-gateway \
    "src/Gateway.Cdk" \
    "NONE" \
    "src/Gateway" \
    "TP-GatewayStack-{env}"
}

# ============================================================
# MAIN
# ============================================================

if [ -n "${1:-}" ]; then
  # Deploy single service
  func="deploy_${1//-/_}"
  if declare -f "$func" > /dev/null; then
    "$func"
  else
    echo "Unknown service: $1"
    exit 1
  fi
else
  echo "Deploying ALL services for $ENV environment"
  echo ""

  # Tier 1
  deploy_catalogue
  deploy_organizations
  deploy_loyalty
  deploy_csv_generator
  deploy_pdf_generator
  deploy_automations
  deploy_extension_api
  deploy_extension_deployer
  deploy_extension_executor
  deploy_extension_log_processor
  deploy_customer_service

  # Tier 2
  deploy_inventory
  deploy_pricing
  deploy_media
  deploy_reporting_api
  deploy_marketplace
  deploy_integration
  deploy_distribution_portal

  # Tier 3
  deploy_sales
  deploy_access_control
  deploy_transfer
  deploy_geidea
  deploy_ecwid

  # LAST
  deploy_gateway
fi

echo ""
echo "══════════════════════════════════════════"
echo "  DEPLOYMENT SUMMARY ($ENV)"
echo "══════════════════════════════════════════"
echo "Total: $TOTAL"
echo "Success: $SUCCESS"
echo "Failed: $FAILED"
if [ ${#FAILED_LIST[@]} -gt 0 ]; then
  echo "Failed services:"
  for f in "${FAILED_LIST[@]}"; do echo "  - $f"; done
fi
