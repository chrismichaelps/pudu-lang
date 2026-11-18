---
type: module
path: "@root/test/swift-entry-points.mjs"
fidelity: Active
tags: [module, test, native, swift, foreign]
aliases: [Swift Entry Points Test]
---

# Swift Entry Points Test

`node test/swift-entry-points.mjs <optimized-compiler>` checks that a Swift library reached
through C entry points behaves the same interpreted and native. It is registered in
`test/gates.sh` as "Swift entry points answer natively as interpreted".

## Purpose and interface

- Runs only on macOS with `swiftc` on the path. Elsewhere the script reports a skip and exits
  without failing.
- Builds the Swift library from [[Swift Counter Fixture]] and the Pudu program that declares
  its entry points.
- Runs the program interpreted and natively. The two outputs must be identical, line for line.

## Algorithm and invariants

- The native program links the Swift library as an ordinary C dependency. No compiler change is
  involved: `@_cdecl` symbols are plain C functions to Pudu.
- The release check builds a second program that releases the same handle twice. The
  interpreted and native runs must both refuse it with `E7022`, with the same message.
- A native output that matches the interpreter but a refusal that differs is a failure.
  Comparing the refusal text is what keeps the two backends honest about ownership.

## Dependencies and consumers

[[Swift Counter Fixture]], [[Foreign Ownership]], [[Native Foreign Handles Delivery]]. Gate
entry: [[Repository Gates]].

## Resolved Grill Log

- **Q:** Why compare native output against the interpreter rather than a fixed expectation alone?
  **A:** The expected values pin the arithmetic. The interpreter comparison pins that the native
  backend reads the same handles and callbacks the interpreter does.
- **Q:** Why skip off macOS rather than fail? **A:** The Swift toolchain is part of the Apple
  developer tools. Linux gates run without it, so a missing `swiftc` is a missing prerequisite,
  not a regression.

## Referenced by

[[Swift Counter Fixture]] · [[Repository Gates]] · [[Native Mobile Targets Delivery]]
