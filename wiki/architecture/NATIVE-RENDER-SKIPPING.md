---
type: architecture
status: ACTIVE_DESIGN
tags: [architecture, native, mobile, ios, ui, performance]
aliases: [Native Render Skipping]
---

# Native Render Skipping

## Purpose

This page fixes the cost model of the view stream of [[Pudu Native]] and the three parts that
reduce it. Every host event calls `view(model)` and reconciles the result with the mounted tree
through [[Std Mobile View]]. The platform views change only where values changed, but building
the next view and comparing it with the mounted tree both scale with the size of the tree, not
with the size of the change. A screen of two thousand rows that changes one label therefore
pays for two thousand rows on every event.

The goal is a frame budget in which the work per event scales with what changed. The three parts
are delivered in order, and each one depends on the one before it.

## Cost model

| Quantity | Scales with | Paid on every event today |
| --- | --- | --- |
| Building the next view | size of the view tree | yes |
| Reconciling against the mounted tree | size of the view tree | yes |
| Platform view changes | values that changed | only where they changed |
| Resource requests | keyed requests described by the view | yes, unless the runtime coalesces them |

## Parts

1. **Memoized subtrees with counters** (this change). `View.Memo` wraps a subtree with a key. A
   reconcile with an equal key reuses the mounted subtree without calling its render function,
   comparing its children, or writing any instruction. A changed key renders once and reconciles
   against the cached previous result. The counters `compared`, `rendered` and `reused` are
   reported by `View.measured`, so fixtures can pin that skipping happened. See [[Std Mobile View]]
   and [[Std Mobile Memo]].
2. **Checker rule for memo render functions (implemented).** A render function passed to a memo must name a
   top-level function. A top-level function captures nothing, so its key is its whole input. A
   render function that reads a local, a closure capture or a mutable place can show stale content
   when its key is unchanged. The rule is enforced by the checker, not by the runtime: a
   `@static_function` type refuses, with E3103, any constructor argument that is not a module-level
   function's name ([[Type Check Static]]).
3. **Runtime-owned resources.** The view description carries a pure description of keyed requests
   beside the view. The runtime owns the requests:
   - one request in flight per key;
   - cancellation when a key is no longer described;
   - a cache policy per key;
   - backoff with jitter, honouring `Retry-After`;
   - conditional requests;
   - pause while the application is in the background;
   - bounded caches that shrink under memory pressure;
   - page-keyed pagination;
   - per-release telemetry of the counters from part 1.

   The program states what it wants to show. The runtime decides when to fetch it and when to drop it.

   **Status.** Implemented on iOS: [[Std Mobile Resource]] is the table of keyed needs and its commands;
   FETCH, CANCEL and WAKE carry the commands to the platform ([[pudu_ios_fetch.h]]); FETCHED, WOKE and
   MEMORY return answers, the wake and memory warnings. Conditional requests are left to the platform's
   protocol cache. Remaining: background pause, network-change awareness, pagination helpers,
   per-release telemetry aggregation, and the Android host.

## Memo keys

A memo key is text: the site name, a zero code point (`"\u{0}"`), then the canonical JSON text of
the key value. The canonical text of a derived `Encode` value is a total, comparable key. Two
keys are equal exactly when their texts are equal, so the reuse decision needs no comparison of
the rendered tree.

## Invariants

- Equal memo keys at the same site reuse the mounted subtree. No render function runs for a
  reused memo.
- A memo adds no node to the mounted tree. Its ids are those of the subtree it holds.
- A changed key renders exactly once per reconcile.
- The counters count what happened: `compared` counts reconciled nodes, `rendered` counts memo
  renders, and `reused` counts memos whose key was unchanged.
- Part 2 and part 3 do not change the stream format. A stream from before this change still
  decodes to the same screen.

## Negative Logic

- No skipping by value identity. A key is text, and two equal values with different encodings
  are treated as different keys; the cost of that is a render, never a stale screen.
- No memo keyed by a rendered tree. Comparing rendered trees is the cost this page removes.
- No memo whose render reads anything besides its key is accepted. Part 2 refuses lambdas and local
  bindings at the constructor argument, so a captured value cannot reach a memo.
- No resource request is started by a memo. Part 3 owns requests; a memo only renders.

## Frame budget

Work per event must scale with what changed. A commit that changes one row of a thousand rows
renders one row, compares the rows that were rendered, and writes the instructions for that row.
Every change to this page's parts must keep that property, and the counters of part 1 are the
evidence the property holds.

## Dependencies and consumers

Depends on [[Std Mobile View]] for the view tree and the `measured` reconcile, on [[Std Mobile Memo]]
for the keyed constructor, and on [[Std Mobile Stream]] for the instruction words. Part 3 depends
on [[Native IOS Refresh Delivery]] for the refresh state and on the host scheduling in
[[Pudu Native iOS UI]]. Frame pacing rules are in the ProMotion section of [[Pudu Native iOS UI]].

## Resolved Grill Log

- **Q:** Why key by the canonical JSON text rather than the value? **A:** A view case cannot hold a
  value of every type; the canonical JSON text of a derived `Encode` value is a total, comparable
  key. _Rejected:_ a generic equality on values, which would need every value type to carry one.
- **Q:** Why does the key include a site name? **A:** Two render functions can receive equal keys
  at the same place; the site keeps them apart. _Rejected:_ the render function itself as part of
  the key, which has no comparable form.
- **Q:** Why cache the rendered view inside the memo? **A:** A changed key reconciles against the
  previous result without rendering the old key again.
- **Q:** Why counters in the library? **A:** A skipped render is invisible; only a count shows that
  skipping happened, and fixtures pin it.

## Referenced by

[[architecture/_MOC]] · [[Pudu Native iOS UI]] · [[Std Mobile View]] · [[Std Mobile Memo]] · [[Uses Mobile Memo]]
