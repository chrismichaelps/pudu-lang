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
- `//` starts a line comment. `/* ... */` block comments nest; an unterminated block comment is retained as trivia and produces `E0003` over the complete consumed comment.
- Identifiers start with a Unicode letter or `_` and continue with Unicode letters, decimal digits, or `_`; keywords are ASCII lowercase and reserved. Full Unicode XID conformance is deferred until a pinned Unicode-table dependency is admitted.
- Value identifiers may use `snake_case` or `camelCase`; public API formatter preference is `snake_case`. Types, traits, modules, and variants use `PascalCase`. Constant declarations use `UPPER_SNAKE_CASE`.
- Numeric-literal digits are ASCII. `_` may occur only between digits. Integer bases use lowercase `0b`, `0o`, or `0x` and require at least one base-valid digit.
- Decimal floats require either `.` followed by a decimal digit or an `e`/`E` exponent. Exponents allow one optional `+`/`-` and require digits. A dot not followed by a digit remains punctuation, so `1..2` is integer, range, integer. Malformed owned numeric candidates are retained as `Invalid` and produce `E0004`.
- Strings are UTF-8 text with `\n`, `\r`, `\t`, `\\`, `\"`, `\0`, and `\u{HEX}` escapes. String interpolation is reserved but not admitted in the 0.1 core; an unescaped `{` or `}` produces E0008 rather than silently becoming text. A later semantic slice will admit `{expression}` segments and `{{`/`}}` brace escapes together. Raw CR/LF is not admitted.
- Character literals contain exactly one Unicode scalar value after escapes and additionally admit `\'`. Raw CR/LF is not admitted.
- Quoted input that reaches EOF or raw CR/LF before its closing delimiter produces E0002 without consuming the line break. Unknown escapes produce E0005. `\u{HEX}` requires one through six ASCII hexadecimal digits and rejects surrogates and values above U+10FFFF with E0006. Closed characters whose decoded payload is not exactly one scalar produce E0007.
- A decoded scalar not owned by trivia, quoted, number, identifier, or symbol scanning is retained as a one-scalar `Invalid` token with E0099; lexing then continues.

## Reserved Keywords

`module import export as let var const mut fn async return if else match case for in while loop break continue type enum struct trait impl where await task spawn comptime macro true false null unsafe with scope`

`enum`, `struct`, `task`, and `spawn` are reserved for compatibility even where v1 canonical syntax uses `type` and structured `scope` forms.

## Module and Declaration Grammar

```ebnf
program          = module_decl, import_decl*, top_declaration*, EOF ;
module_decl      = "module", module_path ;
module_path      = upper_ident, (".", upper_ident)* ;
import_decl      = "import", module_path, import_suffix? ;
import_suffix    = "as", upper_ident
                 | "{", import_item, (",", import_item)*, ","?, "}" ;
import_item      = ident ;
top_declaration  = "export"?, (const_decl | function_decl | type_decl | trait_decl | impl_decl | macro_decl) ;
const_decl       = "const", constant_ident, (":", type_ref)?, "=", expression ;
local_binding    = ("let" | "var"), lower_ident, (":", type_ref)?, "=", expression
                 | "const", constant_ident, (":", type_ref)?, "=", expression ;
block            = "{", statement*, "}" ;
statement        = local_binding | return_stmt | break_stmt | continue_stmt | expression ;
return_stmt      = "return", expression? ;
break_stmt       = "break" ;
continue_stmt    = "continue" ;
function_decl    = "async"?, "fn", lower_ident, type_params?, "(", params?, ")",
                   ("->", type_ref)?, where_clause?, (block | "=", expression) ;
params           = param, (",", param)*, ","? ;
param            = lower_ident, (":", type_ref)?, ("=", expression)? ;
type_decl        = "type", upper_ident, type_params?, "=", (record_type | sum_type | type_ref) ;
record_type      = "{", field_decl, (",", field_decl)*, ","?, "}" ;
field_decl       = "mut"?, lower_ident, ":", type_ref ;
sum_type         = "|"?, variant, ("|", variant)+ ;
variant          = upper_ident, ("(", type_list, ")" | record_type)? ;
trait_decl       = "trait", upper_ident, type_params?, where_clause?, "{", trait_member*, "}" ;
trait_member     = "async"?, "fn", lower_ident, type_params?, "(", params?, ")",
                   ("->", type_ref)?, where_clause?, (block | "=", expression)? ;
impl_decl        = "impl", type_params?, type_ref, "for", type_ref, where_clause?, "{", function_decl*, "}" ;
```

Rules:

- A file has exactly one module declaration and no top-level executable statements.
- Module names match the manifest-relative file path.
- Imports are absolute. Wildcard imports are prohibited.
- Declarations are private unless `export`.
- `constant_ident` is an identifier composed of uppercase Unicode letters, decimal digits, and `_`, beginning with an uppercase letter or `_`; at least one uppercase letter is required.
- `lower_ident` begins with `_` or a Unicode letter that is not uppercase; remaining characters follow the identifier lexical rule. The single `_` spelling is reserved for discard patterns and is not a binding name.
- Module-scope values are `const` only. Runtime `let` and `var` bindings are admitted inside blocks, preventing module-load execution and global mutable state.
- `let` is immutable, `var` is mutable, and `const` is evaluated and stored at compile time.
- A statement ends at a line break unless the expression is explicitly continued. A line break continues the previous statement when the preceding line ends with a binary operator awaiting its right operand, or when the following line begins with `.`, `?`, or `.await`. A line-initial `(` or `[` starts a new statement and never becomes a call or index. Keywords that cannot begin a statement, such as `else`, always continue the construct that requires them.
- A block yields its final unterminated expression statement, or `()` when its last entry is a binding or `return`.
- Exported functions require explicit parameter and return types; private functions may infer omitted types when inference is unambiguous.
- Default arguments are type-checked in the function declaration's lexical environment. They may reference module constants and earlier parameters, but not caller locals, later parameters, mutable global state, async operations, or unsafe operations. At a call, supplied arguments evaluate first from left to right; omitted defaults then evaluate in parameter order using already bound earlier parameter values. Any declared recoverable failure is part of the call expression's ordinary failure behavior.

## Type Grammar

```ebnf
type_ref         = reference_type | function_type | parenthesized_type | named_type ;
reference_type   = "&", "mut"?, type_ref ;
function_type    = "async"?, "fn", "(", type_list?, ")", "->", type_ref ;
parenthesized_type = "(", ")"
                   | "(", type_ref, ")"
                   | "(", type_ref, ",", type_list?, ")" ;
named_type       = module_path_or_type, ("[", type_list, "]")? ;
type_list        = type_ref, (",", type_ref)*, ","? ;
type_params      = "[", type_param, (",", type_param)*, ","?, "]" ;
type_param       = upper_ident, (":", type_ref, ("+", type_ref)*)? ;
where_clause     = "where", constraint, (",", constraint)* ;
constraint       = upper_ident, ":", type_ref, ("+", type_ref)* ;
```

- Built-ins: signed/unsigned fixed integers through 128 bits, target-width `Int`/`UInt`, `Float32`, `Float64`, `Bool`, `Char`, `Str`, unit `()`, never `Never`, `BigInt`, and `Decimal`.
- `Float` aliases `Float64`; aliases are transparent and may not create overload distinctions.
- `Option[T]` represents absence. Ordinary types exclude `null`.
- `Array[T, N]` requires non-negative compile-time `N`.
- Generic type arguments use square brackets consistently.
- `()` is unit, `(T)` groups one type without adding structure, and a comma forms a tuple; type lists admit one trailing comma.
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

```ebnf
pattern          = pattern_alt, ("|", pattern_alt)* ;
pattern_alt      = "_"
                 | lower_ident
                 | literal, ((".." | "..="), literal)?
                 | "(", pattern, (",", pattern)*, ","?, ")"
                 | module_path_or_type, ("(", pattern, (",", pattern)*, ","?, ")")?
                 | module_path_or_type?, "{", field_pattern, (",", field_pattern)*, (",", "..")?, ","?, "}" ;
field_pattern    = lower_ident, (":", pattern)? ;
```

```ebnf
tuple_expr       = "(", expression, ",", (expression, (",", expression)*, ","?)?, ")" ;
array_expr       = "[", (expression, (",", expression)*, ","?)?, "]" ;
record_expr      = module_path_or_type, "{", field_init, (",", field_init)*, ","?, "}" ;
field_init       = lower_ident, (":", expression)? ;
match_expr       = "match", expression, "{", match_arm+, "}" ;
match_arm        = "case", pattern, ("if", expression)?, "=>", (expression | block) ;
while_expr       = "while", expression, block ;
loop_expr        = "loop", block ;
for_expr         = "for", pattern, "in", expression, block ;
```

- An array literal `[a, b, c]` builds an `Array[T]` value. `[]` is the empty array. Arrays are immutable persistent sequences backed by a fingertree: `push`, `insert`, and `remove` return new arrays with structural sharing, so no update copies the entire collection. Built-in methods: `length()`, `get(i)`, `indexOf(x)`, `contains(x)`, `push(x)`, `pop()`, `insert(i, x)`, `remove(i)`, `slice(i, j)`, `reverse()`, `map(f)`, `filter(f)`, `reduce(f, init)`. Indexing an array with `arr[i]` reads the element; out-of-bounds is `E7004`. `for x in arr` iterates elements.
- Record fields are immutable unless explicitly marked `mut` in the type declaration.
- A pattern alternation binds with `|`; a range pattern joins two literals with `..` or `..=`. `_` never binds, a bare lowercase identifier always binds, and an uppercase path is a constructor even with no payload.
- A record pattern may end with `..` to ignore the remaining fields; a field pattern without `:` binds the field to its own name.
- `match` arms are introduced by `case`, may carry an `if` guard, and produce an expression or a block after `=>`. Arms are separated by line breaks like every other construct.
- A record is built by naming its type and its fields: `User{id: 1, name: n}`. A field written without `:` takes the value of the binding with the same name, mirroring the record pattern's shorthand.
- A record construction is not admitted directly in the condition of `if` or `while`, the scrutinee of `match`, or the iterated expression of `for`, because `if READY { ... }` would otherwise be ambiguous with a block. Parenthesize the construction to use one there.
- A parenthesized expression groups; adding a comma makes it a tuple, and `(e,)` is the one-member tuple. This mirrors the type grammar, where `(T)` groups and `(T,)` is a tuple.
- `while`, `loop`, and `for` are expressions of type `()` in v1; their bodies are blocks, and `break`/`continue` are statements valid only inside them.
- Sum variants are namespaced by their type; qualification is required when ambiguous.
- Matches are exhaustive for closed types. A guarded arm does not contribute exhaustiveness because its guard may be false.
- Pattern alternatives must bind identical names with identical inferred types.
- `_` ignores a value and never binds.

## Expression Grammar and Precedence

From tightest to loosest: postfix calls/index/member/`?`/`.await`; unary `! - & &mut ~`; multiplicative `* / % &* *|`; additive `+ - &+ &- +| -|`; shift and bitwise AND `<< >> &`; range and bitwise XOR `.. ..= ^`; comparison `< <= > >=`; equality `== !=`; boolean `&&`; boolean `||` and bitwise OR `|`; assignment; control expressions.

- Assignment is right-associative. Every other admitted binary band is left-associative; semantic typing rejects operator chains whose intermediate result cannot serve as the next operand.
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

[[grammar/_MOC]] · [[Pudu Module]] · [[Pudu Type]] · [[Ownership]] · [[architecture/SEMANTICS]] · [[Standard Library]] · [[FMCF Workflow]] · [[Token]] · [[2026-08-21-frontend-foundation]]
