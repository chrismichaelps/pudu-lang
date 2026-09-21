---
type: module
path: "@root/src/Pudu/Lsp/Context.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.65
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Context]
---

# LSP Context

## Purpose

Classify a completion position from the compiler's parsed module and retain the closed-sum facts
needed to turn that classification into legal candidates. This module answers what syntactic kind
of thing belongs at a cursor; it does not decide editor protocol shapes or render completion items.

## Interface

```haskell
data CompletionContext
  = PatternContext (Located Expression) [Located MatchArm] (Located MatchArm)
  | TypeContext [Text]
  | ImportContext ImportSite
  | ValueContext (Maybe (Located Expression))
  | SuppressedContext

data ImportSite
  = ImportPath Int        -- the path being written starts at this offset
  | ImportSelection Text  -- inside the selection braces of this module's import
  | ImportAlias           -- after `as`; nothing is offered

data VariantShape
  = UnitVariant
  | TupleVariant [Located TypeSyntax]
  | RecordVariant [(Text, Located TypeSyntax)]

data SumShape = SumShape
  { sumModule   :: ModuleName
  , sumTypeParams :: [Text]
  , sumVariants :: [(Text, VariantShape)]
  }

contextAt    :: [Token] -> Maybe Module -> Int -> CompletionContext
importSiteAt :: [Token] -> Int -> Maybe ImportSite
sumShapes   :: ModuleName -> [Located Declaration] -> [(Text, SumShape)]
programSums :: ProgramResult -> Map Text SumShape
```

### Governance

- **Context comes from syntax, not neighboring characters.** The traversal follows the parsed
  declaration, block, statement, expression, arm, and type nodes that contain the cursor. A match
  arm pattern retains its subject and sibling arms; a type position retains every lexically visible
  type parameter, innermost first.
- **Failure is conservative.** A cursor not proven to be in a pattern or type position is a value
  position. Missing or recovery syntax must not manufacture a stronger context.
- Comments, quoted literals, and imports are classified from the lexer's tokens, which exist for any
  text, so they are known while the document does not parse. String, character, template, and
  comment spans suppress code candidates entirely. An import site is read backwards from the cursor
  over path tokens to the `import` keyword: a path still being written (`import Std.Co`,
  `import Std.`, a path continued on the next line) is `ImportPath` with the offset the path starts
  at; a path whose last name ends before the cursor has been left; `as` starts an alias; `{` after
  a path is a selection from that module.
- Every other context needs the tree. With no tree the position is an ordinary value position.
  The tree is the compiler's tooling syntax (`compileSyntax`), which survives a later-phase error
  such as a non-exhaustive match, so a pattern context is found while an arm is being added.
- Value contexts retain the innermost expression when one exists. Calls, their arguments, record
  initializers, and ordinary expressions therefore pass through the same query boundary even when
  candidate ranking has no stronger fact than the names in lexical scope.
- **Sum facts use canonical identity.** Program sums are keyed by the same module-qualified nominal
  key used by typing. Their payload arity is completion metadata only; typing remains authoritative.
- The root syntax supplies private/local sums, while the interface graph supplies exported sums from
  visible modules. Neither completion nor this query reparses source text.
- Variant shapes retain positional or named payload type syntax and the sum's declared type
  parameters so presentation can substitute the checked subject's concrete arguments.
- Guards, wildcards, nested patterns, and alternative patterns do not change the cursor's subject type.
  [[Lsp Pattern Completion]] decides whether an earlier arm fully covers a variant from the retained
  sibling arms.

### Linkage

- **Requires:** [[Syntax Tree]], [[Compiler Program]], [[Type Interface]].
- **Consumed by:** [[Lsp Completion]], [[Lsp Documents]], [[Lsp Server]].

## Negative Logic (Prohibited Paths)

- Do not infer context from keywords, indentation, or a textual prefix when a parsed node answers.
- Do not treat an arbitrary identifier as a type parameter; only declaration-owned parameters enter
  `TypeContext`.
- Do not use source spelling as the identity of an imported sum.
- Do not claim a pattern context outside the span of the arm's pattern.
- Do not treat a finished import path followed by whitespace as an import position; the cursor has
  moved on to the next declaration.
- Do not return code candidates from comment or quoted-literal text.

## Grill Log

- **Q:** Why retain the match subject and all arms instead of only returning `PatternContext`?
  **A:** Legal variants depend on the subject's checked nominal type, and useful suggestions depend
  on what unguarded sibling arms already cover. _Rationale:_ the syntax query carries evidence while
  the completion module owns candidate policy. _Rejected:_ recomputing the enclosing match from text.
- **Q:** Why store sum shapes when the documentation index already lists types? **A:** Documentation
  entries do not preserve a sum's variants and payload arity. _Rationale:_ completion needs exact
  constructor facts without widening the public documentation model. _Rejected:_ parsing rendered
  type documentation or offering every constructor in the program.
- **Q:** What happens when parsing or typing is incomplete? **A:** The query returns the narrowest
  context it can prove, and completion falls back conservatively when its required facts are absent.
  _Rationale:_ partial editor input is routine and must not produce unrelated confident candidates.
  _Rejected:_ guessing a subject type or constructor owner from spelling.

- **Q:** Why read import sites from tokens instead of the parsed import declarations? **A:** An
  import is completed while it is incomplete, and `import Std.` never parses. The tokens are the
  lexer's own and exist for any text. _Rationale:_ the moment an import is most in need of
  completion is the moment no tree exists. _Rejected:_ matching `import ` at the start of a text
  line, which fails for tabs, comments, and paths continued on the next line.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Pattern Completion]] · [[Lsp Import Completion]] · [[Lsp Completion]] · [[Lsp Documents]] · [[Lsp Server]]
