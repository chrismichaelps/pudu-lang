---
type: module
path: "@root/src/Pudu/Compiler/Lower.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, compiler]
aliases: [Compiler Lower, Native Lowering]
---

# Compiler Lower

## Purpose and interface

Lower the checked root module of a compiled program into [[Core IR]], or
refuse — never guess. This is the one gate between the full language and the
native subset: everything the emitter can represent is lowered exactly, and
everything else becomes a typed `E6001` refusal carrying the construct's own
span, so the reader learns what the native backend does not support and where.
The module is the driver: it finds the entry, decides which functions are
reachable, validates their signatures, and settles the result;
[[Compiler Lower Body]] owns block, statement, expression and call lowering;
[[Compiler Lower Control]] owns loop targets, transfers and Never joins;
[[Compiler Lower State]] owns shared state and [[Compiler Lower Signature]]
owns callable signature admission.

```haskell
data LowerResult = Lowered !CoreModule | LowerRefused ![Diagnostic]
lowerProgram :: Text -> Maybe LowerTypes -> Module -> LowerResult
```

The entry name (`"main"`) is a parameter, not a constant: the caller owns the
entry-point vocabulary exactly as the evaluator's callers do. The caller hands
in the checked root module and LowerTypes constructed from the same successful
CompileResult, never an errored program. Missing facts refuse at the module span.

## Algorithm and invariants

- The root module must exist and compile (the caller refuses errored programs
  first); the entry must be a plain, non-async function with no parameters, no
  type parameters, and a block body. The entry keeps milestone 1's rule: its
  declared return annotation is not consulted, its result type comes from the
  body or its explicit returns, and that result must be `Int`, `()`, or Never. A Never-only entry uses the unit C ABI.
- Only functions *reachable from the entry* are validated, lowered, and
  carried. The table of top-level functions is built in declaration order; the
  worklist starts at the entry, and every call discovered while lowering a
  reachable body enqueues its callee. An uncalled declaration — even one whose
  body or signature the backend could not carry — is never visited, never
  refuses, and never appears in the core module, because the interpreter never
  runs it either. A module with no entry function refuses at its first
  declaration, naming the function (or "this declaration") it found there.
- Non-entry functions are synchronous and block bodied, with no type
  parameters, constraints, `unsafe`/`comptime` modifiers or default parameter
  values. Final monomorphic schemes carry `Int`, `Bool` or unit parameters and
  `Int`, `Bool` or `()` results, including inferred and aliased types. Export visibility adds
  no native restriction. See [[Compiler Lower Signature]] for refusal spans. The signature is validated once per function and memoized, so
  a function reached through several calls refuses exactly once.
- Carried functions are ordered by declaration, not by discovery, so the core
  module — and every artifact derived from it — is a function of the program
  alone.
- Calls lower left to right, matching the evaluator's argument evaluation
  order; the call's type is the callee's settled result type; recursion and
  mutual recursion terminate the worklist through the visited set.
- Locals are numbered per function; scopes are a stack, so inner declarations
  shadow outer ones exactly as the evaluator's scopes do. Assignment resolves
  to the nearest binding and lowers to `CoreAssign`.
- Blocks lower statements left to right and the trailing expression (if any)
  as the block result. Locals may carry unit; its initializer and assignments preserve effects. Assignment yields unit. Resultless blocks and calls
  returning `()` carry unit; statement `if`/`while` discard their body values.
  A print's internal unit representation is effect-only: an entry's trailing
  print result or an explicit print-valued return refuses because the actual
  result is `Result[(), Str]`. Nested blocks and conditionals are inspected
  recursively. A trailing `if` without else discards any supported taken value and yields unit, or Never if its condition transfers. While yields unit unless its condition transfers.
  Text locals and function results are outside the subset; standalone literal
  text or `display` in discarded statement position can still be lowered.
- Structural Core expression types are computed while lowering; annotated locals and signatures consume settled checker facts: `Int` and `Bool` for values,
  `Text` only for string literals and `display(...)` under `print(...)`.
  Integer literals must be `ResolvedInteger PlatformSigned`; suffixed widths
  and other kinds refuse with the kind's name.
- Assignment is recognised in the tree as `BinaryExpression (NameExpression
  name) "=" right`, matching the evaluator's own statement reading; `print`
  and `display` are unqualified single-name calls, matching the evaluator's
  builtin dispatch.
- `if` without else is a statement (`CoreIf ... Nothing`); `if` with else in
  statement position discards its value; in value position it lowers to
  `CoreIfValue`, where the else branch is a block or a chained `if`.
  An admitted value-position if without else uses a unit-valued Core block around CoreIf.
  Never branches join the inhabited branch type. Never operands remain Never
  through eager scalar operations, while short-circuit right operands stay guarded.
  Never assignments, initializers and conditions preserve their transfer. While expressions yield unit;
  loops yield their scalar/unit break type, or Never without a local break.
- `return` lowers to `CoreReturn` with an operand matching the function's
  result type. The entry records the first explicit Int/unit return so a
  resultless outer block cannot turn `return 1` into a void function. The
  generated C main applies `reportResult`'s exit-status clamp to the entry's
  Int result; individual Pudu functions emit ordinary C returns.

## Failures and negative logic

- One refusal per unsupported construct, with the construct's span, built by
  [[Diagnostic Native]]; a program lowers only when nothing refused.
- Refused today, deliberately and explicitly: imports, a module with no entry
  function, parameters on the entry function, calls through local values,
  calls to the entry function, parameter types outside `Int`/`Bool`/unit, default
  parameter values, unresolved or polymorphic signatures, result types outside
  `Int`/`Bool`/`()`, expression bodies on non-entry functions, pattern
  bindings (`let`/`let else` with patterns),  `match`, `try`, `await`, lambdas, ranges, tuples, arrays, sets,
  records, member/index access, method calls, module-qualified names, borrows
  (`&`, `*`), bitwise operators, wrapping/saturating operators, non-platform
  integer kinds, floats, decimals, chars, `Text`-typed locals, and every
  statement or expression form not listed above.
- No silent reinterpretation: an unsupported construct is never approximated,
  evaluated at compile time, or deferred to runtime.

## Dependencies and consumers

Requires [[Compiler Lower Types]], [[Compiler Lower Body]], [[Compiler Lower State]],
[[Compiler Lower Signature]], [[Frontend Syntax]] trees, [[Source]] spans, [[Pudu Core]], and [[Diagnostic Native]].
Consumed by the `pudu build --native` path in [[Pudu CLI]]. It may import
frontend and semantic modules — that is its job — and no backend module
imports it.

## Grill Log

- **Q:** How does lowering cross modules? **A:** It takes every module of the compiled program with its own checked facts (`programNativeModules`), keys every function by its canonical name (`Module.function`), and lowers on demand from the root's entry, entering each function's module first. Records and sums come from each module's own declarations and are named by canonical identity, so two modules' `Point`s never meet (#539).

- **Q:** Where do sum shapes come from? **A:** `declaredSums` and `declaredRecords` from the checked module become the lowering's shapes, and `moduleLayouts` closes every layout the lowered functions mention (#525).

- **Q:** Why refuse `Text` locals but allow string literals? **A:** Printing a
  literal needs no runtime string representation, while a `Text`-typed local
  would force allocation, ownership, and comparison semantics into the first
  milestone. The refusal keeps the promise honest: what runs natively is what
  the interpreter runs. _Rejected:_ a partial string runtime.
- **Q:** Why lower `while` from expression position rather than statement
  position? **A:** In the tree `while` is an expression node used as a
  statement; the evaluator admits it only there and gives it `Unit`. Lowering
  reads it the same way so a `while` yields unit as specified; numeric targets preserve loop control. _Rejected:_ fabricated scalar while results.
- **Q:** Why one refusal per construct instead of aggregating by category?
  **A:** The reader fixes what is named; a diagnostic per span is what the
  rest of the compiler already promises, and the span is the only part of the
  refusal a reader can act on. _Rejected:_ a summary-only refusal.
- **Q:** Why parameterise the entry name? **A:** The evaluator's entry name is
  a caller decision (`evaluateProgramEntryFolded` takes it); hard-coding
  `"main"` here would create a second source of truth for it. _Rejected:_
  a private entry constant.
- **Q:** Why keep the entry's milestone 1 rule instead of requiring an
  annotation like every other function? **A:** It is the shipped, tested
  behavior for `main` — a body-derived `Int` or `()` — and tightening it would
  break programs milestone 1 accepted for no semantic gain. The asymmetry is
  documented, not accidental. _Rejected:_ a uniform annotation requirement
  across the milestone boundary.
- **Q:** Why is reachability a worklist rather than a fixpoint over all
  declarations? **A:** A declaration the entry cannot reach is never executed,
  so validating it would refuse programs the interpreter runs — the one
  outcome the gate must never produce. The worklist mirrors the evaluator's
  own reachability: start at the entry, follow calls. _Rejected:_
  validating every declaration up front.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[src/Pudu/_MOC]] · [[Core IR]] · [[Pudu Core]] ·
[[Compiler Lower Body]] · [[Compiler Lower State]] · [[Compiler Lower Signature]] ·
[[Backend Emit]] · [[Diagnostic Native]] · [[Backend]]

Loop-control extension: [[Compiler Lower Control]] owns scalar/unit loop results,
labelled transfers and Never joins under [[Native Emission Coverage]].

## If-without-else unit conformance (#490)

[[ADR-0025-if-without-else-unit-results]] repairs normal unit production across
the interpreter oracle. Value-position lowering then admits any supported then
block and discards its result inside a resultless CoreIf wrapper. Effects,
failures and transfers remain intact; a divergent condition remains Never.
Resolved Grill Log: no native-specific coercion, payload leakage or temporary
scalar refusal after evaluator agreement. Unsupported branch constructs retain
their own representation refusals.


## Solved native type inputs (#491)

Require optional LowerTypes from the same checked module: lowerProgram :: Text -> Maybe LowerTypes -> Module -> LowerResult. Missing facts refuse E6001 at moduleSpan. Pass facts through context. Non-entry Int/Bool signatures and Int/Bool/unit results consume final monomorphic synchronous schemes, including inference and aliases; annotation spelling no longer selects ABI. Represented annotated locals are admitted using exact initializer facts. Previous annotation-only restrictions are superseded by this contract.

Resolved Grill Log: consume canonical settled checker facts; preserve structural Never, print carrier refusals and existing runtime representations. Rejected: re-inference, display-name ABI selection, offset-only identity or silent fallback.

## Unit scalar admission (#492)

Unit literals lower as empty Core blocks and settled unit parameters retain the existing scalar sentinel slot. Argument emission executes effects before binding zero; no Result carrier is erased. General tuples remain pending; unit display/equality are implemented by #493. Resolved Grill Log: empty tuple syntax is the single unit inhabitant, not an owned aggregate.

## Record layouts (#521)

`lowerProgram` adds the root module's own records from `declaredRecords` to
the facts before lowering.
