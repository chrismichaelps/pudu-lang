---
type: handoff
status: ACTIVE
aliases: [Binary Facade Delivery]
tags: [handoff, stdlib, serialization]
---
# Binary Facade Delivery

Issue #739 public partition continues on feature/739-binary-derives, based on the native commits
in PR #741. Own Std.Binary, native builtin tags/install/type/resolution/dispatch wiring,
the facade smoke/gate, registration and matching mirrors. Preserve the complete UsesBinary fixture,
protocol-suite entry and benchmark for the following acceptance partition. No delegated agents.

Architect resolves the Encode/Decode derive names with pack/unpack methods before implementation;
Runtime Engineer retains native boundary ownership; Tooling/Release runs actual CLI, typed refusal,
packaging and full validation. The project owner waived independent review for this engine delivery loop on 2026-10-30.
Merge follows successful required checks.

The facade gate passes exact CLI output, native framing errors, skipped sum-field handling,
JSON coexistence, formatter checks, positioned type refusal and actual archive inspection.
Lint and shell syntax checks pass. The unchanged facade/wiring also passed the preceding full
clean regression gate as part of the working continuation. Only the smoke/gate was added since.

Exact next action: commit/push the bounded facade partition; open its dev-targeted PR after the native prerequisite is integrated.

## Referenced by

[[handoffs/_MOC]] · [[Std Binary]] · [[Binary Facade Gate]]

Integration update: merge the current native partition and dev, preserving both changelog histories.
Bring forward accurate absent-field defaults and one-way required-field removal documentation.
The facade gate now consumes depth 512 and refuses depth 513 and duplicate Fields/Choice names
through positioned E7001 diagnostics; no new public API is introduced. Revalidate before delivery.

The current-dev run passed its warning-free build and full suite, then exposed one wrong test
assumption: the writer fault points to the native call inside Std.Binary, as runtime errors always
do, rather than its outer caller. Inspection confirmed the actual span; the focused gate passes
with that established provenance retained. Merge the #742-integrated native parent e96a3c26,
preserving both gate registrations and navigation entries, then rerun the clean full gate.

The second clean current-dev gate passed every check at 9d6f22a4; that tested facade is pushed.
Integrate native extent admission eb764a08 and retain its explicit UInt32 prefix contract in the
public documentation. The native arithmetic boundary tests avoid multi-gigabyte allocations.
Refresh focused and full validation before the dev-targeted facade PR follows native integration.
