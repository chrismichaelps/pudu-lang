# Basics

This page covers what every Pudu file is made of: a module, its imports, and the values and functions it declares.

## Modules

Every file begins with exactly one `module` declaration, and the name matches the file's path. `module Shapes.Area` lives in `Shapes/Area.pudu`. A file holds declarations only; nothing runs when a module is loaded.

```pudu
module Greeting

import Std.Io as Io

const GREETING: Str = "Hello"

export fn greet(name: Str) -> Str {
  "{GREETING}, {name}!"
}

fn main() -> Int {
  let _written = Io.writeLine(greet("Pudu"))
  0
}
```

## Imports

Imports are absolute, and there are exactly three forms:

| Form | What it binds |
| --- | --- |
| `import Std.Text` | the module, used as `Std.Text.trim(value)` |
| `import Std.Text as Text` | the module under a shorter name, `Text.trim(value)` |
| `import Std.Option {unwrapOr}` | the named items, used unqualified |

There are no wildcard imports. A reader can always answer "where did this name come from" from the import list alone.

## Visibility

Declarations are private to their module unless they are marked `export`. Exported functions must write out every parameter type and their return type, because other modules depend on that signature.

## Values

| Keyword | Meaning |
| --- | --- |
| `let` | an immutable binding |
| `var` | a binding that may be assigned again |
| `const` | a value computed while the program is compiled |

```pudu
module Values

fn main() -> Int {
  let language = "Pudu"
  var lessons = 1
  lessons = lessons + 1
  let summary = "{language} has {lessons} lessons"
  if summary.isEmpty() { 1 } else { 0 }
}
```

At module scope only `const` is allowed, so a program has no global mutable state. A `const` initialiser runs at compile time and cannot read files, the clock, or anything else outside the program.

## Taking a value apart

A binding can name the parts of a value instead of the value itself. A record is taken apart by
field, a tuple and an array by position, and `..` in an array pattern holds whatever the named
elements did not take:

```pudu
module Apart

type Point = { x: Int, y: Int }

fn main() -> Int {
  let point = Point{x: 3, y: 4}
  let {x, y} = point
  let {x: across} = point

  let pair = (10, 20)
  let (left, right) = pair

  let scores = [95, 82, 47, 61]
  let [best, second, ..rest] = scores
  let [..earlier, worst] = scores

  var {y: movable} = point
  movable = movable + 1

  if x == 3 && y == 4 && across == 3
    && left == 10 && right == 20
    && best == 95 && second == 82 && rest == [47, 61]
    && earlier.length() == 3 && worst == 61
    && movable == 5
  {
    0
  } else {
    1
  }
}
```

`var` binds parts that may be assigned again. A pattern here has to be one that always applies: one
that tests a tag, like `Some(value)`, has nowhere to go when it does not match, so it belongs in
`let … else` instead. An array pattern is the exception — it names a length, and an array of another
length stops the program where the binding is.

## Functions

A function names its parameters and their types, and writes its result type after `->`. The body is a block whose last expression is the result, or an expression after `=`:

```pudu
module Arithmetic

fn double(number: Int) -> Int = number * 2

fn describe(number: Int) -> Str {
  let doubled = double(number)
  "{number} doubled is {doubled}"
}

fn main() -> Int {
  if describe(21) == "21 doubled is 42" { 0 } else { 1 }
}
```

Generic functions take type parameters in square brackets:

```pudu
module Generics

fn first[T](items: &Array[T]) -> Option[T] {
  if items.length() == 0 { None } else { Some(items[0]) }
}

fn main() -> Int {
  match first(&[3, 1, 2]) {
    case Some(value) => value - 3
    case None => 1
  }
}
```

## Text

Strings are UTF-8. An expression in braces inside a string is interpolated, and `\{` or `\}` writes a literal brace:

```pudu
module Text

fn main() -> Int {
  let name = "Ada"
  let line = "Hello, {name}! There are {name.length()} letters."
  let braces = "\{ not interpolated \}"
  if line.contains("Ada") && braces.startsWith("\{") { 0 } else { 1 }
}
```

## Comments

- `//` starts a line comment, and `/* ... */` block comments nest.
- `///` above a declaration is its documentation. `pudu doc` reads it, and editors show it on hover.

## Statements and blocks

A statement ends at the end of its line; there are no semicolons. Two statements written on one line are an error. A line continues the previous statement when that line ends with an operator waiting for its right side, or when the next line begins with `.` or `?`:

```pudu
module Lines

fn main() -> Int {
  let total = 1 +
    2 +
    3
  let shouted = "quiet"
    .toUpper()
  if total == 6 && shouted == "QUIET" { 0 } else { 1 }
}
```

A block's value is its last expression. `if` and `match` are expressions, so both can produce a value directly.
