---
type: handoff
status: ACTIVE
issue: 926
aliases: [Native Platform Ledger Delivery]
---

# Native Platform Ledger Delivery

Language Architect → Toolchain Engineer. Owns [[Backend Ledger]], [[Backend Toolchain Probe]],
[[Pudu CLI Doctor]], the ledger hooks in the library and app builders and targets ([[Backend Toolchain Library]],
[[Backend Toolchain App]], [[Backend Native Target]]), the new native diagnostics in [[Diagnostic Native]], and the
device matrix in [[iOS Simulator Run]].

## Scope

How Pudu Native adopts new platform releases without a compiler release: one ledger of toolchain
facts, a preflight that refuses with the exact fix, and `pudu doctor --native` for the whole state.
The design is [[Native Platform Adoption]]; the iOS feature target it serves is [[Pudu Native iOS UI]].
Stacked on [[Native iOS Recycling Delivery]] (#925).

Findings: E6009 (installed Xcode below the ledger minimum), E6010 (an effective store rule the selected
SDK does not meet, device builds only), W6011 (Xcode newer than tested; the build proceeds), W6012 (a store
rule takes effect within N days, or a Development build misses it).

## Evidence

The ledger spec passes seven properties: releases, findings by purpose, the ninety-day window, capabilities and triples, probe parsers against real tool output, ledger wording, the doctor report, and an end-to-end refusal where a fake Xcode 25.4 is refused with E6009 before any compile and nothing is written. The existing target specs still pass through the new probe path.

`pudu doctor --native` on this Mac reports Xcode 26.6 (minimum 26.0, tested 26.6), both SDKs 26.5, the App Store rule met, fold-posture needing SDK 27.1, and the iOS 26.4 runtime's families; it exits 0, and exits 1 with E6009, W6012 and E6010 lines under a fake Xcode 25.4.

The full simulator suite passed on iPhone, and the new device matrix passed Counter, Feed and Catalog on an iPad Pro 13-inch (M5) with iOS 26.4. The diagnostic code gate passes.

## Exact next action

Merge after #927 lands and CI is green; then #928, iOS materials as the first SDK-gated capability.

## Referenced by

[[handoffs/_MOC]] · [[Native Platform Adoption]] · [[Pudu Native iOS UI]] · [[Native iOS Recycling Delivery]]
