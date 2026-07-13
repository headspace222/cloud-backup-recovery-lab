<#
.SYNOPSIS
    Enables blob soft delete, versioning, and point-in-time restore on the
    target storage account.

.PARAMETER ResourceGroupName
    Resource group containing the storage account.

.PARAMETER StorageAccountName
    Name of the storage account to protect.

.PARAMETER RetentionDays
    How many days deleted blobs/versions remain recoverable. Default: 7.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,

    [int]$RetentionDays = 7
)

Write-Host "Enabling blob soft delete ($RetentionDays day retention) ..." -ForegroundColor Cyan
Enable-AzStorageBlobDeleteRetentionPolicy -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -RetentionDays $RetentionDays

Write-Host "Enabling container soft delete ($RetentionDays day retention) ..." -ForegroundColor Cyan
Enable-AzStorageContainerDeleteRetentionPolicy -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -RetentionDays $RetentionDays

Write-Host "Enabling blob versioning ..." -ForegroundColor Cyan
Update-AzStorageBlobServiceProperty -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -IsVersioningEnabled $true

Write-Host "Enabling change feed (required for point-in-time restore) ..." -ForegroundColor Cyan
Update-AzStorageBlobServiceProperty -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -EnableChangeFeed $true

Write-Host "Enabling point-in-time restore ($RetentionDays day window) ..." -ForegroundColor Cyan
Enable-AzStorageBlobRestorePolicy -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -RestoreDays $RetentionDays

Write-Host "`nAll protection features enabled. Verifying current state ..." -ForegroundColor Green
Get-AzStorageBlobServiceProperty -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName | Select-Object DeleteRetentionPolicy, IsVersioningEnabled, ChangeFeed, RestorePolicy