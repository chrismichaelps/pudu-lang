---
type: module
path: "@root/test-fixtures/exhaustnamespace/RejectsJsonCoverage.pudu"
fidelity: Active
subsystem: "[[Testing]]"
grammar: "[[grammar/pudu]]"
tags: [fixture, exhaustiveness]
---

# Exhaust Namespace RejectsJsonCoverage

## Purpose

Omit the Text branch in a nested Option[Value] match while Std.Json is imported; require E5001 rather than importing coverage from another owner.

## Interface

`main() -> Int` calls a private classifier whose missing Text branch must be refused statically.

## Algorithm

Static graph compilation uses canonical constructor owners; successful entries exercise the classifier and Json independently.

## Negative Logic

No basename-dependent constructor coverage or wildcard repair of the complete classifier.

## Edge Cases

Importing same-named Json variants neither removes nor supplies coverage for the local Atom type.

## Grill Log

- **Q:** Why use a module graph rather than one unit source? **A:** The regression requires unrelated loaded declarations to share constructor names. _Rationale:_ a single-source check cannot reproduce that environment. _Rejected:_ only testing local constructor names (#378).

## Referenced by

[[Type Exhaust]] · [[Type Check Pattern Spec]]
