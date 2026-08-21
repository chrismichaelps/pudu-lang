---
type: seam
capacity: EXPLORATORY
capacity_score: 3
lifecycle: EXPLORATORY
drift_score: 0
drift_status: HEALTHY
production_adapters: 1
change_freq_per_quarter: 0
tags: [seam]
aliases: [Native Toolchain]
---

# Native Toolchain

## Classification

EXPLORATORY — one production C11 compiler adapter on the native compilation path. The boundary earns isolation because process discovery, invocation, cancellation, output staging, and diagnostic translation are external failure modes. It does not earn a multi-backend framework.

## Interface

- Input: generated C source, target model, output path, optimization/debug policy.
- Success: atomically published native [[Compilation Artifact]].
- Failure: typed tool-not-found, invocation, timeout/cancellation, or compile failure with captured bounded output.
- No shell interpolation; arguments are passed structurally.

## Adapters

| Adapter | Type | Path | Last verified | Status |
| --- | --- | --- | --- | --- |
| System C compiler (`cc`/configured path) | production | planned `@root/src/Pudu/Backend/Toolchain.hs` | not implemented | PLANNED |

## Health

DRIFT 0 (HEALTHY by specification). No callers exist; no bypass exists.

## Negative Logic

- No guessed compiler flags outside the target policy.
- No publishing partial executable output.
- No unbounded stderr/stdout retention.
- No fallback to a different compiler after a semantic compile failure.

## Grill Log

- **Q:** Should clang and gcc be separate production adapters now? **A:** No; use one conservative C11 invocation contract and promote only after verified divergence demands it. _Rationale:_ current variation is speculative. _Rejected:_ provider hierarchy before a second adapter.
- **Q:** Should missing `cc` trigger automatic installation? **A:** No; return an actionable diagnostic. _Rationale:_ compilers must not mutate developer machines implicitly. _Rejected:_ package-manager automation.

## Referenced by

[[seams/_MOC]] · [[architecture/OVERVIEW]] · [[Backend]] · [[Native Backend]] · [[Compilation Artifact]] · [[ADR-0002-compiler-pipeline]]
