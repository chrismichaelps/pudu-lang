---
type: handoff
status: ACTIVE
issue: 977
aliases: [Native Tabs]
---

# Native Tabs

Implementer owns native tab bars: the TABS instruction, the tab bar on the iOS and Android hosts, the SELECTED report, the stdlib fixture and the example that exercises them. Role transition: the Language Architect owns the public contract in [[Std Mobile Navigation]], [[Std Mobile Stream]], [[Std Mobile Events]] and [[Std Mobile View]]; the Implementer takes the contract as fixed. Independent Language Architect review and Forensic Guardian wiki-parity review are pending.

## Scope

Instruction TABS 54; event SELECTED 29. TABS replaces a single-stack navigation and NAVIGATE replaces the tabs. The tab bar's stacks, pages and sheet reuse the stack logic of the single navigation. Numbering as in [[NATIVE-MOBILE]].

## Owned files

- `packages/pudu/v0.1/lib/Std/Mobile/Navigation.pudu`, `Stream.pudu`, `Events.pudu`, `View.pudu`
- `packages/pudu/v0.1/cbits/pudu_ios_tabs.h`, `cbits/pudu_android_routes.h`, `cbits/pudu_ios_events.h`, `cbits/pudu_ios_nodes.h`, `cbits/pudu_ios_host.m`, `cbits/pudu_android_events.h`, `cbits/pudu_android_host.c`, `cbits/pudu_android_kinds.h`
- `packages/pudu/v0.1/android/org/pudu/PuduTabs.java`, `android/org/pudu/PuduBridge.java`, `android/org/pudu/PuduNavigator.java`
- `packages/pudu/v0.1/src/Pudu/Backend/Toolchain/HostSources.hs`, `packages/pudu/v0.1/pudu.cabal`
- `examples/mobile/Tabs.pudu`, `test-fixtures/stdlib/UsesMobileTabs.pudu`, `test/Pudu/Compiler/Program/Eval/DataSpec.hs` (count `10`), `test/ios-simulator.mjs`

## Known limits

The Android tab bar has not run on an emulator or device. Its only evidence is the source and the shared checks of [[pudu-android-routes]]. The iOS self-test of [[pudu-ios-tabs]] is the one run path described for the example; its result is not recorded on this page.

## Exact next action

Run the Tabs example on an Android emulator or device: pick Settings and back, open Detail, pop it once, show the sheet and dismiss it, then record `Selected: 1`, `Pops: 1` and `Dismissals: 1` in [[Tabs Example]].

## Referenced by

[[handoffs/_MOC]] · [[Std Mobile Navigation]] · [[pudu-ios-tabs]] · [[PuduTabs]] · [[Tabs Example]] · [[Uses Mobile Tabs]] · [[NATIVE-MOBILE]]
