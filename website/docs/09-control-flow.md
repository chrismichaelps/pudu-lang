# Control flow

Pudu's control flow is made of expressions: `if` and `match` produce values, and a `loop` can produce the value it was searching for.

## if

`if` is an expression. Every branch that can be reached must produce the same type:

```pudu
module Grades

fn letter(score: Int) -> Str {
  if score >= 90 { "A" } else if score >= 80 { "B" } else { "C" }
}

fn main() -> Int {
  if letter(95) == "A" && letter(70) == "C" { 0 } else { 1 }
}
```

## match

`match` compares a value against patterns, top to bottom, and runs the first arm that fits. Every arm starts with `case`, and an arm may add a guard with `if`. A `match` must cover every shape the value can have:

```pudu
module Matching

fn describe(value: Option[Int]) -> Str {
  match value {
    case Some(score) if score >= 90 => "excellent"
    case Some(score) => "scored {score}"
    case None => "no score"
  }
}

fn main() -> Int {
  if describe(Some(95)) == "excellent" && describe(None) == "no score" { 0 } else { 1 }
}
```

Patterns include literals, ranges such as `1..=9`, alternatives joined with `|`, tuples, records, and variants. `_` matches anything and binds nothing.

## if let

`if let` tests one pattern without writing a whole `match`. The names it binds exist only inside its block:

```pudu
module Lookup

fn firstFailing(scores: &Array[Int]) -> Option[Int] {
  for score in *scores {
    if score < 60 { return Some(score) }
  }
  None
}

fn main() -> Int {
  if let Some(failing) = firstFailing(&[95, 82, 47]) {
    failing - 47
  } else {
    1
  }
}
```

## let … else

`let PATTERN = value else { ... }` binds a pattern for the rest of the block. The `else` block runs when the pattern does not match, and it must leave — with `return`, `break`, or `continue` — so every line after it can rely on the binding:

```pudu
module Early

import Std.Text as Text

fn portOf(text: Str) -> Int {
  let Some(port) = Text.wholeOf(text) else { return 0 }
  port
}

fn main() -> Int {
  if portOf("8080") == 8080 && portOf("http") == 0 { 0 } else { 1 }
}
```

## Loops

| Loop | Runs |
| --- | --- |
| `while condition { ... }` | while the condition holds |
| `while let PATTERN = value { ... }` | while the pattern matches |
| `for item in collection { ... }` | once for each item |
| `loop { ... }` | until a `break` |

`for` walks arrays, text (one `Char` at a time), sets, maps (as `(key, value)` pairs), and any type that implements `Std.Iter.Sequence`. A `loop` is an expression whose value is what its `break` carries:

```pudu
module Search

fn main() -> Int {
  var total = 0
  for score in [95, 82, 47] {
    total = total + score
  }
  var remaining = total
  let found = loop {
    remaining = remaining - 10
    if remaining < 100 { break remaining }
  }
  if found < 100 { 0 } else { 1 }
}
```

## Labels

`break` and `continue` act on the nearest loop. A label written `@name` before a loop lets an inner loop leave an outer one:

```pudu
module Labels

fn main() -> Int {
  var found = 0
  @rows for row in [1, 2, 3] {
    for column in [1, 2, 3] {
      if row * column == 6 {
        found = row * 10 + column
        break @rows
      }
    }
  }
  if found == 23 { 0 } else { 1 }
}
```
