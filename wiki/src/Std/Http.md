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
- Form fields and URL components share one percent codec, owned by [[Std Url]], so the two cannot
  disagree about which bytes an escape names.

### Linkage

- **Requires:** `Std.Option`, [[Std Url]], the Pudu prelude, and [[grammar/pudu]].
- **Consumed by:** HTTP callers and `Std.Http.Message`.

## Algorithm

Transform protocol values with deterministic array and string passes. Form encoding is
`Url.encodeComponent` with each `%20` written as `+`; because a literal `%` is itself escaped, every
`%20` in that output came from a space. Form decoding is `Url.decodeComponent`, which already reads
`+` as a space and escapes as UTF-8 bytes.

## Negative Logic (Prohibited Paths)

- No socket, TLS, DNS, filesystem, clock, or environment access.
- No silent replacement character for a malformed percent escape.
- No second percent codec: escaping a character from its scalar value rather than its UTF-8 bytes
  wrote `€` as `%20%AC`.

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


## TLS and binary compression implementation contract

Response adds binaryBody: Option[Bytes]. None transmits UTF-8 body; Some transmits those exact bytes, including an empty byte payload. responseBytes centralizes selection. Text construction initializes None; header-only transformations preserve the complete record. Existing direct response literals must add binaryBody: None.

Request carries the same field with the same precedence, so a body that is not UTF-8 text — an
uploaded image, a compressed payload — has an exact representation in both directions. `request`
initializes it to `None`; `withHeader` keeps the whole record; `withBody` sets a text body, states its
length in UTF-8 bytes, and clears any byte body; `withBytes` sets a byte body with its length in
bytes and an empty text body. `requestBytes` answers the body as bytes whichever form holds it.

Resolved Grill Log: protocol bytes must remain bytes; verified transport cannot downgrade. Errors remain explicit and resource ownership transfers once. Implementation is code-only; no validation or readiness claim.


## Constructor migration references

Existing fixture mirrors: [[src/test-fixtures/stdlib/UsesApp]],
[[src/test-fixtures/stdlib/UsesHttpServer]], [[src/test-fixtures/stdlib/UsesHttpClient]].
Only record construction was migrated; these fixtures were not run.
