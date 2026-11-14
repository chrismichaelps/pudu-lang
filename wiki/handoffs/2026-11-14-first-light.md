---
type: handoff
status: ACTIVE
issue: 909
aliases: [Native First Light Delivery]
---

# Native First Light Delivery

Language Architect → Backend Engineer. This partition is phase 1 of [[Pudu Native]]: a counter built only from Pudu on the iOS simulator. Backend Engineer → Forensic Guardian review covers [[Std Mobile View]], [[Std Mobile Host]] and [[iOS Host Adapter]].

## Scope

The counter runs in the simulator CI job, tapped programmatically, with cold start and binary size recorded.

## Evidence so far

A local run on an iPhone simulator showed the label and button (screenshot) and printed `PUDU_LABEL Count: 3` after three programmatic taps, status 0. The static archive of the program is 95,696 bytes and the linked executable 147,392 bytes. First-frame timings taken while the machine was saturated are not recorded.

## Exact next action

Add the counter scenario to test/ios-simulator.mjs, then record first-frame time on an idle machine.

## Referenced by

[[handoffs/_MOC]] · [[Pudu Native]] · [[Native Counter Example]] · [[Uses Mobile View]]
