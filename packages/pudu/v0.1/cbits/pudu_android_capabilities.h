#ifndef PUDU_ANDROID_CAPABILITIES_H
#define PUDU_ANDROID_CAPABILITIES_H

/* The instructions beyond building the tree: materials, gestures, alerts,
   values, haptics, accessibility, menus, motion, bounds, options, page counts
   and moments. Each refuses what the iOS host refuses, with the same words. */
#include <jni.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "pudu_android_nodes.h"
#include "pudu_android_values.h"

static void pudu_do_material(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), code = pudu_word(reader);
  jmethodID set = pudu_static(env, pudu_bridge_class, "materialStyle", "(Landroid/view/View;II)Z");
  if (pudu_kinds[node] != PUDU_UI_MATERIAL) pudu_stream_defect("set a material on a node that is not one:", node);
  if (!(*env)->CallStaticBooleanMethod(env, pudu_bridge_class, set, pudu_nodes[node], (jint)code, pudu_role_color(PUDU_ROLE_SURFACE)))
    pudu_stream_defect("used unknown material", code);
  pudu_checked(env, "materialStyle");
}

/* A count of choices, then each choice's role and label, as arrays. */
static void pudu_choices(JNIEnv *env, pudu_reader *reader, jintArray *roles, jobjectArray *labels, uint32_t known) {
  uint32_t count = pudu_word(reader);
  jclass string = (*env)->FindClass(env, "java/lang/String");
  *roles = (*env)->NewIntArray(env, (jsize)count);
  *labels = (*env)->NewObjectArray(env, (jsize)count, string, NULL);
  for (uint32_t i = 0; i < count; i++) {
    jint role = (jint)pudu_word(reader);
    jstring label = pudu_text(env, reader);
    if ((uint32_t)role >= known) pudu_stream_defect("gave a choice an unknown role, index", i);
    (*env)->SetIntArrayRegion(env, *roles, (jsize)i, 1, &role);
    (*env)->SetObjectArrayElement(env, *labels, (jsize)i, label);
    (*env)->DeleteLocalRef(env, label);
  }
}

static void pudu_do_gestures(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), tag = pudu_word(reader), mask = pudu_word(reader);
  if (mask >= 32) pudu_stream_defect("used unknown gestures", mask);
  pudu_bridge(env, "gestures", "(Landroid/view/View;II)V", pudu_nodes[node], (jint)tag, (jint)mask);
}

static void pudu_do_alert(JNIEnv *env, pudu_reader *reader) {
  uint32_t tag = pudu_word(reader), style = pudu_word(reader);
  jstring title = pudu_text(env, reader), message = pudu_text(env, reader);
  jintArray roles;
  jobjectArray labels;
  if (style > 1) pudu_stream_defect("showed an alert with an unknown style or role, tag", tag);
  pudu_choices(env, reader, &roles, &labels, 3);
  pudu_bridge(env, "alert", "(IILjava/lang/String;Ljava/lang/String;[I[Ljava/lang/String;)V", (jint)tag, (jint)style,
              title, message, roles, labels);
  if (pudu_self_testing) {
    char *said = pudu_utf8(env, title);
    printf("PUDU_ALERT %s\n", said);
    free(said);
  }
}

static void pudu_do_value(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), word = pudu_word(reader);
  const pudu_kind *kind = pudu_node_kind(node);
  if (kind->number == NULL) pudu_stream_defect("set a value on a node that holds none:", node);
  if (kind->choosing && (jint)word >= pudu_choice_count(env, pudu_nodes[node]))
    pudu_stream_defect(pudu_kinds[node] == PUDU_UI_WHEEL ? "selected past the last row:" : "selected past the last segment:", word);
  kind->number(env, pudu_nodes[node], word);
}

static void pudu_do_haptic(JNIEnv *env, pudu_reader *reader) {
  uint32_t code = pudu_word(reader);
  if (code == 0 || code >= 8) pudu_stream_defect("played unknown haptic", code);
  pudu_bridge(env, "haptic", "(I)V", (jint)code);
  if (pudu_self_testing) printf("PUDU_HAPTIC %u\n", code);
}

static void pudu_do_traits(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), mask = pudu_word(reader);
  if (mask >= (1u << 19)) pudu_stream_defect("used unknown accessibility traits", mask);
  pudu_bridge(env, "traits", "(Landroid/view/View;I)V", pudu_nodes[node], (jint)mask);
}

static void pudu_do_access_text(JNIEnv *env, pudu_reader *reader, const char *which) {
  uint32_t node = pudu_node_id(reader);
  pudu_bridge(env, which, "(Landroid/view/View;Ljava/lang/String;)V", pudu_nodes[node], pudu_text(env, reader));
}

static void pudu_do_access_hint(JNIEnv *env, pudu_reader *reader) { pudu_do_access_text(env, reader, "accessHint"); }
static void pudu_do_access_value(JNIEnv *env, pudu_reader *reader) { pudu_do_access_text(env, reader, "accessValue"); }

static void pudu_do_menu(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), tag = pudu_word(reader);
  jintArray roles;
  jobjectArray labels;
  pudu_choices(env, reader, &roles, &labels, 3);
  pudu_bridge(env, "menu", "(Landroid/view/View;I[I[Ljava/lang/String;)V", pudu_nodes[node], (jint)tag, roles, labels);
}

static void pudu_do_animate(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), on = pudu_word(reader);
  const pudu_kind *kind = pudu_node_kind(node);
  if (kind->children == NULL) pudu_stream_defect("placed a child in a node that holds nothing:", node);
  pudu_bridge(env, "animate", "(Landroid/view/ViewGroup;Z)V", kind->children(env, pudu_nodes[node]), (jboolean)(on != 0));
}

/* BOUNDS: low, high and step as signed words; an inverted range or a step
   below one is refused. */
static void pudu_do_bounds(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  int32_t low = (int32_t)pudu_word(reader), high = (int32_t)pudu_word(reader), step = (int32_t)pudu_word(reader);
  if (pudu_node_kind(node)->bounds == NULL) pudu_stream_defect("bounded a node that takes no bounds:", node);
  if (high < low || step < 1) pudu_stream_defect("set an inverted range or a step below one on node", node);
  pudu_node_kind(node)->bounds(env, pudu_nodes[node], low, high, step);
}

static void pudu_do_options(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), count = pudu_word(reader);
  jclass string = (*env)->FindClass(env, "java/lang/String");
  jobjectArray labels;
  if (pudu_node_kind(node)->options == NULL) pudu_stream_defect("gave options to a node that takes none:", node);
  if (count == 0) pudu_stream_defect("gave no options to node", node);
  labels = (*env)->NewObjectArray(env, (jsize)count, string, NULL);
  for (uint32_t i = 0; i < count; i++) {
    jstring label = pudu_text(env, reader);
    (*env)->SetObjectArrayElement(env, labels, (jsize)i, label);
    (*env)->DeleteLocalRef(env, label);
  }
  pudu_node_kind(node)->options(env, pudu_nodes[node], labels);
}

static void pudu_do_count(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), total = pudu_word(reader);
  if (pudu_kinds[node] != PUDU_UI_PAGES) pudu_stream_defect("counted pages on a node that is not a page control:", node);
  pudu_pages_count(env, pudu_nodes[node], total);
}

/* MOMENT: the mode, then the seconds as the high and low words. */
static void pudu_do_moment(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), mode = pudu_word(reader);
  int64_t high = (int32_t)pudu_word(reader);
  int64_t seconds = (int64_t)((uint64_t)high << 32) | (int64_t)pudu_word(reader);
  if (pudu_kinds[node] != PUDU_UI_DATE) pudu_stream_defect("set a moment on a node that is not a date picker:", node);
  if (mode >= PUDU_MOMENTS) pudu_stream_defect("used unknown date mode", mode);
  pudu_date_moment(env, pudu_nodes[node], mode, seconds);
}

#endif
