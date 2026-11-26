#!/usr/bin/env bash
set -euo pipefail

# Auto-setup (re-create) seluruh infrastruktur Week 12 di AWS Sandbox / CloudShell / Git Bash
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
TABLE_NAME="equipment-loans"
FUNCTION_NAME="equipment-loans-api"
API_NAME="equipment-loans-http-api"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ZIP_PATH="$PROJECT_ROOT/function.zip"
LAMBDA_SRC="$PROJECT_ROOT/src/lambda_function.py"

echo "=== 1. Verifikasi Kredensial AWS Sandbox ==="
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/LabRole"
echo "Account ID : $ACCOUNT_ID"
echo "Region     : $REGION"
echo "IAM Role   : $ROLE_ARN"

echo ""
echo "=== 2. Setup DynamoDB Table ($TABLE_NAME) ==="
if ! aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "Mencoba membuat tabel DynamoDB '$TABLE_NAME'..."
  if aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=loan_id,AttributeType=S \
    --key-schema AttributeName=loan_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" >/dev/null 2>&1; then
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION"
  else
    echo "User voclabs tidak punya izin CreateTable langsung; tabel akan otomatis dibuat oleh Lambda (LabRole) saat /health dipanggil."
  fi
else
  echo "Tabel '$TABLE_NAME' sudah ada."
fi

echo ""
echo "=== 3. Package & Deploy AWS Lambda ($FUNCTION_NAME) ==="
zip -j "$ZIP_PATH" "$LAMBDA_SRC" >/dev/null

if ! aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "Membuat Lambda function '$FUNCTION_NAME'..."
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.12 \
    --role "$ROLE_ARN" \
    --handler lambda_function.lambda_handler \
    --zip-file "fileb://$ZIP_PATH" \
    --environment "Variables={TABLE_NAME=$TABLE_NAME}" \
    --timeout 15 \
    --region "$REGION" >/dev/null
  aws lambda wait function-active-v2 --function-name "$FUNCTION_NAME" --region "$REGION"
else
  echo "Mengupdate kode Lambda '$FUNCTION_NAME'..."
  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://$ZIP_PATH" \
    --region "$REGION" >/dev/null
  aws lambda wait function-updated-v2 --function-name "$FUNCTION_NAME" --region "$REGION"
fi

LAMBDA_ARN=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" --query "Configuration.FunctionArn" --output text)

echo ""
echo "=== 4. Setup API Gateway HTTP API ($API_NAME) ==="
API_ID=$(aws apigatewayv2 get-apis --region "$REGION" --query "Items[?Name=='$API_NAME'] | [0].ApiId" --output text)
if [ -z "$API_ID" ] || [ "$API_ID" = "None" ]; then
  API_ID=$(aws apigatewayv2 create-api \
    --name "$API_NAME" \
    --protocol-type HTTP \
    --region "$REGION" \
    --query "ApiId" --output text)

  INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id "$API_ID" \
    --integration-type AWS_PROXY \
    --integration-uri "$LAMBDA_ARN" \
    --payload-format-version "2.0" \
    --region "$REGION" \
    --query "IntegrationId" --output text)

  for ROUTE_KEY in "GET /health" "POST /loans" "GET /loans" "GET /loans/{loan_id}" "PUT /loans/{loan_id}" "DELETE /loans/{loan_id}"; do
    echo "  Menambahkan route: $ROUTE_KEY"
    aws apigatewayv2 create-route \
      --api-id "$API_ID" \
      --route-key "$ROUTE_KEY" \
      --target "integrations/$INTEGRATION_ID" \
      --region "$REGION" >/dev/null
  done

  aws apigatewayv2 create-stage \
    --api-id "$API_ID" \
    --stage-name '$default' \
    --auto-deploy \
    --region "$REGION" >/dev/null
else
  echo "HTTP API '$API_NAME' sudah ada (ApiId: $API_ID)."
fi

aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id "apigateway-invoke-$API_ID" \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" \
  --region "$REGION" >/dev/null 2>&1 || true

INVOKE_URL=$(aws apigatewayv2 get-api --api-id "$API_ID" --region "$REGION" --query "ApiEndpoint" --output text)
echo ""
echo "=== SETUP SELESAI ==="
echo "Invoke URL: $INVOKE_URL"
sleep 2
curl -s "$INVOKE_URL/health"
echo ""
