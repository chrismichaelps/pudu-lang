---
type: module
path: "@root/src/Pudu/Frontend/Expand/Substitute.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.85
tags: [module, medium, frontend, macro]
aliases: [Macro Substitution]
---

# Macro Substitution

## Purpose

Perform hygienic parameter substitution, identifier renaming, and span retagging over AST expressions and patterns during macro expansion.

## Interface

```haskell
hygienicName :: Text -> Int -> Text
patternNames :: Located Pattern -> [Text]
substituteExpression
  :: Map Text (Located Expression)
  -> Int
  -> Map Text Text
  -> Span
  -> Located Expression
  -> Located Expression
retag :: Span -> Located Expression -> Located Expression
renamePattern :: Span -> Map Text Text -> Located Pattern -> Located Pattern
```

## Governance

- **Hygiene is enforced by scope:** Every binding the macro body introduces is renamed with a unique `%<id>` suffix that no source text can spell.
- **Lexical scope boundaries:** Block declarations extend the rename environment only for subsequent statements and results in that block. Pattern bindings in `if let` and `while let` extend renames only for the successful branch/body, never leaking into subjects or else branches.
- **Span retagging:** Replaced expressions and syntax nodes are retagged with the call's span so diagnostics point to the invocation site rather than the macro definition.
- **Record shorthand:** Record pattern shorthand preserves the field selector while generating an explicit nested binding when its local name is renamed for hygiene.
- **Lambda scope:** Introduced value parameters receive hygienic names. Each
  default is substituted with only earlier parameters in scope; the body sees
  all parameters. A parameter masks a same-named macro argument after its
  default. Inserted caller arguments retain their authored syntax and spans,
  and are never renamed through the lambda's local environment. Lambda type
  parameters, annotations and `where` clauses are retained.
- **Body cache identity:** A substituted lambda's function-body span records its
  authored definition anchor, invocation anchor and expansion identifier using
  `generatedSpan`. Nested bodies at the same invocation remain distinct in the
  compiled evaluator's Span-keyed cache. Caller expressions keep their existing
  body identity. Child expression diagnostics retain the invocation span.

## Linkage

- **Requires:** `Pudu.Frontend.Syntax.Located`, `Pudu.Frontend.Syntax.Tree`, `Pudu.Source`.
- **Consumed by:** `Pudu.Frontend.Expand`.

## Negative Logic (Prohibited Paths)

- No macro registry lookup, kind checking, or depth counting; those belong to `Pudu.Frontend.Expand`.
- No free variable capture or unhygienic renaming.

## Grill Log

- **Q:** Can every generated lambda body use the invocation span as its key?
  **A:** No; retain the body definition span plus generated invocation identity.
  _Rationale:_ nested bodies otherwise select each other's compiled code and
  can recurse until E7002; separate invocations may bind different parameters.
  _Rejected:_ disabling compiled caching, structural syntax comparisons on each
  call, or inventing source offsets.
- **Q:** How does substitution cross a lambda binder? **A:** Thread argument
  bindings and renames together through parameters, processing the default
  before adding its binder, then substitute the body with that scope.
  _Rationale:_ macro parameters and lambda parameters may share a spelling;
  replacing bound references with a caller argument changes program meaning.
  _Rejected:_ a body-wide parameter map; renaming inserted caller expressions;
  treating a lambda as an opaque expression.
- **Q:** Why extract substitution into `Pudu.Frontend.Expand.Substitute`? **A:** Pure AST tree substitution and hygienic variable renaming form a cohesive, self-contained subphase (~155 lines), reducing `Pudu.Frontend.Expand` to a coordinator (~360 lines) focused on macro collection, parameter kind verification, and recursive expansion.

## Referenced by

[[Macro Expansion]] · [[Macro Expansion Spec]]
