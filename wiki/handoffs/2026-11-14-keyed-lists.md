---
type: handoff
status: ACTIVE
issue: 914
aliases: [Native Keyed Lists Delivery]
---

# Native Keyed Lists Delivery

Language Architect → Backend Engineer. Phase 2 of [[Pudu Native]]: keyed lists and a reconciler with stable node ids. Backend Engineer → Forensic Guardian review covers [[Std Mobile View]], [[Std Mobile Stream]] and [[iOS Host Adapter]].

## Ownership

Backend Engineer owns duplicate-key reconciliation in [[Std Mobile View]] and the exact-stream regression in [[Uses Mobile View]]. Independent review of the follow-up is pending.

## Scope

The mounted tree of [[Std Mobile View]] keeps stable node ids handed out by the program and recycled after REMOVE. Keyed rows are reconciled by key into INSERT, REMOVE and MOVE instructions. [[Std Mobile Stream]] encodes the instructions. The example [[Native List Example]] exercises them.

## Evidence so far

A simulator run typed Milk and pressed Add then Reverse three times: the screen showed `3 items`, `Milk 3`, `Milk 1`, `Milk 2` in that order, status 0.

## Exact next action

After keyed-list and simulator-app integration, implement scrolling, safe areas and keyboard avoidance as the first slice of [[Pudu Native iOS UI]].

## Referenced by

[[handoffs/_MOC]] · [[Pudu Native]] · [[Native List Example]] · [[Native Controls Delivery]] · [[Std Mobile View]] · [[Std Mobile Stream]] · [[iOS Host Adapter]]
