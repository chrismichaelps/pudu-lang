#ifndef PUDU_ANDROID_ROUTES_H
#define PUDU_ANDROID_ROUTES_H

/* NAVIGATE, REFRESH, FETCH, CANCEL and WAKE on Android. Each instruction is
   read and checked whole here, so a defect is refused before anything on the
   screen changes; the Java side then does the platform work on the main
   thread. The checks and their messages are the iOS host's. */
#include <jni.h>
#include <stdint.h>
#include <stdlib.h>
#include "pudu_android_events.h"
#include "pudu_android_jni.h"
#include "pudu_android_kinds.h"
#include "pudu_android_nodes.h"

/* What PuduFetch.start answers. */
enum { PUDU_FETCH_SENT = 0, PUDU_FETCH_REPEATED = 1, PUDU_FETCH_UNREADABLE = 2 };

static int pudu_node_scrolls(uint32_t node) { return pudu_kinds[node] == PUDU_UI_SCROLL || pudu_kinds[node] == PUDU_UI_LIST; }

/* NAVIGATE: the route count, each route's id, body node and title, then 0, or
   1 and the sheet's id and body node. A newer presentation drops pop and
   dismissal reports the program has not read. */
static void pudu_do_navigate(JNIEnv *env, pudu_reader *reader) {
  uint32_t count = pudu_word(reader);
  if (count == 0) pudu_stream_defect("showed a navigation without a root route, count", count);
  jclass view_class = (*env)->FindClass(env, "android/view/View");
  jclass string_class = (*env)->FindClass(env, "java/lang/String");
  jintArray ids = (*env)->NewIntArray(env, (jsize)count);
  jbooleanArray fills = (*env)->NewBooleanArray(env, (jsize)count);
  jobjectArray bodies = (*env)->NewObjectArray(env, (jsize)count, view_class, NULL);
  jobjectArray titles = (*env)->NewObjectArray(env, (jsize)count, string_class, NULL);
  uint32_t *seen = calloc(count, sizeof *seen);
  if (seen == NULL) abort();
  for (uint32_t i = 0; i < count; i++) {
    uint32_t route = pudu_word(reader), node = pudu_node_id(reader);
    jstring title = pudu_text(env, reader);
    jint id = (jint)route;
    jboolean fill = (jboolean)pudu_node_scrolls(node);
    for (uint32_t j = 0; j < i; j++) {
      if (seen[j] == route) pudu_stream_defect("showed two routes with id", route);
    }
    seen[i] = route;
    (*env)->SetIntArrayRegion(env, ids, (jsize)i, 1, &id);
    (*env)->SetBooleanArrayRegion(env, fills, (jsize)i, 1, &fill);
    (*env)->SetObjectArrayElement(env, bodies, (jsize)i, pudu_nodes[node]);
    (*env)->SetObjectArrayElement(env, titles, (jsize)i, title);
    (*env)->DeleteLocalRef(env, title);
  }
  uint32_t present = pudu_word(reader), sheet = 0, sheet_node = 0;
  if (present > 1) pudu_stream_defect("marked a sheet with", present);
  if (present == 1) {
    sheet = pudu_word(reader);
    sheet_node = pudu_node_id(reader);
    for (uint32_t j = 0; j < count; j++) {
      if (seen[j] == sheet) pudu_stream_defect("showed a sheet sharing a route's id", sheet);
    }
  }
  free(seen);
  pudu_unqueue(PUDU_UI_POPPED);
  pudu_unqueue(PUDU_UI_DISMISSED);
  pudu_shown_root = NULL;
  pudu_bridge(env, "navigate", "([I[Landroid/view/View;[Z[Ljava/lang/String;ZILandroid/view/View;Z)V", ids, bodies, fills, titles,
              (jboolean)(present == 1), (jint)sheet, present == 1 ? pudu_nodes[sheet_node] : NULL,
              (jboolean)(present == 1 && pudu_node_scrolls(sheet_node)));
}

/* Run on the program thread before each wait: ends pulls the program read
   without asking to refresh. The tags of pulls still queued go along. */
static void pudu_refresh_settle(void) {
  JNIEnv *env = pudu_env();
  jint tags[PUDU_EVENT_SCAN];
  jsize count = (jsize)pudu_queued_tags(PUDU_UI_REFRESHED, (uint32_t *)tags, PUDU_EVENT_SCAN);
  jintArray queued = (*env)->NewIntArray(env, count);
  (*env)->SetIntArrayRegion(env, queued, 0, count, tags);
  pudu_bridge(env, "settleRefresh", "([I)V", queued);
  (*env)->DeleteLocalRef(env, queued);
}

/* REFRESH: the node, the tag its pulls report, and 1 or 0. */
static void pudu_do_refresh(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), reported = pudu_word(reader), on = pudu_word(reader);
  if (!pudu_node_scrolls(node)) pudu_stream_defect("refreshed a node that does not scroll:", node);
  if (on > 1) pudu_stream_defect("set refreshing to", on);
  pudu_before_wait = pudu_refresh_settle;
  pudu_bridge(env, "refresh", "(Landroid/view/ViewGroup;IZ)V", pudu_nodes[node], (jint)reported, (jboolean)(on == 1));
}

/* FETCH: the generation, method, URL, header count, each header's name and
   value, then the body. Generation 0, a generation in flight, or a URL the
   platform cannot read is a defect of the program. */
static void pudu_do_fetch(JNIEnv *env, pudu_reader *reader) {
  uint32_t generation = pudu_word(reader);
  jstring method = pudu_text(env, reader), url = pudu_text(env, reader);
  uint32_t count = pudu_word(reader);
  jclass string_class = (*env)->FindClass(env, "java/lang/String");
  jobjectArray headers = (*env)->NewObjectArray(env, (jsize)(count * 2), string_class, NULL);
  for (uint32_t i = 0; i < count * 2; i++) {
    jstring part = pudu_text(env, reader);
    (*env)->SetObjectArrayElement(env, headers, (jsize)i, part);
    (*env)->DeleteLocalRef(env, part);
  }
  jstring body = pudu_text(env, reader);
  if (generation == 0) pudu_stream_defect("sent a request without a generation", generation);
  jmethodID start = pudu_static(env, pudu_bridge_class, "fetch", "(ILjava/lang/String;Ljava/lang/String;[Ljava/lang/String;Ljava/lang/String;)I");
  jint answer = (*env)->CallStaticIntMethod(env, pudu_bridge_class, start, (jint)generation, method, url, headers, body);
  pudu_checked(env, "fetch");
  if (answer == PUDU_FETCH_UNREADABLE) pudu_stream_defect("sent a request to an unreadable URL, generation", generation);
  if (answer == PUDU_FETCH_REPEATED) pudu_stream_defect("sent two requests under generation", generation);
}

/* CANCEL: unknown or answered generations are ignored, since the program may
   cancel what has just landed; an unread answer is dropped. */
static void pudu_do_cancel(JNIEnv *env, pudu_reader *reader) {
  uint32_t generation = pudu_word(reader);
  pudu_bridge(env, "cancelFetch", "(I)V", (jint)generation);
  pudu_unqueue_tag(PUDU_UI_FETCHED, generation);
}

/* SOURCE: the origin (0 an asset, 1 a URL), the scaling, then the name or URL. */
static void pudu_do_source(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), origin = pudu_word(reader), scaling = pudu_word(reader);
  jstring location = pudu_text(env, reader);
  if (pudu_kinds[node] != PUDU_UI_IMAGE) pudu_stream_defect("set a source on a node that is not an image:", node);
  if (origin >= 2) pudu_stream_defect("used unknown image origin", origin);
  if (scaling >= 3) pudu_stream_defect("used unknown image scaling", scaling);
  pudu_bridge(env, "source", "(Landroid/widget/ImageView;IILjava/lang/String;)V", pudu_nodes[node], (jint)origin, (jint)scaling, location);
}

/* WAKE: milliseconds until one WOKE event, replacing any earlier wake. */
static void pudu_do_wake(JNIEnv *env, pudu_reader *reader) {
  uint32_t delay = pudu_word(reader);
  pudu_bridge(env, "wake", "(J)V", (jlong)delay);
}

/* OPEN and SHARE: the tag, then the URL or text; COPY: the text; PASTE: the
   tag; STATUS: the style code and 1 to hide the bar or 0 to show it. */
static void pudu_do_open(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  jstring url = pudu_text(env, reader);
  pudu_bridge(env, "open", "(ILjava/lang/String;)V", (jint)tag, url);
}

static void pudu_do_share(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  jstring text = pudu_text(env, reader);
  pudu_bridge(env, "share", "(ILjava/lang/String;)V", (jint)tag, text);
}

static void pudu_do_copy(JNIEnv *env, pudu_reader *reader) {
  pudu_bridge(env, "copy", "(Ljava/lang/String;)V", pudu_text(env, reader));
}

static void pudu_do_paste(JNIEnv *env, pudu_reader *reader) {
  pudu_bridge(env, "paste", "(I)V", (jint)pudu_word(reader));
}

static void pudu_do_status(JNIEnv *env, pudu_reader *reader) {
  uint32_t style = pudu_word(reader), hidden = pudu_word(reader);
  if (style >= 3) pudu_stream_defect("used unknown status bar style", style);
  if (hidden > 1) pudu_stream_defect("set the status bar hidden to", hidden);
  pudu_bridge(env, "status", "(IZ)V", (jint)style, (jboolean)(hidden == 1));
}

#endif
