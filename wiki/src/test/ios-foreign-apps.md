---
type: module
path: "@root/test/ios-foreign-apps.mjs"
fidelity: Active
tags: [module, test, native, mobile, foreign, swift]
aliases: [iOS Foreign Apps Test]
---

# iOS Foreign Apps Test

`test/ios-foreign-apps.mjs` holds the iOS simulator checks for programs that call foreign
code. It was split from [[iOS Simulator Run]] so that both scripts stay under 500 lines.

## Purpose and interface

- `objectiveCSmoke` is the Objective-C bridge check, moved here unchanged in behavior from
  [[iOS Simulator Run]].
- `swiftSmoke` compiles the Swift library from [[Swift Counter Fixture]] for
  `arm64-apple-ios15.0-simulator` as an embedded framework. The install name uses `@rpath`.
- `swiftSmoke` builds the Pudu program for `ios-simulator-arm64` through the ordinary app
  path ([[Backend Toolchain App]]), runs it on a simulator, and requires its output to equal
  the output of the same program run by the macOS interpreter.
- Both smokes use one `installAndCheck` helper. It installs the built app, launches it and
  compares the captured lines.

## Algorithm and invariants

- The helper receives the `run`, `launch` and `uninstall` functions from
  [[iOS Simulator Run]] and does not start simulators itself. This keeps device lifecycle in
  one place and keeps this script small.
- PASS lines are written synchronously with `writeSync`, for the same reason as
  [[iOS Simulator Run]]: a CI log shows each result as it is produced rather than when the
  event loop runs.
- The framework is signed inside the app's `Frameworks` directory, so the `@rpath` lookup
  resolves at launch without the host linking it directly.
- A simulator run that cannot start is reported with the same skip and required-mode rules as
  [[iOS Simulator Run]].

## Dependencies and consumers

[[iOS Simulator Run]], [[Swift Counter Fixture]], [[Native Mobile Targets]]. Verified against
iOS 26.4 on the development Mac, where the macOS check and the simulator run both pass.

## Resolved Grill Log

- **Q:** Where do foreign-interface apps live? **A:** `test/ios-foreign-apps.mjs`; the smoke
  passes its run, launch and uninstall helpers so this script stays under 500 lines.
- **Q:** Why require the macOS interpreter's output rather than a fixed string? **A:** The
  same program runs on both sides, so a difference can only come from the simulator's foreign
  call path.

## Referenced by

[[iOS Simulator Run]] · [[Swift Counter Fixture]] · [[Native Mobile Targets Delivery]]
