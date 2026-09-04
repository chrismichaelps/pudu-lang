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
extern "C" int32_t pudu_ffi_cpp_active_count(void);
extern "C" int32_t pudu_ffi_cpp_anchor(void);
extern "C" Tint pudu_ffi_cpp_tint_make(int32_t base);
extern "C" int32_t pudu_ffi_cpp_tint_sum(Tint tint);
extern "C" Span pudu_ffi_cpp_span_make(double start, int32_t count);
extern "C" double pudu_ffi_cpp_span_end(Span span);
extern "C" const char *pudu_ffi_cpp_text_static(int32_t which);
extern "C" const char *pudu_ffi_cpp_text_none(void);
extern "C" int8_t pudu_ffi_cpp_i8(int8_t value);
extern "C" int16_t pudu_ffi_cpp_i16(int16_t value);
extern "C" int32_t pudu_ffi_cpp_i32(int32_t value);
extern "C" int64_t pudu_ffi_cpp_i64(int64_t value);
extern "C" uint8_t pudu_ffi_cpp_u8(uint8_t value);
extern "C" uint16_t pudu_ffi_cpp_u16(uint16_t value);
extern "C" uint32_t pudu_ffi_cpp_u32(uint32_t value);
extern "C" uint64_t pudu_ffi_cpp_u64(uint64_t value);
extern "C" float pudu_ffi_cpp_f32(float value);
extern "C" double pudu_ffi_cpp_f64(double value);
extern "C" bool pudu_ffi_cpp_bool(bool value);
extern "C" void pudu_ffi_cpp_void(void);
extern "C" Labelled pudu_ffi_cpp_labelled(const char *label, uint64_t count);
extern "C" uint64_t pudu_ffi_cpp_labelled_measure(Labelled value);
extern "C" Labelled pudu_ffi_cpp_labelled_none(void);
extern "C" const char *pudu_ffi_cpp_invalid_utf8(void);
```

### Governance

- The C++ object layout never crosses. Pudu receives only an opaque address.
- Every callable symbol has C linkage. Mangled methods, templates, RTTI, and exceptions remain on
  the C++ side.
- The deletion counter is test evidence that a refused second release did not enter foreign code.
- The shared address proves a second simultaneous ownership claim is refused before it becomes a
  second handle value.
- Allocation uses nothrow form so no C++ exception can cross the boundary.
- Scalar identity and flat text-record symbols exercise the exact C ABI classes at their extrema;
  malformed returned bytes exist only to prove that invalid UTF-8 becomes a Pudu runtime diagnostic.

## Grill Log

- **Q:** Export the class and call its methods directly? **A:** No. _Rationale:_ names, layout, and
  exception ABI are compiler-specific and cannot be asserted portably. _Rejected:_ mangled symbol
  lookup and object-layout declarations.
- **Q:** Put this fixture in the production library? **A:** No. _Rationale:_ it exists only as
  conformance evidence and is compiled into the test suite. _Rejected:_ shipping probe symbols.
- **Q:** Test only ordinary middle-of-range values? **A:** No. _Rationale:_ signed storage appears to
  work for unsigned values until bit 63 is set, which is precisely where a silent decode bug lived.
  _Rejected:_ representative values without both extrema.

## Referenced by

[[src/cbits/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]]
