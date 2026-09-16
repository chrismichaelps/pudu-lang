---
type: concept
tags: [concept, semantics]
aliases: [Unsafe Capabilities]
---

# Unsafe Capabilities

## Purpose

Record how Pudu bounds unchecked code: an unsafe region grants named capabilities, and every unchecked ability is reached through one.

## Position

C++ has no marker at all — undefined behavior is reachable from ordinary code with nothing to grep for. Rust marks the boundary but not its content: one `unsafe` grants raw pointers, foreign calls, unchecked indexing, and union access alike, so an auditor reads bodies to learn which invariant is at stake.

Pudu names the capability. [[grammar/pudu]]'s unsafe boundary already enumerated the four abilities the construct enables, so the region declares which of them it takes:

```pudu
unsafe(raw) { ... }          // raw pointer work, nothing else
unsafe(foreign, null) { ... } // a foreign call that may yield null
unsafe { ... }                // the blanket form: all four
```

## Rules

- A region grants exactly the capabilities it names; naming none is the blanket form and grants all four.
- A function may be declared `unsafe`, optionally naming capabilities. Calling it requires an open region granting what the declaration asked for — a blanket declaration requires only that some region is open, and a named one requires each capability by name.
- A function's unsafety is a contract its callers uphold, not a claim about its body. A body needing nothing unchecked is still a legitimate unsafe function, because the invariant may live in its parameters.
- A region that grants a capability nothing in it used reports `W3001`. An audited surface stays minimal only if unused grants are removed.
- Unsafe never disables type checking, scope, or safe-value ownership. [[architecture/SEMANTICS]] is explicit that the compiler keeps enforcing them inside a region.
- `null` requires the `null` capability and has no type until raw pointers exist, so writing it reports which slice will give it one rather than admitting an untyped value.

## Diagnostics

- `E3023` — an unsafe function called outside a region, or inside one that does not grant what it asked for. The message names the missing capability.
- `E3024` — `null` outside a granting region, or inside one before raw pointers exist.
- `E1044` — a capability outside the closed vocabulary.
- `W3001` — a region granting an ability nothing in it used.

## What is not decided yet

Raw pointers, foreign declarations, and unchecked indexing have no syntax, so the `raw`, `foreign`, and `unchecked` capabilities can be granted but nothing yet consumes them. They are admitted now so that the capability vocabulary is fixed before the operations arrive, rather than being retrofitted around them.

## Grill Log

- **Q:** One `unsafe` or named capabilities? **A:** Named, from the set [[grammar/pudu]] already enumerates. _Rationale:_ a reader and a tool both want to know which invariant is in play, and a single switch answers "some invariant, read the body". _Rejected:_ a blanket keyword only; an attribute per operation, which spreads the boundary instead of bounding it.
- **Q:** Should an unsafe function whose body needs nothing be reported? **A:** No. _Rationale:_ the unsafety is a contract about its inputs, which the body cannot show. _Rejected:_ warning on it, which would push authors to drop a marker their callers depend on.
- **Q:** Should a region grant capabilities the language cannot yet use? **A:** Yes, and report them unused. _Rationale:_ fixing the vocabulary before the operations arrive keeps later slices from renaming it. _Rejected:_ admitting only `null`, which would force a grammar change per slice.
- **Q:** What type does `null` have inside its region? **A:** None yet, and the diagnostic says so. _Rationale:_ giving it a free type variable would let it flow anywhere, which is the one thing [[architecture/SEMANTICS]] forbids unsafe from doing — it does not disable type checking. _Rejected:_ typing `null` as any type; silently accepting it.

## Referenced by

[[grammar/pudu]] · [[architecture/SEMANTICS]] · [[Type Check]] · [[Type Env]]
