# Derives

Equality, hashing, ordering, display, JSON, and database rows are code every type needs and nobody wants to write twice. A `derives` clause asks for it; a `derive` declaration writes it once, for every type, as ordinary Pudu that reads the type's shape while the program compiles.

## Asking for implementations

Put `derives` after a record or sum and list the traits it should implement. Attributes, written `@name` or `@name(value)`, tune what a derive does with a field:

```pudu
module Orders

import Std.Io as Io
import Std.Json
import Std.Order {Eq, Hash}
import Std.Show {Show}

type Line = { sku: Str, @json("qty") quantity: Int } derives Eq, Hash, Show, Json.Encode, Json.Decode

type Order = {
  @json("order_id") id: Int,
  lines: Array[Line],
  @skip note: Option[Str],
} derives Eq, Hash, Show, Json.Encode, Json.Decode

fn main() -> Int {
  let order = Order{id: 7, lines: [Line{sku: "tea", quantity: 2}], note: Some("gift")}
  let text = Json.encode(&order.encode())
  let _written = Io.writeLine(text)
  let _shown = Io.writeLine(order.show())
  let back: Result[Order, Json.DecodeError] = match Json.decode(text) {
    case Ok(json) => Order.decode(&json)
    case Err(_) => Err(Json.DecodeError{path: [], expected: "JSON", found: "text"})
  }
  match back {
    case Ok(read) => if read.id == 7 && read.lines.equals(&order.lines) && read.note == None { 0 } else { 1 }
    case Err(problem) => {
      let _failed = Io.writeLine(Json.explainDecode(&problem))
      1
    }
  }
}
```

That prints:

```text
{"order_id":7,"lines":[{"sku":"tea","qty":2}]}
Order{id: 7, lines: [Line{sku: "tea", quantity: 2}], note: Some("gift")}
```

What a derived implementation does is what a person would write by hand, field by field in declaration order. The traits `Std` ships derives for:

| Trait | Module | Reads |
| --- | --- | --- |
| `Eq`, `Hash`, `Ord` | `Std.Order` | fields in order; variants in declaration order |
| `Show` | `Std.Show` | the type's own names |
| `Json.Encode`, `Json.Decode` | `Std.Json` | `@json(name)`, `@skip`, `@default(json)` |
| `Row` | `Std.Db.Row` | `@column(name)` |

Sums work the same way. A JSON sum is an object with one key, the variant's name; ordering compares variants by their position, then their payloads:

```pudu
module Shapes

import Std.Order {Eq, Ord}
import Std.Show {Show}

type Shape = Dot | Circle(Int) | Rect{w: Int, h: Int} derives Eq, Ord, Show

fn main() -> Int {
  let shapes = [Rect{w: 2, h: 3}, Dot, Circle(4)]
  let first = shapes[1]
  if first.before(&shapes[2]) && Circle(4).show() == "Circle(4)" && !Dot.equals(&Circle(1)) { 0 } else { 1 }
}
```

## When a field cannot be derived

Every field has to provide what the derive needs of it. A field that cannot is reported at the field, with a note at the `derives` clause that asked:

```text
error[E3092]: Order.lines: Array[Line] does not implement Hash, which derive Hash requires of every field
   = note: derive requested here
```

Give the field's type the trait — usually by deriving it there too — or leave the trait out of the clause.

## Writing a derive

A `derive` declaration implements a trait for every record, or every sum, that asks for it. Its body reads the type through `Std.Meta`, all of it at compile time: `comptime for` walks the fields, and each `field` knows its name, its attributes, and how to read itself from a value:

```pudu
module Describe

import Std.Meta
import Std.Show {Show}

trait Describe {
  fn describe(self: &Self) -> Str
}

derive Describe for T: Record {
  fn describe(self: &T) -> Str {
    var text = Meta.nameOf[T]()
    comptime for field: Meta.Field[T, F] in Meta.fields[T]() where F: Show {
      if !field.has("secret") {
        text = text + " " + field.attributeOr("label", field.name) + "=" + field.get(self).show()
      }
    }
    text
  }
}

type User = { @label("user") name: Str, age: Int, @secret password: Str } derives Describe

fn main() -> Int {
  let user = User{name: "ada", age: 36, password: "hunter2"}
  if user.describe() == "User user=\"ada\" age=36" { 0 } else { 1 }
}
```

| Call | Answers |
| --- | --- |
| `Meta.nameOf[T]()` | the type's name |
| `Meta.fields[T]()` | a record's fields, in declaration order |
| `Meta.variants[T]()` | a sum's variants, in declaration order |
| `field.name`, `field.get(&value)` | a field's name and value |
| `field.has(name)`, `field.attributeOr(name, fallback)` | a field's attributes |
| `variant.matches(&value)`, `variant.fields()` | a variant's test and payload fields |
| `Meta.build[T](each)`, `Meta.collect[T](each)` | a new record, or an array, one field at a time |

The `where F: Show` on the loop is the derive's promise about every field: inside the loop each field has its own type `F`, and the derive may only use what `F` is bound to provide. A derive is checked once, where it is written, against that promise; a mistake in its body is reported there, not once per type that uses it.

## Building values

`Meta.build` makes a value rather than reading one, which is how `Json.Decode` and `Db.Row` work. Its callback answers each field; a callback answering `Result` stops at the first `Err`. A trait member that takes no `self` is called through the field's type:

```pudu
module Defaults

import Std.Meta

trait Fill {
  fn filled(text: Str) -> Self
}

impl Fill for Int { fn filled(text: Str) -> Self = text.length() }
impl Fill for Str { fn filled(text: Str) -> Self = text }

derive Fill for T: Record {
  fn filled(text: Str) -> T {
    Meta.build[T](fn(field: Meta.Field[T, F]) -> F where F: Fill { F.filled(text + ":" + field.name) })
  }
}

type Pair = { label: Str, size: Int } derives Fill

fn main() -> Int {
  let pair = Pair.filled("x")
  if pair.label == "x:label" && pair.size == 6 { 0 } else { 1 }
}
```

## Nothing happens at run time

A derive expands into an ordinary `impl` before anything else is checked. The running program never sees `Meta`, a loop over fields, or an attribute: a derived JSON encoder is the same code, and as fast, as one written by hand. To read what a file's derives produced, run:

```sh
pudu expand Orders.pudu
```

It prints each implementation as the module that defines the derive would write it.
