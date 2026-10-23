---
type: module
path: "@root/src/Pudu/Type/Check/Install.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.62
depth_status: MEDIUM
coupling: 4.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Check Install]
---

# Type Check Install

## Purpose

Declare one body-free [[Type Interface]]'s signatures into a checker, split into what every
importer receives and what only a particular consumer receives.

## Interface

```haskell
interfaceScope :: DeclaredTypes -> Map Text NominalId -> TypeInterface -> DeclaredTypes
installShared :: DeclaredTypes -> TypeInterface -> Checker ()
installWanted
  :: DeclaredTypes -> Set NominalId -> Set Text
  -> Map NominalId [Located Function] -> Set (NominalId, Text)
  -> TypeInterface -> Checker ()
```

## Governance

- `installShared` binds constructors, trait members, and foreign functions under bare and
  module-qualified names. It depends on no import list and runs once per graph in
  [[Type Interface Graph]].
- `installWanted` binds only imported functions and annotated constants, and implementation methods
  whose trait is visible; [[Type Check Import]] runs it per consumer.
- Restrictions (unsafe capabilities, compile-time purity) follow every name a value is published
  under.
- An imported function or annotated constant is declared under its bare name only for the time it
  takes to publish it under its module-qualified name; `preservingName` ([[Type Env]]) then restores
  the bare name's previous binding and restrictions. The consumer reaches it through its qualifier
  or a selected binding from [[Type Check Import]], never by the bare name, so a prelude value such
  as `show` keeps its own type and restrictions (#545).
- Types are formed under the declaring interface's names first (`interfaceScope`).

## Linkage

- **Requires:** [[Type Env]], [[Type Formation]], [[Type Check Method]], [[Type Check Foreign]],
  [[Type Interface]], [[Type Value]].
- **Consumed by:** [[Type Interface Graph]], [[Type Check Import]].

## Negative Logic (Prohibited Paths)

- No body checking, coherence checking, or dependency traversal.
- No imported function or constant remains bound under its bare name; only selected imports bind
  bare names, through [[Type Check Import]].

## Grill Log

- **Q:** Why a separate module? **A:** Graph preparation and per-consumer import both need the same
  declaration code, and the graph module sits below [[Type Check Import]].

- **Q:** Why could an aliased import change what `show(3)` means? **A:** Declaration bound the
  function's bare name in the shared module frame and nothing removed it, overwriting the prelude
  binding the resolver had already accepted. Scope the bare binding to its declaration and restore
  the previous one (#545). **Rejected:** declaring straight under the qualified name, which would
  duplicate the declaration code and the restriction recording for one caller; filtering the
  prelude names, which would leave a later local or graph binding exposed to the same overwrite.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Interface Graph]] · [[Type Check Import]]
