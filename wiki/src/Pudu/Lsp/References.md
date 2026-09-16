---
type: module
path: "@root/src/Pudu/Lsp/References.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp References]
---

# LSP References

## Purpose

Locate all references to the declaration or binding under an editor cursor across the document.

## Interface

```haskell
referencesAt :: Text -> Analysis -> Int -> Bool -> Json
```

## Governance

- References are resolved purely through compiler semantic symbol identities (`SymbolId`), not text matching.
- When `includeDeclaration` is true, the symbol's defining span is prepended to the reference list.
- Missing symbols or foreign builtins without spans yield an empty JSON array, never guessing by text.

## Algorithm

Find the resolved declaration or reference at the cursor scalar offset via `symbolAt`. Match against all `resolutionReferences` whose `referenceSymbol` matches the identified `symbolId`. Deduplicate and convert each span into an LSP `Location` object `{ uri, range }`.

## Negative Logic (Prohibited Paths)

- No raw substring matching or regex search.
- No cross-document guessing without a verified resolution index.

## Grill Log

- **Q:** Should unresolved identifiers fallback to text search across the document? **A:** No. _Rationale:_ text matching confuses shadowed bindings and identically named methods across different types. _Rejected:_ text-based reference fallback.
- **Q:** How is `includeDeclaration` handled? **A:** By inspecting the parameter flag from the client's `context.includeDeclaration` and conditionally including the declaration span. _Rationale:_ standard LSP editors allow toggling definition inclusion in reference searches.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
