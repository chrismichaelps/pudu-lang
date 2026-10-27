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
| Platform Int/Bool, checked arithmetic, if/while, printing | Implemented | Preserve differential evidence |
| Scalar functions, recursion, call depth | Implemented (#488, #491) | Preserve inferred/aliased signature facts, argument ordering and diagnostics |
| Loop control and scalar loop results | Implemented (#489) | Preserve labels, transfers, Never joins and condition-scope evidence |
| Unit values, parameters and operations | Implemented (#492, #493) | Preserve effect-first temporaries, display and equality; invalid unit operations remain a runtime-refusal obligation |
| Entry result reporting | Partial | Int status/unit silence work; Bool and other value-result rendering still need native admission and CLI parity |
| Complete numeric families | Pending | Widths, floats, Decimal, wrapping/saturation, bitwise rules |
| Text and bytes | Pending | Owned representation, UTF-8, allocation, comparisons and IO failures |
| Records, tuples, sums and collections | Pending | Layout, construction/update, access, equality, allocation and destruction |
| Pattern matching and iteration | Pending | Exhaustive ordered decisions, guards, bindings, ranges and iterator protocol |
| Modules and constants | Pending | Canonical linkage, qualified identities, checked folds and graph publication |
| Callables and generic code | Pending | Closures/captures, defaults, monomorphization and trait dispatch |
| Accepted operations with runtime refusals | Partial (#494) | Represented Unit/Bool operators now retain E7001; remaining runtime types/operators still need equivalent coverage |
| Errors, references and resources | Pending | Result/Option propagation, borrows, moves, drop and all unwind paths |
| Host services and concurrency | Pending | Explicit runtime adapters, FFI, tasks, scopes, cancellation and platform evidence |

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

Lower display(unit), unit equality and inequality through the existing Core/display model. Freeze every eager unit operand through its effects and an integer-zero temporary. Inline display evaluates its operand once and prints exactly the two UTF-8 bytes (). Select the string runtime printer. Unit arithmetic/ordering remain explicit E6001 boundaries until the interpreter E7001 runtime refusal is represented; accepting those as integer operations would change behavior. No owned text representation is implied.

Resolved Grill Log: effects precede constant unit representation, including calls, transfers and failures; both operands execute left to right. No syntax/checker change or Result erasure.

## Explicit operator runtime failures (#494)

CoreOperatorFailure carries the original operation span, ordered operands and shared E7001 message. Compiler Lower Scalar owns normal operator classification and exact fact admission. Bool ordering is valid; unit ordering/arithmetic and invalid Bool operations trap only after operand effects. Shared diagnostic factories preserve generic cannot-apply versus comparisonOnly unsupported-operator wording. Never operands preserve transfer without fabricating a trap; print Result guards remain. Valid unimplemented Int/owned operations retain explicit coverage boundaries. Resolved Grill Log: actual interpreter dispatch is authoritative, with no native arithmetic approximation or second inference pass.
