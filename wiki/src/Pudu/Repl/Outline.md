---
type: module
path: "@root/src/Pudu/Repl/Outline.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 2.0
interface_stability: 0.9
tags: [module, shallow]
aliases: [Repl Outline]
---

# Repl Outline

## Purpose

Render parsed structure compactly for `:ast`, showing how the parser grouped an input.

## Interface

### Signatures

```haskell
outlineBlock :: Located Block -> [Text]
outlineExpression :: Located Expression -> Text
outlinePattern :: Located Pattern -> Text
```

### Governance

- The rendering is structural, not a formatter: it parenthesizes every binary and unary grouping so precedence is visible, which is the question `:ast` is asked.
- Spans and trivia are omitted; a reader debugging grouping does not want offsets, and the source line is already in front of them.
- Every syntax node has a rendering, so a new construct cannot silently render as nothing. A missing case is not cosmetic here: an unrendered node ends the session with an incomplete-pattern failure rather than an answer.

### Linkage

- **Requires:** [[Syntax Tree]], [[Syntax Name]].
- **Consumed by:** [[Pudu REPL]].

## Algorithm

Direct structural recursion producing one line per statement and one string per expression or pattern.

## Negative Logic (Prohibited Paths)

- No re-parsing, no evaluation, no source reconstruction, and no claim to be canonical formatting.

## Edge Cases

- Nested blocks render inline with `;` separators rather than expanding, keeping one entry on one line.

## Depth

DEPTH 0.30 (SHALLOW by intent). It is a projection of the tree for one command.

## Grill Log

- **Q:** Should `:ast` print the derived `Show` output? **A:** No. _Rationale:_ span-laden `Show` output buries the structure the command exists to reveal. _Rejected:_ deriving-based dumping; a full pretty-printer, which is the formatter's job.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Pudu REPL]] · [[Syntax Tree]]
