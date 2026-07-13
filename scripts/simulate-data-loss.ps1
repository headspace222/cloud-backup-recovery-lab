<#
.SYNOPSIS
    Creates test data and simulates two common data loss incidents:
    accidental deletion and accidental overwrite.

.PARAMETER ResourceGroupName
    Resource group containing the storage account.

.PARAMETER StorageAccountName
    Name of the storage account.

.PARAMETER ContainerName
    Container to use for the simulation. Created if it doesn't exist.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,

    [string]$ContainerName = "backup-recovery-test"
)

$ctx = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Context

$container = Get-AzStorageContainer -Name $ContainerName -Context $ctx -ErrorAction SilentlyContinue
if (-not $container) {
    Write-Host "Creating container '$ContainerName' ..." -ForegroundColor Cyan
    New-AzStorageContainer -Name $ContainerName -Context $ctx -Permission Off | Out-Null
}

$tempDir = Join-Path $env:TEMP "backup-recovery-sim-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

Write-Host "`nStep 1: Uploading original test data ..." -ForegroundColor Cyan

"Original content - critical-report.txt - version 1 - $(Get-Date)" | Out-File -FilePath (Join-Path $tempDir "critical-report.txt") -Encoding utf8
"Original content - customer-list.csv - version 1 - $(Get-Date)" | Out-File -FilePath (Join-Path $tempDir "customer-list.csv") -Encoding utf8

Set-AzStorageBlobContent -File (Join-Path $tempDir "critical-report.txt") -Container $ContainerName -Blob "critical-report.txt" -Context $ctx -Force | Out-Null
Set-AzStorageBlobContent -File (Join-Path $tempDir "customer-list.csv") -Container $ContainerName -Blob "customer-list.csv" -Context $ctx -Force | Out-Null

Write-Host "  Uploaded: critical-report.txt, customer-list.csv" -ForegroundColor Green

Write-Host "`nStep 2: Simulating accidental DELETION of critical-report.txt ..." -ForegroundColor Yellow
Remove-AzStorageBlob -Container $ContainerName -Blob "critical-report.txt" -Context $ctx
Write-Host "  Deleted. With soft delete enabled, this is recoverable within the retention window." -ForegroundColor Yellow

Write-Host "`nStep 3: Simulating accidental OVERWRITE of customer-list.csv ..." -ForegroundColor Yellow
"CORRUPTED/WRONG content - this overwrote the original by mistake - $(Get-Date)" | Out-File -FilePath (Join-Path $tempDir "customer-list-bad.csv") -Encoding utf8
Set-AzStorageBlobContent -File (Join-Path $tempDir "customer-list-bad.csv") -Container $ContainerName -Blob "customer-list.csv" -Context $ctx -Force | Out-Null
Write-Host "  Overwritten. With versioning enabled, the original version is recoverable." -ForegroundColor Yellow

Write-Host "`nIncident simulation complete." -ForegroundColor Green
Write-Host "Next: run recover-deleted-blob.ps1 and recover-previous-version.ps1 to prove recovery works." -ForegroundColor Cyan

Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue