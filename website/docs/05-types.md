# Types

Every value in Pudu has one type, known when the program is compiled. This page covers the built-in types, the types a program declares, and the collections the language provides.

## Built-in types

| Type | Values |
| --- | --- |
| `Int`, `UInt` | whole numbers the width of the target machine |
| `Int8` … `Int128`, `UInt8` … `UInt128` | whole numbers of a fixed width |
| `Float32`, `Float64` | floating-point numbers; `Float` is `Float64` |
| `Decimal` | exact base-ten numbers, written `1.5d` |
| `BigInt` | whole numbers of any size |
| `Bool` | `true` and `false` |
| `Char` | one Unicode scalar value, written `'a'` |
| `Str` | UTF-8 text |
| `()` | the unit value, for results that carry nothing |

Fixed-width arithmetic is checked: `+`, `-`, and `*` stop the program with a diagnostic naming the type rather than wrapping around. The wrapping operators `&+ &- &*` and the saturating operators `+| -| *|` are there when that is what you mean. A literal may carry its width, as in `255u8` or `1.5f32`. [Numbers](/docs/numbers) covers each of these in depth.

## Records

A record type names its fields. A record is built by naming the type and every field:

```pudu
module Records

type User = { id: Int, name: Str, email: Str }

fn main() -> Int {
  let ada = User{id: 1, name: "Ada", email: "ada@example.com"}
  let renamed = User{..ada, name: "Ada Lovelace"}
  if renamed.id == ada.id && renamed.name != ada.name { 0 } else { 1 }
}
```

`User{..ada, name: n}` builds a copy of `ada` with one field replaced, so changing one field never means writing out all the others. Fields are immutable unless the type marks them `mut`.

## Sum types

A sum type lists the shapes a value can take. Each variant may carry values:

```pudu
module Shapes

import Std.Io as Io

type Point = { x: Float64, y: Float64 }

type Shape =
  | Circle(Point, Float64)
  | Rectangle(Point, Point)

fn area(shape: &Shape) -> Float64 {
  match shape {
    case Circle(_, radius) => 3.14159 * radius * radius
    case Rectangle(low, high) => (high.x - low.x) * (high.y - low.y)
  }
}

fn main() -> Int {
  let origin = Point{x: 0.0, y: 0.0}
  let shapes = [Circle(origin, 1.0), Rectangle(origin, Point{x: 2.0, y: 3.0})]
  for shape in shapes {
    let _written = Io.writeLine("area: {area(&shape)}")
  }
  0
}
```

A variant can also name what it carries, written `Circle{ radius: Float64 }`. It is then built as `Circle{radius: 2.0}` and matched as `case Circle{radius}`.

## Option and Result

Two sum types appear in almost every program:

- `Option[T]` is `Some(value)` or `None`. It is how Pudu writes a value that may be absent; no ordinary type can hold `null`.
- `Result[T, E]` is `Ok(value)` or `Err(problem)`. It is how Pudu writes work that may fail. See [Errors](/docs/errors).

Because they are ordinary sum types, their helpers are module functions rather than methods: `Option.unwrapOr(value, fallback)`, from `Std.Option`.

## Generic types

A type may take type parameters, in square brackets:

```pudu
module Boxes

type Pair[A, B] = { first: A, second: B }

fn swap[A, B](pair: Pair[A, B]) -> Pair[B, A] {
  Pair{first: pair.second, second: pair.first}
}

fn main() -> Int {
  let swapped = swap(Pair{first: 1, second: "one"})
  if swapped.first == "one" { 0 } else { 1 }
}
```

## Tuples

A tuple groups values of different types without naming them: `(1, "one")`. A member is read by its position, `pair[0]`. `()` is the empty tuple, the unit value.

## Collections

| Type | Built with | Notes |
| --- | --- | --- |
| `Array[T]` | `[1, 2, 3]` | an ordered sequence; `push`, `insert`, and `remove` return a new array |
| `Map[K, V]` | `mapOf([("a", 1)])` | keys kept in order |
| `Set[T]` | `#{1, 2, 3}` or `setOf([1, 2, 3])` | members kept in order |

Arrays, maps, and sets never change in place: every operation answers a new value that shares what it can with the old one. Arrays carry built-in methods such as `length()`, `contains(x)`, `map(f)`, `filter(f)`, and `reduce(f, initial)`. Maps carry `get(key)`, `containsKey(key)`, `insert(key, value)`, `remove(key)`, `keys()`, and `size()`. `value in set` tests membership.

```pudu
module Collections

fn main() -> Int {
  let numbers = [1, 2, 3, 4]
  let evens = numbers.filter(fn(n: Int) => n % 2 == 0)
  let ages = mapOf([("ada", 36), ("grace", 45)])
  let older = ages.insert("alan", 41)
  let seen = #{"ada", "grace"}
  let counted = evens.length() == 2 && older.size() == 3 && ages.size() == 2
  if counted && ages.containsKey("ada") && "grace" in seen { 0 } else { 1 }
}
```
