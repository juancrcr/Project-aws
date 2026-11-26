<#
.SYNOPSIS
  Menyimpan bukti koneksi, test CRUD live, dan backup isi DynamoDB ke folder lokal
  sebelum sesi sandbox 3 jam berakhir/reset.
#>

$ErrorActionPreference = "Stop"

$Region = if ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { "us-east-1" }
$TableName = "equipment-loans"
$ApiName = "equipment-loans-http-api"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$EvidenceDir = Join-Path $ProjectRoot "evidence"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

$ApiId = aws apigatewayv2 get-apis --region $Region --query "Items[?Name=='$ApiName'] | [0].ApiId" --output text
if (-not $ApiId -or $ApiId -eq "None") {
    throw "API '$ApiName' tidak ditemukan. Jalankan .\scripts\setup-aws.ps1 terlebih dahulu."
}
$InvokeUrl = aws apigatewayv2 get-api --api-id $ApiId --region $Region --query "ApiEndpoint" --output text

$ReportFile = Join-Path $EvidenceDir "aws-evidence-$Timestamp.txt"
$BackupFile = Join-Path $EvidenceDir "dynamodb-backup-$Timestamp.json"

$Log = @()
$Log += "=== AWS SANDBOX EVIDENCE ($Timestamp) ==="
$Log += "Invoke URL : $InvokeUrl"
$Log += ""

$Log += "--- 1. GET /health ---"
$HealthRes = Invoke-RestMethod -Uri "$InvokeUrl/health" -Method GET
$Log += ($HealthRes | ConvertTo-Json -Depth 5)
$Log += ""

$Log += "--- 2. POST /loans (Create Sample) ---"
$Payload = @{
    borrower_name  = "Budi Santoso"
    borrower_id    = "220123456"
    equipment_name = "Oscilloscope Rigol DS1054Z"
    quantity       = 1
    due_date       = "2026-12-03"
} | ConvertTo-Json
$CreateRes = Invoke-RestMethod -Uri "$InvokeUrl/loans" -Method POST -Body $Payload -ContentType "application/json"
$Log += ($CreateRes | ConvertTo-Json -Depth 5)
$Log += ""

$Log += "--- 3. GET /loans (List) ---"
$ListRes = Invoke-RestMethod -Uri "$InvokeUrl/loans" -Method GET
$Log += ($ListRes | ConvertTo-Json -Depth 5)
$Log += ""

$Log += "--- 4. DynamoDB Table Status ---"
$TableStatus = aws dynamodb describe-table --table-name $TableName --region $Region --query "Table.{Name:TableName,Status:TableStatus,ItemCount:ItemCount}" --output json
$Log += $TableStatus

$Log | Out-File -FilePath $ReportFile -Encoding utf8
aws dynamodb scan --table-name $TableName --region $Region --output json | Out-File -FilePath $BackupFile -Encoding utf8

Write-Host "Evidence tersimpan di : $ReportFile" -ForegroundColor Green
Write-Host "Backup data DynamoDB  : $BackupFile" -ForegroundColor Green
