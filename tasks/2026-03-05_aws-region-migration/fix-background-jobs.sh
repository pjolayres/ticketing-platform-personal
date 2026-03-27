#!/bin/bash
# Fix DIAG-001: Redeploy all BackgroundJobs Lambdas with correct .runtimeconfig.json
# Uses S3 as intermediary (direct upload via fileb:// hits SSL timeout on large zips)

set -uo pipefail

PROFILE="AdministratorAccess-660748123249"
REGION="eu-central-1"
S3_BUCKET="ticketing-terraform-prod-eu"
S3_PREFIX="lambda-packages"
ROOT="/Users/paulo/Repositories/mdlbeasts/ticketing-platform"

# Each line: function-name|relative-zip-path
ENTRIES=(
  "sales-background-jobs-lambda-prod|ticketing-platform-sales/src/TP.Sales.BackgroundJobs/bin/Release/net8.0/TP.Sales.BackgroundJobs.zip"
  "inventory-background-jobs-lambda-prod|ticketing-platform-inventory/src/TP.Inventory.BackgroundJobs/bin/Release/net8.0/TP.Inventory.BackgroundJobs.zip"
  "loyalty-background-jobs-lambda-prod|ticketing-platform-loyalty/src/TP.Loyalty.BackgroundJobs/bin/Release/net8.0/TP.Loyalty.BackgroundJobs.zip"
  "transfer-background-jobs-lambda-prod|ticketing-platform-transfer/src/TP.Transfer.BackgroundJobs/bin/Release/net8.0/TP.Transfer.BackgroundJobs.zip"
  "access-control-background-jobs-lambda-prod|ticketing-platform-access-control/src/TP.AccessControl.BackgroundJobs/bin/Release/net8.0/TP.AccessControl.BackgroundJobs.zip"
  "customers-background-jobs-lambda-prod|ticketing-platform-customer-service/src/TP.Customers.BackgroundJobs/bin/Release/net8.0/TP.Customers.BackgroundJobs.zip"
  "distribution-portal-background-jobs-lambda-prod|ticketing-platform-distribution-portal/src/TP.DistributionPortal.BackgroundJobs/bin/Release/net8.0/TP.DistributionPortal.BackgroundJobs.zip"
  "extensions-background-jobs-lambda-prod|ticketing-platform-extension-api/TP.Extensions.BackgroundJobs/bin/Release/net8.0/TP.Extensions.BackgroundJobs.zip"
  "geidea-background-jobs-lambda-prod|ticketing-platform-geidea/src/TP.Geidea.BackgroundJobs/bin/Release/net8.0/TP.Geidea.BackgroundJobs.zip"
  "integration-background-jobs-lambda-prod|ticketing-platform-integration/src/TP.Integration.BackgroundJobs/bin/Release/net8.0/TP.Integration.BackgroundJobs.zip"
  "marketplace-background-jobs-lambda-prod|ticketing-platform-marketplace-service/src/TP.Marketplace.BackgroundJobs/bin/Release/net8.0/TP.Marketplace.BackgroundJobs.zip"
  "media-background-jobs-lambda-prod|ticketing-platform-media/src/TP.Media.BackgroundJobs/bin/Release/net8.0/TP.Media.BackgroundJobs.zip"
  "organizations-background-jobs-lambda-prod|ticketing-platform-organizations/src/Organizations/TP.Organizations.BackgroundJobs/bin/Release/net8.0/TP.Organizations.BackgroundJobs.zip"
  "reporting-background-jobs-lambda-prod|ticketing-platform-reporting-api/src/TP.ReportingService.BackgroundJobs/bin/Release/net8.0/TP.ReportingService.BackgroundJobs.zip"
  "ecwid-background-jobs-lambda-prod|ecwid-integration/src/TP.Ecwid.BackgroundJobs/bin/Release/net8.0/TP.Ecwid.BackgroundJobs.zip"
)

TOTAL=${#ENTRIES[@]}
SUCCESS=0
FAILED=0

echo "=== DIAG-001 Fix: Deploying $TOTAL BackgroundJobs Lambdas ==="
echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

for entry in "${ENTRIES[@]}"; do
  func_name="${entry%%|*}"
  zip_rel="${entry##*|}"
  zip_path="$ROOT/$zip_rel"
  s3_key="$S3_PREFIX/${func_name}.zip"
  idx=$((SUCCESS + FAILED + 1))

  if [ ! -f "$zip_path" ]; then
    echo "[$idx/$TOTAL] SKIP $func_name — zip not found"
    FAILED=$((FAILED + 1))
    continue
  fi

  echo -n "[$idx/$TOTAL] $func_name ... "

  # Upload to S3
  if ! aws s3 cp "$zip_path" "s3://$S3_BUCKET/$s3_key" --profile "$PROFILE" --region "$REGION" --quiet 2>/dev/null; then
    echo "FAILED (S3 upload)"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Update Lambda to use S3 object
  result=$(aws lambda update-function-code \
    --function-name "$func_name" \
    --s3-bucket "$S3_BUCKET" \
    --s3-key "$s3_key" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'State' \
    --output text 2>&1)

  if [ $? -eq 0 ]; then
    echo "OK (state: $result)"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "FAILED (Lambda update: $result)"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=== Results: $SUCCESS/$TOTAL succeeded, $FAILED failed ==="
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Cleanup S3 staging files
echo ""
echo "Cleaning up S3 staging files..."
aws s3 rm "s3://$S3_BUCKET/$S3_PREFIX/" --recursive --profile "$PROFILE" --region "$REGION" --quiet 2>/dev/null
echo "Done."
