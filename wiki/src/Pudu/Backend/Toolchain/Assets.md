---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Toolchain/Assets.hs"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Backend]]"
tags: [module, backend, toolchain, mobile, assets]
aliases: [Backend Toolchain Assets, Application Assets]
---

# Backend Toolchain Assets

## Purpose and interface

Finds, checks and stages the files an application carries beside its code. The files live in an `assets` directory beside the entry module. They are packaged as they are, under the same relative names, so a program names an asset the same way on every platform. The iOS application bundle receives them in `<App>.app/assets/`. Android stages them and passes `-A` to aapt2, so the asset manager reads them by the same names. The module is called by [[Backend Toolchain App]] and [[Backend Toolchain Android]] before either packages anything.

```text
assetDirectory :: FilePath -> IO (Maybe FilePath)
assetFiles     :: FilePath -> IO (Either Text [FilePath])
stageAssets    :: FilePath -> [FilePath] -> FilePath -> IO ()
```

## Behavior

- `assetDirectory` returns `assets` beside the entry module when that directory exists, and nothing otherwise.
- `assetFiles` walks the directory and returns every regular file as a path relative to it, sorted by name. Directories are entered; anything that is neither a file nor a directory is skipped.
- A name is accepted only when each of its segments is non-empty, does not begin with a dot, and holds only ASCII letters, digits, dots, dashes and underscores. Any other name is refused with its relative path in the reason.
- A symbolic link anywhere under the directory is refused, naming its relative path.
- `stageAssets` copies each listed file to the same relative name under the destination, creating intermediate directories.

## Refusal

A refusal is `ToolchainAssetRefused`. It is reported as diagnostic E6013, `the application's assets cannot be packaged`, with the reason as its detail. Nothing is packaged when any asset is refused.

## Invariants

- The listing is the set of files that will be packaged. Staging copies only listed names, so nothing outside the listing reaches a bundle.
- A relative name is the only key a program uses for an asset. Two platforms read the same name, so the check runs before either platform is asked.
- The walk never follows a link, so the packaged set stays inside the assets directory.

## Negative Logic

- No renaming. A renamed asset would no longer match the name the program uses.
- No link following. A link is a path to a file outside the directory, and packaging it would copy content the program did not place there.
- No hidden files. A leading dot is a platform convention for metadata, and the loaders do not agree on whether to read it.
- No content check. The module does not decode files; decoding is the host's job at run time.

## Dependencies and consumers

Depends on the `directory` and `filepath` packages. Called by [[Backend Toolchain App]] when it builds an iOS bundle and by [[Backend Toolchain Android]] when it builds an application package. The refusal is built in [[Pudu Diagnostic Native]]. Runtime readers are [[pudu-ios-image]] on iOS and [[PuduImage]] on Android.

## Resolved Grill Log

- **Q:** Why refuse a name rather than rename it? **A:** A renamed asset would no longer match the name the program uses. The program would load a file that exists under a different name on one platform and not another, and the failure would appear only on the device. A refusal names the file at build time, where the author can change it. _Rejected:_ silent renaming to a safe form.
- **Q:** Why are symbolic links refused rather than followed? **A:** A link can point anywhere on the build machine. Following it would package content outside the application without the author placing it there. Refusing the link keeps the packaged set equal to the directory's contents. _Rejected:_ following links, and skipping them silently, which would hide a missing asset.
- **Q:** Why check names on the compiler side? **A:** Both platforms read names differently around case, normalization and separators. One check before packaging gives one answer for every target.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Toolchain App]] · [[Backend Toolchain Android]] · [[Pudu Diagnostic Native]] · [[NATIVE-MOBILE]]
