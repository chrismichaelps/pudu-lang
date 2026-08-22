---
type: module
path: "@root/src/Pudu/Diagnostic/Render.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 2.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Diagnostic Render]
---

# Diagnostic Render

## Purpose

Turn an opaque [[Diagnostic Model]] value into the text a person reads: a severity headline, a source location, the offending line with a caret span, help, and related context.

## Interface

### Signatures

```haskell
data RenderStyle = PlainStyle | ColorStyle
renderDiagnostic :: RenderStyle -> Source -> Diagnostic -> Text
renderDiagnostics :: RenderStyle -> Source -> [Diagnostic] -> Text
renderSummary :: [Diagnostic] -> Text
```

### Governance

- Rendering is a pure function of the diagnostic and the snapshot it points into. Nothing here inspects the filesystem, the terminal, or the environment; the caller decides the style.
- A diagnostic whose span belongs to a different snapshot renders its headline and location without an excerpt rather than quoting unrelated text.
- The caret covers the span on its first line and is at least one column wide, so a zero-width span at end of input is still visible.
- A multi-line span shows its first line and marks the continuation rather than dumping the whole region.
- Tab characters in the quoted line are expanded consistently in both the line and the caret row, so the caret cannot drift.
- Colour is applied only through the explicit `ColorStyle`; `PlainStyle` output contains no escape sequences and is what tests and files use.
- Related entries render as notes with their own location. Help renders once, last.

### Linkage

- **Requires:** [[Diagnostic Model]], [[Source]].
- **Consumed by:** the `pudu` executable and [[Pudu REPL]].

## Algorithm

Resolve the span's start and end to positions, slice the containing line out of the snapshot text, and assemble headline, location, gutter, excerpt, caret row, related notes, and help, padding the gutter to the line number's width.

## Negative Logic (Prohibited Paths)

- No terminal detection, no environment reads, no IO, no wrapping of user messages, no truncation that hides the caret, and no invented locations for spans it cannot resolve.

## Edge Cases

- An empty source, a span at end of input, and a span whose line is the last line without a trailing newline all render with a caret rather than an exception.
- A diagnostic with neither help nor related context renders as headline, location, and excerpt only.

## Depth

DEPTH 0.55 (MEDIUM). It hides position resolution, line slicing, caret arithmetic, and layout behind two total functions.

## Grill Log

- **Q:** Should rendering detect a terminal and choose colour itself? **A:** No; the style is a parameter. _Rationale:_ a pure renderer is testable byte for byte, and only the entry point knows whether output is a terminal, a pipe, or a file. _Rejected:_ ambient terminal detection inside the renderer.
- **Q:** What happens when the span is from another snapshot? **A:** Render without the excerpt. _Rationale:_ quoting text from a different snapshot would be a confidently wrong excerpt. _Rejected:_ silently rendering the wrong line; dropping the diagnostic.
- **Q:** Should long lines be truncated around the caret? **A:** Not yet. _Rationale:_ truncation logic that hides the caret is worse than a long line, and the trade-off deserves its own decision once real programs exist. _Rejected:_ fixed-width windowing now.

## Referenced by

[[src/Pudu/_MOC]] · [[Diagnostic Model]] · [[Source]] · [[Pudu REPL]] · [[Tooling]]
