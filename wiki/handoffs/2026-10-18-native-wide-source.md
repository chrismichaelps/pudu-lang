---
type: handoff
status: HANDED_OFF
issue: 507
aliases: [Native Wide Source Delivery]
---
# Native Wide Source Delivery

Delivery Owner → Language Architect: [[Native Wide Source Admission]] resolves
canonical source admission and public conformance after #506. Backend Engineer
owns Compiler.Lower.Types; Test Engineer owns SignedPrograms, UnsignedPrograms,
LowerTypesSpec, EmitSpec and NativeSpec. Matching module mirrors have resolved
contracts before implementation. No subagents; preserve unrelated dist-ticky.

Stack on #506 because dev lacks the prerequisite frame/carrier series. Keep
BigInt/floats and all other unrepresented types refused; numeric coverage stays
Partial and full C11 completion remains open. Required independent implementation,
architecture/wiki review and additional platform evidence remain pending.

Preflight evidence: actual tree/compiled CLI executions agree on the proposed
mixed-width snapshot/recursive/unit-join source, and 26 endpoint entry checks
match independent status expectations. Native still refuses E6001 before source
admission, as required. Three replacement BigInt/Float32/Float64 refusal fixtures
pass ordinary checking. Four out-of-range literal boundary fixtures report
E3018 (integer range), not the floating-literal E3019. Keep that distinction.
Artifacts: ~/.codex/tmp/pudu-507/oracle-preflight.json and entries/.

Language Architect → Backend Engineer → Test Engineer: #506 is committed as
362cd217 after all 19 clean gates/678 groups pass.

Backend Engineer → Test Engineer: canonical admission is enabled with only the
existing fixed-width predicate extended. The canonical regression is red before
admission and green afterward; same-spelling user-owned/applied identities stay
rejected. Replacement unsupported-type refusal spans pass. Eight wide success
programs carry 969 independent expected output lines; 24 failure programs cover
arithmetic, shifts, negation, deferred settlement and recursive call depth.
Both tree and compiled evaluator source matrices pass exact native parity.
45 actual CLI executions match independent results/statuses and four static
E3018 refusals remain byte-identical to the pre-admission build. The GCC 15 and ASan/UBSan complete numeric source matrices also pass against
the tree evaluator, including exact failure diagnostics and recursive depth.
Entry-status groups pass with both evaluator modes. All 19 clean gates pass, with a fresh 319-module production/127-module test
warning build and 678 test groups; 351 strict C11 frame translations pass.
No full-language completion or promotion claim is made.

Test Engineer → Delivery Owner → Language Architect: #507 is ready for a local
commit. Exact next action: commit source admission, then implement ready #508's
checked bounded natural scratch for exact floating formatting. Full numeric and
language coverage, independent reviews and supported-platform evidence remain
open. Preserve the current full goal; no subagents execute.

## Referenced by

[[handoffs/_MOC]] · [[Native Wide Source Admission]] · [[Native Wide Frame Delivery]]
