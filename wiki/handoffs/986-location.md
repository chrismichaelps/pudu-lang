---
type: handoff
status: ACTIVE
issue: 986
aliases: [Native Location]
---

# Native Location

Implementer owns the #986 slice: device location as one-shot positions and tracked positions. Role transition: the Language Architect's contract for LOCATE 61 and TRACK 62 in [[Std Mobile Stream]], and for LOCATED 34 in [[Std Mobile Events]] and [[Std Mobile View]], is taken as fixed for this slice. Independent Language Architect review and Forensic Guardian wiki-parity review are pending.

## Scope

`Std.Mobile.Location` with `locate`, `track`, `position` and `accuracyCode`; the iOS host on CoreLocation with its own location manager ([[pudu-ios-location]]); the Android host on LocationManager under the fine or coarse location permission ([[PuduLocation]]); the example [[Where Example]]; the stdlib fixture [[Uses Mobile Location]]; the simulator run in [[iOS Simulator Run]].

## Owned files

- `packages/pudu/v0.1/lib/Std/Mobile/Location.pudu`
- `packages/pudu/v0.1/cbits/pudu_ios_location.h`
- `packages/pudu/v0.1/android/org/pudu/PuduLocation.java`
- `examples/mobile/where/Where.pudu` and `examples/mobile/where/pudu.toml`
- `test-fixtures/stdlib/UsesMobileLocation.pudu`
- Shared files edited by this slice: `packages/pudu/v0.1/lib/Std/Mobile/Stream.pudu`, `lib/Std/Mobile/Events.pudu`, `lib/Std/Mobile/View.pudu`, `cbits/pudu_ios_host.m`, `cbits/pudu_ios_nodes.h`, `cbits/pudu_ios_events.h`, `cbits/pudu_android_kinds.h`, `cbits/pudu_android_events.h`, `cbits/pudu_android_routes.h`, `cbits/pudu_android_host.c`, `android/org/pudu/PuduBridge.java`, `src/Pudu/Backend/Toolchain/HostSources.hs`, `pudu.cabal`
- `test/Pudu/Compiler/Program/Eval/DataSpec.hs`, `test/ios-simulator.mjs`

## Known limits

The Android path has not run on a device or an emulator. Its evidence is the source of [[PuduLocation]]. The iOS simulator run of [[Where Example]] with `PUDU_UI_LOCATION_TEST` and a `simctl location set` fix is the only run path recorded here. The accuracy a device reports for a given fix is not yet observed on hardware.

## Exact next action

Run [[Where Example]] on an Android device with location allowed and confirm one position and tracked moves. Record the result in [[PuduLocation]].

## Referenced by

[[handoffs/_MOC]] · [[Std Mobile Location]] · [[pudu-ios-location]] · [[PuduLocation]] · [[Where Example]] · [[Uses Mobile Location]] · [[NATIVE-MOBILE]]
