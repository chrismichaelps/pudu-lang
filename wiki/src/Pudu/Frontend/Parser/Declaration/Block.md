---
type: module
path: "@root/src/Pudu/Frontend/Parser/Declaration/Block.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.7
depth_status: MEDIUM
coupling: 6.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Parser Block]
---

# Parser Block

## Purpose

Parse brace-delimited blocks into ordered statements plus an optional result expression, resolving the newline-delimited statement boundary and owning block-local recovery.

## Interface

### Signatures

```haskell
parseBlock :: Parser (Located Block)
```

### Governance

- Two statements written on one line are rejected with `E1049`. A newline delimits a statement here and there is no terminator, so `{ 1 2 }` is not one expression and not two statements — it is two with the separator missing, and it silently became the second one. The rule reports once per block and never where the statement it followed already failed, which is what keeps a hostile `{{{{...` reporting one `E1099` rather than one diagnostic per brace.

- The block is the fixed point of the declaration/statement/expression recursion: it supplies itself as the `BlockParser` capability to [[Parser Expression]] and [[Parser Binding]], so no module needs a declaration orchestrator import or an `hs-boot` file.
- A block opens with `{` and closes with `}`; the closing brace is owned here through the state-owned `E1001` expectation.
- Statements are separated by line breaks, not by punctuation, using [[grammar/pudu]]'s continuation rule; the module owns no `;` token and inserts no terminator.
- `let`, `var`, and `const` statements delegate to [[Parser Binding]]'s local entry point, which is the only admitted binding path inside a block.
- `break` takes an optional `@label` and an optional value, independently: `break`, `break @outer`, `break value`, and `break @outer value` are all admitted. `continue` takes only the label, because it returns to a loop that is about to run again and nothing is waiting to receive a value.
- A `break`'s value follows the same line rule as `return`'s: absent when the next token closes the block or begins a new line, so a `break` alone on its line never swallows the statement after it.
- Whether a label names an enclosing loop, and whether that loop can carry a value at all, are semantic rules owned by [[Name Resolution]] and [[Type Check]] rather than parsing ones.
- `return` produces `ReturnStatement`; its value is absent when the next token closes the block or begins a new line, and is otherwise a full expression.
- Every other statement is an expression statement. A trailing expression statement becomes `blockResult`, matching "a block yields its final unterminated expression"; a block whose last entry is a binding or `return` yields `()` by carrying no result.
- Block nesting and each statement's own descent are charged to [[Parser State]]'s shared 512-level budget, so a hostile brace flood reports one `E1099`. Statement iteration itself is bounded by required token progress, not by the depth budget, because a long statement list is ordinary input and must stay linear.
- A statement that consumes no token emits one `E1040` from expression recovery, records `InvalidStatement`, and advances exactly one token, so an unrecognized statement start can never loop.

### Linkage

- **Requires:** [[Parser State]], [[Parser Expression]], [[Parser Binding]], [[Token]], [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** the future function declaration and declaration orchestrator partitions.

## Algorithm

Require `{`, then iterate without growing depth: stop at `}` or EOF, dispatch on the leading keyword to a local binding or `return`, otherwise parse an expression statement; each iteration is budgeted and required to consume input. Close with `}`, merge the brace-to-brace span, and promote a trailing expression statement to the block result.

## Negative Logic (Prohibited Paths)

- No semicolon ownership, terminator synthesis, scope or name resolution, control-flow validity checking, unreachable-code analysis, `break`/`continue`/`match`/loop syntax, or module-scope declarations inside a block.

## Edge Cases

- Once [[Parser State]] latches budget exhaustion, statement iteration stops and the closing `}` is not demanded, so a brace flood reports one `E1099` with no unwinding `E1001` cascade.
- An empty block yields no statements and no result; a missing `}` reports one `E1001` at EOF and returns the statements already recovered.
- `return` immediately before `}` or before a new line carries no expression; `return` followed by a same-line expression carries it.
- A line-initial `(` after an expression statement starts a new statement rather than a call, so `f()` on one line and `(x)` on the next are two statements.
- Statement recovery never consumes the closing brace, keeping enclosing blocks and declarations parseable.

## Depth

DEPTH 0.70 (MEDIUM). It resolves the newline statement boundary, owns the recursion fixed point for three grammar modules, and centralizes block-local recovery behind one entry point.

## Grill Log

- **Q:** Where does the block/expression/declaration recursion terminate? **A:** In this module, by passing `parseBlock` to the capability parameters of [[Parser Expression]] and [[Parser Binding]]. _Rationale:_ the knot resolves at one explicit call site instead of through a cyclic import or `hs-boot`. _Rejected:_ mutual imports; a single monolithic declaration file.
- **Q:** How is the block result distinguished from a statement? **A:** Promote the final statement to `blockResult` exactly when it is an expression statement. _Rationale:_ without semicolons every trailing expression is unterminated, and typing — not parsing — decides whether the value is admissible. _Rejected:_ a parser-side `()` check; requiring explicit `return`.
- **Q:** Is a long statement list hostile input? **A:** No; only nesting consumes the depth budget, while iteration is guarded by required progress. _Rationale:_ ordinary functions exceed 512 statements far more plausibly than 512 nested braces, and truncating them would reject valid programs. _Rejected:_ charging one budget level per statement, which capped block length at the recursion limit.
- **Q:** How does a hostile or unrecognized statement avoid looping? **A:** Require token progress per iteration and advance one token after a non-consuming statement. _Rationale:_ recovery must be total and cascade-free while remaining inside the enclosing braces. _Rejected:_ skipping to the next `}`, which discards recoverable statements; unguarded iteration.

## Referenced by

[[src/Pudu/Frontend/Parser/Declaration/_MOC]] · [[Parser State]] · [[Parser Expression]] · [[Parser Binding]] · [[Syntax Tree]] · [[Frontend]]
