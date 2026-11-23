---
type: handoff
status: ACTIVE
issue: 983
aliases: [Native Device]
---

# Native Device

Implementer owns the #983 slice: device facts, network reachability and keep-awake. Role transition: the Language Architect's contract for DEVICE 58, NETWORK 59 and AWAKE 60 in [[Std Mobile Stream]], and for DESCRIBED 32 and NETWORKED 33 in [[Std Mobile Events]] and [[Std Mobile View]], is taken as fixed for this slice. Independent Language Architect review and Forensic Guardian wiki-parity review are pending.

## Scope

`Std.Mobile.Device` with `describe`, `watchNetwork` and `keepAwake`, and the pure decoders `facts` and `linkOf`; the iOS host on UIKit, Foundation and a Network path monitor ([[pudu-ios-device]]); the Android host on ConnectivityManager under the normal permission `ACCESS_NETWORK_STATE` ([[PuduDevice]]); the example [[About Example]]; the stdlib fixture [[Uses Mobile Device]]; the simulator run in [[ios-simulator]].

## Owned files

- `packages/pudu/v0.1/lib/Std/Mobile/Device.pudu`
- `packages/pudu/v0.1/cbits/pudu_ios_device.h`
- `packages/pudu/v0.1/android/org/pudu/PuduDevice.java`
- `examples/mobile/About.pudu`
- `test-fixtures/stdlib/UsesMobileDevice.pudu`
- Shared files edited by this slice: `packages/pudu/v0.1/lib/Std/Mobile/Stream.pudu`, `lib/Std/Mobile/Events.pudu`, `lib/Std/Mobile/View.pudu`, `cbits/pudu_ios_host.m`, `cbits/pudu_ios_nodes.h`, `cbits/pudu_ios_events.h`, `cbits/pudu_android_kinds.h`, `cbits/pudu_android_events.h`, `cbits/pudu_android_routes.h`, `cbits/pudu_android_host.c`, `android/org/pudu/PuduBridge.java`, `android/AndroidManifest.xml`, `src/Pudu/Backend/Toolchain/App.hs`, `src/Pudu/Backend/Toolchain/HostSources.hs`, `pudu.cabal`
- `test/Pudu/Compiler/Program/Eval/DataSpec.hs`, `test/ios-simulator.mjs`

## Known limits

The Android path has not run on a device or an emulator. Its evidence is the source of [[PuduDevice]]. The iOS simulator run of [[About Example]] with `PUDU_UI_DEVICE_TEST` is the only run path recorded here. Link kinds reported on iOS depend on the simulator's network, so a Wifi or Cellular result is not yet observed on hardware.

## Exact next action

Run [[About Example]] on an Android device and confirm the facts, a Wifi or Cellular link, and that the screen stays on. Record the result in [[PuduDevice]].

## Referenced by

[[handoffs/_MOC]] · [[Std Mobile Device]] · [[pudu-ios-device]] · [[PuduDevice]] · [[About Example]] · [[Uses Mobile Device]] · [[NATIVE-MOBILE]]
