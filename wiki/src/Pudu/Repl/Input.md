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
- A line ending on a binary operator awaiting its right operand also continues, matching
  [[grammar/pudu]]'s own continuation rule rather than inventing a second one for the prompt.

### Linkage

- **Requires:** [[Lexer]], [[Token]], [[Source Text]].
- **Consumed by:** [[Pudu REPL]].

## Algorithm

Lex the entry so far, count unbalanced openers over real tokens, and read another line while any
remain or the last line invites one. Stop at a balancing `}` or a blank line.

## Negative Logic (Prohibited Paths)

- No parsing, checking, or evaluation. Whether an entry *means* anything is decided after it is
  read, not while.
- No brace counting over raw text.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Pudu REPL]] · [[grammar/pudu]]
