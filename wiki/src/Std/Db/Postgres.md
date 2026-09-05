---
type: module
path: "@root/lib/Std/Db/Postgres.pudu"
fidelity: Active
tags: [module, stdlib, database, drivers]
aliases: [Std Db Postgres]
---
# Std Db Postgres

## Purpose and interface
Adapt the existing PostgreSQL protocol and bounded pool to the backend-neutral Driver contract. postgres and postgresql schemes, dollar-number placeholders. Parameters preserve null, text, integer, boolean, decimal and Float64; byte parameters are rejected before I/O until binary binding exists. Returned wire text stays TextValue rather than guessing types; native OIDs are metadata strings. Error category and SQLSTATE survive adaptation. Connector URI policy is the explicit ConnectionString subset. Close delegates to Db.closePool.

## Resolved Grill Log
- **Q:** Make PostgreSQL session types mandatory for every database? **A:** No; the public driver seam uses independent values and callbacks.
- **Q:** Rewrite SQL to pretend dialects are identical? **A:** No; the selected driver declares its placeholder convention, and the caller writes its dialect.
- **Q:** Advertise drivers that have no implementation? **A:** No; third-party drivers are supported through the contract, but only concrete adapters are listed as bundled.

## Referenced by
[[src/Std/_MOC]] · [[Std App Database]] · [[Std Db]] · [[architecture/STDLIB]]
