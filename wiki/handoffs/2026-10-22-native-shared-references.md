---
type: handoff
status: COMPLETE
issue: 544
aliases: [Native Shared Reference Delivery]
---
# Native Shared Reference Delivery

Delivery Owner → Language Architect → Backend Engineer.
No subagents, per user instruction. Semantic and Forensic Guardian review remain
promotion requirements; no author self-approval is implied.

Validated base: aa0daa01 (#543), all 20 clean gates, 712 optimized groups,
Clang/GCC/ASan/UBSan, both interpreter modes and 71 counted programs. Both
feature/541-native-let-else and feature/543-native-constants were pushed.
No PR was opened and nothing was merged into dev. origin/dev was fetched before
creating feature/544-native-shared-references; prerequisites are still stacked.

[[Native Shared References]] resolves the representation. The checked probe in
/Users/chrismperez/.codex/tmp/pudu-native-references/probe/Main.pudu passes
checking and prints 9, 7, hello with exit 0 in tree and compiled modes. The
native baseline refuses &Point at its parameter type (baseline.log). Actual
Eval.Operator implements & and * as Value identities; mutable call arguments
add separate place writeback and must not be silently admitted.

Bounded ownership: Compiler/Lower/{Types,Scalar,Reference}.hs, the new
ReferencePrograms corpus, ModulePrograms and TextLeakSpec corpus integration,
LowerTypesSpec static fact/refusal tests, production/test Cabal registration
and corresponding vault pages. Reuse the existing whole-program harness;
NativeSpec is already 588 lines and needs no growth or new exports. Main's
existing property lists already execute the corpus coordinators.

Planned Reference and ReferencePrograms mirrors exist with resolved Grill Logs.
Complete touched existing mirrors before code. Type projection may erase only
ReferenceTypeValue False, recursively preserving canonical pointee identity;
True remains unsupported. Add sharedReferenceTarget to inspect exact raw
reference facts. Reference lowering must preserve Never, reject print's hidden
Result, evaluate once and retain the operand's original diagnostic span.

Done: the false-only type projection and identity lowerer are in, with the
corpus, counted cleanup and fact/refusal checks passing under Clang, GCC 15,
ASan/UBSan and both interpreter modes. The stale EmitSpec `&value` refusal now
uses a `&mut Int` parameter. Methods, mutable writeback, generic code and every
other emission gap remain open; trait methods are the next slice.

## Referenced by

[[handoffs/_MOC]] · [[Native Shared References]]
