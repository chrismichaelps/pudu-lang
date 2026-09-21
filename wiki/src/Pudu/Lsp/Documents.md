---
type: module
path: "@root/src/Pudu/Lsp/Documents.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 2.0
interface_stability: 0.9
tags: [module, shallow]
aliases: [Lsp Documents]
---

# Lsp Documents

## Purpose

What the server knows about each open document: one compile's answers, kept by the URI the editor named them with.

## Interface

```haskell
data Analysis = Analysis { analysisText, analysisSource, analysisDiagnostics, analysisFileIndex, analysisProgramIndex, analysisTypes, analysisTokens, analysisModule, analysisSums, analysisRecords, analysisMethods, analysisExports, .. }
data Documents = Documents { docWorkspaceRoot :: !(Maybe FilePath), docMap :: !(Map Text Analysis) }

emptyDocuments   :: Documents
setWorkspaceFolders :: [FilePath] -> Documents -> Documents
workspaceFolders    :: Documents -> [FilePath]
analysisOf       :: Text -> Documents -> Maybe Analysis
allDocuments     :: Documents -> [(Text, Analysis)]
rememberAnalysis :: Text -> Analysis -> Documents -> Documents
forgetDocument   :: Text -> Documents -> Documents
documentOf       :: Documents -> Json -> Maybe Analysis
uriOf            :: Json -> Maybe Text
```

### Governance

- **The store is a value the loop threads, not a mutable cell.** What a reply says and what the server holds therefore cannot disagree part-way through answering a request.
- One `Analysis` is everything one compile said about one file — its text, source, diagnostics,
  documentation index, resolved symbol identities, and what the checker made of each expression by
  span. Hover and definition use resolution to distinguish a foreign declaration from a local or
  parameter with the same spelling.
- The ordinary lexer tokens, tooling tree of the root module, and the program's canonical sum and record shapes ([[Lsp Shapes]]) stay beside those
  semantic products. Syntax-directed features can therefore identify the cursor's construct and
  combine it with the same compile's checked type without reparsing or consulting stale global data.
- **Two documentation indexes, because a span belongs to one file.** `analysisFileIndex` holds this
  document's declarations and is what anything starting from a cursor must ask — hover, the outline,
  token classification — since an offset compared against another module's spans matches a
  declaration the reader is nowhere near. `analysisProgramIndex` holds every module's and answers
  questions keyed by name, where an imported function counts as much as a local one: completion and
  signature help.
- A document the editor closed is forgotten rather than kept, so a stale answer about a file nobody has open cannot be given.

### Linkage

- **Requires:** [[Compiler Pipeline]], [[Doc Index]], [[Source Text]], [[Lsp Context]].
- **Consumed by:** [[Lsp Server]].

## Referenced by

[[src/Pudu/_MOC]]
