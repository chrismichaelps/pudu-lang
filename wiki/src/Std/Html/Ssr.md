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

`prepareCompact(Array[Piece])` is the opt-in preparation path. It renders fixed views exactly as
`prepare` does, but joins each complete adjacent static run into one retained `Markup([block])`
before the next `Hole`. It never joins across a hole, never retains request values, and emits no
empty static block. `prepare` remains byte-for-byte and chunk-for-chunk compatible; only callers
choosing `prepareCompact` receive the smaller per-request traversal. Both functions return the same
public `Plan` shape, so `chunks`, `render`, `finish`, and `renderWithin` need no parallel API.

`fragment(Html)` and `document(Html)` produce Rendered {body, byteLength} for response reuse.
`finish` produces the same record from a successful plan render. byteLength counts UTF-8 bytes.
Document adds a doctype; plans themselves add none unless a fixed view explicitly contains one.
A plan is a public record: prepared markup is an explicit trusted representation, not a security
barrier against manual construction. Caller-provided Html.Trusted retains its existing meaning.

## Complexity and limits

Static HTML rendering is paid once per prepare. Each unique used slot is rendered once per call;
repeated slots still occupy output bytes for each occurrence. Output is buffered and joined once.
Compact preparation additionally joins adjacent static fragments once, trading one preparation-time
join and retained static block for fewer plan-part and fragment visits on every response. A complete
static run is the compaction boundary: a hole always flushes it, because crossing the hole would
reorder output and prevent incremental delivery. This mode does not claim a fixed maximum block
size; callers that require bounded transport blocks retain `prepare` or apply a later streaming
transport policy.
The output budget limits accepted output bytes, not peak allocation: a dynamic slot is rendered
before its fragments are counted. No streaming transport, hydration, automatic cache invalidation
or performance measurement is claimed. Existing Html escaping is reused rather than reimplemented.

## Grill Log

- **Q:** Substitute strings inside serialized HTML? **A:** No; slots hold typed Html fragments.
- **Q:** Cache personalized slot output globally? **A:** No; memoization is local to one render.
- **Q:** Treat byte budgets as a complete memory sandbox? **A:** No; slot construction and
  rendering can allocate before counting. Negative budgets fail explicitly.
- **Q:** Hide a missing slot? **A:** No; report its name in traversal order.
- **Q:** Change `prepare` so every caller gets new chunk boundaries? **A:** No; compaction is additive
  and opt-in through `prepareCompact`.
- **Q:** Compact across a slot because the surrounding markup is static? **A:** No; the slot is an
  ordering and streaming boundary, and its value exists only per request.
- **Q:** Promise a hard static-block byte limit here? **A:** No; splitting UTF-8 safely would add a
  second policy unrelated to eliminating adjacent fragments. Existing preparation preserves fine
  chunks, while compact preparation deliberately retains one block per static run.

## Dependencies and consumers
[[Std Html]] supplies rendering. [[Std Http Server Reply]] consumes Rendered responses.

## Referenced by
[[src/Std/_MOC]] · [[2026-09-06-application-stack]] · [[2026-09-20-html-plan-compaction]]
