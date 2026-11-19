---
type: handoff
status: ACTIVE
issue: 971
aliases: [Android Routes Delivery]
---

# Android Routes Delivery

Implementer owns the Android platform side of navigation, refresh, requests, wake, memory and insets. Role transition: the Language Architect owns the public contract in [[Std Mobile Stream]] and [[Std Mobile Events]]; the Implementer takes the contract as fixed. Independent Language Architect review and Forensic Guardian wiki-parity review are pending.

## Scope

Instructions NAVIGATE 36, REFRESH 37, FETCH 38, CANCEL 39 and WAKE 40, and events POPPED 14, DISMISSED 15, REFRESHED 16, INSETS 17, FETCHED 18, WOKE 19 and MEMORY 20 on Android. Numbering as in [[NATIVE-MOBILE]].

## Owned files

- `cbits/pudu_android_{routes,events,kinds}.h`, `cbits/pudu_android_host.c`
- `android/org/pudu/{PuduNavigator,PuduRefresh,PuduFetch,PuduBridge,PuduActivity}.java`
- `android/AndroidManifest.xml`, `HostSources.hs`, `pudu.cabal`

## Simulator and device refusals

Each refusal listed in [[pudu-android-routes]] is a stream defect that leaves the screen unchanged. Android runtime behavior is not yet exercised on a device or emulator.

## Exact next action

Run the Pages, Refresh, Remote and Controls apps on an Android emulator or device, and record each navigation, pull, request and wake result in [[pudu-android-routes]].

## Referenced by

[[handoffs/_MOC]] · [[pudu-android-routes]] · [[PuduNavigator]] · [[PuduRefresh]] · [[PuduFetch]] · [[PuduActivity]] · [[NATIVE-MOBILE]] · [[Std Mobile Stream]]
