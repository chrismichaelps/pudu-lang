---
type: module
path: "@root/test/Pudu/Backend/TargetSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend, mobile]
aliases: [Backend Native Target Tests]
---

# Backend Native Target Tests

## Purpose and interface

`backendTargetProperties :: [(String, IO Property)]` holds
[[Native Mobile Targets]] to its contract. The pure target policy runs without a platform SDK.

## Algorithm and invariants

- Target names are exactly the four documented, each found by its own name;
  runtime-pack names and partial names are not targets.
- A program that runs a child program, emitted with the embedded entry, is
  refused on `ios-simulator-arm64` naming child programs; an ordinary program
  is not. The embedded unit declares `pudu_program_run` and no `main`; the
  executable unit keeps `main`.
- Library names: a bare name and `@rpath/` and system framework paths are kept
  on iOS; another absolute path is refused once; every path is refused on
  Android.
- With `PATH` emptied and `PUDU_XCRUN` unset, an iOS build is
  `ToolchainSdkMissing "ios-simulator-arm64" "xcrun"`; a scripted `xcrun` that
  does not know the SDK is `ToolchainSdkMissing` carrying its words. Neither
  writes the output.
- A library output named `pudu_program.h` fails before SDK discovery.
- The path test includes parent traversal beneath an allowed prefix and a
  version string containing a path.
- With Xcode present on macOS, a real simulator build writes the archive and
  header with no warnings, the archive defines `_pudu_program_run` and no
  `_main`; elsewhere this check reports an explicit skip.

## Dependencies and consumers

[[Backend Native Target]], [[Backend Toolchain Library]], [[Backend Emit]],
[[Compiler Frame Lowering]], [[Compiler Program]]. Consumed by
[[Repository Test Runner]].

## Resolved Grill Log

- **Q:** How do SDK diagnostics run on Linux CI? **A:** Scripted `xcrun` and
  environment control, as the host toolchain tests script `PUDU_CC`.
- **Q:** Why not run the simulator here? **A:** Booting a device takes
  minutes and needs Xcode; [[iOS Simulator Run]] owns that check.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Native Target]] · [[Repository Test Runner]]
