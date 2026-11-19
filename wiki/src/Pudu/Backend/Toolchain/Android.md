---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Toolchain/Android.hs"
fidelity: Active
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, toolchain, mobile, android]
aliases: [Backend Toolchain Android]
---

# Backend Toolchain Android

## Purpose and interface

Builds Android targets through the NDK and the SDK's build tools. It produces two
products: a static library and header for a host project ([[Backend Toolchain Library]]
covers the Apple counterpart), and an application package that holds the program linked
with the embedded host ([[Native Toolchain Host Sources]]) as `libpudu_app.so`. The
compiler writes the package; it never installs or runs it.

```haskell
data AndroidTools = AndroidTools
  { toolClang :: !FilePath, toolArchiver :: !FilePath
  , toolAbi :: !String, toolSdk :: !(Maybe FilePath) }

androidAbi :: Text -> Maybe (String, String)
androidTools :: Text -> Bool -> IO (Either ToolchainFailure AndroidTools)
compileAndroidLibrary :: AndroidTools -> Text -> [Text] -> FilePath
  -> IO (Either ToolchainFailure ([Text], Text))
compileApk :: AndroidTools -> Text -> [Text] -> Text -> FilePath
  -> IO (Either ToolchainFailure Text)
packageManifest :: Bool -> Text -> Text
packageLinkFlags :: Bool -> [String]
```

## Test builds (#951)

A package is a test build only when `PUDU_ANDROID_TEST_BUILD` is set to a
non-empty value while it is built. Only a test build is linked with
`--debug-mode` (`packageLinkFlags`) and carries the
`org.pudu.selftest` meta-data marker in its manifest (`packageManifest`).
A release package is neither debuggable nor marked.

Resolved Grill Log: the launcher activity is exported, so a self-test switch
any application can send must not be decided by a flag every build sets.
The build decides; the activity checks what the build recorded.

Links: [[Native Android Activity]] · [[Backend Toolchain App]] · [[Backend Toolchain Library]] · [[Native Toolchain Host Sources]]

## Algorithm and invariants

- `androidAbi` maps `android-arm64` to `arm64-v8a` with the triple
  `aarch64-linux-android24`, and `android-x86_64` to `x86_64` with
  `x86_64-linux-android24`. Any other target is `ToolchainTargetUnbuilt`.
- `androidTools` locates the NDK from `ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT`, else
  the newest version under the SDK's `ndk` directory. The SDK comes from
  `ANDROID_HOME` or `ANDROID_SDK_ROOT`, else the platform's usual location. The NDK
  clang for the triple and `llvm-ar` must exist. Each missing piece is
  `ToolchainSdkMissing` naming the target and what was absent. An application
  build also requires the SDK.
- Library build (`compileAndroidLibrary`), staged beside the output:
  1. The emitted unit is written as C and compiled with the shared compiler flags
     plus `-fPIC`.
  2. `llvm-ar rcs` archives the object.
  3. The header is written with the link options (`-lz` only when the unit carries
     the compression marker) and the export prototypes, then both products are
     renamed onto the output and beside it.
- Application build (`compileApk`) requires the platform directory, the newest build
  tools, and `javac`, `jar` and `keytool` on `PATH`. The steps run in order, stopping
  at the first failure, and the output of each step that printed anything is kept as
  warnings:
  1. The clang shared library `libpudu_app.so` is linked from the host source, the
     static library and `-llog -landroid`.
  2. `javac` compiles the bridge classes against `android.jar` for Java 11.
  3. `d8` dexes the classes at minimum API 24.
  4. `aapt2 link` builds the base package from the manifest against `android.jar`.
  5. `jar` adds `classes.dex` and stores the `lib` directory uncompressed.
  6. `zipalign -P 16 -f 4` aligns the package.
  7. `keytool` makes a fresh RSA 2048 key for the build in a new keystore.
  8. `apksigner sign` writes the signed package.
- The package is published by renaming the signed file onto the output. Every
  staging directory is removed on every path.
- The manifest label is escaped for XML. The package segment is derived from the
  program's name: ASCII letters and digits only, lower-cased, a leading digit
  prefixed with `p`, and `app` when nothing remains.

## Negative Logic

- No `PUDU_CC` for an Android target: the NDK clang for the triple is the only compiler
  that knows its system root.
- No application without an Android SDK, a platform, build tools and a Java
  development kit. Each absence is named before any tool runs.
- No partial package or library at the output path: a failed step leaves the output
  untouched.

## Dependencies and consumers

[[Backend Toolchain Library]], [[Backend Toolchain Process]], [[Backend Emit Entry]],
[[Native Host Compression]], [[Native Toolchain Host Sources]], [[Backend Toolchain App]]
(the Apple application counterpart). Consumed by [[Pudu CLI]] for Android builds. The
activity that the package launches is described in [[Native Android Activity]].

## Resolved Grill Log

- **Q:** Why build the shared library with the NDK clang rather than the host compiler?
  **A:** The NDK clang carries the system root and the API 24 triple. _Rejected:_ a host
  compiler with a sysroot flag, which would not pin the API level.
- **Q:** Why a fresh key per build? **A:** The package is for local and test use, so
  the keystore is created inside the staging directory and discarded with it.
  _Rejected:_ a stored signing key in the repository.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native Mobile Targets]]

## Permission entries (#976)

The `uses-permission` entries of the declared kinds are inserted before `<application>` in the package manifest. A permission an older API level needs only is bounded with `android:maxSdkVersion`, so storage and Bluetooth access the newer levels replace are not requested there. The entries come from [[Pudu Backend Permissions]].
