---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Inference.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, inference]
aliases: [Derive Capture Inference]
---

# Derive Capture Inference

## Purpose and interface

`inferenceCaptures` accepts a defining module and its ordinary full Resolution.
Return the set of module declaration name spans whose unwritten signatures a
derive depends on, transitively. `inferenceErrors` selects resolver findings
within those admitted helper declarations. A private helper or constant needs no
new annotation solely because a derive captures it.

## Algorithm and invariants

Index top-level declaration extents by start offset. Map resolved ModuleOrigin
value references to their actual declaration name spans, never spelling guesses.
Locate each reference's owning declaration with an ordered predecessor query;
generated references use their request anchor for containment. Seed the worklist
from derive declaration references, then follow only declarations with unwritten
function parameter/result types or constant annotations. Annotated contracts need
no body inference at this boundary. A visited set closes cycles and diamonds.
Two ordinary resolver walks suffice: the signature/template projection and the
full reference graph; do not re-resolve a whole module per newly found helper.

## Edge cases and negative logic

Lexical local/parameter shadowing is excluded by resolved symbol origin. References
outside a top-level extent or with different source identity cannot add a helper.
No body evaluation, constant folding, source-string generation, private export,
global-name heuristics or ignoring errors from a needed inference declaration.
Unrelated ordinary body errors remain the ordinary phase's responsibility.

## Grill Log

- **Q:** Infer a captured helper separately for every target? **A:** Infer its
  actual unwritten contract once before generic template checking. _Rejected:_
  caller-driven helper signatures or repeated per-request author diagnostics.
- **Q:** Require private helper annotations? **A:** Preserve ordinary inference.
  _Rejected:_ a new language restriction introduced by the delivery machinery.
- **Q:** Walk every helper textually? **A:** Use resolved identities and an
  indexed bounded worklist. _Rejected:_ binding-shadow guesses and quadratic
  repeated whole-module resolution as the dependency closure grows.

## Linkage and references

Requires [[Name Resolution]], [[Symbol Model]], [[Source]] and [[Syntax Tree]].
Referenced by [[Validated Derive Definitions]] · [[Type Check]] · [[Derive Graph]]
· [[src/_MOC]].
