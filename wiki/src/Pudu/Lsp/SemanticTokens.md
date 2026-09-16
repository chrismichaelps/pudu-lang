---
type: module
path: "@root/src/Pudu/Lsp/SemanticTokens.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Semantic Tokens]
---

# LSP Semantic Tokens

## Purpose

Emit delta-encoded semantic tokens for syntax highlighting derived directly from the compiler's lexer, symbol table, and declaration index.

## Interface

```haskell
semanticTokensLegend :: Json
semanticTokensFull   :: Analysis -> Json
```

## Governance

- Semantic tokens follow the LSP 3.16+ delta-encoding standard (5 integers per token: `[deltaLine, deltaStartChar, length, tokenType, tokenModifiers]`).
- The token legend defines canonical token types: `type`, `class`, `function`, `method`, `variable`, `parameter`, `property`, `keyword`, `comment`, `string`, `number`, `operator`.
- Token classifications are determined by combining lexer token tags, doc index entries, and resolver symbol visibility/sorts.

## Algorithm

1. Scan all lexical tokens and comments from the document source.
2. For identifier tokens, cross-reference with `analysisFileIndex` and `analysisResolution` to classify as type, trait, function, method, parameter, or variable.
3. Sort tokens monotonically by start position.
4. Delta-encode the line and column offsets relative to the preceding token and output the integer array `{ data: [...] }`.

## Negative Logic (Prohibited Paths)

- No unsorted tokens: LSP clients require strictly ordered tokens.
- No negative deltas: tokens must never overlap with prior token starts.

## Grill Log

- **Q:** Why delta-encode on the server rather than sending absolute positions? **A:** The LSP specification strictly mandates relative 5-tuple delta encoding for `textDocument/semanticTokens/full`.
- **Q:** What happens if a token is not in the symbol index? **A:** It falls back to its lexical classification (e.g. identifier, keyword, literal).

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
