---
type: module
path: "@root/src/Pudu/Lsp/Highlight.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.35
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Highlight]
---

# LSP Highlight

## Purpose

Provide in-editor document highlight ranges for the symbol currently under the cursor.

## Interface

```haskell
documentHighlightAt :: Analysis -> Int -> Json
```

## Governance

- All occurrences of the resolved symbol (declaration and references) in the active document are highlighted.
- Highlight kinds follow LSP specification (1 = Text, 2 = Read, 3 = Write). The declaration is marked Write/Text, and references are marked Read.
- Missing symbols answer an empty array without guessing.

## Algorithm

Find the symbol at the given offset. Collect its declaration span and all reference spans matching `symbolId`. Map each span to a `DocumentHighlight` record with its range and kind.

## Negative Logic (Prohibited Paths)

- No text-based highlighting across unrelated symbols that happen to share an identifier string.

## Grill Log

- **Q:** Why provide document highlights when editors have word highlighting? **A:** Editor word highlighting is lexical and colors words in comments or shadowed scopes incorrectly. Document highlight uses semantic resolution.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
