---
type: module
path: "@root/src/Pudu/Compiler/Lower/Drop.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, compiler, ownership]
aliases: [Compiler Lower Drop]
---

# Compiler Lower Drop

## Purpose

Lower ownership ends into native Core: adopt the locals that own a value
needing drop, emit a drop call where a scope ends, and build one glue function
per needs-drop type that runs the type's own `drop` and then its parts.

## Interface

`ownedAt`, `adoptLocal`, `adoptOwned`, `adoptLocals`, `ownedLocals`,
`dropValue`, `droppingBlock`, `closingScope`, `droppingAll`, `droppingLoop`,
`needsDropType`.

## Algorithm

`ownedAt` asks the current module's `scopeOwned` set whether checking marked
the binder or statement at a span. Spans restart in every module, so only the
module whose function is being lowered can answer.

`adoptLocal` registers a binder whose type needs drop: the local id joins
`lowerOwned`, and the function's `contextOwnedLocals` entry records the local
with its glue, in bind order. `adoptOwned` makes a local own its value whatever its binder: `adoptLocal`
checks `ownedAt` and then delegates to it. `ownedLocals` answers the ids of the
bound locals whose binders checking marked owning, so a caller can hand that set
to a lifted body. `adoptLocals` folds over a pattern's or a
parameter list's binders. A named function's parameters and a closure's are
both adopted this way; [[Compiler Lower Function Body]] and [[Compiler Lower
Lambda]] each close the scope that holds them.

`dropValue` asks `glueFor` for the type and, when there is one, emits
`CoreEvaluate (CoreCall glue [value])`. `droppingBlock` drops the innermost
scope; `droppingAll` drops every open scope, parameters included;
`droppingLoop` drops the scopes opened inside a loop for a transfer to it.
`closingScope` keeps a finished block's result in a fresh local, drops the
scope, and answers a block whose result reads the kept local; a block whose
result is `CoreNeverType` left through a transfer that dropped already, so it
is left alone.

`needsDropType` is true when the type has its own `drop` method or any part
does. A visited set stops a self-holding type from recursing forever.

`glueFor` makes one function per needs-drop type, keyed by `::drop::` plus a
sanitized rendering of the type. The key is marked made before the body is
built, so a type that holds itself calls the glue being built. `glueBody` runs
the user's `drop` on the whole value through `invokeLent`, writes the returned
value back into `self`, then drops tuple members, record fields or sum payloads
in declaration order. A `KernelPresent` guard keeps an emptied value from
being dropped again.

## Negative Logic

A type that needs no drop gets no glue and no drop call. A moved local is
empty, so its slot is skipped by the runtime drop table; the lowering still
emits the call where the scope ends, and the glue's presence guard makes the
call a no-op.

A block that stopped (a refusal) is not closed; no program is emitted.

## Edge Cases

A sum glue binds each variant's payload to locals and drops the locals in
declaration order. A tuple's members are dropped by index. A record's fields
are read through `CoreField` and dropped in declaration order. The glue's own
`self` is a parameter, not an owned local, because the caller transfers the
only reference to it.

## Resolved Grill Log

- **Q:** Why one glue function per type instead of inlining the drops at each
  scope? **A:** A type's parts and its user `drop` are the same everywhere;
  one function keeps the drop order in one place and lets the runtime drop
  table name a function index. _Rationale:_ repeated inlining would multiply
  code and let two sites disagree.
- **Q:** Why mark the glue key before building its body? **A:** A recursive
  type's glue calls itself for its own part. _Rationale:_ the key is the
  recursion point, and the function table is filled after the body is built.
- **Q:** Why is the `KernelPresent` guard in the glue rather than at every
  call? **A:** A moved local's slot is empty at scope end, and the same glue
  is called from the runtime drop table after a stop. _Rationale:_ one guard
  covers both paths without a second lowering rule.

## Referenced by

[[Compiler Lower]] · [[Compiler Lower Body]] · [[Compiler Lower State]] · [[Core Frame IR]] · [[Backend Runtime]] · [[Native Emission Coverage]]
