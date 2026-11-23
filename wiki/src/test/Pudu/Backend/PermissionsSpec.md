---
type: module
path: "@root/test/Pudu/Backend/PermissionsSpec.hs"
fidelity: Active
tags: [module, test, backend, toolchain, permission]
aliases: [Permissions Spec, Test Backend Permissions]
---

# Permissions Spec

## Purpose and interface

Property tests of [[Pudu Backend Permissions]] and the manifest table it reads: which permissions an application declares, which requests they cover, and the platform declarations each kind writes. The module exports `permissionProperties`, a list of named properties that the test runner executes once each.

## Properties

1. The manifest's permission table is read in written order: `camera` on line 4 and `motion` on line 5, each with its reason.
2. Declared permissions that cover every request build: a camera request with a camera declaration gives no problem, and a contacts declaration never requested is reported as unused.
3. An undeclared request, an unknown key and a missing reason refuse the build, with exactly those three problems: `Unknown "camra"` on line 3, `ReasonMissing "contacts"` on line 4, and `Undeclared "camera"`.
4. Each kind writes its declarations: the key `photos-add` names PhotosAdd and `camra` names nothing; location-always writes both its usage keys with the reason, the flag `-DPUDU_PERMISSION_LOCATION_ALWAYS=1`, and three Android entries with location; photos writes the Photos framework; storage access is bounded to level 32.
5. The property list and manifest carry the declarations: the usage key and its value reach the Info.plist text, with the value escaped, and the camera entry reaches the Android manifest before `<application>`.

## Invariants

- Each property compares an exact problem list, an exact declaration list, an exact key set or an exact text fragment, never only that a result is present.
- Properties take no files and no host. They test the pure settlement and the text writers.

## Negative Logic

- No compile or packaging run. The bundle and package contents are checked by the build tests of [[Backend Toolchain App]] and [[Backend Toolchain Android]].
- No platform prompt or host behavior. Those are checked by the simulator and device runs of [[Permissions Example]].

## Dependencies and consumers

Depends on [[Pudu Backend Permissions]], [[Backend Toolchain Android]] for `packageManifest`, [[Backend Toolchain App]] for `infoPlist`, and [[Compiler Manifest]] for `parseManifest` and `manifestPermissions`. Run by the backend test group of [[Main]].

## Resolved Grill Log

- **Q:** Why check the refusal problems as one exact list? **A:** Each refusal is a different rule. A test with one bad entry would pass if a different rule caught it, so the three problems are checked together and in order.
- **Q:** Why check the platform text rather than only the declarations? **A:** A declaration can be right while its text is written wrong, such as an unescaped reason that breaks the plist. The writers are the last step before the bundle, so their text is checked.

## Referenced by

[[src/test/_MOC]] · [[Pudu Backend Permissions]] · [[Assets Spec]] · [[NATIVE-MOBILE]]
