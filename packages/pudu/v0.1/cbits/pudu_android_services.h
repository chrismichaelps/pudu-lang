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

/* LOAD: the node, then the URL. */
static void pudu_do_load(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  if (pudu_kinds[node] != PUDU_UI_WEB) pudu_stream_defect("loaded a page into a node that is not a web view:", node);
  pudu_bridge(env, "load", "(Landroid/webkit/WebView;Ljava/lang/String;)V", pudu_nodes[node], pudu_text(env, reader));
}

/* MEDIA: the node, playing, looping, then the source. */
static void pudu_do_media(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  if (pudu_kinds[node] != PUDU_UI_VIDEO) pudu_stream_defect("set media on a node that is not a video:", node);
  uint32_t playing = pudu_word(reader), looping = pudu_word(reader);
  if (playing > 1 || looping > 1) pudu_stream_defect("set a media flag to", playing > 1 ? playing : looping);
  pudu_bridge(env, "media", "(Landroid/widget/VideoView;ZZLjava/lang/String;)V", pudu_nodes[node], (jboolean)(playing == 1),
              (jboolean)(looping == 1), pudu_text(env, reader));
}

/* AUDIO: the tag, playing, looping, then the source. */
static void pudu_do_audio(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader), playing = pudu_word(reader), looping = pudu_word(reader);
  if (playing > 1 || looping > 1) pudu_stream_defect("set a media flag to", playing > 1 ? playing : looping);
  pudu_bridge(env, "audio", "(IZZLjava/lang/String;)V", (jint)tag, (jboolean)(playing == 1), (jboolean)(looping == 1), pudu_text(env, reader));
}

/* KEYBOARD: no words. */
static void pudu_do_keyboard(JNIEnv *env, pudu_reader *reader) {
  (void)reader;
  pudu_bridge(env, "keyboard", "()V");
}

/* BACK: 1 to receive back as BACKED, 0 to return it to the platform. */
static void pudu_do_back(JNIEnv *env, pudu_reader *reader) {
  uint32_t on = pudu_word(reader);
  if (on > 1) pudu_stream_defect("set back handling to", on);
  pudu_bridge(env, "back", "(Z)V", (jboolean)(on == 1));
}

/* PICK_CONTACT: the tag; PICK_DOCUMENT: the tag, then the MIME types;
   TAKE_PHOTO: the tag; RECORD: the tag, then 1 or 0. */
static void pudu_do_pick_contact(JNIEnv *env, pudu_reader *reader) { pudu_bridge(env, "pickContact", "(I)V", (jint)pudu_word(reader)); }

static void pudu_do_pick_document(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  pudu_bridge(env, "pickDocument", "(ILjava/lang/String;)V", (jint)tag, pudu_text(env, reader));
}

static void pudu_do_take_photo(JNIEnv *env, pudu_reader *reader) { pudu_bridge(env, "takePhoto", "(I)V", (jint)pudu_word(reader)); }

static void pudu_do_record(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader), on = pudu_word(reader);
  if (on > 1) pudu_stream_defect("set recording to", on);
  pudu_bridge(env, "record", "(IZ)V", (jint)tag, (jboolean)(on == 1));
}

/* BADGE: the count; launchers here count notifications, so it is read and ignored. */
static void pudu_do_badge(JNIEnv *env, pudu_reader *reader) {
  (void)env;
  (void)pudu_word(reader);
}

/* SECURE: 1 or 0; TOAST: the text. */
static void pudu_do_secure(JNIEnv *env, pudu_reader *reader) {
  uint32_t on = pudu_word(reader);
  if (on > 1) pudu_stream_defect("set secure screen to", on);
  pudu_bridge(env, "secure", "(Z)V", (jboolean)(on == 1));
}

static void pudu_do_toast(JNIEnv *env, pudu_reader *reader) { pudu_bridge(env, "toast", "(Ljava/lang/String;)V", pudu_text(env, reader)); }

/* Unix seconds from a high signed word and a low word. */
static jlong pudu_seconds(pudu_reader *reader) {
  int32_t high = (int32_t)pudu_word(reader);
  uint32_t low = pudu_word(reader);
  return (jlong)high * 4294967296LL + (jlong)low;
}

/* SHARE_FILE: the tag, then the path. */
static void pudu_do_share_file(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  pudu_bridge(env, "shareFile", "(ILjava/lang/String;)V", (jint)tag, pudu_text(env, reader));
}

/* REVIEW: no words; there is no system rating prompt here. */
static void pudu_do_review(JNIEnv *env, pudu_reader *reader) {
  (void)env;
  (void)reader;
}

/* ADD_EVENT: the tag, the start and end seconds, the title, then the location. */
static void pudu_do_add_event(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  jlong start = pudu_seconds(reader), end = pudu_seconds(reader);
  jstring title = pudu_text(env, reader), location = pudu_text(env, reader);
  pudu_bridge(env, "addEvent", "(IJJLjava/lang/String;Ljava/lang/String;)V", (jint)tag, start, end, title, location);
}

/* COMPOSE_MAIL: the tag, the recipients, the subject, then the body. */
static void pudu_do_compose_mail(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  jstring to = pudu_text(env, reader), subject = pudu_text(env, reader), body = pudu_text(env, reader);
  pudu_bridge(env, "composeMail", "(ILjava/lang/String;Ljava/lang/String;Ljava/lang/String;)V", (jint)tag, to, subject, body);
}

/* COMPOSE_MESSAGE: the tag, the recipients, then the body. */
static void pudu_do_compose_message(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  jstring to = pudu_text(env, reader), body = pudu_text(env, reader);
  pudu_bridge(env, "composeMessage", "(ILjava/lang/String;Ljava/lang/String;)V", (jint)tag, to, body);
}

#endif
