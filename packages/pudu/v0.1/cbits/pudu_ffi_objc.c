/* Objective-C entries into callback adapters: stack blocks whose invoke
 * reads the registration key from the block, and delegate classes whose
 * methods read it from the object's extra bytes. */

#include "pudu_ffi_callback_adapter.h"
#include <string.h>

#if defined(__APPLE__)
/* A block's first argument is the block itself; its key names the entry. */
static void invoke_block_callback(ffi_cif *cif, void *result, void **arguments, void *data) {
  (void)cif;
  const struct pudu_callback_adapter *adapter = data;
  const struct pudu_ffi_block *block;
  memcpy(&block, arguments[0], sizeof(block));
  pudu_ffi_dispatch_callback(adapter, result, arguments, block == NULL ? 0 : block->key);
}
#endif

/* The block entry shares the adapter's signature and is built on first use.
 * Only a signature whose context comes first can be a block's invoke. */
void *pudu_ffi_callback_block_code(void *opaque) {
#if defined(FFI_CLOSURES) && FFI_CLOSURES && defined(__APPLE__)
  struct pudu_callback_adapter *adapter = opaque;
  if (adapter == NULL || adapter->context != 0) return NULL;
  pudu_ffi_lock_callbacks();
  if (adapter->block_code == NULL) {
    void *code = NULL;
    ffi_closure *closure = ffi_closure_alloc(sizeof(*closure), &code);
    if (closure != NULL &&
        ffi_prep_closure_loc(closure, &adapter->cif, invoke_block_callback, adapter, code) == FFI_OK) {
      adapter->block_closure = closure;
      adapter->block_code = code;
    } else if (closure != NULL) {
      ffi_closure_free(closure);
    }
  }
  void *code = adapter->block_code;
  pudu_ffi_unlock_callbacks();
  return code;
#else
  (void)opaque;
  return NULL;
#endif
}

#if defined(FFI_CLOSURES) && FFI_CLOSURES && defined(__APPLE__)
#include <objc/message.h>
#include <objc/runtime.h>

/* A delegate method receives its object and selector where the callback
 * takes its context; the object's extra bytes hold the registration key. */
static void invoke_method_callback(ffi_cif *cif, void *result, void **arguments, void *data) {
  (void)cif;
  const struct pudu_callback_adapter *adapter = data;
  id object;
  memcpy(&object, arguments[0], sizeof(object));
  uintptr_t key = 0;
  if (object != nil) memcpy(&key, object_getIndexedIvars(object), sizeof(key));
  pudu_ffi_dispatch_callback(adapter, result, arguments + 1, key);
}

static const char *method_encoding(uint8_t kind) {
  switch (kind) {
  case PUDU_I8: return "c";
  case PUDU_I16: return "s";
  case PUDU_I32: return "i";
  case PUDU_I64: return "q";
  case PUDU_U8: return "C";
  case PUDU_U16: return "S";
  case PUDU_U32: return "I";
  case PUDU_U64: return "Q";
  case PUDU_F32: return "f";
  case PUDU_F64: return "d";
  case PUDU_BOOL: return "B";
  case PUDU_TEXT: return "*";
  case PUDU_VOID: return "v";
  case PUDU_HANDLE: return "@";
  case PUDU_BYTES:
  case PUDU_POINTER: return "^v";
  default: return NULL;
  }
}

/* The method entry and its type encoding; records are not method arguments. */
static void *method_code(struct pudu_callback_adapter *adapter, char *encoding, size_t room) {
  if (adapter->context != 0 || adapter->arity > PUDU_MAX_ARGUMENTS) return NULL;
  const char *answer = method_encoding(adapter->result_kind);
  if (answer == NULL) return NULL;
  size_t used = strlen(answer) + 2;
  if (used >= room) return NULL;
  memcpy(encoding, answer, used - 2);
  memcpy(encoding + used - 2, "@:", 3);
  for (int32_t index = 1; index < adapter->arity; ++index) {
    const char *part = method_encoding(adapter->kinds[index]);
    if (part == NULL || used + strlen(part) >= room) return NULL;
    memcpy(encoding + used, part, strlen(part) + 1);
    used += strlen(part);
  }
  if (adapter->method_code == NULL) {
    adapter->method_types[0] = &ffi_type_pointer;
    adapter->method_types[1] = &ffi_type_pointer;
    for (int32_t index = 1; index < adapter->arity; ++index)
      adapter->method_types[index + 1] = adapter->argument_types[index];
    void *code = NULL;
    ffi_closure *closure = ffi_closure_alloc(sizeof(*closure), &code);
    if (closure == NULL) return NULL;
    if (ffi_prep_cif(&adapter->method_cif, FFI_DEFAULT_ABI, (unsigned int)adapter->arity + 1,
                     adapter->cif.rtype, adapter->method_types) != FFI_OK ||
        ffi_prep_closure_loc(closure, &adapter->method_cif, invoke_method_callback, adapter, code) != FFI_OK) {
      ffi_closure_free(closure);
      return NULL;
    }
    adapter->method_closure = closure;
    adapter->method_code = code;
  }
  return adapter->method_code;
}
#endif

/* Defines a subclass of NSObject whose methods enter the given adapters. A
 * class already registered under the name is answered as it stands. */
void *pudu_ffi_delegate_class(const char *name, int32_t count, const char *const *selectors,
                              void *const *adapters) {
#if defined(FFI_CLOSURES) && FFI_CLOSURES && defined(__APPLE__)
  if (name == NULL || count < 0 || (count && (!selectors || !adapters))) return NULL;
  Class existing = objc_getClass(name);
  if (existing != Nil) return (void *)existing;
  Class base = objc_getClass("NSObject");
  Class created = base == Nil ? Nil : objc_allocateClassPair(base, name, 0);
  if (created == Nil) return NULL;
  pudu_ffi_lock_callbacks();
  for (int32_t index = 0; index < count; ++index) {
    char encoding[2 * PUDU_MAX_ARGUMENTS + 8];
    void *code = method_code(adapters[index], encoding, sizeof encoding);
    if (code == NULL || !class_addMethod(created, sel_registerName(selectors[index]), (IMP)code, encoding)) {
      pudu_ffi_unlock_callbacks();
      objc_disposeClassPair(created);
      return NULL;
    }
  }
  pudu_ffi_unlock_callbacks();
  objc_registerClassPair(created);
  return (void *)created;
#else
  (void)name; (void)count; (void)selectors; (void)adapters;
  return NULL;
#endif
}

/* A new instance owned by the caller, carrying the registration key. */
void *pudu_ffi_delegate_new(void *type, void *key) {
#if defined(FFI_CLOSURES) && FFI_CLOSURES && defined(__APPLE__)
  if (type == NULL) return NULL;
  id object = class_createInstance((Class)type, sizeof(uintptr_t));
  if (object == nil) return NULL;
  uintptr_t value = (uintptr_t)key;
  memcpy(object_getIndexedIvars(object), &value, sizeof(value));
  return (void *)object;
#else
  (void)type; (void)key;
  return NULL;
#endif
}

/* Gives up the claim pudu_ffi_delegate_new handed over. */
void pudu_ffi_delegate_release(void *object) {
#if defined(FFI_CLOSURES) && FFI_CLOSURES && defined(__APPLE__)
  if (object != NULL) ((void (*)(id, SEL))objc_msgSend)((id)object, sel_registerName("release"));
#else
  (void)object;
#endif
}

#if defined(__APPLE__)
extern void *_NSConcreteStackBlock[32];
static const struct pudu_ffi_block_descriptor pudu_ffi_block_descriptor = {0, sizeof(struct pudu_ffi_block)};
#endif

size_t pudu_ffi_block_size(void) {
  return sizeof(struct pudu_ffi_block);
}

/* Writes a stack block into caller storage that outlives the foreign call. */
int pudu_ffi_block_fill(void *storage, void *invoke, void *key) {
#if defined(__APPLE__)
  if (storage == NULL || invoke == NULL) return 0;
  struct pudu_ffi_block *block = storage;
  *block = (struct pudu_ffi_block){
    .isa = _NSConcreteStackBlock, .invoke = invoke,
    .descriptor = &pudu_ffi_block_descriptor, .key = (uintptr_t)key
  };
  return 1;
#else
  (void)storage; (void)invoke; (void)key;
  return 0;
#endif
}
