---
type: module
path: "@root/src/Pudu/Lsp/Rename.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Rename]
---

# LSP Rename

## Purpose

Validate whether an identifier under the cursor can be renamed and compute atomic workspace edits to update its declaration and all references.

## Interface

```haskell
prepareRenameAt :: Analysis -> Int -> Json
renameAt :: Text -> Analysis -> Int -> Text -> Json
```

## Governance

- A symbol can only be renamed if it has an explicit source span and is not a built-in symbol, foreign symbol, or reserved keyword.
- `prepareRenameAt` provides the client with the precise range and existing name placeholder before triggering the user rename input.
- `renameAt` produces a standard `WorkspaceEdit` carrying a replacement edit for the declaration span and every matching reference span.

## Algorithm

1. `prepareRenameAt`: Check `symbolAt`. If the symbol has a source span, return `{ range, placeholder: name }`; otherwise return `JsonNull`.
2. `renameAt`: Collect the defining span and all reference spans for the target `symbolId`. Generate `TextEdit` replacements containing `newText` for each unique span under `changes[uri]`.

## Negative Logic (Prohibited Paths)

- No partial renames: the edit must atomically include all references and definition.
- No renaming built-in primitives or un-spanned compiler symbols.

## Grill Log

- **Q:** Should renaming fail if the new name is not a valid Pudu identifier? **A:** The client provides validation, but the server renames the exact AST spans; compiler re-check immediately validates the resulting program on the subsequent change notification.
- **Q:** What if the cursor is on a use site rather than the declaration? **A:** `symbolAt` resolves reference sites to the underlying `SymbolId`, renaming both the declaration and all peer references identically.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
