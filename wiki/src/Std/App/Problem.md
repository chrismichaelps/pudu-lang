---
type: module
path: "@root/lib/Std/App/Problem.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, application, errors, http]
aliases: [Std App Problem]
---

# Std App Problem

## Purpose and interface

One machine-readable failure body (RFC 9457 problem details) for every refusal a service makes, so
a client parses one shape whatever went wrong.

Exports:
- `type Problem = { kind, title, status, detail, instance, extensions }`; `kind` is the `type` member.
- `type ProblemError = NotJson(Str) | NotAnObject | MissingStatus`; `MEDIA_TYPE`.
- `status(code)`, `typed(kind, code, title)`, `detailed(code, detail)`; record update sets the rest.
- `withExtension(problem, name, value)`: appended once; standard member names are ignored.
- `fromReport(report: &Validate.Report)`: 422 with `errors` mapping each field to its expectations.
- `toJson`, `respond` (status plus `application/problem+json`), `parse` (client side), `explain`.
- `uniform: Route.Middleware`: rewrites every plain 4xx/5xx into a problem with the request path as
  `instance`; a 5xx body is dropped so internal text never reaches a client.

## Connections

`uniform` is added with `App.wrapping`. [[Std App Idempotency]] and [[Std App Page]] refusals are
problems, and [[Std Validate]] reports convert with `fromReport`, so validation, pagination,
idempotency, and handler failures share one body.

## Grill Log

- **Q:** Render a stack trace or message in development? **A:** No. _Rationale:_ a flag that leaks
  internals in one environment leaks them in the one someone misconfigured; the trace belongs in
  [[Std Log]]. _Rejected:_ an environment-dependent detail.
- **Q:** Let an extension override `status` or `type`? **A:** No. _Rationale:_ a body whose members
  disagree with the response status is the ambiguity this format exists to remove.
- **Q:** Rewrite responses that already carry a body type? **A:** Only failures that are not already
  problems; a handler that wrote its own problem is left alone.

## Dependencies and consumers

- Depends on [[Std Json]], [[Std Validate]], [[Std Http Server Route]], and `Std.Http.Message`.
- Consumed by [[Std App Idempotency]] and service handlers.

## Referenced by

[[src/Std/_MOC]] · [[architecture/WEB]]
