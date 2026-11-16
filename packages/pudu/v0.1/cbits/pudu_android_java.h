/* The whole Android platform for a Pudu program, through JNI: any class,
   constructor, method, field, array or string, reached from foreign
   declarations. Java objects cross as owned handles, numbered references the
   program releases; a handle of zero is null. Arguments cross as one byte
   buffer of tagged values, so one C entry point serves every Java signature:

     Z bool (1 byte)   B byte (1)   C char (2)   S short (2)   I int (4)
     J long (8)        F float (4)  D double (8) L handle (8)  T text (4-byte length, UTF-8)

   all little-endian. A call made with `main` set runs on the main thread and
   the program waits for it, as views and most services require. A Java
   exception never escapes: the call answers zero and the next call to
   pudu_java_failure answers the exception's text. Only the host's single
   translation unit includes this, so it shares the host's VM and activity. */
#ifndef PUDU_ANDROID_JAVA_H
#define PUDU_ANDROID_JAVA_H
#include <jni.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "pudu_android_jni.h"

/* The handle table: global references with a free list. */
static jobject *pudu_handles;
static int64_t pudu_handle_room, pudu_handle_free = -1;
static int64_t *pudu_handle_next;
static pthread_mutex_t pudu_handles_lock = PTHREAD_MUTEX_INITIALIZER;
static jobject pudu_loader;
static __thread char *pudu_java_said;

static int64_t pudu_hold(JNIEnv *env, jobject object) {
  int64_t slot;
  if (object == NULL) return 0;
  pthread_mutex_lock(&pudu_handles_lock);
  if (pudu_handle_free < 0) {
    int64_t room = pudu_handle_room < 64 ? 64 : pudu_handle_room * 2;
    pudu_handles = realloc(pudu_handles, (size_t)room * sizeof *pudu_handles);
    pudu_handle_next = realloc(pudu_handle_next, (size_t)room * sizeof *pudu_handle_next);
    if (pudu_handles == NULL || pudu_handle_next == NULL) abort();
    for (int64_t i = room - 1; i >= pudu_handle_room; i--) {
      pudu_handles[i] = NULL;
      pudu_handle_next[i] = pudu_handle_free;
      pudu_handle_free = i;
    }
    pudu_handle_room = room;
  }
  slot = pudu_handle_free;
  pudu_handle_free = pudu_handle_next[slot];
  pudu_handles[slot] = (*env)->NewGlobalRef(env, object);
  pthread_mutex_unlock(&pudu_handles_lock);
  return slot + 1;
}

static jobject pudu_held(int64_t handle) {
  jobject found = NULL;
  pthread_mutex_lock(&pudu_handles_lock);
  if (handle > 0 && handle <= pudu_handle_room) found = pudu_handles[handle - 1];
  pthread_mutex_unlock(&pudu_handles_lock);
  return found;
}

/* Releases a handle; releasing zero or a released handle does nothing. */
void pudu_java_release(int64_t handle) {
  JNIEnv *env = pudu_env();
  jobject gone = NULL;
  pthread_mutex_lock(&pudu_handles_lock);
  if (handle > 0 && handle <= pudu_handle_room && pudu_handles[handle - 1] != NULL) {
    gone = pudu_handles[handle - 1];
    pudu_handles[handle - 1] = NULL;
    pudu_handle_next[handle - 1] = pudu_handle_free;
    pudu_handle_free = handle - 1;
  }
  pthread_mutex_unlock(&pudu_handles_lock);
  if (gone != NULL) (*env)->DeleteGlobalRef(env, gone);
}

/* A pending exception becomes the failure text; answers whether one was pending. */
static int pudu_caught(JNIEnv *env) {
  jthrowable thrown;
  jstring text;
  if (!(*env)->ExceptionCheck(env)) return 0;
  thrown = (*env)->ExceptionOccurred(env);
  (*env)->ExceptionClear(env);
  text = (jstring)(*env)->CallObjectMethod(env, thrown, pudu_method_of(env, thrown, "toString", "()Ljava/lang/String;"));
  (*env)->ExceptionClear(env);
  free(pudu_java_said);
  pudu_java_said = pudu_utf8(env, text);
  (*env)->DeleteLocalRef(env, text);
  (*env)->DeleteLocalRef(env, thrown);
  return 1;
}

/* The text of the last failed call on this thread, or empty; reading clears it. */
const char *pudu_java_failure(void) {
  static __thread char *answered;
  free(answered);
  answered = pudu_java_said != NULL ? pudu_java_said : strdup("");
  pudu_java_said = NULL;
  return answered;
}

int64_t pudu_java_activity(void) { return pudu_hold(pudu_env(), pudu_activity); }

/* A class by its binary name (`android.widget.Toast`), loaded through the
   application's loader so application and framework classes both resolve
   from any thread. */
int64_t pudu_java_class(const char *name) {
  JNIEnv *env = pudu_env();
  jstring written;
  jobject found;
  int64_t handle;
  if (pudu_loader == NULL) {
    jobject loader = pudu_call_object(env, pudu_activity, "getClassLoader", "()Ljava/lang/ClassLoader;");
    pudu_loader = (*env)->NewGlobalRef(env, loader);
  }
  written = (*env)->NewStringUTF(env, name);
  found = (*env)->CallObjectMethod(env, pudu_loader,
                                   pudu_method_of(env, pudu_loader, "loadClass", "(Ljava/lang/String;)Ljava/lang/Class;"), written);
  (*env)->DeleteLocalRef(env, written);
  if (pudu_caught(env)) return 0;
  handle = pudu_hold(env, found);
  (*env)->DeleteLocalRef(env, found);
  return handle;
}

/* The tagged arguments as JNI values; strings become local references the
   caller deletes. Answers the count, or -1 for a malformed buffer. */
static int pudu_arguments(JNIEnv *env, const uint8_t *bytes, uint64_t length, jvalue *values, int room) {
  uint64_t at = 0;
  int count = 0;
  while (at < length) {
    uint8_t tag = bytes[at++];
    uint64_t wide = 0;
    size_t width = tag == 'Z' || tag == 'B' ? 1 : tag == 'C' || tag == 'S' ? 2 : tag == 'I' || tag == 'F' || tag == 'T' ? 4 : 8;
    if (count == room || at + width > length) return -1;
    for (size_t i = 0; i < width; i++) wide |= (uint64_t)bytes[at + i] << (8 * i);
    at += width;
    switch (tag) {
      case 'Z': values[count].z = wide != 0; break;
      case 'B': values[count].b = (jbyte)wide; break;
      case 'C': values[count].c = (jchar)wide; break;
      case 'S': values[count].s = (jshort)wide; break;
      case 'I': values[count].i = (jint)(uint32_t)wide; break;
      case 'J': values[count].j = (jlong)wide; break;
      case 'F': { uint32_t bits = (uint32_t)wide; memcpy(&values[count].f, &bits, 4); break; }
      case 'D': memcpy(&values[count].d, &wide, 8); break;
      case 'L': values[count].l = pudu_held((int64_t)wide); break;
      case 'T':
        if (at + wide > length) return -1;
        values[count].l = pudu_string(env, (const char *)bytes + at, (size_t)wide);
        at += wide;
        break;
      default: return -1;
    }
    count += 1;
  }
  return count;
}

/* One call, as the program described it. `kind` is the JNI return letter of
   the signature (V Z B C S I J F D L), or N for a constructor. */
typedef struct {
  int64_t target;
  int is_static;
  char kind;
  const char *name, *signature;
  const uint8_t *arguments;
  uint64_t length;
  int64_t whole;
  double real;
  int shown;
} pudu_java_task;

static void pudu_java_perform(JNIEnv *env, pudu_java_task *task) {
  jvalue values[32];
  jobject target = pudu_held(task->target);
  jclass type;
  jmethodID method;
  int count = pudu_arguments(env, task->arguments, task->length, values, 32);
  task->whole = 0;
  task->real = 0;
  if (count < 0 || target == NULL) {
    free(pudu_java_said);
    pudu_java_said = strdup(count < 0 ? "malformed Java arguments" : "a null Java target");
    return;
  }
  if ((*env)->PushLocalFrame(env, count + 8) != 0) return;
  type = task->is_static || task->kind == 'N' ? (jclass)target : (*env)->GetObjectClass(env, target);
  method = task->is_static ? (*env)->GetStaticMethodID(env, type, task->name, task->signature)
                           : (*env)->GetMethodID(env, type, task->kind == 'N' ? "<init>" : task->name, task->signature);
  if (pudu_caught(env)) { (*env)->PopLocalFrame(env, NULL); return; }
#define PUDU_INVOKE(Type) (task->is_static ? (*env)->CallStatic##Type##MethodA(env, type, method, values) \
                                           : (*env)->Call##Type##MethodA(env, target, method, values))
  switch (task->kind) {
    case 'N': {
      jobject made = (*env)->NewObjectA(env, type, method, values);
      if (!pudu_caught(env)) task->whole = pudu_hold(env, made);
      break;
    }
    case 'V': PUDU_INVOKE(Void); break;
    case 'Z': task->whole = PUDU_INVOKE(Boolean); break;
    case 'B': task->whole = PUDU_INVOKE(Byte); break;
    case 'C': task->whole = PUDU_INVOKE(Char); break;
    case 'S': task->whole = PUDU_INVOKE(Short); break;
    case 'I': task->whole = PUDU_INVOKE(Int); break;
    case 'J': task->whole = PUDU_INVOKE(Long); break;
    case 'F': task->real = PUDU_INVOKE(Float); break;
    case 'D': task->real = PUDU_INVOKE(Double); break;
    default: {
      jobject answer = PUDU_INVOKE(Object);
      if (!pudu_caught(env)) task->whole = pudu_hold(env, answer);
      break;
    }
  }
#undef PUDU_INVOKE
  if (pudu_caught(env)) task->whole = 0;
  (*env)->PopLocalFrame(env, NULL);
}

static pthread_mutex_t pudu_java_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t pudu_java_done = PTHREAD_COND_INITIALIZER;

/* PuduBridge.perform, on the main thread: a task the program is waiting on. */
JNIEXPORT void JNICALL Java_org_pudu_PuduBridge_perform(JNIEnv *env, jclass type, jlong handle) {
  pudu_java_task *task = (pudu_java_task *)(intptr_t)handle;
  char *said;
  (void)type;
  pudu_java_perform(env, task);
  /* The failure belongs to the waiting program thread, not the main one. */
  said = pudu_java_said;
  pudu_java_said = NULL;
  pthread_mutex_lock(&pudu_java_lock);
  task->name = said;
  task->shown = 1;
  pthread_cond_broadcast(&pudu_java_done);
  pthread_mutex_unlock(&pudu_java_lock);
}

static pudu_java_task pudu_java_run(pudu_java_task task, int main) {
  JNIEnv *env = pudu_env();
  if (!main) {
    pudu_java_perform(env, &task);
    return task;
  }
  pudu_bridge(env, "runOnMain", "(J)V", (jlong)(intptr_t)&task);
  pthread_mutex_lock(&pudu_java_lock);
  while (!task.shown) pthread_cond_wait(&pudu_java_done, &pudu_java_lock);
  pthread_mutex_unlock(&pudu_java_lock);
  if (task.name != NULL) {
    free(pudu_java_said);
    pudu_java_said = (char *)task.name;
  }
  return task;
}

/* Calls. `target` is an object handle for an instance method, or a class
   handle for a static method or constructor. */
int64_t pudu_java_whole(int64_t target, int is_static, const char *name, const char *signature, const uint8_t *arguments,
                        uint64_t length, int main) {
  const char *answer = strrchr(signature, ')');
  pudu_java_task task = { target, is_static, answer != NULL ? answer[1] : 'V', name, signature, arguments, length, 0, 0, 0 };
  if (task.kind == '[') task.kind = 'L';
  return pudu_java_run(task, main).whole;
}

double pudu_java_real(int64_t target, int is_static, const char *name, const char *signature, const uint8_t *arguments,
                      uint64_t length, int main) {
  const char *answer = strrchr(signature, ')');
  pudu_java_task task = { target, is_static, answer != NULL ? answer[1] : 'D', name, signature, arguments, length, 0, 0, 0 };
  return pudu_java_run(task, main).real;
}

/* A new object of the class handle, through the constructor of `signature`. */
int64_t pudu_java_new(int64_t type, const char *signature, const uint8_t *arguments, uint64_t length, int main) {
  pudu_java_task task = { type, 0, 'N', "<init>", signature, arguments, length, 0, 0, 0 };
  return pudu_java_run(task, main).whole;
}

/* A string handle's text, or the text of any object's toString; empty for null. */
const char *pudu_java_text(int64_t handle) {
  static __thread char *answered;
  JNIEnv *env = pudu_env();
  jobject held = pudu_held(handle);
  jstring text = NULL;
  free(answered);
  answered = NULL;
  if (held != NULL) {
    text = (jstring)(*env)->CallObjectMethod(env, held, pudu_method_of(env, held, "toString", "()Ljava/lang/String;"));
    if (pudu_caught(env)) text = NULL;
  }
  answered = pudu_utf8(env, text);
  if (text != NULL) (*env)->DeleteLocalRef(env, text);
  return answered;
}

/* A Java string made from UTF-8 text. */
int64_t pudu_java_string(const char *text) {
  JNIEnv *env = pudu_env();
  jstring made = pudu_string(env, text, strlen(text));
  int64_t handle = pudu_hold(env, made);
  (*env)->DeleteLocalRef(env, made);
  return handle;
}

/* Fields: read as a whole number, a real or a handle, by the field's JNI type. */
int64_t pudu_java_field(int64_t target, int is_static, const char *name, const char *type) {
  JNIEnv *env = pudu_env();
  jobject held = pudu_held(target);
  jclass owner;
  jfieldID field;
  int64_t answer = 0;
  if (held == NULL) return 0;
  owner = is_static ? (jclass)held : (*env)->GetObjectClass(env, held);
  field = is_static ? (*env)->GetStaticFieldID(env, owner, name, type) : (*env)->GetFieldID(env, owner, name, type);
  if (pudu_caught(env)) return 0;
#define PUDU_FIELD(Type) (is_static ? (*env)->GetStatic##Type##Field(env, owner, field) : (*env)->Get##Type##Field(env, held, field))
  switch (type[0]) {
    case 'Z': answer = PUDU_FIELD(Boolean); break;
    case 'B': answer = PUDU_FIELD(Byte); break;
    case 'C': answer = PUDU_FIELD(Char); break;
    case 'S': answer = PUDU_FIELD(Short); break;
    case 'I': answer = PUDU_FIELD(Int); break;
    case 'J': answer = PUDU_FIELD(Long); break;
    default: {
      jobject value = PUDU_FIELD(Object);
      answer = pudu_caught(env) ? 0 : pudu_hold(env, value);
      if (value != NULL) (*env)->DeleteLocalRef(env, value);
    }
  }
#undef PUDU_FIELD
  if (!is_static) (*env)->DeleteLocalRef(env, owner);
  return pudu_caught(env) ? 0 : answer;
}

/* Arrays: a length, and an element of an object array as a handle. */
int64_t pudu_java_length(int64_t array) {
  JNIEnv *env = pudu_env();
  jobject held = pudu_held(array);
  return held == NULL ? 0 : (*env)->GetArrayLength(env, (jarray)held);
}

int64_t pudu_java_element(int64_t array, int64_t index) {
  JNIEnv *env = pudu_env();
  jobject held = pudu_held(array), item;
  int64_t handle;
  if (held == NULL) return 0;
  item = (*env)->GetObjectArrayElement(env, (jobjectArray)held, (jsize)index);
  if (pudu_caught(env)) return 0;
  handle = pudu_hold(env, item);
  if (item != NULL) (*env)->DeleteLocalRef(env, item);
  return handle;
}

/* Whether two handles name the same Java object. */
int pudu_java_same(int64_t left, int64_t right) {
  JNIEnv *env = pudu_env();
  return (*env)->IsSameObject(env, pudu_held(left), pudu_held(right));
}

#endif
