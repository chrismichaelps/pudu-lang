---
type: handoff
status: ACTIVE
issue: 810
aliases: [Native Word Map Algebra Delivery]
---
# Native Word Map Algebra Delivery

Architect → Backend Engineer → Test Engineer → Forensic Guardian self-audit.
Branch feature/810-native-word-map-algebra starts from dev a1708407.
Owned: Core/Keyed (extracted tags), Lower/WordMap, direct/intrinsic dispatch,
Runtime/Tree, Emit/Keyed and Emit/Frame/Value; WordMapPrograms and focused
NativeSpec/TextLeakSpec/FrameEmitSpec/module registration; manifests, mirrors,
architecture/navigation/history. No subagents; preserve unrelated changes.

Tooling ownership also carries the identical shared E7010 registry correction
tracked in PR #807. The code and its reporting semantics are unchanged.

Resolved contract: immutable linear merge over ascending node views, zero
elision and left representative retention; bounds-checked temporary arrays
and logarithmic balanced construction. Only exact Map[K, UInt64] facts admit.
Hold source operands in declaration order before frame method lowering.
Direct and first-class forms reuse the same builder and existing builtin ABI.

PRs #807 and #809 remain separate pending review/validation. The latter's
live full gate run stays in the c11-emission checkout; this isolated checkout
does not alter its inputs. Independent implementation/architecture/wiki
review remains required; an author self-audit cannot approve its own work.

The baseline CLI refused wordMapUnion with E6001 while the interpreter
printed the explicit answer. Focused groups now pass under Clang with both
evaluator modes, GCC 15 and Clang ASan/UBSan. Three counted programs release
every allocation; frame-level malformed payload/operand/result cases retain
their exact fault span. Cases include NaN/signed-zero representatives,
high/all-bit masks, input snapshots, persistent reuse and 1000 owned keys.
Callable entry checks exposed dependency/unused-helper defects; make,
tree_node and tree_retain now select exactly the needed runtime parts without
relaxing compiler warnings. Core.hs and Lower/Body.hs are below 500 lines.

Linux full-suite descriptor classification/deadline failures in PR #807 are
tracked separately by #811. No platform completion or independent approval
is claimed here. The diff is bounded below the 600-line split limit; it
includes mechanical tag extraction plus the focused kernel and corpus.

Exact next action: run clean optimized repository gates, then open the
reviewable dev PR and continue with the Linux output validation repair.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]] · [[Core Keyed Operations]]
