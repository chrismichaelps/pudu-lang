# Collections

Most programs hold many values at once. Pudu has three built-in collections — arrays, maps, and sets — and the standard library adds more for special shapes of data. This chapter covers the three you will use every day.

| Collection | Holds | Written |
| --- | --- | --- |
| `Array[T]` | values in order, reached by position | `[1, 2, 3]` |
| `Map[K, V]` | values reached by a key, kept in key order | `mapOf([("ada", 36)])` |
| `Set[T]` | distinct values, kept in order | `#{"red", "green"}` |

Collection operations answer new collections rather than changing the old one. Binding the result to a `var` is how a collection grows over time.

## Arrays

An array holds values of one type in order. `items[i]` reads the value at a position, counting from zero:

```pudu
module Arrays

import Std.List as List

fn main() -> Int {
  let primes = [2, 3, 5, 7]
  let first = primes[0]
  let missing = List.get(&primes, 9)
  let longer = primes.push(11)
  let front = longer.slice(0, 2)
  let both = primes.concat([13, 17])
  let ok = first == 2 && missing == None && primes.length() == 4 && longer.length() == 5
  if ok && front == [2, 3] && both.length() == 6 && primes.contains(5) { 0 } else { 1 }
}
```

`push` answered a new array, so `primes` still has four elements. Reading a position that is not there stops the program, whether it is written `items[i]` or `items.get(i)`. When a position might be missing, `List.get(&items, i)` from `Std.List` answers an `Option` instead: `None` for a position past the end.

## Ranges and slices

A range is two ends written with `..`, or `..=` when the last value is included. It is a value: it
can be named, passed to a function, and asked questions. It does not build the numbers it covers, so
a range over millions of values costs the same as a range over three:

```pudu
module Ranges

fn main() -> Int {
  let span = 1..4
  let inclusive = 1..=4

  var total = 0
  for n in 0..1000 {
    total = total + n
  }

  if span.length() == 3
    && inclusive.length() == 4
    && span.contains(2)
    && span.toArray() == [1, 2, 3]
    && span.map(|n| n * n) == [1, 4, 9]
    && span.sum() == 6
    && total == 499500
  {
    0
  } else {
    1
  }
}
```

Indexing with a range reads a stretch rather than one value. Either end may be left off, and the
value being indexed supplies the one that is missing:

```pudu
module Slices

fn main() -> Int {
  let primes = [2, 3, 5, 7, 11]
  let middle = primes[1..3]
  let tail = primes[2..]
  let front = primes[..2]
  let whole = primes[..]
  let upToAndIncluding = primes[1..=3]

  let text = "hello world"
  let greeting = text[0..5]

  if middle == [3, 5]
    && tail == [5, 7, 11]
    && front == [2, 3]
    && whole.length() == 5
    && upToAndIncluding == [3, 5, 7]
    && greeting == "hello"
  {
    0
  } else {
    1
  }
}
```

A slice that reaches past the end stops the program, the same way reading a position that is not
there does. It is not quietly shortened, because a shorter answer would hide the arithmetic that
asked for too much.

## Building an array step by step

A `var` holding an array grows one value at a time:

```pudu
module Building

fn squaresBelow(limit: Int) -> Array[Int] {
  var squares: Array[Int] = []
  var n = 1
  while n * n < limit {
    squares = squares.push(n * n)
    n = n + 1
  }
  squares
}

fn main() -> Int {
  if squaresBelow(30) == [1, 4, 9, 16, 25] { 0 } else { 1 }
}
```

An empty array needs its type written, `Array[Int]`, because there is nothing in it for the compiler to learn the type from.

## Transforming arrays

`map`, `filter`, and `reduce` take a function and apply it across an array:

```pudu
module Transforming

type Order = { item: Str, price: Int, quantity: Int }

fn main() -> Int {
  let orders = [
    Order{item: "tea", price: 4, quantity: 3},
    Order{item: "cake", price: 6, quantity: 1},
    Order{item: "coffee", price: 5, quantity: 2}
  ]
  let totals = orders.map(fn(order: Order) => order.price * order.quantity)
  let large = orders.filter(fn(order: Order) => order.quantity > 1)
  let revenue = totals.reduce(fn(sum: Int, total: Int) => sum + total, 0)
  if totals == [12, 6, 10] && large.length() == 2 && revenue == 28 { 0 } else { 1 }
}
```

## Std.List

[Std.List](/module/Std.List) holds dozens more operations on arrays: sorting, searching, grouping, and combining.

```pudu
module Lists

import Std.List as List
import Std.Option as Option

fn main() -> Int {
  let scores = [72, 95, 88, 61, 95]
  let ranked = List.sorted(&scores)
  let best = Option.unwrapOr(List.maximum(&scores), 0)
  let passing = List.countWhere(&scores, fn(score: Int) => score >= 70)
  let unique = List.distinct(&scores)
  let named = List.zip(&["ada", "grace"], &[95, 88])
  let ok = ranked == [61, 72, 88, 95, 95] && best == 95 && passing == 4
  if ok && unique.length() == 4 && named[1] == ("grace", 88) { 0 } else { 1 }
}
```

| Function | Answers |
| --- | --- |
| `List.sorted(&items)` | the items in ascending order |
| `List.sortOn(&items, key)` | the items ordered by a key drawn from each |
| `List.find(&items, test)` | the first item the test accepts, or `None` |
| `List.fold(&items, combine, start)` | every item combined into one value |
| `List.partition(&items, test)` | the items the test accepts and the ones it rejects |
| `List.range(from, to)` | the whole numbers from `from` up to `to` |

## Maps

A map stores a value under each key. `get` answers an `Option`, because the key may have no entry:

```pudu
module Maps

import Std.Map as Map
import Std.Option as Option

fn main() -> Int {
  let ages = mapOf([("ada", 36), ("grace", 85)])
  let withAlan = ages.insert("alan", 41)
  let adaAge = Option.unwrapOr(withAlan.get("ada"), 0)
  let missing = withAlan.get("linus")
  let withoutGrace = withAlan.remove("grace")
  let names = withAlan.keys()
  let ok = adaAge == 36 && missing == None && withoutGrace.size() == 2
  if ok && names == ["ada", "alan", "grace"] && Map.getOr(&ages, "linus", 0) == 0 { 0 } else { 1 }
}
```

Keys are kept in order, so `keys()` and a `for` loop visit them sorted. A `for` loop over a map walks `(key, value)` pairs:

```pudu
module Counting

import Std.Map as Map
import Std.Option as Option

fn wordCounts(text: Str) -> Map[Str, Int] {
  var counts: Map[Str, Int] = mapOf([])
  for word in text.split(" ") {
    let seen = Option.unwrapOr(counts.get(word), 0)
    counts = counts.insert(word, seen + 1)
  }
  counts
}

fn main() -> Int {
  let counts = wordCounts("the cat saw the other cat")
  var lines: Array[Str] = []
  for (word, count) in counts {
    lines = lines.push("{word}: {count}")
  }
  let same = counts == Map.tally(&"the cat saw the other cat".split(" "))
  if lines[0] == "cat: 2" && lines.length() == 4 && same { 0 } else { 1 }
}
```

## Sets

A set holds each value at most once. `in` asks whether a value is a member:

```pudu
module Sets

fn main() -> Int {
  let warm = #{"red", "orange", "yellow"}
  let flag = #{"red", "white", "blue"}
  let both = warm.intersect(flag)
  let either = warm.union(flag)
  let onlyWarm = warm.difference(flag)
  let grown = warm.insert("red").insert("pink")
  let ok = "red" in both && both.size() == 1 && either.size() == 5
  if ok && onlyWarm.size() == 2 && grown.size() == 4 && !("green" in warm) { 0 } else { 1 }
}
```

## Choosing a collection

- Reach for an **array** when order matters or you will walk every value.
- Reach for a **map** when you look values up by something other than their position.
- Reach for a **set** when all you need to know is whether something is there.

The standard library has more specialised collections when these three do not fit — double-ended queues, priority queues, hash maps, tries, and graphs. The [standard library](/docs/standard-library) chapter maps them out.
