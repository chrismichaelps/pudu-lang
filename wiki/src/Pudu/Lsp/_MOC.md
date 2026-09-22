---
type: moc
tags: [moc, tooling, lsp]
---

# Language Server Map

- [[Language Server]] — answers an editor's questions from the ordinary compile.
- [[Lsp Analysis]] — one document compiled under the source root its path and module give it.
- [[Lsp Repair Cache]] — repaired analyses reused while the documents' state holds.
- [[Lsp Scheduler]] — reading apart from working, so cancellations and newer edits are seen at once.
- [[Lsp Protocol]] — byte framing and the shapes the wire carries.
- [[Lsp Feature]] — the index turned into hovers, definitions, outlines, and completions.
- [[Lsp Hover]] — cursor policy that preserves inferred types and foreign trust provenance.
- [[Lsp Definition]] — the declaration a name names, in this document or the module exporting it.
- [[Lsp Imported Name]] — the export a name at a cursor reaches through an import.
- [[Lsp References]] — find all usages of a declaration across the document.
- [[Lsp Rename]] — prepare and execute rename edits across declaration and uses.
- [[Lsp Highlight]] — semantic highlighting for occurrences of the active symbol.
- [[Lsp Semantic Tokens]] — delta-encoded full syntax tokens for rich coloring.
- [[Lsp Signature Help]] — parameter tracking and active signatures in calls.
- [[Lsp Inlay Hints]] — inferred type annotations displayed inline for let bindings.
- [[Lsp Workspace Symbols]] — symbol search across all indexed open documents.
- [[Lsp Code Action]] — context-sensitive quick fixes and formatting actions.
- [[Lsp Completion]] — member method, symbol, keyword, and primitive type completions.
- [[Lsp Context]] — syntax- and token-directed completion positions.
- [[Lsp Receiver]] — the member access being completed and its whole receiver's type.
- [[Lsp Shapes]] — declared sum and record shapes by canonical identity, with generic substitution.
- [[Lsp Import Completion]] — whole module paths offered while an import is written.
- [[Lsp Module Catalog]] — every module an import could reach, found once per source root.
- [[Lsp Pattern Completion]] — typed sum candidates, conservative coverage, and payload details.
- [[Lsp Json]] — reading and writing the protocol's JSON.

## Referenced by

[[src/Pudu/_MOC]] · [[Tooling]]
