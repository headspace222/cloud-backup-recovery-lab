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

Wait 5-10 minutes after Step 1 before proceeding. Soft delete and the other
protection features report as enabled immediately via the API, but
enforcement takes a short time to fully propagate across the storage
account. Deleting a blob before propagation completes results in a genuine
hard delete rather than a soft delete, which will not be recoverable.

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

Note on repeated testing: if customer-list.csv has been through the
simulation multiple times, it will have accumulated many versions, and "the
version immediately before the current one" may not be the clean original.
For unambiguous evidence, create one clean two-version cycle on a fresh
blob name:

```powershell
$ctx = (Get-AzStorageAccount -ResourceGroupName "rg-data-migration-lab" -Name "stmigrationlabjane01").Context

"ORIGINAL clean content - this is the version we want to recover" | Out-File "$env:TEMP\clean-test.txt" -Encoding utf8
Set-AzStorageBlobContent -File "$env:TEMP\clean-test.txt" -Container "backup-recovery-test" -Blob "clean-recovery-test.txt" -Context $ctx -Force

Start-Sleep -Seconds 2

"CORRUPTED overwrite content - this should NOT be what we see after recovery" | Out-File "$env:TEMP\clean-test-bad.txt" -Encoding utf8
Set-AzStorageBlobContent -File "$env:TEMP\clean-test-bad.txt" -Container "backup-recovery-test" -Blob "clean-recovery-test.txt" -Context $ctx -Force

.\scripts\recover-previous-version.ps1 -ResourceGroupName "rg-data-migration-lab" -StorageAccountName "stmigrationlabjane01" -ContainerName "backup-recovery-test" -BlobName "clean-recovery-test.txt"
```

**Evidence to capture:**
- 05-version-restored.png

Verify the actual content:

```powershell
Get-AzStorageBlobContent -Container "backup-recovery-test" -Blob "clean-recovery-test.txt" -Destination "$env:TEMP\verify-clean.txt" -Context $ctx -Force
Get-Content "$env:TEMP\verify-clean.txt"
```

**Evidence to capture:**
- 06-content-verification.png

## Step 5 - Push

```powershell
cd C:\cloud-backup-recovery-lab
git add -A
git commit -m "Complete build with all evidence"
git push
```