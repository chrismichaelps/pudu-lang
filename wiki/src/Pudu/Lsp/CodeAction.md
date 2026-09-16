---
type: module
path: "@root/src/Pudu/Lsp/CodeAction.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.35
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Code Action]
---

# LSP Code Action

## Purpose

Provide context-sensitive code actions and quick fixes for the editor cursor range.

## Interface

```haskell
codeActionsAt :: Text -> Analysis -> Range -> Json -> Json
```

## Governance

- Offers "Format document with pudu fmt" whenever the document is not already formatted according to the compiler's canonical formatter.
- Quick fixes for compiler diagnostics are offered when actionable guidance exists.

## Algorithm

1. Inspect active document text and format using `formatSource`.
2. If formatted output differs from raw text, produce a document-wide formatting `CodeAction`.
3. Return `JsonArray` containing available actions.

## Negative Logic (Prohibited Paths)

- No heuristic transformations that alter program semantics.

## Grill Log

- **Q:** Why offer formatting as a code action? **A:** Users often trigger formatting via the Quick Fix lightbulb or quick action menu in addition to explicit format commands.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
