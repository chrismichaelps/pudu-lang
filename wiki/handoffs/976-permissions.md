---
type: handoff
status: ACTIVE
issue: 976
aliases: [Native Permissions]
---

# Native Permissions

Implementer owns declared, build-checked permissions: the `[app.permissions]` table, the permission requests on the iOS and Android hosts, their stream instructions and report, and the example that exercises them. Role transition: the Language Architect owns the public contract in [[Std Mobile Permission]], [[Std Mobile Stream]], [[Std Mobile Events]] and [[Std Mobile View]]; the Implementer takes the contract as fixed. Independent Language Architect review and Forensic Guardian wiki-parity review are pending.

## Scope

Instructions PERMISSIONS 51, PERMISSION 52 and SETTINGS 53; event PERMISSIONED 28. Build checks E6014, E6015, E6016 and warning W6017 from [[Pudu Backend Permissions]]. Numbering as in [[NATIVE-MOBILE]].

## Owned files

- `packages/pudu/v0.1/lib/Std/Mobile/Permission.pudu`, `Stream.pudu`, `Events.pudu`, `View.pudu`
- `packages/pudu/v0.1/src/Pudu/Backend/Permissions.hs`, `src/Pudu/Compiler/Manifest.hs`, `src/Pudu/Backend/Toolchain/App.hs`, `src/Pudu/Backend/Toolchain/Android.hs`, `src/Pudu/Backend/Toolchain/HostSources.hs`
- `packages/pudu/v0.1/cbits/pudu_ios_permission.h`, `cbits/pudu_ios_host.m`, `cbits/pudu_ios_events.h`, `cbits/pudu_android_host.c`, `cbits/pudu_android_kinds.h`, `cbits/pudu_android_events.h`
- `packages/pudu/v0.1/android/org/pudu/PuduPermission.java`, `android/org/pudu/PuduBridge.java`
- `examples/mobile/permissions/`, `test-fixtures/stdlib/UsesMobilePermission.pudu`, `test/Pudu/Backend/PermissionsSpec.hs`

## Known limits

Neither the Android permission path nor the always-location and never-ask-again paths have run on a device or emulator. The iOS paths have run on the simulator only with the privacy presets of [[Permissions Example]].

## Exact next action

Run the Permissions example on an Android device or emulator, including the never-ask-again path: deny the camera twice with "don't ask again" checked, relaunch, and record `Camera: Blocked` in [[Permissions Example]].

## Referenced by

[[handoffs/_MOC]] · [[Std Mobile Permission]] · [[pudu-ios-permission]] · [[PuduPermission]] · [[Pudu Backend Permissions]] · [[Permissions Example]] · [[Uses Mobile Permission]] · [[NATIVE-MOBILE]]
