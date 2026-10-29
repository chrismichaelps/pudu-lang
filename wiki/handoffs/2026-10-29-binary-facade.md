---
type: handoff
status: ACTIVE
aliases: [Binary Facade Delivery]
tags: [handoff, stdlib, serialization]
---
# Binary Facade Delivery

Issue #739 public partition continues on feature/739-binary-derives, based on the native commits
in draft PR #741. Own Std.Binary, native builtin tags/install/type/resolution/dispatch wiring,
the facade smoke/gate, registration and matching mirrors. Preserve the complete UsesBinary fixture,
protocol-suite entry and benchmark for the following acceptance partition. No delegated agents.

Architect resolves the Encode/Decode derive names with pack/unpack methods before implementation;
Runtime Engineer retains native boundary ownership; Tooling/Release runs actual CLI, typed refusal,
packaging and full validation. Independent implementation, Language Architect and Forensic Guardian
reviews remain pending. No merge or self-approval.

The facade gate passes exact CLI output, native framing errors, skipped sum-field handling,
JSON coexistence, formatter checks, positioned type refusal and actual archive inspection.
Lint and shell syntax checks pass. The unchanged facade/wiring also passed the preceding full
clean regression gate as part of the working continuation. Only the smoke/gate was added since.

Exact next action: commit/push the bounded facade partition; open its dev-targeted PR after the native prerequisite is integrated.

## Referenced by

[[handoffs/_MOC]] · [[Std Binary]] · [[Binary Facade Gate]]
