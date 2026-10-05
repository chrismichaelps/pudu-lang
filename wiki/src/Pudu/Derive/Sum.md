---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Sum.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, expansion]
aliases: [Derive Sum Residualizer]
---

# Derive Sum Residualizer

## Purpose and interface

`SelectedVariant` carries the declared index and actual instantiated payload.
`variantFields` exposes named payloads and positional fields named by zero-based
decimal positions; unit variants expose none. `variantPattern` creates an ordinary
qualified pattern. `matchesVariant` lowers a test to ordinary if-let. `readField`
lowers a selected field read to a block holding an ordinary `let … else` whose
fallback panics with `expected Owner.Variant`.

## Invariants and edges

The prepared target supplies the canonical owner and concrete payload types.
Keep declaration order, payload kind, field/variant attributes and authored spans.
Pattern binders live in their own generated block and the subject is evaluated
before they enter scope; user expressions cannot be captured by those binders.
Every syntax node uses the existing request-owned bounded Residual state.
Reading a selected variant field requires a value of that variant; a mismatch
panics (E7007) naming the variant expected, through ordinary authored syntax,
never a Meta runtime placeholder. The generated text is therefore what a person
could write, and `pudu expand` prints it as such.
Builders and Sum writes are separate integration work until explicitly admitted.

## Grill Log

- **Q:** Use a runtime descriptor or a Meta panic to project a payload? **A:**
  Generate an ordinary destructuring binding with its existing mismatch outcome.
  _Rejected:_ runtime metadata, silent defaults or a fabricated field type.
- **Q:** Keep the refutable destructuring `let`, failing with E7013? **A:** No.
  _Rationale:_ authored code cannot spell a refutable `let` without `else`
  (E1059), so printed expansions did not check. `let … else { panic(...) }` is
  the authored form, tests the same pattern once, and names the variant in its
  failure. _Rejected:_ printing a different form from the one that runs.
- **Q:** Derive a variant's owner from its basename? **A:** Append the variant
  segment to the already canonical target path. _Rejected:_ caller imports
  selecting the constructor or a competing same-basename sum.

## References

Requires [[Derive Residual State]], [[Derive Syntax]], [[Derive Target Application]]
and [[Syntax Tree]]. Referenced by [[Derive Record Residualizer]] · [[Derive Graph]]
· [[src/_MOC]].
