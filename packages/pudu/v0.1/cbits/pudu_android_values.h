#ifndef PUDU_ANDROID_VALUES_H
#define PUDU_ANDROID_VALUES_H

/* Controls that hold a value: slider, stepper, segmented control, wheel,
   date picker, page control and color well. Values cross the stream as exact
   integers, as on iOS. A slider runs in step indexes, so its value stays
   exact whatever its range; a stepper and a wheel are number pickers over
   step indexes and option indexes. The listeners the bridge attaches report
   the stepped value, the index, the moment or the color the person chose. */
#include <jni.h>
#include <stdint.h>
#include "pudu_android_events.h"
#include "pudu_android_jni.h"

enum { PUDU_MOMENTS = 3 };

static jobject pudu_make_slider(JNIEnv *env) {
  jobject slider = pudu_new_view(env, "android/widget/SeekBar");
  pudu_call(env, slider, "setMinimumWidth", "(I)V", pudu_dp(220));
  pudu_bridge(env, "listen", "(Landroid/view/View;I)V", slider, (jint)PUDU_UI_VALUED);
  return slider;
}

static jobject pudu_make_stepper(JNIEnv *env) {
  jobject stepper = pudu_new_view(env, "android/widget/NumberPicker");
  pudu_bridge(env, "listen", "(Landroid/view/View;I)V", stepper, (jint)PUDU_UI_VALUED);
  return stepper;
}

static jobject pudu_make_segments(JNIEnv *env) {
  jobject segments = pudu_new_view(env, "android/widget/RadioGroup");
  pudu_call(env, segments, "setOrientation", "(I)V", (jint)0);
  pudu_bridge(env, "listen", "(Landroid/view/View;I)V", segments, (jint)PUDU_UI_VALUED);
  return segments;
}

static jobject pudu_make_wheel(JNIEnv *env) {
  jobject wheel = pudu_new_view(env, "android/widget/NumberPicker");
  pudu_call(env, wheel, "setWrapSelectorWheel", "(Z)V", JNI_FALSE);
  pudu_bridge(env, "listen", "(Landroid/view/View;I)V", wheel, (jint)PUDU_UI_VALUED);
  return wheel;
}

static jobject pudu_make_date(JNIEnv *env) { return pudu_new_view(env, "org/pudu/PuduMoment"); }
static jobject pudu_make_pages(JNIEnv *env) { return pudu_new_view(env, "org/pudu/PuduPages"); }
static jobject pudu_make_well(JNIEnv *env) { return pudu_new_view(env, "org/pudu/PuduWell"); }

/* BOUNDS: the host has refused an inverted range or a step below one. A
   slider's range is its step count; the listener maps an index back to its
   value. A stepper shows each step's value as its own label. */
static void pudu_slider_bounds(JNIEnv *env, jobject view, int32_t low, int32_t high, int32_t step) {
  int64_t steps = ((int64_t)high - low) / step;
  pudu_call(env, view, "setMax", "(I)V", (jint)steps);
  pudu_bridge(env, "stepped", "(Landroid/view/View;II)V", view, (jint)low, (jint)step);
}

static void pudu_stepper_bounds(JNIEnv *env, jobject view, int32_t low, int32_t high, int32_t step) {
  pudu_bridge(env, "steps", "(Landroid/widget/NumberPicker;III)V", view, (jint)low, (jint)high, (jint)step);
}

/* OPTIONS: the host has refused an empty list. */
static void pudu_choice_options(JNIEnv *env, jobject view, jobjectArray labels) {
  pudu_bridge(env, "options", "(Landroid/view/View;[Ljava/lang/String;)V", view, labels);
}

/* VALUE setters, one per kind that holds a number. */
static void pudu_slider_number(JNIEnv *env, jobject view, uint32_t word) {
  pudu_bridge(env, "slide", "(Landroid/widget/SeekBar;I)V", view, (jint)(int32_t)word);
}

static void pudu_stepper_number(JNIEnv *env, jobject view, uint32_t word) {
  pudu_bridge(env, "step", "(Landroid/widget/NumberPicker;I)V", view, (jint)(int32_t)word);
}

/* A selected index past the last option was refused by the host. */
static void pudu_choice_number(JNIEnv *env, jobject view, uint32_t index) {
  pudu_bridge(env, "select", "(Landroid/view/View;I)V", view, (jint)index);
}

static void pudu_pages_number(JNIEnv *env, jobject view, uint32_t page) {
  pudu_call(env, view, "current", "(I)V", (jint)page);
}

static void pudu_well_number(JNIEnv *env, jobject view, uint32_t rgba) {
  /* The well's packed form puts red in the high byte. */
  uint32_t red = rgba >> 24 & 0xff, green = rgba >> 16 & 0xff, blue = rgba >> 8 & 0xff, alpha = rgba & 0xff;
  pudu_call(env, view, "color", "(I)V", (jint)(alpha << 24 | red << 16 | green << 8 | blue));
}

/* How many choices a segmented control or wheel offers, for the host's
   bounds check on VALUE. */
static jint pudu_choice_count(JNIEnv *env, jobject view) {
  jmethodID count = pudu_static(env, pudu_bridge_class, "optionCount", "(Landroid/view/View;)I");
  jint answer = (*env)->CallStaticIntMethod(env, pudu_bridge_class, count, view);
  pudu_checked(env, "optionCount");
  return answer;
}

/* COUNT and MOMENT. */
static void pudu_pages_count(JNIEnv *env, jobject view, uint32_t total) {
  pudu_call(env, view, "count", "(I)V", (jint)total);
}

static void pudu_date_moment(JNIEnv *env, jobject view, uint32_t mode, int64_t seconds) {
  pudu_call(env, view, "show", "(IJ)V", (jint)mode, (jlong)seconds);
}

/* What the controls self-test does to each value kind, as on iOS: one change
   followed by the event the platform sends for it. */
static void pudu_slider_drive(JNIEnv *env, jobject view) { pudu_bridge(env, "driveSlider", "(Landroid/widget/SeekBar;)V", view); }
static void pudu_stepper_drive(JNIEnv *env, jobject view) { pudu_bridge(env, "driveStepper", "(Landroid/widget/NumberPicker;)V", view); }
static void pudu_choice_drive(JNIEnv *env, jobject view) { pudu_bridge(env, "driveChoice", "(Landroid/view/View;)V", view); }
static void pudu_date_drive(JNIEnv *env, jobject view) { pudu_call(env, view, "pick", "(J)V", (jlong)1000000000); }
static void pudu_pages_drive(JNIEnv *env, jobject view) { pudu_call(env, view, "pick", "(I)V", (jint)2); }
static void pudu_well_drive(JNIEnv *env, jobject view) { pudu_call(env, view, "pick", "(I)V", (jint)0xffff8000); }

#endif
