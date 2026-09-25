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
- Types are formed under the declaring interface's names first (`interfaceScope`).

## Linkage

- **Requires:** [[Type Env]], [[Type Formation]], [[Type Check Method]], [[Type Check Foreign]],
  [[Type Interface]], [[Type Value]].
- **Consumed by:** [[Type Interface Graph]], [[Type Check Import]].

## Negative Logic (Prohibited Paths)

- No body checking, coherence checking, or dependency traversal.

## Grill Log

- **Q:** Why a separate module? **A:** Graph preparation and per-consumer import both need the same
  declaration code, and the graph module sits below [[Type Check Import]].

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Interface Graph]] · [[Type Check Import]]
