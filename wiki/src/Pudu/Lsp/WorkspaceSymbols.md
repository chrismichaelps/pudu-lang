---
type: module
path: "@root/src/Pudu/Lsp/WorkspaceSymbols.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.35
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Workspace Symbols]
---

# LSP Workspace Symbols

## Purpose

Search and list declarations across all indexed open documents matching a user query string.

## Interface

```haskell
workspaceSymbolsAt :: Documents -> Text -> Json
```

## Governance

- Searches the `DocIndex` of every open document in `Documents`.
- Queries are case-insensitive substring matches against `docName`.
- Empty queries return all top-level symbols across known documents.

## Algorithm

1. Extract all document analyses from `Documents`.
2. For each document, filter `indexEntries` by query matching `docName`.
3. Format matches as `SymbolInformation` with name, kind, container name, and document location.

## Negative Logic (Prohibited Paths)

- No disk crawling: only documents loaded into the language server session are queried.

## Grill Log

- **Q:** Should disk files not yet opened be searched? **A:** No; `workspace/symbol` in this thin-compiler design searches open compilation graphs. Cross-project file indexing is owned by editor search.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
