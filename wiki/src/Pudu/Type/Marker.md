---
type: module
path: "@root/src/Pudu/Type/Marker.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.62
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.9
tags: [module, medium]
aliases: [Type Marker]
---

# Type Marker

## Purpose

Decide the markers the compiler controls — `Copy`, `Send`, and `Sync` — from a type's structure rather than from a table of written implementations.

## Interface

### Signatures

```haskell
isMarkerTrait :: NominalId -> Bool
isUserImplementable :: NominalId -> Bool
satisfiesMarker :: NominalId -> Type -> Checker Bool
```

### Governance

- These markers are structural facts, not declarations. [[grammar/pudu]] states each rule directly, so answering them by looking up an `impl` would make every builtin fail a bound no program can satisfy.
- `Copy` holds for integer, floating, boolean, and character scalars, for unit, for a shared reference, and for a tuple, record, or sum whose every stored component is `Copy`. It does not hold for owned text, for a growable collection, for an exclusive reference, or for a function value.
- `Send` and `Sync` follow the same structural walk, with owned text and collections included: a value crosses into a task when everything it holds does. A shared reference is `Send` exactly when its referent is `Sync`, which is the rule that keeps sharing across tasks honest.
- The walk carries the nominal types it is already deciding, so a recursive declaration answers instead of looping.
- A rigid parameter is never satisfied here. Its declared bounds decide it, and the caller consults those first; guessing would let an unbounded parameter borrow a guarantee it never declared.
- A declaration this module cannot see satisfies nothing. Absence of evidence is not evidence of a marker.
- `Copy` is compiler-controlled, so [[architecture/SEMANTICS]] rejects a user-written implementation of it with `E3021`. `Send` and `Sync` remain implementable, because a wrapper may state a guarantee its structure cannot show.

### Linkage

- **Requires:** [[Type Env]], [[Type Value]], [[grammar/pudu]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Type Check Method]] when discharging trait obligations, and [[Type Check Coherence]] when admitting an implementation.

## Algorithm

Walk the type: scalars and unit answer immediately, references answer by the rule for their sharing, aggregates answer by their components with the use's type arguments substituted for the declaration's parameters, and nominal declarations are visited at most once.

## Negative Logic (Prohibited Paths)

- No implicit `Drop` for any builtin, no marker granted to an unseen declaration, no satisfaction of a rigid parameter without its bound, no ownership or borrow analysis, and no table of wired-in implementations standing in for the structural rule.

## Edge Cases

- `Never` and the error type satisfy every marker vacuously, so an unreachable branch and an already-reported mistake raise no second complaint.
- An unsolved inference variable satisfies nothing; the obligation that mentions it is left for the caller, which skips unresolved obligations rather than guessing.
- `Array[T]` is `Send` and `Sync` when its elements are, but never `Copy`: it owns its storage.

## Depth

DEPTH 0.62 (MEDIUM). It hides the structural rules, argument substitution, and cycle protection behind one question.

## Grill Log

- **Q:** Should builtin markers be wired-in `impl` entries? **A:** No; decide them structurally. _Rationale:_ `Copy` for a user record depends on that record's fields, which no fixed table can express, and two mechanisms for one rule would drift. _Rejected:_ a table of builtin implementations; a `derive` attribute.
- **Q:** Is owned text `Copy`? **A:** No. _Rationale:_ [[grammar/pudu]] lists exactly which values copy, and text is an owning handle rather than a scalar. _Rejected:_ copying text for convenience, which would hide an allocation behind an assignment.
- **Q:** May a program implement `Send` by hand? **A:** Yes, unlike `Copy`. _Rationale:_ [[architecture/SEMANTICS]] names only `Copy` as compiler-controlled, and a wrapper around a synchronized resource can be sendable when its structure cannot prove it. _Rejected:_ rejecting all marker implementations; admitting a hand-written `Copy`.
- **Q:** What about a type declared in another module? **A:** It satisfies nothing until its declaration is visible. _Rationale:_ a marker is a structural claim, and claiming one for a shape this phase cannot see would be a guess. _Rejected:_ assuming unseen aggregates are copyable.

## Variants

- `Drop`-aware `Copy` rejection joins this module when ownership checking admits `Drop` implementations, at which point an aggregate with a destructor stops copying.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check Method]] · [[Type Check Coherence]] · [[grammar/pudu]] · [[architecture/SEMANTICS]]
