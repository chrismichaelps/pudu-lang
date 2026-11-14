---
type: handoff
status: DONE
issue: 575
aliases: [Native Rendering Callable Delivery]
---
# Native Rendering Callable Delivery

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit. Own Compiler Lower Intrinsic/Body, RenderingCallablePrograms,
OutputCallablePrograms registration, test manifest and matching vault pages.
No sub-agents; independent implementation/architect/wiki review is pending.
Branch feature/575-native-render-callables starts at freshly fetched dev and
fast-forwards f96d40de as the documented implementation prerequisite.
Preserve unrelated work and the full release gate/workflows.

[[Native Rendering Callables]] resolves the contract before source changes.
Both evaluator oracle probes in /tmp/pudu-render-value-oracles.log establish
simultaneous Int/Str specializations, escaping, identity and builtin rendering.

Implementation: lowerIntrinsicValue recognizes six builtin tags. Existing
output keys remain unchanged; display/show keys include the full derived
canonical CoreType representation, including nominal owners. Core rendering
and normal frame ownership remain the only execution path. Builtin closureSite
identity stays per tag, independently of the generated body. No runtime ABI
change or revision bump is needed.

Forced GHC -Werror builds compile changed library/test modules and relink the
CLI/tests. Five focused callable groups pass under Clang, GCC 15 and ASan/UBSan,
and with the tree oracle, in /tmp/pudu-render-callables-{clang,gcc,asan,tree}.log.
This covers eight new healthy sources and five new runtime failures plus the
existing output corpus and failed-handle/failed-Result regressions. The final
transfer source adds a ninth healthy case: both oracles and all three native
toolchains match exact output in /tmp/pudu-render-callables-transfer.log.
The cross-module provider collision case matches both evaluators and actual
CLI native builds under all three toolchains in
/tmp/pudu-render-callables-modules.log. It is registered in modulePrograms.
Final 15-program counted cleanup passes Clang, GCC 15 and ASan/UBSan in
/tmp/pudu-render-final-cleanup-{clang,gcc,asan}.log. The deterministic emission
property passes in /tmp/pudu-render-emission-regression.log.
Both manifests and diff whitespace checks pass. No full local release run or
independent review occurred; the full gate/workflows remain unchanged.

PR #572 compiler, musl, Lambda and website checks pass. Its Raylib job hit the
existing 15-minute timeout during FFI execution; a single job rerun was requested
via gh run rerun 40533443124 --job 122292883133. Inspect that live attempt before
any repeat. PR #573/#574 CI continues independently. No CI policy was weakened.

The implementation depends on the accumulated native stack, so do not publish
a tens-of-thousands-line dev PR. Existing reviewable dependency PRs #571–#574
remain draft and unmerged; publish subsequent bounded dependencies as needed.

Exact next action: extend first-class pure conversion/collection builtins,
starting with charFromCode/bytesOf/mapOf/setOf, using their existing direct
lowering semantics and per-tag identity. Inspect the live Raylib rerun and
#573/#574 CI before requesting independent review; preserve all remaining
full-emission obligations.

## Referenced by

[[handoffs/_MOC]] · [[Native Rendering Callables]]
