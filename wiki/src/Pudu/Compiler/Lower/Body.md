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
  and must be Int or unit. A resultless outer block cannot erase an explicit
  Int return. Non-entry functions retain their validated declared result.
- Blocks push a lexical scope, lower statements left to right, lower their
  trailing expression and pop the scope. Locals resolve nearest-first and are
  numbered independently per function. Assignments become CoreAssign and yield
  unit; declarations carry only Int or Bool and reject explicit annotations.
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
- Statement if and while lower with explicit blocks; value if requires both
  branches and equal supported types. Assignment-as-value, value while,
  labels, break and continue remain explicit refusals.
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

Requires [[Compiler Lower State]], [[Compiler Lower Signature]], [[Frontend Syntax]],
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
