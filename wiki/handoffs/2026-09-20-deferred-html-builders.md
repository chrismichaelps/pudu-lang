---
type: handoff
status: COMPLETE
date: 2026-09-20
issue: 262
tags: [handoff, stdlib, html, builder, performance]
aliases: [2026-09-20-deferred-html-builders]
---

# Deferred HTML Builder Handoff

## Objective

Resolve issue #262 with separately named zero-argument conditional builders that avoid constructing
false optional subtrees while preserving eager APIs, typed HTML safety, persistent builder values,
output order, and trust behavior.

## Ownership and role transitions

1. **Language Architect:** [[Std Html]], [[Std Html Build]], and [[Std Html Compose]] settle the
   additive name, callback lifetime, zero/one-call contract, and eager compatibility.
2. **Runtime Engineer:** owns the three HTML modules and their mirrors.
3. **Test Engineer:** owns `UsesHtmlBuild.pudu` and its explicit result in `ProtocolSpec.hs`.
4. **Forensic Guardian:** reconciles source, mirrors, MOC, changelog, and this handoff after gates.

The repository owner directed this delivery to avoid separate review-agent execution. These roles
describe the completed engineering passes within one implementation flow.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request. Production validation and source/vault parity
remain required.

## Contract

- `whenBuilt(condition, builder)` is additive in `Std.Html`, `Std.Html.Build.Building`, and
  `Std.Html.Compose.Composition`. Existing eager `when` signatures and evaluation remain unchanged.
- False tests the condition before invoking the callback: plain HTML returns `Fragment([])`, while
  fluent `Node` and `Content` return their persistent receiver value unchanged.
- True invokes the callback exactly once and sends its typed result through the existing return,
  `holds(child.html())`, or persistent node-append path at the call's exact output position.
- Callbacks return `Html` or `Node`; no string becomes markup, and deliberate `Trusted` construction
  remains visible inside the callback. Destinations, handler blocking, escaping, and non-recursive
  rendering are unchanged.
- Earlier builder aliases remain unchanged after either branch. Deferred true output appends after
  existing children in the same order as eager `when`.

## Measurement

The optimized same-machine probe ran a false optional subtree builder 200 times. The builder creates
1,000 typed paragraph nodes per invocation. The eager path supplied `expensive()` to `when`; the
deferred path supplied the same function body to `whenBuilt`.

| Measure | Eager false | Deferred false |
|---|---:|---:|
| heap allocated | 5,287,071,968 bytes | 62,426,608 bytes |
| process maximum RSS | 85,426,176 bytes | 80,084,992 bytes |
| elapsed | 1.33s | 0.04s |

Deferred construction reduced measured heap allocation by 98.8%, process maximum RSS by 6.3%, and
elapsed time by 97.0%. These figures include compiler and evaluator startup and are one-host
comparative evidence, not service latency or portable complexity guarantees.

## Exact next action

Commit directly to `dev`, post the commit on issue #262, close it, and continue to issue #263,
“Provide HTML byte coalescing with a real output-size bound.”

## Completion evidence

- `UsesHtmlBuild.pudu` checks without diagnostics and returns all 106 focused assertions.
- Counter-backed callbacks prove zero calls for false and one call for true in all three APIs; eager
  false arguments still evaluate once.
- Exact output checks preserve earlier builder aliases, append order, escaping, and explicit trusted
  markup.
- Full repository gate evidence is recorded before delivery.
- `git diff --check` passes; owned source files remain below 500 lines; source, mirrors, MOC,
  changelog, and handoff are aligned.

## Referenced by

[[handoffs/_MOC]] · [[Std Html]] · [[Std Html Build]] · [[Std Html Compose]] · [[src/Std/_MOC]]
