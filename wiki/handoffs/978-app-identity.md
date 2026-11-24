---
type: handoff
status: ACTIVE
issue: 978
aliases: [Native App Identity]
---

# Native App Identity

Implementer owns the application identity and incoming links: the `[app]` table, the identity check, the platform writers for Info.plist and the Android manifest, the LINKED event and the link handling of the iOS and Android hosts. Role transition: the Language Architect's contract for `Linked(Str)` in [[Std Mobile View]] and LINKED 30 in [[Std Mobile Events]] is taken as fixed for this slice. Independent Language Architect review and Forensic Guardian wiki-parity review are pending.

## Scope

Manifest table `[app]` with name, identifier, version, build and schemes; E6018 for a value a store would refuse; LINKED 30 event carrying the URL as text; the Info.plist display name, version, build and URL types; the Android package, version code, version name, label, VIEW filters and singleTask launch; the link self-test on iOS. Numbering as in [[NATIVE-MOBILE]].

## Owned files

- `packages/pudu/v0.1/src/Pudu/Backend/Identity.hs`
- `packages/pudu/v0.1/src/Pudu/Backend/Toolchain/App.hs`, `Toolchain/Android.hs`
- `packages/pudu/v0.1/src/Pudu/Compiler/Manifest.hs`, `Pudu/Diagnostic/Native.hs`
- `packages/pudu/v0.1/app/Main.hs`
- `packages/pudu/v0.1/android/AndroidManifest.xml`, `android/org/pudu/PuduActivity.java`
- `packages/pudu/v0.1/cbits/pudu_ios_host.m`, `cbits/pudu_ios_system.h`, `cbits/pudu_ios_events.h`, `cbits/pudu_android_events.h`
- `packages/pudu/v0.1/lib/Std/Mobile/Events.pudu`, `lib/Std/Mobile/View.pudu`
- `test/Pudu/Backend/IdentitySpec.hs`, `test/Pudu/Backend/AppSpec.hs`, `test-fixtures/stdlib/UsesMobileSystem.pudu`, `test/ios-simulator.mjs`
- `examples/mobile/links/Links.pudu`, `examples/mobile/links/pudu.toml`

The changes to `test/Pudu/Backend/PermissionsSpec.hs` and `test/Pudu/Backend/TargetSpec.hs` are in the same working tree and are not described on this page.

## Known limits

The Android link path has not run on a device or an emulator. Its evidence is the source of [[Native Android Activity]] and the manifest writer of [[Backend Toolchain Android]]. The iOS self-test of [[Links Example]] is the only run path described; its result is not recorded here.

## Exact next action

Open a `pudulinks://` link on an Android device and confirm the label shows `Link: pudulinks://...` when the application is launched by the link and again while it is already running, then record both results in [[Links Example]].

## Referenced by

[[handoffs/_MOC]] · [[Pudu Backend Identity]] · [[Std Mobile Events]] · [[Std Mobile View]] · [[Links Example]] · [[Identity Spec]] · [[NATIVE-MOBILE]]
