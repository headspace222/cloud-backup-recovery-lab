# Architecture Diagram

```mermaid
flowchart TB
    subgraph Setup["Protection Features Enabled"]
        direction TB
        P1[Soft Delete - 7 day retention]
        P2[Blob Versioning]
        P3[Change Feed]
        P4[Point-in-Time Restore - 6 day window]
        P2 -.required for.-> P4
        P3 -.required for.-> P4
    end

    subgraph Incidents["Simulated Incidents"]
        direction TB
        I1[Accidental Deletion - critical-report.txt removed]
        I2[Accidental Overwrite - customer-list.csv corrupted]
    end

    subgraph Recovery["Recovery - Unified Mechanism"]
        direction TB
        R1[List all versions - Get-AzStorageBlob -IncludeVersion]
        R2[Identify correct previous version]
        R3[Download version content]
        R4[Re-upload as current blob]
        R1 --> R2 --> R3 --> R4
    end

    Setup --> Incidents
    I1 -.captured as non-current version, not soft-deleted item.-> R1
    I2 -.captured as non-current version.-> R1
    R4 --> V[Verified: content matches pre-incident original]

    style Setup fill:#e8f4fd,stroke:#1a73e8
    style Incidents fill:#fce8e6,stroke:#d93025
    style Recovery fill:#e6f4ea,stroke:#188038
```

## Reading This Diagram

**Setup (top, blue):** four protection features configured on the storage
account, with the dependency between versioning/change feed and point-in-time
restore made explicit.

**Incidents (middle, red):** the two failure modes this lab deliberately
simulates - a full deletion and a content overwrite - modelling the most
common real-world data loss scenarios.

**Recovery (bottom, green):** the key finding from this lab's build. Both
incident types were expected to route through different recovery mechanisms
(soft delete's Undelete() for deletion, versioning for overwrite) but with
both features enabled together, both actually route through the same
version-based recovery path - deletion doesn't produce a standalone
soft-deleted item when versioning is active; it produces a non-current
version, identical in shape to an overwrite. This is documented in detail in
docs/architecture.md, and is the kind of platform interaction that's only
visible once you've built and tested against it directly.