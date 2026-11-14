---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Toolchain/Library.hs"
fidelity: Active
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, toolchain, mobile]
aliases: [Backend Toolchain Library]
---

# Backend Toolchain Library

## Purpose and interface

Builds an emitted unit with an embedded entry into a static library and its
header for a mobile target ([[Native Mobile Targets]]).

```haskell
data LibraryRequest = LibraryRequest
  { librarySource :: !Text, libraryOutput :: !FilePath, libraryTarget :: !NativeTarget }
data LibraryProducts = LibraryProducts
  { libraryHeader :: !FilePath, libraryLinks :: ![Text], libraryWarnings :: !Text }

compileLibrary :: LibraryRequest -> IO (Either ToolchainFailure LibraryProducts)
```

## Algorithm and invariants

- Apple: `PUDU_XCRUN` when set, else `xcrun` on `PATH`; absent is
  `ToolchainSdkMissing target "xcrun"`. Within the deadline,
  `xcrun --sdk <sdk> --show-sdk-path`, `--find clang` and `--find libtool`
  each answer one line; a failure, empty answer or timeout is
  `ToolchainSdkMissing` with the command and what it printed.
- In a temporary directory beside the output: the unit is written as C, the
  compiler runs `-std=c11 -O2 -Wall -Wextra -target <triple> -isysroot <root>
  -c`, then `libtool -static` archives the object. Both run through
  [[Backend Toolchain Process]].
- The archive is renamed onto the output, then the header (from
  [[Backend Emit Entry]]) is written to a temporary file and renamed onto
  `pudu_program.h` beside it. The temporary directory is removed on every path.
- `libraryLinks` is `-lz` when the unit carries the compression marker; the
  header names the same libraries. Captured compiler and archiver output is the
  warnings payload.
- Android: `ANDROID_NDK_HOME`, then `ANDROID_NDK_ROOT`; neither naming a
  directory is `ToolchainSdkMissing`; a present NDK is
  `ToolchainTargetUnbuilt`.

## Negative Logic (Prohibited Paths)

- No `PUDU_CC` for a mobile target: the platform SDK's own compiler is the only
  one that knows its system root.
- Reject an output named `pudu_program.h` before SDK discovery. A failed
  compile or archive leaves the output untouched. Each product is renamed
  atomically. A host should build each library slice in its own directory.
- No refusal decisions here; [[Backend Native Target]] decides before this runs.

## Dependencies and consumers

[[Backend Native Target]], [[Backend Toolchain Process]], [[Backend Emit Entry]],
[[Native Host Compression]]; `directory`, `filepath`, `process`, `temporary`.
Exercised by [[Backend Native Target Tests]].

## Resolved Grill Log

- **Q:** Why compile to an object and archive rather than one compiler call?
  **A:** A static library is an archive of objects; the archiver is the tool
  that writes it with a symbol table the linker reads. _Rejected:_ shipping the
  object alone, which Xcode links but cannot manage as a library.
- **Q:** Why `PUDU_XCRUN`? **A:** Tests on hosts without Xcode point it at a
  scripted `xcrun` to exercise `E6007` without the SDK, as `PUDU_CC` does for
  the host compiler. _Rejected:_ probing `/Applications` for Xcode.
- **Q:** Why is the header renamed after the archive? **A:** A reader who sees
  the header can rely on the library beside it being the one it declares.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native Mobile Targets]]
