---
type: handoff
status: ACTIVE
issue: 989
aliases: [Native Services]
---

# Native Services

Implementer owns the #989 slice: notifications, device-owner authentication, the in-app browser, speech, image picking, battery, screen brightness, orientation lock and motion sensing. The instruction codes 63 to 73 in [[Std Mobile Request]] and the events 35 to 41 in [[Std Mobile Events]] are taken as fixed for this slice. Independent Language Architect review and Forensic Guardian wiki-parity review are pending.

## Scope

[[Std Mobile Request]] with the eleven writers; [[Std Mobile Notify]], [[Std Mobile Auth]], [[Std Mobile Media]] and [[Std Mobile Paging]]; the battery, brightness, orientation and sense functions of [[Std Mobile Device]]; the iOS host ([[pudu-ios-notify]], [[pudu-ios-media]], [[pudu-ios-device]], [[pudu-ios-scene]]); the Android host ([[pudu-android-services]], [[PuduNotify]], [[PuduAlarm]], [[PuduAuth]], [[PuduMedia]], [[PuduDevice]]); the example [[Toolbox Example]]; the stdlib fixtures [[Uses Mobile Services]] and [[Uses Mobile List]].

## Owned files

- `packages/pudu/v0.1/lib/Std/Mobile/Request.pudu`, `Notify.pudu`, `Auth.pudu`, `Media.pudu`, `Paging.pudu`
- `packages/pudu/v0.1/cbits/pudu_ios_notify.h`, `pudu_ios_media.h`, `pudu_android_services.h`
- `packages/pudu/v0.1/android/org/pudu/PuduNotify.java`, `PuduAlarm.java`, `PuduAuth.java`, `PuduMedia.java`
- `examples/mobile/toolbox/`
- `test-fixtures/stdlib/UsesMobileServices.pudu`
- Shared files edited by this slice: `packages/pudu/v0.1/lib/Std/Mobile/Stream.pudu`, `Events.pudu`, `View.pudu`, `Device.pudu`, `cbits/pudu_ios_host.m`, `pudu_ios_device.h`, `pudu_ios_scene.h`, `pudu_android_host.c`, `pudu_android_events.h`, `pudu_android_kinds.h`, `android/AndroidManifest.xml`, `android/org/pudu/PuduActivity.java`, `PuduBridge.java`, `PuduDevice.java`, `src/Pudu/Backend/Toolchain/HostSources.hs`, `App.hs`, `pudu.cabal`, `examples/mobile/Catalog.pudu`, `test-fixtures/stdlib/UsesMobileList.pudu`, `test/Pudu/Compiler/Program/Eval/DataSpec.hs`, `test/ios-simulator.mjs`, `test/ios-foreign-apps.mjs`

## Known limits

The Android path has not run on a device or an emulator. Its evidence is the source of [[PuduNotify]], [[PuduAuth]] and [[PuduMedia]]. Android alarms are inexact, so a reminder may arrive late. The iOS simulator has no passcode, so AUTHENTICATED reports false there, and no accelerometer, so SENSED never arrives. The picked-image copy lives in the temporary directory, which the platform may clear.

## Exact next action

Run [[Toolbox Example]] on an Android device: confirm the reminder notification and its tap, biometric confirmation, speech, a picked photo, and the browser's return.

## Referenced by

[[handoffs/_MOC]] · [[Std Mobile Request]] · [[Std Mobile Notify]] · [[Std Mobile Auth]] · [[Std Mobile Media]] · [[Std Mobile Paging]] · [[Toolbox Example]] · [[Uses Mobile Services]] · [[Uses Mobile List]] · [[NATIVE-MOBILE]]
