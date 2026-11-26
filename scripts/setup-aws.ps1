<#
.SYNOPSIS
  Auto-setup (re-create) seluruh infrastruktur Week 12 (DynamoDB, Lambda, API Gateway)
  di sesi AWS Sandbox / Learner Lab yang reset setiap 3 jam.
#>

$ErrorActionPreference = "Stop"

$Region = if ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { "us-east-1" }
$TableName = "equipment-loans"
$FunctionName = "equipment-loans-api"
$ApiName = "equipment-loans-http-api"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ZipPath = Join-Path $ProjectRoot "function.zip"
$LambdaSource = Join-Path $ProjectRoot "src\lambda_function.py"

Write-Host "=== 1. Verifikasi Kredensial AWS Sandbox ===" -ForegroundColor Cyan
$AccountId = aws sts get-caller-identity --query "Account" --output text
if (-not $AccountId) {
    throw "Gagal membaca AWS credentials. Pastikan AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, dan AWS_SESSION_TOKEN sudah diset."
}
$RoleArn = "arn:aws:iam::${AccountId}:role/LabRole"
Write-Host "Account ID : $AccountId"
Write-Host "Region     : $Region"
Write-Host "IAM Role   : $RoleArn"

Write-Host "`n=== 2. Setup DynamoDB Table ($TableName) ===" -ForegroundColor Cyan
$ErrorActionPreference = "Continue"
aws dynamodb describe-table --table-name $TableName --region $Region *> $null
$TableExists = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = "Stop"

if (-not $TableExists) {
    Write-Host "Membuat tabel DynamoDB '$TableName'..."
    aws dynamodb create-table `
        --table-name $TableName `
        --attribute-definitions AttributeName=loan_id,AttributeType=S `
        --key-schema AttributeName=loan_id,KeyType=HASH `
        --billing-mode PAY_PER_REQUEST `
        --region $Region | Out-Null
    Write-Host "Menunggu tabel aktif..."
    aws dynamodb wait table-exists --table-name $TableName --region $Region
} else {
    Write-Host "Tabel '$TableName' sudah ada."
}

Write-Host "`n=== 3. Package & Deploy AWS Lambda ($FunctionName) ===" -ForegroundColor Cyan
Compress-Archive -Path $LambdaSource -DestinationPath $ZipPath -Force

$ErrorActionPreference = "Continue"
aws lambda get-function --function-name $FunctionName --region $Region *> $null
$FuncExists = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = "Stop"

if (-not $FuncExists) {
    Write-Host "Membuat Lambda function '$FunctionName'..."
    aws lambda create-function `
        --function-name $FunctionName `
        --runtime python3.12 `
        --role $RoleArn `
        --handler lambda_function.lambda_handler `
        --zip-file "fileb://$ZipPath" `
        --environment "Variables={TABLE_NAME=$TableName}" `
        --timeout 15 `
        --region $Region | Out-Null
    aws lambda wait function-active-v2 --function-name $FunctionName --region $Region
} else {
    Write-Host "Mengupdate kode Lambda '$FunctionName'..."
    aws lambda update-function-code `
        --function-name $FunctionName `
        --zip-file "fileb://$ZipPath" `
        --region $Region | Out-Null
    aws lambda wait function-updated-v2 --function-name $FunctionName --region $Region
}

$LambdaArn = aws lambda get-function --function-name $FunctionName --region $Region --query "Configuration.FunctionArn" --output text
Write-Host "Lambda ARN : $LambdaArn"

Write-Host "`n=== 4. Setup API Gateway HTTP API ($ApiName) ===" -ForegroundColor Cyan
$ApiId = aws apigatewayv2 get-apis --region $Region --query "Items[?Name=='$ApiName'] | [0].ApiId" --output text
if (-not $ApiId -or $ApiId -eq "None") {
    Write-Host "Membuat HTTP API '$ApiName'..."
    $ApiId = aws apigatewayv2 create-api `
        --name $ApiName `
        --protocol-type HTTP `
        --region $Region `
        --query "ApiId" --output text

    $IntegrationId = aws apigatewayv2 create-integration `
        --api-id $ApiId `
        --integration-type AWS_PROXY `
        --integration-uri $LambdaArn `
        --payload-format-version "2.0" `
        --region $Region `
        --query "IntegrationId" --output text

    $Routes = @(
        "GET /health",
        "POST /loans",
        "GET /loans",
        "GET /loans/{loan_id}",
        "PUT /loans/{loan_id}",
        "DELETE /loans/{loan_id}"
    )
    foreach ($RouteKey in $Routes) {
        Write-Host "  Menambahkan route: $RouteKey"
        aws apigatewayv2 create-route `
            --api-id $ApiId `
            --route-key $RouteKey `
            --target "integrations/$IntegrationId" `
            --region $Region | Out-Null
    }

    aws apigatewayv2 create-stage `
        --api-id $ApiId `
        --stage-name '$default' `
        --auto-deploy `
        --region $Region | Out-Null
} else {
    Write-Host "HTTP API '$ApiName' sudah ada (ApiId: $ApiId)."
}

$ErrorActionPreference = "Continue"
aws lambda add-permission `
    --function-name $FunctionName `
    --statement-id "apigateway-invoke-$ApiId" `
    --action lambda:InvokeFunction `
    --principal apigateway.amazonaws.com `
    --source-arn "arn:aws:execute-api:${Region}:${AccountId}:${ApiId}/*/*" `
    --region $Region *> $null
$ErrorActionPreference = "Stop"

$InvokeUrl = aws apigatewayv2 get-api --api-id $ApiId --region $Region --query "ApiEndpoint" --output text
Write-Host "`n=== SETUP SELESAI ===" -ForegroundColor Green
Write-Host "Invoke URL : $InvokeUrl" -ForegroundColor Yellow

Write-Host "`n=== 5. Uji Konektivitas Otomatis ===" -ForegroundColor Cyan
Start-Sleep -Seconds 2
$Health = Invoke-RestMethod -Uri "$InvokeUrl/health" -Method GET
$Health | ConvertTo-Json -Compress
