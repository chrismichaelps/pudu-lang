---
type: module
path: "@root/src/Pudu/Lsp/InlayHints.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Inlay Hints]
---

# LSP Inlay Hints

## Purpose

Render editor inlay hints showing inferred types for `let` bindings within the visible document range.

## Interface

```haskell
inlayHintsAt :: Analysis -> Range -> Json
```

## Governance

- Inlay hints annotate variable bindings where the reader did not write an explicit type annotation.
- The type displayed is the inferred type from `analysisTypes`.
- Hints are filtered strictly to the visible `Range` requested by the client.

## Algorithm

1. Scan all variable declaration symbols in `analysisResolution` that intersect the requested `Range`.
2. Check if the binding in source text already contains an explicit `: <Type>`.
3. If not explicit, query `analysisTypes` at the binding span to get the inferred `Type`.
4. Render an `InlayHint` at the end of the identifier span with `label: ": " <> renderType t`.

## Negative Logic (Prohibited Paths)

- Do not emit hints on bindings that already have explicit type annotations.
- Do not compute hints outside the requested view range.

## Grill Log

- **Q:** Why restrict hints to unannotated bindings? **A:** Repeating an explicit type annotation creates visual noise. Inlay hints are valuable specifically for compiler-inferred types.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
