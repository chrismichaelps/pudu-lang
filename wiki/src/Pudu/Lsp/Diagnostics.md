---
type: module
path: "@root/src/Pudu/Lsp/Diagnostics.hs"
fidelity: Active
domain: "[[Diagnostic Model]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Diagnostics]
---

# LSP Diagnostics

## Purpose

Turn one program compile's diagnostics into what an editor publishes for one open document: each
finding at a range in that document's text, with its help and notes intact.

## Interface

```haskell
data Elsewhere
elsewhereFor       :: Source -> ProgramResult -> IO Elsewhere
ownDiagnostics     :: Source -> [Diagnostic] -> [Diagnostic]
diagnosticEntries  :: Text -> Source -> Elsewhere -> [Diagnostic] -> [Json]
```

## Governance

- A program compile reports every module's findings. An offset means something only in the file it
  was taken from, so a finding is placed by the file its span names, never by its offsets alone.
- A finding in this document is published at its own range.
- A generated span whose request is in this document, and whose derive is written in another file,
  is published at the request: that is the text the reader wrote. The derive's own location travels
  as related information.
- An error in another module the document reaches through an import is published at that import,
  as `Module: message`, with the error's own location as related information. The first import whose
  module reaches the file, directly or through its own imports, carries it. A warning or note in
  another module is that module's to publish when it is open, and is dropped here.
- An error no import reaches is published at the start of the document rather than lost.
- Help is a line of its own beginning `help:`. An editor that folds a message onto one line then
  reads `… only help: move …`, never two sentences run together.
- Every note becomes related information at its own file and range. A note whose file the analysis
  holds no text for is kept in the message instead, since a position needs that file's text.
- `Elsewhere` keeps the URI and text of each other file a finding or note names, and which import
  reaches each module's file. It holds nothing for files no finding names, so a clean program keeps
  no dependency text.
- `ownDiagnostics` are the findings located in this document, the only ones whose offsets may be
  compared with a cursor.

## Algorithm

`elsewhereFor` collects the file names every finding and note mentions, keeps the URI and text of
each one besides the document, and maps each module's file to the first of the document's imports
whose module reaches it through the program's import graph. `diagnosticEntries` places each finding
by the rules above and renders range, severity, code, source, message, and related information.

## Negative Logic (Prohibited Paths)

- No finding is placed by offsets taken from another file.
- No dependency text is read from disk at publish time; publishing stays pure.
- No other module's warning is published on this document.

## Linkage

- **Requires:** [[Diagnostic Model]], [[Compiler Program]], [[Lsp Protocol]], [[Lsp Feature]].
- **Consumed by:** [[Lsp Analysis]], [[Lsp Documents]], [[Lsp Server]], [[Lsp Repair]].

## Grill Log

- **Q:** Publish another module's error on its own file's URI? **A:** No. _Rationale:_ an editor
  replaces a URI's diagnostics on every publish, so two documents publishing for one file would
  erase each other's findings; the import is where the reader can act. _Rejected:_ cross-URI
  publishing.
- **Q:** Keep every dependency's text in each analysis to resolve notes? **A:** Only the files a
  finding names. _Rationale:_ positions need the file's text, and a clean program names none.
  _Rejected:_ retaining all program sources per document.
- **Q:** Join help to the message with a blank line, as before? **A:** No. _Rationale:_ list views
  fold line breaks into spaces, which ran the message and help together as one sentence.
  _Rejected:_ unlabelled help.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
