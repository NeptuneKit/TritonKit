The follow-up scope has been resolved as **not planned** for general cache deletion; this does not mean race-safe deletion was implemented.

The safety mitigation shipped in v0.2.25 remains in place: inspect and cleanup preview are read-only. Confirmed cleanup returns `xcode_not_idle` when build activity is present or unknown, and `derived_data_cleanup_unavailable` even when idle. Waiting for idle does not enable deletion, and Triton must not automatically fall back to manual deletion.

Since v0.2.26, ordinary Xcode builds use Xcode's default user-level DerivedData instead of creating a repository-local `.triton/DerivedData` by default. An explicit `--derived-data-path` remains available for deliberate isolation. This change does not remove existing caches.

The later scope decision on 2026-10-24 cancelled general automatic deletion, superseding the earlier comment's plan to complete a general exclusive-ownership/deletion protocol. External Xcode builds do not participate in Triton's lock, so process snapshots alone cannot establish safe exclusion. A future Triton-owned cache lifecycle would need a separately scoped design and acceptance criteria.

We have not established which version or invocations produced the two directories in the original report, whether their contents were duplicates, or how much physical disk space could safely be reclaimed. Logical file bytes and modification times do not establish reclaimable space or last use. No real cache was deleted for this review.

Current read-only usage and the unsupported deletion boundary are documented in SP-179 and SP-191. The issue can be closed as not planned for automatic deletion while retaining these supported inspection capabilities.
