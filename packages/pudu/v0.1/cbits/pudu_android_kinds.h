#ifndef PUDU_ANDROID_KINDS_H
#define PUDU_ANDROID_KINDS_H

/* The view stream's instruction codes and control kinds, and what each kind
   accepts on Android. An instruction a kind has no entry for is refused by
   the host, as on iOS. */
#include <jni.h>
#include <stdint.h>
#include "pudu_android_controls.h"
#include "pudu_android_list.h"
#include "pudu_android_values.h"

/* Instruction codes and control kinds; they match Std.Mobile.Stream. */
enum { PUDU_UI_CREATE = 1, PUDU_UI_TEXT = 2, PUDU_UI_APPEND = 3, PUDU_UI_ROOT = 4, PUDU_UI_TAG = 5, PUDU_UI_RESET = 6,
       PUDU_UI_STATE = 7, PUDU_UI_HINT = 8, PUDU_UI_NAME = 9, PUDU_UI_INSERT = 10, PUDU_UI_REMOVE = 11, PUDU_UI_MOVE = 12,
       PUDU_UI_THEME = 20, PUDU_UI_APPEARANCE = 21, PUDU_UI_STYLE = 22, PUDU_UI_COLOR = 23, PUDU_UI_RANGE = 24,
       PUDU_UI_COLUMNS = 25, PUDU_UI_MATERIAL_SET = 26, PUDU_UI_GESTURES = 27,
       PUDU_UI_ALERT = 28, PUDU_UI_VALUE = 29, PUDU_UI_HAPTIC = 30, PUDU_UI_TRAITS = 31, PUDU_UI_ACCESS_HINT = 32,
       PUDU_UI_ACCESS_VALUE = 33, PUDU_UI_MENU = 34, PUDU_UI_ANIMATE = 35, PUDU_UI_NAVIGATE = 36, PUDU_UI_REFRESH = 37,
       PUDU_UI_FETCH = 38, PUDU_UI_CANCEL = 39, PUDU_UI_WAKE = 40, PUDU_UI_BOUNDS = 41, PUDU_UI_OPTIONS = 42,
       PUDU_UI_COUNT = 43, PUDU_UI_MOMENT = 44, PUDU_UI_SOURCE = 45, PUDU_UI_OPEN = 46,
       PUDU_UI_SHARE = 47, PUDU_UI_COPY = 48, PUDU_UI_PASTE = 49, PUDU_UI_STATUS = 50, PUDU_UI_INSTRUCTIONS = 51 };
enum { PUDU_UI_LABEL = 1, PUDU_UI_BUTTON = 2, PUDU_UI_COLUMN = 3, PUDU_UI_ROW = 4, PUDU_UI_FIELD = 5, PUDU_UI_TOGGLE = 6,
       PUDU_UI_SCROLL = 7, PUDU_UI_LIST = 8, PUDU_UI_MATERIAL = 9, PUDU_UI_PROGRESS = 10, PUDU_UI_ACTIVITY = 11,
       PUDU_UI_SLIDER = 12, PUDU_UI_STEPPER = 13, PUDU_UI_SEGMENTS = 14, PUDU_UI_WHEEL = 15, PUDU_UI_DATE = 16,
       PUDU_UI_TEXT_AREA = 17, PUDU_UI_SEARCH = 18, PUDU_UI_SYMBOL = 19, PUDU_UI_PAGES = 20, PUDU_UI_WELL = 21,
       PUDU_UI_IMAGE = 22, PUDU_UI_KINDS = 23 };

typedef struct {
  jobject (*make)(JNIEnv *);
  void (*text)(JNIEnv *, jobject, jstring);
  void (*hint)(JNIEnv *, jobject, jstring);
  void (*state)(JNIEnv *, jobject, uint32_t);
  /* The group a placement puts children in; a list places into its rows. */
  jobject (*children)(JNIEnv *, jobject);
  void (*fill)(JNIEnv *, jobject, jstring);
  void (*press)(JNIEnv *, jobject);
  jstring (*shown)(JNIEnv *, jobject);
  /* Text color and size; a kind without them refuses COLOR and STYLE. */
  void (*paint)(JNIEnv *, jobject, jint);
  void (*style)(JNIEnv *, jobject, uint32_t);
  /* Whether the kind takes Ink without a COLOR; buttons follow the accent. */
  int inked;
  /* VALUE, BOUNDS and OPTIONS; a kind without one refuses that instruction. */
  void (*number)(JNIEnv *, jobject, uint32_t);
  void (*bounds)(JNIEnv *, jobject, int32_t, int32_t, int32_t);
  void (*options)(JNIEnv *, jobject, jobjectArray);
  /* What the controls self-test does to the kind. */
  void (*drive)(JNIEnv *, jobject);
  /* A list's children are its window rows; a choosing kind bounds VALUE by its options. */
  int listed, choosing;
} pudu_kind;

static jobject pudu_no_list(JNIEnv *env) { (void)env; return NULL; }
static jobject pudu_make_image(JNIEnv *env) { return pudu_bridge_object(env, "image", "()Landroid/widget/ImageView;"); }
static void pudu_text_area_drive(JNIEnv *env, jobject view) {
  jstring notes = (*env)->NewStringUTF(env, "Notes");
  pudu_field_fill(env, view, notes);
  (*env)->DeleteLocalRef(env, notes);
}
static void pudu_search_drive(JNIEnv *env, jobject view) {
  jstring typed = (*env)->NewStringUTF(env, "pudu");
  pudu_field_fill(env, view, typed);
  (*env)->DeleteLocalRef(env, typed);
}

static const pudu_kind pudu_kind_table[PUDU_UI_KINDS] = {
  [PUDU_UI_LABEL] = { .make = pudu_make_label, .text = pudu_view_text, .shown = pudu_label_shown, .paint = pudu_view_paint,
                      .style = pudu_view_style, .inked = 1 },
  [PUDU_UI_BUTTON] = { .make = pudu_make_button, .text = pudu_view_text, .press = pudu_button_press, .paint = pudu_view_paint,
                       .style = pudu_view_style },
  [PUDU_UI_COLUMN] = { .make = pudu_make_column, .children = pudu_itself },
  [PUDU_UI_ROW] = { .make = pudu_make_row, .children = pudu_itself },
  [PUDU_UI_FIELD] = { .make = pudu_make_field, .text = pudu_view_text, .hint = pudu_field_hint, .fill = pudu_field_fill,
                      .paint = pudu_view_paint, .style = pudu_view_style, .inked = 1 },
  [PUDU_UI_TOGGLE] = { .make = pudu_make_toggle, .text = pudu_view_text, .state = pudu_toggle_state, .fill = pudu_toggle_fill,
                       .paint = pudu_view_paint, .style = pudu_view_style, .inked = 1 },
  [PUDU_UI_SCROLL] = { .make = pudu_make_scroll, .children = pudu_inner_column },
  [PUDU_UI_LIST] = { .make = pudu_no_list, .listed = 1 },
  [PUDU_UI_MATERIAL] = { .make = pudu_make_material, .children = pudu_inner_column },
  [PUDU_UI_PROGRESS] = { .make = pudu_make_progress, .number = pudu_progress_value },
  [PUDU_UI_ACTIVITY] = { .make = pudu_make_activity, .state = pudu_activity_state },
  [PUDU_UI_SLIDER] = { .make = pudu_make_slider, .number = pudu_slider_number, .bounds = pudu_slider_bounds, .drive = pudu_slider_drive },
  [PUDU_UI_STEPPER] = { .make = pudu_make_stepper, .number = pudu_stepper_number, .bounds = pudu_stepper_bounds, .drive = pudu_stepper_drive },
  [PUDU_UI_SEGMENTS] = { .make = pudu_make_segments, .number = pudu_choice_number, .options = pudu_choice_options,
                         .drive = pudu_choice_drive, .choosing = 1 },
  [PUDU_UI_WHEEL] = { .make = pudu_make_wheel, .number = pudu_choice_number, .options = pudu_choice_options,
                      .drive = pudu_choice_drive, .choosing = 1 },
  [PUDU_UI_DATE] = { .make = pudu_make_date, .drive = pudu_date_drive },
  [PUDU_UI_TEXT_AREA] = { .make = pudu_make_text_area, .text = pudu_view_text, .fill = pudu_field_fill, .paint = pudu_view_paint,
                          .style = pudu_view_style, .inked = 1, .drive = pudu_text_area_drive },
  [PUDU_UI_SEARCH] = { .make = pudu_make_search, .text = pudu_view_text, .hint = pudu_field_hint, .fill = pudu_field_fill,
                       .paint = pudu_view_paint, .style = pudu_view_style, .inked = 1, .drive = pudu_search_drive },
  [PUDU_UI_SYMBOL] = { .make = pudu_make_symbol, .text = pudu_symbol_text, .paint = pudu_symbol_paint },
  [PUDU_UI_PAGES] = { .make = pudu_make_pages, .number = pudu_pages_number, .drive = pudu_pages_drive },
  [PUDU_UI_WELL] = { .make = pudu_make_well, .number = pudu_well_number, .drive = pudu_well_drive },
  [PUDU_UI_IMAGE] = { .make = pudu_make_image },
};

#endif
