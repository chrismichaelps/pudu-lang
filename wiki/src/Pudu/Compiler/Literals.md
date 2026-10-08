---
type: module
path: "@root/src/Pudu/Compiler/Literals.hs"
fidelity: Active
domain: "[[Compiler Pipeline]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: DEEP
coupling: 2.0
interface_stability: 0.9
tags: [module, performance, lowering, constants]
aliases: [Compiler Literals]
---
# Compiler Literals

`resolveLiterals :: Map Span Text -> Map Span [Type] -> Module -> Module` rewrites every integer literal in expression
position into `ResolvedInteger kind value` once, after type checking. The kind is the checker's
answer for the literal's span, else the literal's own suffix, else the platform `Int`; the value is
the parsed number. The evaluator then builds the value directly, with no parsing and no `Map Span`
lookup. A literal the parser cannot read is left unchanged, so the evaluator's own answer for it
stands.

The rewrite is a `GHC.Generics` traversal over the syntax tree that stops at `Located Expression`
holding an integer literal. Only the module handed to the evaluator (`compileModule`) is rewritten;
`compileSyntax`, which tooling reads for positions and text, retains authored literals and selections.
Generated owner annotations lower through `resolveOwnerSelections :: Map Span [Type] -> Module -> Module`.

See [[Compiler Pipeline]] · [[architecture/PERFORMANCE]] · [[Eval Match]].

## Grill Log

- **Q:** Why resolve literals ahead of evaluation? **A:** Measured: evaluating an integer literal
  parsed its text (suffix, radix, an `Integer` multiply and add per digit) and looked its kind up in a
  `Map Span`, every time. On a counting loop that was 42% of the time and 31% of the allocation
  (#317). _Rationale:_ a literal's value and kind are fixed once checking has run, so computing them
  per evaluation is work with no answer to change.
- **Q:** Why a new `Literal` constructor instead of caching in the evaluator? **A:** A cache keyed by
  span keeps the `Span` comparison, which compares the source identity first and was itself 12.6% of
  the loop. The constructor puts the answer where the evaluator already is.
  _Rejected:_ a `Map Span Value` built at load time; a lazy field on `IntegerValue` (it would still
  need the checker's kind by span).
- **Q:** Why not also floats and decimals? **A:** Not until a measurement shows them on a hot path;
  the same constructor pattern applies when one does.
- **Q:** Does this change what a program means? **A:** No. The kind is chosen by the same rule the
  evaluator used: checker's kind, then suffix, then `Int`. The equivalence is covered by the program
  suites, which run every literal form through the rewritten module.


`resolveLiterals` takes the static selections too: a recorded reference becomes an explicit type application of every chosen type, in declaration order, and an explicit application's written prefix is replaced by the full list. Types are written with their canonical keys; a rigid parameter keeps its one-segment name.
- **Q:** Add a runtime channel for selections? **A:** No; the existing post-check rewrite makes them ordinary syntax, cached and evaluated like any other.

## Static field owner selection (#457)

`resolveOwnerSelections` lowers only generated complete static owners into ordinary method
applications with the checker-selected implementation and method arguments. Other authored syntax
and integer literals stay unchanged. Use an existing distinct generated owner-application span for
the lowered callee so the printer retains the explicit selection. Executable lowering erases the
owner application only after transferring its complete checked selection. Resolved Grill Log:
expanded code must reparse without introducing a new bracket ambiguity or a new public syntax.

An empty selection map returns the original module without traversal. Resolved Grill Log:
ordinary modules with no static selections do not pay for the additional owner-only projection.

Both projections retain that distinct callee span. Resolved Grill Log: an execution product reused
for printed expansion must retain the same explicit owner selection as an analysis product.
