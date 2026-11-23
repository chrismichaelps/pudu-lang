#ifndef PUDU_ANDROID_SERVICES_H
#define PUDU_ANDROID_SERVICES_H

/* The platform requests that are not about the view: notifications,
   authentication, the browser, speech, the battery, the screen, motion and
   the photo picker. Each handler reads and checks its words here and hands
   the request to the Java side, which answers on the main thread. */
#include <jni.h>
#include <stdint.h>
#include "pudu_android_jni.h"
#include "pudu_android_kinds.h"
#include "pudu_android_nodes.h"

/* NOTIFY: the id, the delay in seconds, the title, then the body. */
static void pudu_do_notify(JNIEnv *env, pudu_reader *reader) {
  uint32_t id = pudu_word(reader), delay = pudu_word(reader);
  jstring title = pudu_text(env, reader), body = pudu_text(env, reader);
  pudu_bridge(env, "notify", "(IJLjava/lang/String;Ljava/lang/String;)V", (jint)id, (jlong)delay, title, body);
}

/* UNNOTIFY: the id. */
static void pudu_do_unnotify(JNIEnv *env, pudu_reader *reader) { pudu_bridge(env, "unnotify", "(I)V", (jint)pudu_word(reader)); }

/* AUTHENTICATE: the tag, then the reason. */
static void pudu_do_authenticate(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  pudu_bridge(env, "authenticate", "(ILjava/lang/String;)V", (jint)tag, pudu_text(env, reader));
}

/* BROWSE: the tag, then the URL. */
static void pudu_do_browse(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  pudu_bridge(env, "browse", "(ILjava/lang/String;)V", (jint)tag, pudu_text(env, reader));
}

/* SPEAK: the tag, the rate in percent, the language tag, then the text. */
static void pudu_do_speak(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader), rate = pudu_word(reader);
  jstring language = pudu_text(env, reader), text = pudu_text(env, reader);
  pudu_bridge(env, "speak", "(IILjava/lang/String;Ljava/lang/String;)V", (jint)tag, (jint)rate, language, text);
}

/* HUSH: no words. */
static void pudu_do_hush(JNIEnv *env, pudu_reader *reader) {
  (void)reader;
  pudu_bridge(env, "hush", "()V");
}

/* BATTERY: the tag. */
static void pudu_do_battery(JNIEnv *env, pudu_reader *reader) { pudu_bridge(env, "battery", "(I)V", (jint)pudu_word(reader)); }

/* BRIGHTNESS: the percent, at most 100. */
static void pudu_do_brightness(JNIEnv *env, pudu_reader *reader) {
  uint32_t percent = pudu_word(reader);
  if (percent > 100) pudu_stream_defect("set brightness to", percent);
  pudu_bridge(env, "brightness", "(I)V", (jint)percent);
}

/* ORIENTATION: 0 any, 1 portrait, 2 landscape. */
static void pudu_do_orientation(JNIEnv *env, pudu_reader *reader) {
  uint32_t code = pudu_word(reader);
  if (code > 2) pudu_stream_defect("locked unknown orientation", code);
  pudu_bridge(env, "orientation", "(I)V", (jint)code);
}

/* SENSE: 1 or 0, then the interval in milliseconds. */
static void pudu_do_sense(JNIEnv *env, pudu_reader *reader) {
  uint32_t on = pudu_word(reader), interval = pudu_word(reader);
  if (on > 1) pudu_stream_defect("set motion sensing to", on);
  pudu_bridge(env, "sense", "(ZI)V", (jboolean)(on == 1), (jint)interval);
}

/* PICK_IMAGE: the tag. */
static void pudu_do_pick_image(JNIEnv *env, pudu_reader *reader) { pudu_bridge(env, "pickImage", "(I)V", (jint)pudu_word(reader)); }

#endif
