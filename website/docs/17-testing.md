# Testing

Tests in Pudu are ordinary programs. A test module builds a suite of checks with `Std.Test`, runs it, and reports; `pudu test` finds those modules and runs them. There is no separate test language to learn.

## A first test

```pudu
module PriceTest

import Std.Test as Test

fn withTax(price: Int, percent: Int) -> Int = price + price * percent / 100

export fn main() -> Int {
  let suite = Test.suite("prices", &[
      Test.equals("adds the tax", &withTax(200, 10), &220),
      Test.equals("no tax changes nothing", &withTax(200, 0), &200),
      Test.that("tax never lowers a price", withTax(50, 5) >= 50)
    ])
  Test.report(&Test.run(&suite))
}
```

Run it with `pudu test PriceTest.pudu`, or run every test under a directory with `pudu test test`. The report counts the checks that held, and a failing check prints its name with what it expected and what it found. `Test.report` answers the program's exit status, which is `0` only when every check held.

## Kinds of check

| Check | Holds when |
| --- | --- |
| `Test.that(name, condition)` | the condition is true |
| `Test.not(name, condition)` | the condition is false |
| `Test.equals(name, &actual, &expected)` | the two values are equal |
| `Test.differs(name, &left, &right)` | the two values differ |
| `Test.contains(name, &items, value)` | an array contains the value |
| `Test.sameElements(name, &left, &right)` | two arrays hold the same values in any order |
| `Test.succeeded(name, &result)` | a `Result` is `Ok` |
| `Test.errored(name, &result)` | a `Result` is `Err` |
| `Test.present(name, &option)` | an `Option` is `Some` |
| `Test.absent(name, &option)` | an `Option` is `None` |
| `Test.todo(name, reason)` | never: it marks a check still to be written |

Prefer `equals` to `that(name, a == b)`: when it fails, it shows both values rather than only `false`.

## Testing failure

Code that returns a `Result` is tested on both paths:

```pudu
module ParseTest

import Std.Test as Test
import Std.Text as Text

fn parseAge(text: Str) -> Result[Int, Str] {
  match Text.wholeOf(text.trim()) {
    case Some(age) if age >= 0 && age < 150 => Ok(age)
    case Some(_) => Err("out of range")
    case None => Err("not a number")
  }
}

export fn main() -> Int {
  let suite = Test.suite("ages", &[
      Test.equals("reads a number", &parseAge(" 36 "), &Ok(36)),
      Test.errored("refuses text", &parseAge("thirty")),
      Test.equals("says why", &parseAge("400"), &Err("out of range"))
    ])
  Test.report(&Test.run(&suite))
}
```

## Tables of cases

When one check applies to many inputs, write the inputs as data. `Test.each` builds one check per case, named from the case:

```pudu
module LeapTest

import Std.Test as Test

fn isLeap(year: Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

export fn main() -> Int {
  let leap = [1996, 2000, 2024]
  let common = [1900, 2023, 2100]
  let leapChecks = Test.each(&leap, fn(year: Int) => "{year} is leap", isLeap)
  let commonChecks = Test.each(&common, fn(year: Int) => "{year} is not leap", fn(year: Int) => !isLeap(year))
  let suite = Test.suite("leap years", &leapChecks.concat(commonChecks))
  Test.report(&Test.run(&suite))
}
```

## Groups

Suites nest. A group gathers suites under a name, and the report counts through every level:

```pudu
module ShopTest

import Std.Test as Test

fn discount(total: Int) -> Int = if total >= 100 { total / 10 } else { 0 }

export fn main() -> Int {
  let small = Test.suite("small orders", &[Test.equals("no discount", &discount(99), &0)])
  let large = Test.suite("large orders", &[
      Test.equals("ten percent", &discount(100), &10),
      Test.equals("scales", &discount(250), &25)
    ])
  let everything = Test.group("shop", &[small, large])
  Test.report(&Test.run(&everything))
}
```

## Property checks

A property check states something that should hold for every input, and tries it on many generated ones. When it finds an input that breaks the property, it looks for a simpler one before reporting:

```pudu
module PropertyTest

import Std.Test as Test
import Std.Test.Property as Property

fn reverse(items: Array[Int]) -> Array[Int] {
  var reversed: Array[Int] = []
  for item in items {
    reversed = [item].concat(reversed)
  }
  reversed
}

export fn main() -> Int {
  let suite = Test.suite("properties", &[
      Property.forAllInts("doubling is adding a number to itself", 42u64, 200, 1000, fn(n: Int) => n * 2 == n + n),
      Property.forAllInts("absolute values are never negative", 7u64, 200, 1000, fn(n: Int) => (if n < 0 { -n } else { n }) >= 0),
      Test.equals("reversing twice gives the original", &reverse(reverse([1, 2, 3])), &[1, 2, 3])
    ])
  Test.report(&Test.run(&suite))
}
```

`forAllInts` takes a name, a seed so a failure can be reproduced exactly, how many values to try, and the bound the values stay below.

## Where tests live

`pudu init` puts tests under `test/`, mirroring the modules they test: `src/App/Greeting.pudu` is tested by `test/App/GreetingTest.pudu`. `pudu test` with no path runs everything under `test/`.

Keep most logic in modules that take values and return values, and most tests there too. Code that reads files or the network is tested best by passing it the data it would have read, rather than by reaching the outside world from a test.
