---
type: module
path: "@root/src/Pudu/Compiler/Lower/State.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, compiler]
aliases: [Compiler Lower State]
---

# Compiler Lower State

## Purpose and interface

Own program context, per-function scopes, local numbering and accumulated typed refusals.

Exports: `LowerContext(..), LowerState(..), LoopFrame(..), CoreSignature(..), emptyContext, startFunction, refuse, refused, halt, lookupLocal, bindLocal, intType`.

## Algorithm and invariants

Program context survives function boundaries; local numbering and scopes reset. The optional result records the declared non-entry type or the first explicit entry return, so resultless outer blocks cannot erase an explicit Int return. Refusals preserve source spans and never throw.

The program context carries the entry name, declaration-ordered function
table, signature memo, worklist queue, visited set, accumulated refusals and
completed Core functions. Per-function state carries next local ID, lexical
scope frames, optional result type, numeric loop supply and nearest-first loop
frames holding optional source labels and observed break types. CoreSignature carries the parameter
locals and result type. `startFunction` binds parameters in a fresh frame,
numbers them from zero and starts subsequent locals after them; loop IDs restart
at zero and loop frames empty at each function boundary; context remains
unchanged. Lookup searches inner frames before outer frames. A refusal prepends
one source-spanned native diagnostic; `halt` adds it and returns no subtree,
while `refused` returns no subtree without adding a duplicate diagnostic.

```haskell
emptyContext :: Text -> LowerTypes -> [(Text, Located Function)] -> LowerContext
startFunction :: LowerState -> [CoreParameter] -> Maybe CoreType -> LowerState
halt :: Span -> Text -> LowerState -> (LowerState, Maybe a)
```

## Negative logic

No host exceptions, semantic rechecking, global mutable state, or backend emission. Unsupported syntax remains a typed E6001 refusal.

## Dependencies and consumers

[[Compiler Lower]] · [[Compiler Lower Body]] · [[Compiler Lower Signature]] · [[Pudu Core]] · [[Diagnostic Native]]. Only lowering modules consume this phase-owned module.

## Grill Log

- **Q:** Why extract this responsibility? **A:** State ownership and signature admission are stable boundaries independent of mutually recursive expression/block traversal. Each remains reviewable below 500 lines. _Rejected:_ an oversized body module or a circular expression split.
- **Q:** Can refactoring alter accepted semantics? **A:** No; only explicit corrections preventing invalid Core returns and Result erasure are permitted. Signature refusals and scope resolution retain their source provenance. _Rejected:_ backend inference or approximation.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Compiler Lower]] · [[Compiler Lower Body]]

## Scalar loop-control extension (#489)

[[Compiler Lower Control]] owns nearest labelled target resolution, break-type joins,
while/loop values and direct terminal Never detection. State resets loop numbering
and frames per function. Body delegates through traversal callbacks; if branches
join Never with reachable types. Print-valued break operands refuse Result erasure.

Resolved Grill Log: while conditions lower before their frame; operands lower
before break observation; labels become numeric identities; only scalar/unit
results are admitted. Rejected silent Result erasure and source-label C names.


## Solved native type inputs (#491)

LowerContext retains contextTypes :: LowerTypes. emptyContext :: Text -> LowerTypes -> [(Text, Located Function)] -> LowerContext. Facts survive every function boundary without rechecking or global state.

Resolved Grill Log: consume canonical settled checker facts; preserve structural Never, print carrier refusals and existing runtime representations. Rejected: re-inference, display-name ABI selection, offset-only identity or silent fallback.
