---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Type/Formation/Shell.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, formation]
aliases: [Type Formation Shells]
---

# Type Formation Shells

## Purpose and interface

`addShell`, `locallyDeclared` and `paramEntries` own the pure first declaration
pass used by [[Type Formation]]. Shells establish canonical nominal identities
and parameter arities before aliases, fields and implementation heads are formed.

## Algorithm and invariants

Register local and canonical qualified names for record/sum/alias declarations,
trait identities and foreign opaque handles. Collect names that clear stale bare
aliases at the local module boundary. Preserve fully qualified identities from
other modules. Parameter arities remain beside their names.

## Negative logic and edge cases

No field formation, checking, body walking, diagnostics or IO. Later aliases and
recursive nominal types resolve through shells without repeating collection.
This extraction preserves the prior collection order and shadowing rules.

## Grill Log

- **Q:** Leave the expanded formation module over 500 lines? **A:** No; extract
  its pure shell pass. _Rationale:_ nominal registration is a distinct dependency
  before type formation. _Rejected:_ exposing checker state or duplicating the pass.

## Referenced by

[[Type Formation]] · [[src/Pudu/Type/_MOC]] · [[Pudu Cabal Manifest]]

Trait shells register their parameter names as well as their canonical identity,
so bound method selection can specialize applications without reading bodies.
Resolved Grill Log: trait parameters belong to the same declaration inventory as
type parameters; a missing inventory would silently retain fresh result variables.

Type and trait shells inventory their parameter kinds alongside names. The
constructor-bound shorthand needs that fact before any body is checked.
Resolved Grill Log: declaration arity belongs in collection, not a trait-name special case.
