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
| Direct integer calls | #904 merged and [[Native Direct Call Tests]] cover the stack path, fallback, and exports. Eligible named direct callees have typed C parameters and locals. Their cell entries preserve deferred magnitudes. See [[Backend Typed Integer Calls]]. |
| Slot reuse | Draft #933 is open. Its two #821 commits are integrated locally. [[Native Frame Slot Reuse]] records the storage proof and the separate branch measurements. |
| Tuple, sum payload, and capture members | [[Backend Emit Cell]] defines their common carrier map. Consistency checks still reject frame operands without that carrier. This row needs a per-type audit of reachable lowering. |
| Foreign callbacks, pointers, and arrays | #875 resolved the callback contract. #876 and #877 still need implementation. [[Foreign Callback Delivery]] · [[Foreign Pointer Delivery]] |
| C calling into Pudu | #899 is on the base. [[Native Calls Delivery]] records the start guard and host-call tests. |
| Word maps, hashing, text, and operators | Word-map, store, and kernel groups cover the implemented operations. #832 addresses receiver lowering, and its status does not establish operator coverage. Compare the remaining emitter guards with checked operand types. |
| Numeric operators and carriers | The emitter selects integer, wide, BigInt, Decimal, and floating helpers for their corresponding typed operands. Audit reachable checked combinations before changing guards. |
| Builtin values and trait methods | Builtin callable dispatch is implemented for the #935 kernels and existing tested families. #647 trait-qualified values lower through a closure that dispatches against its first argument. |
| Exported text, records, and Result | #906 merged with the typed crossings in [[Backend Export Crossing]]. |
| Entry parameters and ambiguity | Implemented default evaluation and explicit duplicate-entry refusal in the integration tree. The usual CLI checks duplicate declarations before lowering. The frame entry ABI still takes zero parameters. |
| Objective-C, Swift, and JNI | #879, #881, and #880 still need their platform bridges. [[Native Platform Adoption]] states the current boundary. |
| Moves, drop, and unwind | Existing mutable-loan groups cover explicit returns and propagation. Dynamic dispatch writes a lent receiver back through its place. General method loan fallback and move/drop coverage still need audits. |
| Output Result bodies and assignments | The new conformance program returns `print` directly from a named function and assigns its result and a direct output result. [[Backend Output Programs]] |
| Defaults and concrete signatures | Native calls omit trailing defaults and can call the source entry by name or value. Monomorphic defaulted and async exports cross C. Generic methods still need coverage analysis. |
| Emission faults | `pudu build --native` renders `FrameFault` through E6001 in the CLI with its own span or the module span fallback. |

The integrated build passed with `-Werror`. Focused checks passed for slot
lifetimes, the strict C11 corpus, entry statuses and diagnostics, output
Results, direct calls, C exports, word maps, indexed stores, kernels, and
host services.

Backend Engineer → Test Engineer. The callable and integer work owns the
default/signature lowering, entry instance registration, export crossing, and
typed integer emitter with their focused differential and C-host tests.
The optimized build with warnings as errors, export tests, direct-call tests,
entry status conformance, and 355 strict C11 translations passed.

The checked method scheme made every argument required even when the
implementation wrote a default. The native signature now follows that scheme
and the full-arity CLI reproducer prints 9 in both modes. Inferred generic
trait calls and calls through a generic trait default also built successfully.
The seven interleaved CallBench runs had matching checksums. Medians were
104 ms for native Pudu and 109 ms for handwritten C, with other tests running.

Backend Engineer → Test Engineer. The pattern slice owns tuple, record,
and sequence binding transfers and the tuple diagnostic corpus. The
optimized build and tuple diagnostic suite passed. Direct CLI comparisons
matched output, exit status, and E7007 span for both tuple and sequence
panic subjects. A generic mutable receiver and argument wrote both places
back through receiver and trait-qualified calls. Mutable Sequence protocol
signatures fail checking before they can reach the native fallback.

Exact next action: define the mobile TLS provider boundary for the existing
connected-descriptor upgrade, including platform trust and TLS 1.3.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]] · [[CHANGELOG]]
