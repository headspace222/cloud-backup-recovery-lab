# Setup Guide

Builds on the storage account from the data migration lab
(stmigrationlabjane01 / rg-data-migration-lab) - no new storage account
required.

**Estimated time:** 30-40 minutes.

## Step 1 - Enable Protection Features

```powershell
cd C:\cloud-backup-recovery-lab
.\scripts\enable-protection-features.ps1 -ResourceGroupName "rg-data-migration-lab" -StorageAccountName "stmigrationlabjane01"
```

**Evidence to capture:**
- 01-protection-features-enabled.png

Also confirm in the portal: Storage account, Data protection (left nav).

**Evidence to capture:**
- 02-data-protection-portal-view.png

## Step 2 - Simulate the Incidents

```powershell
.\scripts\simulate-data-loss.ps1 -ResourceGroupName "rg-data-migration-lab" -StorageAccountName "stmigrationlabjane01" -ContainerName "backup-recovery-test"
```

**Evidence to capture:**
- 03-incident-simulation-output.png

## Step 3 - Recover the Deleted Blob

```powershell
.\scripts\recover-deleted-blob.ps1 -ResourceGroupName "rg-data-migration-lab" -StorageAccountName "stmigrationlabjane01" -ContainerName "backup-recovery-test" -BlobName "critical-report.txt"
```

**Evidence to capture:**
- 04-deleted-blob-recovered.png

## Step 4 - Recover the Overwritten Blob's Previous Version

```powershell
.\scripts\recover-previous-version.ps1 -ResourceGroupName "rg-data-migration-lab" -StorageAccountName "stmigrationlabjane01" -ContainerName "backup-recovery-test" -BlobName "customer-list.csv"
```

**Evidence to capture:**
- 05-version-restored.png

Verify actual content:

```powershell
Get-AzStorageBlobContent -Container "backup-recovery-test" -Blob "customer-list.csv" -Destination "$env:TEMP\verify.csv" -Context (Get-AzStorageAccount -ResourceGroupName "rg-data-migration-lab" -Name "stmigrationlabjane01").Context -Force
Get-Content "$env:TEMP\verify.csv"
```

**Evidence to capture:**
- 06-content-verification.png

## Step 5 - Push

```powershell
cd C:\cloud-backup-recovery-lab
git init
git add -A
git commit -m "Initial build: backup and recovery via native storage protection features"
git branch -M main
git remote add origin https://github.com/headspace222/cloud-backup-recovery-lab.git
git push -u origin main
```