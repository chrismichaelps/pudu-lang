---
type: handoff
status: ACTIVE
issue: 878
aliases: [Native Mobile Targets Delivery]
---

# Native Mobile Targets Delivery

Language Architect → Backend and Tooling Engineer. This partition owns the
embedded C entry, Apple SDK builds, target diagnostics, and the simulator
smoke. Tooling Engineer → Forensic Guardian review covers the draft stack
and [[iOS Simulator CI]]. Android remains a later partition.

## Resolved Grill Log

One target builds one library slice. The application owns the process and
calls the generated C entry once. SDK discovery and unsupported runtime parts
fail before C compilation. Simulator evidence compares a host application's
C foreign calls with interpreter output.

## Validation

The arm64 device and simulator archives passed SDK and entry checks. The
iOS 26.4 simulator host matched the interpreter for `abs`, `strlen`, and
a call to the CoreFoundation C symbol `CFAbsoluteTimeGetCurrent`. The host
also resolved and called a C symbol from a signed embedded framework through
`@rpath`.

The [hosted macOS run](https://github.com/chrismichaelps/pudu-lang/actions/runs/43517221095)
passed for `debf8584`. The compiler, workflow and simulator script are
identical on this branch. The packaged XCFramework slices also linked into
separate device and simulator C hosts locally.

## Exact next action

Independently review [PR #891](https://github.com/chrismichaelps/pudu-lang/pull/891),
the shared native tool runner and first partition in the iOS stack.

## Referenced by

[[handoffs/_MOC]] · [[Native Mobile Targets]] · [[Backend Toolchain Library]]
