---
type: module
path: "@root/cbits/pudu_ffi.c"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "C11"
depth_score: 0.7
depth_status: DEEP
coupling: 1.0
interface_stability: 0.7
tags: [module, deep, foreign, ffi, c]
aliases: [Pudu FFI Bridge]
---

# Pudu FFI Bridge

## Purpose

Open native libraries and invoke symbols through libffi using the crossing kind codes shared with
[[Foreign Call]].

## Interface

```c
void *pudu_ffi_open(const char *path);
void *pudu_ffi_symbol(void *handle, const char *name);
const char *pudu_ffi_error(void);
int pudu_ffi_call(void *symbol, int32_t arity, const uint8_t *kinds,
                  const int64_t *integers, const double *doubles,
                  void *const *pointers, const int32_t *field_starts,
                  const int32_t *field_counts, const uint8_t *field_kinds,
                  const int64_t *field_integers, const double *field_doubles,
                  void *const *field_pointers, const uint8_t *slot_kinds,
                  int64_t *slot_integers, double *slot_doubles,
                  int64_t *slot_field_integers, double *slot_field_doubles,
                  uint8_t result_kind,
                  int32_t result_field_count, const uint8_t *result_field_kinds,
                  int64_t *result_integer, double *result_double,
                  int64_t *result_field_integers, double *result_field_doubles);
```

### Governance

- Kind codes are an ABI shared with Haskell and never reordered. Opaque handles use pointer ABI
  storage while travelling through the integer carrier only inside the bridge.
- libffi, not handwritten register placement, applies the platform calling convention.
- The bridge allocates or frees no foreign handle. It only carries an address the library owns.
- Invalid kinds, arity, or signature preparation return a bounded status code before calling the
  symbol.
- Text pointers in direct and record arguments borrow UTF-8 storage owned by the Haskell call frame.
  Integer slots are bit carriers; signedness is recovered above the bridge from the kind code.
- The fixed 32-argument and 32-field capacities are mirrored as checker limits, so these guards are
  defence in depth rather than reachable behavior for a checked declaration.
- An argument named by `slot_kinds` is written by the library rather than read from the caller: the
  bridge owns the storage for the call, passes its address, and reads back what was left there. A
  null `slot_kinds` is a call with no slots. Storage is zeroed first, so an unwritten pointer reads
  back null while an unwritten scalar reads back zero — which is a value, not an absence, and the
  distinction belongs to the declaration under [[ADR-0019 Getting a Value Back Out of a Library]].
- Storage the bridge lays out itself carries the alignment its widest member requires, because a
  record's fields are read by the platform at the platform's own offsets.

### Linkage

- **Requires:** system dynamic loader and libffi.
- **Used by:** [[Foreign Call]].

## Grill Log

- **Q:** Cast and call a small set of function-pointer signatures directly? **A:** No. _Rationale:_
  integer and floating arguments occupy different ABI classes, and enumerating combinations leaves
  the unlisted shape to fail by corrupting a call frame. _Rejected:_ handwritten signature tables.
- **Q:** Free a returned pointer here? **A:** No. _Rationale:_ only the declaration names the
  matching release function, and this bridge deliberately knows nothing about library ownership.
  _Rejected:_ `free` for every returned address.
- **Q:** Reuse the integer field array for text pointers? **A:** No. _Rationale:_ a text field needs
  scoped encoded storage, while an integer is only bits; conflating them admitted text records and
  then wrote a null pointer. _Rejected:_ implicit pointer packing in the integer carrier.
- **Q:** Lay out a record in an array of bytes? **A:** No. _Rationale:_ such an array promises an
  alignment of one, while the platform reads an eight-byte field at an address it considers valid
  for eight; it held only because the compiler happened to place it well. _Rejected:_ storage whose
  correctness is the allocator's accident.
- **Q:** Tell a written zero from an unwritten scalar slot? **A:** No. _Rationale:_ both leave the
  same bytes, and no portable observation separates them. _Rejected:_ manufacturing absence from a
  byte pattern.

## Referenced by

[[src/cbits/_MOC]] · [[Foreign Call]] · [[ADR-0018 Calling a Library Written Elsewhere]] · [[ADR-0019 Getting a Value Back Out of a Library]]

## Bundled native modules

The exact name `pudu_sqlite` opens a reserved bridge handle. Symbol lookup on that handle delegates only to [[Pudu SQLite Bridge]]; other libraries retain ordinary loader behavior.

### Resolved Grill Log
- **Q:** Depend on executable symbol export flags for bundled adapters? **A:** No; resolve the reserved module through a fixed symbol table.
