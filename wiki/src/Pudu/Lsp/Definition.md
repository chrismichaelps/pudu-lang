---
type: module
path: "@root/src/Pudu/Lsp/Definition.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Definition]
---

# LSP Definition

## Purpose

Map the name under an editor cursor to the declaration it names, in this document or in the module
that exports it.

## Interface

```haskell
definitionAt     :: Text -> Analysis -> Int -> Json
definitionAcross :: (FilePath -> IO (Maybe Text)) -> Text -> Analysis -> Int -> IO Json
fileUri          :: FilePath -> Text
```

## Governance

- Definition lookup uses the resolver's symbol identity at the cursor; equal spelling is never
  identity.
- A name another module exports, reached through an import ([[Lsp Imported Name]]), is defined where
  that module declares it: the export's span names its file, and the range is computed against that
  file's text — the editor's copy when it is open, since offsets become positions only against the
  text they were taken from. A selected name is defined at its export, not at the import that
  brought it in, which only repeats it.
- The cursor on an import's path opens the module's file: one of the files the program read, found
  by the path the module name spells beneath its source root.
- A file URI percent-encodes every byte outside the unreserved set and `/`.
- Missing words and declarations answer null; no location is guessed.

## Algorithm

When the name reaches an export, read its module's text and answer its span there; when the cursor
is on an import path, answer the start of that module's file; otherwise find the resolved
declaration or reference at the cursor and answer its span in this document.

## Negative Logic (Prohibited Paths)

- No filesystem search: only a file the program read, or the one an export's span names.
- No cross-document guessing by spelling.

## Grill Log

- **Q:** Search files when the index has no match? **A:** No. _Rationale:_ the loaded compiler graph
  is authoritative; guessing by text can jump to a different declaration. _Rejected:_ workspace
  text search fallback.
- **Q:** Pick the first declaration sharing the cursor word? **A:** No. _Rationale:_ lexical
  shadowing gives equal text different identities. _Rejected:_ text-only definition lookup.
- **Q:** Keep definition pure, as it was? **A:** Only within the document. _Rationale:_ a position in
  another file needs that file's text, and the analysis keeps offsets, not its dependencies' texts;
  reading the one file asked for costs less than holding every dependency's text for every
  document. _Rejected:_ storing dependency texts in each analysis.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
