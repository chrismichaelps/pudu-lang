---
type: moc
tags: [moc, tooling, lsp]
---

# Language Server Map

- [[Language Server]] — answers an editor's questions from the ordinary compile.
- [[Lsp Protocol]] — byte framing and the shapes the wire carries.
- [[Lsp Feature]] — the index turned into hovers, definitions, outlines, and completions.
- [[Lsp Hover]] — cursor policy that preserves inferred types and foreign trust provenance.
- [[Lsp Definition]] — indexed declaration navigation for the name under the cursor.
- [[Lsp References]] — find all usages of a declaration across the document.
- [[Lsp Rename]] — prepare and execute rename edits across declaration and uses.
- [[Lsp Highlight]] — semantic highlighting for occurrences of the active symbol.
- [[Lsp Semantic Tokens]] — delta-encoded full syntax tokens for rich coloring.
- [[Lsp Signature Help]] — parameter tracking and active signatures in calls.
- [[Lsp Inlay Hints]] — inferred type annotations displayed inline for let bindings.
- [[Lsp Workspace Symbols]] — symbol search across all indexed open documents.
- [[Lsp Code Action]] — context-sensitive quick fixes and formatting actions.
- [[Lsp Completion]] — member method, symbol, keyword, and primitive type completions.
- [[Lsp Json]] — reading and writing the protocol's JSON.

## Referenced by

[[src/Pudu/_MOC]] · [[Tooling]]
