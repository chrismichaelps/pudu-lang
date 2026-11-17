/* The executable fallback may outlive the run that first used this signature.
 * Native keys name live interpreter entries, never their storage. */

#include "pudu_ffi_internal.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

static _Thread_local void *pudu_ffi_scope;

void *pudu_ffi_swap_scope(void *scope) {
  void *previous = pudu_ffi_scope;
  pudu_ffi_scope = scope;
  return previous;
}

typedef int (*pudu_callback_dispatch)(void *, void *, const int64_t *, const double *,
                                     int64_t *, double *);
typedef void (*pudu_callback_dispose)(void *);

#if defined(FFI_CLOSURES) && FFI_CLOSURES
struct pudu_callback_adapter {
  struct pudu_callback_adapter *next;
  char *owner;
  int32_t arity, context, leaf_count, shape_count;
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
  ffi_closure *closure;
  void *code;
};

struct pudu_callback_entry {
  struct pudu_callback_entry *next;
  const struct pudu_callback_adapter *adapter;
  uintptr_t key;
  size_t invocations;
  int retired;
  void *user;
  pudu_callback_dispatch dispatch;
  pudu_callback_dispose dispose;
};

static atomic_flag pudu_callback_lock = ATOMIC_FLAG_INIT;
static struct pudu_callback_adapter *pudu_callback_adapters;
static struct pudu_callback_entry *pudu_callback_entries;
static uintptr_t pudu_callback_next_key = 1;

static void lock_callbacks(void) {
  while (atomic_flag_test_and_set_explicit(&pudu_callback_lock, memory_order_acquire)) {}
}

static void unlock_callbacks(void) {
  atomic_flag_clear_explicit(&pudu_callback_lock, memory_order_release);
}

static struct pudu_callback_entry *acquire_entry(const struct pudu_callback_adapter *adapter,
                                                 uintptr_t key) {
  lock_callbacks();
  struct pudu_callback_entry *entry = pudu_callback_entries;
  while (entry && (entry->key != key || entry->adapter != adapter)) entry = entry->next;
  if (entry != NULL) entry->invocations++;
  unlock_callbacks();
  return entry;
}

static void dispose_entry(struct pudu_callback_entry *entry) {
  entry->dispose(entry->user);
  free(entry);
}

static void release_entry(struct pudu_callback_entry *entry) {
  lock_callbacks();
  int dispose = --entry->invocations == 0 && entry->retired;
  unlock_callbacks();
  if (dispose) dispose_entry(entry);
}

static void write_result(uint8_t kind, void *result, int64_t integer, double floating) {
  switch (kind) {
  case PUDU_VOID: break;
  case PUDU_F32: *(float *)result = (float)floating; break;
  case PUDU_F64: *(double *)result = floating; break;
  case PUDU_I64:
  case PUDU_U64: *(uint64_t *)result = (uint64_t)integer; break;
  /* libffi's closure return storage widens smaller integers to a register. */
  default: *(ffi_arg *)result = (ffi_arg)integer; break;
  }
}

static int decode_arguments(const struct pudu_callback_adapter *adapter, void **arguments,
                            int64_t *integers, double *doubles) {
  size_t leaf = 0;
  for (int32_t argument = 0; argument < adapter->arity; ++argument) {
    for (int32_t field = 0; field < adapter->counts[argument]; ++field, ++leaf) {
      if (pudu_ffi_take_field(arguments[argument], adapter->offsets[leaf], adapter->leaves[leaf],
                              &integers[leaf], &doubles[leaf]) != 0) return 0;
    }
  }
  return 1;
}

static void invoke_callback(ffi_cif *cif, void *result, void **arguments, void *data) {
  (void)cif;
  const struct pudu_callback_adapter *adapter = data;
  int64_t integer = adapter->fallback_integer;
  double floating = adapter->fallback_double;
  void *context;
  memcpy(&context, arguments[adapter->context], sizeof(context));
  struct pudu_callback_entry *entry = acquire_entry(adapter, (uintptr_t)context);
  if (entry != NULL) {
    size_t count = adapter->leaf_count > 0 ? (size_t)adapter->leaf_count : 1;
    int64_t *integers = calloc(count, sizeof(*integers));
    double *doubles = calloc(count, sizeof(*doubles));
    int valid = integers && doubles && decode_arguments(adapter, arguments, integers, doubles);
    /* The dispatcher handles an absent carrier as invocation failure. */
    int64_t returned_integer = 0;
    double returned_double = 0.0;
    if (entry->dispatch(entry->user, pudu_ffi_scope, valid ? integers : NULL,
                        valid ? doubles : NULL, &returned_integer, &returned_double)) {
      integer = returned_integer;
      floating = returned_double;
    }
    free(doubles);
    free(integers);
    release_entry(entry);
  }
  write_result(adapter->result_kind, result, integer, floating);
}

static void free_adapter(struct pudu_callback_adapter *adapter) {
  if (adapter->closure) ffi_closure_free(adapter->closure);
  free(adapter->record_elements);
  free(adapter->record_types);
  free(adapter->offsets);
  free(adapter->shape);
  free(adapter->leaves);
  free(adapter->owner);
  free(adapter);
}

static int prepare_adapter(struct pudu_callback_adapter *adapter) {
  size_t leaf = 0;
  struct pudu_layout layout = {
    .next = adapter->shape, .end = adapter->shape + adapter->shape_count,
    .types = adapter->record_types, .elements = adapter->record_elements
  };
  for (int32_t index = 0; index < adapter->arity; ++index) {
    uint8_t kind = adapter->kinds[index];
    size_t count = (size_t)adapter->counts[index];
    if (count > (size_t)adapter->leaf_count - leaf) return 0;
    ffi_type *type;
    if (index == adapter->context) {
      if (kind != PUDU_POINTER || count != 0) return 0;
      type = &ffi_type_pointer;
    } else if (kind == PUDU_STRUCT) {
      size_t consumed = 0;
      if (count == 0) return 0;
      type = pudu_ffi_record_type(&layout, adapter->leaves + leaf, adapter->offsets + leaf,
                                  count, &consumed);
      if (consumed != count) return 0;
    } else {
      if (kind == PUDU_VOID || kind == PUDU_POINTER || kind == PUDU_BYTES ||
          count != 1 || adapter->leaves[leaf] != kind) return 0;
      type = pudu_ffi_type_for(kind);
    }
    if (type == NULL) return 0;
    adapter->argument_types[index] = type;
    leaf += count;
  }
  ffi_type *result = pudu_ffi_type_for(adapter->result_kind);
  if (leaf != (size_t)adapter->leaf_count || layout.next != layout.end ||
      adapter->result_kind > PUDU_VOID || adapter->result_kind == PUDU_TEXT || result == NULL ||
      ffi_prep_cif(&adapter->cif, FFI_DEFAULT_ABI, (unsigned int)adapter->arity,
                   result, adapter->argument_types) != FFI_OK) return 0;
  adapter->closure = ffi_closure_alloc(sizeof(*adapter->closure), &adapter->code);
  return adapter->closure != NULL &&
    ffi_prep_closure_loc(adapter->closure, &adapter->cif, invoke_callback,
                         adapter, adapter->code) == FFI_OK;
}
#endif

/* Successfully published adapters remain executable for the lifetime of the
 * host. The signature and bitwise fallback form part of the cache key. */
void *pudu_ffi_callback_adapter(const char *owner, int32_t arity, int32_t context,
                                const uint8_t *kinds, const int32_t *counts,
                                int32_t leaf_count, const uint8_t *leaves,
                                int32_t shape_count, const uint8_t *shape,
                                uint8_t result_kind, int64_t fallback_integer,
                                double fallback_double) {
#if defined(FFI_CLOSURES) && FFI_CLOSURES
  if (!owner || arity < 1 || arity > PUDU_MAX_ARGUMENTS || context < 0 || context >= arity ||
      !kinds || !counts || leaf_count < 0 || (leaf_count && !leaves) ||
      shape_count < 0 || (shape_count && !shape)) return NULL;
  size_t leaf_size = leaf_count ? (size_t)leaf_count : 1;
  size_t shape_size = shape_count ? (size_t)shape_count : 1;
  lock_callbacks();
  for (struct pudu_callback_adapter *held = pudu_callback_adapters; held; held = held->next) {
    if (held->arity == arity && held->context == context && held->leaf_count == leaf_count &&
        held->shape_count == shape_count && held->result_kind == result_kind &&
        held->fallback_integer == fallback_integer &&
        memcmp(&held->fallback_double, &fallback_double, sizeof(fallback_double)) == 0 &&
        strcmp(held->owner, owner) == 0 &&
        memcmp(held->kinds, kinds, (size_t)arity) == 0 &&
        memcmp(held->counts, counts, (size_t)arity * sizeof(*counts)) == 0 &&
        (!leaf_count || memcmp(held->leaves, leaves, (size_t)leaf_count) == 0) &&
        (!shape_count || memcmp(held->shape, shape, (size_t)shape_count) == 0)) {
      unlock_callbacks();
      return held;
    }
  }
  struct pudu_callback_adapter *adapter = calloc(1, sizeof(*adapter));
  if (adapter) {
    adapter->arity = arity;
    adapter->context = context;
    adapter->leaf_count = leaf_count;
    adapter->shape_count = shape_count;
    adapter->result_kind = result_kind;
    adapter->fallback_integer = fallback_integer;
    adapter->fallback_double = fallback_double;
    adapter->owner = malloc(strlen(owner) + 1);
    adapter->leaves = malloc(leaf_size);
    adapter->shape = malloc(shape_size);
    adapter->offsets = calloc(leaf_size, sizeof(*adapter->offsets));
    adapter->record_types = calloc(shape_size, sizeof(*adapter->record_types));
    adapter->record_elements = calloc(shape_size, sizeof(*adapter->record_elements));
    if (adapter->owner && adapter->leaves && adapter->shape && adapter->offsets &&
        adapter->record_types && adapter->record_elements) {
      memcpy(adapter->owner, owner, strlen(owner) + 1);
      memcpy(adapter->kinds, kinds, (size_t)arity);
      memcpy(adapter->counts, counts, (size_t)arity * sizeof(*counts));
      if (leaf_count) memcpy(adapter->leaves, leaves, (size_t)leaf_count);
      if (shape_count) memcpy(adapter->shape, shape, (size_t)shape_count);
      if (prepare_adapter(adapter)) {
        adapter->next = pudu_callback_adapters;
        pudu_callback_adapters = adapter;
        unlock_callbacks();
        return adapter;
      }
    }
    free_adapter(adapter);
  }
  unlock_callbacks();
#else
  (void)owner; (void)arity; (void)context; (void)kinds; (void)counts;
  (void)leaf_count; (void)leaves; (void)shape_count; (void)shape;
  (void)result_kind; (void)fallback_integer; (void)fallback_double;
#endif
  return NULL;
}

void *pudu_ffi_callback_code(void *opaque) {
#if defined(FFI_CLOSURES) && FFI_CLOSURES
  struct pudu_callback_adapter *adapter = opaque;
  return adapter ? adapter->code : NULL;
#else
  (void)opaque;
  return NULL;
#endif
}

void *pudu_ffi_callback_register(void *adapter, void *user, pudu_callback_dispatch dispatch,
                                  pudu_callback_dispose dispose) {
#if defined(FFI_CLOSURES) && FFI_CLOSURES
  if (!adapter || !user || !dispatch || !dispose) return NULL;
  struct pudu_callback_entry *entry = calloc(1, sizeof(*entry));
  if (entry == NULL) return NULL;
  lock_callbacks();
  uintptr_t key = pudu_callback_next_key;
  if (key == 0) {
    unlock_callbacks();
    free(entry);
    return NULL;
  }
  pudu_callback_next_key = key == UINTPTR_MAX ? 0 : key + 1;
  entry->adapter = adapter;
  entry->key = key;
  entry->user = user;
  entry->dispatch = dispatch;
  entry->dispose = dispose;
  entry->next = pudu_callback_entries;
  pudu_callback_entries = entry;
  unlock_callbacks();
  return (void *)key;
#else
  (void)adapter; (void)user; (void)dispatch; (void)dispose;
  return NULL;
#endif
}

void pudu_ffi_callback_retire(void *context) {
#if defined(FFI_CLOSURES) && FFI_CLOSURES
  uintptr_t key = (uintptr_t)context;
  lock_callbacks();
  struct pudu_callback_entry **link = &pudu_callback_entries;
  while (*link && (*link)->key != key) link = &(*link)->next;
  struct pudu_callback_entry *entry = *link;
  int dispose = 0;
  if (entry != NULL) {
    *link = entry->next;
    entry->retired = 1;
    dispose = entry->invocations == 0;
  }
  unlock_callbacks();
  if (dispose) dispose_entry(entry);
#else
  (void)context;
#endif
}
