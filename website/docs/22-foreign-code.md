# Unsafe and foreign code

Everything on the other pages is checked by the compiler. Some work cannot be: calling a library written in C, or relying on a promise the types do not express. Pudu keeps that work inside regions marked `unsafe`, and makes each one say which kind of trust it is asking for.

## Unsafe regions

An `unsafe` region names the capabilities it grants:

| Capability | Grants |
| --- | --- |
| `foreign` | calling a function declared in a `foreign` block |
| `raw` | calling functions that work with memory the compiler cannot see |
| `unchecked` | operations that skip a check the caller has already made |
| `null` | the `null` value a foreign library may hand back |

`unsafe(foreign) { ... }` grants only foreign calls. `unsafe { ... }` with no list grants all four, and is best kept for code that really needs them. A region that grants a capability nothing inside it used is reported with a warning, so the marked surface stays as small as the work it covers.

Unsafe does not turn anything else off. Inside a region the compiler still checks types, names, ownership, and initialisation; what it grants is the right to make a call whose contract the compiler cannot prove.

## Unsafe functions

A function can be declared unsafe when calling it correctly depends on something its caller must guarantee. The capability it names is then required at every call:

```pudu
module Contracts

/// Reads the item at `index`. The caller has already checked that the index
/// is in range; this function trusts it.
unsafe(unchecked) fn itemAt(items: &Array[Int], index: Int) -> Int {
  items[index]
}

/// The safe wrapper: it makes the check, so its own callers need no region.
fn itemOr(items: &Array[Int], index: Int, fallback: Int) -> Int {
  if index < 0 || index >= items.length() { return fallback }
  unsafe(unchecked) { itemAt(items, index) }
}

fn main() -> Int {
  let items = [10, 20, 30]
  if itemOr(&items, 1, 0) == 20 && itemOr(&items, 9, -1) == -1 { 0 } else { 1 }
}
```

Calling `itemAt` outside a region, or inside one that does not grant `unchecked`, is error `E3023`, and the message names the missing capability. This is the shape unsafe code should take: a small unsafe function with its contract written beside it, and a safe function around it that upholds the contract, so the rest of the program never sees the region.

## Calling a C library

A `foreign` block declares functions another library provides, with the exact types each argument and result crosses as. The library is named first; `"c"` is the C library every program already has:

```pudu
module Native

foreign "c" version "1" {
  fn strlen(text: Str) -> Int64
  fn absolute symbol "abs" (value: Int32) -> Int32
  fn sqrt(value: Float64) -> Float64
}

fn byteLength(text: Str) -> Int64 {
  unsafe(foreign) { strlen(text) }
}

fn main() -> Int {
  let ok = unsafe(foreign) { absolute(-42i32) == 42i32 && sqrt(144.0) == 12.0 }
  if ok && byteLength("pudu") == 4i64 { 0 } else { 1 }
}
```

- `symbol "abs"` calls the library's `abs` under a Pudu name, when the library's name is unclear or clashes with one of the program's.
- Integer widths are part of the declaration. `Int32` and `Int64` are different functions in C, and the width written is the width that crosses.
- `Str` crosses as UTF-8 text ending in a nought byte, copied for the call. Text coming back that is not valid UTF-8 is refused at the boundary rather than passed on.
- `version "1"` names the library version the declarations were written against.

Every call to a foreign function needs `unsafe(foreign)`, because the declaration is a claim about the library the compiler cannot check: a wrong signature corrupts the program rather than producing a diagnostic.

## Handles a library owns

Many C libraries hand back a pointer to something they made and expect it to be given back to be freed. A `foreign` block declares such a thing as an opaque type, and names the function that releases it:

```text
foreign "imaging" version "2" {
  type Image
  fn open(path: Str) -> owned Image by close
  fn width(image: Image) -> Int32
  fn close(image: Image) -> ()
}
```

`owned Image by close` tells Pudu the result belongs to the program and must be released with `close`. A library that answers `NULL` instead of an image, a use after `close`, and a second `close` are each refused before the next foreign call begins, instead of becoming a crash somewhere later.

A library that writes its result through a pointer the caller provides declares that parameter `out`. The call then answers a tuple: the function's own result first, followed by each value written.

## Where foreign code runs

Foreign calls are refused in the [playground](/playground), which runs programs confined, and in any program run with `pudu run --confined`. They run everywhere else a Pudu program does. C++ libraries are reached through an `extern "C"` surface; C++ names, classes, and exceptions do not cross.
