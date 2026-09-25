---
type: module
path: "@root/lib/Std/Html/Bounded.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, html, rendering, limits]
aliases: [Std Html Bounded]
---

# Std Html Bounded

## Purpose and interface

Iterative HTML rendering with a strict nonnegative UTF-8 output budget. `render(view, maximum)`
returns `Rendered { parts, byteLength }`, `InvalidLimit(maximum)`, or `TooLarge(maximum)`.
Successful parts join to exactly `Std.Html.render(view)`; their grouping is private to this bounded
path and does not alter `Std.Html.renderChunks`.

## Algorithm and boundaries

The writer carries the active child array, next index, and explicit parent/closing continuations.
Every raw scalar is admitted by its UTF-8 width before its source string is retained. Text scans
unconsumed suffixes and admits fixed escape expansions scalar by scalar; it flushes contiguous safe
runs but never constructs a complete rejected escape result. Element names, accepted ordered
attributes, attribute values, delimiters, trusted markup, and closing tags use the same admission.

`Std.Html.escapeScalar`, `isHandler`, and `isVoidElement` remain the authoritative safety
and syntax tables. This module adds no interpolation, trust conversion, destination decision,
recursive traversal, or input-tree limit. The caller already owns the `Html` tree; only rendered
output traversal and retention are bounded.

## Grill Log

- **Q:** Put this writer into the 408-line core module? **A:** No; the bounded responsibility would
  push `Std.Html` past the repository's 500-line source boundary. A focused sibling keeps both
  modules shallow while sharing authoritative renderer predicates.
- **Q:** Call `escape(content)` and measure afterwards? **A:** No; a refused single text node would
  already allocate and traverse its complete escaped result.
- **Q:** Convert trusted markup to complete `Bytes` to count it? **A:** No; scalar UTF-8 widths are
  admitted incrementally, stopping at the first certain overflow.
- **Q:** Recreate handler and void tables? **A:** No; this module calls exported `Std.Html`
  predicates so bounded and unbounded rendering cannot diverge there.
- **Q:** Promise the same fragment boundaries as `renderChunks`? **A:** No; only joined bytes and
  exact length are equivalent. This allows safe text runs to be grouped efficiently.

## Dependencies and consumers

[[Std Html]] supplies the typed tree and authoritative syntax/safety predicates. [[Std Html SSR]]
uses bounded rendering for first-time dynamic slots under an output budget.

## Referenced by

[[src/Std/_MOC]] · [[Std Html]] · [[Std Html SSR]] · [[2026-09-20-bounded-ssr-slots]]
