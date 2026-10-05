---
type: module
path: "@root/test/Pudu/Derive/GraphSpec.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, test]
aliases: [Derive Graph Spec]
---

# Derive Graph Spec

## Purpose and interface

`deriveGraphProperties` compiles real loaded programs and executes generated
ordinary methods in both tree and compiled modes. Use arbitrary user traits and
the actual Std.Meta facade; no stubs, manual AST replacement or implicit derives.

## Coverage and invariants

Sum graph fixtures execute unit, positional, named and generic payloads through
a definition module that does not import the consumer target. Assert reflected
declaration indexes, attributes, canonical pattern selection, field values and
ordinary E7013 mismatch behavior in both evaluators. Empty payloads do no work.

Canonical aliases and fully applied external requests preserve the declared
target name. Cross-module templates capture private helpers and constants despite
consumer shadowing, with no extra caller imports or private exports. Conditional
generic bounds propagate through nested/mutually generated heads and preserve
consumer parameter names colliding with T/F template spellings. Inspect final
canonical rules and generated provenance, not only successful output.

Failure fixtures verify one definition error despite multiple requests, field
capability diagnostics with request notes, orphan aliases, private/missing
strategies and generated/ordinary typed overlap. All failed graph products remain
non-executable. Generic unrequested templates are still validated. Private helper
mistakes must be attributed once before multiple generated callers.

## Negative logic and Grill Log

No timing threshold, benchmark-specific behavior or library-completion claim.
**Q:** Are manual kernel transformations graph evidence? **A:** No; this suite
uses compileProgram and actual program products. **Q:** Run one evaluator only?
**A:** Compare both output and diagnostics in both modes. **Q:** Accept inference
from a successful concrete call? **A:** Inspect the emitted conditional rules and
prove invalid concrete calls fail as well.

## Linkage and references

Requires [[Compiler Program]], [[Derive Graph]], [[Eval Program]],
[[Diagnostic Model]] and [[Source]]. Referenced by [[Test Main]] · [[Pudu Test Cabal Manifest]]
· [[src/_MOC]] · [[Derive Design]].
