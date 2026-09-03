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
  PUDU_VOID = 12
};

#define PUDU_MAX_ARGUMENTS 32

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

/* Make the call.
 *
 * Returns 0 on success and a non-zero code when the signature could not be
 * assembled, so a refusal reaches the caller as a value rather than as a
 * crash — the one failure mode here that is recoverable. */
int pudu_ffi_call(void *symbol, int32_t arity, const uint8_t *kinds, const int64_t *integers,
                  const double *doubles, void *const *pointers, uint8_t result_kind,
                  int64_t *result_integer, double *result_double) {
  if (symbol == NULL) {
    return 1;
  }
  if (arity < 0 || arity > PUDU_MAX_ARGUMENTS) {
    return 2;
  }

  ffi_type *argument_types[PUDU_MAX_ARGUMENTS];
  union pudu_slot slots[PUDU_MAX_ARGUMENTS];
  void *argument_values[PUDU_MAX_ARGUMENTS];

  for (int32_t index = 0; index < arity; index++) {
    uint8_t kind = kinds[index];
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
    default:
      return 3;
    }
  }

  ffi_type *returned = type_for(result_kind);
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
    float f32;
    double f64;
  } produced;
  memset(&produced, 0, sizeof(produced));

  ffi_call(&call, FFI_FN(symbol), &produced, argument_values);

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
    *result_integer = (int64_t)produced.raw;
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
    *result_integer = (int64_t)(uint64_t)produced.raw;
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
    *result_integer = (int64_t)(intptr_t)produced.raw;
    break;
  case PUDU_VOID:
    break;
  default:
    return 4;
  }
  return 0;
}
