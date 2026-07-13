# Architecture & Design Rationale

## RPO and RTO: The Actual Design Question

Backup and recovery isn't a single yes/no setting - the real design decisions
are two numbers:

- **RPO (Recovery Point Objective)**: how much data can you afford to lose,
  measured in time?
- **RTO (Recovery Time Objective)**: how long can you afford to be down while
  recovering?

This lab's three features map directly onto these numbers:

| Feature | RPO Characteristic | RTO Characteristic |
|---|---|---|
| Soft delete | Effectively zero data loss for the deleted item | Fast - a single undelete operation |
| Versioning | Zero data loss for the overwritten version | Fast - identify and restore the correct version |
| Point-in-time restore | Configurable to any point in retention window | Slower - restores at container scope |

## Why Native Storage Features Rather Than Azure Backup (the Named Service)

Azure Backup, with Recovery Services vaults, is the standard enterprise tool
for backing up VMs, SQL databases, and file shares. For blob storage
specifically, Azure Backup's "Operational Backup for Blobs" capability is
built on exactly the same soft delete, versioning, and change feed features
configured directly in this lab - it adds a management layer, not a
fundamentally different protection mechanism.

**Where the vault-based service earns its cost and complexity:**
- Managing backup policy consistently across dozens or hundreds of storage
  accounts
- Centralised alerting and compliance reporting
- Cross-subscription and cross-region backup governance

For a single storage account, direct configuration of these native features
is simpler, has identical recovery capability, and avoids a separate vault
resource.

## Why Both Soft Delete and Versioning (Not Just One)

- **Soft delete** protects against a blob being deleted entirely.
- **Versioning** protects against a blob being overwritten with wrong or
  corrupted content while it still exists. Soft delete does nothing here -
  the blob was never deleted; only versioning retains the previous content.

A real incident could be either, so this lab deliberately simulates and
recovers from each separately.

## Retention Window: A Real Trade-off, Not a Default

This lab uses a 7-day retention window for soft delete and versioning. A real
constraint surfaced during setup: point-in-time restore's retention window
must be strictly less than the delete retention policy's window - setting
both to the same value (7 days) is rejected by Azure with a BadRequest error.
enable-protection-features.ps1 handles this automatically by using one day
less than the delete retention value for the restore policy.

This lab uses a 7-day retention window. Longer retention means more time to
notice and recover from an incident, at the cost of more storage consumed by
retained deleted items and old versions.

## What I'd Add at Enterprise Scale

- Azure Backup with Recovery Services vaults, once managing policy across
  many resources makes centralised management worth its overhead
- Cross-region backup (a full second copy in another region)
- Automated recovery testing on a schedule, not just at initial setup
- Immutable storage policies (WORM) for data under legal hold or regulatory
  retention requirements