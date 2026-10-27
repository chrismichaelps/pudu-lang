---
type: handoff
status: ACTIVE
issue: 568
aliases: [Native Named Callable Delivery]
---
# Native Named Callable Delivery

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit. Ownership: Core closure metadata,
Compiler/Lower/{Lambda,Layout}, Backend/{Runtime,Runtime/Frame,Emit/Frame,
Emit/Frame/Body}, NamedCallablePrograms, native/cleanup registration, frame
allocation instrumentation, Cabal
manifest and matching mirrors. [[Native Named Callable Dispatch]] resolves
the ABI and execution contract before implementation. No sub-agents.
Preserve unrelated work and the full release gate/workflows.

Branch feature/568-native-named-callable-depth starts at freshly fetched dev and
fast-forwards #567. Expression-body support is committed as e17d9987; output
Results as fcd11c0d. Their focused compiler/evaluator/sanitizer/cleanup evidence
is recorded in their handoffs. The complete native goal remains active.

Named closures now identify their actual functions. Core closure metadata and
function descriptors explicitly identify hidden environments; indirect-call
steps retain their scratch closure and the dispatcher skips it for named
targets. Runtime revision 14 records this private ABI. The source depth check
and invocation span occur once at the actual call.

Validation: incremental -Werror builds compiled changed Core/lowering/runtime
and test modules and relinked both executables. Three focused property groups
pass Clang, GCC 15, ASan/UBSan and PUDU_EVAL=tree. The lane includes nine
counted-allocation success cases (three new plus six existing closure cases),
explicit answers, both new named failures and existing lambda failures.
Logs: /tmp/pudu-callable-final-{clang,gcc,asan,tree}.log. The original premature
failure is /tmp/pudu-callable-red.log. The sanitizer wrapper originally located
in an old Claude temporary directory disappeared; its replacement is
/tmp/pudu-native-asan-cc and the final sanitizer lane passes.

Five regression groups pass in /tmp/pudu-callable-regressions-fixed.log:
frame allocation/failure cleanup, panic/overflow cleanup, direct-target closure
shape, deterministic emission and suspending direct-call emission. The first
run caught stale calloc-only test accounting after output Results introduced
malloc-owned storage. FrameRuntimeSpec now counts both allocators without
changing failure-attempt numbering, expected output/status, strict warnings
or zero-live assertions. The original failure is retained in
/tmp/pudu-callable-regressions.log.

The full release gate and workflows remain unchanged. No full release run or
independent review occurred; platform evidence and full-emission completion
remain open. No PR or promotion is claimed.

Default-argument probes also found an observable contract to preserve later:
both evaluators evaluate defaults before descend, in the caller environment
extended by earlier arguments. A default can see a caller-local function
shadow and a return inside a default returns from the caller. Evidence:
/tmp/pudu-default-probes.log. Do not implement callee prologue defaults without
resolving those interactions against actual execution.

Exact next action: commit #568, then design first-class output builtin values
with exact builtin rendering/equality and no additional user call-depth cost.

## Referenced by

[[handoffs/_MOC]] · [[Native Named Callable Dispatch]]
