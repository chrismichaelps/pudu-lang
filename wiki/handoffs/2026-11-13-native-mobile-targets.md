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

## Exact next action

The arm64 device and simulator archives passed SDK and entry checks. The
iOS 26.4 simulator host matched the interpreter for `abs`, `strlen`, and
a call to the CoreFoundation C symbol `CFAbsoluteTimeGetCurrent`.

Review the shared native tool runner in [PR #891](https://github.com/chrismichaelps/pudu-lang/pull/891) before advancing the dependent iOS partitions.

## Referenced by

[[handoffs/_MOC]] · [[Native Mobile Targets]] · [[Backend Toolchain Library]]
