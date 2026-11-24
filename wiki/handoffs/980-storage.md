---
type: handoff
status: ACTIVE
issue: 980
aliases: [Native Storage]
---

# Native Storage

Implementer owns persistent and secure storage and the public integer parser. Role transition: the Language Architect's contract for `Stored(UInt32, Option[Str])` in [[Std Mobile View]], STORED 31 in [[Std Mobile Events]] and STORE_READ 55, STORE_WRITE 56 and STORE_REMOVE 57 in [[Std Mobile Stream]] is taken as fixed for this slice. Independent Language Architect review and Forensic Guardian wiki-parity review are pending.

## Scope

`Std.Mobile.Storage` with the Plain and Secure places; the iOS host on user defaults and the keychain ([[pudu-ios-storage]]); the Android host on SharedPreferences and AES-GCM under the Keystore ([[PuduStore]]); `Std.Num.parseInt` and `parseIntIn`, with the private copies in `Std.Text`, `Std.Cron`, `Std.Ui.Desktop` and `Std.Ui.Accessible` delegating to it; the self-test table of the iOS host and the Security link.

## Owned files

- `packages/pudu/v0.1/lib/Std/Mobile/Storage.pudu`, `lib/Std/Num.pudu`, `lib/Std/Text.pudu`, `lib/Std/Cron.pudu`, `lib/Std/Ui/Desktop.pudu`, `lib/Std/Ui/Accessible.pudu`
- `packages/pudu/v0.1/cbits/pudu_ios_storage.h`, `cbits/pudu_ios_host.m`
- `packages/pudu/v0.1/android/org/pudu/PuduStore.java`
- `packages/pudu/v0.1/src/Pudu/Backend/Toolchain/App.hs`, `Toolchain/HostSources.hs`, `pudu.cabal`
- `examples/mobile/Vault.pudu`
- `test-fixtures/stdlib/UsesMobileStorage.pudu`, `test-fixtures/stdlib/UsesNumParse.pudu`
- `test/Pudu/Compiler/Program/Eval/DataSpec.hs`

## Known limits

The Android path has not run on a device or an emulator. Its evidence is the source of [[PuduStore]]. The iOS run of [[Vault Example]] is the only run path recorded here; its relaunch result is not yet recorded. The values written by `Vault` are kept until the application is removed, so a reinstall check is part of the next action.

## Exact next action

Run [[Vault Example]] on an Android device, confirm that the secure token survives a relaunch, then uninstall the application, reinstall it, and confirm the token reads `missing` and the launch count restarts at 1. Record both results in [[PuduStore]].

## Referenced by

[[handoffs/_MOC]] · [[Std Mobile Storage]] · [[pudu-ios-storage]] · [[PuduStore]] · [[Std Num]] · [[Vault Example]] · [[Uses Mobile Storage]] · [[Uses Num Parse]] · [[NATIVE-MOBILE]]
