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

- After a dot, completion offers the receiver's fields, then the methods it carries. Fields come
  from [[Lsp Shapes]] by the receiver type's canonical identity, with its type arguments
  substituted into each field's declared type; a `mut` field's detail says `mut`. References are
  unwrapped and aliases arrive expanded by the checker.
- Methods come from the methods the program's modules declared (`analysisMethods`), by the owner the
  checker looks a call up under: a nominal type's methods including inherited trait defaults, a
  `dynamic` trait's members, an applied type's head, and for a type parameter the members of the
  traits its bounds and `where` clauses name. A bound's trait is found by how this module can write
  it: its own trait, a selectively imported one, or through an import's qualifier. A wired-in type
  also has the methods its runtime provides. Details are the checker's schemes; a method two traits
  provide is offered once.
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
- Bindings in scope come from resolution's [[Scope Index]] at the cursor: a `let` in an ended
  block, another arm's pattern names, and a closure's parameters outside it are absent, and an inner
  shadow is offered instead of the outer binding. They are read from the written text whenever it
  resolved — it does while the name being typed is unknown — and from a repaired copy only when it
  did not parse. Type details come from the repaired copy only before the offset where the two
  texts agree.
- Module qualifiers come from the parsed imports (`importQualifiers`): `import M` binds the last
  segment of `M` (`moduleQualifier`, the rule resolution and evaluation use), `import M as N` binds
  only `N`, and `import M { a }` binds no qualifier, only its items. Whitespace, comments, and line
  breaks inside an import are the parser's business. The written text's tree is asked first; while
  it does not parse, the repaired copy's, whose imports are the same. `Lib.Tools.` is a path, never
  a qualifier.
- A name a selective import brought in is described by the module it was selected from, whatever
  other module declares the same name and whatever the import order.
- Completion responses are pure functions of the stored compiler analysis.

## Algorithm

1. Locate cursor position and ask the syntax/token context query first. Pattern, import, comment, and
   quoted-literal contexts take precedence over a textual dot inside them.
2. Otherwise, if [[Lsp Receiver]] finds a member site: a receiver that is one name an import binds
   offers that module's exports; any other receiver offers the fields and methods of the type the
   checker gave the whole receiver expression.
3. If syntax proves a match-pattern position, use the checked subject type and canonical visible-sum
   facts to produce variants spelled according to the root module's imports.
4. If syntax proves a type position, produce scoped type parameters and visible type names.
5. If tokens prove an import site, offer module paths with an edit replacing the written path; if tokens prove comment or quoted-literal
   text, return no code candidates.
6. Otherwise return documented symbols from `analysisProgramIndex` merged with language keywords and primitive types.

## Negative Logic (Prohibited Paths)

- Do not suggest member methods when the cursor is not following a dot accessor.
- Do not guess member names when the receiver type is unknown or untyped.
- Do not find the receiver from the character before the dot or type it by a point query.
- Do not select local bindings by declaration offset; visibility is resolution's frames.
- Do not find a record's fields by the type's basename or by slicing its declaration's text.
- Do not read imports from text lines, and do not treat a full module path or a selective import as
  a qualifier.
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
