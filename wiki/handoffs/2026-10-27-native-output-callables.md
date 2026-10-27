---
type: handoff
status: ACTIVE
issue: 569
aliases: [Native Output Callable Delivery]
---
# Native Output Callable Delivery

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit. [[Native Output Callable Values]] owns
the resolved contract and bounded implementation/test ownership. Branch
feature/569-native-output-callables starts at freshly fetched dev and
fast-forwards #568. No sub-agents; independent review remains pending.

The prior named-callable repair is committed as 567eba69; the worktree was
clean before this slice. Both evaluators agree on distinct builtin rendering,
identity equality and operator kinds in /tmp/pudu-builtin-probes.log.
Preserve the full release gate/workflows and private ignored inputs.

Core callable metadata now identifies builtin values independently of hidden
environments. Generated output bodies share outputResult with direct calls;
function descriptors mark intrinsic frames uncounted. Runtime kind projection
covers dynamic sum/callable diagnostic labels. Runtime revision is 15.

Validation: -Werror builds compiled changed modules and relinked CLI/tests.
All five focused groups pass Clang, GCC 15, ASan/UBSan and PUDU_EVAL=tree in
/tmp/pudu-output-callable-complete-{clang,gcc,asan,tree}.log. Six healthy
counted programs and one repeated failed-Result program release every tracked
allocation. Isolated failed handles include both evaluators, all missing-fd
masks, prefix/wait checks and the four tags through aliases. Explicit outputs,
seven runtime failures and source/builtin depth boundaries pass. CLI imported
provider/returned builtin output matches exact bytes/status with both evaluators
in /tmp/pudu-output-callable-cli.log.

Seven focused frame/overflow/sum/shape/determinism/include regression groups
pass in /tmp/pudu-output-callable-final-regressions.log. Earlier named-callable
and remaining E6001 regression groups pass in
/tmp/pudu-output-callable-regressions.log. The original unsupported value is
recorded in /tmp/pudu-output-callable-red.log.

Strict GCC exposed a join warning in the builtin set-key failure program.
The original evidence remains in /tmp/pudu-output-callable-gcc-red.log.
Runtime Aggregate now checks delimiter, part, separator and label additions
individually, plus the final delimiter lower bound before allocation/copy.
Synthetic separator/label overflow probes reach the exact memory failure with
zero live allocations; no warning suppression or oracle change was introduced.
The existing always-exiting memory failure function declares standard C11
_Noreturn. Final GCC and sanitizer lanes pass.

The full release gate/workflows are unchanged. No full release run or
independent review occurred; Linux/Windows and complete native coverage remain
open. This slice needs PR size partitioning before review. Other builtin
families, bound methods, callable constants, defaults, numeric/host/resource/
concurrency surfaces remain in the complete goal.

A code audit also found an ownership follow-up: fail_text/fail_text_help copy
payloads before frame cleanup, then pass them into a terminating reporter that
does not free those copies. Add a counted dynamic-diagnostic regression before
repairing that boundary. NativeSpec is also above the default source-size target;
move corpus registration into a bounded data module before further growth.

Exact next action: commit #569, then prove and repair diagnostic-copy cleanup
with a counted E7001/computed-help failure regression.

## Referenced by

[[handoffs/_MOC]] · [[Native Output Callable Values]]
