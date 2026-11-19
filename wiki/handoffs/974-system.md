---
type: handoff
status: ACTIVE
issue: 974
aliases: [Native System Services]
---

# Native System Services

Implementer owns the native system request work: open, share, clipboard and status bar on the iOS and Android hosts, their stream instructions, their reports, and the example that exercises them. Role transition: the Language Architect owns the public contract in [[Std Mobile System]], [[Std Mobile Stream]] and [[Std Mobile Events]]; the Implementer takes the contract as fixed. Independent Language Architect review and Forensic Guardian wiki-parity review are pending.

## Scope

Instructions OPEN 46, SHARE 47, COPY 48, PASTE 49 and STATUS 50; events OPENED 25, SHARED 26 and PASTED 27. Numbering as in [[NATIVE-MOBILE]]. The image and fetch timeouts of [[pudu-ios-image]], [[PuduImage]] and [[PuduFetch]] are part of the same change.

## Owned files

- `cbits/pudu_ios_system.h`, `cbits/pudu_ios_host.m`, `cbits/pudu_ios_events.h`, `cbits/pudu_ios_scene.h`
- `android/org/pudu/PuduSystem.java`, `android/org/pudu/PuduBridge.java`, `cbits/pudu_android_host.c`, `cbits/pudu_android_kinds.h`, `cbits/pudu_android_events.h`, `cbits/pudu_android_routes.h`
- `lib/Std/Mobile/{System,Stream,Events,View}.pudu`, `examples/mobile/Services.pudu`, `test-fixtures/stdlib/UsesMobileSystem.pudu`

## Known limits

Android reports a share as shown, not as completed; the program is told this in [[Std Mobile System]]. Neither the Android system path nor the Android image and fetch limits have run on a device or emulator.

## Exact next action

Run the Services example on an Android emulator or device, and record its three labels, `Pasted: from Pudu`, `Opened: false` and `Shared: true` once the chooser opens, in [[Services Example]].

## Referenced by

[[handoffs/_MOC]] · [[Std Mobile System]] · [[pudu-ios-system]] · [[PuduSystem]] · [[Services Example]] · [[Uses Mobile System]] · [[NATIVE-MOBILE]]
