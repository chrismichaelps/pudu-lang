---
type: module
path: "@root/src/Pudu/Lsp/ImportedName.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.35
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Imported Name]
---

# LSP Imported Name

## Purpose

Say which declaration another module exports the name at a cursor reaches through an import, so
definition and hover can answer from where that module declared it.

## Interface

```haskell
importedNameAt :: Analysis -> Int -> Maybe ExportedName
importedEntry  :: Analysis -> ExportedName -> Maybe DocEntry
```

### Governance

- `Q.name` reaches `name` in the module an import binds `Q` to — the last segment of its path or its
  alias — read from the parsed imports ([[Lsp Import Completion]] `importQualifiers`). A qualifier
  itself reached through a dot (`a.Q.name`) is not one.
- A bare name reaches an export when an import selects it and nothing nearer shadows it: the
  resolver's symbol at the cursor, when there is one, must be the import's.
- Of an export and a type of the same name, a capitalised use prefers neither; a lowercase one
  prefers the value.
- `importedEntry` joins by module and name together, never by basename alone, and never answers
  with a method.

### Linkage

- **Requires:** [[Lsp Documents]], [[Lsp Feature]], [[Lsp Import Completion]].
- **Consumed by:** [[Lsp Definition]], [[Lsp Hover]].

## Negative Logic (Prohibited Paths)

- Do not answer a local, parameter, or declaration of this module that shares a name with an
  import.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Definition]] · [[Lsp Hover]]
