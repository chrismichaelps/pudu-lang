---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Toolchain/App.hs"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, toolchain, mobile, ios]
aliases: [Backend Toolchain App]
---

# Backend Toolchain App

## Purpose and interface

Builds a runnable application bundle for a native target from a Pudu program. The
bundle is the program's static library ([[Backend Toolchain Library]]) linked with the
embedded iOS host ([[iOS Host Adapter]]), a generated `Info.plist`, and an ad-hoc
signature. The compiler writes the bundle; it never runs on the device.

```haskell
data AppRequest = AppRequest
  { appSource :: !Text, appOutput :: !FilePath, appTarget :: !NativeTarget
  , appExports :: ![Text], appName :: !Text, appIdentifier :: !Text }

compileApp :: AppRequest -> IO (Either ToolchainFailure Text)
infoPlist :: Text -> Text -> Text
bundleIdentifier :: Text -> Text
```

## Algorithm and invariants

- Only the simulator SDK is built. Any other target, including a device target, is
  `ToolchainTargetUnbuilt` before any tool runs.
- SDK paths and tools come from [[Backend Toolchain Library]] (`appleTools` and
  `invoke`), so SDK resolution and tool invocation match the library build.
- In a temporary directory beside the output:
  1. The program's static library and header are built with `compileLibrary`, using
     `appExports` as the exported prototypes.
  2. The embedded iOS host source is written beside them.
  3. The SDK's own clang compiles and links the host into `<Name>.app/<Name>` with
     `-fobjc-arc`, the simulator target triple, the system root, the library, the
     libraries the program declares, and `-framework UIKit -framework Foundation`.
  4. `Info.plist` is written from `infoPlist appName appIdentifier`.
  5. The bundle is signed ad hoc with `codesign --force --sign -`.
- `infoPlist` writes the bundle identifier, the executable name, the application name,
  package type `APPL`, version `1` and short version `1.0`, minimum system `15.0`, the
  `iPhoneSimulator` platform, the iPhone and iPad device families, and an empty launch
  screen. Every text value is escaped for XML.
- `bundleIdentifier name` is `org.pudu.` followed by the name with every character
  outside ASCII letters, digits, `-` and `.` replaced by `-`.
- Compiler, linker and signer output is returned as the warnings text, as in
  [[Backend Toolchain Library]].
- Publish the signed staging bundle on macOS with an exclusive rename. An occupied
  destination produces `E6006` and names the output path. If two builds race, only one
  can publish there.

## Negative Logic

- No device application: it needs a signing identity the machine's owner chooses, so
  a device target is refused as a target not yet built.
- No Android target.
- No partial bundle at the output path: a failed stage leaves the output untouched.
- An existing output path is refused. Select a free path or move the previous bundle
  before rebuilding.

## Dependencies and consumers

[[Backend Toolchain Library]], [[Backend Native Target]], [[Native Toolchain Host Sources]],
[[Backend Toolchain Process]]. Consumed by [[Pudu CLI]] through `pudu build --app`, and by
the simulator run [[iOS Simulator Run]].

## Resolved Grill Log

- **Q:** Why embed the host instead of shipping it as a data file? **A:** The release
  archive stages only library sources, and an embedded host always matches the compiler
  that wrote the program. _Rejected:_ a host file looked up beside the library.
- **Q:** Does an `.app` suffix authorize deleting an existing directory? **A:** No.
  Publish only to a vacant path, with exclusivity enforced by the macOS rename.
  _Rejected:_ recursive deletion or a separate existence check before an ordinary rename.
- **Q:** Why only the simulator? **A:** A device application must be signed with an
  identity the machine's owner chooses; that arrives with signed store builds.
  _Rejected:_ guessing an identity.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native App Delivery]] · [[Native App Tests]] · [[iOS Host Adapter]] · [[Native Mobile Targets]]

## iOS layout staging (#919)

Resolved Grill Log: materialize the embedded layout header alongside the host translation unit in the existing include directory and link CoreGraphics for the geometry checks. No second compiler invocation is needed. See [[iOS Host Layout]].
