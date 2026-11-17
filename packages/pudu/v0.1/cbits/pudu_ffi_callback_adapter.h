/* Callback adapter state shared by the C callback bridge and its Objective-C
 * entries: blocks and delegate methods. */
#ifndef PUDU_FFI_CALLBACK_ADAPTER_H
#define PUDU_FFI_CALLBACK_ADAPTER_H

#include "pudu_ffi_internal.h"
#include <stdint.h>

/* The layout clang gives a block literal with no copy or dispose helpers,
 * followed by the registration key. A framework that keeps the block copies
 * it, and the copy carries the key with it. */
struct pudu_ffi_block_descriptor {
  unsigned long reserved, size;
};

struct pudu_ffi_block {
  void *isa;
  int flags, reserved;
  void *invoke;
  const struct pudu_ffi_block_descriptor *descriptor;
  uintptr_t key;
};

#if defined(FFI_CLOSURES) && FFI_CLOSURES
struct pudu_callback_adapter {
  struct pudu_callback_adapter *next;
  char *owner;
  int32_t member, arity, context, leaf_count, shape_count;
  uint8_t result_kind;
  int64_t fallback_integer;
  double fallback_double;
  uint8_t kinds[PUDU_MAX_ARGUMENTS];
  int32_t counts[PUDU_MAX_ARGUMENTS];
  uint8_t *leaves, *shape;
  size_t *offsets;
  ffi_type *record_types;
  ffi_type **record_elements;
  ffi_type *argument_types[PUDU_MAX_ARGUMENTS];
  ffi_cif cif;
  ffi_closure *closure, *block_closure, *method_closure;
  void *code, *block_code, *method_code;
  ffi_type *method_types[PUDU_MAX_ARGUMENTS + 1];
  ffi_cif method_cif;
};

void pudu_ffi_lock_callbacks(void);
void pudu_ffi_unlock_callbacks(void);
void pudu_ffi_dispatch_callback(const struct pudu_callback_adapter *adapter, void *result,
                                void **arguments, uintptr_t key);
#endif

#endif
