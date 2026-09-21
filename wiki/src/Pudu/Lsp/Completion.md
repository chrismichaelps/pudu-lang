---
type: module
path: "@root/src/Pudu/Lsp/Completion.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Completion]
---

# LSP Completion

## Purpose

Provide completions that depend on where the cursor is. A match pattern offers constructors of the
checked subject type, a type position offers type parameters and visible types, and `value.` offers
the fields or methods of the value. Ordinary value positions retain bindings in scope, declarations,
imports, the everyday prelude, keywords, and built-in types. `completionRepaired` answers from a
[[Lsp Repair|repaired copy]] when the written text has no types.

## Interface

```haskell
completionAt       :: Documents -> Json -> Json
completionRepaired :: (Text -> IO Analysis) -> IO [Text] -> Documents -> Json -> IO Json
```

`completionRepaired` takes the compile used for repairs and the module catalog for the document's
source root; the catalog is run only when the cursor is at an import site.

## Governance

- After a dot, completion offers the methods the receiver value carries based on its inferred type and implemented trait blocks.
- In a match pattern, completion offers only constructors belonging to the checked subject's sum,
  excluding variants already covered by an unguarded irrefutable sibling arm, plus `_`.
- In a type position, completion offers lexical type parameters, visible types, usable module
  qualifiers, and built-in primitive types.
- In an import position, completion offers whole module paths from [[Lsp Import Completion]]: the
  server's on-disk catalog plus the modules the program already reached. Inside comments and quoted
  literals, completion returns no unrelated code candidates.
- The context is computed once per request from the written document and dispatched on; an import
  site is answered before any repair is attempted, because no repair makes an import path parse.
- In other positions without a preceding dot, completion offers documented symbols, language keywords, and built-in primitive types.
- Completion responses are pure functions of the stored compiler analysis.

## Algorithm

1. Locate cursor position and ask the syntax/token context query first. Pattern, import, comment, and
   quoted-literal contexts take precedence over a textual dot inside them.
2. Otherwise, if after a dot: determine receiver expression end offset, query `analysisTypes` for the receiver's type, and collect built-in and `impl` methods for that nominal type.
3. If syntax proves a match-pattern position, use the checked subject type and canonical visible-sum
   facts to produce variants spelled according to the root module's imports.
4. If syntax proves a type position, produce scoped type parameters and visible type names.
5. If tokens prove an import site, offer module paths with an edit replacing the written path; if tokens prove comment or quoted-literal
   text, return no code candidates.
6. Otherwise return documented symbols from `analysisProgramIndex` merged with language keywords and primitive types.

## Negative Logic (Prohibited Paths)

- Do not suggest member methods when the cursor is not following a dot accessor.
- Do not guess member names when the receiver type is unknown or untyped.
- Do not offer constructors from unrelated sums or suppress a constructor because a guarded or
  refutable pattern mentioned it.
- Do not offer ordinary value keywords in a proven pattern or type position.

## Grill Log

- **Q:** Why include keywords and primitive types in completions? **A:** Editor completion lists without language keywords feel incomplete and force users to type keywords manually.
- **Q:** Why does pattern completion depend on checked types rather than constructor spelling?
  **A:** Different sums may use the same variant name, imports may qualify it, and generic subjects
  preserve their nominal owner. _Rationale:_ the type checker already resolved the exact subject;
  using that identity prevents unrelated variants from leaking into the list. _Rejected:_ searching
  every documented name for constructor-shaped entries.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]] · [[Lsp Import Completion]]
