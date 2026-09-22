---
type: module
path: "@root/src/Pudu/Lsp/ImportCompletion.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Import Completion]
---

# LSP Import Completion

## Purpose

Turn an [[Lsp Context]] import site into completion items: whole module paths while a path is being
written, nothing after `as`.

## Interface

```haskell
importCompletions :: [Text] -> Analysis -> Analysis -> Int -> ImportSite -> [Json]
exportCandidates  :: Analysis -> ModuleName -> [Json]
moduleMembers     :: Analysis -> Analysis -> Int -> [Json]
importQualifiers  :: Analysis -> Analysis -> [(Text, ModuleName)]
```

## Governance

- A path is offered whole (`Std.Collections`) with a `textEdit` replacing everything from the start
  of the written path to the cursor, so choosing it after `import Std.Co` never doubles the prefix.
  `filterText` is the path, so a client filters on the dotted text the reader typed. `sortText`
  ranks a path the typed text begins first, then one with a segment the last typed segment begins
  (`Cur` for `Std.Bytes.Cursor`), then the rest, so a client that only sorts still shows the likely
  module first.
- Candidates are the catalog the server found for the document's source root
  ([[Lsp Module Catalog]]) and the modules the program already reached, each once, sorted.
- The document's own module is never offered. When the document does not parse, its name is read
  from the `module` header tokens.
- **A module's candidates are its exports.** `exportCandidates` lists exactly what the program's
  export index says the module exports — functions, constants, types, traits, a sum's variants,
  foreign types and functions — and nothing private. Each is presented with the documentation of
  that declaration in that module, joined by module and name together, never by the first entry
  with a matching basename. A variant is described as its type's (`State.Ready`).
- The same candidates answer `Q.` for a qualifier an import binds (`moduleMembers`, through
  `importQualifiers`) and a selection being written (`import M { … }`). While a selection is being
  written the document does not parse, so [[Lsp Completion]] answers it from a two-line program
  that imports `M`. A name the selection already holds is not offered again.
- After a finished path on its line only `as` is offered; nothing else can follow there.
- An alias offers nothing; it is a new name.

### Linkage

- **Requires:** [[Lsp Context]], [[Lsp Documents]], [[Lsp Feature]], [[Lsp Protocol]], [[Token]].
- **Consumed by:** [[Lsp Completion]].

## Negative Logic (Prohibited Paths)

- Do not insert only the last segment; the edit range and the label must agree.
- Do not offer a module that neither the catalog nor the program knows.
- Do not list a module's documentation entries as its members; documentation includes private
  declarations and omits variants.

## Grill Log

- **Q:** Why replace the whole written path instead of completing one segment at a time? **A:**
  Clients differ in what they treat as a word, and `.` ends a word in most. _Rationale:_ an explicit
  edit range gives the same result in every client. _Rejected:_ segment-by-segment items with no
  range, which some clients insert after the dot and others over the whole path.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Completion]] · [[Lsp Context]]
