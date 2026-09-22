# Ownership and references

A Pudu value has one owner, and what may change is written where a reader can see it: `var` on a binding, `mut` on a record field, and `&mut` in a signature and at the call. This page covers how values move, how a function borrows a value to read it or to change it, and what the checker refuses.

## Owned values

Values are owned by default. Assigning a value, or passing it to a function by value, moves it. Numbers, booleans, characters, unit, and shared references are copied instead, because copying them is free and leaves nothing behind.

## let and var

A `let` binding never changes. A `var` binding may be assigned again:

```pudu
module Totals

fn main() -> Int {
  let limit = 3
  var total = 0
  var round = 0
  while round < limit {
    total = total + round
    round = round + 1
  }
  if total == 3 { 0 } else { 1 }
}
```

Assigning to a `let`, a parameter, or a name bound by a pattern is refused with `E3078`. To work with a changing copy of a parameter, bind it again: `var remaining = count`.

## Borrowing with & and &mut

| Type | Meaning |
| --- | --- |
| `&T` | a shared borrow: read the value, do not change it |
| `&mut T` | an exclusive borrow: the one place allowed to change the value |

A borrow is written at the call as well as in the signature, and `*` reads or writes through a reference:

```pudu
module Scores

fn read(score: &Int) -> Int { *score }

fn award(score: &mut Int, points: Int) -> () {
  *score = *score + points
}

fn main() -> Int {
  var score = 40
  award(&mut score, 2)
  if read(&score) == 42 { 0 } else { 1 }
}
```

`award(&mut score, 2)` lends the variable `score` to the call. Whatever `award` stores through its parameter is in `score` when the call returns — whether the function finished normally, left early with `return`, or left through `?`.

There is no implicit conversion between a value and a reference in either direction: a value where a reference is wanted must be borrowed, and a reference where a value is wanted must be dereferenced. A field reached through a reference needs no `*`, so `user.name` works whether `user` is a `User` or a `&User`.

## Records with mut fields

A record field changes only when its type declares it `mut`, and only through a binding that may change: a `var`, or a `&mut` borrow. A method that changes its receiver takes `self: &mut Self`, and is called on a receiver that could itself be assigned:

```pudu
module Counters

type Counter = { mut count: Int, label: Str }

trait Tick {
  fn tick(self: &mut Self) -> ()
}

impl Tick for Counter {
  fn tick(self: &mut Self) -> () {
    self.count = self.count + 1
  }
}

fn main() -> Int {
  var clicks = Counter{count: 0, label: "clicks"}
  clicks.tick()
  clicks.tick()
  clicks.count = clicks.count + 1
  if clicks.count == 3 && clicks.label == "clicks" { 0 } else { 1 }
}
```

`label` is not declared `mut`, so `clicks.label = "taps"` is refused with `E3079`. A whole new value can always be built instead, with `Counter{..clicks, label: "taps"}`.

## Elements of arrays

An element of an array is a place too:

```pudu
module Scaling

fn double(values: &mut Array[Int]) -> () {
  var index = 0
  while index < values.length() {
    values[index] = values[index] * 2
    index = index + 1
  }
}

fn main() -> Int {
  var prices = [10, 20, 30]
  double(&mut prices)
  prices[0] = 1
  if prices[0] == 1 && prices[2] == 60 { 0 } else { 1 }
}
```

The methods on a collection still answer new values: `prices.push(40)` gives a longer array and leaves `prices` as it was, so writing it as a statement on its own does nothing and is reported as a warning. Text, tuples, and maps have no element places; `counts = counts.insert(key, value)` is how a map changes.

## Two borrows of one place

A call may be lent several places, but not the same one twice, and not a place together with something that contains it:

```pudu
module Swaps

type Pair = { mut left: Int, mut right: Int }

fn exchange(first: &mut Int, second: &mut Int) -> () {
  let held = *first
  *first = *second
  *second = held
}

fn main() -> Int {
  var pair = Pair{left: 1, right: 2}
  exchange(&mut pair.left, &mut pair.right)
  if pair.left == 2 && pair.right == 1 { 0 } else { 1 }
}
```

`exchange(&mut pair.left, &mut pair.left)` is refused with `E3082`, and so is lending `&mut pair` beside `&mut pair.left`.

## Where &mut may appear

An exclusive borrow lasts exactly as long as the call it was lent to. So `&mut T` is only ever the type of a parameter, and `&mut place` is only ever written as an argument. It is refused as a function's result, in a binding, in a record field or variant, inside another type such as `Option[&mut Int]`, as a parameter of an `async fn`, and in a closure that captures one. A function that holds a `&mut` parameter may lend it on by name: `award(score, 1)`.

| Code | Refused |
| --- | --- |
| `E3076` | a change to a name a closure captured |
| `E3077` | an assignment to something that is not a place |
| `E3078` | a change to a binding not declared `var` |
| `E3079` | an assignment to a field not declared `mut` |
| `E3080` | a change through a shared reference `&T` |
| `E3081` | `&mut` written anywhere but a call argument |
| `E3082` | two borrows of overlapping places in one call |
| `E3083` | `&mut` in a type position other than a parameter |
| `E3084` | an exclusive borrow kept in a binding, a result, a closure, or another value |

## Closures capture copies

A function literal captures the bindings around it by copying them. Assigning to a captured name would change only the copy, so the language refuses it with `E3076` and asks for the new value to be returned instead:

```pudu
module Capture

fn main() -> Int {
  let base = 10
  let addBase = fn(n: Int) => n + base
  if addBase(32) == 42 { 0 } else { 1 }
}
```

## Resources

Resources such as files, sockets, and database connections are released when their owner is done with them. Where release can fail or must happen at a particular point, the standard library gives an explicit `close` and a scoped form — such as `Io.withReader` — that releases the resource however the work inside it ended. A resource a C library hands back is declared with the function that releases it; see [unsafe and foreign code](/docs/foreign-code).
