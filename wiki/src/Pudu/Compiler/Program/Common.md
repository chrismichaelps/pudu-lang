---
type: module
path: "@root/test/Pudu/Compiler/Program/Common.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Testing]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.52
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.85
tags: [module, test, medium]
aliases: [Program Test Common]
---

# Program Test Common

## Purpose

Compile complete fixture programs and expose stable observations for program-level tests: rendered
entry results, raw entry values, module order, and static or runtime diagnostics.

## Interface

`runEntry` renders a successful `main` result. `runEntryValue` preserves the runtime value for
structural assertions that rendering cannot express. Diagnostic helpers expose codes, messages,
help, and source offsets without making each specification repeat program compilation.

### Linkage

- **Requires:** [[Compiler Program]], [[Eval Program]], [[Eval Value]], [[Diagnostic Model]].
- **Consumed by:** [[Language Foundation Program Spec]] and the other program specifications.

## Algorithm

Compile the root path, refuse evaluation when no root module was produced, otherwise evaluate
`main` with the discovered dependencies and inferred integer kinds. Projection helpers transform
that one result into the representation a property needs.

## Negative Logic (Prohibited Paths)

- No fallback evaluation after compilation fails.
- No diagnostic normalization that discards stable wording, help, or span evidence.

## Edge Cases

- `runEntryValue` returns `Nothing` both for compilation failure and for evaluation without a value;
  tests needing failure identity use the diagnostic helpers instead.
- Runtime helpers return compile diagnostics when the program never reaches evaluation.

## Depth

DEPTH 0.52 (MEDIUM). It centralizes the full-program boundary while leaving assertions in their
own specifications.

## Grill Log

- **Q:** Render every successful value before tests see it? **A:** No. _Rationale:_ closure capture
  metadata and other structural invariants deliberately have no source-visible rendering, so
  `runEntryValue` keeps the raw value for narrow white-box regressions. _Rejected:_ adding debug
  fields to the language's value renderer.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[Language Foundation Program Spec]]
