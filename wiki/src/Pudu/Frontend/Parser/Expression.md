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

Parse the admitted expression vocabulary — literals, names, blocks, `if`, `match`, `while`, `loop`, `for`, unary and binary operators, and the full postfix family — with centralized precedence and no dependency cycle on declaration parsing.

## Interface

### Signatures

```haskell
type BlockParser = Parser (Located Block)

parseExpression :: BlockParser -> Parser (Located Expression)
parseExpressionAt :: BlockParser -> Int -> Parser (Located Expression)
parseScrutinee :: BlockParser -> Parser (Located Expression)
```

### Governance

- A type-argument list and an index both open with `[`, and two things tell them apart: the closing
  bracket is followed by `(`, and the first token inside could begin a **type** — which for an
  identifier means it is capitalised, as [[grammar/pudu]] requires of every type name and forbids of
  every value name. So `handlers[index](value)` reads an element and calls it while
  `convert[UInt8](value)` names a type, and neither reader has to think about it.
- What remains ambiguous is an index by a *capitalised constant* that is immediately called —
  `handlers[DEFAULT](value)` — which parentheses settle. Deciding by content alone was rejected: the
  naming rule separates `Int` from `index` but not a single-letter parameter `T` from a constant `N`.

- A prefix operator binds tighter than **every** binary one. Its operand was parsed at the
  multiplying level, which is *inside* that level, so `*a * *b` parsed as `*(a * (*b))` — a
  dereference of a product rather than a product of two dereferences. The threshold is named rather
  than written as a number, so a new operator cannot leave the prefix rule behind.

- An interpolated string is **sugar for concatenation**: `"a{x}b"` is `"a" + display(x) + "b"`.
  There is nothing a template means that concatenation does not, and a node of its own would make
  resolution, typing, and evaluation each carry a case for a construct with no new meaning.
- Each hole is rendered through `display` rather than `show`. A message being built wants a string's
  own content; the quotes an inspection adds would be wrong in every interpolated string that
  contains one.

- The future declaration parser injects its block parser, avoiding a module cycle.
- Prefix parses literals, single-segment names, parentheses/grouping, blocks, array literals `[a, b, c]`, `if`, and `!`/`-`/`&`/`&mut`/`~` unary forms.
- The postfix family is call, member, index, `?` failure propagation, and `.await`; every member of it binds tighter than every unary and binary operator, matching [[grammar/pudu]]'s precedence table.
- Binary precedence bands (tightest to loosest): multiplicative `* / % &* *|` (8); additive `+ - &+ &- +| -|` (7); shift and bitwise AND `<< >> &` (6); range and XOR `.. ..= ^` (5); comparison `< <= > >=` (4); equality `== !=` (3); `&&` (2); `||` and `|` (1); assignment `=` (0, right-associative). Shifts are left-associative and bind between additive and range, following the C/Rust convention that shifts are looser than arithmetic but tighter than comparison. `&` shares the shift band because bitwise AND is tighter than XOR and OR but looser than additive, matching C. `^` shares the range band so `a ^ b..c` parses as `(a ^ b)..c`; `|` shares the logical-or band because bitwise OR is looser than every arithmetic and comparison operator.
- A loop may be prefixed by `@name`, which parses as part of that loop rather than as an expression of its own. The sigil is required: with bare names, `break outer` could equally name a label or carry the value of a binding called `outer`, and no amount of lookahead settles which.
- `match` scrutinizes one expression and requires at least one `case` arm, reported as `E1051` when absent; an arm is `case pattern (if guard)? => (expression | block)` using [[Parser Pattern]].
- `while`, `loop`, and `for` are expressions whose bodies are blocks; `for` binds a pattern before `in`. Their `()` value and the validity of `break`/`continue` inside them are semantic rules.
- Line breaks are significant to continuation, matching [[grammar/pudu]]: a binary operator or a postfix `(`/`[` that begins a new line does not extend the expression, while a line-initial `.`, `?`, or `.await` does. Continuation is decided from the operator token's own leading trivia, so no synthetic terminator token is ever inserted.
- Assignment is right-associative; every other admitted binary operator is left-associative, matching [[grammar/pudu]].
- Calls admit empty arguments and one trailing comma; member access requires an identifier.
- Parentheses group one expression, and a comma makes the same syntax a tuple, mirroring the type grammar's `(T)` and `(T, U)`.
- An uppercase path directly followed by `{` builds a record. A field written without `:` takes the binding with the field's own name, mirroring the record pattern's shorthand.
- A record construction is withheld in the expression that precedes a block — an `if` or `while` condition, a `match` scrutinee, a `for` iterable — because `if READY { ... }` would otherwise be ambiguous with the block. Records are admitted again inside any bracketed context, so parentheses reinstate one.
- Every recursive prefix, nested `else if`, postfix, argument-list, and binary-tail descent uses [[Parser State]]'s shared budget.
- Argument parsing distinguishes a consumed closing delimiter from budget/progress exhaustion so one `E1099` does not cascade into a synthetic missing-`)` diagnostic.
- Unknown expression starts emit `E1040`; malformed `else` emits `E1042`; a `match` with no arms emits `E1051`; a label followed by anything but `loop`, `while`, or `for` emits `E1053` at the label, because the label is the part the reader can delete to make the program legal again.
- Reserved keywords (`enum`, `struct`, `task`, `spawn`, `module`, `mut`) in expression position emit `E1041` with targeted guidance: `enum`/`struct` point to `type`, `task`/`spawn` point to `async fn` and `scope`, `module` explains it is file-only, and `mut` points to `var`. Recovery skips to the line boundary so one keyword produces one diagnostic instead of a cascade.

### Linkage

- **Requires:** [[Parser State]], [[Parser Pattern]], [[Token]], [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** current [[Parser Binding]] and future declaration partitions.

## Algorithm

Use budgeted precedence climbing: parse prefix, apply postfix, then consume closed-vocabulary binary operators whose binding power meets the threshold; recursively parse the right operand with an associativity-adjusted minimum. `if`, `while`, `loop`, `for`, and `match` parse through the injected block capability; `match` loops `case` arms until `}` with required token progress.

## Negative Logic (Prohibited Paths)

- No statement/declaration parsing, raw-text symbol construction, semantic operator lookup, semicolon ownership, synthesized terminator tokens, or recursion without budget.

## Edge Cases

- Empty call lists and trailing commas are valid; missing operands preserve closing delimiters and yield one invalid node/diagnostic; parenthesized expressions preserve merged spans.
- Line sensitivity applies inside grouping and argument lists as well, so `(a` followed by a line-initial `- b` stops the operand and reports the missing `)` instead of silently spanning the break. Closing delimiters, commas, and `else` are matched regardless of line position because none of them can begin a statement.

## Depth

DEPTH 0.82 (DEEP). It hides precedence, postfix chaining, recursion safety, span construction, and expression recovery behind two operations.

## Grill Log

- **Q:** Avoid module cycle how? **A:** Accept block parsing as an explicit capability parameter. _Rationale:_ Expression owns expression mechanics while Declaration owns recursive block statements. _Rejected:_ `hs-boot`; monolithic parser file.
- **Q:** Pratt or precedence climbing? **A:** Precedence climbing with explicit prefix/postfix functions. _Rationale:_ small operator grammar and direct diagnostics. _Rejected:_ scattered precedence functions.
- **Q:** How are symbols classified? **A:** Match `SymbolKind` constructors and render through `symbolText`. _Rationale:_ the lexer vocabulary remains the single exhaustive punctuation authority. _Rejected:_ raw `Text` token construction.
- **Q:** How are hostile flat chains bounded? **A:** Charge recursive postfix, argument, and binary continuation steps to the same 512-level parser budget. _Rationale:_ flat attacker input must not exhaust the host stack. _Rejected:_ guarding only parenthesized recursion.
- **Q:** How does budget exhaustion avoid delimiter cascades? **A:** Argument parsing returns explicit completion evidence and checks token progress. _Rationale:_ an `E1099` at an unconsumed argument must not be misreported as a missing close. _Rejected:_ unconditional `expectSymbol` after exhausted descent.

- **Q:** How are statement boundaries expressed without semicolons? **A:** Gate binary and `(`/`[` postfix continuation on the operator token starting a new line, while `.`/`?`/`.await` continue across breaks. _Rationale:_ [[grammar/pudu]] delimits statements by newlines and braces; fluent chains stay idiomatic while `f()` followed by a line-initial `-value` remains two statements. _Rejected:_ semicolon insertion into the token stream, which breaks losslessness; unconditional greedy continuation, which makes every line-initial unary operator ambiguous; leading-operator continuation for all operators, which keeps the same ambiguity.

- **Q:** How is `Name {` told apart from a block? **A:** By position: a record construction is not admitted where a block may follow, and parentheses reinstate it. _Rationale:_ `if READY { ... }` is genuinely ambiguous, and a lookahead cannot resolve it because `{ value }` is both a plausible block and a plausible record shorthand. _Rejected:_ lookahead heuristics; requiring a keyword before every record; dropping the shorthand.

## Variants

- Match/loop/await/range nodes extend prefix/postfix tables in their semantic slices.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser State]] · [[Parser Binding]] · [[Token]] · [[Syntax Tree]] · [[Frontend]]
