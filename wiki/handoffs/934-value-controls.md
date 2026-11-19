---
type: handoff
status: ACTIVE
issue: 934
aliases: [Native Value Controls Delivery]
---

# Native Value Controls Delivery

Implementer owns the host code and the mirror pages of the value controls. Role transitions: the Language
Architect owns the public contract in [[Std Mobile Control]], [[Std Mobile Stream]], [[Std Mobile Events]] and
[[Std Mobile View]]; the Implementer takes the contract as fixed and owns the platform side. Independent
Language Architect review of the public contract and Forensic Guardian wiki-parity review are pending.

## Scope

Ten value control kinds (12 to 21), the instructions BOUNDS 41, OPTIONS 42, COUNT 43 and MOMENT 44, and the events
VALUED 21, COLORED 22 and DATED 23. Both hosts use one numbering; see the view stream section of
[[NATIVE-MOBILE]].

## Owned files

- `lib/Std/Mobile/Control.pudu`, `lib/Std/Mobile/View.pudu`, `lib/Std/Mobile/Stream.pudu`, `lib/Std/Mobile/Events.pudu`
- `cbits/pudu_ios_kinds.h`, `cbits/pudu_ios_values.h`, `cbits/pudu_ios_nodes.h`, `cbits/pudu_ios_events.h`,
  `cbits/pudu_ios_controls.h`, `cbits/pudu_ios_host.m`
- `cbits/pudu_android_kinds.h`, `cbits/pudu_android_events.h`
- `android/org/pudu/PuduListener.java`, `android/org/pudu/PuduPages.java`, `android/org/pudu/PuduWell.java`,
  `android/org/pudu/PuduMoment.java`
- `HostSources.hs`, `pudu.cabal`, fixtures for the value controls

Android numbering: Android's BOUNDS, OPTIONS, COUNT and MOMENT move from 36 to 39 to 41 to 44, and its VALUED, COLORED
and DATED move from 14 to 16 to 21 to 23. Android does not yet handle 36 to 40.

## Simulator refusals

`test/ios-simulator.mjs` adds three host refusals to the simulator run: a value sent to a label, inverted slider bounds, and empty segment labels. Each must be refused as a stream defect and must not change the screen.

## Exact next action

Run the controls simulator self-test on iPhone and iPad with `PUDU_UI_CONTROLS_TEST` set, and record each value kind's
result in [[pudu-ios-values]].

## Referenced by

[[handoffs/_MOC]] · [[Std Mobile Control]] · [[pudu-ios-kinds]] · [[pudu-ios-values]] · [[Std Mobile View]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[NATIVE-MOBILE]] · [[Uses Mobile Controls]] · [[Native Controls Example]]
