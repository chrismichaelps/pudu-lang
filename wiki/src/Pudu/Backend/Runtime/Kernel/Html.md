---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Html.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native HTML Kernel]
---
# Native HTML Kernel

Renders a `Std.Html.Html` page in one pass into one growing buffer.

The walk uses an explicit heap stack of child-list frames rather than recursion, so page nesting depth is bounded by memory rather than the call stack, matching the stack-based renderer in `Std.Html`.

## Contract

- `pudu_html_render(view, document, element, text, fragment, trusted)` takes the page and the four variants' indexes, and returns the text.
- A document starts with `<!DOCTYPE html>` and a line break.
- Text is escaped while it is copied. Runs without `&`, `<`, `>`, `"` or `'` are written whole, and each of those five becomes its entity, as `Str.escapeHtml` writes them. Trusted markup is written as given. A fragment writes its children.
- An element whose name is not a letter followed by letters, digits, `-`, `_`, `.` or `:` writes only its children. Otherwise it writes its tag, each attribute whose name is valid and does not begin with `on` (any case) with an escaped value, then ` />` for a void element, or `>`, its children and its closing tag.

## Resolved Grill Log

The tree stays the page's representation because the UI and bounded rendering modules build and match its variants; the kernel removes the per-piece strings and the final join instead. [[Native Aggregate Emission]]

The walk keeps an explicit heap stack of child-list frames instead of recursing, so nesting depth is limited by memory and never by the C call stack, as in `Std.Html`'s stack-based renderer.

## Referenced by

[[Native Kernel Runtime]] · [[Eval Html Render]]
