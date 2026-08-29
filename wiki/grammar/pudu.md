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
- `///` starts a documentation comment and `/** ... */` is its block form. A run of them immediately above a declaration, with nothing but whitespace between, is that declaration's documentation; it is preserved as trivia like any other comment and is never syntax. `////` is an ordinary line comment, not documentation, so a row of slashes stays a visual separator.
- Identifiers start with a Unicode letter or `_` and continue with Unicode letters, decimal digits, or `_`; keywords are ASCII lowercase and reserved. Full Unicode XID conformance is deferred until a pinned Unicode-table dependency is admitted.
- Value identifiers may use `snake_case` or `camelCase`; public API formatter preference is `snake_case`. Types, traits, modules, and variants use `PascalCase`. Constant declarations use `UPPER_SNAKE_CASE`.
- Numeric-literal digits are ASCII. `_` may occur only between digits. Integer bases use lowercase `0b`, `0o`, or `0x` and require at least one base-valid digit. An integer may end in one closed lowercase width suffix: `i8`, `i16`, `i32`, `i64`, `i128`, `u8`, `u16`, `u32`, `u64`, or `u128`; the suffix is part of the literal token, including after a base-prefixed body.
- Decimal floats require either `.` followed by a decimal digit or an `e`/`E` exponent. Exponents allow one optional `+`/`-` and require digits. A float may end in the closed lowercase suffix `f32` or `f64`; the suffix is part of the literal token. The closed lowercase suffix `d` selects `Decimal` and is admitted after either shape, so `1d` and `1.5d` are both decimal literals while `1f32` and `1.5u8` stay malformed. A dot not followed by a digit remains punctuation, so `1..2` is integer, range, integer. Malformed owned numeric candidates are retained as `Invalid` and produce `E0004`.
- Input that ends before a construct is closed reports `E1000` rather than `E1001`: a file that ran out is a different mistake from a wrong token, and naming the end of input says the construct was never closed at all.
- Strings are UTF-8 text with `\n`, `\r`, `\t`, `\\`, `\"`, `\0`, and `\u{HEX}` escapes. A `{ expression }` segment interpolates, and `\{` and `\}` write a literal brace; the rules are stated with the semantics below. A `}` with no interpolation to close is `E0008` rather than silently becoming text. Raw CR/LF is not admitted.
- Character literals contain exactly one Unicode scalar value after escapes and additionally admit `\'`. Raw CR/LF is not admitted.
- Quoted input that reaches EOF or raw CR/LF before its closing delimiter produces E0002 without consuming the line break. Unknown escapes produce E0005. `\u{HEX}` requires one through six ASCII hexadecimal digits and rejects surrogates and values above U+10FFFF with E0006. Closed characters whose decoded payload is not exactly one scalar produce E0007.
- A decoded scalar not owned by trivia, quoted, number, identifier, or symbol scanning is retained as a one-scalar `Invalid` token with E0099; lexing then continues.

## Reserved Keywords

`module import export as let var const mut fn async return if else match case for in while loop break continue type enum struct trait impl where await task spawn comptime macro true false null unsafe with scope dynamic`

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
macro_decl       = "macro", lower_ident, "(", macro_params?, ")", ("=", expression | block) ;
macro_params     = macro_param, (",", macro_param)*, ","? ;
macro_param      = lower_ident, ":", macro_kind ;
macro_kind       = "expr" | "ident" | "block" ;
macro_call       = lower_ident, "!", "(", (expression, (",", expression)*, ","?)?, ")" ;
const_decl       = "const", constant_ident, (":", type_ref)?, "=", expression ;
local_binding    = ("let" | "var"), lower_ident, (":", type_ref)?, "=", expression
                 | "const", constant_ident, (":", type_ref)?, "=", expression ;
block            = "{", statement*, "}" ;
statement        = local_binding | return_stmt | break_stmt | continue_stmt | expression ;
return_stmt      = "return", expression? ;
break_stmt       = "break", loop_label?, expression? ;
continue_stmt    = "continue", loop_label? ;
loop_label       = "@", lower_ident ;
dynamic_type     = "dynamic", upper_path ;
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
(* impl[T] Holds[T] for Boxed[T] — the parameters bind across the trait and the target *)
```

Rules:

- A file has exactly one module declaration and no top-level executable statements.
- Module names match the manifest-relative file path.
- Imports are absolute. Wildcard imports are prohibited: a reader must be able to answer "where did this name come from" from the import list alone.
- `Core.*` is the language's own namespace and holds the implicit prelude. `Std.*` is the standard library shipped with the compiler; see [[architecture/STDLIB]] for the modules and their guarantees. Neither is implicitly imported except `Core.Prelude`.
- A `Std.*` module resolves from the program's source root first and the compiler's library root second, so a program may shadow a standard module deliberately and visibly. There is no network step, no cache, and no version resolution.
- `import M` binds the module qualified, `import M as N` binds it under `N`, and `import M {a, b}` binds the named items unqualified. The three forms are the whole import vocabulary.
- Declarations are private unless `export`.
- `constant_ident` is an identifier composed of uppercase Unicode letters, decimal digits, and `_`, beginning with an uppercase letter or `_`; at least one uppercase letter is required.
- `lower_ident` begins with `_` or a Unicode letter that is not uppercase; remaining characters follow the identifier lexical rule. The single `_` spelling is reserved for discard patterns and is not a binding name.
- Module-scope values are `const` only. Runtime `let` and `var` bindings are admitted inside blocks, preventing module-load execution and global mutable state.
- `let` is immutable, `var` is mutable, and `const` is evaluated and stored at compile time.
- A statement ends at a line break unless the expression is explicitly continued. Two statements written on one line are not separated — the language has no statement terminator — and the second is rejected with `E1049`, reported once per block and never where recovery has already reported something else. A line break continues the previous statement when the preceding line ends with a binary operator awaiting its right operand, when the following line begins with `.`, `?`, or `.await`, or when the following line begins with a binary operator that has no prefix form. That last case is decided by the operator alone and never by indentation: an operator with no prefix form cannot begin anything, so a line starting with one had no reading but a parse error, and continuing it cannot change a program that already had a meaning. `-`, `&` and `*` do have a prefix form, so a line beginning with one ordinarily starts a statement — `total` then `-1` is a negation on its own line, not a subtraction — and the joined reading is written by ending the line above with the operator instead. There is one refused mixed shape: after an expression has already continued through a line-leading binary operator, a following line-leading `-`, `&`, or `*` is `E1055`, because the page has established a leading-operator chain and silently ending it at the first prefix-capable spelling changes arithmetic or dereference meaning. The diagnostic asks the writer to put it at the end of the preceding line when continuation was intended, or parenthesize the prefix expression when a new statement was intended. At statement scope the operator remains available to ordinary recovery; inside a delimited expression, where it cannot be a sibling statement, recovery advances to the enclosing separator or closer so that one ambiguity does not fabricate a missing-delimiter error. A line-initial `(` or `[` starts a new statement and never becomes a call or index. Keywords that cannot begin a statement, such as `else`, always continue the construct that requires them.
- A block yields its final unterminated expression statement, or `()` when its last entry is a binding or `return`.
- **A value has methods from exactly two places**: the closed sets the compiler wires into `Array`, `Str`, `Map`, `Set`, and `Char`, and the `impl` blocks a program writes. Everything else is a module function called on the value as an argument — `Option.unwrapOr(value, fallback)`, not `value.unwrapOr(fallback)` — because `Option` is an ordinary sum type and nothing has implemented anything for it. A program that wants method syntax for its own type writes an `impl`, which is the same mechanism the standard library would use.
- `Array` and `Str` carry closed sets of built-in methods. Every one answers with a new value rather than changing its receiver, so writing one as a statement does nothing and is reported as `W3002`. Text indices count Unicode scalars, and an index outside the text is `E7004`.
- **`charAt` and `slice` cost what they skip; `drop` and `take` cost what they move.** Text is stored so that reaching the *n*th character walks past the first *n*, which makes an index into a long text expensive and a scan that carries an index quadratic. `drop` and `take` pay only for the characters they move over, so a reader that carries the text it has not consumed yet advances in constant time and scans a whole input in linear time. That is the difference between a parser that handles a line and one that handles a file.
- **A running program loops for as long as its work takes.** A `const` initialiser is folded while the compiler runs, so a loop that never ends there is a build that never ends, and it is stopped with `E7002`. A program the reader asked to run is bounded by the machine, exactly as in any other language: an input of any size needs more steps than a fixed count allows, so a bound there is not a safety property but a language that cannot read a file.
- A function literal is written `fn(params) => expression` or `fn(params) -> Type { block }`, reusing the same `fn` the function type uses. It captures the bindings in scope where it is written, takes no default arguments, and is not generalized: its type is fixed at the point it appears.
- A tuple is indexed by a literal position. Its members have different types, so a computed index has no single type and is reported as `E3027`.
- `Map[K, V]` and `Set[T]` are wired-in collections built with `mapOf` and `setOf`. Both keep their contents in key order, so two are equal when their contents are however they were built, and a value the language cannot order — a function, a task — is refused as a key with `E7008`.
- An empty tuple `()` is the unit value and has the unit type.
- `{ expression }` inside a string literal interpolates: the expression is evaluated, rendered through `display`, and concatenated. `\{` and `\}` write a literal brace. A `}` with no interpolation to close is `E0008`; an interpolation that is empty or never closes is `E0010`.
- The prelude provides the effects a program may perform — output, input, files, directories, arguments, environment, a monotonic clock, and `exit`. Each answers with `Result[T, Str]` rather than raising, since the language has no exceptions. A module-scope `const` is folded at compile time and may reach none of them, which is reported as `E7009`.
- Exported and asynchronous functions require explicit parameter and return types; synchronous private functions may infer omitted types when inference is unambiguous. An async declaration must expose a complete surface result before any caller can normalize it into stable `Task[S, E]` channels.
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
if_expr          = "if", expression, block, ("else", (if_expr | if_let_expr | block))? ;
if_let_expr      = "if", "let", pattern, "=", expression, block,
                   ("else", (if_expr | if_let_expr | block))? ;
match_expr       = "match", expression, "{", match_arm+, "}" ;
match_arm        = "case", pattern, ("if", expression)?, "=>", (expression | block) ;
while_expr       = loop_label?, "while", expression, block ;
loop_expr        = loop_label?, "loop", block ;
for_expr         = loop_label?, "for", pattern, "in", expression, block ;
```

- An array literal `[a, b, c]` builds an `Array[T]` value. `[]` is the empty array. Arrays are immutable persistent sequences backed by a fingertree: `push`, `insert`, and `remove` return new arrays with structural sharing, so no update copies the entire collection. Built-in methods: `length()`, `get(i)`, `indexOf(x)`, `contains(x)`, `push(x)`, `pop()`, `insert(i, x)`, `remove(i)`, `slice(i, j)`, `reverse()`, `map(f)`, `filter(f)`, `reduce(f, init)`. Indexing an array with `arr[i]` reads the element; out-of-bounds is `E7004`. `for x in arr` iterates elements.
- Record fields are immutable unless explicitly marked `mut` in the type declaration.
- A pattern alternation binds with `|`; a range pattern joins two literals with `..` or `..=`. `_` never binds, a bare lowercase identifier always binds, and an uppercase path is a constructor even with no payload.
- A record pattern may end with `..` to ignore the remaining fields; a field pattern without `:` binds the field to its own name.
- `match` arms are introduced by `case`, may carry an `if` guard, and produce an expression or a block after `=>`. Arms are separated by line breaks like every other construct.
- `if let PATTERN = EXPRESSION` tests one refutable pattern without spelling a two-arm `match`. The expression evaluates once; bindings exist only in the then block; failure evaluates the optional else branch or yields `()`. `else if let` nests like `else if`. A syntactically irrefutable pattern is `E1056`: use ordinary `let` when matching cannot fail. Pattern bindings are not boolean operands and therefore cannot be inserted into `&&` or `||` chains.
- `let PATTERN = EXPRESSION else BLOCK` binds a refutable pattern for the **remainder of the enclosing block**. The expression evaluates once. The `else` block must not fall through — its type is `Never`, which `return`, `break`, `continue`, and a diverging call all satisfy — and `E3036` says so when it can. That divergence is what earns the binding its scope: every statement after it runs only where the pattern matched. A syntactically irrefutable pattern is `E1057`: use ordinary `let` when matching cannot fail. Which of the two forms a `let` opens is settled by the token after it, since a binding names a value: a lowercase identifier is always the ordinary binding, and a constructor path, tuple, record, literal, or `_` is always the pattern form. `E1057` therefore reports `let _ = v else { … }` and `let (a, b) = pair else { … }`, which reach this form and cannot fail. Where `if let` binds inside its own block, `let … else` binds after itself, and neither subsumes the other — the first is for a value used once, the second for a value every following step depends on.
- A method may be called qualified by the type that implements it or by the trait that declares it: `Bot.label(&bot)` and `Speak.label(&bot)` both select `label`. The trait form is how a program picks one provider when several traits declare the same member for one type.
- A qualified call passes the receiver as an ordinary first argument, so a method declared with `self: &Self` takes a borrow. Method-call syntax borrows the receiver for you; the qualified form does not, because it is an ordinary call.
- `dynamic Trait` is a type: some value implementing that trait, whose own type is not named. It is the one place the language admits a value whose concrete type is not known at the use site, and it is what a heterogeneous collection needs — `Array[dynamic Listener]` holds any mix of implementations, and a fourth implementation added elsewhere needs no edit where the array is walked.
- Only a trait may follow `dynamic` (`E3031`). A trait written in type position without it is `E3030`, which names `dynamic` as one of the two forms that work.
- A concrete type widens into a dynamic one wherever a dynamic type is expected, and only there: a widening is not a conversion the reader has to write, but a narrowing is a `match`. A type that does not implement the trait is `E3032`.
- The expectation reaches into an `if`, a `match`, an array literal, a block, and a record field, so branches of different types each widen against what the context asked for rather than against each other. A field declared `Array[dynamic Node]` therefore takes a literal of mixed implementations, which is what a composite needs. Without that, two implementations of one trait would disagree before the declared type was ever consulted.
- A trait member returning `Self` is not callable through a dynamic value: the caller would have no type to give the result. That restriction is the honest one — the concrete type is exactly what a dynamic value does not carry.
- A member a module does not export is `E3033`, reported where it was written. The diagnostic names the *member*, not the module alias, and says that a built-in method is called on the value itself — `value.length()` rather than `Text.length(value)` — because that is the mistake it almost always is.
- **A type a module does not declare is `E3035`**, the same mistake for a type that `E3033` is for a value. Only the head of a type path is resolved — a later segment selects through a module, and that needs types to decide — so an unfound qualified name used to become a nominal type of its own named after what was written, and `M.Map[Str, Int]` was a different type from `Map[Str, Int]`. The rule is applied only where the module named was actually read, because a type a module really declares is indistinguishable from one it does not when its interface was never available.
- Declaring the same member in two traits for one type is legal. Only an unqualified call has to choose, and that call is rejected until it is written qualified.
- A record is built by naming its type and its fields: `User{id: 1, name: n}`. A field written without `:` takes the value of the binding with the same name, mirroring the record pattern's shorthand.
- A record construction is not admitted directly in the condition of `if` or `while`, the scrutinee of `match`, or the iterated expression of `for`, because `if READY { ... }` would otherwise be ambiguous with a block. Parenthesize the construction to use one there.
- A parenthesized expression groups; adding a comma makes it a tuple, and `(e,)` is the one-member tuple. This mirrors the type grammar, where `(T)` groups and `(T,)` is a tuple.
- `while` and `for` are expressions of type `()`; `loop` has the type its `break` statements carry, and `Never` when it has none. Their bodies are blocks, and `break`/`continue` are statements valid only inside them.
- A loop may be labelled by writing `@name` directly before it. `break @name` and `continue @name` act on the loop that label names rather than the nearest enclosing one, which is how a search leaves an outer loop from inside an inner one. The `@` is required: without it, `break outer` could not be told apart from breaking with the value of a binding called `outer`.
- A label may name only a loop (`E1053`). A `break` or `continue` outside every loop is `E2016`, and one naming a label no enclosing loop carries is `E2017`; both are reported before the program runs. A label repeating one already enclosing it is `W2002` — the inner one wins, but the outer loop can no longer be named.
- A function body is never inside a loop that encloses its definition: a closure may outlive the loop entirely, so a `break` written in one is `E2016`.
- Sum variants are namespaced by their type; qualification is required when ambiguous.
- **A variant may name its payload elements**, written `Circle{ radius: Int }`. `Circle{radius: 2}` builds one and `case Circle{radius}` matches it, and every field must be supplied at a construction, exactly as a record's must.
- **The declaration chooses the spelling, and only one spelling reaches the value.** A variant that named its payload is never called and never used as a value — `Circle(2)`, `Shape.Circle(2)`, a bare `Circle` stored in a binding, and `case Circle(r)` are all `E3034`. Were both admitted they would build two things that no one pattern could match, and a program that mixed them would type check and then find no arm at run time. A variant that named nothing is unchanged: it is still a constructor and still a function.
- **Naming a variant is a test, not a binding.** `case Circle{radius}` matches one variant of several, so it never covers the whole type the way a record type's own `case Boxed{value}` does. A named field that tests rather than binds covers nothing at all: `case Circle{radius: 0}` leaves `Circle` for a later arm, which is the rule `case Ok(1)` already followed.
- A variant's fields are reachable only through a pattern. There is no `shape.radius`, because the value may be another variant and no field access could say what it would mean.
- **A type declaration's parameters are instantiated at every use.** `type Boxed[T] = { value: T }` makes `Boxed{value: 7}` a `Boxed[Int]`, and reading `value` from it gives `Int` — not the declaration's parameter, which nothing could ever satisfy. This holds for records exactly as it already did for sums, and in every position a type is used: construction, field access, and patterns.
- **An implementation may carry its own type parameters**, written `impl[T] Trait[T] for Boxed[T]`. Inside it, `Self` is the target *with its arguments* — `Boxed[T]`, not a bare `Boxed` — and the implementation's parameters are rigid in its methods, exactly as a function's are inside its body. Bounds written on those parameters are in force there too, so `impl[N: Ord + Add] Sequence[N, N] for Range[N]` may call what `Ord` and `Add` promise.
- A trait may carry its own type parameters, written `trait Holds[T] { ... }`, and an implementation says what they are for the type it is written for: `impl Holds[Int] for Box`. The parameters are rigid inside the trait's members.
- A trait-qualified call is typed from the implementation it will run, not from the trait's declaration. `Holds.get(&box)` has the result `Box`'s implementation gives it, because the declaration deliberately leaves that open and only the implementation closes it. This is the same selection the evaluator makes for the same call.
- Matches are exhaustive for closed types. A guarded arm does not contribute exhaustiveness because its guard may be false.
- Pattern alternatives must bind identical names with identical inferred types.
- `_` ignores a value and never binds.

## Expression Grammar and Precedence

From tightest to loosest: postfix calls/index/member/`?`/`.await`; unary `! - & &mut ~ *`; multiplicative `* / % &* *|`; additive `+ - &+ &- +| -|`; shift and bitwise AND `<< >> &`; range and bitwise XOR `.. ..= ^`; comparison `< <= > >=`; equality `== !=`; boolean `&&`; boolean `||` and bitwise OR `|`; assignment; control expressions.

- Assignment is right-associative. Every other admitted binary band is left-associative; semantic typing rejects operator chains whose intermediate result cannot serve as the next operand.
- Assignment is a statement-like expression of type `()` and requires a mutable place.
- Function calls evaluate callee then arguments left-to-right.
- Blocks evaluate statements left-to-right and yield the final unterminated expression or `()`.
- `if` and `match` are expressions; all reachable branches must unify.
- `return`, `break`, and `continue` have type `Never` at their valid control boundary.
- Every `break` leaving the same `loop` must carry the same type, which is that loop's type. A `break` carrying a value may leave only a `loop`: `while` and `for` finish when their own condition does, so a value carried out of one would exist on some runs and not others, and that is `E3029`.
- A range endpoint is evaluated exactly once.

## Numeric Semantics

- A `Decimal` is an arbitrary-precision coefficient and a non-negative base-ten scale: the value is `coefficient * 10 ^ (-scale)`. Trailing zeros are significant and preserved, so `1.50d` renders as `1.50` and `scale` reports 2, while `1.5d` renders as `1.5` and reports 1. Equality and ordering follow the number rather than the digits, so the two compare equal. [[ADR-0007]] records why.
- Decimal addition, subtraction, and multiplication are exact and never round. A sum or difference carries the wider operand scale; a product carries the sum of the operand scales. No configured precision can truncate one.
- Decimal division is exact or it is an error. `1d / 4d` is `0.25d`; `1d / 3d` has no terminating base-ten expansion and reports `E7010`. Rounding is the decimal analogue of integer wrapping — a real answer altered to fit — and is equally impossible to get by accident. A program that wants a rounded quotient writes `Std.Decimal.divide(left, right, digits, mode)`, which never reports a non-terminating quotient because the caller already said what to do about one.
- There is no implicit conversion between `Decimal` and any other numeric type in either direction. `0.1` as a binary float is not the number `0.1`, and admitting it as `0.1d` silently would import the error the type exists to avoid. `Std.Decimal` supplies `fromInt`, `parse`, `toInt`, and `toFloat64`, and documents which of them lose information.

- Unsuffixed integer literals are arbitrary precision during inference, then must fit the context-selected integer type; when no context selects one, they default to `Int` and must fit it. A width suffix selects its exact signed or unsigned type and must fit that type. An out-of-range literal is `E3018`; suffixes do not introduce implicit numeric conversion.
- Unsuffixed floating literals and `f64` literals are `Float64`. The `f32` suffix explicitly selects `Float32`; context never narrows an unsuffixed literal. A finite spelling outside the selected IEEE range is `E3019`. Runtime `Float32` operations round every result to binary32 rather than calculating with hidden binary64 precision.
- Fixed-width `+ - *` are checked and report `E7005` at run time naming the type that could not hold the result; compile-time overflow is `E3018`. Wrapping `&+ &- &*` reduce into the type's interval and saturating `+| -| *|` clamp to its ends: the three are different operations. Bitwise operations are taken over the type's own width, a right shift keeps the sign only on a signed type, and a shift count that is negative or not below the width is `E7004`.
- **A literal is the type inference gave it, not the type it was spelled.** Writing `let count: Int8 = 127`, or passing `127` to a parameter declared `Int8`, makes that literal an `Int8`; only a literal inference left unconstrained is a platform `Int`. The width a declaration promised is therefore enforced on every value, not only on one written with a suffix — before this, `fn add(a: Int8, b: Int8) -> Int8 { a + b }` called with `127, 127` answered `254`.
- A prefix operator binds tighter than every binary one, so `*a * *b` is a product of two dereferences. A shift's count is a plain `Int` whatever the value's type is.
- A call may carry explicit type arguments, written `name[Type, Type](arguments)`. Fewer than the declaration's parameters may be written and the rest are inferred; more is `E3028`. A `[` opens type arguments only when its closing bracket is followed by `(` and its first token could begin a type, so an index is never mistaken for one.
- `&+`, `&-`, and `&*` wrap modulo 2^N. `+|`, `-|`, and `*|` saturate.
- Division by zero produces typed `DivisionByZero`; signed minimum divided by `-1` follows checked overflow rules.
- Integer division truncates toward zero. Remainder has the dividend's sign.
- Floating operations follow IEEE 754; equality follows IEEE semantics. Conversions that may lose range or precision require explicit syntax/library operations.
- No implicit numeric narrowing. Widening is allowed only where exact for every source value.

## Failure Semantics

- `Result[T, E]` is the recoverable failure carrier in v1.
- Postfix `?` yields a carrier's payload and returns that carrier's failure from the current function. **Which carrier is meant is read from the function's own declared result, never from the target.** In a function returning `Result`, `Ok(v)?` yields `v` and `Err(e)?` returns `Err(convert(e))`. In a function returning `Option`, `Some(v)?` yields `v` and `None?` returns `None`. One operator serves both because the return type has already said which is meant, so a target that is not that carrier is an ordinary type error rather than a rule of its own. A return type that is neither carrier is `E3011`. A result left unannotated is inferred as `Result`, because the `Ok` and `Err` in such a body are what decide it.
- A `match` whose every failure arm rebuilds the failure it received, in a function carrying that same carrier, is `W3003`: the arms decide nothing the return type had not already said, and `?` is the word for them. A warning rather than an error, because it names a better spelling of working code. An arm that transforms the payload, or that changes carrier, is a decision and is left alone.
- Panics represent violated internal invariants or explicit `panic`; they are not recoverable domain errors.
- Native/host exceptions are translated at unsafe or standard-library boundaries.
- `null` is permitted only inside `unsafe` foreign-interface expressions and must be converted to `Option` or a validated reference before leaving that boundary.

## Ownership and Resource Semantics

- Values are owned by default. Non-`Copy` assignment and by-value argument passing move.
- `&T` is a shared borrow; `&mut T` is an exclusive borrow.
- Prefix `*` dereferences a reference: `*r` has type `T` when `r` has type `&T` or `&mut T`. There is no implicit conversion in either direction, so a value where a reference is wanted must be borrowed and a reference where a value is wanted must be dereferenced. A field or method reached through a reference needs no `*`; `r.field` reads through the borrow.
- Borrows are inferred to the last use within a function and cannot outlive the owner.
- Mutation requires `var`, a mutable record field reached through owned mutable authority, or `&mut`.
- Destruction is deterministic at the end of ownership. Types with resource cleanup implement `Drop`; user code cannot call `drop` twice.
- Unsafe code is lexically explicit and cannot suppress move/borrow accounting for safe values.

## Iteration and Control Flow

- `for pattern in expression` binds the pattern at the **element type of what is iterated**, which is decided by the value beside it and never left open. An `Array[T]` yields `T`, a `Str` yields `Char`, a `Set[T]` yields `T`, a `Map[K, V]` yields `(K, V)`, a tuple yields its members' common type, and a sum yields the type its variants carry — which is what makes an `Option[T]` a sequence of nought or one `T`. A tuple or sum whose members disagree is rejected, because one binder cannot hold two types.
- A user type is iterated through `Std.Iter.Sequence`, which is `begin` and `advance`:

  ```pudu
  export trait Sequence[S, T] {
    fn begin(self: &Self) -> S
    fn advance(self: &Self, state: S) -> Option[(S, T)]
  }
  ```

  `begin` answers the state to start from and `advance` answers the next item and the state after it, or `None` when the sequence is finished. The state is **passed rather than mutated**, so a sequence is an ordinary value: two walks of the same value see the same items. A type with no such implementation reports `E3030` at the `for` rather than part way through one.
- The element type a `for` binds over a user type is read from that type's own `advance`, so the type the checker binds is the type the loop actually produces.
- Iterator adapters are lazy; terminal collection/consumption drives them.
- `while` reevaluates its condition before each iteration.
- `loop` takes the type of what its `break` statements carry, so a search with no natural end is still an expression: `let found = loop { ... break value }`. A `loop` no `break` leaves does not finish, and its type is `Never`, which stands wherever any type is wanted. A `break` carrying nothing carries `()`.
- `break` and `continue` act on the nearest enclosing loop unless a label names another. A labelled `continue` restarts the loop it names, which skips the remainder of every loop body between it and that one.

## Async and Structured Concurrency

- `async fn` returns a lazy `Task[T, E]`; calling it does not execute until awaited or spawned in a scope. A declared `Result[T, E]` return supplies those task channels and is not nested inside the task.
- `.await` is legal only inside `async fn` or an async block and is a cancellation point.
```ebnf
scope_expr       = "async", "with", "scope", block ;
```

- `async with scope { ... }` creates a structured task scope. Spawned tasks cannot outlive it.
- A task started inside a scope becomes its child. Awaiting the task joins it there; a child never awaited is joined when the scope exits, in the order the children started. A scope may be opened only inside an `async fn`, because joining is an await.
- Leaving a scope by a control transfer joins its children first, so the transfer continues only after the region it left is empty.
- Leaving a scope normally awaits children; leaving by failure or cancellation cancels children, runs cleanup, then waits for termination.
- Cancellation is distinct from domain `Result` failure and cannot be swallowed accidentally.
- A value crossing into a concurrently executing task must satisfy `Send`; shared cross-task references additionally require `Sync` and cannot outlive the scope.
- **A program reaches concurrency by declaring `main` itself `async`.** Calling an `async fn` gives a `Task`, `.await` is legal only inside an `async fn`, and a `Task` is not a `Result` — so a synchronous `main` can call an async function but can do nothing with what it gets back. `export async fn main() -> Result[Int, Str]` is the entry point that can, and its whole-number result is still the exit status.
- `.await` on a `Task[T, E]` yields `T`, not `Result[T, E]`. The failure channel belongs to the enclosing scope, which is what makes a child's failure leave the scope rather than something each await has to unwrap. Writing `task.await?` is therefore a type error: there is no `Result` there to propagate.
- Detached tasks are absent from v1. `task` and bare `spawn` remain reserved.

## Traits and Dispatch

- Traits declare behavior contracts without stored state.
- Implementations are coherent: at least the trait or implementing nominal type must be declared in the current module.
- Static dispatch is the default for generic trait bounds. Dynamic dispatch requires an explicit future trait-object form and is not in v1.
- Overlapping implementations and implicit conversions are prohibited.

## Compile-Time and Macro Semantics

- `const` expressions and `comptime fn` execute in a deterministic, resource-limited evaluator with no IO, environment, time, randomness, unsafe, or task operations.
- `comptime` marks a function that may run in that evaluator. The guarantee is transitive: a compile-time body may call other compile-time functions and wired-in constructors, and nothing else. It may be neither `async` nor `unsafe`, because both name capabilities the compile-time evaluator does not have.
- A compile-time function is an ordinary function too. Runtime code may call it; the marker adds a guarantee rather than restricting where it is usable.
- A module-scope `const` is evaluated when the module is compiled, so a failure in its initializer — division by zero, an exhausted evaluation budget, a constant reading one declared later — is a compile diagnostic rather than something the program discovers when it runs.
- Compile-time evaluation has configurable step and memory limits; exceeding them is a diagnostic.
- v1 macros are hygienic syntax transformers with typed parameters. They cannot access files, network, environment, compiler internals, or arbitrary host code. [[Macro Design]] records why typed parameters were chosen over a token-tree matcher.
- Each parameter declares the syntax it accepts — `expr`, `ident`, or `block` — so a mismatched argument is reported against the call. Arity is exact.
- A call is written `name!(...)`, so expansion is visible without knowing which names are macros. Arguments are parsed before substitution, so an expansion cannot change the grouping the caller wrote.
- Every binding a macro body introduces is renamed at each expansion, so it can neither capture a name at the call site nor be captured by one.
- Expansion is bounded; a macro that expands into itself reports where the expansion started.
- Expanded tokens retain call-site and definition-site provenance for diagnostics.
- Macros cannot introduce unhygienic bindings without an explicit future escape hatch.

## Unsafe Boundary

```ebnf
unsafe_block     = "unsafe", capabilities?, block ;
capabilities     = "(", capability, (",", capability)*, ","?, ")" ;
capability       = "raw" | "foreign" | "unchecked" | "null" ;
function_decl    = "unsafe", capabilities?, ... ;
```

- `unsafe { ... }` is the only construct enabling raw pointers, foreign calls marked unsafe, unchecked indexing, or `null`.
- A region names the capabilities it grants. `unsafe(raw) { ... }` grants raw pointer work and nothing else; `unsafe { ... }` with no list is the blanket form and grants all four. Naming them is what makes an unsafe region auditable: a reader sees which invariant is in play without reading the body, and tooling can find every region that does raw pointer work without a whole-program analysis.
- A function may be declared `unsafe`, optionally naming capabilities. Calling it requires an open region that grants what the declaration asked for: a blanket declaration requires only that some region is open, and a declaration naming capabilities requires each of them. A call from safe code is rejected.
- A function's unsafety is a contract its callers uphold, not a claim about its body. A body that needs nothing unchecked is still a legitimate unsafe function, because the invariant may live in its parameters.
- A region that grants a capability nothing in it used is reported. Unsafe is an audited surface, so a grant that buys nothing is removed rather than kept.
- Unsafe does not disable type checking, ownership of safe values, or lexical initialization checks.
- Public safe APIs wrapping unsafe code must state and enforce their invariants; unsafe requirements cannot be hidden in ordinary parameters.
- `null` requires the `null` capability. It has no type until raw pointers exist, so writing it reports which slice will give it one rather than admitting an untyped value.

## Copy Eligibility

- `Copy` is a compiler-controlled marker used by ownership checking, not an ordinary trait that user code may implement manually.
- Integer, floating, boolean, character, unit, and shared-reference values are `Copy`. Mutable references, owning pointers/handles, and values with `Drop` are not.
- Tuples, fixed arrays, and declared aggregates are `Copy` exactly when every stored component is `Copy` and the aggregate has no `Drop` implementation or resource identity.
- Generic aggregate copying requires a `Copy` obligation for each type parameter reachable through a copied field. Failure to prove eligibility keeps the value move-only.

## Formatting Constitution

- Official formatting uses two-space indentation, braces on declaration/control lines, trailing commas for multiline lists, and one declaration per logical block.
- Semicolons are not part of canonical syntax; newlines and braces delimit statements.
- Imports sort lexically and group standard-library before project modules.
- Formatter output is idempotent and is the only supported style for committed Pudu code. `pudu fmt` implements it, and `pudu fmt --check` is a repository gate. It works from the token stream, so it can only move whitespace: the tokens it emits are the tokens it read, and it never joins or splits a line, because a newline here delimits a statement.

## Prohibited Patterns

- No implicit nullability, numeric narrowing, exception leakage, wildcard imports, top-level execution, detached tasks, or ambient global mutation.
- No parser feature whose static and dynamic semantics are unspecified in [[architecture/SEMANTICS]].
- No optimization may alter checked overflow, destruction order, left-to-right evaluation, failure propagation, or cancellation behavior.

## Senior Definition Needed

- Stable syntax for unsafe foreign declarations and C ABI layouts will be finalized before the FFI slice.
- Macro repetition syntax remains open. [[Macro Design]] records the reason: `Array` values and compile-time functions may already cover what repetition exists for elsewhere, and a syntax added first would be the one every use is then forced through.

## Referenced by

[[grammar/_MOC]] · [[Pudu Module]] · [[Pudu Type]] · [[Ownership]] · [[architecture/SEMANTICS]] · [[Standard Library]] · [[FMCF Workflow]] · [[Token]] · [[2026-08-21-frontend-foundation]]
