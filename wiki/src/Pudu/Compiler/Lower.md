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

```haskell
data LowerResult = Lowered !CoreModule | LowerRefused ![Diagnostic]
lowerProgram :: Text -> Module -> LowerResult
```

The entry name (`"main"`) is a parameter, not a constant: the caller owns the
entry-point vocabulary exactly as the evaluator's callers do. The caller hands
in the checked root module (`rootCompileResult >>= compileModule`), never an
errored program.

## Algorithm and invariants

- The root module must exist and compile (the caller refuses errored programs
  first); `main` must be a plain, non-async function with no parameters, no
  type parameters, and a block body. Anything else refuses with the
  declaration's span.
- Only the entry function is lowered. A declaration the entry cannot reach is
  not carried and does not refuse: calls are refused in this milestone, so an
  uncalled function is unreachable and its absence cannot change behaviour. A
  module with no entry function refuses instead, at its first declaration,
  naming the function (or "this declaration") it found there.
- Locals are numbered in declaration order per function; scopes are a stack,
  so inner declarations shadow outer ones exactly as the evaluator's scopes
  do. Assignment resolves to the nearest binding and lowers to `CoreAssign`.
- Blocks lower statements left to right and the trailing expression (if any)
  as the block result. A result of type `Int` is the program result; a
  `Unit`-typed result (print, assignment, `if` without else, `while`) is
  evaluated and discarded; every other result type refuses.
- Expression types are computed while lowering: `Int` and `Bool` for values,
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
- `return` lowers to `CoreReturn` with an `Int` or `Unit` operand; the emitter
  applies the same exit-status clamp as `reportResult`.

## Failures and negative logic

- One refusal per unsupported construct, with the construct's span, built by
  [[Diagnostic Native]]; a program lowers only when nothing refused.
- Refused today, deliberately and explicitly: imports, a module with no entry
  function, parameters, type annotations on bindings, pattern bindings
  (`let`/`let else` with patterns), `break`, `continue`, labeled loops,
  `match`, `try`, `await`, lambdas, ranges, tuples, arrays, sets, records,
  member/index access, method calls, module-qualified names, borrows (`&`,
  `*`), bitwise operators, wrapping/saturating operators, non-platform integer
  kinds, floats, decimals, chars, `Text`-typed locals, and every statement or
  expression form not listed above.
- No silent reinterpretation: an unsupported construct is never approximated,
  evaluated at compile time, or deferred to runtime.

## Dependencies and consumers

Requires [[Compiler Program]] (`ProgramResult`, root module), [[Frontend
Syntax]] trees, [[Integer Literal]] kinds, [[Source]] spans, [[Core IR]]
module, and [[Diagnostic Native]] for refusals. Consumed by the `pudu build
--native` path in [[Pudu CLI]]. It may import frontend and semantic modules —
that is its job — and no backend module imports it.

## Grill Log

- **Q:** Why refuse `Text` locals but allow string literals? **A:** Printing a
  literal needs no runtime string representation, while a `Text`-typed local
  would force allocation, ownership, and comparison semantics into the first
  milestone. The refusal keeps the promise honest: what runs natively is what
  the interpreter runs. _Rejected:_ a partial string runtime.
- **Q:** Why lower `while` from expression position rather than statement
  position? **A:** In the tree `while` is an expression node used as a
  statement; the evaluator admits it only there and gives it `Unit`. Lowering
  reads it the same way so a `while` used for its value refuses instead of
  inventing one. _Rejected:_ value-typed loops.
- **Q:** Why one refusal per construct instead of aggregating by category?
  **A:** The reader fixes what is named; a diagnostic per span is what the
  rest of the compiler already promises, and the span is the only part of the
  refusal a reader can act on. _Rejected:_ a summary-only refusal.
- **Q:** Why parameterise the entry name? **A:** The evaluator's entry name is
  a caller decision (`evaluateProgramEntryFolded` takes it); hard-coding
  `"main"` here would create a second source of truth for it. _Rejected:_
  a private entry constant.

## Referenced by

[[src/Pudu/Compiler/_MOC]] · [[src/Pudu/_MOC]] · [[Core IR]] · [[Pudu Core]] ·
[[Backend Emit]] · [[Diagnostic Native]] · [[Backend]]
