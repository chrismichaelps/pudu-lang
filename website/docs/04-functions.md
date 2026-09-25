# Functions

Functions are where a Pudu program does its work. This chapter covers declaring them, calling them, giving parameters defaults, passing functions as values, and writing function literals.

## Declaring a function

A function names its parameters with their types and states what it returns:

```pudu
module Area

fn rectangleArea(width: Int, height: Int) -> Int {
  width * height
}

fn main() -> Int {
  if rectangleArea(3, 4) == 12 { 0 } else { 1 }
}
```

The last expression in the body is the result, so there is no `return` in `rectangleArea`. A function that produces nothing useful returns `()`, the unit value, and may leave the return type out when it is not exported.

## Expression bodies

A function whose whole body is one expression can say so with `=`:

```pudu
module Doubling

fn double(n: Int) -> Int = n * 2

fn square(n: Int) -> Int = n * n

fn main() -> Int {
  if double(square(3)) == 18 { 0 } else { 1 }
}
```

## Returning early

`return` leaves a function straight away with a value. It reads best at the top of a function, dealing with the special cases before the main work:

```pudu
module Grading

fn grade(score: Int) -> Str {
  if score < 0 || score > 100 { return "invalid" }
  if score >= 90 { return "excellent" }
  "scored {score}"
}

fn main() -> Int {
  let ok = grade(-5) == "invalid" && grade(95) == "excellent" && grade(70) == "scored 70"
  if ok { 0 } else { 1 }
}
```

## Default values

A parameter can have a default, used when a call leaves the argument out. Parameters with defaults come after the ones without:

```pudu
module Defaults

fn greet(name: Str, greeting: Str = "Hello", punctuation: Str = "!") -> Str {
  "{greeting}, {name}{punctuation}"
}

fn main() -> Int {
  let plain = greet("Ada")
  let warm = greet("Ada", "Welcome")
  let quiet = greet("Ada", "Hi", ".")
  if plain == "Hello, Ada!" && warm == "Welcome, Ada!" && quiet == "Hi, Ada." { 0 } else { 1 }
}
```

## Recursion

A function may call itself. There is no special syntax, and the recursion ends when a branch stops calling:

```pudu
module Factorial

fn factorial(n: Int) -> Int {
  if n <= 1 { 1 } else { n * factorial(n - 1) }
}

fn fibonacci(n: Int) -> Int {
  if n < 2 { n } else { fibonacci(n - 1) + fibonacci(n - 2) }
}

fn main() -> Int {
  if factorial(5) == 120 && fibonacci(10) == 55 { 0 } else { 1 }
}
```

For long-running work, a loop is usually clearer and uses less memory than deep recursion; the [control flow](/docs/control-flow) chapter covers loops.

## Functions are values

A function can be stored in a binding, passed to another function, and kept in a collection. Its type is written `fn(ParameterTypes) -> Result`:

```pudu
module Values

fn double(n: Int) -> Int = n * 2

fn increment(n: Int) -> Int = n + 1

fn applyTwice(change: fn(Int) -> Int, start: Int) -> Int {
  change(change(start))
}

fn main() -> Int {
  let steps = [double, increment]
  var value = 5
  for step in steps {
    value = step(value)
  }
  if applyTwice(double, 3) == 12 && value == 11 { 0 } else { 1 }
}
```

## Function literals

A function literal is a function written where it is used. The short form, with `=>`, has a single expression as its body; the long form has a block and states its return type:

```pudu
module Literals

fn main() -> Int {
  let numbers = [1, 2, 3, 4, 5, 6]
  let evens = numbers.filter(fn(n: Int) => n % 2 == 0)
  let labels = evens.map(fn(n: Int) -> Str {
    let doubled = n * 2
    "{n} doubles to {doubled}"
  })
  if evens == [2, 4, 6] && labels[0] == "2 doubles to 4" { 0 } else { 1 }
}
```

A literal can use the bindings around it. It captures them by copying, so it sees their values as they were when it was written, and it cannot change them:

```pudu
module Capturing

fn adder(amount: Int) -> fn(Int) -> Int {
  fn(n: Int) => n + amount
}

fn main() -> Int {
  let addTen = adder(10)
  let addOne = adder(1)
  if addTen(5) == 15 && addOne(5) == 6 { 0 } else { 1 }
}
```

`adder` returns a function. Each call makes a new one that remembers its own `amount`.

## The short form

The same literal is written with bars instead of `fn`, which is the form to reach for when the
literal is an argument and the interesting part is the body. The types are usually clear from where
it is used, so they can be left off:

```pudu
module ShortLiterals

fn twice(f: fn(Int) -> Int) -> fn(Int) -> Int { |x| f(f(x)) }

fn main() -> Int {
  let numbers = [1, 2, 3, 4, 5, 6]
  let evens = numbers.filter(|n| n % 2 == 0)
  let doubled = numbers.map(|n| n * 2)
  let total = numbers.reduce(|carried, n| carried + n, 0)

  let annotated = |n: Int| -> Int { n * 3 }
  let takesNothing = || 7
  let block = |n| {
    let squared = n * n
    squared + 1
  }

  if evens == [2, 4, 6]
    && doubled[0] == 2
    && total == 21
    && annotated(2) == 6
    && takesNothing() == 7
    && block(3) == 10
    && twice(|n| n + 3)(1) == 7
  {
    0
  } else {
    1
  }
}
```

`|x| body` and `fn(x) => body` build the same value; nothing can tell them apart afterwards. `||` is
the literal that takes nothing — the two bars written together. `async` goes in front of either form.

Because a bar is also the operator that joins two values, a literal that begins a line is read as a
new statement rather than as a continuation of the line above. That is what lets a literal be the
last expression of a block, which is where one most often goes:

```pudu
module LiteralResult

fn chooser(step: Int) -> fn(Int) -> Int {
  let doubled = step * 2
  |n| n + doubled
}

fn main() -> Int {
  if chooser(5)(1) == 11 { 0 } else { 1 }
}
```

A literal holds on to the names it mentions, and only those. `doubled` above is kept because the
literal uses it; anything else in scope is free to be collected as soon as the function returns.

## Generic functions

A function can work for many types by naming a type parameter in square brackets. The compiler works out the type at each call:

```pudu
module Generic

import Std.Option as Option

fn firstOr[T](items: &Array[T], fallback: T) -> T {
  if items.isEmpty() { fallback } else { items[0] }
}

fn pairUp[A, B](left: A, right: B) -> (A, B) {
  (left, right)
}

fn main() -> Int {
  let number = firstOr(&[7, 8, 9], 0)
  let word = firstOr(&[], "none")
  let pair = pairUp("age", 36)
  if number == 7 && word == "none" && pair[1] == 36 { 0 } else { 1 }
}
```

A type parameter can also require behaviour, such as `T: Ord` for values that can be compared. That is covered with [traits](/docs/traits).

## Parameters that change what they are given

A parameter normally receives a copy of a value or a read-only borrow of it. A parameter typed `&mut T` may change the caller's value, and the caller writes `&mut` to agree:

```pudu
module Changing

fn addBonus(score: &mut Int, bonus: Int) -> () {
  *score = *score + bonus
}

fn main() -> Int {
  var score = 40
  addBonus(&mut score, 2)
  if score == 42 { 0 } else { 1 }
}
```

The [ownership](/docs/ownership) chapter explains borrowing in full.

## Exported functions

A function marked `export` can be imported by other modules. Its parameter types and return type must be written out, because other modules are checked against its signature alone.
