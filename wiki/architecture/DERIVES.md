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

## Integration contracts

A trait may have one derive for each shape, Record and Sum. The derive catalog is
separate from the ordinary trait namespace and is keyed by canonical trait identity
and shape; a type asks once and selects its shape. Imported aliases select the same
identity. Attribute names remain inert metadata rather than runtime declarations.

Graph elaboration publishes generated ordinary impl heads before module interfaces
are prepared. Derive definitions are checked once in their defining module, with
an abstract shape parameter and fresh field parameters carrying loop/callback bounds.
The residualizer folds metadata, unrolls heterogeneous loops, and preserves runtime
expressions. User derives and Std derives use the same mechanism.

Every generated span retains valid authored offsets plus a definition, request and
node identity. Fact maps key by the complete span, not offsets alone. Diagnostics
retain both authored locations. Products with external generated provenance safely
miss persistent caches until graph source rebinding is implemented; derive bodies
participate in interface fingerprints so edits invalidate consumers. No cache-hit
performance guarantee is made for those products.

The existing evaluator limits are 4096 call depth and 100000 compile-time loop
iterations. A phase-neutral limits module supplies both evaluator and residualizer;
expansion accounts bounded traversal work and nested unrolling rather than permitting
an unbounded build. Existing runtime loops remain unrestricted.

The library adds ordinary trait contracts where none previously existed:
`Show.show(&Self) -> Str`, `Json.Encode.encode(&Self) -> Json`,
`Json.Decode.decode(&Json) -> Result[Self, DecodeError]`, and
`Db.Row.fromRow(&Driver.Rows, Int) -> Result[Self, RowError]`. These contracts
preserve existing module functions. `Db.Row` builds fields through ordinary
`Std.Db.Row.Column.fromColumn`, which uses the existing strict row readers.

Derived equality and hashing delegate to field traits. Ordering is lexicographic
in declaration order and tests each direction, without requiring Eq. Hashing combines
ordered field hashes and the variant index. Show renders declared names and fields
in declaration order. JSON records are objects; sums are single-key objects whose
key is the variant name and whose value is an array for positional payloads or an
object for named payloads. Unit variants carry an empty array. `@json` renames wire
fields/variants. Decode ignores unknown fields, refuses duplicate consumed keys,
and applies `@default` to missing fields. A skipped field uses its explicit default
or decodes JSON null; an Option therefore becomes None while required scalars refuse
absence. Consumed wire names must be unique. DecodeError preserves a field/index
path separately from textual JsonError positions. `@column` selects the strict
row reader's column name.

Generic static trait calls inside a build callback must preserve concrete type
selection after type erasure. The implementation must carry or specialize that
selection; consulting the result's runtime value cannot select a decoder before
that value exists. Generated code remains ordinary trait calls with no metadata.

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
- **Q:** Does unrolling risk slow builds? **A:** Every loop uses the shared
  compile-time iteration and call-depth limits, and expansion visits each node once; caching generated
  impls across modules is later work once real derives measure the cost. _Rationale:_ an
  unbounded compile-time loop is a build that never ends, so the bound comes before the
  optimization. _Rejected:_ unlimited unrolling with caching promised up front.
- **Q:** How does the compiler recognize a compile-time-only name? **A:** By its declaring
  module: names declared in `Std.Meta` refuse outside derive definitions. _Rationale:_
  reflection over type shapes is intrinsic compiler work, like the prelude import, while no
  individual derive is known — the design's core rule survives because only the module is
  fixed, never its members. Canonical module identity (not spelling) keeps aliases honest.
  _Rejected:_ per-name compiler knowledge, which makes every new Meta function a compiler
  change; marker attributes, which user code could forge.
- **Q:** Reserve `derive` and `derives` as keywords? **A:** No; both stay contextual identifiers.
  _Rationale:_ each is only special where the grammar puts it — a declaration start and a
  definition end — so reserving them renames working programs for no diagnostic gain, and the
  `foreign` precedent shows contextual words carry their weight. _Rejected:_ new keywords.
- **Q:** Check the parsed surface in later phases before instantiation exists? **A:** Resolution
  walks what names exist and binds rigid positions (derive parameter, loop `where` subjects) the
  way generic headers bind theirs; checking reports `E3090` on a surviving compile-time loop;
  evaluation refuses one as unexpanded. _Rationale:_ each phase stays explicit about the missing
  phase instead of crashing the compiler or silently accepting template code. _Rejected:_
  catch-all silence; leaving rigid variables unbound until instantiation.
- **Q:** Where do attributes sit on a type declaration? **A:** First, before visibility and
  `export` modifiers: `@json("id") export type ...`. _Rationale:_ the attribute annotates the
  whole declaration that follows, matching field and variant position where the attribute
  immediately precedes its item; modifiers keep their existing relative order after it.
  _Rejected:_ attributes between modifiers, which would split the modifier prefix the parser
  and the formatter treat as one unit.
- **Q:** Which literal productions may attribute arguments use? **A:** Unsigned integer, decimal,
  string, char, `true`, `false`, and `null` literals only. _Rationale:_ arguments are inert
  data read at compile time; a leading `-` parses as negation rather than part of the literal,
  and compound values would need evaluation to stay inert. _Rejected:_ signed numerics and
  compound literals as argument productions.

## Referenced by

[[architecture/_MOC]] · [[Macro Design]] · [[architecture/SEMANTICS]]
