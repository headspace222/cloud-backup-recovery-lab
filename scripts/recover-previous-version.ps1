<#
.SYNOPSIS
    Recovers the previous version of a blob after an accidental overwrite,
    using blob versioning.

.PARAMETER ResourceGroupName
    Resource group containing the storage account.

.PARAMETER StorageAccountName
    Name of the storage account.

.PARAMETER ContainerName
    Container the blob is in.

.PARAMETER BlobName
    Name of the blob to restore to its previous version.
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

Write-Host "Listing all versions of '$BlobName' ..." -ForegroundColor Cyan

$allVersions = Get-AzStorageBlob -Container $ContainerName -Context $ctx -IncludeVersion -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $BlobName } | Sort-Object -Property LastModified -Descending

if ($allVersions.Count -lt 2) {
    Write-Host "Fewer than 2 versions found - nothing to roll back to." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($allVersions.Count) version(s):" -ForegroundColor Cyan
$allVersions | Select-Object VersionId, LastModified, Length | Format-Table -AutoSize

$currentVersion = $allVersions[0]
$previousVersion = $allVersions[1]

Write-Host "`nCurrent version (the accidental overwrite): $($currentVersion.LastModified)" -ForegroundColor Yellow
Write-Host "Restoring previous version: $($previousVersion.LastModified) ..." -ForegroundColor Cyan

$tempPath = Join-Path $env:TEMP "restore-$BlobName-$(Get-Random)"
$previousVersion.BlobClient.DownloadTo($tempPath) | Out-Null

Set-AzStorageBlobContent -File $tempPath -Container $ContainerName -Blob $BlobName -Context $ctx -Force | Out-Null

Remove-Item $tempPath -ErrorAction SilentlyContinue

Write-Host "`nRecovery complete." -ForegroundColor Green