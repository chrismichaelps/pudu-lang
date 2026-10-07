---
type: handoff
status: ACTIVE
issue: 450
tags: [application, measurements, delivery]
---
# Application Request Measurement Delivery

Language Architect resolves snapshot serialization in [[Std App]]. Runtime Engineer owns its
measurement closure, exact concurrent fixture and registration. Work remains sequential;
independent semantic and vault-parity review precede integration.

One measurement step owns one shared mutex. The handler runs outside it, and duration is captured
before waiting for it. Only the read, pure metric update and write hold it. Missing cells leave the
response intact. External writes and separately constructed steps over the same cell require their
own coordination; no global lock registry is introduced.

The pre-change concurrent fixture fails at `every request counted` after all 512 responses complete.
The repaired fixture passes in direct and packed evaluation, with exact 256 counter and duration
observations for each status, concurrent handlers, separate stores and exact endpoint output.
Removing the lock in a temporary library restores the named failure. The existing application
fixture retains its exact 68 checks. Formatting, lint, whitespace, the dependency gate and the
optimized full compatibility suite pass.

Exact next action: obtain independent semantic and vault-parity review before integration.

## Referenced by

[[handoffs/_MOC]] · [[Uses App Metrics Concurrent]]
