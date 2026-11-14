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
  PUDU_STRUCT = 14,
  /* A run of bytes the library reads. An address like any other here; what
   * makes it different is above, where the storage it names belongs to a value
   * that outlives the call and is not copied to get here. */
  PUDU_BYTES = 15
};

#define PUDU_MAX_ARGUMENTS 32
#define PUDU_MAX_FIELDS 32

/* Storage for one argument this call lays out itself: a record crossing by
 * value, or the cell behind an output slot.
 *
 * A union rather than a byte array because what goes in is read by the platform
 * at the platform's own offsets. A field of eight bytes must sit at an address
 * the platform accepts for eight bytes, and an array of bytes promises an
 * alignment of one — true storage today only because the compiler happened to
 * place it well. The widest member states the requirement instead of relying on
 * that.
 *
 * Record storage is allocated from the complete libffi layout. */
union pudu_storage {
  long double widest;
  void *pointer;
  int64_t integer;
  double floating;
};

void *pudu_sqlite_symbol(const char *name);
static char sqlite_module;

void *pudu_ffi_open(const char *path) {
  if (path && strcmp(path, "pudu_sqlite") == 0) return &sqlite_module;
  return dlopen(path, RTLD_LAZY | RTLD_LOCAL);
}

void *pudu_ffi_symbol(void *handle, const char *name) {
  if (handle == &sqlite_module) return pudu_sqlite_symbol(name);
  return dlsym(handle, name);
}

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
  case PUDU_BYTES:
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
  case PUDU_BYTES:
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
  case PUDU_BYTES:
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
 * crash — the one failure mode here that is recoverable.
 *
 * An argument is an output slot when `slot_kinds` says so, and then the kind at
 * that position describes what the library writes rather than what the caller
 * sends. The native argument is the address of storage this frame owns; the
 * caller supplies no value for it, and what the library left there is read back
 * into the slot arrays before returning. `slot_kinds` may be null, which is a
 * call with no slots at all. */
/* Descriptors and leaf offsets are consumed in declaration order. */
struct pudu_layout {
  const uint8_t *next, *end;
  ffi_type *types;
  ffi_type **elements;
  unsigned char *storage[PUDU_MAX_ARGUMENTS + 1];
  size_t *offsets[PUDU_MAX_ARGUMENTS + 1];
};

static ffi_type *record_type(struct pudu_layout *layout, const uint8_t *kinds,
                             size_t *offsets, size_t count, size_t *leaf) {
  if (layout->end - layout->next < 2 || *layout->next++ != PUDU_STRUCT) return NULL;
  uint8_t members = *layout->next++;
  if (members == 0 || members > PUDU_MAX_FIELDS) return NULL;
  ffi_type *type = layout->types++;
  ffi_type **elements = layout->elements;
  layout->elements += members + 1;
  size_t starts[PUDU_MAX_FIELDS + 1], direct[PUDU_MAX_FIELDS];
  for (uint8_t member = 0; member < members; ++member) {
    if (layout->next == layout->end) return NULL;
    starts[member] = *leaf;
    uint8_t kind = *layout->next;
    if (kind == PUDU_STRUCT) {
      elements[member] = record_type(layout, kinds, offsets, count, leaf);
    } else {
      if (*leaf == count || kinds[*leaf] != kind || kind == PUDU_VOID) return NULL;
      layout->next++;
      (*leaf)++;
      elements[member] = type_for(kind);
    }
    if (elements[member] == NULL) return NULL;
  }
  starts[members] = *leaf;
  elements[members] = NULL;
  *type = (ffi_type){.type = FFI_TYPE_STRUCT, .elements = elements};
  if (ffi_get_struct_offsets(FFI_DEFAULT_ABI, type, direct) != FFI_OK) return NULL;
  for (uint8_t member = 0; member < members; ++member)
    for (size_t i = starts[member]; i < starts[member + 1]; ++i)
      offsets[i] += direct[member];
  return type;
}

static ffi_type *prepare_record(struct pudu_layout *layout, size_t index,
                                const uint8_t *kinds, int32_t count) {
  if (count <= 0 || (size_t)count > SIZE_MAX / sizeof(size_t)) return NULL;
  layout->offsets[index] = calloc((size_t)count, sizeof(size_t));
  if (layout->offsets[index] == NULL) return NULL;
  size_t leaf = 0;
  ffi_type *type = record_type(layout, kinds, layout->offsets[index], (size_t)count, &leaf);
  if (type == NULL || leaf != (size_t)count) return NULL;
  layout->storage[index] = calloc(1, type->size);
  return layout->storage[index] == NULL ? NULL : type;
}

static int call_with_layout(struct pudu_layout *layout, void *symbol, int32_t arity, const uint8_t *kinds, const int64_t *integers,
                  const double *doubles, void *const *pointers, const int32_t *field_starts,
                  const int32_t *field_counts, const uint8_t *field_kinds,
                  const int64_t *field_integers, const double *field_doubles,
                  void *const *field_pointers, const uint8_t *slot_kinds, int64_t *slot_integers,
                  double *slot_doubles, int64_t *slot_field_integers, double *slot_field_doubles,
                  uint8_t result_kind, int32_t result_field_count,
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
  union pudu_storage slot_storage[PUDU_MAX_ARGUMENTS] = {0};

  for (int32_t index = 0; index < arity; index++) {
    uint8_t slot_kind = slot_kinds == NULL ? PUDU_VOID : slot_kinds[index];
    if (slot_kind != PUDU_VOID) {
      if (slot_integers == NULL || slot_doubles == NULL) {
        return 6;
      }
      if (slot_kind == PUDU_STRUCT) {
        int32_t start = field_starts[index];
        if (start < 0 || slot_field_integers == NULL || slot_field_doubles == NULL ||
            prepare_record(layout, (size_t)index, field_kinds + start, field_counts[index]) == NULL)
          return 6;
      } else if (type_for(slot_kind) == NULL) {
        return 6;
      }
      /* The library is handed the address of that storage, so the argument
       * itself is a pointer and the pointer is what libffi is given a pointer
       * to. */
      argument_types[index] = &ffi_type_pointer;
      slots[index].pointer = slot_kind == PUDU_STRUCT ? (void *)layout->storage[index] : &slot_storage[index];
      argument_values[index] = &slots[index];
      continue;
    }
    uint8_t kind = kinds[index];
    if (kind == PUDU_STRUCT) {
      int32_t count = field_counts[index];
      int32_t start = field_starts[index];
      if (start < 0) return 3;
      ffi_type *type = prepare_record(layout, (size_t)index, field_kinds + start, count);
      if (type == NULL) return 3;
      for (int32_t field = 0; field < count; field++) {
        if (place_field(layout->storage[index], layout->offsets[index][field], field_kinds[start + field],
                        field_integers[start + field], field_doubles[start + field],
                        field_pointers[start + field]) != 0) return 3;
      }
      argument_types[index] = type;
      argument_values[index] = layout->storage[index];
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
    case PUDU_BYTES:
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

  ffi_type *returned = result_kind == PUDU_STRUCT
    ? prepare_record(layout, PUDU_MAX_ARGUMENTS, result_field_kinds, result_field_count)
    : type_for(result_kind);
  if (returned == NULL || layout->next != layout->end) return 4;

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
  } produced = {0};
  void *result_storage = result_kind == PUDU_STRUCT
    ? (void *)layout->storage[PUDU_MAX_ARGUMENTS] : &produced;
  ffi_call(&call, FFI_FN(symbol), result_storage, argument_values);

  /* What the library left in each slot, read before the result so that a call
   * answering through both is read once, here, in one place. Storage was zeroed
   * before the call, so a pointer the library never wrote reads back as null —
   * which is the absence a pointer can carry. A scalar it never wrote reads
   * back as zero, and zero is a value: the declaration asserted the write, and
   * nothing here can check that assertion. */
  if (slot_kinds != NULL) {
    for (int32_t index = 0; index < arity; index++) {
      uint8_t slot_kind = slot_kinds[index];
      if (slot_kind == PUDU_VOID) {
        /* An ordinary argument answers with nothing, written rather than left
         * as it was found, so every position in the array means something. */
        if (slot_integers != NULL) {
          slot_integers[index] = 0;
        }
        if (slot_doubles != NULL) {
          slot_doubles[index] = 0.0;
        }
        continue;
      }
      if (slot_kind == PUDU_STRUCT) {
        int32_t start = field_starts[index];
        int32_t count = field_counts[index];
        for (int32_t field = 0; field < count; field++) {
          if (take_field(layout->storage[index], layout->offsets[index][field],
                         field_kinds[start + field], &slot_field_integers[start + field],
                         &slot_field_doubles[start + field]) != 0) {
            return 6;
          }
        }
        slot_integers[index] = 0;
        slot_doubles[index] = 0.0;
        continue;
      }
      if (take_field((const unsigned char *)&slot_storage[index], 0, slot_kind, &slot_integers[index],
                     &slot_doubles[index]) != 0) {
        return 6;
      }
    }
  }

  if (result_kind == PUDU_STRUCT) {
    for (int32_t field = 0; field < result_field_count; field++) {
      if (take_field(layout->storage[PUDU_MAX_ARGUMENTS], layout->offsets[PUDU_MAX_ARGUMENTS][field], result_field_kinds[field],
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

int pudu_ffi_call(void *symbol, int32_t arity, const uint8_t *kinds, const int64_t *integers,
                  const double *doubles, void *const *pointers, const int32_t *field_starts,
                  const int32_t *field_counts, const uint8_t *field_kinds,
                  const int64_t *field_integers, const double *field_doubles,
                  void *const *field_pointers, const uint8_t *slot_kinds, int64_t *slot_integers,
                  double *slot_doubles, int64_t *slot_field_integers, double *slot_field_doubles,
                  const uint8_t *shape, int32_t shape_count, uint8_t result_kind, int32_t result_field_count,
                  const uint8_t *result_field_kinds,
                  int64_t *result_integer, double *result_double, int64_t *result_field_integers,
                  double *result_field_doubles) {
  if (shape_count < 0) return 3;
  struct pudu_layout layout = {.next = shape, .end = shape + shape_count};
  size_t count = (size_t)shape_count;
  ffi_type *types = count == 0 ? NULL : calloc(count, sizeof(*types));
  ffi_type **elements = count == 0 ? NULL : calloc(count, sizeof(*elements));
  layout.types = types;
  layout.elements = elements;
  int status = 3;
  if (count == 0 || (types != NULL && elements != NULL)) {
    status = call_with_layout(&layout, symbol, arity, kinds, integers, doubles, pointers,
      field_starts, field_counts, field_kinds, field_integers, field_doubles,
      field_pointers, slot_kinds, slot_integers, slot_doubles, slot_field_integers,
      slot_field_doubles, result_kind, result_field_count, result_field_kinds,
      result_integer, result_double, result_field_integers, result_field_doubles);
  }
  for (size_t i = 0; i <= PUDU_MAX_ARGUMENTS; ++i) {
    free(layout.storage[i]);
    free(layout.offsets[i]);
  }
  free(types);
  free(elements);
  return status;
}
