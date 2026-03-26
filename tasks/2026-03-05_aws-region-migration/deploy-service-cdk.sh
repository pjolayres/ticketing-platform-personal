#!/bin/bash
# deploy-service-cdk.sh — Deploy a service's CDK stacks with automatic IAM role import
#
# Usage:
#   ./deploy-service-cdk.sh <service-repo-dir> <cdk-project-relative-path> <stack1> [stack2] [stack3] ...
#
# Example:
#   ./deploy-service-cdk.sh ticketing-platform-loyalty src/TP.Loyalty.Cdk \
#     TP-ConsumersStack-loyalty-prod TP-BackgroundJobsStack-loyalty-prod
#
# Prerequisites:
#   export AWS_PROFILE=AdministratorAccess-660748123249
#   export CDK_DEFAULT_REGION=eu-central-1
#   export ENV_NAME=prod
#
# What this script does for each stack:
#   1. Runs `cdk synth` to generate CloudFormation templates
#   2. Parses templates to find IAM roles with physical names (these will conflict)
#   3. Runs `cdk import` with a resource mapping to adopt existing IAM roles
#   4. Runs `cdk deploy` to create the remaining resources
#
# Inline policies were already pre-deleted in bulk during P3-S5-02.
# If a stack has no conflicting IAM roles, it deploys directly.

set -euo pipefail

REPO_ROOT="/Users/paulo/Repositories/mdlbeasts/ticketing-platform"
SERVICE_DIR="$1"
CDK_PATH="$2"
shift 2
STACKS=("$@")

CDK_DIR="$REPO_ROOT/$SERVICE_DIR/$CDK_PATH"

if [ ! -d "$CDK_DIR" ]; then
  echo "ERROR: CDK directory not found: $CDK_DIR"
  exit 1
fi

cd "$CDK_DIR"

echo "============================================"
echo "Service: $SERVICE_DIR"
echo "CDK dir: $CDK_DIR"
echo "Stacks:  ${STACKS[*]}"
echo "============================================"

# Step 1: Synth all stacks to generate templates
echo ""
echo "[1/3] Running cdk synth..."
cdk synth "${STACKS[@]}" 2>&1 | grep -E "^(✨|Error)" || true
echo "Synth complete."

# Step 2+3: For each stack, extract IAM roles, import, then deploy
for STACK in "${STACKS[@]}"; do
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Stack: $STACK"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  TEMPLATE_FILE="$CDK_DIR/cdk.out/$STACK.template.json"
  if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "ERROR: Template not found: $TEMPLATE_FILE"
    exit 1
  fi

  # Extract IAM roles with physical names from the template
  MAPPING=$(python3 -c "
import json
with open('$TEMPLATE_FILE') as f:
    template = json.load(f)
mapping = {}
for lid, res in template.get('Resources', {}).items():
    if res['Type'] == 'AWS::IAM::Role' and 'RoleName' in res.get('Properties', {}):
        mapping[lid] = {'RoleName': res['Properties']['RoleName']}
if mapping:
    print(json.dumps(mapping))
")

  if [ -n "$MAPPING" ]; then
    echo "Found IAM roles to import:"
    echo "$MAPPING" | python3 -c "import sys,json; [print(f'  {v[\"RoleName\"]} (logical: {k})') for k,v in json.loads(sys.stdin.read()).items()]"

    # Check if stack already exists (from a previous run)
    STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK" --region eu-central-1 --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "DOES_NOT_EXIST")

    if [ "$STACK_STATUS" = "ROLLBACK_COMPLETE" ]; then
      echo "Stack in ROLLBACK_COMPLETE — deleting before import..."
      aws cloudformation delete-stack --stack-name "$STACK" --region eu-central-1
      aws cloudformation wait stack-delete-complete --stack-name "$STACK" --region eu-central-1
      echo "Deleted."
      STACK_STATUS="DOES_NOT_EXIST"
    fi

    if [ "$STACK_STATUS" = "DOES_NOT_EXIST" ]; then
      # Write mapping to temp file
      MAPPING_FILE="/tmp/cdk-import-mapping-$STACK.json"
      echo "$MAPPING" > "$MAPPING_FILE"

      echo "Importing IAM roles..."
      cdk import "$STACK" --resource-mapping "$MAPPING_FILE" --force 2>&1 | grep -E "(importing|IMPORT_COMPLETE|✅|❌|Error)" || true
      echo "Import done."
    else
      echo "Stack already exists (status: $STACK_STATUS) — skipping import."
    fi
  else
    echo "No conflicting IAM roles found — deploying directly."
  fi

  # Deploy remaining resources
  echo "Deploying $STACK..."
  cdk deploy "$STACK" --require-approval never 2>&1 | grep -E "(CREATE_|UPDATE_|FAILED|✅|❌|Outputs:|Error|Deployment time)" || true

  # Verify
  FINAL_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK" --region eu-central-1 --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "UNKNOWN")
  if [[ "$FINAL_STATUS" == *"COMPLETE"* ]] && [[ "$FINAL_STATUS" != *"ROLLBACK"* ]]; then
    echo "✅ $STACK — $FINAL_STATUS"
  else
    echo "❌ $STACK — $FINAL_STATUS"
    echo "Stopping. Fix the issue before continuing."
    exit 1
  fi
done

echo ""
echo "============================================"
echo "All stacks deployed successfully!"
echo "============================================"
