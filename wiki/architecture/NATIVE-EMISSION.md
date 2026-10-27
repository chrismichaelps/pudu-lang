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
| Entry result reporting | Partial (#512, #521, #525) | Integer statuses, unit silence, and Bool/Float/Str/Char/tuple/record/sum rendering match `pudu run`; an entry returning print's Result remains |
| Complete numeric families | Partial (#495, #497, #500, #507, #512) | Fixed integers, Int128/UInt128 and Float32/Float64 are admitted; BigInt and Decimal remain |
| Text and bytes | Partial (#515, #516, #517, #518, #559) | Owned Str values, Char values, operators, rendering, printing, entries, charAt, every Int/Bool/Str-result method (trim and case mapping included), `split`, `lines`, `chars`, `toInt` and `toFloat` match the interpreter (#559); Bytes (`toBytes`), `toDecimal` and print Result remain |
| Records, tuples, sums and collections | Partial (#521, #525, #552, #556, #558) | Tuples, records and sums of every module, generic ones at each instantiation, and the built-in Option/Result are boxed, refcounted values with construction, field, position and payload reads, equality, ordering (tuples), rendering and run-time E7001 naming held variants; collections (Map, Set, Bytes, Range) remain; arrays are native, `sortBy` and slicing by a written range included (#556, #558) |
| Pattern matching and iteration | Partial (#525, #540, #541, #554, #558) | `match`, `if let` (with `else if` chains) and `while let` (with labels, `break` and `continue`) lower every pattern form in order with guards, bindings, literals, ranges, tuples, constructors, records and alternatives; `let ... else` retains bindings in the enclosing block (#541); `for` walks written ranges and sequence types (#554); sequence patterns are native (#558); range values, `for` over Str, tuples and collections remain |
| Modules and constants | Partial (#539, #543) | Calls through selective imports, aliases and qualifiers, functions of every reachable module, and records and sums by canonical identity match the interpreter; folded scalar/tuple/record/sum constants now preserve canonical solved identity; callable and unrepresented constant families remain |
| Callables and generic code | Partial (#551, #552, #555) | Implementation members, inherited defaults, type- and trait-qualified calls, `toText()`, generic functions and implementations (one copy per type list), lambdas with captures, named functions as values and calls through values match the interpreter; default parameter values, method values, higher-kinded parameters and `dynamic` values remain |
| Accepted operations with runtime refusals | Partial (#494, #512) | Represented Unit/Bool/float operators retain E7001; remaining runtime types/operators still need equivalent coverage |
| Errors, references and resources | Partial (#544, #553) | Shared borrows, dereference and `?` on Result and Option match the interpreter; mutable loans with writeback, moves, drop and all unwind paths remain |
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
with empty stderr in both evaluators, while native exits by SIGPIPE (signal 13).
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

## Owned text (#515)

[[Native Text Runtime]] carries Str as a view over static or refcounted bytes.
Stores build the new value before releasing the old, callee frames retain
their text arguments, returned text hands its reference to the destination,
and frames release their text slots on return and unwind. Text operators,
display/show and Str entry rendering follow `textOperation`, `callDisplay`,
`callShow` and `reportResult`. Method calls are next and must keep the
evaluator's argument-before-receiver order (#514). Evidence:
[[Backend Text Programs]] against answers and the interpreter, and
[[Backend Text Leak Tests]] with counted heap blocks. Runtime revision 9.
Progress stays 4/14 (28%).

## Str methods (#516)

[[Compiler Lower Text]] admits length, isEmpty, contains, startsWith,
endsWith, indexOf, spanOf, spanNotOf, drop, take, slice, repeat, reverse,
escapeHtml and replace on Str receivers, evaluating arguments before the
receiver as the evaluator does (#514). [[Native Text Methods]] implements
them by scalar; drop/take/slice return views that retain the source, and
E7004 refusals carry the evaluator's messages. Evidence: [[Backend Text
Method Programs]] against hand-written answers and the interpreter, with
counted-leak runs. Progress stays 4/14 (28%).

## Trim and case mapping (#517)

[[Native Text Case]] reads its case and whitespace tables from the text
library linked into pudu (text-2.1.4) when C is emitted, so native follows
the interpreter's Unicode version by construction. [[Backend Text Case
Tests]] compares every scalar and re-checks that the linked library has no
context rules. Progress stays 4/14 (28%).

## Char values (#518)

Char is a `uint32_t` scalar in its own cell member. Literals, the six
comparisons, `display`, `show`, `code`, `toText`, `Str.charAt` and Char entry
results follow `comparisonOnly`, `callDisplay`, `renderValue`,
`callCharMethod` and `charAtFast`; other operators trap with the evaluator's
E7001 wording after their operands run. [[Native Char Runtime]] holds the
helpers; [[Backend Char Programs]] checks hand-written answers, the
interpreter's refusals and counted leaks under Clang, GCC 15 and ASan/UBSan.
Runtime revision 10. `charFromCode` waits on Option. Progress stays 4/14 (28%).

## Tuples (#521)

[[Native Aggregate Emission]] represents a tuple as a refcounted `pudu_box`
of cells with per-type make, drop, show, equal and compare helpers, written
only when used. Frames now track every owned slot (text or box) with a kind,
so retain on entry, release on return and unwind, and destination
replacement share one path. Ordering applies compareValues, with the total
float order of #522, through base's Ord defaults. [[Backend Tuple Programs]] holds
answers, refusals and counted leaks under Clang, GCC 15 and ASan/UBSan.
Runtime revision 11. Progress stays 4/14 (28%).

## Records (#521)

Records of the root module without type parameters share the tuple box. Their
layout comes from the checker's own formation (`declaredRecords`), not from
type syntax. Literals run fields in written order and store declaration order
(#519); updates run the base first; field assignment rebuilds the local's
value as it is after the assigned value ran. [[Backend Record Programs]] holds
answers, refusals and counted leaks under Clang, GCC 15 and ASan/UBSan.

## Sums and match (#525)

A sum is a `pudu_box` whose first cell is the variant tag, followed by that
variant's payload in declaration order; the root module's sums and Option and
Result at concrete arguments share it. [[Compiler Lower Sum]] admits a
variant only where the checker typed the span as a sum with that variant, so
`Shape.Circle(3)` resolves exactly as checking did (#536 repaired that
checking). [[Compiler Lower Match]] and [[Compiler Frame Match]] lower `match`
into a chain of tag, literal, range and guard tests over one subject slot.
An operator failure on a sum names the variants it holds at run time
("cannot apply < to a Some and a None"), built from the shared wording. A
sum's type argument left unconstrained by checking (the error type of `Ok(1)`)
takes a unit layout, which no value can observe. [[Backend Sum Programs]]
holds hand-written answers and the interpreter's refusals; they pass under
Clang, GCC 15 and Clang ASan/UBSan, and the counted-leak run includes them.

## Modules (#539)

[[Compiler Lower]] lowers every module of the compiled program, each with its
own checked facts, from the root's entry. Functions are keyed `Module.function`;
a written callee resolves in its module as the evaluator links imports.
Records and sums are named by canonical identity and rendered by their written
name. [[Backend Module Programs]] covers every import form, a module that
imports another, two modules' types of one name, and a failure inside an
imported function. A run over every fixture with `main` moved from 3 to 14
programs whose output matches the interpreter byte for byte, with none
differing; the refusals left are led by collection and function types,
generics, `unsafe` blocks and arrays.

## if let and while let (#540)

[[Compiler Lower Match]] lowers `if let` as a two-arm match, the pattern's
block and then a wildcard taking the `else` branch or unit, and `while let` as
a `loop` that matches the subject afresh each turn and breaks on the first
refused value. Both inherit every pattern form, scope and refusal of `match`.
[[Backend Sum Programs]] covers chains, an expression value, a value-less
`if let`, side-effect order of the subject, labelled and nested loops, and
overflows inside a body and a subject.

## Refutable let bindings (#541)

[[Compiler Lower Match]] now lowers `let PATTERN = subject else fallback`
through the existing match/frame path. Success binds into the containing
block; failure runs the diverging fallback with the original outer scope.
[[Backend Sum Programs]] adds exactly-once evaluation, sequential bindings,
partial failure with shadowing, alternative/record/range patterns, labelled
transfers and exact overflow diagnostics. Clang, GCC 15, ASan/UBSan and both interpreter modes pass the corpus;
69 counted programs release every allocation. All 20 clean repository gates
pass, including 711 optimized test groups. The pattern/iteration area remains
partial because iteration and sequence patterns still need native support.

Delivery and evidence: [[Native Refutable Binding Delivery]].

## Module folded values (#543)

[[Native Folded Constants]] passes the compiler's existing immutable products
into native module scopes. [[Compiler Lower Constant]] preserves represented
scalars and aggregates against the solved canonical type at each reference;
missing products and unsupported families retain located E6001 refusals.
[[Backend Module Programs]] and [[Native Solved Types Tests]] cover the new
boundary. No runtime initializer is evaluated by lowering. Clang, GCC 15, ASan/UBSan, both interpreter modes and 71 counted
allocation programs pass. All 20 clean gates pass, including 712 optimized
test groups; the real CLI native build also matches both interpreters.
Evidence is recorded in [[Native Folded Constant Delivery]].

## Shared references (#544)

[[Compiler Lower Reference]] lowers `&` and `*` of represented values to the
operand itself, as the evaluator's identity operators do, once the exact
checked facts show a shared reference. `&mut` keeps refusing until calls write
places back. [[Backend Shared Reference Programs]] covers parameters, results,
aggregates, transfers, failure provenance and borrows of reassigned variables.

## Trait methods (#551)

[[Native Trait Methods]] lowers every method checking declares as an instance:
an implementation's own member, or the trait member it inherits with `Self`
bound to the owner. A receiver's checked type picks the method; arguments run
before the receiver, which is passed first. Str and Char keep their built-in
members first, and `toText()` falls back to `display`. [[Backend Method
Programs]] holds the evidence. Generic implementations and `&mut self` refuse.

## Generics (#552)

[[Native Generics]] lowers each generic function, generic implementation and
generic record once per type list checking instantiated it at. Bounded calls
inside a copy dispatch to the concrete method. The fixture sweep caught a
specialization that returned no result without refusing, which compiled two
Std programs to an empty `main`; lowering now refuses any construct that stops
without saying why. [[Backend Generic Programs]] holds the evidence.

## Try (#553)

[[Compiler Lower Try]] lowers `?` to a match whose failure arm returns the
failure rebuilt at the enclosing function's result type. In `main` that type
comes from the checked signature, kept apart from the entry's own result
handling so print-Result bodies keep refusing. [[Backend Try Programs]] holds
the evidence.

## For (#554)

[[Compiler Lower For]] lowers `for` over a range written with both ends and
over types with `begin` and `advance`, as `evaluateFor` walks them, under an
ordinary loop frame. Inclusive ranges stop at their last element before
stepping, so they reach the largest `Int` without overflowing.
[[Backend For Programs]] holds the evidence.

## Closures (#555)

[[Native Closures]] makes function values refcounted boxes whose first cell
names the lifted function they run. Lambdas copy what they mention, named
functions become forwarders, and calls through values reuse the frame call
path. Ordering tuples now follows `comparableValue` and `compareValues` for
held functions, records and sums. [[Backend Closure Programs]] holds the
evidence.

## Arrays (#556)

[[Native Arrays]] carries arrays as boxes around growable buffers with the
evaluator's method semantics. `map`, `filter` and `reduce` are loops, and
updates that replace their own variable take it, so building an array stays
linear. Found on the way: #557, unannotated lambda parameters' members are not
checked when the lambda is an argument, and such lambdas refuse natively.
[[Backend Array Programs]] holds the evidence.

## Sorting, sequence patterns and slices (#558)

`sortBy` runs as loops that ask the comparison what the evaluator's natural
merge sort asks ([[Compiler Lower Sort]]). Sequence patterns and slicing by a
written range follow `matchPattern` and `rangeBounds`, and a slice failure's
help names the length through a new computed help on `CoreFailText`
([[Compiler Lower Slice]]). Str indexing by Int is native. A loop body's tail
is lowered as a statement, so a trailing `match` whose arms print no longer
refuses. [[Backend Array Pattern Programs]] holds the evidence.

## Str methods with collection results (#559)

`split`, `lines` and `chars` build arrays of views into the receiver
([[Native Text Pieces]]); `toInt` and `toFloat` validate as
`Eval.Builtin.TextNumber` does and build their Option in Core
([[Native Text Number]]). [[Backend Text Collection Programs]] holds the
evidence.
