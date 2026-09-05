---
type: module
path: "@root/cbits/pudu_sqlite.c"
fidelity: Active
tags: [module, native, database, sqlite]
aliases: [Pudu SQLite Bridge]
---
# Pudu SQLite Bridge

## Purpose and interface
A fixed C ABI adapts SQLite to owned FFI handles without misdeclaring SQLite's integer-returning
close/finalize functions as void. The reserved `pudu_sqlite` native module resolves only this
bridge's named functions. SQLite is dynamically loaded per connection on the existing POSIX
runtime platforms; no SQLite headers or link-time SQLite dependency are required. A missing
library or symbol returns a typed negative status through the Pudu adapter.

## Algorithm and ownership
Opening loads a complete function table before opening a full-mutex read/write/create connection.
Failure releases partial resources. Statements retain their connection wrapper through an atomic
reference count; either runtime teardown order is safe. Finalization releases the statement and
its temporary hex buffer before dropping the connection reference. Last reference closes the
native connection and unloads its library. Binding text/blob uses transient-copy semantics, so
Pudu storage is never retained. Column text/blob bytes are copied into checked hex storage before
crossing as text, retaining embedded NUL and allowing Pudu UTF-8 validation. A statement accepts
exactly one SQL command and an exact parameter count. Extra statements are refused before stepping.

## Resolved Grill Log
- **Q:** Declare sqlite3_close as a void release? **A:** No; the bridge owns a real void destructor.
- **Q:** Require a system SQLite installation to start the compiler? **A:** No; load only on connect.
- **Q:** Let a statement outlive its database wrapper? **A:** Retain a connection reference until finalization.
- **Q:** Return SQLite text directly as a NUL-terminated string? **A:** No; use byte lengths and hex transport.

## Referenced by
[[src/cbits/_MOC]] · [[Pudu FFI Bridge]] · [[Std Db Sqlite]] · [[Pudu Cabal Manifest]]
