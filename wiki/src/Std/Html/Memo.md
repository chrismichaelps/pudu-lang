---
type: module
path: "@root/lib/Std/Html/Memo.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, html, rendering, cache]
aliases: [Std Html Memo]
---
# Std Html Memo

## Purpose and interface

Rendered HTML fragments kept by key in a shared cache, so page chrome that is the same on every
request (a header, a navigation bar, a footer) is built and rendered once rather than on each
request. `Memo` holds `held`, a `Std.Sync` cell of `Map[Str, Str]` from key to rendered text, and
`limit`, the most fragments it keeps.

`cache(limit)` returns an empty cache that keeps at most `limit` fragments. `kept(memo, key, render)`
returns the text kept under `key`; on a miss it runs `render`, and keeps the text while the cache
holds fewer than `limit` fragments. Once the cache is full, a missed key's text is used but not
kept. `fragment(memo, key, view)` returns `Html.trusted` of the kept rendering of `view()`, so a kept
view does not run again. `size(memo)` returns how many fragments are kept.

The module adds no markup construction of its own. `Std.Html` is unchanged; a kept fragment enters a
page as a trusted segment, exactly as any other `Html.trusted` value does.

## Contract

Markup is immutable, so a key names a fragment's inputs. A view whose markup depends on anything
other than its key must put that dependency into the key; otherwise a later request receives text
rendered for an earlier one.

Create the cache once, for example at server start, and share it across requests and threads. Two
threads that miss the same key at once both render it, and either rendering may be the one kept;
both are the same text when the key names the inputs, so the race costs a duplicate render and
nothing else.

A compile-time constant cannot hold a cache, because a cell is created at run time. The cache is
therefore an ordinary value the program creates and passes to the code that renders with it.

Evidence: 100,000 pages with a 24-link footer rendered in 1.68 s when rebuilt each time and 0.18 s
when kept, natively, with identical output. A native and interpreter parity program, "kept HTML
fragments render once, match a direct render, and stop keeping when full", checks that a kept
fragment renders once, matches a direct render, and stops being kept when the cache is full.

## Resolved Grill Log

- **Q:** Why an explicit cache object rather than a hidden global? **A:** The cache is passed in
  and created by the program. _Rationale:_ a module constant cannot hold a cell, because constants
  are folded at compile time and effects are refused there, so a global would need a mutable
  cell created at run time with no visible owner. An explicit cache makes its lifetime and its
  sharing visible: the value that is created at server start is the value every request reads,
  and a test can make its own cache without touching shared state. _Rejected:_ a hidden module
  global, which would hide who creates it, when it is shared, and how long it lives.
- **Q:** Why keep the rendered text rather than the `Html` value? **A:** The text is what every
  request needs. _Rationale:_ a page is written out as text, so a hit costs one map lookup and one
  trusted segment, rather than another walk of the view tree that produces the same text. Keeping
  the `Html` value would still require a walk on every request, and the saving would be the
  construction only, not the rendering that dominates the cost. _Rejected:_ keeping the view and
  rendering it on each request.
