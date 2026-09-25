---
type: module
path: "@root/lib/Std/Db/Postgres.pudu"
fidelity: Active
tags: [module, stdlib, database, drivers]
aliases: [Std Db Postgres]
---
# Std Db Postgres

## Purpose and interface
Adapt the existing PostgreSQL protocol and bounded pool to the backend-neutral Driver contract. postgres and postgresql schemes, dollar-number placeholders. Parameters preserve null, text, integer, boolean, decimal, Float64 and bytes; a bytes parameter crosses as its `\x` hexadecimal text form, which the server reads back into exactly those bytes. Returned wire text stays TextValue rather than guessing types, except a `bytea` column (OID 17), whose `\x` hexadecimal cells [[Std Db]]'s `asDriverRows` reads into BytesValue, keeping any other form as text; native OIDs are metadata strings. Checked against a live PostgreSQL 14 server: three bytes, an empty value and a null each round-tripped exactly. Error category and SQLSTATE survive adaptation. Connector URI policy is the explicit ConnectionString subset. Close delegates to Db.closePool.

## Resolved Grill Log
- **Q:** Make PostgreSQL session types mandatory for every database? **A:** No; the public driver seam uses independent values and callbacks.
- **Q:** Rewrite SQL to pretend dialects are identical? **A:** No; the selected driver declares its placeholder convention, and the caller writes its dialect.
- **Q:** Advertise drivers that have no implementation? **A:** No; third-party drivers are supported through the contract, but only concrete adapters are listed as bundled.

## Referenced by
[[src/Std/_MOC]] · [[Std App Database]] · [[Std Db]] · [[architecture/STDLIB]]
