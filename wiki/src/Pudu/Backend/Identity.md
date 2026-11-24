---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Identity.hs"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Backend]]"
tags: [module, backend, mobile, identity, manifest, link]
aliases: [Pudu Backend Identity, Backend Identity]
---

# Pudu Backend Identity

## Purpose and interface

Settles an application's identity against the `[app]` table of the manifest: the name people see, the reverse-DNS identifier, the version people read, the build number stores require to rise, and the URL schemes the application opens. It runs at build time, before either platform's bundle or package is written. The table is read by [[Compiler Manifest]] as `manifestApp`. The module is called by the program build in `app/Main.hs`, which passes the settled identity to [[Backend Toolchain App]] for the iOS bundle and to [[Backend Toolchain Android]] for the application package.

```text
defaultIdentity   :: Text -> Text -> Identity
settleIdentity    :: Identity -> [(Text, Text, Int)] -> Either [IdentityProblem] Identity
```

`Identity` has six fields: `identityName`, `identityIdentifier`, `identityVersion`, `identityBuild`, `identitySchemes` and `identityDeclared`. `IdentityProblem` has three fields: `problemKey`, `problemLine` and `problemReason`.

## Behavior

- `defaultIdentity name identifier` is the identity of an application with no `[app]` table: the name and identifier as given, version `1.0`, build `1`, no schemes, and `identityDeclared` false. The build passes the file name as the name and `org.pudu.<name>` as the identifier.
- `settleIdentity` takes the defaults and the table's entries as key, value as written and line. It folds over the entries in written order. A valid value replaces its field. A refused value keeps the field as it was and adds a problem. The result is `Left` with the problems in written order when any value is refused, else `Right` with the settled identity.
- `name` is stripped of surrounding space and quotes. An empty name is refused.
- `identifier` is two or more dot-separated segments. Each segment is ASCII letters, digits and hyphens and starts with a letter. A valid identifier sets `identityDeclared`.
- `version` is one to three dot-separated numbers, each made of digits. `1.4` and `1.4.2` are valid. `1.2.3.4` is refused.
- `build` is a whole number from 1 to 2100000000.
- `schemes` is one value or a list in brackets. Each scheme is a letter followed by letters, digits, `+`, `.` or `-`. A scheme is stored lowercased. Empty list items are dropped.
- Values may be quoted with double or single quotes. Quotes are removed before checking.
- An unknown key is a problem, with the message that lists the five keys.
- A problem's text is the reason only. The build joins it to the key and line in E6018 of [[Pudu Diagnostic]].

## Invariants

- A settled identity has a non-empty name, a valid identifier, a valid version, a build in range and only valid schemes. No value the build passes on is normalized into a different one.
- The result is `Right` exactly when the problem list is empty. Each problem names the key and line of the entry that caused it.
- `identityDeclared` is true only when the manifest named a valid identifier.

## Negative Logic

- No normalizing of an invalid value. A value a store would refuse is a problem, and the build stops before a bundle is written.
- No network or store check. The build checks the shape of each value only; it does not ask a store whether an identifier is free.
- No change to the program's name. The executable and the bundle path keep the program's file name whatever the display name is.
- No default for an unknown key. A misspelled key is refused rather than ignored.

## Dependencies and consumers

Depends on [[Compiler Manifest]] only through its caller: the module takes the entries as plain values and does not read the manifest itself. Consumers: [[Backend Toolchain App]], which writes the identity into `Info.plist`; [[Backend Toolchain Android]], which writes it into the package manifest; [[Native Diagnostics]] and [[Pudu Diagnostic]], which build E6018 from each problem; the program build in `app/Main.hs`; the tests [[Identity Spec]] and `test/Pudu/Backend/AppSpec.hs`.

## Resolved Grill Log

- **Q:** Why refuse an identifier, version, build or scheme instead of normalizing it? **A:** A store would reject the value at upload, after the bundle is built and signed. Normalizing it silently would ship a value the person did not write, such as an identifier that installs over a different application. The build should say so first, with the line that holds the value, so the person changes the manifest. _Rejected:_ rewriting an identifier or lowercasing a version without telling the person.
- **Q:** Why a `declared` flag? **A:** Android keeps deriving its package from the label unless the identifier is named, so an existing application keeps the package it already has. Without the flag, adding the identifier later would silently change the package of an application that already shipped. The flag is false for an application with no `[app]` table or with no identifier.
- **Q:** Why is the build number separate from the version? **A:** Stores compare the build number, which must rise with every upload. The version is what people read and moves at release. One field would force a version bump for each upload, or a build number that repeats and is refused by the store.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Toolchain App]] · [[Backend Toolchain Android]] · [[Compiler Manifest]] · [[Native Diagnostics]] · [[Identity Spec]] · [[Links Example]] · [[Native App Identity]] · [[NATIVE-MOBILE]]
