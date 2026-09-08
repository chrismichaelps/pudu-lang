---
type: module
path: "@root/src/Pudu/Repl/Input.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
coupling: 2.0
interface_stability: 0.85
tags: [module, shallow, tooling]
aliases: [Repl Input]
---

# Repl Input

## Purpose

Decide when an entry typed at the prompt is finished, and read the rest of one that is not.

## Interface

```haskell
continuationPrompt :: Text
isComplete         :: Text -> IO Bool
isTriviaOnly       :: Text -> IO Bool
readEntry          :: Text -> InputT IO (Maybe Text)
readContinuation   :: Text -> InputT IO Text
```

### Governance

- **Completeness is decided over real tokens, not over text.** A brace inside a string literal or a
  comment must never leave the session waiting for input that will not come, and only the lexer
  knows which braces are which.
- Once continuation has begun, reading ends at a closing `}` that balances the entry, or at a blank
  line. The blank line is what lets a form whose next line starts with `|`, `.`, or `?` — a sum type
  or a fluent chain — be entered at all: the prompt cannot look ahead to see whether more is coming,
  so the reader says so by pressing return.
- The continuation prompt differs from the first, so a reader can see at a glance that the session is
  still waiting rather than wondering whether their entry was accepted.
- A line ending on a binary operator awaiting its right operand also continues, including bitwise shifts
  (`<<`, `>>`) and bitwise XOR (`^`), matching [[grammar/pudu]]'s own continuation rule rather than
  inventing a second one for the prompt.
- Submissions consisting solely of trivia (such as line comments or whitespace) are immediately complete,
  preventing continuation prompt lockup; only doc comments (`///`) and unclosed block comments (`/*`) continue.
- `isTriviaOnly` verifies whether an entry contains solely whitespace and non-doc comments without
  significant tokens or lexical diagnostics, allowing multiline block submissions (`:{ ... :}`) of comments
  to exit cleanly without triggering synthetic expression evaluation or printing `()`.

### Linkage

- **Requires:** [[Lexer]], [[Token]], [[Source Text]], [[Diagnostic]].
- **Consumed by:** [[Pudu REPL]].

## Algorithm

Lex the entry so far, count unbalanced openers over real tokens, check for trailing binary continuation
operators (`+`, `-`, `<<`, `>>`, `^`, etc.), and read another line while any remain or the last line invites one.
Stop at a balancing `}` or a blank line.

## Negative Logic (Prohibited Paths)

- No parsing, checking, or evaluation. Whether an entry *means* anything is decided after it is
  read, not while.
- No brace counting over raw text.

## Grill Log

- **Q:** When does a trivia-only submission complete? **A:** Immediately, unless it carries a doc comment (`DocComment`) or an unclosed block comment (`E0003`). _Rationale:_ typing ordinary comments or blank lines must return control to the prompt rather than waiting indefinitely in continuation mode. _Rejected:_ requiring non-empty significant tokens for all completions.
- **Q:** Why include `<<`, `>>`, and `^` in continuation symbols? **A:** Bitwise shift and XOR are binary expressions with right operands; splitting them across lines is valid grammar and should seamlessly continue. _Rationale:_ language consistency across all binary expression operators. _Rejected:_ forcing shift expressions onto single lines.
- **Q:** How should multiline comment-only blocks (`:{ ... :}`) be evaluated? **A:** They should not evaluate or print `()`. _Rationale:_ typing comments within a multiline block is visual note-taking or staging; evaluating empty/comment blocks as an implicit unit expression `()` clutters the REPL session. _Rejected:_ printing `()` on comment blocks.
- **Q:** Why remove explicit `Data.List (foldl')` import? **A:** `foldl'` is re-exported by modern GHC `Prelude` (GHC 9.10+ / 9.14+); importing it redundantly triggers GHC-66111 `[-Wunused-imports]` build failure under `-Werror`. _Rationale:_ zero-warning compatibility with CI compiler toolchains. _Rejected:_ CPP conditional import wrappers when `Prelude` standard exports cover it.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Pudu REPL]] · [[grammar/pudu]]



## Delimiter and lexical completion

Completion tracks delimiter kinds, not only depth. An unexpected or mismatched closer finishes
input immediately so the compiler can diagnose it; additional lines cannot repair that prefix.
An unfinished block comment keeps collecting input even after code tokens. Other lexical errors
finish immediately for diagnostics. Bare return is complete because its expression is optional.
Continuation reading also submits an irreparable delimiter/lexical error without requiring a blank
line. isTriviaOnly excludes documentation comments to preserve their attachment to declarations.

Resolved Grill Log: do not wait forever for an invalid prefix, and do not treat code followed by
an open comment as complete. No tests, builds or reviews are run.
