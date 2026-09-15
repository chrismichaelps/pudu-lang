# Ownership and references

A Pudu value has one owner. Borrowing it is written in the type, so a signature says whether a function only reads what it is given or may change it.

## Owned values

Values are owned by default. Assigning a value, or passing it to a function by value, moves it. Numbers, booleans, characters, unit, and shared references are copied instead, because copying them is free and leaves nothing behind.

## Borrowing with & and &mut

| Type | Meaning |
| --- | --- |
| `&T` | a shared borrow: read the value, do not change it |
| `&mut T` | an exclusive borrow: the one place allowed to change the value |

A borrow is written at the call as well as in the signature, and `*` reads through a reference:

```pudu
module Scores

fn read(score: &Int) -> Int { *score }

fn next(score: &Int) -> Int { *score + 1 }

fn main() -> Int {
  var score = 41
  score = next(&score)
  if read(&score) == 42 { 0 } else { 1 }
}
```

> The current implementation passes a borrowed value as a copy, and only a variable can be assigned. Assigning through a reference (`*score = value`), to a field (`tally.count = 2`), or to an element (`items[0] = 5`) is refused by `pudu check` with `E3077`. Until those are implemented, a function that changes a value returns the new value and the caller assigns it, as `next` does above; a record is changed by building a new one, `tally = Tally{..tally, count: 2}`.

There is no implicit conversion between a value and a reference in either direction: a value where a reference is wanted must be borrowed, and a reference where a value is wanted must be dereferenced. A field reached through a reference needs no `*`, so `user.name` works whether `user` is a `User` or a `&User`.

## What may change

A binding changes only when something says it may:

- a `var` binding, assigned with `=`,
- a record field declared `mut`, once assigning to a field is implemented,
- or the value behind an `&mut` borrow, once assigning through a reference is implemented.

Collections never change in place. `numbers.push(4)` answers a new array and leaves `numbers` as it was, so writing it as a statement on its own does nothing and is reported as a warning.

## Closures capture copies

A function literal captures the bindings around it by copying them. Assigning to a captured name would change only the copy, so the language refuses it and asks for the new value to be returned instead:

```pudu
module Capture

fn main() -> Int {
  let base = 10
  let addBase = fn(n: Int) => n + base
  if addBase(32) == 42 { 0 } else { 1 }
}
```

## Resources

Resources such as files, sockets, and database connections are released when their owner is done with them. Where release can fail or must happen at a particular point, the standard library gives an explicit `close` and a scoped form — such as `Io.withReader` — that releases the resource however the work inside it ended.
