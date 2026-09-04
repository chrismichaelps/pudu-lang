/* Calling a library written elsewhere.
 *
 * The whole of the unsafety lives here, in one file, behind three functions:
 * open a library, find a symbol in it, call through a signature assembled at
 * run time. Everything above this decides what is allowed to cross; this only
 * carries it. */

#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

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
  PUDU_STRUCT = 14
};

#define PUDU_MAX_ARGUMENTS 32
#define PUDU_MAX_FIELDS 32

/* One argument's fields, when the argument is a record.
 *
 * Deliberately one level deep. Every colour, point, and rectangle a library
 * hands about is a flat record of scalars, and admitting nesting would mean a
 * recursive description crossing this boundary for a case that is rare and
 * whose failure is silent. A nested record is refused where it is declared. */
struct pudu_fields {
  int32_t start;
  int32_t count;
};

void *pudu_ffi_open(const char *path) { return dlopen(path, RTLD_LAZY | RTLD_LOCAL); }

void *pudu_ffi_symbol(void *handle, const char *name) { return dlsym(handle, name); }

const char *pudu_ffi_error(void) { return dlerror(); }

static ffi_type *type_for(uint8_t kind) {
  switch (kind) {
  case PUDU_I8:
    return &ffi_type_sint8;
  case PUDU_I16:
    return &ffi_type_sint16;
  case PUDU_I32:
    return &ffi_type_sint32;
  case PUDU_I64:
    return &ffi_type_sint64;
  case PUDU_U8:
    return &ffi_type_uint8;
  case PUDU_U16:
    return &ffi_type_uint16;
  case PUDU_U32:
    return &ffi_type_uint32;
  case PUDU_U64:
    return &ffi_type_uint64;
  case PUDU_F32:
    return &ffi_type_float;
  case PUDU_F64:
    return &ffi_type_double;
  case PUDU_BOOL:
    return &ffi_type_uint8;
  case PUDU_TEXT:
  case PUDU_HANDLE:
    return &ffi_type_pointer;
  case PUDU_VOID:
    return &ffi_type_void;
  default:
    return NULL;
  }
}

/* One argument's storage, wide enough for any kind that crosses. The union is
 * what libffi is handed a pointer into, so its lifetime is this call's frame
 * and nothing retains it. */
union pudu_slot {
  int8_t i8;
  int16_t i16;
  int32_t i32;
  int64_t i64;
  uint8_t u8;
  uint16_t u16;
  uint32_t u32;
  uint64_t u64;
  float f32;
  double f64;
  void *pointer;
};

/* Write one scalar into a struct's storage at the offset the platform chose.
 *
 * The offset comes from libffi rather than from arithmetic here, because where
 * a field sits inside a record is the ABI's answer and not a calculation a
 * caller may repeat. */
static int place_field(unsigned char *storage, size_t offset, uint8_t kind, int64_t integer,
                       double floating, void *pointer) {
  void *slot = storage + offset;
  switch (kind) {
  case PUDU_I8:
    *(int8_t *)slot = (int8_t)integer;
    return 0;
  case PUDU_I16:
    *(int16_t *)slot = (int16_t)integer;
    return 0;
  case PUDU_I32:
    *(int32_t *)slot = (int32_t)integer;
    return 0;
  case PUDU_I64:
    *(int64_t *)slot = integer;
    return 0;
  case PUDU_U8:
  case PUDU_BOOL:
    *(uint8_t *)slot = (uint8_t)integer;
    return 0;
  case PUDU_U16:
    *(uint16_t *)slot = (uint16_t)integer;
    return 0;
  case PUDU_U32:
    *(uint32_t *)slot = (uint32_t)integer;
    return 0;
  case PUDU_U64:
    *(uint64_t *)slot = (uint64_t)integer;
    return 0;
  case PUDU_F32:
    *(float *)slot = (float)floating;
    return 0;
  case PUDU_F64:
    *(double *)slot = floating;
    return 0;
  case PUDU_TEXT:
    *(void **)slot = pointer;
    return 0;
  case PUDU_HANDLE:
    *(void **)slot = (void *)(intptr_t)integer;
    return 0;
  default:
    return -1;
  }
}

/* Read one scalar back out of a struct the library returned. */
static int take_field(const unsigned char *storage, size_t offset, uint8_t kind, int64_t *integer,
                      double *floating) {
  const void *slot = storage + offset;
  *integer = 0;
  *floating = 0.0;
  switch (kind) {
  case PUDU_I8:
    *integer = *(const int8_t *)slot;
    return 0;
  case PUDU_I16:
    *integer = *(const int16_t *)slot;
    return 0;
  case PUDU_I32:
    *integer = *(const int32_t *)slot;
    return 0;
  case PUDU_I64:
    *integer = *(const int64_t *)slot;
    return 0;
  case PUDU_U8:
    *integer = *(const uint8_t *)slot;
    return 0;
  case PUDU_BOOL:
    *integer = (*(const uint8_t *)slot) != 0 ? 1 : 0;
    return 0;
  case PUDU_U16:
    *integer = *(const uint16_t *)slot;
    return 0;
  case PUDU_U32:
    *integer = *(const uint32_t *)slot;
    return 0;
  case PUDU_U64:
    memcpy(integer, slot, sizeof(uint64_t));
    return 0;
  case PUDU_F32:
    *floating = *(const float *)slot;
    return 0;
  case PUDU_F64:
    *floating = *(const double *)slot;
    return 0;
  case PUDU_TEXT:
  case PUDU_HANDLE:
    *integer = (int64_t)(intptr_t)(*(void *const *)slot);
    return 0;
  default:
    return -1;
  }
}

/* Make the call.
 *
 * Returns 0 on success and a non-zero code when the signature could not be
 * assembled, so a refusal reaches the caller as a value rather than as a
 * crash — the one failure mode here that is recoverable. */
int pudu_ffi_call(void *symbol, int32_t arity, const uint8_t *kinds, const int64_t *integers,
                  const double *doubles, void *const *pointers, const int32_t *field_starts,
                  const int32_t *field_counts, const uint8_t *field_kinds,
                  const int64_t *field_integers, const double *field_doubles,
                  void *const *field_pointers, uint8_t result_kind, int32_t result_field_count,
                  const uint8_t *result_field_kinds,
                  int64_t *result_integer, double *result_double, int64_t *result_field_integers,
                  double *result_field_doubles) {
  if (symbol == NULL) {
    return 1;
  }
  if (arity < 0 || arity > PUDU_MAX_ARGUMENTS) {
    return 2;
  }

  ffi_type *argument_types[PUDU_MAX_ARGUMENTS];
  union pudu_slot slots[PUDU_MAX_ARGUMENTS];
  void *argument_values[PUDU_MAX_ARGUMENTS];
  /* One description and one buffer per struct argument, alive for the call. */
  ffi_type struct_types[PUDU_MAX_ARGUMENTS];
  ffi_type *struct_elements[PUDU_MAX_ARGUMENTS][PUDU_MAX_FIELDS + 1];
  unsigned char struct_storage[PUDU_MAX_ARGUMENTS][PUDU_MAX_FIELDS * 16];

  for (int32_t index = 0; index < arity; index++) {
    uint8_t kind = kinds[index];
    if (kind == PUDU_STRUCT) {
      int32_t count = field_counts[index];
      int32_t start = field_starts[index];
      if (count <= 0 || count > PUDU_MAX_FIELDS || start < 0) {
        return 3;
      }
      for (int32_t field = 0; field < count; field++) {
        ffi_type *member = type_for(field_kinds[start + field]);
        if (member == NULL || field_kinds[start + field] == PUDU_VOID ||
            field_kinds[start + field] == PUDU_STRUCT) {
          return 3;
        }
        struct_elements[index][field] = member;
      }
      struct_elements[index][count] = NULL;
      struct_types[index].size = 0;
      struct_types[index].alignment = 0;
      struct_types[index].type = FFI_TYPE_STRUCT;
      struct_types[index].elements = struct_elements[index];

      size_t offsets[PUDU_MAX_FIELDS];
      if (ffi_get_struct_offsets(FFI_DEFAULT_ABI, &struct_types[index], offsets) != FFI_OK) {
        return 5;
      }
      if (struct_types[index].size > sizeof(struct_storage[index])) {
        return 3;
      }
      memset(struct_storage[index], 0, struct_types[index].size);
      for (int32_t field = 0; field < count; field++) {
        if (place_field(struct_storage[index], offsets[field], field_kinds[start + field],
                        field_integers[start + field], field_doubles[start + field],
                        field_pointers[start + field]) != 0) {
          return 3;
        }
      }
      argument_types[index] = &struct_types[index];
      argument_values[index] = struct_storage[index];
      continue;
    }
    ffi_type *type = type_for(kind);
    if (type == NULL || kind == PUDU_VOID) {
      return 3;
    }
    argument_types[index] = type;
    argument_values[index] = &slots[index];
    switch (kind) {
    case PUDU_I8:
      slots[index].i8 = (int8_t)integers[index];
      break;
    case PUDU_I16:
      slots[index].i16 = (int16_t)integers[index];
      break;
    case PUDU_I32:
      slots[index].i32 = (int32_t)integers[index];
      break;
    case PUDU_I64:
      slots[index].i64 = integers[index];
      break;
    case PUDU_U8:
    case PUDU_BOOL:
      slots[index].u8 = (uint8_t)integers[index];
      break;
    case PUDU_U16:
      slots[index].u16 = (uint16_t)integers[index];
      break;
    case PUDU_U32:
      slots[index].u32 = (uint32_t)integers[index];
      break;
    case PUDU_U64:
      slots[index].u64 = (uint64_t)integers[index];
      break;
    case PUDU_F32:
      slots[index].f32 = (float)doubles[index];
      break;
    case PUDU_F64:
      slots[index].f64 = doubles[index];
      break;
    case PUDU_TEXT:
      slots[index].pointer = pointers[index];
      break;
    /* A handle arrives as the address it was handed back as, which is why it
     * travels in the integer array rather than the string one: nothing here
     * allocated it and nothing here frees it. */
    case PUDU_HANDLE:
      slots[index].pointer = (void *)(intptr_t)integers[index];
      break;
    default:
      return 3;
    }
  }

  ffi_type result_struct;
  ffi_type *result_elements[PUDU_MAX_FIELDS + 1];
  size_t result_offsets[PUDU_MAX_FIELDS];
  ffi_type *returned = NULL;
  if (result_kind == PUDU_STRUCT) {
    if (result_field_count <= 0 || result_field_count > PUDU_MAX_FIELDS) {
      return 4;
    }
    for (int32_t field = 0; field < result_field_count; field++) {
      ffi_type *member = type_for(result_field_kinds[field]);
      if (member == NULL || result_field_kinds[field] == PUDU_VOID ||
          result_field_kinds[field] == PUDU_STRUCT) {
        return 4;
      }
      result_elements[field] = member;
    }
    result_elements[result_field_count] = NULL;
    result_struct.size = 0;
    result_struct.alignment = 0;
    result_struct.type = FFI_TYPE_STRUCT;
    result_struct.elements = result_elements;
    if (ffi_get_struct_offsets(FFI_DEFAULT_ABI, &result_struct, result_offsets) != FFI_OK) {
      return 5;
    }
    returned = &result_struct;
  } else {
    returned = type_for(result_kind);
  }
  if (returned == NULL) {
    return 4;
  }

  ffi_cif call;
  if (ffi_prep_cif(&call, FFI_DEFAULT_ABI, (unsigned int)arity, returned, argument_types) !=
      FFI_OK) {
    return 5;
  }

  /* A result narrower than a register still occupies one, which is what this
   * buffer is: libffi writes the whole slot and the narrow read follows. */
  union {
    ffi_arg raw;
    int64_t i64;
    uint64_t u64;
    float f32;
    double f64;
    unsigned char bytes[PUDU_MAX_FIELDS * 16];
  } produced;
  memset(&produced, 0, sizeof(produced));
  if (result_kind == PUDU_STRUCT && result_struct.size > sizeof(produced.bytes)) {
    return 4;
  }

  ffi_call(&call, FFI_FN(symbol), &produced, argument_values);

  if (result_kind == PUDU_STRUCT) {
    for (int32_t field = 0; field < result_field_count; field++) {
      if (take_field(produced.bytes, result_offsets[field], result_field_kinds[field],
                     &result_field_integers[field], &result_field_doubles[field]) != 0) {
        return 4;
      }
    }
    *result_integer = 0;
    *result_double = 0.0;
    return 0;
  }

  *result_integer = 0;
  *result_double = 0.0;
  switch (result_kind) {
  case PUDU_I8:
    *result_integer = (int8_t)produced.raw;
    break;
  case PUDU_I16:
    *result_integer = (int16_t)produced.raw;
    break;
  case PUDU_I32:
    *result_integer = (int32_t)produced.raw;
    break;
  case PUDU_I64:
    *result_integer = produced.i64;
    break;
  case PUDU_U8:
    *result_integer = (int64_t)(uint8_t)produced.raw;
    break;
  case PUDU_U16:
    *result_integer = (int64_t)(uint16_t)produced.raw;
    break;
  case PUDU_U32:
    *result_integer = (int64_t)(uint32_t)produced.raw;
    break;
  case PUDU_U64:
    memcpy(result_integer, &produced.u64, sizeof(produced.u64));
    break;
  case PUDU_BOOL:
    *result_integer = ((uint8_t)produced.raw) != 0 ? 1 : 0;
    break;
  case PUDU_F32:
    *result_double = (double)produced.f32;
    break;
  case PUDU_F64:
    *result_double = produced.f64;
    break;
  case PUDU_TEXT:
  case PUDU_HANDLE:
    *result_integer = (int64_t)(intptr_t)produced.raw;
    break;
  case PUDU_VOID:
    break;
  default:
    return 4;
  }
  return 0;
}
