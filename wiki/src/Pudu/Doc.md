---
type: module
path: "@root/src/Pudu/Doc.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
coupling: 4.0
interface_stability: 0.7
tags: [module, medium]
aliases: [Doc Index]
---

# Doc Index

## Purpose

Describe every name a module declares: what it is, what type the compiler gave it, what the
reader documented about it, and where to find it.

## Interface

### Signatures

```haskell
data DocKind = DocFunction | DocTraitMethod !Text | DocMethod !Text | DocConstant | DocType | DocTrait | DocMacro
data DocEntry = DocEntry { docName, docModule :: !Text, docKind :: !DocKind
                         , docSignature :: !(Maybe Signature), docComment :: ![Text]
                         , docSpan :: !(Int, Int) }
newtype DocIndex = DocIndex { indexEntries :: [DocEntry] }
buildIndex :: [Token] -> ModuleTypes -> Module -> DocIndex
entriesFor :: Text -> DocIndex -> [DocEntry]
renderEntry :: DocEntry -> Text
renderEntryLines :: DocEntry -> [Text]
renderEntryLinesWith :: Bool -> DocEntry -> [Text]
```

### Governance

- **A signature is never reconstructed from written syntax.** It comes from the scheme the checker
  ended with, so a declaration with no annotations is still described, and one with annotations is
  described as the compiler understood it rather than as it was spelled. This is the module's
  central rule and the reason `ModuleTypes` exists.
- Three sources meet here and each answers only what it is authoritative for: the module says what
  was declared and where, the checker says what type it has, the token stream says what was
  documented.
- Documentation is produced for a module that failed to check. A broken module is when a reader
  most wants to see what it declares, and the entries that did check are still true.
- A member is found under the checker's own key — a trait's member under its owning nominal type,
  a method under the type it is implemented for — by trying candidates in order of specificity.
  The plain name is tried last, so a module with both a free `label` and a `Label.label` never
  describes one as the other.
- An implementation's methods are reported against the type they implement, not against `Self`.
  A trait's own members keep `Self`, where it is the point.

### Linkage

- **Requires:** [[Doc Signature]], [[Syntax Tree]], [[Source Token]], [[Type Boundary]].
- **Consumed by:** [[Compiler Pipeline]], [[Doc Search]], [[Doc Json]], [[Pudu REPL]], [[Program Cli]].

## Algorithm

One pass over `moduleDeclarations`, expanding traits and implementations into their members;
a lookup per entry into the checker's scheme table; a lookup per entry into a map of doc comments
keyed by the offset of the token they lead.

## Negative Logic (Prohibited Paths)

- No type checking, no inference, and no evaluation: the index reports, it does not decide.
- No signature invented for a name the checker had none for; the entry reports no signature instead.
- No documentation attached across an intervening ordinary comment, and none attached to a
  declaration that has none.

## Edge Cases

- A `////` ruler is an ordinary comment, not documentation: a row of slashes is a visual separator.
- A name declared more than once produces one entry per declaration, because the ambiguity is what
  a reader asking about it needs to see.
- The synthetic wrapper the REPL compiles is a declaration like any other and appears in the index;
  callers that show the index to a reader filter it.

## Depth

DEPTH 0.60 (MEDIUM). It joins three producers without owning any of their logic.

## Grill Log

- **Q:** Should documentation be a field on each declaration in the syntax tree? **A:** No.
  _Rationale:_ documentation is not syntax. Every declaration form would grow a field it does not
  use, every parser would have to fill it, and the information is already preserved losslessly in
  the lexer's trivia. _Rejected:_ a `docComment` field on `Function`, `Trait`, and the rest.
- **Q:** Should the index be built from the written annotations, so it works without type checking?
  **A:** No. _Rationale:_ then an unannotated declaration would have no documented type at all, and
  an annotated one could be described differently from how the compiler understands it — which is
  the exact failure a documentation tool exists to prevent. _Rejected:_ a syntax-only index; a
  hybrid that prefers annotations and falls back to inference, which would make the answer depend
  on whether the author happened to write a type.
- **Q:** Should a failed module produce no index? **A:** No. _Rationale:_ it inverts the need — a
  reader consults documentation most when the code is not working. _Rejected:_ gating on
  `hasErrors`.

## Referenced by

[[src/Pudu/Doc/_MOC]] · [[Compiler Pipeline]] · [[Doc Search]]
