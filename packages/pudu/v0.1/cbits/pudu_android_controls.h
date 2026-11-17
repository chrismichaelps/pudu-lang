#ifndef PUDU_ANDROID_CONTROLS_H
#define PUDU_ANDROID_CONTROLS_H

/* The platform controls of the Android host: one factory per control kind,
   the setters each kind accepts, and what a self-test does to a kind and
   reads back. Factories run on the main thread and answer local references;
   the host holds each node globally. Listeners queue events through the
   bridge; a value the host sets is set quietly, so it never echoes back as
   an event the person did not cause. */
#include <jni.h>
#include <stdint.h>
#include "pudu_android_events.h"
#include "pudu_android_jni.h"
#include "pudu_android_theme.h"

/* Factories. A group's spacing is a transparent divider, so children keep
   their own measured sizes, as a stack view's arranged views do. */
static jobject pudu_make_label(JNIEnv *env) {
  jobject label = pudu_new_view(env, "android/widget/TextView");
  pudu_text_style(env, label, 2);
  return label;
}

static jobject pudu_make_button(JNIEnv *env) {
  jobject button = pudu_new_view(env, "android/widget/Button");
  pudu_call(env, button, "setAllCaps", "(Z)V", JNI_FALSE);
  pudu_bridge(env, "listen", "(Landroid/view/View;I)V", button, (jint)PUDU_UI_TAPPED);
  return button;
}

static jobject pudu_make_column(JNIEnv *env) {
  return pudu_bridge_object(env, "group", "(ZI)Landroid/widget/LinearLayout;", JNI_TRUE, pudu_dp(16));
}

static jobject pudu_make_row(JNIEnv *env) {
  return pudu_bridge_object(env, "group", "(ZI)Landroid/widget/LinearLayout;", JNI_FALSE, pudu_dp(12));
}

static jobject pudu_make_field(JNIEnv *env) {
  jobject field = pudu_new_view(env, "android/widget/EditText");
  pudu_call(env, field, "setSingleLine", "(Z)V", JNI_TRUE);
  pudu_call(env, field, "setMinWidth", "(I)V", pudu_dp(220));
  pudu_bridge(env, "listen", "(Landroid/view/View;I)V", field, (jint)PUDU_UI_CHANGED);
  return field;
}

/* A toggle is a switch with its own title, as a labelled platform switch. */
static jobject pudu_make_toggle(JNIEnv *env) {
  jobject toggle = pudu_new_view(env, "android/widget/Switch");
  pudu_bridge(env, "listen", "(Landroid/view/View;I)V", toggle, (jint)PUDU_UI_SWITCHED_ON);
  return toggle;
}

static jobject pudu_make_scroll(JNIEnv *env) { return pudu_bridge_object(env, "scroll", "()Landroid/widget/ScrollView;"); }

/* A material surface: a rounded, translucent panel holding one column. */
static jobject pudu_make_material(JNIEnv *env) {
  return pudu_bridge_object(env, "material", "(I)Landroid/widget/LinearLayout;", pudu_dp(12));
}

static jobject pudu_make_progress(JNIEnv *env) {
  return pudu_bridge_object(env, "progress", "(Z)Landroid/widget/ProgressBar;", JNI_FALSE);
}

static jobject pudu_make_activity(JNIEnv *env) {
  return pudu_bridge_object(env, "progress", "(Z)Landroid/widget/ProgressBar;", JNI_TRUE);
}

/* A system symbol: the platform has no shared symbol set, so the view keeps
   the name as its description and shows nothing, as an unknown symbol does
   on iOS. */
static jobject pudu_make_symbol(JNIEnv *env) { return pudu_new_view(env, "android/widget/ImageView"); }

static jobject pudu_make_text_area(JNIEnv *env) {
  jobject area = pudu_new_view(env, "android/widget/EditText");
  pudu_call(env, area, "setMinLines", "(I)V", (jint)3);
  pudu_call(env, area, "setMinWidth", "(I)V", pudu_dp(220));
  pudu_call(env, area, "setInputType", "(I)V", (jint)0x00020001);
  pudu_bridge(env, "listen", "(Landroid/view/View;I)V", area, (jint)PUDU_UI_CHANGED);
  return area;
}

static jobject pudu_make_search(JNIEnv *env) {
  jobject search = pudu_make_field(env);
  pudu_call(env, search, "setImeOptions", "(I)V", (jint)3);
  return search;
}

/* Setters a kind accepts; a kind without one refuses that instruction. A
   field already showing the text is left alone, so typing keeps its place. */
static void pudu_view_text(JNIEnv *env, jobject view, jstring text) {
  pudu_bridge(env, "quietText", "(Landroid/widget/TextView;Ljava/lang/String;)V", view, text);
}

static void pudu_field_hint(JNIEnv *env, jobject view, jstring hint) {
  pudu_call(env, view, "setHint", "(Ljava/lang/CharSequence;)V", hint);
}

static void pudu_symbol_text(JNIEnv *env, jobject view, jstring name) {
  pudu_call(env, view, "setContentDescription", "(Ljava/lang/CharSequence;)V", name);
}

static void pudu_toggle_state(JNIEnv *env, jobject view, uint32_t on) {
  pudu_bridge(env, "quietChecked", "(Landroid/widget/CompoundButton;Z)V", view, (jboolean)(on != 0));
}

static void pudu_activity_state(JNIEnv *env, jobject view, uint32_t on) {
  pudu_call(env, view, "setVisibility", "(I)V", (jint)(on ? 0 : 4));
}

/* VALUE on a progress bar: thousandths, clamped to a whole. */
static void pudu_progress_value(JNIEnv *env, jobject view, uint32_t permille) {
  pudu_call(env, view, "setProgress", "(I)V", (jint)(permille > 1000 ? 1000 : permille));
}

static void pudu_view_paint(JNIEnv *env, jobject view, jint color) { pudu_text_paint(env, view, color); }
static void pudu_view_style(JNIEnv *env, jobject view, uint32_t code) { pudu_text_style(env, view, code); }

static void pudu_symbol_paint(JNIEnv *env, jobject view, jint color) {
  pudu_call(env, view, "setColorFilter", "(I)V", color);
}

/* The container a group places children in: the group itself, or a scroll
   view's or material's own column. */
static jobject pudu_itself(JNIEnv *env, jobject view) {
  return (*env)->NewLocalRef(env, view);
}

static jobject pudu_inner_column(JNIEnv *env, jobject view) {
  return pudu_bridge_object(env, "inner", "(Landroid/view/ViewGroup;)Landroid/widget/LinearLayout;", view);
}

/* What a self-test does to a kind, and what a kind reports afterward. */
static void pudu_field_fill(JNIEnv *env, jobject view, jstring text) {
  pudu_call(env, view, "setText", "(Ljava/lang/CharSequence;)V", text);
}

static void pudu_toggle_fill(JNIEnv *env, jobject view, jstring text) {
  (void)text;
  pudu_call(env, view, "setChecked", "(Z)V", JNI_TRUE);
}

static void pudu_button_press(JNIEnv *env, jobject view) { (void)pudu_call_int(env, view, "callOnClick", "()Z"); }

static jstring pudu_label_shown(JNIEnv *env, jobject view) {
  jobject text = pudu_call_object(env, view, "getText", "()Ljava/lang/CharSequence;");
  jstring shown = (jstring)pudu_call_object(env, text, "toString", "()Ljava/lang/String;");
  (*env)->DeleteLocalRef(env, text);
  return shown;
}

#endif
