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

- Nothing is allocated: names and messages are built in bounded stack buffers,
  so the counted harness sees no allocation of its own.
- The loader's own reason is never appended. The interpreter reads it after the
  loader has already handed it to an inner attempt, so its message carries none.
- The loader holds a reference to `pow`, so a linker that drops unused libraries
  keeps the math library, and `c` reaches the math functions as the interpreter's
  process does (Linux CI found `pow` and `sqrt` missing without it).
- `foreignLoaderMarker` tells [[Backend Toolchain]] to link the dynamic loader
  where the platform keeps it apart from the C library.

## Text and bytes (#851)

`host_foreign_text` copies a text argument with a closing nought, refusing text that holds one (E7017), and copies a text result out of storage the library keeps, refusing none (E7024) and bytes that are not UTF-8 (E7025). `host_foreign_bytes` lends a run's storage, an empty run still passing an address as the interpreter's bridge does.

## Record text fields (#852)

`pudu_foreign_text_field` copies a record result's text field out, a missing one stopping with E7024 naming the field as the interpreter does.

## Referenced by

[[Native Host Runtime]] · [[Backend Emit Foreign]]
