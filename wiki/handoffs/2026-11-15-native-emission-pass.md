---
type: handoff
status: ACTIVE
issue: 935
aliases: [C11 Emission Continuation Delivery]
---

# C11 Emission Continuation Delivery

Architect → Backend Engineer → Test Engineer. Branch
`feature/935-native-emission-pass` owns binary kernel lowering, emission
and runtime registration, runtime mutex retirement, native dynamic call
arguments and defaults, E6001 help, and their conformance corpus and mirrors.

The saved fixture sweep identified calls to `mutexClose`, `binaryEncode` and
`binaryDecode` as the native lowering refusals in its checked corpus. The
binary codec keeps the interpreter's validation order and wire bytes.
Mutex close stops admission before waiting for its owner. Calls through
function values apply the same dynamic coercion as direct calls.

All 31 previously refused or C-compiler-rejected programs built through the
real native toolchain. The binary facade and database scope retirement
fixtures matched interpreter execution. The decoder's malformed-input probe
passed AddressSanitizer and UndefinedBehaviorSanitizer under strict C11.

The optimized build passed with `-Werror`. The six test shards exercised
842 properties. The compiler-cancellation test missed its readiness
deadline in the parallel run and passed in isolation on the same binary.
The diagnostic registry, native coverage ledger and binary facade gate passed.

The SQLite mutex fixture also builds. Running it with the bundled SQLite C
source compiled as a shared library reached E7015 because that source exports
the interpreter's resolver function and lacks the native loader's individual
release entry point.

## Table audit

Backend Engineer → Test Engineer. The integration worktree also owns the
physical-slot changes from the two #821 commits, entry parameter lowering,
and the output Result regression and their mirrors. The previous #935
corpus and properties above describe the build before this integration.

| Table item | Current evidence and remaining work |
| --- | --- |
| Direct integer calls | #904 merged and [[Native Direct Call Tests]] cover the stack path, fallback, and exports. Typed integer locals and C-parameter calls still need implementation. The current emitter calls `pudu_direct_*` through argument cells. |
| Slot reuse | Draft #933 is open. Its two #821 commits are integrated locally. [[Native Frame Slot Reuse]] records the storage proof and the separate branch measurements. |
| Tuple, sum payload, and capture members | [[Backend Emit Cell]] defines their common carrier map. Consistency checks still reject frame operands without that carrier. This row needs a per-type audit of reachable lowering. |
| Foreign callbacks, pointers, and arrays | #875 resolved the callback contract. #876 and #877 still need implementation. [[Foreign Callback Delivery]] · [[Foreign Pointer Delivery]] |
| C calling into Pudu | #899 is on the base. [[Native Calls Delivery]] records the start guard and host-call tests. |
| Word maps, hashing, text, and operators | Word-map, store, and kernel groups cover the implemented operations. #832 addresses receiver lowering, and its status does not establish operator coverage. Compare the remaining emitter guards with checked operand types. |
| Numeric operators and carriers | The emitter selects integer, wide, BigInt, Decimal, and floating helpers for their corresponding typed operands. Audit reachable checked combinations before changing guards. |
| Builtin values and trait methods | Builtin callable dispatch is implemented for the #935 kernels and existing tested families. #647 reproduces on this worktree. Taking `Named.label` as a value checks, then reports E7001 in the evaluator and E6001 in native compilation. |
| Exported text, records, and Result | #906 merged with the typed crossings in [[Backend Export Crossing]]. |
| Entry parameters and ambiguity | Implemented default evaluation and explicit duplicate-entry refusal in the integration tree. The usual CLI checks duplicate declarations before lowering. The frame entry ABI still takes zero parameters. |
| Objective-C, Swift, and JNI | #879, #881, and #880 still need their platform bridges. [[Native Platform Adoption]] states the current boundary. |
| Moves, drop, and unwind | Existing mutable-loan groups cover explicit returns and propagation. Dynamic dispatch with mutable loans still refuses. Move and drop coverage needs an audit against the implemented language. |
| Output Result bodies and assignments | The new conformance program returns `print` directly from a named function and assigns its result and a direct output result. [[Backend Output Programs]] |
| Defaults and concrete signatures | Native dynamic defaults and parameterized entries lower with checked carriers. Other defaults and generic signatures still need coverage analysis. |
| Emission faults | `pudu build --native` renders `FrameFault` through E6001 in the CLI with its own span or the module span fallback. |

The integrated build passed with `-Werror`. Focused checks passed for slot
lifetimes, the strict C11 corpus, entry statuses and diagnostics, output
Results, direct calls, C exports, word maps, indexed stores, kernels, and
host services.

Exact next action: trace the checked trait-member selection into the evaluator
and native lowering for the #647 `Named.label` reproducer, then use that
selection to dispatch the value through its first argument.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]] · [[CHANGELOG]]
