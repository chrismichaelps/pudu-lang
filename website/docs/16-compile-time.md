# Compile time and macros

Some work is better done once, when the program is compiled, than every time it runs. Pudu has two tools for that: compile-time functions, which compute values, and macros, which write code.

## Compile-time functions

A function declared `comptime fn` can be run by the compiler. A constant whose value calls one is computed during compilation, so the running program starts with the answer already in place:

```pudu
module Tables

import Std.Io as Io

comptime fn powerOfTwo(exponent: Int) -> Int {
  var value = 1
  for _ in 0..exponent {
    value = value * 2
  }
  value
}

comptime fn squares(count: Int) -> Array[Int] {
  var found: Array[Int] = []
  for n in 0..count {
    found = found.push(n * n)
  }
  found
}

const BUFFER_SIZE: Int = powerOfTwo(12)
const SQUARES: Array[Int] = squares(6)

fn main() -> Int {
  let _written = Io.writeLine("buffer {BUFFER_SIZE}, squares {SQUARES}")
  if BUFFER_SIZE == 4096 && SQUARES[5] == 25 { 0 } else { 1 }
}
```

A compile-time function is still an ordinary function: `main` may call `powerOfTwo(3)` at run time too. What `comptime` adds is a promise the compiler checks — the function does only work that gives the same answer on every machine, every time.

## What compile-time code may do

Compile-time code computes with numbers, text, booleans, collections, and the program's own types. It may call other `comptime` functions and functions handed to it as values. It may not read files, write output, look at the clock or the environment, draw random numbers, start tasks, or open an `unsafe` region, because none of those give the same answer twice:

```text
error[E3025]: comptime function cannot call Io.writeLine
   = help: declare the callee comptime, or move the call out of compile-time code
```

Compile-time evaluation also runs under a budget of steps, recursion depth, and memory. A function that never finishes is stopped and reported where it ran past the limit, rather than hanging the compiler.

## Macros

A macro writes code where it is called. Its parameters say what kind of syntax each argument is — an expression, a name, or a block — and its body is ordinary Pudu written in terms of them. A call is spelled with `!`, so a reader can always tell that code is being written for them:

```pudu
module Macros

import Std.Io as Io

macro twice(value: expr) = value + value

macro squared(value: expr) = {
  let held = value
  held * held
}

macro swap(left: ident, right: ident) = {
  let held = left
  left = right
  right = held
}

macro announced(body: block) = {
  let _written = Io.writeLine("starting")
  body
}

fn main() -> Int {
  let held = "mine"
  var first = 3
  var second = 4
  swap!(first, second)
  let sum = announced!({ first + second })
  let _written = Io.writeLine("{twice!(21)} {squared!(1 + 2)} {first} {second} {held}")
  if twice!(21) == 42 && squared!(1 + 2) == 9 && first == 4 && sum == 7 && held == "mine" { 0 } else { 1 }
}
```

| Parameter kind | Accepts | Example argument |
| --- | --- | --- |
| `expr` | any expression | `1 + 2`, `items.length()` |
| `ident` | one name | `first` |
| `block` | a braced block | `{ first + second }` |

An argument of the wrong kind is reported at the call. A macro takes exactly the arguments it declares.

## Macros are hygienic

`squared!(1 + 2)` is `9`, not `1 + 2 * 1 + 2`: an `expr` argument is substituted as one expression, so operator precedence never changes what it means. The argument is also evaluated once, because the body binds it to `held` before using it twice.

The names a macro introduces belong to the macro. `swap!` and `squared!` both declare `held`, and so does `main`; each is renamed at every expansion, so a macro can neither overwrite a caller's variable nor pick one up by accident. That is why `held` in `main` is still `"mine"` at the end.

Macros are expanded before names are resolved and types are checked, so the code a macro writes is checked exactly as if it had been typed out by hand. A macro that expands into itself forever is stopped by a depth limit and reported where the expansion began.

## Choosing between them

Reach for a `comptime fn` when the thing being made is a value: a lookup table, a size, a parsed constant. Reach for a macro when the thing being made is code: a pattern of statements repeated around different expressions. Most programs need neither; an ordinary function is the first tool, and both of these are for when it is not enough.
