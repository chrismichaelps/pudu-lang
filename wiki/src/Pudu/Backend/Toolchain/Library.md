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
  use the shared bounded runner and each answer one stdout line. A failure,
  empty or truncated answer, or timeout is
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
- Android: search the explicit NDK roots and NDKs installed under the
  Android SDK. The requested ABI selects its API 24 compiler and archiver.
  Build and publish a static archive and its generated header.

## iOS TLS provider (#935)

For a unit that selects TLS, set PUDU_IOS_OPENSSL_PREFIX to an OpenSSL
installation for the exact iOS target. It supplies include/openssl/ssl.h,
lib/libssl.a and lib/libcrypto.a. Build the dependency for the same device
or simulator slice with a deployment minimum of iOS 15.0 or earlier.
OpenSSL names the arm64 targets ios64-xcrun and iossimulator-arm64-xcrun.

The toolchain compiles the Apple trust path and links a temporary image to
check the platform and minimum OS before publishing. It folds OpenSSL's
static libraries into the output archive. The generated header's link
options include Security and CoreFoundation, which the app build consumes
directly. An absent or unusable provider is E6007.

Resolved Grill Log: the arm64 device and simulator use different
platforms. A successful target link proves the selected OpenSSL objects
belong to the requested slice. Units without TLS skip provider discovery.

## Android TLS provider (#935)

For a TLS unit, set PUDU_ANDROID_OPENSSL_PREFIX to the OpenSSL installation
for the requested API 24 ABI. The prefix supplies the same headers and
static libraries as the Apple prefix. A validation link checks the provider
before the archive is published. The archive contains the OpenSSL objects.

The host calls pudu_program_android_enable_tls with its process JavaVM
before pudu_program_run. An Android app also declares INTERNET access.
The function succeeds on first registration and on a repeat with the same
VM. [[Native Mobile TLS Trust]] verifies the server using Android's trust
manager and the app's trust configuration.

Resolved Grill Log: the native library works with a host-managed JavaVM.
Registration retains no thread-local JNI environment. The standalone app
builder from #937 still needs to invoke the registration.

## Negative Logic (Prohibited Paths)

- No `PUDU_CC` for a mobile target: the platform SDK's own compiler is the only
  one that knows its system root.
- Reject an output named `pudu_program.h` before SDK discovery. A failed
  compile or archive leaves the output untouched. Each product is renamed
  atomically. A host should build each library slice in its own directory.
- No refusal decisions here; [[Backend Native Target]] decides before this runs.

## Dependencies and consumers

[[Backend Native Target]], [[Backend Toolchain Process]], [[Backend Toolchain Probe]],
[[Backend Ledger]], [[Backend Emit Entry]], [[Native Host Compression]]; `directory`, `filepath`, `process`, `temporary`.
Consumed by [[Pudu CLI]] and [[Backend Native Target Tests]].

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

[[src/Pudu/Backend/_MOC]] · [[Native Mobile Targets]] · [[Pudu CLI]]

## Shared Apple tooling (#916)

The module now also exports `appleTools` and `invoke`. [[Backend Toolchain App]] uses
them for the same SDK resolution and tool invocation, so an application and a library
built for one target find the same SDK and run tools the same way.

## Platform preflight (#926)

Before any Apple compile, the library probes the installed Xcode and the SDK the target
names ([[Backend Toolchain Probe]]) and assesses them against [[Backend Ledger]] for today's
date. The Distribution purpose applies to the `iphoneos` SDK and the Development purpose to
the simulator. A refusing finding fails the build with `ToolchainOutsideLedger` carrying the
finding; warning findings are returned with the build's warnings text. A failed probe is
`ToolchainSdkMissing`, as before.

Resolved Grill Log: the probe runs before the compiler, so a toolchain outside the ledger is
reported as a version fact with its fix, not as a compiler error. _Rejected:_ letting the
compiler fail and matching its output.

## Export prototypes (#899)

`LibraryRequest` carries `libraryExports`, the prototypes the emitted unit
reported, and the published header declares them. Resolved Grill Log: the
header is generated from what was emitted, so it cannot name a function the
archive lacks.
