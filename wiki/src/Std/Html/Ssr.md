---
type: module
path: "@root/lib/Std/Html/Ssr.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, html, rendering]
aliases: [Std Html SSR]
---
# Std Html SSR

## Purpose and interface

Reusable server rendering plans with static fragments and named dynamic slots. Piece is
Fixed(Html) or Slot(Str); prepare(Array[Piece]) renders fixed views once into a Plan of prepared
markup and slots. A plan can be kept in application state and reused across requests. Slots
represent complete HTML fragments, never attribute or script interpolation positions.

`chunks(plan, values)` produces Result[Array[Str], RenderError]. `render` joins these once.
`renderWithin(plan, values, maxBytes)` applies a nonnegative UTF-8 output budget while assembling
fragments, returning TooLarge(maxBytes) or InvalidLimit(maxBytes). Missing slots return
MissingSlot(name). Slots are rendered lazily when first visited, and repeated names reuse their
rendered fragments within that call. Unused values are ignored. No global cache exists, and
per-request values never enter the reusable plan or another request's slot cache.

`fragment(Html)` and `document(Html)` produce Rendered {body, byteLength} for response reuse.
`finish` produces the same record from a successful plan render. byteLength counts UTF-8 bytes.
Document adds a doctype; plans themselves add none unless a fixed view explicitly contains one.
A plan is a public record: prepared markup is an explicit trusted representation, not a security
barrier against manual construction. Caller-provided Html.Trusted retains its existing meaning.

## Complexity and limits

Static HTML rendering is paid once per prepare. Each unique used slot is rendered once per call;
repeated slots still occupy output bytes for each occurrence. Output is buffered and joined once.
The output budget limits accepted output bytes, not peak allocation: a dynamic slot is rendered
before its fragments are counted. No streaming transport, hydration, automatic cache invalidation
or performance measurement is claimed. Existing Html escaping is reused rather than reimplemented.

## Grill Log

- **Q:** Substitute strings inside serialized HTML? **A:** No; slots hold typed Html fragments.
- **Q:** Cache personalized slot output globally? **A:** No; memoization is local to one render.
- **Q:** Treat byte budgets as a complete memory sandbox? **A:** No; slot construction and
  rendering can allocate before counting. Negative budgets fail explicitly.
- **Q:** Hide a missing slot? **A:** No; report its name in traversal order.

## Dependencies and consumers
[[Std Html]] supplies rendering. [[Std Http Server Reply]] consumes Rendered responses.

## Referenced by
[[src/Std/_MOC]] · [[2026-09-06-application-stack]]
