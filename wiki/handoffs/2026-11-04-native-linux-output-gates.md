---
type: handoff
status: ACTIVE
issue: 811
aliases: [Native Linux Output Gate Delivery]
---
# Native Linux Output Gate Delivery

Tooling Engineer → Test Engineer → Forensic Guardian self-audit.
Branch feature/811-native-linux-output-gates starts from dev a1708407.
Owned: OutputSpec.hs, ci.yml and mirrors; output-context clarification,
navigation/changelog. Also carry the identical shared E7010 registry
correction tracked by #807. Preserve unrelated work; no subagents.

Linux CI on #807 observed both native and evaluator Waiting for out-mask2,
which the hardcoded Darwin list classified as normal, then hit the full
suite's 12-minute deadline. Keep the real observations and fix classification
with a bounded kernel-readiness probe. Healthy control and exact prefixes
remain mandatory; increasing the deadline to 45 minutes is not proof of a pass.

PR #809 has all 48 clean local gates passing; PR #812's separate full gate
run continues in the c11-wordmaps checkout. Neither is merged or independently
approved. Full C11 completion remains governed by the native coverage ledger.

Direct, callable and entry/fatal output matrices pass locally against both
evaluator modes with strict C11 warnings-as-errors probe compilation. The
healthy control is nonblocking; measured macOS blocked masks remain 3, 5,
6 and 7. Exact terminal observations/prefixes are unchanged. The probe itself
is bounded and reaped, and unexpected status/bytes cannot become a pass.
The shared E7010 registry gate passes. This does not prove Linux completion.

Independent implementation/wiki-parity review remains required; no source
output behavior or interpreter result has been changed by this test repair.

Exact next action: push the bounded dev PR and observe actual Linux full-suite
completion before recording hosted validation.

## Referenced by

[[handoffs/_MOC]] · [[Native Output Tests]] · [[Pudu Continuous Verification]]
