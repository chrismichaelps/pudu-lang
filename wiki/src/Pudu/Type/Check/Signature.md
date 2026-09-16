---
type: module
path: "@root/src/Pudu/Type/Check/Signature.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.35
depth_status: SHALLOW
coupling: 2.0
interface_stability: 0.85
tags: [module, shallow]
aliases: [Type Check Signature]
---

# Type Check Signature

## Purpose

Decide what a declaration must state about itself, before any body is looked at.

## Interface

```haskell
traitAliases                :: DeclaredTypes -> DeclaredTypes
adoptDeclaredSignature      :: Function -> [Type] -> Type -> Scheme -> Checker ()
requireFunctionAnnotations  :: Function -> Checker ()
requireInterfaceAnnotations :: Function -> Checker ()
selfBoundAsBound            :: NominalId -> [(Text, [NominalId])]
selfRigid                   :: NominalId -> [Text]
nonMutatingMethods          :: [Text]
```

### Governance

- These are the rules a declaration owes that are **not about the type it turns
  out to have**. An exported name must say its type rather than leave a reader
  to infer it from a body they cannot see; a trait member must say its own,
  because an implementer reads the trait and not the default.
- **Nothing here calls back into checking.** That is what lets it be a module
  rather than an argument: every other split in the checker needed a capability
  record because the recursion is real, and this one did not because it decides
  what is owed before any body is checked.
- `E3010` is reported here and where declarations are checked. Both say the same
  thing — a name others can see must state its type — for a function and its
  parameters here, and for a binding there.
- `Self` stays rigid while the trait naming it is checked, so `formType`
  produces `RigidType "Self"` rather than a nominal type nothing implements.

### Linkage

- **Requires:** [[Type Env]], [[Type Formation]], [[Syntax Tree]].
- **Consumed by:** [[Type Check]].

## Algorithm

Direct inspection of a declaration's syntax against the rules its visibility
implies. No inference, no recursion.

## Negative Logic (Prohibited Paths)

- No expression, statement, or block checking — this module runs before any of
  it, and reaching into it would put a body's meaning behind a signature rule.
- No capability record, because there is no cycle to express.

## Grill Log

- **Q:** Why split this out rather than the expression half first? **A:** Because
  it is the part with no back-edge. _Rationale:_ measuring what each cluster
  called showed this one calling nothing in the rest, so it moves as a module
  with no indirection at all; the expression half needs a record for `checkBlock`
  and `checkAgainst`. _Rejected:_ cutting by line count and discovering the
  cycles afterwards.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]]
