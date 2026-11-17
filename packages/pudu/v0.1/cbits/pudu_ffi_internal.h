#ifndef PUDU_FFI_INTERNAL_H
#define PUDU_FFI_INTERNAL_H

#include <stddef.h>
#include <stdint.h>

#ifdef __APPLE__
#include <ffi/ffi.h>
#else
#include <ffi.h>
#endif

/* The kinds a value may cross as. The codes are shared with the evaluator and
 * must not be reordered: they are written by the side that knows the
 * declaration and read by the side that knows the machine. */
enum pudu_kind {
  PUDU_I8 = 0,
  PUDU_I16 = 1,
  PUDU_I32 = 2,
  PUDU_I64 = 3,
  PUDU_U8 = 4,
  PUDU_U16 = 5,
  PUDU_U32 = 6,
  PUDU_U64 = 7,
  PUDU_F32 = 8,
  PUDU_F64 = 9,
  PUDU_BOOL = 10,
  PUDU_TEXT = 11,
  PUDU_VOID = 12,
  PUDU_HANDLE = 13,
  /* A record crossing by value. Its fields are described separately, because a
   * struct is the one shape whose bytes this side must lay out: where a field
   * sits inside one is the platform's rule, not the caller's, and a caller that
   * guessed would be writing into the wrong offsets on some machine. */
  PUDU_STRUCT = 14,
  /* A run of bytes the library reads. An address like any other here; what
   * makes it different is above, where the storage it names belongs to a value
   * that outlives the call and is not copied to get here. */
  PUDU_BYTES = 15,
  PUDU_POINTER = 16
};

#define PUDU_MAX_ARGUMENTS 32
#define PUDU_MAX_FIELDS 32

struct pudu_layout {
  const uint8_t *next, *end;
  ffi_type *types;
  ffi_type **elements;
  unsigned char *storage[PUDU_MAX_ARGUMENTS + 1];
  size_t *offsets[PUDU_MAX_ARGUMENTS + 1];
};

ffi_type *pudu_ffi_type_for(uint8_t kind);
int pudu_ffi_take_field(const unsigned char *storage, size_t offset, uint8_t kind,
                        int64_t *integer, double *floating);
ffi_type *pudu_ffi_record_type(struct pudu_layout *layout, const uint8_t *kinds,
                               size_t *offsets, size_t count, size_t *leaf);
void *pudu_ffi_swap_scope(void *scope);

#endif
