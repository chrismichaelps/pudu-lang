---
type: handoff
status: ACTIVE
issue: 857
aliases: [Native Audio Adapter Delivery]
---

# Native Audio Adapter Delivery

Language Architect → Backend Engineer. This branch builds on the source
packaging in [[Native Desktop Adapter Delivery]]. The native audio runtime
owns playback, stream tokens, and conversion of AudioToolbox status and
timeline values to host outcomes.

## Resolved Grill Log

Reuse the native toolchain's temporary source bundle. Keep stream pointers
inside a run-owned registry, consume a token before closing, and drain
remaining streams at exit. Preserve the interpreter's validation and
unsupported-platform outcome precedence. The C adapter owns its queues.

## Exact next action

The macOS playback and stream smoke matched the interpreter. Sending SIGTERM
during a ten-second clip produced the same cancellation outcome, empty
stderr, and exit status zero in both engines.

Verify counted stream teardown and review the non-macOS outcomes in CI.

## Referenced by

[[handoffs/_MOC]] · [[Native Toolchain Host Sources]] · [[Native Application UI]]
