---
type: module
path: "@root/cbits/pudu_webview_records.c"
fidelity: Active
tags: [module, runtime, desktop, webview]
aliases: [Pudu Webview Records]
---

# Pudu Webview Records

## Purpose and interface

Portable framing shared by every adapter (`pudu_webview_records.h`): `pudu_record_next` reads one
record of length-prefixed fields; `pudu_buffer_*` appends fields, integers and record ends to a
growable buffer; `pudu_field_is`, `pudu_field_int` and `pudu_field_copy` read fields;
`pudu_pattern_match` tests a URL against a navigation pattern.

## Semantics

- A field is `<length>:<bytes>,`; a record ends with a line feed. A length with no digits, more than
  nineteen digits, a missing `:` or `,`, or a length past the end is malformed and reads as `-1`.
- A record with more fields than the caller's array is malformed rather than truncated, so a command
  never runs with its trailing arguments silently dropped.
- Patterns match the whole URL. The scheme and authority (up to the first `/`, `?` or `#` after
  `://`) are matched separately from the rest: there `*` cannot cross `/`, `?`, `#` or `@`, so a
  subdomain wildcard cannot be satisfied by a path or user-info on another host; in the path `*`
  matches any run. Matching is iterative with one backtrack point, so it cannot go exponential.
- A buffer that cannot grow keeps its contents and answers `-1`; callers report a platform failure.

## Grill Log

- **Q:** Why not escape tabs and newlines? **A:** Script and HTML carry both freely; escaping costs a
  pass on each side and a decoder bug corrupts code. Lengths cost one integer per field.
- **Q:** Glob or regular expression for navigation? **A:** Glob with `*` only: it is decided
  synchronously inside the platform's navigation callback, so it must be cheap and cannot fail to
  compile.

## Dependencies and consumers

Used by [[Pudu Webview macOS Adapter]] and [[Pudu Webview GTK Adapter]]; mirrored in Pudu by
[[Std Desktop Records]]. Tested natively by [[Webview Records Test]].

## Referenced by

[[src/cbits/_MOC]]
