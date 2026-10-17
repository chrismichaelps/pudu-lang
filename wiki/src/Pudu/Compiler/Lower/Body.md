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
  and must be Int, unit, or Never; a Never-only entry uses the unit ABI. A resultless outer block cannot erase an explicit
  Int return. Non-entry functions retain their validated declared result.
- Blocks push a lexical scope, lower statements left to right, lower their
  trailing expression and pop the scope. Locals resolve nearest-first and are
  numbered independently per function. Assignments become CoreAssign and yield
  unit; declarations carry Int, Bool, unit, or Never and reject explicit annotations.
- Return operands must match the declared non-entry result, or Int/unit for
  the entry. The first explicit entry return records its type. Bare returns
  carry no Core operand. The checker already proves return agreement.
- Print's internal Core unit representation is effect-only. An entry's
  recursively print-valued final expression and every explicit print-valued
  return refuse E6001: print's actual Result[(), Str] must never escape as
  unit. This includes nested blocks and conditional branches. Discarded print
  statements and discarded print-valued branches retain their effects.
- Supported values are platform Int, Bool, literal text and display of
  Int/Bool. Print accepts literal text or display; text locals and function
  results remain outside the subset. A discarded text/display expression can
  still lower. Integer syntax must already be ResolvedInteger PlatformSigned;
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
  carry the declared result type. A refused signature does not duplicate its
  diagnostic at each call.
- Printable arguments are literal text or display of Int/Bool; the emitter
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
  proves arity and argument compatibility; validated annotations provide the
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
Unit literals and unit-typed parameters are independent admission boundaries.
