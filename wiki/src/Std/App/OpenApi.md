---
type: module
path: "@root/lib/Std/App/OpenApi.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, application, api, documentation]
aliases: [Std App OpenApi]
---

# Std App OpenApi

## Purpose and interface

An OpenAPI 3.1 description built from values and checked against the router that serves it.

Exports:
- `type Schema = Text | Whole | Fraction | Truth | OneOf | ListOf | Record | Named | Nullable`,
  `type Property`, `type Location = InPath | InQuery | InHeader`, `type Parameter`, `type Answer`,
  `type Operation`, `type Document`; `PROBLEM_SCHEMA`, `SPEC_VERSION`.
- `operation(method, path, id)`: router `:name` segments become required path parameters; the rest
  is filled by record update.
- `field`, `optional`, `parameter`, `answer`, `document`, and the `Describing` chain
  `.describe(op).schema(name, shape).server(url)`.
- `problems(document)`: repeated ids, undeclared schemas, uncovered path segments, operations with no
  answers.
- `undocumented(document, router)`: routes served but not described, and operations described but
  not served.
- `toJson`, `route(document, path)`.

## Connections

- A 4xx or 5xx answer with no body is published as `application/problem+json` referencing the
  `Problem` schema, which matches what [[Std App Problem]] actually sends.
- A secured operation adds the bearer scheme that [[Std App Jwt]] tokens satisfy.
- [[Std App]] `describing` refuses to build an application whose description and router disagree.

## Grill Log

- **Q:** Derive schemas by reflecting on types? **A:** No. _Rationale:_ the language has no runtime
  reflection, and a schema derived from an internal type publishes whatever that type happens to
  hold. The API contract is written as a value and checked against the router. _Rejected:_ generated
  schemas from records.
- **Q:** Why check both directions? **A:** An undescribed route is an unreviewed public surface; a
  described but unserved operation is a client integration that will fail.

## Dependencies and consumers

- Depends on [[Std App Problem]], [[Std Json]], [[Std Http Server Route]], and
  [[Std Http Server Reply]].
- Consumed by [[Std App]] `describing`.

## Referenced by

[[src/Std/_MOC]] · [[architecture/WEB]]
