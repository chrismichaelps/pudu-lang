---
type: module
path: "@root/src/Pudu/Frontend/Parser/Expression.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.82
depth_status: DEEP
coupling: 3.0
interface_stability: 1.0
tags: [module, deep]
aliases: [Parser Expression]
---

# Parser Expression

## Purpose

Parse initial-slice literal/name/block/if/unary/binary/call/member expressions with centralized precedence and no dependency cycle on declaration parsing.

## Interface

### Signatures

```haskell
type BlockParser = Parser (Located Block)

parseExpression :: BlockParser -> Parser (Located Expression)
parseExpressionAt :: BlockParser -> Int -> Parser (Located Expression)
```

### Governance

- The future declaration parser injects its block parser, avoiding a module cycle.
- Prefix parses literals, single-segment names, parentheses/grouping, block, `if`, and `!`/`-`/`&`/`&mut` unary forms.
- Postfix call/member binds tighter than every binary operator.
- Assignment is right-associative; every other admitted binary operator is left-associative, matching [[grammar/pudu]].
- Calls admit empty arguments and one trailing comma; member access requires an identifier.
- Every recursive prefix, nested `else if`, postfix, argument-list, and binary-tail descent uses [[Parser State]]'s shared budget.
- Argument parsing distinguishes a consumed closing delimiter from budget/progress exhaustion so one `E1099` does not cascade into a synthetic missing-`)` diagnostic.
- Unknown expression starts emit `E1040`; malformed `else` emits `E1042`; reserved index/`?`/`.await` postfix forms not yet represented by [[Syntax Tree]] emit `E1043` and produce `InvalidExpression` rather than being silently accepted.

### Linkage

- **Requires:** [[Parser State]], [[Token]], [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** the future declaration parser partition.

## Algorithm

Use budgeted precedence climbing: parse prefix, apply postfix, then consume closed-vocabulary binary operators whose binding power meets the threshold; recursively parse the right operand with an associativity-adjusted minimum. `if` parses condition plus the injected block capability, with optional block or nested-`if` else branch.

## Negative Logic (Prohibited Paths)

- No statement/declaration parsing, raw-text symbol construction, semantic operator lookup, implicit semicolon insertion, or recursion without budget.

## Edge Cases

- Empty call lists and trailing commas are valid; missing operands preserve closing delimiters and yield one invalid node/diagnostic; parenthesized expressions preserve merged spans.

## Depth

DEPTH 0.82 (DEEP). It hides precedence, postfix chaining, recursion safety, span construction, and expression recovery behind two operations.

## Grill Log

- **Q:** Avoid module cycle how? **A:** Accept block parsing as an explicit capability parameter. _Rationale:_ Expression owns expression mechanics while Declaration owns recursive block statements. _Rejected:_ `hs-boot`; monolithic parser file.
- **Q:** Pratt or precedence climbing? **A:** Precedence climbing with explicit prefix/postfix functions. _Rationale:_ small operator grammar and direct diagnostics. _Rejected:_ scattered precedence functions.
- **Q:** How are symbols classified? **A:** Match `SymbolKind` constructors and render through `symbolText`. _Rationale:_ the lexer vocabulary remains the single exhaustive punctuation authority. _Rejected:_ raw `Text` token construction.
- **Q:** How are hostile flat chains bounded? **A:** Charge recursive postfix, argument, and binary continuation steps to the same 512-level parser budget. _Rationale:_ flat attacker input must not exhaust the host stack. _Rejected:_ guarding only parenthesized recursion.
- **Q:** How does budget exhaustion avoid delimiter cascades? **A:** Argument parsing returns explicit completion evidence and checks token progress. _Rationale:_ an `E1099` at an unconsumed argument must not be misreported as a missing close. _Rejected:_ unconditional `expectSymbol` after exhausted descent.

## Variants

- Match/loop/await/range nodes extend prefix/postfix tables in their semantic slices.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser State]] · [[Token]] · [[Syntax Tree]] · [[Frontend]]
