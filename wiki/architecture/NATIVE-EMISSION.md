---
type: architecture
tags: [architecture, backend, native]
aliases: [Native Emission Coverage]
---
# Native Emission Coverage

## Purpose and completion rule

Compile ordinary checked Pudu programs into portable C11 with interpreter-identical observable behavior. Full coverage requires every implemented language construct and reachable standard-library boundary to have lowering, representation, execution, cleanup, diagnostics, and differential evidence. A typed E6001 refusal is an honest boundary, not completed support. There is no silent interpreter fallback.

## Coverage ledger

| Area | State | Next obligation |
| --- | --- | --- |
| Platform Int/Bool, checked arithmetic, if/while, printing | Implemented (#498, #505) | Preserve exact deferred magnitudes, control/output parity and closed-pipe continuation/diagnostic regressions |
| Scalar functions, recursion, call depth | Implemented (#499) | Preserve explicit-frame lifetime, argument ordering, E7002 timing and differential evidence; promotion still requires independent review |
| Loop control and scalar loop results | Implemented (#489) | Preserve labels, transfers, Never joins and condition-scope evidence |
| Unit values, parameters and operations | Implemented (#492, #493) | Preserve effect-first temporaries, display/equality and #494 E7001 runtime refusals |
| Entry result reporting | Partial (#512) | Integer statuses, unit silence and Bool/Float32/Float64 rendering match `pudu run`; print Result and aggregate value rendering remain |
| Complete numeric families | Partial (#495, #497, #500, #507, #512) | Fixed integers, Int128/UInt128 and Float32/Float64 are admitted; BigInt and Decimal remain |
| Text and bytes | Pending | Owned representation, UTF-8, allocation, comparisons and IO failures |
| Records, tuples, sums and collections | Pending | Layout, construction/update, access, equality, allocation and destruction |
| Pattern matching and iteration | Pending | Exhaustive ordered decisions, guards, bindings, ranges and iterator protocol |
| Modules and constants | Pending | Canonical linkage, qualified identities, checked folds and graph publication |
| Callables and generic code | Pending | Closures/captures, defaults, monomorphization and trait dispatch |
| Accepted operations with runtime refusals | Partial (#494, #512) | Represented Unit/Bool/float operators retain E7001; remaining runtime types/operators still need equivalent coverage |
| Errors, references and resources | Pending | Result/Option propagation, borrows, moves, drop and all unwind paths |
| Host services and concurrency | Pending | Explicit runtime adapters, FFI, tasks, scopes, cancellation and platform evidence |

## Published progress (#496)

The README progress bar counts **completed coverage areas**, not individual language
constructs, implementation effort or release readiness. Its denominator is every row
of the Coverage ledger above; only `Implemented` counts. `Partial` and `Pending`
contribute zero. Display floor(100 × completed / total) and a 20-cell bar with
floor(20 × completed / total) filled cells. Broad areas have equal weight; changing
this inventory can decrease the percentage. A 100% area count still requires the
completion evidence matrix below before claiming full production coverage.

[[Native Progress Generator]] derives the README marker block from this table;
[[Native Progress Workflow]] refreshes it on every dev push, including PR merges.
Update row states only with matching implementation and evidence in the same PR.
[[Native Progress Tests]] rejects malformed inventory and ambiguous output markers.

Resolved Grill Log: no subjective partial credit or test-count proxy. The count and
denominator stay visible so readers can audit the coarse measure.

## Current Core control-flow contract

[[Pudu Core]] carries numeric CoreLoopId identities; source labels resolve nearest-first during lowering. CoreWhileValue is unit, CoreLoopValue carries its observed break type (or CoreNeverType without a local break), and CoreBreak/CoreContinue identify their destination. A while condition is lowered outside that while's loop frame: control transfer there targets an enclosing loop, matching the checker and interpreter. Never joins a reachable branch without inventing a value. Only direct terminal transfers or provably divergent trailing results make a block divergent.

The emitter places continuation targets before condition setup and break targets outside the loop body. Break operands finish before result assignment and transfer. Numeric targets avoid label collisions. Every loop body result is evaluated and discarded; breaking with a value retains all effects even when the loop result is discarded. Unsupported ownership-bearing constructs still refuse until cleanup is represented explicitly.

## Grill Log

- **Q:** Can full coverage mean removing all refusals immediately? **A:** No; every admitted surface needs exact runtime semantics and evidence. The ledger keeps missing behavior explicit. Rejected: unverified C translation or fallback disguised as compilation.
- **Q:** May C break/continue implement labelled transfers? **A:** Resolved numeric destinations are required; C's nearest-loop rules cannot express outer transfers. Rejected: source labels or textual rewriting.
- **Q:** Can a while condition see its own target? **A:** No; checker and evaluator install the target only for its body. Rejected: pushing the loop before lowering its condition.
- **Q:** Does this change language semantics? **A:** No; this projects already checked control flow and preserves the shared language specification. Rejected: a second type checker inside the backend.

## Dependencies and consumers

[[Backend]] · [[Core IR]] · [[grammar/pudu]] · [[architecture/SEMANTICS]] · [[ADR-0002-compiler-pipeline]]

## Referenced by

[[architecture/_MOC]] · [[Backend]] · [[Native C11 Backend Delivery]]

## Unit-result conformance #490

[[ADR-0025-if-without-else-unit-results]] resolves the checker/evaluator discrepancy as a correctness repair: a no-else if yields unit on both normal paths, preserving all effects, transfers, errors and cleanup. Tree, compiled and boxed-region evaluation, derive true-folding and dynamic contextual checking now agree in focused regression checks. Native lowering removes the temporary taken-value refusal and its differential cases pass. With-else values stay unchanged. This closes the #489 oracle boundary for represented branch values; unsupported syntax and runtime representations remain incomplete coverage.

## Solved type publication

The full-analysis native CLI already retains CompileResult.compileTypes and compileSchemes. TypeInfo.typeAt uses complete Span identities and publishes final substitutions; those facts must enter lowering before inferred scalar signatures, records, sums and generic specialization are broadened. The lowerer must not infer them again. Cached ExecutionProducts omit these facts; native cache support needs its own product contract rather than expanding interpreter execution products implicitly.

## Completion evidence matrix

The full-emission goal is unproven until all of the following are satisfied together:

1. Every implemented expression, statement, declaration, pattern and literal form has a semantic lowering path. Pattern-match exhaustiveness in Haskell alone does not count when a branch only emits E6001.
2. Every formed runtime type and callable form has representation, construction, access, dispatch, update, lifetime and failure behavior. Inferred, generic and generated identities use the checker/resolver's canonical products.
3. Every supported standard-library/host boundary has native execution evidence, including failure and cleanup behavior. Successful ordinary fixture programs must build natively without an unsupported-construct refusal; runtime platform refusals must match the interpreter's own behavior.
4. Differential tests compare stdout, stderr, exit status, mutation and observable resource effects across tree, compiled, optimized-region and native paths where each path is admitted. Effect/order/transfer/cleanup regressions must exercise actual paths rather than passing by fallback.
5. Every reachable runtime diagnostic retains its code, source span, message, notes, help and output ordering. Native representation failures cannot be deferred as opaque C errors.
6. Module linking, constants/derives, generated spans, closure capture, defaults, borrowing, moves/drop, recovery, concurrency and cancellation are explicitly covered rather than inferred from scalar examples.
7. Clean supported-toolchain builds, complete regression/integration gates, platform runtime tests and independent implementation/architecture/wiki review all pass with remaining limitations stated.

A passing slice or a smaller supported subset cannot satisfy this matrix. The goal remains active while any ledger row, runtime surface or verification obligation is pending.

## Solved scalar signatures (#491)

[[Compiler Lower Types]] projects the complete checked module facts into existing scalar Core representations. Final monomorphic synchronous schemes admit inferred and aliased Int/Bool parameters and Int/Bool/unit results; exact expression facts admit annotated scalar locals. Missing facts and unrepresented formed types retain E6001. This changes backend coverage without changing Pudu semantics.

Resolved Grill Log: facts belong to the same successful root CompileResult, exact complete spans identify generated expressions, and canonical builtin identities select representation. No duplicate inference, interpreter cache expansion or new ownership representation.

## Unit call representation (#492)

An empty Core block represents the source unit literal. Canonical settled UnitTypeValue may occupy a parameter slot using the existing C int sentinel ABI; unit-returning functions remain void. Argument emission discards effects exactly once before binding zero, preserving left-to-right order, abrupt transfer, diagnostics and depth-check timing. No syntax or checker change is introduced. Unit display/equality are implemented by #493; general tuple/aggregate representations remain pending.

Resolved Grill Log: never put a void C call in an argument initializer or erase Result as unit. The existing wrappers retain all parameter slots and only execute after arguments complete.

## Unit operations (#493)

Lower display(unit), unit equality and inequality through the existing Core/display model. Freeze every eager unit operand through its effects and an integer-zero temporary. Inline display evaluates its operand once and prints exactly the two UTF-8 bytes (). Select the string runtime printer. #494 represents the interpreter E7001 runtime refusals for Unit arithmetic/ordering; treating those operations as integer arithmetic would change behavior. No owned text representation is implied.

Resolved Grill Log: effects precede constant unit representation, including calls, transfers and failures; both operands execute left to right. No syntax/checker change or Result erasure.

## Explicit operator runtime failures (#494)

CoreOperatorFailure carries the original operation span, ordered operands and shared E7001 message. Compiler Lower Scalar owns normal operator classification and exact fact admission. Bool ordering is valid; unit ordering/arithmetic and invalid Bool operations trap only after operand effects. Shared diagnostic factories preserve generic cannot-apply versus comparisonOnly unsupported-operator wording. Never operands preserve transfer without fabricating a trap; print Result guards remain. Valid unimplemented Int/owned operations retain explicit coverage boundaries. Resolved Grill Log: actual interpreter dispatch is authoritative, with no native arithmetic approximation or second inference pass.

## Platform Int operators (#495)

[[Backend Runtime Integer]] defines all platform Int bitwise, complement, shift,
wrapping and saturation operations in portable C11. Conversion from high unsigned
bit patterns avoids implementation-defined signed narrowing. Right shift fills
sign bits explicitly; shifts validate counts before shifting and preserve distinct
negative/width E7004 diagnostics through [[Diagnostic Arithmetic]]. Saturation
checks safe bounds before signed operations. [[Backend Integer Programs]] supplies
boundary and seeded full-width mathematical expectations in addition to actual
interpreter/native comparison. The target remains the existing explicit 64-bit
model; other integer families and numeric types remain coverage obligations.

Resolved Grill Log: portable defined arithmetic and exact observable parity are
required together. A passing operator slice does not complete numeric families.

## Deferred out-of-range literal intermediates (#498)

The exact carrier now preserves accepted positive 2^63 intermediates through
blocks, locals, calls, mutation, branches, loop slots and entry reporting.
Independent mathematical cases and tree/compiled/native probes pass. The #499
wide-recursion crash discovered during integration is repaired by explicit
heap frames and iterative dispatch in [[Native Execution Frames]]. All 19 clean
gates and 669 test groups now pass. A separate native sanitizer run against the
tree evaluator passes 20 groups, including the permanent pressure case; controlled
allocation/cleanup tests and real CLI parity checks also pass. The ledger now
counts 4/14 complete areas (28%). This is still far from full language coverage.

[[Exact Native Integer Carriers]] and [[Native Frame Pressure Repair]] record
the contracts and local evidence. Independent implementation/architecture/wiki
review, other supported platforms and reviewable PR partitioning remain pending
before promotion. Subsequent numeric work begins with canonical fixed signed
widths (#497), retaining the full unsigned/large/float/Decimal obligations.

## Wide integer prerequisite (#501)

[[Native Wide Integers]] specifies staged Int128/UInt128 delivery. The raw
[[Backend Word128 Kernel]], [[Backend Wide Integer Values]] and
[[Backend Wide Operations]] have independent executed corpora (#501–#503).
[[Native Wide Runtime Integration]] adds full-width output/status and actual
runtime dependency selection (#504, locally validated). [[Native Wide Frame Bridge]] integrates the frame ABI (#506, all 19 clean gates/678 groups pass);
[[Native Wide Source Admission]] adds checked source conformance #507, all 19 clean gates/678 groups pass. These prerequisites do not
change the completed-area count.

## Closed-output parity finding

Before #505, a checked scalar print program with a closed pipe reader exits 0
with empty stderr in both evaluators, while native exits by SIGPIPE (signal 13). Local evidence: ~/.codex/tmp/pudu-504/pipe-probe.json.
This contradicted complete output parity. The refined #505 repair now matches
108 CLI cases, including stderr failures and inherited blocked signals. The clean
run passed 18 gates and exposed one stale standard-header whitelist assertion;
after the inspected signal.h allowance recompiled under -Werror, all 677 groups
pass in the full-suite rerun. Together these checks restore the scalar row.
Independent review and additional supported-platform evidence remain pending.
Printing helpers must not terminate an ignored print-result program by signal.

## Floating output prerequisite (#508)

[[Native Floating Point]] preserves the locked GHC show policy, including
strict decimal margins and exact layout. [[Native Floating Natural Kernel]]
provides checked finite-domain scratch, with 6,780 independent mathematical
rows and seven minimal roots passing both C compilers/sanitizers; all 19 clean
gates/680 groups pass. Exact
formatting, typed arithmetic and source integration remain pending; this is
not BigInt support and does not change completed-area counts.

[[Native Binary64 Formatter]] now matches locked GHC show bytes across 63,661
unique encodings and exact minimal helper closures under Clang/GCC/sanitizers
(#509, all 20 clean gates/682 groups pass). Source/binary archives retain the adapted
code's notices. This raw-bit helper performs no IO and does not admit floating
source; typed arithmetic and Core/frame/source integration remain required.

[[Native Floating Values]] adds bit transport and Double-first arithmetic with
54,344 raw-result/predicate rows (#510, all 20 clean gates/685 groups pass). It remains a helper
prerequisite: Core/frame/source admission, entry reporting, target conformance
and full numeric-family coverage remain required. Progress stays 4/14 (28%).

[[Native Floating Runtime]] connects actual runtime catalogue/dependency selection
and exact output (#511, all 20 clean gates/689 groups pass). Closed-pipe and counted IO
checks pass both compilers/sanitizers. Core/frame/source transport remains open;
this prerequisite does not change the completed-area count.

## Floating source admission (#512)

Float32/Float64 values now pass through Core, frames and C as raw binary64
encodings in a `floating` cell. Literals carry the bits FloatLiteral parsed;
each `+ - * /` is one helper call that rounds, and narrows for Float32, before
the next operation; comparisons use the IEEE predicates; negation flips the
sign bit, NaN included. Other accepted operators trap with the evaluator's
E7001 wording after their operands run. Float and Bool entry results print
their value and exit zero, and stay silent on a closed pipe, as `pudu run`
does. Evidence: the float corpus matches independent IEEE answers and the
interpreter; all 42 native groups pass under Clang and GCC 15; the float
groups pass Clang ASan/UBSan (GCC's UBSan runtime is not installed on this
host); CLI parity holds for open and closed stdout under both compilers.
Runtime revision is 8. Progress stays 4/14 (28%): BigInt, Decimal and the
print Result entry keep their rows partial.
