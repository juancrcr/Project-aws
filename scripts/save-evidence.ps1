<#
.SYNOPSIS
  Menguji /health dan CRUD lengkap (POST, GET list, GET by id, PUT, DELETE) pada endpoint live,
  lalu menyimpan output dan backup isi DynamoDB ke folder evidence/ sebelum sesi Learner Lab reset.
#>

$ErrorActionPreference = "Stop"

$Region = if ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { "us-east-1" }
$TableName = "equipment-loans"
$FunctionName = "equipment-loans-api"
$ApiName = "equipment-loans-http-api"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$EvidenceDir = Join-Path $ProjectRoot "evidence"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

$ErrorActionPreference = "Continue"
$InvokeUrl = ""
$ApiId = aws apigatewayv2 get-apis --region $Region --query "Items[?Name=='$ApiName'] | [0].ApiId" --output text 2>$null
if ($LASTEXITCODE -eq 0 -and $ApiId -and $ApiId -ne "None") {
    $InvokeUrl = aws apigatewayv2 get-api --api-id $ApiId --region $Region --query "ApiEndpoint" --output text
} else {
    $InvokeUrl = aws lambda get-function-url-config --function-name $FunctionName --region $Region --query "FunctionUrl" --output text 2>$null
}
$ErrorActionPreference = "Stop"

if (-not $InvokeUrl -or $InvokeUrl -eq "None") {
    throw "Endpoint tidak ditemukan. Jalankan .\scripts\setup-aws.ps1 terlebih dahulu."
}
$InvokeUrl = $InvokeUrl.TrimEnd("/")

$ReportFile = Join-Path $EvidenceDir "aws-evidence-$Timestamp.txt"
$BackupFile = Join-Path $EvidenceDir "dynamodb-backup-$Timestamp.json"

$Log = @()
function Add-Step($Title, $Method, $Path, $Body = $null) {
    $script:Log += "--- $Title ($Method $Path) ---"
    try {
        $Params = @{ Uri = "$InvokeUrl$Path"; Method = $Method }
        if ($Body) { $Params.Body = ($Body | ConvertTo-Json); $Params.ContentType = "application/json" }
        $Res = Invoke-RestMethod @Params
        $script:Log += ($Res | ConvertTo-Json -Depth 6)
        return $Res
    } catch {
        $script:Log += "ERROR: $($_.Exception.Message)"
        return $null
    }
    finally { $script:Log += "" }
}

$Log += "=== AWS LEARNER LAB EVIDENCE ($Timestamp) ==="
$Log += "Invoke URL : $InvokeUrl"
$Log += ""

Add-Step "1. Health check" GET "/health" | Out-Null

$Create = Add-Step "2. Create" POST "/loans" @{
    borrower_name  = "Budi Santoso"
    borrower_id    = "220123456"
    equipment_name = "Oscilloscope Rigol DS1054Z"
    quantity       = 1
    due_date       = "2026-12-03"
}
Add-Step "3. Read list" GET "/loans" | Out-Null

if ($Create -and $Create.item.loan_id) {
    $Id = $Create.item.loan_id
    Add-Step "4. Read by id" GET "/loans/$Id" | Out-Null
    Add-Step "5. Update (RETURNED)" PUT "/loans/$Id" @{ status = "RETURNED" } | Out-Null
    Add-Step "6. Delete" DELETE "/loans/$Id" | Out-Null
    Add-Step "7. Read by id setelah delete (harus 404)" GET "/loans/$Id" | Out-Null
} else {
    $Log += "CREATE gagal, uji GET by id / PUT / DELETE dilewati."
}

$Log += "--- 8. DynamoDB table status ---"
$Log += (aws dynamodb describe-table --table-name $TableName --region $Region --query "Table.{Name:TableName,Status:TableStatus,ItemCount:ItemCount}" --output json)

$Log | Out-File -FilePath $ReportFile -Encoding utf8
aws dynamodb scan --table-name $TableName --region $Region --output json | Out-File -FilePath $BackupFile -Encoding utf8

Write-Host "Evidence tersimpan di : $ReportFile" -ForegroundColor Green
Write-Host "Backup data DynamoDB  : $BackupFile" -ForegroundColor Green
