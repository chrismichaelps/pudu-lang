---
type: module
path: "@root/lib/Std/Db/Driver.pudu"
fidelity: Active
tags: [module, stdlib, database, drivers]
aliases: [Std Db Driver]
---
# Std Db Driver

## Purpose and interface
Backend-neutral Value, Column, Rows, Error, Client and Driver records. A driver owns URI schemes, placeholders and opening a client; clients own bound-query, fixed-statement and close callbacks. Explicit connect selects exactly one matching driver from a caller-supplied array; zero matches or ambiguous matches fail. No global registry, fallback driver or SQL rewriting. Custom drivers can adapt SQL or other databases without PostgreSQL types. All callbacks propagate typed errors and own resource cleanup; clients must serialize or pool concurrent calls and close admission safely.

## Resolved Grill Log
- **Q:** Make PostgreSQL session types mandatory for every database? **A:** No; the public driver seam uses independent values and callbacks.
- **Q:** Rewrite SQL to pretend dialects are identical? **A:** No; the selected driver declares its placeholder convention, and the caller writes its dialect.
- **Q:** Advertise drivers that have no implementation? **A:** No; third-party drivers are supported through the contract, but only concrete adapters are listed as bundled.

## Referenced by
[[src/Std/_MOC]] · [[Std App Database]] · [[Std Db]] · [[architecture/STDLIB]]

## Extension contract

A package provides a `Driver` value whose `open(uri, capacity)` establishes real backend resources
and returns a `Client`. Client callbacks accept SQL plus typed values, never SQL assembled from
parameter text. They translate backend failures into `Error` while preserving native codes when
available. Opening failure cleans partial resources. Closing must stop admission, wake waiters,
and safely retire active operations; repeated closes must not double-release native handles.
A client may use a bounded pool or serialize an embedded connection. Capacity is a positive upper
bound, not a requirement to open that many resources for an embedded database.

Placeholder metadata describes syntax; it does not convert dialects. Result cells may remain text
when the driver cannot establish a lossless native mapping. SQL NULL is always `NullValue`.
`nativeType` is optional driver metadata, not a PostgreSQL OID required of every implementation.
The core does not parse vendor connection options, select a hidden driver, or promise portable SQL.

[[Std Db Row]] supplies named/indexed access, exact typed readers and cardinality-aware mapping over these backend-neutral results.
