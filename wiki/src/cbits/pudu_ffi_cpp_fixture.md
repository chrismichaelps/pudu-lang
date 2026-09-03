---
type: module
path: "@root/cbits/pudu_ffi_cpp_fixture.cpp"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "C++11"
depth_score: 0.3
depth_status: LOW
coupling: 1.0
interface_stability: 0.0
tags: [module, low, test, foreign, ffi, cpp]
aliases: [Pudu FFI C++ Fixture]
---

# Pudu FFI C++ Fixture

## Purpose

Provide a test-only C++ resource with an explicit C-compatible surface, proving the supported C++
interop path without pretending Pudu can call a compiler-specific C++ ABI.

## Interface

```cpp
extern "C" void *pudu_ffi_cpp_box_new(int32_t value);
extern "C" int32_t pudu_ffi_cpp_box_read(void *box);
extern "C" void pudu_ffi_cpp_box_delete(void *box);
extern "C" void *pudu_ffi_cpp_box_null(void);
extern "C" void *pudu_ffi_cpp_box_shared(void);
extern "C" void pudu_ffi_cpp_box_shared_release(void *box);
extern "C" int32_t pudu_ffi_cpp_delete_count(void);
extern "C" int32_t pudu_ffi_cpp_anchor(void);
```

### Governance

- The C++ object layout never crosses. Pudu receives only an opaque address.
- Every callable symbol has C linkage. Mangled methods, templates, RTTI, and exceptions remain on
  the C++ side.
- The deletion counter is test evidence that a refused second release did not enter foreign code.
- The shared address proves a second simultaneous ownership claim is refused before it becomes a
  second handle value.
- Allocation uses nothrow form so no C++ exception can cross the boundary.

## Grill Log

- **Q:** Export the class and call its methods directly? **A:** No. _Rationale:_ names, layout, and
  exception ABI are compiler-specific and cannot be asserted portably. _Rejected:_ mangled symbol
  lookup and object-layout declarations.
- **Q:** Put this fixture in the production library? **A:** No. _Rationale:_ it exists only as
  conformance evidence and is compiled into the test suite. _Rejected:_ shipping probe symbols.

## Referenced by

[[src/cbits/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]]
