---
type: module
path: "@root/src/Pudu/Format.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.62
depth_status: MEDIUM
tags: [module, medium, tooling]
aliases: [Format, Formatter]
---

# Format

## Purpose

Render source in the one committed style [[grammar/pudu]] describes, without ever changing what a
program means.

## Interface

```haskell
data FormatResult = FormatResult
  { formatText'       :: !Text
  , formatDiagnostics :: ![Diagnostic]
  , formatChanged     :: !Bool
  }
formatSource :: Source -> FormatResult
formatText   :: Source -> Text
```

### Governance

- **Lines are never joined or split.** A newline delimits a statement in this language, so moving
  one moves a statement boundary: `a\nb` is two statements and `a b` is a syntax error. A formatter
  that reflowed would be rewriting programs rather than laying them out. Everything the formatter
  *does* change — indentation, spacing inside a line, blank-line runs, the trailing newline — is
  free precisely because none of it can change what the program means.
- The safety property is exact and tested: **the token sequence out is the token sequence in**, same
  kinds, same lexemes, same order. Only whitespace moves.
- Formatting is idempotent. `format(format(x)) == format(x)` is a property, not an aspiration.
- A file that does not lex is returned **byte for byte unchanged**. A formatter that rewrites text
  it could not read is a formatter that loses work.
- Comments are preserved exactly, on the lines they were written. A comment is the one thing in a
  file the compiler never reads, so nothing else would notice if the formatter dropped one.
- Indentation follows brace depth at two spaces a level. A line opening with a closing brace belongs
  to the level it closes. A line opening with something that cannot begin a statement — `=`, `|`,
  `else`, a binary operator — continues the line above and is indented one level past it, which is
  what keeps a sum type's variants from landing against the margin.
- Runs of blank lines collapse to one. A run is the writer separating two things, and one line says
  that as clearly as four.
- A contiguous run of imports sorts lexically with the standard library first. Each import's own
  leading comments travel with it, because they describe that import and would otherwise attach to
  whichever import sorted into the slot.

### The two adjacencies tokens alone cannot decide

- `name {` is a **record construction** (`User{id: 1}`, tight) or a **block** (`if ready { 1 }`,
  padded), and they are spelled identically at the brace. The decision is made from the shape that
  follows: a record's brace is followed by a field list, and a field name is a *lowercase*
  identifier — which is what separates `Point{x}` shorthand from `{ HalfEven }` yielding a variant.
  A brace closing a control-flow head is never a record, which the grammar already guarantees by
  forbidding a record construction there. An import's selection list is a third case: detached like
  a block, unpadded like a record.
- `!`, `-`, `&`, `~`, and `*` are **prefix or binary** depending only on what precedes them. An
  operator follows an operand; a prefix follows anything else. `a - b` subtracts, `(-b)` negates;
  `a * b` multiplies, `*handle` reads through a borrow. A prefix takes no space after it.

Both are decided once per line, before any spacing is, so a closing brace is always spaced like the
brace it closes rather than like whatever token sits beside it.

### Linkage

- **Requires:** [[Lexer]], [[Token]], [[Source Text]], [[Diagnostic Model]].
- **Consumed by:** [[Pudu CLI]].

## Algorithm

Lex, place every token and comment on the line it was written on, group by line, assign indentation
from running brace depth, classify each line's braces and prefix operators in one pass, then join
each line's pieces with the spacing those classifications imply. Import runs are sorted after
layout, where a line is already a unit.

## Negative Logic (Prohibited Paths)

- No parsing, typing, or evaluation. The formatter reads tokens and nothing else, which is what
  bounds how wrong it can be.
- No line reflowing, no token insertion or deletion, no reordering except whole import lines.
- No rewriting of a file that did not lex.

## Grill Log

- **Q:** Why format from tokens rather than by printing the parsed tree? **A:** Because a tree loses
  comments and because printing one would reflow. _Rationale:_ reflowing is unsafe here — newlines
  are statement boundaries — so the thing a tree-printing formatter is *for* is the thing this
  language cannot allow. _Rejected:_ pretty-printing the AST and re-attaching trivia, which is more
  machinery for a worse guarantee.
- **Q:** Why not preserve the writer's spacing for the ambiguous brace? **A:** It was tried and it
  is wrong too often. _Rationale:_ `fn f() -> Int{a + b}` would keep its tight brace forever because
  the writer once typed it that way, which is exactly what a formatter exists to fix. Deciding from
  the following shape gets every case in the standard library right. _Rejected:_ carrying the
  original gap; asking the parser, which would make the formatter depend on parse success.
- **Q:** Is a hand-flattened `if/else` chain preserved? **A:** No; it becomes the staircase brace
  depth implies. _Rationale:_ that is the style the file is being formatted *into*, and a formatter
  that honoured every local deviation would not be one. _Rejected:_ a width-driven exception.

## Referenced by

[[src/Pudu/_MOC]] · [[Tooling]] · [[grammar/pudu]] · [[Pudu CLI]]
