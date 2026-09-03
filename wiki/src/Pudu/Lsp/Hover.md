---
type: module
path: "@root/src/Pudu/Lsp/Hover.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Hover]
---

# LSP Hover

## Purpose

Answer what the editor cursor is on from one compiler analysis, preserving foreign trust provenance
when a plain inferred type would hide it.

## Interface

```haskell
hoverAt :: Analysis -> Int -> Json
```

### Governance

- The narrowest compiler-recorded expression type answers ordinary names and expressions.
- A foreign function name is answered from its documentation entry first so its inferred signature
  remains visible beside the named library and the fact that the signature is asserted, not proved.
- A declaration entry is a fallback only when no expression type answers; whitespace returns null.
- A call-site hover carries no declaration range because that range is elsewhere in the document.

### Linkage

- **Requires:** [[Lsp Documents]], [[Lsp Feature]], [[Doc]], [[Type Boundary]].
- **Consumed by:** [[Lsp Server]].

## Algorithm

Read the word at the offset, prefer a matching foreign entry, otherwise read the narrowest inferred
type, then fall back to the declaration whose span contains the offset.

## Negative Logic (Prohibited Paths)

- No parsing, type inference, document mutation, IO, or guessed foreign provenance.

## Grill Log

- **Q:** Append foreign provenance to every inferred type? **A:** No. _Rationale:_ only the foreign
  declaration knows which library asserted the signature; ordinary types need no trust warning.
  _Rejected:_ a generic warning on every hover.
- **Q:** Return the foreign declaration's range at a call site? **A:** No. _Rationale:_ a hover range
  describes the selected source under the cursor, not a definition elsewhere. _Rejected:_ attaching
  the declaration span to uses.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
