---
type: module
path: "@root/src/Pudu/Compiler/Lower/Body.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, compiler]
aliases: [Compiler Lower Body, Native Body Lowering]
---

# Compiler Lower Body

## Fixed signed admission (#497)

Use canonical admission predicates for literals, locals and display. A literal
or its negation must fit its admitted kind; retain its exact Integer payload.
Entries and explicit entry returns admit any supported integer kind, preserving
the existing IntValue status policy. Bool entry reporting remains pending.
Resolved Grill Log: preserve annotation fact checks, print Result guards, Never
and scopes; no narrowing at transfers, calls or stored values.

## Purpose and interface

Lower the reachable function bodies selected by [[Compiler Lower]]. Exports
`lowerEntryBody` and `lowerFunctionBody`, both returning accumulated state and
an optional Core function. [[Compiler Lower State]] owns scopes, local numbering
and program context; [[Compiler Lower Signature]] owns signature validation.

```haskell
lowerEntryBody :: Located Function -> LowerState -> (LowerState, Maybe CoreFunction)
lowerFunctionBody :: Located Function -> CoreSignature -> LowerState -> (LowerState, Maybe CoreFunction)
```

## Algorithm and invariants

- Entry functions have no parameters and obey shared function admission. Their
  result comes from the trailing body expression or observed explicit returns,
  and must be an admitted integer, unit, or Never; a Never-only entry uses the unit ABI. A resultless outer block cannot erase an explicit
  integer return. Non-entry functions retain their settled validated signature result.
- Blocks push a lexical scope, lower statements left to right, lower their
  trailing expression and pop the scope. Locals resolve nearest-first and are
  numbered independently per function. Assignments become CoreAssign and yield
  unit; declarations carry admitted integers, Bool, unit, or Never. An explicit annotation
  requires an exact initializer fact matching the structural Core type, with
  represented facts preserving structural Never.
- Return operands must match the declared non-entry result, or Int/unit for
  the entry (including fixed signed integers). The first explicit entry return records its type. Bare returns
  carry no Core operand. The checker already proves return agreement.
- Print's internal Core unit representation is effect-only. An entry's
  recursively print-valued final expression and every explicit print-valued
  return refuse E6001: print's actual Result[(), Str] must never escape as
  unit. This includes nested blocks and conditional branches. Discarded print
  statements and discarded print-valued branches retain their effects.
- Supported values are platform/fixed signed integers, Bool, literal text and display of
  admitted integers/Bool/unit. Print accepts literal text or display; text locals and function
  results remain outside the subset. A discarded text/display expression can
  still lower. Integer syntax must already carry a supported ResolvedInteger kind;
  unresolved integers and other numeric kinds refuse. Arithmetic, comparisons,
  equality and short-circuit booleans retain source spans.
- Statement if lowers with explicit blocks; an if without else in value position
  discards the taken branch result and carries unit, or Never when its condition transfers. Value if with else joins
  supported branch types, joining Never with the reachable branch type. While
  yields unit and loops carry their scalar/unit break type, or Never without
  a local break. Labels, break and continue resolve through Control.
  Assignment-as-value remains an explicit refusal.
- Calls resolve print/display first, then refuse local callable values and
  calls to the entry, then consult the top-level function table. Signatures
  are memoized. Arguments lower left to right; calls enqueue their callee and
  carry the settled result type. A refused signature does not duplicate its
  diagnostic at each call.
- Printable arguments are literal text or display of Int/Bool/unit; the emitter
  can fuse these without introducing text allocation or ownership semantics.

## Negative logic

Unsupported expressions and statements refuse at their own span, never execute
at compile time, approximate an operation, or defer representation failure to
the C compiler. Imports and reachability are driver concerns. Signature
inference, semantic rechecking and C emission are outside this module.

## Dependencies and consumers

Requires [[Compiler Lower Control]], [[Compiler Lower State]], [[Compiler Lower Signature]], [[Frontend Syntax]],
[[Pudu Core]], and [[Integer Literal]]. Consumed by [[Compiler Lower]].

## Grill Log

- **Q:** Why keep blocks and expressions together? **A:** Their mutual recursion
  is one traversal responsibility; state and signature admission are independent
  seams. All three implementation modules remain below 500 lines. _Rejected:_
  circular expression modules or one oversized body module.
- **Q:** Why refuse a trailing print or an explicit return of print? **A:**
  Print produces Result[(), Str] and the interpreter observes that carrier.
  CorePrint's unit is valid only when the result is discarded. _Rejected:_
  silently erasing Result or baking an Ok string into emitted code.
- **Q:** Can an empty outer result turn `return 1` into a void function? **A:**
  No; the observed explicit entry return type determines the Core function
  result. _Rejected:_ deriving unit from the absence of a trailing expression.
- **Q:** Why are argument types not inferred here? **A:** The checker already
  proves arity and argument compatibility; settled schemes provide the
  representation. _Rejected:_ backend inference duplicating the checker.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[src/Pudu/_MOC]] · [[Compiler Lower]] ·
[[Compiler Lower State]] · [[Compiler Lower Signature]] · [[Core IR]] · [[Backend]]

## Scalar loop-control extension (#489)

[[Compiler Lower Control]] owns nearest labelled target resolution, break-type joins,
while/loop values and direct terminal Never detection. State resets loop numbering
and frames per function. Body delegates through traversal callbacks; if branches
join Never with reachable types. Print-valued break operands refuse Result erasure.

Resolved Grill Log: while conditions lower before their frame; operands lower
before break observation; labels become numeric identities; only scalar/unit
results are admitted. Rejected silent Result erasure and source-label C names.

## Never operand admission (#489)

Resolved Grill Log: Never operands are admitted in scalar expected contexts
without retagging their Core type or inventing an inhabited value. Eager unary,
binary and call expressions remain Never when an operand cannot return; logical
right operands remain guarded and therefore do not make the whole expression
Never. A Never condition makes its conditional Never. Never initializers bind
a Never local, and Never assignments and return operands retain their transfer.
Result-valued print expressions remain effect-only: bindings, call arguments,
explicit returns, break operands and function results cannot erase their carrier.
A divergent block's unreachable trailing print does not produce a value.

Resolved Grill Log: an admitted if without else has unit value and can be represented by
a Core block containing its conditional statement; no new literal or runtime
representation is needed. A Never condition preserves divergence.

## If-without-else unit boundary (#490)

Resolved Grill Log: [[ADR-0025-if-without-else-unit-results]] repairs the evaluator
oracle to return unit after normal completion. Value lowering wraps the existing
CoreIf statement in a resultless Core block, regardless of the discarded branch
value. Condition evaluation and branch effects run exactly once; transfers and
runtime failures remain intact. A Never condition remains Never. Print's Result
is discarded within this boundary and cannot escape through it. With-else
branches retain their value and print-result admission rules. Rejected: native-only
coercion or retaining the temporary #489 refusal after oracle agreement.

## Unit local admission (#489)

Resolved Grill Log: unit-valued initializers may bind a unit local; the emitter
runs their effects before producing its unit sentinel. Unit assignments retain
their right operand's effects. Reads retain unit type. Print-valued initializers
and assignment operands still refuse because Result[(), Str] cannot become unit.
Unit literals and unit-typed parameters are admitted by #492 through empty Core blocks and settled unit signatures.


## Solved native type inputs (#491)

Admit explicit local annotations only when the initializer exact complete Span has a represented solved type compatible with structural Core type. Structural Never still propagates without retagging. Print Result escape guards remain first; missing facts refuse E6001, with no offset lookup, annotation-name expansion or second unifier. Non-entry results use the settled signature, not declared spelling.

Resolved Grill Log: consume canonical settled checker facts; preserve structural Never, print carrier refusals and existing runtime representations. Rejected: re-inference, display-name ABI selection, offset-only identity or silent fallback.


## Unit literals and parameters (#492)

Lower TupleExpression [] to CoreBlockValue (CoreBlock [] Nothing) with CoreUnitType. Keep nonempty tuples refused. Unit literals then work in locals, returns, branches and break operands through existing scalar/unit paths. Print Result guards remain unchanged.

Resolved Grill Log: preserve the single unit inhabitant and every effect without allocating a new representation. Reject void-valued C initializers, Result erasure and omitted argument evaluation. Nonempty tuples remain pending; #493 implements unit display/equality.


## Unit display and equality (#493)

Admit display of unit alongside Int/Bool in the existing inline printer path. Admit matching unit equality/inequality and Never joins. Preserve all effect-only Result guards and continue refusing unit arithmetic/ordered comparisons rather than inventing integer semantics.

Resolved Grill Log: unit has one value but its operands still execute. Reject skipped/repeated effects, void C initializers, wrong runtime printer selection and accidental ordered/arithmetic unit admission. Owned text representation and E7001 invalid-operation lowering remain separate obligations.

#493 carrier audit: explicit display and equality guards reject Core print carriers, including nested blocks/conditional values, before unit admission. Refusal regressions use checked Result-valued source, so print is never silently formatted or compared as unit. Genuine no-else unit boundaries remain admitted.


## Explicit scalar runtime refusals (#494)

Delegate unary/binary operations to Compiler Lower Scalar, importing eagerType for call propagation. Keep scopes, calls, unit/display carrier guards and syntax dispatch here. Extraction prevents the body from exceeding 500 lines.

Resolved Grill Log: reproduce actual interpreter dispatch, canonical settled kinds, operand order and diagnostic spans; never classify print Result as unit or implement invalid operations as integer arithmetic. No syntax/inference change.

## Deferred Int literal carrier admission (#498, hardening partition)

The initial no-loss guard refused deferred positive-boundary literals. The
exact-carrier integration below supersedes that temporary boundary: magnitudes
through 2^63 are represented directly, including accepted block/local paths.
Larger unrepresented magnitudes still refuse at the literal's complete span.
The checker and interpreter remain unchanged.

### Failed-block diagnostic containment

foldStatements returns a stopped flag and ends that block after the first
statement whose lowering produces Nothing. lowerBlock skips its trailing
expression after that failure and always pops the scope. When a block is used
as an expression, compare refusal counts across lowerBlock; if new refusals
were added, propagate Nothing instead of presenting the recovery block as a
real unit value to unary/binary consumers. This prevents a refused literal from
causing a fabricated unit-operator or unknown-local refusal. Other functions
and independent admitted blocks retain ordinary worklist validation.

Resolved Grill Log: recovery IR is never a successful value. Stop within the
failed lexical scope, preserve the original located refusal, and test block
and local cases independently rather than weakening the exact-one diagnostic
assertion. This changes native diagnostic recovery only, not Pudu execution.

## Exact integer carrier integration (#498)

Admit canonical platform Int literal magnitudes through 2^63 in the exact
carrier; keep a located refusal outside that representable domain. The accepted
deferred positive boundary must now lower through blocks/locals without the
interim E6001 guard. Failed-block containment stays unchanged. No checker or
interpreter changes, new primitive kinds or ownership-bearing values.

Resolved Grill Log: implement [[Exact Native Integer Carriers]] without changing the oracle. Preserve positive boundary values, exact diagnostic provenance, Never transfers, and warning-free helper selection. The internal carrier is not a public type-layout promise; full native coverage remains open.

When any call argument is structurally Never, lower the eager argument sequence
to a Never Core block and do not record/emit the call. The arguments retain
source order; no call-depth check or callee body executes after an argument
transfers. This avoids passing an unreachable scalar dummy to a struct integer
parameter and keeps a callee used only by that impossible call out of emission.
The ordinary signature checks before arguments remain unchanged.
Resolved Grill Log: Never carries no C argument value. Sequence its effects,
then preserve the transfer; do not invent a numeric payload or unused wrapper.
