---
type: handoff
status: ACTIVE
issue: 991
aliases: [Native Pick]
---

# Native Pick

Implementer owns the #991 slice: contact, document and photo pickers, audio recording, the application badge, the secure screen setting and toasts. The instruction codes 79 to 85 in [[Std Mobile Request]], and the events 45 and 46 in [[Std Mobile Events]], are taken as fixed for this slice; the instruction bound is 86. Independent Language Architect review and Forensic Guardian wiki-parity review are pending.

## Scope

[[Std Mobile Pick]], [[Std Mobile Request]], [[Std Mobile System]], [[Std Mobile Events]] and [[Std Mobile View]]; the iOS host ([[pudu-ios-pick]]); the Android host ([[PuduPick]]); the example [[Picker Example]]; the stdlib fixture [[Uses Mobile Pick]].

## Owned files

- `packages/pudu/v0.1/lib/Std/Mobile/Pick.pudu`, `Request.pudu`, `System.pudu`, `Events.pudu`, `View.pudu`
- `packages/pudu/v0.1/cbits/pudu_ios_pick.h`
- `packages/pudu/v0.1/android/org/pudu/PuduPick.java`
- `examples/mobile/pick/Picker.pudu` and its `pudu.toml`
- `test-fixtures/stdlib/UsesMobilePick.pudu`
- Shared files edited by this slice: `cbits/pudu_ios_host.m`, `pudu_ios_nodes.h`, `pudu_ios_events.h`, `pudu_android_services.h`, `android/org/pudu/PuduActivity.java`, the toolchain framework and source lists, `test/ios-simulator.mjs`, `test/Pudu/Compiler/Program/Eval/DataSpec.hs`

## Known limits

The Android path has not run on a device or an emulator. Its evidence is the source of [[PuduPick]]. The iOS self-test checks the example's labels at rest only, so the suite does not exercise the pickers, recording or the camera. iOS ignores SECURE, and Android ignores BADGE, so each of those is checked on one host only.

## Exact next action

Run [[Picker Example]] on an Android device: a picked contact, a picked document, a photo, a recording, a toast, and FLAG_SECURE blocking a screenshot.

## Referenced by

[[handoffs/_MOC]] · [[Std Mobile Pick]] · [[Std Mobile Request]] · [[Std Mobile System]] · [[Std Mobile Events]] · [[Std Mobile View]] · [[Picker Example]] · [[Uses Mobile Pick]] · [[pudu-ios-pick]] · [[PuduPick]] · [[NATIVE-MOBILE]]
