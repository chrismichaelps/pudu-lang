---
type: module
path: "@root/lib/Std/Mobile/Memo.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui, performance]
aliases: [Std Mobile Memo]
---

# Std Mobile Memo

## Purpose and interface

Constructor of memoized subtrees for [[Std Mobile View]]. A memo keeps a render function and the key it
was last rendered with, and reuses the mounted subtree while the key is unchanged. The constructor
is the only way this module builds a memo; the memo node itself is `View.Memo`, defined in [[Std Mobile View]].
The module performs no I/O.

Exports:
- `@static_function export type Render[K] = Render(fn(K) -> View)`: the only accepted form of a memo's
  render function. The attribute makes the checker refuse any constructor argument that is not a
  module-level function's name, as [[Type Check Static]] describes.
- `lazy[K: Json.Encode](site: Str, render: Render[K], key: K) -> View`: builds a `Memo` whose key
  is the text of `site`, then a zero code point (`"\u{0}"`), then the canonical JSON text of `key`
  encoded with `key.encode()`. The render function runs only when the memo is built or when its key changes.

Usage:

```
View.Keyed(list.map(|item: Item| ("{item.id}", Memo.lazy("row", Memo.Render(row), item))))
```

where `row` is a module-level `fn row(item: Item) -> View.View`.

## Invariants

- The memo key is text. Two keys are equal exactly when their texts are equal.
- The site name is part of the key, so two sites with equal key values never share a subtree.
- The render receives the key value it was built with and nothing else. The checker enforces this: a
  render that reads anything besides its key is a module-level function that captures nothing, and a
  lambda or a local binding is refused with E3103 before anything runs.
- The canonical JSON text is the key's whole encoding; no field outside the key takes part.

## Negative Logic

- A memo whose render reads a value besides its key cannot be built. The guarantee is that the memo is
  reused only while the key is unchanged, and an unchanged key means an unchanged view: the render
  reads nothing but its key, enforced by E3103 ([[Type Check Static]]).
- No memo is built from a render function alone. Without a key there is nothing to compare.
- No resource request is started here. Requests belong to the runtime of part 3 of [[Native Render Skipping]].

## Dependencies and consumers

Depends on [[Std Mobile View]] for the `Memo` variant, on the `Json.Encode` trait for the key text, and on
[[Type Check Static]] for the refusal of render functions that are not module-level names. Consumers: the fixture
[[Uses Mobile Memo]], and the refusal fixtures [[Memo Render Lambda]] and [[Memo Render Local]]. The examples
that adopt memos are listed in [[Native Render Skipping]].

## Resolved Grill Log

- **Q:** Why does the site name go into the key? **A:** Two render functions can receive equal key
  values at the same place in the tree; the site name keeps their memos apart. _Rejected:_ comparing
  the render functions, which have no comparable form.
- **Q:** Why is the render a named type rather than a bare function? **A:** The attribute belongs on a type
  declaration, so the rule reaches every use of the constructor through any import alias. _Rejected:_ a
  parameter attribute, which a caller could route around through another function.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Native Render Skipping]] · [[Uses Mobile Memo]] · [[Type Check Static]] · [[Memo Render Lambda]] · [[Memo Render Local]]
