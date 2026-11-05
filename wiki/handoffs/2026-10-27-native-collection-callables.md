---
type: handoff
status: DONE
issue: 631
aliases: [Native Collection Callable Delivery]
---
# Native Collection Callable Delivery

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit. Owned: Compiler Lower Intrinsic/Convert/Bytes/Keyed/Types, Core
and Core Frame caller failures, Compiler Frame/Body, Backend Emit Frame Body,
Runtime Frame/Text/revision, CollectionCallablePrograms, OutputCallablePrograms
registration, FrameSpec, the test manifest and matching vault pages. No
sub-agents. Branch feature/631-native-collection-callables starts at the #575
tip; its draft PR bases on feature/575-native-render-callables.

[[Native Collection Callables]] was resolved before source changes.

Implementation: Convert, Bytes and Keyed export the Core builders their direct
calls already used, and Intrinsic registers one body per solved signature
through them. Frames record the site of the value call that created them;
CoreFailCaller/FrameFailCaller report a builtin's refusal there. Types forms
any open variable as unit. Runtime revision 17.

Evidence: probes of every corpus program match the tree interpreter byte for
byte natively, including E7008 spans through a value, a record field, a
generic caller and a nested call. The five output-callable groups pass under
Clang, GCC 15 and ASan/UBSan. Removing the dispatcher's call_site store makes
the first refusal case fail, so the corpus covers the new field. The full
test binary at -O0 ran over the Types change; see the commit for its result.

The previous slices' PRs are #576–#630, stacked on #487. No full release gate
run locally and no independent review yet; the gate and workflows are
unchanged.

Exact next action: make the remaining pure prelude builtins first-class values
where a direct native lowering exists (convertInteger with its type argument,
then panic), using the same shared-builder pattern and caller-site refusals.

## Referenced by

[[handoffs/_MOC]] · [[Native Collection Callables]]
