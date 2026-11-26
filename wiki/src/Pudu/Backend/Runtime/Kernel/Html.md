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
- The page is written straight into the text owner it becomes (a growing `pudu_text_owner` buffer), so no final copy is made.
- The first capacity is the length the same thread rendered last plus an eighth, at least 256 bytes. At the end, a quarter or more of unused capacity is returned to the allocator.
- Void elements are recognised by grouping the names by length, so no per-name length is computed.

## Resolved Grill Log

The tree stays the page's representation because the UI and bounded rendering modules build and match its variants; the kernel removes the per-piece strings and the final join instead. [[Native Aggregate Emission]]

The walk keeps an explicit heap stack of child-list frames instead of recursing, so nesting depth is limited by memory and never by the C call stack, as in `Std.Html`'s stack-based renderer.

Writing into the text owner removes the final copy, and the per-thread length hint makes growth rare on repeated pages; RenderBench went from 0.07 s to 0.05 s, and an address and undefined-behavior sanitizer run of the parity program was clean.

**Q:** How is the void element lookup kept in step with `Std.Html`? **A:** The names are grouped by length; the four-letter group once omitted `base`, so native output closed it while the interpreter did not (#1014). A parity program now renders every void element, lists, and a wide set of attributes natively, in the interpreter, and through the library writer, and requires all three to agree.

## Referenced by

[[Native Kernel Runtime]] · [[Eval Html Render]]

## Drop helper, kept renderings and skipping (#1021)

The writer carries a drop helper for the page type, and each frame records the output offset at which its subtree starts. A thread-local table of 256 cells keeps the rendered text of a subtree, keyed by the markup value's identity; 1024 seen slots record which subtrees have been rendered before. A subtree seen a second time is rendered once more and kept, with a retained reference, when its rendered length is at least 64 bytes. Kept cells are released at exit. Escaping jumps over clean runs with `pudu_html_skip` from [[Native Text Methods]].

Resolved Grill Log: the seen table holds no references, so an address reused by another subtree only means that subtree is rendered and kept. The kept cell holds a reference, so a kept text always belongs to the subtree it was keyed by. Subtrees under 64 bytes are not worth a cell.
