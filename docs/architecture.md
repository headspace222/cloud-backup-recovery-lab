# Architecture & Design Rationale

## RPO and RTO: The Actual Design Question

Backup and recovery isn't a single yes/no setting - the real design decisions
are two numbers:

- **RPO (Recovery Point Objective)**: how much data can you afford to lose,
  measured in time? If your last good backup is from 6 hours ago and
  something fails now, you lose 6 hours of data. A lower RPO costs more
  (more frequent backups/snapshots, more storage).
- **RTO (Recovery Time Objective)**: how long can you afford to be down while
  recovering? A faster recovery process (automated, tested, documented)
  costs more engineering effort upfront but reduces incident duration.

This lab's three features map directly onto these numbers:

| Feature | RPO Characteristic | RTO Characteristic |
|---|---|---|
| Soft delete | Effectively zero data loss for the deleted item itself (it's fully recoverable, not partially) | Fast - a single undelete operation |
| Versioning | Zero data loss for the specific overwritten version | Fast - identify and restore the correct version |
| Point-in-time restore | Configurable to any point within the retention window | Slower - restores at container scope, more data to process |

## Why Native Storage Features Rather Than Azure Backup (the Named Service)

Azure Backup, with Recovery Services vaults, is the standard enterprise tool
for backing up VMs, SQL databases, and file shares - workloads where backup
needs centralised policy management across many resources, cross-region
vault replication, and integration with a single pane of governance.

For blob storage specifically, Azure Backup's "Operational Backup for Blobs"
capability is built on exactly the same soft delete, versioning, and change
feed features configured directly in this lab - it does not add a
fundamentally different protection mechanism, it adds a management layer on
top of the same underlying features.

**Where the vault-based service earns its cost and complexity:**
- Managing backup policy consistently across dozens or hundreds of storage
  accounts, rather than configuring each individually
- Centralised alerting and compliance reporting across an entire
  organisation's backup posture
- Cross-subscription and cross-region backup governance

For a single storage account - or a small number managed by one team - direct
configuration of these native features is simpler, has an identical recovery
capability, and avoids a separate vault resource with its own management
overhead. This lab's scope (one storage account) sits clearly on the side of
"direct configuration is the right choice," and that boundary is worth being
able to articulate rather than defaulting to the more complex tool by habit.

## Why Both Soft Delete and Versioning (Not Just One)

These protect against genuinely different failure modes, and neither
substitutes for the other:

- **Soft delete** protects against a blob being deleted entirely - the whole
  object disappearing. Without it, a `Remove-AzStorageBlob` call (accidental
  or malicious) is immediately and permanently destructive.
- **Versioning** protects against a blob being overwritten with different,
  wrong, or corrupted content while the blob itself still exists. Soft
  delete does nothing here - the blob was never deleted, so there's nothing
  for soft delete to recover; the *previous content* is what's lost, and
  only versioning retains that.

A real incident could be either, and a production system should defend
against both - this lab deliberately simulates and recovers from each
separately to prove that distinction rather than asserting it.

**A finding worth stating precisely, discovered during this lab's build:**
with both features enabled together, deleting a blob does not behave the way
soft delete alone would suggest. Rather than the blob appearing as a
standalone "soft-deleted" item recoverable via `Undelete()`, versioning
intercepts first - the pre-delete content is retained as a non-current
version, and the blob simply loses its "current" pointer. Querying with
`-IncludeDeleted` finds nothing (because nothing is soft-deleted in the
narrow sense); querying with `-IncludeVersion` finds the content correctly.
The practical result is that `recover-deleted-blob.ps1` and
`recover-previous-version.ps1` end up using the same underlying recovery
mechanism (list versions, restore the most recent one) - not because the
two incidents are conceptually the same, but because this specific
combination of Azure features routes both through versioning rather than
through soft delete's own recovery path. This is exactly the kind of
platform behaviour that's only obvious once you've hit it directly - the
Azure documentation describes each feature independently, but doesn't
foreground how they interact when both are active simultaneously.

## Retention Window: A Real Trade-off, Not a Default

This lab uses a 7-day retention window for soft delete, versioning, and
point-in-time restore. Longer retention means a longer window to notice and
recover from an incident, at the cost of more storage consumed by retained
deleted items and old versions. For a lab with a handful of small test
files, this cost is negligible; at production scale with large or
frequently-changing datasets, retention period is a genuine cost lever worth
tuning deliberately rather than leaving at whatever default Azure suggests.

A real constraint surfaced during setup: point-in-time restore's retention
window must be **strictly less** than the delete retention policy's window -
setting both to the same value (7 days) is rejected by Azure with a
BadRequest error. `enable-protection-features.ps1` handles this
automatically by using one day less than the delete retention value for the
restore policy, but it's worth understanding *why*: point-in-time restore
relies on being able to compare the target restore point against the change
feed and versioned blobs, all of which are themselves subject to the delete
retention window - if the restore window could equal or exceed the delete
retention window, a restore could be requested for a point in time where the
underlying data needed to fulfil it may already be gone.

## A Real Constraint: Propagation Delay Before Enforcement

Enabling soft delete via `Enable-AzStorageBlobDeleteRetentionPolicy` reports
success immediately, but enforcement does not activate instantaneously
across the storage account. Deleting a blob within the first few minutes of
enabling soft delete can result in a genuine hard delete rather than the
expected soft delete - discovered directly during this lab's build, when an
initial recovery attempt found no trace of the deleted blob at all (not even
as a soft-deleted item), rather than the expected recoverable state. The fix
is straightforward - wait 5-10 minutes after enabling protection features
before relying on them - but the underlying lesson is more general: a
successful API response confirming a setting is "enabled" is not the same
guarantee as that setting being fully enforced yet. This same propagation
pattern appeared with Azure Policy assignments in the cost governance lab.

## What I'd Add at Enterprise Scale

- **Azure Backup with Recovery Services vaults**, once managing backup
  policy across many storage accounts (or VMs, databases, file shares)
  makes centralised policy management worth its overhead
- **Cross-region backup** (not just cross-region storage redundancy, which
  is a separate concept covered in the migration lab) - a full second copy
  in another region, recoverable even if the primary region and its backups
  are both unavailable
- **Automated recovery testing on a schedule**, rather than only proving
  recovery works during initial setup - untested backups are a common real
  cause of failed recovery during an actual incident
- **Immutable storage policies (WORM)** for data under legal hold or
  regulatory retention requirements, preventing deletion or modification
  even by an account with delete permissions, for financial records
  specifically relevant to this portfolio's target roles