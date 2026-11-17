#ifndef PUDU_ANDROID_JNI_H
#define PUDU_ANDROID_JNI_H

/* The Java side of the Android host as C sees it: the virtual machine, the
   environment of the calling thread, the activity and its root group, and
   the calls the host makes into framework views. Every view call runs on the
   main thread; the program thread only posts commits and waits for events.
   A Java exception during a host call is a defect of the host, reported and
   fatal, as a malformed stream is. */
#include <android/log.h>
#include <jni.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static JavaVM *pudu_vm;
static jobject pudu_activity;
static jobject pudu_root_group;
static jclass pudu_bridge_class;
static jclass pudu_listener_class;
static float pudu_density = 1.0f;

static _Noreturn void pudu_host_defect(const char *problem) {
  __android_log_print(ANDROID_LOG_FATAL, "pudu", "host defect: %s", problem);
  abort();
}

/* The calling thread's environment, attaching a thread the VM has not seen. */
static JNIEnv *pudu_env(void) {
  JNIEnv *env = NULL;
  if ((*pudu_vm)->GetEnv(pudu_vm, (void **)&env, JNI_VERSION_1_6) == JNI_EDETACHED &&
      (*pudu_vm)->AttachCurrentThread(pudu_vm, &env, NULL) != JNI_OK) {
    pudu_host_defect("a thread could not attach to the virtual machine");
  }
  return env;
}

static void pudu_checked(JNIEnv *env, const char *during) {
  if ((*env)->ExceptionCheck(env)) {
    (*env)->ExceptionDescribe(env);
    (*env)->ExceptionClear(env);
    pudu_host_defect(during);
  }
}

/* A framework or bridge class, held for the life of the program. Classes are
   looked up on the main thread, whose loader sees the application's own. */
static jclass pudu_class(JNIEnv *env, const char *name) {
  jclass local = (*env)->FindClass(env, name);
  jclass held;
  pudu_checked(env, name);
  held = (*env)->NewGlobalRef(env, local);
  (*env)->DeleteLocalRef(env, local);
  return held;
}

static jmethodID pudu_method(JNIEnv *env, jclass type, const char *name, const char *signature) {
  jmethodID found = (*env)->GetMethodID(env, type, name, signature);
  pudu_checked(env, name);
  return found;
}

static jmethodID pudu_static(JNIEnv *env, jclass type, const char *name, const char *signature) {
  jmethodID found = (*env)->GetStaticMethodID(env, type, name, signature);
  pudu_checked(env, name);
  return found;
}

/* A method of the object's own class, looked up per call; the host's calls
   happen once per instruction, not per frame. */
static jmethodID pudu_method_of(JNIEnv *env, jobject target, const char *name, const char *signature) {
  jclass type = (*env)->GetObjectClass(env, target);
  jmethodID found = pudu_method(env, type, name, signature);
  (*env)->DeleteLocalRef(env, type);
  return found;
}

static void pudu_call(JNIEnv *env, jobject target, const char *name, const char *signature, ...) {
  va_list arguments;
  jmethodID method = pudu_method_of(env, target, name, signature);
  va_start(arguments, signature);
  (*env)->CallVoidMethodV(env, target, method, arguments);
  va_end(arguments);
  pudu_checked(env, name);
}

static jint pudu_call_int(JNIEnv *env, jobject target, const char *name, const char *signature, ...) {
  va_list arguments;
  jint answer;
  jmethodID method = pudu_method_of(env, target, name, signature);
  va_start(arguments, signature);
  answer = (*env)->CallIntMethodV(env, target, method, arguments);
  va_end(arguments);
  pudu_checked(env, name);
  return answer;
}

static jobject pudu_call_object(JNIEnv *env, jobject target, const char *name, const char *signature, ...) {
  va_list arguments;
  jobject answer;
  jmethodID method = pudu_method_of(env, target, name, signature);
  va_start(arguments, signature);
  answer = (*env)->CallObjectMethodV(env, target, method, arguments);
  va_end(arguments);
  pudu_checked(env, name);
  return answer;
}

/* A static bridge method; the bridge owns everything the framework only
   offers to Java code: listeners, dialogs, adapters and widgets without a
   framework class. */
static void pudu_bridge(JNIEnv *env, const char *name, const char *signature, ...) {
  va_list arguments;
  jmethodID method = pudu_static(env, pudu_bridge_class, name, signature);
  va_start(arguments, signature);
  (*env)->CallStaticVoidMethodV(env, pudu_bridge_class, method, arguments);
  va_end(arguments);
  pudu_checked(env, name);
}

static jobject pudu_bridge_object(JNIEnv *env, const char *name, const char *signature, ...) {
  va_list arguments;
  jobject answer;
  jmethodID method = pudu_static(env, pudu_bridge_class, name, signature);
  va_start(arguments, signature);
  answer = (*env)->CallStaticObjectMethodV(env, pudu_bridge_class, method, arguments);
  va_end(arguments);
  pudu_checked(env, name);
  return answer;
}

/* A new framework view of the named class, made for the activity. */
static jobject pudu_new_view(JNIEnv *env, const char *name) {
  jclass type = (*env)->FindClass(env, name);
  jobject made;
  pudu_checked(env, name);
  made = (*env)->NewObject(env, type, pudu_method(env, type, "<init>", "(Landroid/content/Context;)V"), pudu_activity);
  pudu_checked(env, name);
  (*env)->DeleteLocalRef(env, type);
  return made;
}

/* UTF-8 bytes as a Java string; the stream's text is always valid UTF-8 the
   program produced, but Java's modified UTF-8 differs for code points past
   the basic plane, so text crosses as bytes decoded by the bridge. */
static jstring pudu_string(JNIEnv *env, const char *bytes, size_t length) {
  jbyteArray raw = (*env)->NewByteArray(env, (jsize)length);
  jstring text;
  (*env)->SetByteArrayRegion(env, raw, 0, (jsize)length, (const jbyte *)bytes);
  text = (jstring)pudu_bridge_object(env, "decode", "([B)Ljava/lang/String;", raw);
  (*env)->DeleteLocalRef(env, raw);
  return text;
}

/* A Java string as newly allocated UTF-8; the caller frees it. */
static char *pudu_utf8(JNIEnv *env, jstring text) {
  jbyteArray raw;
  jsize length;
  char *copy;
  if (text == NULL) return strdup("");
  raw = (jbyteArray)pudu_bridge_object(env, "encode", "(Ljava/lang/String;)[B", text);
  length = (*env)->GetArrayLength(env, raw);
  copy = malloc((size_t)length + 1);
  if (copy == NULL) abort();
  (*env)->GetByteArrayRegion(env, raw, 0, length, (jbyte *)copy);
  copy[length] = 0;
  (*env)->DeleteLocalRef(env, raw);
  return copy;
}

/* Density-independent pixels to the screen's pixels. */
static jint pudu_dp(float points) { return (jint)(points * pudu_density + 0.5f); }

#endif
