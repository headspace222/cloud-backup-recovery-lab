<#
.SYNOPSIS
    Recovers an accidentally deleted blob using soft delete.

.PARAMETER ResourceGroupName
    Resource group containing the storage account.

.PARAMETER StorageAccountName
    Name of the storage account.

.PARAMETER ContainerName
    Container the deleted blob is in.

.PARAMETER BlobName
    Name of the blob to recover.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,

    [string]$ContainerName = "backup-recovery-test",

    [Parameter(Mandatory=$true)]
    [string]$BlobName
)

$ctx = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Context

Write-Host "Checking for soft-deleted versions of '$BlobName' ..." -ForegroundColor Cyan

$deletedBlobs = Get-AzStorageBlob -Container $ContainerName -Context $ctx -IncludeDeleted | Where-Object { $_.Name -eq $BlobName -and $_.IsDeleted }

if (-not $deletedBlobs) {
    Write-Host "No soft-deleted blob found matching '$BlobName'. It may already be recovered, or the retention window has expired." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found soft-deleted blob. Undeleting ..." -ForegroundColor Cyan

$blobClient = $deletedBlobs[0].BlobClient
$blobClient.Undelete()

Write-Host "`nRecovery complete. Verifying ..." -ForegroundColor Green
$recovered = Get-AzStorageBlob -Container $ContainerName -Blob $BlobName -Context $ctx
Write-Host "  Blob '$($recovered.Name)' is now present, last modified: $($recovered.LastModified)" -ForegroundColor Green