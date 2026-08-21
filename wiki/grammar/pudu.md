---
type: grammar
language: Pudu
version: "0.1 semantics draft"
tags: [grammar]
aliases: [Grammar — Pudu, Pudu Grammar]
---

# Grammar — Pudu

This page is normative for surface syntax. [[architecture/SEMANTICS]] is normative for static and dynamic meaning. Private local proposal material is design input only where distilled into this vault; unresolved private examples do not override semantics and must not be exposed in repository history.

## Source and Lexical Rules

- Source is UTF-8 [[Source Text]]. Invalid UTF-8 is diagnostic `E0001` before lexing.
- Whitespace separates tokens but is otherwise insignificant outside strings.
- `//` starts a line comment. `/* ... */` block comments nest and must terminate.
- Identifiers start with a Unicode letter or `_` and continue with Unicode letters, decimal digits, or `_`; keywords are ASCII lowercase and reserved. Full Unicode XID conformance is deferred until a pinned Unicode-table dependency is admitted.
- Value identifiers may use `snake_case` or `camelCase`; public API formatter preference is `snake_case`. Types, traits, modules, and variants use `PascalCase`. Constant declarations use `UPPER_SNAKE_CASE`.
- Decimal digits may contain `_` only between digits. Integer bases use `0b`, `0o`, or `0x`.
- Strings are UTF-8 text with `\n`, `\r`, `\t`, `\\`, `\"`, `\0`, and `\u{HEX}` escapes. String interpolation is reserved but not admitted in the 0.1 core; an unescaped `{` or `}` produces E0008 rather than silently becoming text. A later semantic slice will admit `{expression}` segments and `{{`/`}}` brace escapes together.
- Character literals contain exactly one Unicode scalar value after escapes.

## Reserved Keywords

`module import export as let var const mut fn async return if else match case for in while loop break continue type enum struct trait impl where await task spawn comptime macro true false null unsafe with scope`

`enum`, `struct`, `task`, and `spawn` are reserved for compatibility even where v1 canonical syntax uses `type` and structured `scope` forms.

## Module and Declaration Grammar

```ebnf
program          = module_decl, import_decl*, top_declaration*, EOF ;
module_decl      = "module", module_path ;
module_path      = upper_ident, (".", upper_ident)* ;
import_decl      = "import", module_path,
                   (("as", upper_ident) | ("{", import_item, (",", import_item)*, "}"))? ;
top_declaration  = "export"?, (const_decl | function_decl | type_decl | trait_decl | impl_decl | macro_decl) ;
const_decl       = "const", constant_ident, (":", type_ref)?, "=", expression ;
local_binding    = ("let" | "var"), lower_ident, (":", type_ref)?, "=", expression
                 | "const", constant_ident, (":", type_ref)?, "=", expression ;
function_decl    = "async"?, "fn", lower_ident, type_params?, "(", params?, ")",
                   ("->", type_ref)?, where_clause?, (block | "=", expression) ;
type_decl        = "type", upper_ident, type_params?, "=", (record_type | sum_type | type_ref) ;
trait_decl       = "trait", upper_ident, type_params?, where_clause?, "{", trait_member*, "}" ;
impl_decl        = "impl", type_params?, type_ref, "for", type_ref, where_clause?, "{", function_decl*, "}" ;
```

Rules:

- A file has exactly one module declaration and no top-level executable statements.
- Module names match the manifest-relative file path.
- Imports are absolute. Wildcard imports are prohibited.
- Declarations are private unless `export`.
- `constant_ident` is an identifier composed of uppercase Unicode letters, decimal digits, and `_`, beginning with an uppercase letter or `_`; at least one uppercase letter is required.
- Module-scope values are `const` only. Runtime `let` and `var` bindings are admitted inside blocks, preventing module-load execution and global mutable state.
- `let` is immutable, `var` is mutable, and `const` is evaluated and stored at compile time.
- Exported functions require explicit parameter and return types; private functions may infer omitted types when inference is unambiguous.
- Default arguments are type-checked in the function declaration's lexical environment. They may reference module constants and earlier parameters, but not caller locals, later parameters, mutable global state, async operations, or unsafe operations. At a call, supplied arguments evaluate first from left to right; omitted defaults then evaluate in parameter order using already bound earlier parameter values. Any declared recoverable failure is part of the call expression's ordinary failure behavior.

## Type Grammar

```ebnf
type_ref         = reference_type | function_type | tuple_type | named_type ;
reference_type   = "&", "mut"?, type_ref ;
function_type    = "async"?, "fn", "(", type_list?, ")", "->", type_ref ;
tuple_type       = "(", type_ref, ",", type_list?, ")" ;
named_type       = module_path_or_type, ("[", type_list, "]")? ;
type_params      = "[", type_param, (",", type_param)*, "]" ;
where_clause     = "where", constraint, (",", constraint)* ;
constraint       = upper_ident, ":", type_ref, ("+", type_ref)* ;
```

- Built-ins: signed/unsigned fixed integers through 128 bits, target-width `Int`/`UInt`, `Float32`, `Float64`, `Bool`, `Char`, `Str`, unit `()`, never `Never`, `BigInt`, and `Decimal`.
- `Float` aliases `Float64`; aliases are transparent and may not create overload distinctions.
- `Option[T]` represents absence. Ordinary types exclude `null`.
- `Array[T, N]` requires non-negative compile-time `N`.
- Generic type arguments use square brackets consistently.
- Generic constraints are nominal trait bounds; v1 has no higher-kinded types, specialization, implicit arguments, or default generic type parameters on functions.
- A synchronous function type `fn(A) -> T` has no recoverable failure unless `T` is explicitly `Result[S, E]`; its normalized semantic signature is success `S`, failure `E`, capability `Sync`. `fn(A) -> T` otherwise normalizes to failure `Never`.
- An asynchronous function type is written `async fn(A) -> T`. Calling it produces `Task[T, Never]`; when its declared return is `Result[S, E]`, calling it produces `Task[S, E]`. This spelling preserves async capability and recoverable failure in first-class function types.

## Data Types and Patterns

```pudu
type User = { id: Int64, name: Str }

type Result[T, E] =
  | Ok(T)
  | Err(E)
```

- Record fields are immutable unless explicitly marked `mut` in the type declaration.
- Sum variants are namespaced by their type; qualification is required when ambiguous.
- Matches are exhaustive for closed types. A guarded arm does not contribute exhaustiveness because its guard may be false.
- Pattern alternatives must bind identical names with identical inferred types.
- `_` ignores a value and never binds.

## Expression Grammar and Precedence

From tightest to loosest: postfix calls/index/member/`?`/`.await`; unary `! - & &mut`; multiplicative `* / % &* *|`; additive `+ - &+ &- +| -|`; range `.. ..=`; comparison `< <= > >=`; equality `== !=`; boolean `&&`; boolean `||`; assignment; control expressions.

- Assignment is a statement-like expression of type `()` and requires a mutable place.
- Function calls evaluate callee then arguments left-to-right.
- Blocks evaluate statements left-to-right and yield the final unterminated expression or `()`.
- `if` and `match` are expressions; all reachable branches must unify.
- `return`, `break`, and `continue` have type `Never` at their valid control boundary.
- A range endpoint is evaluated exactly once.

## Numeric Semantics

- Unsuffixed integer literals are arbitrary precision during inference, then must fit the selected type.
- Fixed-width `+ - *` are checked and produce typed `Overflow` failure in recoverable contexts; compile-time overflow is a diagnostic.
- `&+`, `&-`, and `&*` wrap modulo 2^N. `+|`, `-|`, and `*|` saturate.
- Division by zero produces typed `DivisionByZero`; signed minimum divided by `-1` follows checked overflow rules.
- Integer division truncates toward zero. Remainder has the dividend's sign.
- Floating operations follow IEEE 754; equality follows IEEE semantics. Conversions that may lose range or precision require explicit syntax/library operations.
- No implicit numeric narrowing. Widening is allowed only where exact for every source value.

## Failure Semantics

- `Result[T, E]` is the recoverable failure carrier in v1.
- Postfix `?` is valid only in a function returning compatible `Result`; `Ok(v)?` yields `v`, `Err(e)?` returns `Err(convert(e))` from the current function.
- Panics represent violated internal invariants or explicit `panic`; they are not recoverable domain errors.
- Native/host exceptions are translated at unsafe or standard-library boundaries.
- `null` is permitted only inside `unsafe` foreign-interface expressions and must be converted to `Option` or a validated reference before leaving that boundary.

## Ownership and Resource Semantics

- Values are owned by default. Non-`Copy` assignment and by-value argument passing move.
- `&T` is a shared borrow; `&mut T` is an exclusive borrow.
- Borrows are inferred to the last use within a function and cannot outlive the owner.
- Mutation requires `var`, a mutable record field reached through owned mutable authority, or `&mut`.
- Destruction is deterministic at the end of ownership. Types with resource cleanup implement `Drop`; user code cannot call `drop` twice.
- Unsafe code is lexically explicit and cannot suppress move/borrow accounting for safe values.

## Iteration and Control Flow

- `for pattern in expression` desugars through the `IntoIterator`/`Iterator` traits exactly once.
- Iterator adapters are lazy; terminal collection/consumption drives them.
- `while` reevaluates its condition before each iteration.
- `loop` is potentially divergent and may type as a value when every exit supplies a compatible break value in the later grammar; v1 statement `break` yields `()`.

## Async and Structured Concurrency

- `async fn` returns a lazy `Task[T, E]`; calling it does not execute until awaited or spawned in a scope. A declared `Result[T, E]` return supplies those task channels and is not nested inside the task.
- `.await` is legal only inside `async fn` or an async block and is a cancellation point.
- `async with scope { ... }` creates a structured task scope. Spawned tasks cannot outlive it.
- Leaving a scope normally awaits children; leaving by failure or cancellation cancels children, runs cleanup, then waits for termination.
- Cancellation is distinct from domain `Result` failure and cannot be swallowed accidentally.
- A value crossing into a concurrently executing task must satisfy `Send`; shared cross-task references additionally require `Sync` and cannot outlive the scope.
- Detached tasks are absent from v1. `task` and bare `spawn` remain reserved.

## Traits and Dispatch

- Traits declare behavior contracts without stored state.
- Implementations are coherent: at least the trait or implementing nominal type must be declared in the current module.
- Static dispatch is the default for generic trait bounds. Dynamic dispatch requires an explicit future trait-object form and is not in v1.
- Overlapping implementations and implicit conversions are prohibited.

## Compile-Time and Macro Semantics

- `const` expressions and `comptime fn` execute in a deterministic, resource-limited evaluator with no IO, environment, time, randomness, unsafe, or task operations.
- Compile-time evaluation has configurable step and memory limits; exceeding them is a diagnostic.
- v1 macros are hygienic declarative syntax macros over token trees. They cannot access files, network, environment, compiler internals, or arbitrary host code.
- Expanded tokens retain call-site and definition-site provenance for diagnostics.
- Macros cannot introduce unhygienic bindings without an explicit future escape hatch.

## Unsafe Boundary

- `unsafe { ... }` is the only construct enabling raw pointers, foreign calls marked unsafe, unchecked indexing, or `null`.
- Unsafe does not disable type checking, ownership of safe values, or lexical initialization checks.
- Public safe APIs wrapping unsafe code must state and enforce their invariants; unsafe requirements cannot be hidden in ordinary parameters.

## Copy Eligibility

- `Copy` is a compiler-controlled marker used by ownership checking, not an ordinary trait that user code may implement manually.
- Integer, floating, boolean, character, unit, and shared-reference values are `Copy`. Mutable references, owning pointers/handles, and values with `Drop` are not.
- Tuples, fixed arrays, and declared aggregates are `Copy` exactly when every stored component is `Copy` and the aggregate has no `Drop` implementation or resource identity.
- Generic aggregate copying requires a `Copy` obligation for each type parameter reachable through a copied field. Failure to prove eligibility keeps the value move-only.

## Formatting Constitution

- Official formatting uses two-space indentation, braces on declaration/control lines, trailing commas for multiline lists, and one declaration per logical block.
- Semicolons are not part of canonical syntax; newlines and braces delimit statements.
- Imports sort lexically and group standard-library before project modules.
- Formatter output is idempotent and is the only supported style for committed Pudu code.

## Prohibited Patterns

- No implicit nullability, numeric narrowing, exception leakage, wildcard imports, top-level execution, detached tasks, or ambient global mutation.
- No parser feature whose static and dynamic semantics are unspecified in [[architecture/SEMANTICS]].
- No optimization may alter checked overflow, destruction order, left-to-right evaluation, failure propagation, or cancellation behavior.

## Senior Definition Needed

- Stable syntax for unsafe foreign declarations and C ABI layouts will be finalized before the FFI slice.
- Declarative macro matcher/repetition syntax will be finalized before macro implementation.
- `Decimal` precision/rounding context will be finalized with the numeric standard-library slice.

## Referenced by

[[grammar/_MOC]] · [[Pudu Module]] · [[Pudu Type]] · [[Ownership]] · [[architecture/SEMANTICS]] · [[Standard Library]] · [[FMCF Workflow]] · [[2026-08-21-frontend-foundation]]
