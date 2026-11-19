---
type: handoff
status: ACTIVE
issue: 963
aliases: [Native Render Skipping Delivery]
---

# Native Render Skipping Delivery

Backend Engineer implementing; Language Architect review required for the checker rule of
[[Native Render Skipping]]; Forensic Guardian wiki-parity review pending.
The architect owns the memo contract in [[Std Mobile View]] and its keyed constructor in [[Std Mobile Memo]].
Implementation owns the memo node, the `measured` reconcile and the fixture [[Uses Mobile Memo]].

## Scope

Part 1 of [[Native Render Skipping]] adds `View.Memo`, `Std.Mobile.Memo.lazy` and `View.measured` with its
`Stats` counters. Part 2 adds the checker rule: a `@static_function` type refuses, with E3103, any
constructor argument that is not a module-level function's name ([[Type Check Static]]). Its refusal
fixtures are [[Memo Render Lambda]] and [[Memo Render Local]]. Part 3, runtime-owned resources, is implemented on
iOS: [[Std Mobile Resource]], the FETCH, CANCEL and WAKE instructions, the FETCHED, WOKE and MEMORY events,
and the platform URL session host [[pudu_ios_fetch.h]]. Its example is [[Native Remote Example]] with the
fixture [[Uses Mobile Resource]] (12 checks). Remaining in part 3: background pause, network-change
awareness, pagination helpers, per-release telemetry aggregation and the Android host.

## Exact next action

Validate on the simulator and open the PR for #963.

## Referenced by

[[handoffs/_MOC]] · [[Std Mobile View]] · [[Std Mobile Memo]] · [[Native Render Skipping]] · [[Uses Mobile Memo]] · [[Type Check Static]]
