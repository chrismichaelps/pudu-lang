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
  , appExports :: ![Text], appName :: !Text, appIdentifier :: !Text
  , appIdentity :: !Identity }

compileApp :: AppRequest -> IO (Either ToolchainFailure Text)
infoPlist :: Text -> Identity -> [(Text, Text)] -> Text
bundleIdentifier :: Text -> Text
```

## Algorithm and invariants

- Before step 1, the installed Xcode and the simulator SDK are probed
  ([[Backend Toolchain Probe]]) and assessed against [[Backend Ledger]] with today's
  date and the Development purpose. A refusing finding fails the build with
  `ToolchainOutsideLedger`; warning findings are returned with the build's warnings.
- The minimum system version in `Info.plist` is the ledger's deployment target, passed in
  as the third argument of `infoPlist`.
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
     libraries the program declares, and `-framework UIKit -framework Foundation -framework QuartzCore`.
  4. `Info.plist` is written from `infoPlist appName appIdentity` and the usage keys of the declared permissions.
  5. The bundle is signed ad hoc with `codesign --force --sign -`.
- `infoPlist` writes the bundle identifier, the executable name, the application name,
  package type `APPL`, the display name, build number and version from the identity, minimum system from [[Backend Ledger]] (`15.0` today), the
  `iPhoneSimulator` platform, the iPhone and iPad device families, and an empty launch
  screen. It sets the Boolean `CADisableMinimumFrameDurationOnPhone` to true to enable
  higher-rate Core Animation timing hints on capable iPhones. Every text value is escaped for XML.
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

- **Q:** Does bundle opt-in set a refresh rate? **A:** Core Animation still selects the rate
  for the display and content. This key permits higher-rate hints. See [[Pudu Native iOS UI]].

- **Q:** Why embed the host instead of shipping it as a data file? **A:** The release
  archive stages only library sources, and an embedded host always matches the compiler
  that wrote the program. _Rejected:_ a host file looked up beside the library.
- **Q:** Does an `.app` suffix authorize deleting an existing directory? **A:** No.
  Publish only to a vacant path, with exclusivity enforced by the macOS rename.
  _Rejected:_ recursive deletion or a separate existence check before an ordinary rename.
- **Q:** Why only the simulator? **A:** A device application must be signed with an
  identity the machine's owner chooses; that arrives with signed store builds.
  _Rejected:_ guessing an identity.

## Pickers and system touches (#991)

Frameworks linked always for the pickers: ContactsUI, Contacts and UniformTypeIdentifiers, alongside AVFoundation. See [[pudu-ios-pick]].

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native App Delivery]] · [[Native App Tests]] · [[iOS Host Adapter]] · [[Native Mobile Targets]]

## iOS layout staging (#919)

Resolved Grill Log: materialize the embedded layout header alongside the host translation unit in the existing include directory and link CoreGraphics for the geometry checks. No second compiler invocation is needed. See [[iOS Host Layout]].

- **Q:** Why link QuartzCore? **A:** The host reads the media clock for first-frame timing and self-test deadlines, and display-link frame pacing needs the same framework.

## Permission declarations (#976)

The declared permissions of [[Pudu Backend Permissions]] add to the bundle. Each declared kind's usage keys are written into `Info.plist` with the reason the person reads, so a kind the application declares has its prompt text and one it does not declare has none. The compile flags `-DPUDU_PERMISSION_<KIND>=1` select the host code of each declared kind, and the frameworks of those kinds are linked after the base frameworks.

## Device framework (#983)

The iOS link adds the Network framework to `hostFrameworks`, for the path monitor that [[pudu-ios-device]] reads for reachability. The Android side needs only the `ACCESS_NETWORK_STATE` declaration in the manifest, which [[PuduDevice]] documents.

## Service frameworks (#989)

The iOS host always links LocalAuthentication, SafariServices, AVFoundation, PhotosUI, CoreMedia and CoreMotion, in `hostFrameworks`. No program needs to request them; the host sources decide their use. CoreMedia supplies the time constants of the video and audio host code (#990).
