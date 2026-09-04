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
                  void *const *pointers, uint8_t result_kind,
                  int64_t *result_integer, double *result_double);
```

### Governance

- Kind codes are an ABI shared with Haskell and never reordered. Opaque handles use pointer ABI
  storage while travelling through the integer carrier only inside the bridge.
- libffi, not handwritten register placement, applies the platform calling convention.
- The bridge allocates or frees no foreign handle. It only carries an address the library owns.
- Invalid kinds, arity, or signature preparation return a bounded status code before calling the
  symbol.

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

## Referenced by

[[src/cbits/_MOC]] · [[Foreign Call]] · [[ADR-0018 Calling a Library Written Elsewhere]]
