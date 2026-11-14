---
type: module
path: "@root/test/ios-simulator.mjs"
fidelity: Active
tags: [module, test, native, mobile]
aliases: [iOS Simulator Run]
---

# iOS Simulator Run

## Purpose and interface

`node test/ios-simulator.mjs <pudu>` builds a Pudu program for
`ios-simulator-arm64`, links it into a minimal application and compares what
the application prints on a booted simulator with `pudu run`.

Use `--require-simulator` to make an unavailable simulator a failure.
[[iOS Simulator CI]] uses this mode.

## Algorithm and invariants

- Reports unavailable prerequisites outside Apple silicon macOS, when
  `xcrun` is missing, or when no iOS simulator runtime is installed. The
  default mode skips and required mode fails.
- The program calls `abs` and `strlen` through `foreign "c"` and calls
  `CFAbsoluteTimeGetCurrent` through the CoreFoundation system framework.
  It checks that the returned timestamp is positive, so the host and simulator
  can compare stable output.
- Compile a small C framework for the simulator with an `@rpath` install name,
  sign it inside the app's Frameworks directory, and resolve its symbol from
  Pudu without linking the host directly to the framework. Run the same C
  implementation through a macOS dylib to compare interpreter output.
- `main.m` owns `main`, calls `pudu_program_run` inside an autorelease pool,
  prints the status it returns and ends, so the launch finishes by itself.
- The application is linked with `xcrun --sdk iphonesimulator clang`, given an
  `Info.plist` with its identifier and executable, and ad-hoc signed.
- The script creates its own iPhone device, boots it, installs, launches with
  `--console-pty` capturing standard output, and deletes the device afterwards
  on every path. An explicit `PUDU_IOS_SIMULATOR_UDID` instead uses an already
  booted test simulator and uninstalls only the uniquely identified smoke app.
- Passes when the captured lines equal `pudu run`'s output followed by the
  status line.

## Dependencies and consumers

[[Native Mobile Targets]], [[Backend Toolchain Library]]. Run on an Apple silicon Mac with an installed iOS runtime.

## Resolved Grill Log

- **Q:** Why create a device rather than use an existing one? **A:** An
  existing device may be booted by its owner; a private device is deleted
  afterwards without touching anyone else's.
- **Q:** Why not start `UIApplicationMain`? **A:** The check is that the
  library runs inside an application process the host owns; a run loop would
  only make the launch wait. Where a host calls the entry is its framework's
  choice.

## Referenced by

[[Native Mobile Targets]] · [[Native Mobile Targets Delivery]]
