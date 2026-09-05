---
type: module
path: "@root/lib/Std/Db/Sqlite.pudu"
fidelity: Active
tags: [module, stdlib, database, sqlite]
aliases: [Std Db Sqlite]
---
# Std Db Sqlite

## Purpose and interface
A real SQLite implementation of [[Std Db Driver]]. `driver` advertises `sqlite` and question-mark
placeholders. `connect` accepts `sqlite::memory:` or `sqlite:/path/to/file.db` (also relative paths).
The suffix is a literal filename, not a libpq or SQLite file URI; NUL, empty paths, file: names and
query/fragment syntax are refused. Each client owns one serialized connection; capacity is a
positive upper bound, so even a larger requested capacity uses one connection.

## Algorithm and ownership
A mutex covers complete prepare/bind/step/finalize operations and shutdown. An optional-handle cell
closes admission before release. Typed failures finalize statements and preserve SQLite status.
Exactly one SQL command is accepted; parameters bind by ordinal index with exact arity. NULL,
text, Int64, Float64 and Bytes bind natively; booleans bind as integer zero/one. Decimal is refused
rather than converted to lossy binary float. Returned SQLite storage classes remain typed. Text
bytes undergo explicit UTF-8 validation. Every query is fully materialized; row streaming and
cross-call transaction ownership are not promised by the shared Client API.

## Resolved Grill Log
- **Q:** Open several independent memory databases to satisfy pool capacity? **A:** No; serialize one connection.
- **Q:** Interpolate parameters into SQL? **A:** No; bind prepared statement slots.
- **Q:** Silently coerce exact Decimal to floating point? **A:** No; return unsupported.
- **Q:** Drop statement ownership after a typed decode failure? **A:** No; always finalize before returning.

## Referenced by
[[src/Std/_MOC]] · [[Std Db Driver]] · [[Std App Database]] · [[Pudu SQLite Bridge]]

## Usage and runtime requirements

```pudu
import Std.Db.Driver as Driver
import Std.Db.Sqlite as Sqlite

fn example() -> Result[Driver.Rows, Driver.Error] {
  let client = Driver.connect(&[Sqlite.driver()], "sqlite::memory:", 1) ?
  let outcome = Driver.query(&client, "SELECT ? AS message, ? AS payload",
    &[Driver.TextValue("connected"), Driver.BytesValue(bytesOf([0u8, 255u8]))])
  let closed = Driver.close(&client)
  match closed {
    case Err(problem) => Err(problem)
    case Ok(_) => outcome
  }
}
```

The real SQLite shared library must be available to the POSIX loader (`libsqlite3.so.0`,
`libsqlite3.dylib`, or `libsqlite3.so`). The compiler ships the adapter, not SQLite itself.
SQLite is loaded only when connecting. There are no shell commands, SQL interpolation, or
subprocess connections. Filenames are literal after `sqlite:`; percent escapes are not decoded.
Foreign-key enforcement follows SQLite defaults; set `PRAGMA foreign_keys = ON` explicitly where
required. Statements with trailing non-whitespace after the first statement are refused, including
trailing comments after a semicolon. Multi-statement scripts need explicit separate calls.

The result command is `SQLITE_DONE`, not an affected-row count. Integers remain Int64, SQL NULL
remains NullValue, and empty blobs/text remain distinct. Decimal parameters require an explicit
application storage choice. Standalone BEGIN/COMMIT calls do not reserve a client for one caller;
a scoped transaction API with exclusive client ownership remains follow-up work.

ABI contracts are based on SQLite's [opening API](https://www.sqlite.org/c3ref/open.html),
[parameter binding](https://www.sqlite.org/c3ref/bind_blob.html),
[statement preparation](https://www.sqlite.org/c3ref/prepare.html), and
[column access](https://www.sqlite.org/c3ref/column_blob.html).
No compilation, tests, code review, or live SQLite execution was performed in this delivery.
