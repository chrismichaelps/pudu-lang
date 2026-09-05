---
type: module
path: "@root/lib/Std/Db/ConnectionString.pudu"
fidelity: Active
tags: [module, stdlib, database]
aliases: [Std Db ConnectionString]
---
# Std Db ConnectionString

## Purpose
PostgreSQL connection strings.

## Interface and algorithm
Parse postgres/postgresql URIs into Session.Config without opening a socket. Require explicit user, host, database and sslmode=disable; default port 5432. Decode percent bytes as UTF-8, preserve literal plus, reject NUL, fragments, duplicate/unknown options, multi-host lists and malformed ports. Support bracketed IPv6. Errors never include the source URI or credential values. connect and pool compose existing real socket/session APIs. TLS negotiation, libpq keyword strings and other database engines remain unsupported.

## Resolved Grill Log
- **Q:** Silently ignore unsupported connection settings? **A:** No; reject before network I/O.
- **Q:** Let handlers interpolate values into SQL? **A:** No; query binds parameters separately.
- **Q:** Claim live database conformance without execution? **A:** No; this delivery is unvalidated at the user's direction.

## Referenced by
[[src/Std/_MOC]] · [[Std App]] · [[Std Db]] · [[Std Db Session]] · [[2026-09-05-database-framing]]

## Supported URI subset

`postgresql://user:password@host:5432/database?sslmode=disable` and the `postgres://` alias
are supported. Password may be omitted; user, host, and database must be explicit. Reserved
characters in components use percent-encoded UTF-8, e.g. `%40` for an at sign in a password.
Bracketed IPv6 hosts are accepted. Plus signs remain plus signs. Port defaults to 5432.

The existing session uses plain TCP. Consequently missing `sslmode` and every mode other than
`disable` are refused before opening a socket. There is no automatic downgrade. `Std.Tls` opens
new TLS sockets but does not expose the existing-socket upgrade needed for PostgreSQL's ordinary
SSLRequest negotiation. Verified PostgreSQL TLS remains the next transport feature; hosted
services requiring it cannot use this URI API yet. Unknown/duplicate query options, keyword
connection strings, Unix socket paths and multiple hosts are rejected, not silently approximated.

URI scheme and escaping follow the relevant subset of
[PostgreSQL connection URI documentation](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING-URIS).
This API deliberately does not claim complete libpq compatibility.
