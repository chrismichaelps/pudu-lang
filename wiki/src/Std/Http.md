---
type: module
path: "@root/lib/Std/Http.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.58
depth_status: MEDIUM
tags: [module, stdlib, http]
aliases: [Std Http]
---

# Std Http

## Purpose

Represent and transform the HTTP protocol surface that does not require a socket: methods,
statuses, requests, responses, headers, cookies, authorization, negotiation, forms, ranges, and
message encodings.

## Interface

```pudu
export type Method
export type Status
export type Request
export type Response
export type Version
export type Cookie
export type SetCookie
export type Preference
export type Range

export fn methodName(value: &Method) -> Str
export fn methodFrom(name: Str) -> Method
export fn status(code: Int) -> Status
export fn request(method: Method, target: Str) -> Request
export fn withHeader(value: &Request, name: Str, held: Str) -> Request
export fn withBody(value: &Request, body: Str) -> Request
export fn header(headers: &Array[(Str, Str)], name: Str) -> Option[Str]
export fn renderForm(fields: &Array[(Str, Str)]) -> Str
export fn parseForm(body: Str) -> Array[(Str, Str)]
```

The module additionally exports the status predicates, header constants and transformations,
cookie/authentication helpers, content negotiation, range parsing, request-body helpers, and
protocol renderers declared in `lib/Std/Http.pudu`. Private helpers own base64, percent encoding,
numeric parsing, and preference ordering.

### Governance

- Protocol values remain pure data. Network transport belongs to a later host boundary.
- Header comparisons are case-insensitive while exported canonical names are lowercase.
- Form decoding preserves malformed percent escapes literally rather than inventing bytes.
- A valid percent escape performs its two dependent `Option` steps through `Option.andThen`, then
  uses one `if let` to bind the decoded character. The one-success/one-fallback decision must not
  regress to nested `match`.

### Linkage

- **Requires:** `Std.Option`, the Pudu prelude, and [[grammar/pudu]].
- **Consumed by:** HTTP callers and `Std.Http.Message`.

## Algorithm

Transform protocol values with deterministic array and string passes. Form encoding walks Unicode
characters, writing safe characters directly and percent-encoding the rest. Form decoding walks
the source once, maps `+` to space, attempts a two-digit hexadecimal decode only where two digits
remain, advances over both digits only after a character is produced, and otherwise copies the
original character.

## Negative Logic (Prohibited Paths)

- No socket, TLS, DNS, filesystem, clock, or environment access.
- No silent replacement character for a malformed percent escape.
- No nested `match` for dependent optional form-decoding steps.

## Grill Log

- **Q:** Why compose the two optional decoding steps before branching? **A:** They share one failure
  behavior. _Rationale:_ `Option.andThen` states dependency and `if let` states the only decision,
  so the source has one success path and one literal fallback. _Rejected:_ two nested exhaustive
  matches; unchecked extraction; changing malformed-input behavior.
- **Q:** Why keep HTTP transport out of this module? **A:** These transformations are deterministic
  protocol logic. _Rationale:_ separating host effects keeps them executable in tests and avoids
  making request construction depend on a network capability. _Rejected:_ an all-in-one client.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[ADR-0010 Refutable Pattern Conditions]]
