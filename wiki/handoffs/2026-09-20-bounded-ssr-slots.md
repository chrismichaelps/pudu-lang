---
type: handoff
status: COMPLETE
date: 2026-09-20
issue: 261
tags: [handoff, stdlib, html, ssr, limits, performance]
aliases: [2026-09-20-bounded-ssr-slots]
---

# Bounded SSR Slot Handoff

## Objective

Resolve issue #261 by enforcing the remaining SSR output budget during iterative dynamic-slot
rendering, including inside one large text or trusted node, while preserving successful output,
typed HTML safety, repeated-slot reuse, and existing error precedence.

## Ownership and role transitions

1. **Language Architect:** [[Std Html]], [[Std Html Bounded]], and [[Std Html SSR]] settle the
   bounded-writer result, exact byte definition, error mapping, and compatibility contract.
2. **Runtime Engineer:** owns `Std/Html.pudu`, `Std/Html/Bounded.pudu`, `Std/Html/Ssr.pudu`, and their
   mirrors.
3. **Test Engineer:** owns `UsesHtmlServer.pudu` and its explicit result in `ProtocolSpec.hs`.
4. **Forensic Guardian:** reconciles source, mirrors, MOC, changelog, and this handoff after gates.

The repository owner directed this delivery to avoid separate review-agent execution. These roles
describe the completed engineering passes within one implementation flow.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request. Production validation and source/vault parity
remain required.

## Contract

- `Std.Html.Bounded.render` accepts a nonnegative byte maximum and returns fragments with their exact
  combined UTF-8 length, `InvalidLimit`, or `TooLarge`.
- Raw and trusted strings are scanned by scalar UTF-8 width. Text is escaped in safe runs plus fixed
  scalar expansions, with admission before retention. A rejected single node is never completely
  escaped or encoded merely to discover that it is too large.
- The bounded writer remains iterative and delegates scalar escape spelling, handler detection, and
  void-element membership to authoritative `Std.Html` functions.
- `Ssr.renderWithin` checks static parts in order, renders a first-used slot with only the remaining
  budget, and caches its successful fragments and byte length per request. Every repeated occurrence
  counts the cached length without rerendering.
- Negative limits fail before traversal. Otherwise the first missing slot or certain overflow in
  document order wins, matching the prior contract. Successful joined bytes remain identical.
- The limit applies to renderer output. It does not claim to bound or reclaim the caller-built input
  `Html` tree that already exists when rendering begins.

## Measurement

The optimized same-machine probe built one fragment containing 200,000 `<` characters followed by
an element that should remain unreached, then rejected it fifty times at a three-byte limit. The
baseline reproduced the previous render-complete-then-count path; the bounded path used
`Ssr.renderWithin`.

| Measure | Render then count | Bounded rendering |
|---|---:|---:|
| heap allocated | 2,436,739,600 bytes | 179,451,376 bytes |
| elapsed | 0.48s | 0.09s |

Early enforcement reduced measured heap allocation by 92.6% and elapsed time by 81.3%. These figures
include compiler and evaluator startup and are one-host comparative evidence, not service latency,
network, or portable complexity guarantees. Process maximum RSS was not used as improvement evidence
because startup sampling dominated it in this short probe.

## Exact next action

Commit directly to `dev`, post the commit on issue #261, close it, and continue to issue #262,
“Add deferred conditional HTML builders.”

## Completion evidence

- `UsesHtmlServer.pudu` checks without diagnostics and returns all 41 focused assertions.
- Exact checks cover successful parity, exact and short boundaries, zero and negative limits,
  Unicode, escape expansion, trusted/attribute rendering, repeat accounting, both precedence orders,
  and early rejection of a large individual text node.
- Full repository gate evidence is recorded before delivery.
- `git diff --check` passes; every implementation source remains below 500 lines; source, mirrors,
  MOC, changelog, and handoff are aligned.

## Referenced by

[[handoffs/_MOC]] · [[Std Html]] · [[Std Html Bounded]] · [[Std Html SSR]] · [[src/Std/_MOC]]
