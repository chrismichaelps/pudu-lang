---
type: architecture
semantic_version: "0.1.0-draft"
status: NORMATIVE_DRAFT
tags: [architecture, semantics]
aliases: [Semantic System, Pudu Semantics]
---

# Pudu Semantic System

This page defines the normative semantic model of [[Pudu Language]]. [[grammar/pudu]] defines surface syntax; this page defines meaning. Implementation behavior that disagrees with this page is a compiler defect unless a superseding ADR changes the semantic version.

## Semantic Purpose

Pudu programs should be locally readable, memory-safe in safe code, deterministic absent explicit concurrency/IO, and predictable about evaluation order, failure, cleanup, numeric behavior, and cancellation.

## Semantic Layers

1. **Elaboration:** surface sugar becomes a smaller untyped core while preserving source provenance.
2. **Resolution:** names bind to stable declaration and local symbol identities.
3. **Typing:** expressions receive types and typed failure obligations.
4. **Ownership:** moves, borrows, initialization, and destruction are proven valid.
5. **Lowering:** checked programs become [[Core IR]] with explicit control and cleanup.
6. **Evaluation:** interpreter and native backend implement the same Core IR observations.

No layer may repair an invalid state that an earlier layer was obligated to reject.

## Judgement Notation

- `Σ` — global module/type/trait environment.
- `Γ` — lexical value environment mapping symbols to types, mutability, and initialization.
- `Ω` — ownership state mapping places to `Available`, `Moved`, `Shared(n)`, or `Exclusive`.
- `Φ` — possible recoverable failure type of the current function.
- `κ` — async/cancellation capability (`Sync` or `Async`).
- `e ⇝ e'` — one dynamic evaluation step.
- `v` — a fully evaluated value.
- `p` — an assignable place.

Primary static judgement:

```text
Σ ; Γ ; Ω ; Φ ; κ ⊢ e : T ▷ Ω' ! E
```

Meaning: under environments `Σ`, `Γ`, and ownership state `Ω`, expression `e` has type `T`, leaves ownership state `Ω'`, and may propagate recoverable failures `E`, within capability `κ`.

Supporting judgements:

```text
Σ ⊢ T well-formed
Σ ; Γ ⊢ pattern : T ⇒ Γ_bindings
Σ ⊢ impl coherent
Σ ; Γ ; Ω ⊢ p readable | writable | movable
Σ ⊢ match_arms exhaustive for T
```

## Binding and Scope Rules

- Lexical scope begins after a successful binding declaration and ends at its containing block.
- A declaration cannot read itself during initialization unless it is a function declaration admitted for recursion.
- Shadowing is permitted for immutable locals only when the previous binding is not borrowed; shadowing a `var`, parameter, import, or type name is a lint error initially and may become a hard error for public code.
- `let x = e` evaluates `e` before binding immutable `x`.
- `var x = e` evaluates `e`, binds initialized mutable `x`, and makes `x` a writable place.
- `const x = e` uses the compile-time evaluator and substitutes an immutable typed value.
- Every read requires definite initialization on all incoming control-flow paths.

## Name Resolution Rules

- Resolution is lexical, deterministic, and independent of import order.
- Local value names shadow module declarations; type and value namespaces are distinct; variants live in their type namespace but can be imported explicitly.
- Imports never re-export implicitly.
- Ambiguous unqualified references are errors with related spans for every candidate.
- Trait method lookup considers inherent methods first, then in-scope traits; multiple applicable trait methods require qualification.
- Cyclic module imports are allowed only for declaration signatures. Module-scope values are compile-time constants, so initialization cycles and module-load execution do not exist.

## Type Formation and Equality

- Nominal types are equal only by declaration identity and equal type arguments.
- Structural equality applies to tuples, functions, and internal anonymous record patterns, not named record declarations.
- Type aliases expand transparently and cannot be recursive without passing through a nominal data constructor.
- Function types normalize to parameter types, success type, recoverable error type, and async capability. Surface `Result[T, E]` supplies success `T` and failure `E`; absent `Result`, failure is `Never`. Surface `async fn` supplies `Async`, while ordinary `fn` supplies `Sync`.
- `Never` is a subtype of every type solely for unreachable control-flow joins.
- `&mut T` may reborrow temporarily as `&T`; general subtyping and implicit variance are not in v1.
- Generic instantiation substitutes monotypes satisfying every declared trait constraint.

## Inference Boundary

- Literals, local bindings, private return types, and private unannotated parameters may participate in bidirectional local inference.
- Exported signatures are fully annotated and checked without inspecting callers.
- Inference never chooses an implicit lossy numeric conversion, trait implementation among overlapping candidates, or failure conversion lacking a unique `From` implementation.
- Generalization occurs only for syntactic values at immutable `let` bindings; mutable bindings remain monomorphic to avoid unsound value restriction interactions.
- Unresolved type variables at a public or statement boundary produce a diagnostic rather than defaulting, except integer literals may default to `Int` when the value fits.

## Expression Evaluation Order

- Evaluation is strict and left-to-right.
- In `f(a, b)`, evaluate `f`, then `a`, then `b`, then call.
- Record and collection elements evaluate in source order.
- Boolean `&&` and `||` short-circuit.
- A block evaluates statements sequentially and yields its final expression or unit.
- Assignment evaluates the target place once, then the right side, then stores.
- Pattern guards evaluate only after structural pattern success.
- Optimizations must preserve all observable ordering: IO, mutation, panic, failure propagation, destruction, and cancellation points.

## Control-Flow Typing

- `if` conditions have `Bool`; reachable branch values unify to one result type.
- `match` scrutinee evaluates once. Arms are tested top-to-bottom; the first matching pattern with a true guard executes.
- Closed sum, boolean, tuple/record, and finite literal-domain matches are statically checked for usefulness and exhaustiveness where decidable.
- `return e` requires `e` compatible with the enclosing function success type and transfers cleanup through every exited scope.
- `break` and `continue` target the nearest loop and transfer cleanup for exited inner scopes.
- Code after an expression of type `Never` is unreachable and warned unless compiler-generated.

## Function and Call Semantics

- Arguments bind by value unless their parameter type is a reference.
- By-value non-`Copy` arguments move; `Copy` arguments duplicate their value.
- Calling a synchronous failing function produces `Result[T, E]`. Calling an `async fn` produces a cold `Task[T, E]`; its surface `Result[T, E]` return is normalized into the task's success/failure channels rather than nested as `Task[Result[T, E], Never]`.
- Default expressions are type-checked at the declaration in its lexical environment and may reference only module constants plus earlier parameters. A call evaluates the callee and supplied arguments left-to-right, binds those parameter values, then evaluates omitted defaults in parameter order. Defaults cannot observe caller locals or ambient mutable state; their declared recoverable failures propagate as failures of the call expression.
- Recursion is permitted. Tail calls are not guaranteed to be optimized in v1.
- Trait-bounded generic calls use static monomorphization for native compilation; the interpreter may use equivalent dictionaries internally without observable difference.
- Exported functions form compatibility boundaries: changing parameter order/type, return type, failure type, async status, or generic constraints is breaking.

## Recoverable Failure and Panic

- Recoverable failures are values, canonically `Result[T, E]`.
- `?` elaborates to an exhaustive match that returns `Err(convert(error))` early; it never catches panic or cancellation.
- A function returning ordinary `T` cannot propagate recoverable failure.
- `panic` aborts the current task after deterministic cleanup of initialized safe resources. It is intended for violated invariants, not expected input/domain failure.
- Double panic during cleanup terminates the process with a runtime diagnostic; it cannot be represented as `Result` because the original invariant is already lost.
- Foreign exceptions are caught at the boundary and mapped to declared errors or panic only when the foreign contract marks them unrecoverable.

## Ownership State Transitions

```text
declare initialized p:      absent → Available
read Copy p:                Available → Available
move p:                     Available → Moved
shared borrow p:            Available/Shared(n) → Shared(n+1)
end shared borrow p:        Shared(n) → Shared(n-1)/Available
exclusive borrow p:         Available → Exclusive
end exclusive borrow p:     Exclusive → Available
replace p:                  Available(writable, unborrowed) → Available
reinitialize p:             Moved(writable, unborrowed) → Available
drop p:                     Available → Moved
```

- Reading, moving, borrowing, or dropping from `Moved` is rejected. Storing a new value into a writable, unborrowed moved place is reinitialization and is permitted.
- Moving or mutating from `Shared(n)` and every access except the active exclusive reference from `Exclusive` is rejected.
- Assignment resolves the destination place once, then evaluates the right side. At the store point, an initialized destination's old value is dropped immediately before replacement; an uninitialized destination is stored without a drop. If right-side evaluation fails, replacement has not occurred and any old destination value not consumed by that evaluation remains in its resulting ownership state.
- Partial moves are tracked by place projection. A partially moved aggregate may use untouched fields but cannot be read or dropped as a whole until every moved field is reinitialized. Partial moves from a type with user `Drop` are rejected because its destructor requires the whole value.
- Borrow regions run from creation through last possible use, constrained by control flow. They do not extend merely to the lexical block end.
- References cannot be stored in a value that outlives the referent; return references must derive from explicitly borrowed parameters, never locals.
- Drop order is reverse declaration order within a scope; aggregate fields drop in declaration order after user `Drop` code completes.
- `Copy` is compiler-controlled: user-written implementations are rejected. A value is copyable only when its representation contains exclusively `Copy` components and has neither resource identity nor `Drop`; mutable references are never `Copy`. Generic copying generates structural `Copy` obligations for all reachable type parameters.

## Resource Safety

- Initialization is all-or-nothing from the caller's perspective; already initialized fields are dropped if later construction fails.
- Cleanup runs on normal exit, recoverable early return, loop transfer, cancellation, and panic where runtime integrity remains available.
- `Drop` cannot be async in v1. Potentially blocking resource closure belongs in an explicit async standard-library operation before ownership ends.
- A `Drop` implementation must not move from `self`, resurrect references, or silently discard an error-bearing close contract.
- Resources whose close can recoverably fail expose explicit `close() -> Result[(), E]`; implicit `Drop` performs best-effort release and reports failure through runtime diagnostics without changing a successful function result.

## Numeric Semantics

- Integer representations are two's-complement; `Int`/`UInt` width equals the compilation target pointer width and is recorded in artifact metadata.
- Checked fixed-width arithmetic either yields the exact mathematical result or a typed overflow failure; it never invokes undefined behavior.
- Wrapping and saturating operators are separate typed operations and cannot be introduced by optimization.
- Shifts require a non-negative count smaller than the bit width in checked form; library operations provide masked variants explicitly.
- Floating point follows the declared target IEEE behavior. Reassociation, contraction, and fast-math transformations require an explicit future compilation mode and cannot be default.
- `Decimal` has no semantics until its precision/rounding ADR is accepted; it is reserved but rejected by semantic analysis meanwhile.

## Async and Cancellation Semantics

- Calling `async fn` constructs a cold task. Await/spawn starts it at most once.
- A scope owns every spawned child. No child remains runnable after scope completion.
- Normal scope exit awaits all children. Failure or cancellation requests child cancellation, executes cleanup, and joins children before propagating.
- Cancellation is a control signal checked at `await`, scope operations, and designated standard-library cancellation points; it is not a user-matchable `Result` variant by default.
- Cleanup regions are cancellation-masked long enough to preserve invariants, but blocking indefinitely is a runtime fault.
- Concurrent mutation requires ownership transfer or synchronized library types. `Send` permits ownership transfer; `Sync` permits shared reference access.
- If multiple child tasks fail concurrently, the lexically earliest spawned failing child supplies the primary failure and remaining failures become structured related diagnostics; this makes aggregation deterministic.

## Compile-Time Semantics

- Compile-time evaluation uses the same pure Core IR operations as runtime evaluation, under a capability set excluding IO, unsafe, time, environment, randomness, and concurrency.
- Evaluation is deterministic across hosts for integer, boolean, text, collection, and user-data operations.
- Target-dependent values such as `Int` width are available only through explicit target queries and become part of cache keys.
- Step, recursion, and memory budgets prevent denial of service; budget exhaustion is a diagnostic with the initiating expression span.
- Macro expansion precedes name resolution for introduced syntax but preserves hygiene identities and expansion provenance.

## Unsafe and Foreign Semantics

- Unsafe code may assert pointer validity, layout, initialization, aliasing, or foreign-call contracts that the compiler cannot prove.
- The compiler continues to enforce syntax, types, scope, safe-value ownership, and control-flow cleanup within unsafe blocks.
- Safe callers cannot be required to uphold undocumented invariants. A safe wrapper validates inputs or encodes the invariant in its types.
- Foreign integer sizes, calling convention, struct layout, exception behavior, allocation ownership, thread safety, and nullability are explicit in foreign declarations.
- Undefined behavior is confined to violated unsafe contracts; safe Pudu code must not cause undefined behavior through any input.

## Observable Equivalence

Interpreter and native execution are conformant when, for the same target model and explicit inputs, they produce equal:

- success value or typed failure value;
- stdout/stderr byte sequence and exit status;
- ordered externally visible IO calls in the conformance harness;
- panic diagnostic code and primary source provenance;
- deterministic child-failure selection.

Timing, memory addresses, allocation counts, and thread scheduling are not observable unless surfaced through explicit standard-library APIs.

## Soundness Obligations

The implementation is designed toward these properties:

- **Progress:** A closed, well-typed, ownership-valid expression is a value, can take a step, is waiting at a declared async boundary, or terminates with a declared failure/panic/cancellation—not a stuck invalid operation.
- **Preservation:** If a checked expression takes a step, its type and ownership invariants remain valid under the evolved store.
- **Memory safety:** Safe code has no use-after-move/free, double drop, data race, invalid dereference, or out-of-bounds unchecked access.
- **Failure containment:** Recoverable failures do not escape undeclared and host exceptions do not cross safe public APIs.
- **Backend conformance:** Lowering and C emission preserve Core IR observable semantics.

These obligations require executable property/conformance tests now and mechanized proof only if later risk justifies it; the project must not claim formal proof without one.

## Diagnostic Contract

- Static rejection selects the earliest phase capable of explaining the defect accurately.
- Later phases do not duplicate diagnostics caused solely by an earlier error node.
- Recovery nodes preserve spans and suppress cascades through explicit poison types/symbols.
- Diagnostic codes are grouped: `E0xxx` source/lexing, `E1xxx` parsing, `E2xxx` names, `E3xxx` types, `E4xxx` ownership, `E5xxx` exhaustiveness/effects, `E6xxx` lowering/backend, `E7xxx` runtime/toolchain; warnings use matching `W` groups.

## Semantic Compatibility and History

- Semantic versions use `MAJOR.MINOR.PATCH` independently from compiler binary versions until Pudu 1.0.
- A change to accepted program meaning, evaluation order, type equivalence, ownership validity, failure propagation, layout promise, or concurrency behavior requires an ADR and a semantic version change.
- Breaking semantic changes increment MAJOR before/after 1.0 according to the current compatibility policy; backward-compatible feature additions increment MINOR; clarifications that do not change conforming behavior increment PATCH.
- Every semantic ADR records examples before/after, affected diagnostics, migration, interpreter/native conformance, and review date.
- [[CHANGELOG]] provides the chronological index; this page's `## Revision Ledger` records normative semantic revisions.

## Revision Ledger

- **0.1.0-draft · 2026-08-21:** Established evaluation order, local inference boundary, `Result` propagation, ownership transitions, deterministic cleanup, structured concurrency/cancellation, compile-time capability restrictions, unsafe containment, and conformance obligations. See [[ADR-0001-language-purpose-and-v1-scope]], [[ADR-0002-compiler-pipeline]], and [[ADR-0003-ownership-and-resource-safety]].
- **0.1.0-draft clarification · 2026-08-21:** Closed pre-implementation ambiguities in default-argument evaluation, module-scope initialization, and compiler-controlled structural `Copy`. No implementation compatibility exists yet; these rules are part of the initial draft review. See [[ADR-0003-ownership-and-resource-safety]].
- **0.1.0-draft clarification 2 · 2026-08-21:** Defined move reinitialization, replacement drop timing, constant naming, and normalized synchronous/asynchronous failure signatures before implementation. See [[ADR-0003-ownership-and-resource-safety]].

## Grill Log

- **Q:** Should Pudu claim formal soundness now? **A:** No; state soundness obligations and test them without claiming mechanized proof. _Rationale:_ honest, actionable guarantees are stronger than an unsupported marketing claim. _Rejected:_ calling the design formally safe before proof.
- **Q:** Can native and interpreter behavior differ for convenience? **A:** Only in explicitly non-observable implementation details. _Rationale:_ a semantic oracle is useful only when both execution paths share meaning. _Rejected:_ backend-specific arithmetic or ordering.
- **Q:** Should exceptions be the hidden implementation of `Result`? **A:** No at semantic boundaries; lowering may use control flow internally but must preserve value semantics and cleanup. _Rationale:_ hidden host exceptions weaken failure containment. _Rejected:_ exception-based public semantics.
- **Q:** How should cleanup failure interact with a successful return? **A:** Recoverable close errors require explicit `close`; implicit drop reports best-effort failure diagnostically. _Rationale:_ silently replacing an already computed domain result is unpredictable. _Rejected:_ arbitrary exception replacement; silent discard.
- **Q:** Should cancellation be a normal error variant? **A:** No; keep it a structured control signal unless explicitly converted at a boundary. _Rationale:_ ordinary catch-all failure handling must not accidentally defeat cancellation. _Rejected:_ universal `Cancelled` error union.
- **Q:** Can local inference use caller information? **A:** No. _Rationale:_ caller-dependent APIs undermine modular compilation and tooling. _Rejected:_ global inference for concision.

## Variants

- A future effect row may replace explicit `Result` plumbing only after diagnostics and public signature readability are proven better.
- A formal Coq/Lean model may mechanize the ownership/core fragment after the executable semantics stabilizes.
- A future `throws`-style surface could elaborate to the same failure judgement but is not admitted without an RFC and migration analysis.

## Referenced by

[[architecture/_MOC]] · [[architecture/OVERVIEW]] · [[Engineering Delivery]] · [[Performance Constitution]] · [[grammar/pudu]] · [[Pudu Type]] · [[Ownership]] · [[Core IR]] · [[Semantics]] · [[ADR-0001-language-purpose-and-v1-scope]] · [[ADR-0002-compiler-pipeline]] · [[ADR-0003-ownership-and-resource-safety]] · [[ADR-0005-performance-and-low-level-optimization]] · [[CHANGELOG]] · [[2026-08-21-frontend-foundation]]
