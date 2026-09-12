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
data DocKind = DocFunction | DocTraitMethod !Text | DocMethod !Text | DocConstant | DocType | DocTrait | DocMacro | DocForeign !Text
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

- Documentation is the nearest documented token **before** a declaration, bounded below by where
  the previous declaration ended. A declaration's span starts at its `fn` or `type` keyword, not at
  the `export` in front of it, so keying on the span alone silently detaches every exported
  declaration's documentation. The bound is what stops a declaration reaching back into another
  one's comment.
- A member's bound is its enclosing declaration rather than the previous top-level one, so a
  trait's first member cannot claim the trait's own documentation.
- An implementation member with no direct documentation inherits the matching local trait member's
  documentation. A direct implementation comment always wins. The lookup uses the trait named by
  the implementation and the member name, so documentation cannot cross between unrelated traits
  that happen to use the same method name.

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
- A foreign block contributes its opaque handle declarations as types and its functions as foreign
  functions. The latter retain the library name so hover can state that their signature is asserted
  rather than proved, including at a call site.
- `entriesFor` matches declarations by unqualified name (`docName entry == name`) or fully-qualified
  module path (`docModule entry <> "." <> docName entry == name`), enabling `:doc Std.Math.factorial`
  as well as `:doc factorial`.

### Linkage

- **Requires:** [[Doc Signature]], [[Syntax Tree]], [[Source Token]], [[Type Boundary]].
- **Consumed by:** [[Compiler Pipeline]], [[Doc Search]], [[Doc Json]], [[Pudu REPL]], [[Pudu CLI]].

## Algorithm

One pass over `moduleDeclarations` collects trait-member documentation by `(trait, member)`. A
second declaration-order pass expands declarations into entries, looks up the checker's scheme,
and attaches a direct comment or the matching inherited trait comment.

## Negative Logic (Prohibited Paths)

- No type checking, no inference, and no evaluation: the index reports, it does not decide.
- No signature invented for a name the checker had none for; the entry reports no signature instead.
- No documentation attached across an intervening ordinary comment, and none attached to a
  declaration that has none, except for the explicit trait-member inheritance rule.
- No inheritance by member name alone and no inheritance over a direct implementation comment.

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
- **Q:** Should `entriesFor` support qualified module paths (`Std.Math.abs`)? **A:** Yes.
  _Rationale:_ in interactive sessions or multi-module projects, readers frequently look up
  documentation using qualified names (`:doc Std.Math.min`). Matching both unqualified and
  qualified names avoids false 'not in scope' errors while preserving unqualified lookup.
  _Rejected:_ requiring callers to strip module prefixes before querying.
- **Q:** Should every implementation repeat the documentation already owned by its trait member?
  **A:** No. _Rationale:_ repetition drifts and makes comprehensive standard-library documentation
  expensive to maintain. The implementation already names its trait, so `(trait, member)` is a
  precise fallback key. _Rejected:_ copying comments into every implementation; inheriting by
  member name alone; replacing a direct implementation-specific comment.

Resolved Grill Log: trait documentation is inherited only through the implementation's explicit
trait identity, while direct implementation documentation remains authoritative.

## Referenced by

[[src/Pudu/Doc/_MOC]] · [[Compiler Pipeline]] · [[Doc Search]]
