---
type: module
path: "@root/test/swift-counter.mjs"
fidelity: Active
tags: [module, test, native, swift, foreign]
aliases: [Swift Counter Fixture]
---

# Swift Counter Fixture

`test/swift-counter.mjs` is the shared fixture for the Swift entry point checks. It holds a
Swift library and the Pudu program that calls it. The fixture has no run mode of its own; the
[[Swift Entry Points Test]] and [[iOS Foreign Apps Test]] scripts import it.

## Purpose and interface

- The Swift source defines a `Counter` class exposed through C entry points declared with
  `@_cdecl`:
  - `swift_counter_new` creates a counter and returns an owned handle. It uses
    `Unmanaged.passRetained`, so the caller holds one retain.
  - `swift_counter_release` drops that retain. It is the declared release for the handle.
  - `swift_counter_add` adds to the counter.
  - `swift_counter_each` takes a C function pointer and a context pointer. The callback is
    marked `@convention(c)` and receives the context back on each call.
  - `swift_greeting_length` takes text as input and returns its length.
- `swiftProgram(library, prefix, releases)` returns the Pudu source. It declares the entry
  points in a `foreign` block against the given library, using the given symbol prefix. The
  `releases` argument selects which handles the program releases, so the same fixture can be
  reused for the refused double release.
- The program prints `4`, `14` and `11`, in that order, when run.

## Algorithm and invariants

- Each handle crosses as an opaque foreign value. Pudu calls `swift_counter_release` once for
  every handle it obtained from `swift_counter_new`.
- The callback never outlives the call that supplied its context. The context is a pointer
  owned by the caller for the duration of `swift_counter_each`.
- The library is compiled without the Swift runtime symbols being named by Pudu. Pudu sees only
  the C names.

## Dependencies and consumers

[[Foreign Ownership]], [[Foreign Callback Signature]]. Consumers: [[Swift Entry Points Test]],
[[iOS Foreign Apps Test]].

## Resolved Grill Log

- **Q:** Why return an owned handle rather than a borrowed one? **A:** A borrowed handle has no
  point at which Pudu must release it, so the release path would go untested. The owned form
  makes the release call observable and refusable.
- **Q:** Why a `@convention(c)` callback with a context pointer? **A:** A Swift closure cannot
  cross as a C function pointer. The context carries the state the closure would have captured.

## Referenced by

[[Swift Entry Points Test]] · [[iOS Foreign Apps Test]] · [[iOS Simulator Run]]
