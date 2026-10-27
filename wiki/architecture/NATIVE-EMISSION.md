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
| Explicit scalar functions, recursion, call depth | Implemented (#488) | Preserve argument ordering and diagnostics |
| Loop control and scalar loop results | Implemented (#489) | Preserve labels, transfers, Never joins and condition-scope evidence |
| Complete numeric families | Pending | Widths, floats, Decimal, wrapping/saturation, bitwise rules |
| Text and bytes | Pending | Owned representation, UTF-8, allocation, comparisons and IO failures |
| Records, tuples, sums and collections | Pending | Layout, construction/update, access, equality, allocation and destruction |
| Pattern matching and iteration | Pending | Exhaustive ordered decisions, guards, bindings, ranges and iterator protocol |
| Modules and constants | Pending | Canonical linkage, qualified identities, checked folds and graph publication |
| Callables and generic code | Pending | Closures/captures, defaults, monomorphization and trait dispatch |
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

## Oracle discrepancy #490

Value-position if-without-else has checked Unit type but the evaluator returns its taken branch's actual value. Native code cannot erase an Int/Bool/Result merely because the checker says Unit. Issue #490 owns the compatibility decision and parity repair. Until resolved, #489 admits genuinely Unit/Never branches and refuses other taken values explicitly; these refusals remain incomplete coverage.

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
