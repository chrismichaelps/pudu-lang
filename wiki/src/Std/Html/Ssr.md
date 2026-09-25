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
When a limit is present, static fragments and cached repeated slots are admitted by exact retained
byte length. A slot first visited under the budget is rendered through [[Std Html Bounded]]
with only the remaining bytes; overflow can therefore stop inside one large text, trusted, element,
or attribute value instead of constructing the complete rejected subtree.

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

`prepareBytes(Array[Piece])` is the additive byte-native preparation path. It renders and encodes
static views once, compacts adjacent static byte runs without crossing a slot, and returns an
`EncodedPlan` backed by `Std.Html.Buffer.CompactBytePlan`; no request value enters that plan.
`byteSegments(plan, values)` returns `EncodedSegments { parts, byteLength }`. It visits slots in
document order, renders and UTF-8 encodes each unique used `Html` value once for that call, reuses
those bytes at every repeated position, and preserves empty byte parts as valid values.
`finishBytes(plan, values)` returns `EncodedResponse { body, byteLength }` and delegates contiguous
completion to the checked byte assembler. Both functions return `Std.Html.Buffer.AssembleError`, so
missing slots, invalid public metadata, overflow, refused copies, and final-length mismatch remain
typed rather than becoming partial output.

`beginIncremental(plan, producers, maxBytes)` creates a request-local encoded cursor without calling
any dynamic producer. `flushIncremental` is the pull/backpressure step: it emits at most one positive
bounded byte chunk and returns the next cursor, or reports completion. It stops and emits accumulated
static bytes before entering a dynamic part, so a head or placeholder can reach the consumer before
the body producer runs. Producers return `Result[Html, Str]`, run at most once per used slot, and are
cached only inside that cursor. Missing producers and producer failures are late typed errors in plan
order. `cancelIncremental` makes later flush/finish calls return `StreamCancelled` without invoking
remaining producers. `finishIncremental` explicitly drains the cursor and returns the remaining
bounded chunks; it does not join them.

`Shell = ShellFixed(Html) | ShellSlot(Str) | ShellElement(Str, Array[(Str, Str)], Array[Shell]) |
ShellFragment(Array[Shell])` is an additive typed reusable tree. A slot is always a complete child
fragment; there is no attribute, script, style, text-string, or raw-markup interpolation form.
`prepareShell(&Shell) -> Plan` compiles the tree iteratively into the existing `Markup` and `Hole`
operations. Element boundaries come from the one `Std.Html` renderer, preserving ordered
attributes, escaping, handler blocking, void spelling, and trusted values without a second
serializer. Explicit child cursors and closing continuations keep compilation non-recursive, and
request values never enter the resulting plan.

## Complexity and limits

Static HTML rendering is paid once per prepare. Each unique used slot is rendered once per call;
repeated slots still occupy output bytes for each occurrence. Output is buffered and joined once.
Compact preparation additionally joins adjacent static fragments once, trading one preparation-time
join and retained static block for fewer plan-part and fragment visits on every response. A complete
static run is the compaction boundary: a hole always flushes it, because crossing the hole would
reorder output and prevent incremental delivery. This mode does not claim a fixed maximum block
size; callers that require bounded transport blocks retain `prepare` or apply a later streaming
transport policy.
The output budget limits renderer output, not the already caller-built input tree. Bounded dynamic
rendering stops as soon as output overflow is certain and does not retain a complete rejected slot.
No streaming transport, hydration, automatic cache invalidation or cross-request cache is claimed.
Existing Html escaping and safety rules remain authoritative.
The byte-native path stores static UTF-8 once per reusable plan. Per request it encodes each unique
used slot once, even when that slot occurs repeatedly, and counts every occurrence from retained byte
lengths. Segmented delivery performs no final join; contiguous delivery performs one exact-size
allocation and checked copies. The legacy text path retains its established chunking, errors, and
results.
Shell compilation is paid once. Rendering its ordinary `Plan` keeps the established behavior: each
unique used slot renders once, repeated positions reuse it, unused values are ignored, and the first
missing slot in document order fails deterministically.
Incremental delivery retains at most the current bounded batch plus one rendered dynamic value and
the per-request cache. It is pull-driven application output, not a socket write or network-TTFB
promise. A consumer controls backpressure by requesting the next flush only when ready. No latency,
allocation, or asymptotic improvement is claimed without a focused measurement.

## Grill Log

- **Q:** Substitute strings inside serialized HTML? **A:** No; slots hold typed Html fragments.
- **Q:** Cache personalized slot output globally? **A:** No; memoization is local to one render.
- **Q:** Treat byte budgets as a complete memory sandbox? **A:** No; slot construction and
  the caller-built input tree already exist before rendering. Negative budgets fail explicitly, and
  bounded rendering limits only output traversal and retention.
- **Q:** Hide a missing slot? **A:** No; report its name in traversal order.
- **Q:** Change `prepare` so every caller gets new chunk boundaries? **A:** No; compaction is additive
  and opt-in through `prepareCompact`.
- **Q:** Compact across a slot because the surrounding markup is static? **A:** No; the slot is an
  ordering and streaming boundary, and its value exists only per request.
- **Q:** Promise a hard static-block byte limit here? **A:** No; splitting UTF-8 safely would add a
  second policy unrelated to eliminating adjacent fragments. Existing preparation preserves fine
  chunks, while compact preparation deliberately retains one block per static run.
- **Q:** Replace `Plan`, `finish`, or `renderWithin` with bytes? **A:** No; their public text results
  and error order remain compatible. Byte preparation and completion are additive.
- **Q:** Cache encoded slots in the reusable plan? **A:** No; only static bytes are shared. Slot
  rendering and encoding use a fresh per-call map and cannot cross request boundaries.
- **Q:** Count Unicode characters as response length? **A:** No; retained lengths count UTF-8 bytes,
  including multibyte scalars and bytes introduced by HTML escaping.
- **Q:** Join segments merely to learn their length? **A:** No; checked buffer resolution returns
  segments and their exact length together. Only `finishBytes` requests a contiguous body.
- **Q:** Add a second template language for nested slots? **A:** No; `Shell` is ordinary typed data
  whose only dynamic operation is a named complete-child position.
- **Q:** Reimplement HTML opening and closing serialization? **A:** No; shell compilation asks
  `Std.Html.renderChunks` for a typed shallow element boundary and retains those renderer-produced
  fragments around compiled child operations.
- **Q:** Allow a slot inside a void element? **A:** It has no output position, exactly like an
  ordinary child supplied to a void `Html.Element`; compilation retains the void element and ignores
  its children.
- **Q:** Compile by recursive descent? **A:** No; an explicit cursor/continuation stack handles deep
  shells without consuming the host call stack.
- **Q:** Check a dynamic slot only after `Html.renderChunks` finishes? **A:** No; the remaining
  budget is passed into the iterative HTML writer, which stops at the first scalar or syntax fragment
  that cannot fit.
- **Q:** Render a repeated slot again under its later remaining budget? **A:** No; a successful first
  rendering caches its fragments and exact byte length for that request. Every occurrence counts the
  cached length, and an occurrence that no longer fits returns `TooLarge` without rerendering.
- **Q:** Let a later missing slot outrank earlier overflow? **A:** No; parts remain evaluated in
  document order. An earlier missing slot returns `MissingSlot`; an earlier certain overflow returns
  `TooLarge`; invalid negative limits are refused before traversal as before.
- **Q:** Resolve every producer when the cursor begins? **A:** No; that would reproduce buffering
  behind a cursor-shaped API. A dynamic producer is first requested only when a flush reaches it.
- **Q:** Fill a partial static batch from the following producer? **A:** No; the static batch is
  emitted at the dynamic boundary, preserving the earliest useful output even when below the maximum.
- **Q:** Treat bytes already emitted as retractable after a late error? **A:** No; the error applies
  to the next step. Callers have already committed earlier chunks and decide their transport-level
  recovery policy explicitly.
- **Q:** Continue after cancellation? **A:** No; flush and finish return `StreamCancelled` and do not
  call another producer.

## Dependencies and consumers
[[Std Html]] supplies rendering. [[Std Html Bounded]] supplies budget-aware dynamic traversal.
[[Std Html Buffer]] supplies compact encoded plans, checked segmentation, and contiguous completion.
[[Std Http Server Reply]] consumes Rendered responses.

## Referenced by
[[src/Std/_MOC]] · [[2026-09-06-application-stack]] · [[2026-09-20-html-plan-compaction]] ·
[[2026-09-20-encoded-ssr-responses]] · [[2026-09-20-typed-html-shells]] ·
[[2026-09-20-bounded-ssr-slots]] · [[2026-09-21-incremental-html-output]]
