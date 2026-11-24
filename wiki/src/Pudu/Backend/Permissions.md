---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Permissions.hs"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Backend]]"
tags: [module, backend, mobile, permission, manifest]
aliases: [Pudu Backend Permissions, Backend Permissions]
---

# Pudu Backend Permissions

## Purpose and interface

Settles an application's declared permissions against the kinds its program requests, and derives the platform declarations each declared kind needs. It runs at build time, after the program is lowered and before either platform's bundle or package is written. The declarations come from the `[app.permissions]` table of the manifest, read by [[Compiler Manifest]]. The module is called by [[Backend Toolchain App]] for the iOS bundle and by [[Backend Toolchain Android]] for the application package.

```text
requestedKinds      :: CoreModule -> Set PermissionKind
settlePermissions   :: [(Text, Text, Int)] -> Set PermissionKind -> ([PermissionProblem], [Permission], [Text])
kindNamed           :: Text -> Maybe PermissionKind
appleUsageKeys      :: [Permission] -> [(Text, Text)]
appleFlags          :: [Permission] -> [Text]
appleFrameworks     :: [Permission] -> [Text]
androidEntries      :: [Permission] -> [Text]
```

`PermissionKind` has the eleven kinds of [[Std Mobile Permission]]. `Permission` pairs a kind with its reason. `PermissionProblem` has three constructors: `Undeclared`, `Unknown` and `ReasonMissing`.

## Behavior

- `requestedKinds` scans the lowered program for constructions of `Std.Mobile.Permission.Kind` values. A construction counts only in a function outside the permission module. The scan is one generic traversal of the core IR, which derives `Data`; span values are opaque to it.
- `settlePermissions` takes the manifest entries as key, reason and line, and the requested set. It returns the problems that refuse the build, the declared permissions, and the keys declared but never requested.
- An entry whose key names no kind is `Unknown`, with its key and line. An entry with an empty or blank reason is `ReasonMissing`. A requested kind with no entry is `Undeclared`, named by its key.
- A declared kind that is never requested is not a problem. It is listed in the third result, and the build reports it as warning W6017.
- `appleUsageKeys` maps each declared kind to its Info.plist usage keys with the reason. When two kinds share a key, the first kind's reason is kept.
- `appleFlags` gives one compile flag per declared kind: `-DPUDU_PERMISSION_<KIND>=1`.
- `appleFrameworks` gives the frameworks each declared kind's host code links, without duplicates.
- `androidEntries` gives one `uses-permission` line for each Android permission the declared kinds need, sorted by name. An entry bounded by `maxSdkVersion` names its bound.

Declaration table, per kind:

| Kind | Manifest key | iOS usage keys | Compile flag | Framework | Android permissions |
|---|---|---|---|---|---|
| Camera | camera | NSCameraUsageDescription | PUDU_PERMISSION_CAMERA | AVFoundation | CAMERA |
| Microphone | microphone | NSMicrophoneUsageDescription | PUDU_PERMISSION_MICROPHONE | AVFoundation | RECORD_AUDIO |
| Photos | photos | NSPhotoLibraryUsageDescription | PUDU_PERMISSION_PHOTOS | Photos | READ_MEDIA_IMAGES, READ_MEDIA_VISUAL_USER_SELECTED, READ_EXTERNAL_STORAGE (max 32) |
| PhotosAdd | photos-add | NSPhotoLibraryAddUsageDescription | PUDU_PERMISSION_PHOTOS_ADD | Photos | WRITE_EXTERNAL_STORAGE (max 28) |
| Location | location | NSLocationWhenInUseUsageDescription | PUDU_PERMISSION_LOCATION | CoreLocation | ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION |
| LocationAlways | location-always | NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription | PUDU_PERMISSION_LOCATION_ALWAYS | CoreLocation | the location pair, ACCESS_BACKGROUND_LOCATION |
| Notifications | notifications | none | PUDU_PERMISSION_NOTIFICATIONS | UserNotifications | POST_NOTIFICATIONS |
| Contacts | contacts | NSContactsUsageDescription | PUDU_PERMISSION_CONTACTS | Contacts | READ_CONTACTS |
| Calendar | calendar | NSCalendarsFullAccessUsageDescription, NSCalendarsUsageDescription | PUDU_PERMISSION_CALENDAR | EventKit | READ_CALENDAR, WRITE_CALENDAR |
| Bluetooth | bluetooth | NSBluetoothAlwaysUsageDescription | PUDU_PERMISSION_BLUETOOTH | CoreBluetooth | BLUETOOTH_CONNECT, BLUETOOTH_SCAN, BLUETOOTH (max 30) |
| Motion | motion | NSMotionUsageDescription | PUDU_PERMISSION_MOTION | CoreMotion | ACTIVITY_RECOGNITION |

## Invariants

- A kind is declared on iOS by its usage keys, compile flag and framework together, and on Android by its permission entries. An application carries no API for a kind it did not declare.
- The settled set is the requested set minus the declared set, and the problems list is empty only when no request is undeclared, no key is unknown and no reason is blank.
- Each Android permission appears once in the output, with the highest bound any declared kind gives it.

## Negative Logic

- No use of a permission string the program does not construct. A usage string with no request is reported, and review rejects it.
- No scan inside the permission module. Its decode tables construct every kind to read host reports; counting them would mark every kind requested.
- No request by the build itself. The build only checks; the program asks at run time through [[Std Mobile Permission]].
- No default reason. A reason is the text the person reads, and the build does not invent one.

## Dependencies and consumers

Depends on [[Core]] for the core IR types, which derive `Data`, and on [[Compiler Manifest]] for the parsed `[app.permissions]` entries. Consumers: [[Backend Toolchain App]], which writes the usage keys, flags and frameworks into the iOS build; [[Backend Toolchain Android]], which writes the manifest entries before `<application>`; the native diagnostics of [[Pudu Diagnostic]], which builds E6014, E6015, E6016 and W6017; the tests [[Permissions Spec]].

## Resolved Grill Log

- **Q:** Why is reachability from `main` the source of truth for requests? **A:** A program can only request a kind it constructs, and lowering keeps only what `main` reaches. A kind that is declared but never reached is not requested, and the warning says so. Scanning the source text would count a kind in a comment or in an unused function. Review rejects a usage string with no request, so the build must be able to name the request that justifies each one. _Rejected:_ grepping the source for `Permission.` names, which misses a kind a library builds and counts one only written in a comment.
- **Q:** Why are the permission module's own functions excluded? **A:** Its decode tables build every kind so that a host report can be read back as a kind. Those constructions are the module's own bookkeeping, not a request by the program. Excluding the module by name keeps the scan one rule with one exception, and the exception is documented here.
- **Q:** Why per-kind compile flags and frameworks? **A:** An application carries no API it did not declare. A flag per kind lets the host source leave out the code for an undeclared kind, and a framework is linked only when some declared kind needs it. A single flag for all permissions would link every framework into every application, and a reviewer could not see from the bundle what the application can ask for.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Toolchain App]] · [[Backend Toolchain Android]] · [[Compiler Manifest]] · [[Native Diagnostics]] · [[Std Mobile Permission]] · [[Permissions Spec]] · [[NATIVE-MOBILE]]
