---
type: module
path: "@root/src/Pudu/Lsp/Completion.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Completion]
---

# LSP Completion

## Purpose

Provide code completion items for member methods following dot access, as well as in-scope declarations, primitive types, and keywords in general positions.

## Interface

```haskell
completionAt :: Documents -> Json -> Json
```

## Governance

- After a dot, completion offers the methods the receiver value carries based on its inferred type and implemented trait blocks.
- In general positions without a preceding dot, completion offers documented symbols, language keywords, and built-in primitive types.
- Completion responses are pure functions of the stored compiler analysis.

## Algorithm

1. Locate cursor position and check if it follows a dot delimiter on a receiver expression.
2. If after a dot: determine receiver expression end offset, query `analysisTypes` for the receiver's type, and collect built-in and `impl` methods for that nominal type.
3. If not after a dot: return documented symbols from `analysisProgramIndex` merged with language keywords and primitive types.

## Negative Logic (Prohibited Paths)

- Do not suggest member methods when the cursor is not following a dot accessor.
- Do not guess member names when the receiver type is unknown or untyped.

## Grill Log

- **Q:** Why include keywords and primitive types in completions? **A:** Editor completion lists without language keywords feel incomplete and force users to type keywords manually.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
