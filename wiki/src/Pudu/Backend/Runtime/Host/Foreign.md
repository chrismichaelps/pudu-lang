---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Foreign.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Foreign]
---
# Native Host Foreign

The dynamic loader behind native foreign calls (#850). `pudu_foreign_function`
resolves a declaration's function on its first call, under one lock, into the
wrapper's cache. A library opens with the interpreter's candidates in its
order: the written name, the versioned spellings when a version is written,
then the plain spellings; `c` opens the program itself. A library that does not
open or a symbol it does not export stops the program with E7015 in the
interpreter's words.

## Governance

- The loader itself does not allocate scratch storage: names and messages are built in bounded stack buffers,
  so the counted harness sees no allocation of its own.
- The loader's own reason is never appended. The interpreter reads it after the
  loader has already handed it to an inner attempt, so its message carries none.
- The loader holds a reference to `pow`, so a linker that drops unused libraries
  keeps the math library, and `c` reaches the math functions as the interpreter's
  process does (Linux CI found `pow` and `sqrt` missing without it).
- `foreignLoaderMarker` tells [[Backend Toolchain]] to link the dynamic loader
  where the platform keeps it apart from the C library.

## Text and bytes (#851)

`host_foreign_text_in` validates and copies arguments, refusing embedded noughts (E7017). `host_foreign_text_out` supplies result validation and depends on the runtime text-copy helper. Result wrappers refuse missing text (E7024) and invalid UTF-8 (E7025). `host_foreign_bytes` lends a run's storage, an empty run still passing an address as the interpreter's bridge does.

## Record text fields (#852)

`pudu_foreign_missing_field` reports E7024 with the missing field name. Wrappers validate every raw text leaf before allocating field copies.

## Handle claims (#853)

The native run gate serializes calls through liveness checking, dispatch and
claim settlement. Each owned address has one live claim. Counted results can
share an address and each gets a distinct generation. Borrowed handles have
no claim. Explicit release removes the exact live generation. Teardown
drains owned claims by signed address, then counted claims by generation.

## Resolved Grill Log

- Resolve each destructor before the producing call, and cache its typed
  pointer so cleanup cannot fail to resolve it.
- Select argument and result text helpers independently for scalar crossings. A
  call that only takes text needs no result copy. Record pack and unpack
  helpers still select both directions when a record contains text.
- The run gate covers the whole call. Keep a separate lease table deferred
  until dispatch can release the gate or support callbacks.

## Referenced by

[[Native Host Runtime]] · [[Backend Emit Foreign]]

## Owned output slots (#854)

Resolved Grill Log: Reserve batch claim space before dispatch. Reject duplicate or existing addresses before exposing any new boxes. Release each unambiguous fresh obligation on refusal.
