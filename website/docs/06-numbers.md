# Numbers

Pudu has whole numbers of every common width, floating-point numbers, exact decimals, and whole numbers of any size. Each is its own type, and no number turns into another without the program saying so.

## Choosing a type

| Type | Use it for | Literal |
| --- | --- | --- |
| `Int` | counting, indexing, most arithmetic | `42` |
| `Int8` … `Int128`, `UInt8` … `UInt128` | a value with a fixed size: a byte, a file offset, a protocol field | `255u8`, `-7i32`, `9000000000i64` |
| `Float64`, `Float32` | measurements, where a tiny rounding error is acceptable | `3.14`, `1.5f32` |
| `Decimal` | money, and anything else a person reads as a written number | `19.99d` |
| `BigInt` | whole numbers that outgrow every fixed width | a whole literal given the type |

A literal with no suffix is an `Int` or a `Float64`. A suffix gives it a width: `u8` through `u128` for unsigned integers, `i8` through `i128` for signed ones, `f32` and `f64` for floats, and `d` for a decimal. Underscores may separate digits: `1_000_000`.

## Arithmetic that cannot go wrong quietly

`+`, `-`, and `*` on a fixed-width integer are checked. A result that does not fit stops the program with a diagnostic naming the type, rather than wrapping around to a small or negative number:

```text
error[E7005]: UInt8 cannot hold the result of this add
   = help: use the wrapping or saturating form, or a wider type; checked arithmetic never truncates quietly
```

When wrapping around or stopping at the limit is what the program means, it says so with an operator of its own:

```pudu
module Arithmetic

fn main() -> Int {
  let level: UInt8 = 250u8
  let wrapped = level &+ 10u8
  let saturated = level +| 10u8
  let floor = 3u8 -| 5u8
  let hashed = 4000000000u32 &* 3u32
  if wrapped == 4u8 && saturated == 255u8 && floor == 0u8 && hashed == 3410065408u32 { 0 } else { 1 }
}
```

| Operation | Checked | Wrapping | Saturating |
| --- | --- | --- | --- |
| add | `+` | `&+` | `+\|` |
| subtract | `-` | `&-` | `-\|` |
| multiply | `*` | `&*` | `*\|` |

Division and remainder by nought have no answer at all, so [Std.Math](/module/Std.Math) offers `Math.divide` and `Math.remainder`, which answer an `Option`.

## Moving between widths

Two numbers of different types never meet in one operation: `1u8 + 1i32` is refused where it is written. Moving a value to another width goes through `BigInt`, which holds any whole number. Widening is always exact; narrowing answers an `Option`, because the value may not fit:

```pudu
module Widths

import Std.Num {Integer}

fn main() -> Int {
  let reading = 300
  let wide = reading.toBigInt()
  let asByte = 0u8.fromBigInt(wide)
  let asShort = 0i16.fromBigInt(wide)
  if asByte == None && asShort == Some(300i16) { 0 } else { 1 }
}
```

The receiver of `fromBigInt` only names the type wanted — `0u8` asks for a `UInt8` — so generic code can keep its caller's type.

## Exact decimals

A `Float64` stores a binary fraction, so `0.1 + 0.2` is not quite `0.3`. A `Decimal` stores the digits that were written, so sums of prices come out exact. [Std.Decimal](/module/Std.Decimal) rounds with a named rule, because every rule decides the halfway case differently:

```pudu
module Prices

import Std.Decimal as D

fn main() -> Int {
  let items = [19.99d, 5.01d, 0.10d]
  let subtotal = D.sum(items)
  let tax = D.round(subtotal * 0.0825d, 2, D.HalfEven)
  let total = subtotal + tax
  let exact = 0.1d + 0.2d == 0.3d
  if exact && subtotal == 25.10d && tax == 2.07d && D.toText(total) == "27.17" { 0 } else { 1 }
}
```

Division is the one operation that may not terminate in base ten. `D.divide(value, divisor, digits, rule)` says how many digits to keep and how to round the last one, and answers `None` only for a divisor of nought.

## Whole numbers of any size

A `BigInt` grows as it needs to. It is what a program reaches for when a factorial, a checksum, or a counter will not fit in 128 bits:

```pudu
module Factorials

import Std.Io as Io

fn factorial(n: BigInt) -> BigInt {
  var product: BigInt = 1
  var step: BigInt = 2
  while step <= n {
    product = product * step
    step = step + 1
  }
  product
}

fn main() -> Int {
  let big = factorial(30)
  let _written = Io.writeLine("30! = {big}")
  if "{big}" == "265252859812191058636308480000000" { 0 } else { 1 }
}
```

## Numeric helpers

| Module | Provides |
| --- | --- |
| [Std.Math](/module/Std.Math) | `min`, `max`, `clamp`, `abs`, `pow`, `gcd`, `isPrime`, and division that answers an `Option` |
| [Std.Math.Float](/module/Std.Math.Float) | `sqrt`, `floor`, `round`, trigonometry, logarithms, and the constants `pi()` and `e()` |
| [Std.Decimal](/module/Std.Decimal) | rounding rules, exact division, parsing, and formatting decimals |
| [Std.Num](/module/Std.Num) | the traits generic numeric code asks for, and conversion through `BigInt` |
| [Std.Bits](/module/Std.Bits) | bitwise operations, shifts, and counting bits |
| [Std.Random](/module/Std.Random) | seeded and clock-driven random numbers |
