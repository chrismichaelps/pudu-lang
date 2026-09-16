---
type: module
path: "@root/src/Pudu/Type/Check/Record.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 4.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Check Record]
---

# Type Check Record

## Purpose

Check a record construction, and a variant that names its payload.

## Interface

```haskell
data CheckValue = CheckValue
  { valueOf      :: DeclaredTypes -> [Text] -> Located Expression -> Checker Type
  , valueAgainst :: DeclaredTypes -> [Text] -> Type -> Located Expression -> Checker Type
  }

recordType        :: CheckValue -> DeclaredTypes -> [Text] -> Span -> ModuleName -> [Located FieldInit] -> Checker Type
namedVariantShape :: Text -> Checker (Maybe (NominalId, [Text], [(Text, Type)]))
```

### Governance

- A field's value is an expression and an expression may be a record
  construction, so one direction is an argument. **Two directions are carried
  rather than one**: a field with a written value is checked *against* its
  declared type, so a literal of mixed implementations reaches the field's own
  type rather than being inferred on its own first.
- A generic record is instantiated at every construction: `Boxed{value: 7}` is a
  `Boxed[Int]`, and the field is checked against `Int` rather than against the
  declaration's rigid parameter, which nothing could satisfy.
- A variant that named its payload is built by naming it, and the names sit over
  the same positional payload — so `namedVariantShape` answers with the shape
  only when the declaration gave names and they match the payload's width.
- Every declared field must be supplied (`E3008`), and a field the type does not
  declare is `E3005` where it was written rather than at the construction.

### Linkage

- **Requires:** [[Type Env]], [[Type Formation]], [[Type Unify]], [[Syntax Tree]].
- **Consumed by:** [[Type Check Expression]].

## Algorithm

Look the declaration up, instantiate its parameters afresh, check each written
field against the type it was declared with, then name what is missing.

## Negative Logic (Prohibited Paths)

- No expression checking of its own — the record is the path back.
- No deciding what a variant's payload *is*; that is [[Type Formation]], which
  keeps the names beside it.

## Grill Log

- **Q:** Why does the record carry both directions? **A:** Because a field is an
  expectation, not an inference. _Rationale:_ a field declared
  `Array[dynamic Node]` accepts a literal of mixed implementations only if the
  field's type reaches the literal; inferring the literal first makes its
  elements disagree before the field is ever consulted. _Rejected:_ one
  direction and a unification afterwards, which is what that was.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check Expression]] · [[grammar/pudu]]
