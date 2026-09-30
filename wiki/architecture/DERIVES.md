---
type: architecture
tags: [architecture, semantics, comptime]
aliases: [Derive Design]
---

# Derive Design

## Decision

A type's code for equality, hashing, ordering, display, JSON, and database rows is written once, as
a **derive**: an ordinary Pudu declaration that reads a type's shape at compile time and is
instantiated for each type that asks for it. The compiler knows no derive by name; `Std` ships its
derives the same way any package would.

Reflection happens only while compiling. A derive's loops over fields and variants are unrolled per
type and every reflective call folds to a constant, so the code that runs is what a person would
have written by hand, with no reflection left in the program.

## Using a derive

A type opts in; nothing is derived by default.

```pudu
type Order = {
  @json("order_id") id: Int,
  lines: Array[Line],
  @skip cache: Option[Str]
} derives Eq, Hash, Json.Encode, Json.Decode
```

`derives X` is written on the type and means `derive impl X for Order`. The standalone form
`derive impl X for Order` is written in another module for a type it does not own, under the
existing orphan rules. A type may name a derive once.

## Writing a derive

```pudu
derive Encode for T: Record {
  fn encode(self: &T) -> Json {
    var entries = []
    comptime for field: Meta.Field[T, F] in Meta.fields[T]() where F: Encode {
      if !field.has("skip") {
        entries = entries.push((field.attributeOr("json", field.name), field.get(self).encode()))
      }
    }
    Json.object(&entries)
  }
}
```

- `derive X for T: Shape { ... }` holds the members of trait `X`. `Shape` is `Record` or `Sum`, the
  kind of type the derive accepts; a type of the other kind asking for it is refused at its
  `derives` clause.
- `comptime for element: Pattern in list where Bounds { body }` iterates over a list known at
  compile time. Each element may have its own type, which is why it is unrolled rather than
  looped. Its `where` clause states what every element's types must satisfy.

## Reflection: `Std.Meta`

Every `Meta` function is compile-time only; naming one from code that runs is refused.

| Call | Answers |
|---|---|
| `Meta.nameOf[T]()` | the declared name of `T` |
| `Meta.fields[T]()` | for a record, one `Field[T, F]` per field, in declaration order |
| `Meta.variants[T]()` | for a sum, one `Variant[T]` per variant, in declaration order |
| `field.name`, `field.get(&value)`, `field.set(&value, held)` | the field's name and access to it |
| `field.has(name)`, `field.attributeOr(name, fallback)` | the field's attributes |
| `Meta.build[T](each)` | a record of `T`, with `each` applied to every field |
| `variant.name`, `variant.fields()`, `variant.matches(&value)`, `variant.build(each)` | a variant's name, payload fields, test, and construction |

`build` is how a derive makes a value rather than reads one, as `Json.Decode` and `Db.Row` must.
`each` is a compile-time function taking a `Field[T, F]` and answering an `F`, or a
`Result[F, E]`; it is unrolled into one record literal, and with `Result` the first `Err` is
answered. Its bounds are stated like a loop's: `Meta.build[T](fn(field: Meta.Field[T, F]) ->
Result[F, Error] where F: Decode { ... })`.

Types, fields, and variants carry **attributes**, written `@name` or `@name(literal, ...)`. They are
inert data that only compile-time code reads. An attribute no derive reads is allowed; a derive may
refuse one it does not recognise.

## Phases

1. **Resolution** runs as today; `derives` clauses, `derive` declarations, and attributes are
   resolved like any other names.
2. **Derive checking** checks each `derive` declaration once, generically, at its definition. `T`
   is abstract under its shape bound, and inside a `comptime for` each element's type variables are
   abstract under the loop's `where` bounds, exactly as a generic function's parameters are. A
   mistake in a derive body is reported once, to its author.
3. **Derive instantiation** runs after declaration collection and before function bodies are
   checked. For each `derives X` it produces an ordinary `impl X for T`: every `comptime for` is
   unrolled once per field or variant, `Meta` calls fold to constants (`field.name` to its literal,
   `field.get(self)` to `self.id`, attribute reads to their values), and an `if` on a compile-time
   Boolean keeps only the branch taken. The only check left at a use site is whether each element's
   types meet the loop's `where` bounds.
4. **Checking and evaluation** see only the generated impls, never a derive or a `Meta` call.

A `where` bound that mentions a type parameter of a generic type becomes a bound on the generated
impl: `type Pair[A] = { left: A, right: A } derives Eq` produces `impl[A: Eq] Eq for Pair[A]`.

Instantiation shares the compile-time evaluator's step and depth budget. A derive needing another
capability of a field type (`Encode` on `Line`) relies on that type's own `derives` or `impl`,
never on an implicit derive.

## Diagnostics

- A mistake inside a derive body is reported at the derive's definition, once.
- A field whose type does not meet a loop's bound is reported at the field, with a note at the
  `derives` clause: `Order.lines: Array[Line]` does not implement `Encode`, which `derive Encode`
  requires of every field.
- Every generated node carries the derive body's span and the `derives` site, so errors, editor
  hover, and the debugger point at text a person wrote.
- `pudu expand <file>` prints the generated impls.

## What Std ships

`Eq`, `Hash`, and `Ord` (field order, then variant order), `Show`, `Json.Encode` and `Json.Decode`
(honouring `@json(name)`, `@skip`, and `@default(value)`), and `Db.Row` (honouring
`@column(name)`), each an ordinary derive. Hand-written impls in `Std` that these reproduce exactly
are replaced by `derives`, and the existing fixtures confirm the behaviour did not change.

## Testing

- Fixtures per shipped derive over records, sums, generic types, attributes, and recursive types.
- Checker specs: a derive-body mistake reported once at the definition; an unmet field bound
  reported at the field; generated code carrying real spans; `Meta` refused outside compile time.
- `pudu expand` snapshots, each semantic delta inspected.
- A benchmark showing a derived `Json.Encode` runs as fast as a hand-written one.

## Out of scope

Quasi-quoted syntax and item or statement macros (the next design, reusing `Meta`); derives that
add free functions outside an impl; reflection at run time; derives taking parameters other than
attributes.

## Grill Log

- **Q:** Built-in derives or derives anyone can write? **A:** Anyone, in Pudu. _Rationale:_ a
  compiler that knows derives by name makes every new format a compiler change; `Std` proves the
  mechanism by shipping its own derives through it. _Rejected:_ a fixed native set.
- **Q:** Generate syntax, or reflect and unroll? **A:** Reflect and unroll. _Rationale:_ a derive
  stays ordinary, checked Pudu with no syntax tree to learn, it is checked once at its definition,
  and the generated code carries no reflection. _Rejected:_ quasi-quoted syntax as the first
  mechanism, which checks a derive only when it expands; source text returned as a string, which
  has neither safety nor useful diagnostics.
- **Q:** Check a derive per use, as a template? **A:** No. _Rationale:_ the `where` bound on
  `comptime for` lets the body be checked once with element types abstract, so a use site only
  checks bounds and reports them at the field. _Rejected:_ template-style checking, whose errors
  repeat at every type and describe the derive's internals.
- **Q:** Derive automatically for every type that fits? **A:** No; a type opts in. _Rationale:_
  an automatic impl changes what a type means without anything written at the type, and two
  packages' automatic impls would conflict. _Rejected:_ blanket impls over shape bounds.

## Referenced by

[[architecture/_MOC]] · [[Macro Design]] · [[architecture/SEMANTICS]]
