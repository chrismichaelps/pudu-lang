---
type: handoff
tags: [handoff, frontend, parser, diagnostics]
---

# Line-Leading Operators Handoff

## Objective

Let a binary operator lead a continuation line when it cannot begin an expression, while
refusing the one mixed shape that would silently change a wrapped expression's value.

## FMCF Roles

- **Language Architect:** resolved continuation from the closed operator vocabulary rather
  than indentation, and specified `E1055` for a prefix-capable spelling after a leading-
  operator chain has already begun.
- **Frontend Engineer:** owns `Parser Expression`, the expression/block regression tests,
  and the natural standard-library fixture that previously required a workaround.
- **Forensic Guardian:** audits code/wiki fidelity, diagnostic ownership, backlinks,
  review size, and final validation evidence before PR #127 is ready.

## Resolved Contract

- A line-leading binary operator with no prefix form continues the expression above it.
- `-`, `&`, and `*` ordinarily begin a new unary expression on their line.
- If a binary expression already crossed a line through a line-leading operator, meeting a
  following line-leading `-`, `&`, or `*` reports `E1055` once. Block parsing leaves that
  token for statement recovery; an enclosing expression construct parses and discards the
  ambiguous prefix run under the shared budget so its separator, closer, block, arrow, or
  next arm remains.
- Indentation and the left expression's AST shape never decide continuation.
- Trailing binary operators and line-leading `.`, `?`, and `.await` retain their existing
  continuation behavior; line-leading `(` and `[` remain statement starts.

## Why the Mixed Shape Is Refused

`1` followed by `+ 2 * 3` has established a leading-operator chain. If the next line is
`- 4`, treating it as a new unary statement makes the binding seven instead of the three a
reader sees in the chain. Continuing every `-` would instead change existing programs.
`E1055` requires the writer to choose: put `-` at the end of the preceding line to
continue, or parenthesize the unary expression to make it a visibly separate statement.

The parser carries whether the current binary expression consumed a line-leading
continuation, including through recursive precedence bands. It does not guess from braces
or indentation, so `while ready {}\n-1` and an unrelated `*borrowed` stay legal.

## Diagnostics Allocated

`E1055` — a prefix-capable operator follows an established line-leading binary chain. The
primary span is the operator and the help names the two explicit spellings.

## Validation State

- Focused expression and block properties pass at `-O0` and cover every binary operator,
  all three binary/prefix spellings, precedence-band propagation, exact code/span/help,
  ordinary unary statements, grouped/call/index/array/tuple delimiter recovery, nested
  delimiters in an invalid tail, and hostile recursion-budget cases.
- All 32 standard-library modules and 30 valid standard-library fixtures check without
  diagnostics; `UsesStructures.pudu` formats, checks, and runs with its natural leading
  `!=` layout.
- Full `-O0` and `-O2` suites pass. The production `-O2 -Werror` build, whole Pudu formatter
  check, diagnostic-code ownership check, LSP session, documentation parity, and negative
  documentation command all pass.
- Independent review found and verified fixes for delimiter/control-owner cascades, consecutive
  ambiguous prefix recovery, contextually accurate `E1055` help, hostile recovery-budget
  exhaustion, and module-mirror dependency/interface parity. The final audit reports no open
  implementation or wiki finding.

## Exact Next Action

Commit the reviewed scope and open the issue #127 PR against `dev`.

## Referenced by

[[handoffs/_MOC]] · [[Engineering Delivery]] · [[grammar/pudu]] · [[Parser Expression]]
