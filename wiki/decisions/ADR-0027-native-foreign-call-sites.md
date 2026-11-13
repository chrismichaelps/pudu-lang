---
type: decision
status: Accepted design; implementation in progress (#850)
date: 2026-11-12
tags: [decision, native, foreign, backend]
aliases: [Native Foreign Call Sites]
---
# ADR-0027 — Native foreign calls are typed call sites

## Context and decision

The interpreter calls a foreign function through a general bridge: it learns a
declaration's signature while the program runs, so it describes each call to
libffi and lets libffi build the frame ([[ADR-0018-calling-a-library-written-elsewhere]]).
Generated C knows every declaration's signature when it is written. A native
program therefore calls each foreign function through a pointer of its exact C
type, declared once per declaration, and carries no call-description library.

Resolution is the interpreter's own. The library opens on first use with the
same candidates in the same order: the written name, its versioned spellings,
then the plain spellings; the name `c` opens the program itself. The symbol is
the declaration's `symbol`, else its name. Each library and each symbol is
resolved once per program and kept. A library that does not open, or a symbol
it does not export, stops the program with E7015 at the call, in the
interpreter's words and with its help.

Crossing types keep the interpreter's C types: `Int8`..`Int64` and
`UInt8`..`UInt64` as the fixed-width integers, `Float32` as `float`, `Float64`
as `double`, `Bool` as an unsigned byte (nonzero answers true) and `()` as
`void`. Text, bytes, records, handles and slots follow in their own slices
(#851–#854) under the same rule.

## Rejected

- Linking libffi into native programs. _Rationale:_ it re-derives at run time
  what the generated C already states, and adds a dependency every native
  program would carry.
- Linking each library at build time (`-l`). _Rationale:_ the interpreter opens
  a library when a call first needs it, so a program whose foreign call is
  never reached runs without the library; build-time linking would refuse it
  and change which failure a missing library produces.

## Consequences

A native program that makes a foreign call needs the platform's dynamic
loader (`dlopen`, `dlsym`), linked where the platform keeps it apart from the C
library. Version text selects candidate file names and is not otherwise
checked, as in the interpreter.

## Text and bytes (#851)

`Str` crosses as a nought-terminated UTF-8 copy for the call and comes back copied out of storage the library keeps; `Bytes` cross as the lent address of their storage, the length an ordinary parameter ([[ADR-0020-handing-a-library-a-run-of-bytes]]).

## Records (#852)

A record crosses as a C struct declared from the record, nested records as nested structs, so its layout is the platform's own. The interpreter's bridge flattens nested records, which differs only where an inner record ends in padding (#863).

## Referenced by

[[decisions/_MOC]] · [[Native Emission Coverage]]
