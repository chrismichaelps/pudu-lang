---
type: module
path: "@root/test/Pudu/Compiler/Program/LanguageSpec.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Testing]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.7
depth_status: DEEP
coupling: 4.0
interface_stability: 0.8
tags: [module, test, deep]
aliases: [Language Foundation Program Spec]
---

# Language Foundation Program Spec

## Purpose

Exercise function literals, lexical capture, ranges, slices, and destructuring as coherent
full-program features, including their refusal and diagnostic contracts.

## Interface

Exports the five language-foundation properties aggregated by the program test suite:
`testFunctionLiterals`, `testRangesAndSlices`, `testCapturedScope`,
`testDestructuringBindings`, and `testLanguageRefusals`.

### Linkage

- **Requires:** [[Program Test Common]], [[Eval Match]], [[Eval Value]], [[Syntax Tree]].
- **Consumed by:** the package test runner through `Pudu.Compiler.ProgramSpec`.

## Algorithm

Run comprehensive success fixtures and combine their deliberately distinct totals. Compile or run
negative fixtures and assert diagnostic codes; for runtime boundary behavior assert exact message,
help, and source offsets. Direct matcher and closure-shape assertions cover evaluator invariants
that a source-level rendering cannot distinguish.

## Negative Logic (Prohibited Paths)

- No snapshot update without checking the semantic delta.
- No acceptance inferred from one happy-path spelling when grammar, formatter, or runtime supports
  several forms.
- No output-only substitute for capture residency and boundary structure.

## Edge Cases

- Open ranges include missing start, missing end, and both ends missing.
- Inclusive negative slice ends are validated as written before conversion to an exclusive bound.
- Range extent methods refuse results that exceed the declared `Int` result.
- Array sequence patterns do not admit heterogeneous tuples at runtime.
- A closure produced inside an imported declaration keeps its dependency module boundary while
  narrowing transient locals.

## Depth

DEPTH 0.70 (DEEP). The suite crosses parsing, formatting, typing, linking, evaluation, diagnostics,
and retention behavior for language foundations that must agree across every phase.

## Grill Log

- **Q:** Assert only final fixture totals? **A:** No. _Rationale:_ exact diagnostics and direct
  structural checks catch phase disagreement that can leave an aggregate result unchanged.
  _Rejected:_ treating successful evaluation as evidence for every failure boundary.
- **Q:** Test imported capture only by calling the returned function? **A:** No. _Rationale:_ the
  old behavior produced the right answer while retaining the entire imported call stack. The test
  inspects local-frame count and retained names. _Rejected:_ an output-only regression.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Program Test Common]]
