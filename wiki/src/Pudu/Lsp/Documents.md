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
data Analysis = Analysis { analysisText, analysisSource, analysisDiagnostics, analysisIndex, analysisTypes, .. }
newtype Documents = Documents (Map Text Analysis)

analysisOf       :: Text -> Documents -> Maybe Analysis
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
- A document the editor closed is forgotten rather than kept, so a stale answer about a file nobody has open cannot be given.

### Linkage

- **Requires:** [[Compiler Pipeline]], [[Doc Index]], [[Source Text]].
- **Consumed by:** [[Lsp Server]].

## Referenced by

[[src/Pudu/_MOC]]
