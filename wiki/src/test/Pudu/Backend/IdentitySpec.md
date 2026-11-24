---
type: module
path: "@root/test/Pudu/Backend/IdentitySpec.hs"
fidelity: Active
tags: [module, test, backend, toolchain, identity]
aliases: [Identity Spec, Test Backend Identity]
---

# Identity Spec

## Purpose and interface

Property tests of [[Pudu Backend Identity]] and the platform writers it feeds: the `[app]` table as read by [[Compiler Manifest]], the settled identity, the values a store would refuse, and the text each platform receives. The module exports `identityProperties`, a list of named properties that the test runner executes once each.

## Properties

1. The manifest's `[app]` table settles over the defaults. The table sets name `Pudu Links`, identifier `dev.pudu.my-links`, version `2.3.1`, build `42` and schemes `PuduLinks` and `pudu+x`. The settled identity is that table, with the schemes lowercased and the identifier marked declared. An empty table settles to the defaults unchanged.
2. Refusals name the key and line. An identifier `app` with one segment on line 2, a version `1.2.3.4` on line 3, a build `0` on line 4, a scheme `1x` on line 5 and an unknown key `color` on line 6 give exactly five problems, in that order, each with its key and line.
3. The platform text carries the identity. The `Info.plist` text has the identifier as `CFBundleIdentifier`, the name as `CFBundleDisplayName`, the version as `CFBundleShortVersionString`, the build as `CFBundleVersion`, and the schemes inside `CFBundleURLTypes`. The Android manifest text has the package `dev.pudu.my_links` with the hyphen written as an underscore, `versionCode` 42, `versionName` 2.3.1, the label `Pudu Links`, a `data` element for scheme `pudulinks`, and `singleTask` launch.
4. An application with no declared identifier writes the derived package and no placeholder. For program `Counter` with the default identity, the Android package is `org.pudu.counter`, and the manifest text holds no `PUDU_` placeholder.

## Invariants

- Each property compares an exact problem list, an exact field value or an exact text fragment, never only that a result is present.
- Properties take no files and no host. The writers are called with plain values and their text is compared.

## Negative Logic

- No manifest file is read by the spec. The `[app]` table is given as text and read through [[Compiler Manifest]] only to produce the entries.
- No store or device check. Whether a platform accepts the written identity is checked by the simulator and device runs of [[Links Example]].

## Dependencies and consumers

Depends on [[Pudu Backend Identity]], [[Backend Toolchain Android]] for `packageManifest`, [[Backend Toolchain App]] for `infoPlist`, and [[Compiler Manifest]] for `parseManifest` and `manifestApp`. Run by the backend test group of [[Main]].

## Resolved Grill Log

- **Q:** Why check the refusals as one exact list with keys and lines? **A:** The diagnostic prints the key and the line, so a test that counted refusals would pass with the wrong line. Each refusal is a different rule, and the exact list shows each rule catches its own value.
- **Q:** Why check the Android package by its text rather than by the identity alone? **A:** A declared identifier with a hyphen is not a legal Android package segment. The underscore rule is only visible in the written package, and the package is what the device installs under.
- **Q:** Why check that an undeclared application leaves no placeholder? **A:** The Android manifest is a template with `PUDU_` markers. A marker left in the output would install an application with a literal placeholder for its name or version, and the build would still succeed.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Pudu Backend Identity]] · [[Permissions Spec]] · [[Links Example]] · [[NATIVE-MOBILE]]
