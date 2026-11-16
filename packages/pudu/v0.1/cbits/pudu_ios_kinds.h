#ifndef PUDU_IOS_KINDS_H
#define PUDU_IOS_KINDS_H

/* The view stream's instruction codes and control kinds, and what each kind
   accepts. An instruction a kind has no entry for is refused by the host. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include "pudu_ios_controls.h"
#include "pudu_ios_controls_test.h"
#include "pudu_ios_feedback.h"
#include "pudu_ios_layout.h"
#include "pudu_ios_list.h"
#include "pudu_ios_material.h"
#include "pudu_ios_text.h"
#include "pudu_ios_theme.h"
#include "pudu_ios_values.h"

/* Instruction codes and control kinds; they match Std.Mobile.Stream. */
enum { PUDU_UI_CREATE = 1, PUDU_UI_TEXT = 2, PUDU_UI_APPEND = 3, PUDU_UI_ROOT = 4, PUDU_UI_TAG = 5, PUDU_UI_RESET = 6,
       PUDU_UI_STATE = 7, PUDU_UI_HINT = 8, PUDU_UI_NAME = 9, PUDU_UI_INSERT = 10, PUDU_UI_REMOVE = 11, PUDU_UI_MOVE = 12,
       PUDU_UI_THEME = 20, PUDU_UI_APPEARANCE = 21, PUDU_UI_STYLE = 22, PUDU_UI_COLOR = 23, PUDU_UI_RANGE = 24,
       PUDU_UI_COLUMNS = 25, PUDU_UI_MATERIAL_SET = 26, PUDU_UI_GESTURES = 27,
       PUDU_UI_ALERT = 28, PUDU_UI_VALUE = 29, PUDU_UI_HAPTIC = 30, PUDU_UI_TRAITS = 31, PUDU_UI_ACCESS_HINT = 32,
       PUDU_UI_ACCESS_VALUE = 33, PUDU_UI_MENU = 34, PUDU_UI_ANIMATE = 35, PUDU_UI_BOUNDS = 36, PUDU_UI_OPTIONS = 37,
       PUDU_UI_COUNT = 38, PUDU_UI_MOMENT = 39, PUDU_UI_INSTRUCTIONS = 40 };
enum { PUDU_UI_LABEL = 1, PUDU_UI_BUTTON = 2, PUDU_UI_COLUMN = 3, PUDU_UI_ROW = 4, PUDU_UI_FIELD = 5, PUDU_UI_TOGGLE = 6,
       PUDU_UI_SCROLL = 7, PUDU_UI_LIST = 8, PUDU_UI_MATERIAL = 9, PUDU_UI_PROGRESS = 10, PUDU_UI_ACTIVITY = 11,
       PUDU_UI_SLIDER = 12, PUDU_UI_STEPPER = 13, PUDU_UI_SEGMENTS = 14, PUDU_UI_WHEEL = 15, PUDU_UI_DATE = 16,
       PUDU_UI_TEXT_AREA = 17, PUDU_UI_SEARCH = 18, PUDU_UI_SYMBOL = 19, PUDU_UI_PAGES = 20, PUDU_UI_WELL = 21,
       PUDU_UI_KINDS = 22 };

typedef struct {
  UIView *(*make)(void);
  void (*text)(UIView *, NSString *);
  void (*hint)(UIView *, NSString *);
  void (*state)(UIView *, uint32_t);
  /* The control that carries the node's tag and accessible name. */
  UIView *(*control)(UIView *);
  UIStackView *(*children)(UIView *);
  void (*fill)(UIView *, NSString *);
  void (*press)(UIView *);
  NSString *(*shown)(UIView *);
  /* Text color and font; a kind without them refuses COLOR and STYLE. */
  void (*paint)(UIView *, UIColor *);
  void (*style)(UIView *, UIFont *);
  /* Whether the kind takes Ink without a COLOR; buttons follow the tint. */
  BOOL inked;
  /* VALUE, BOUNDS and OPTIONS; a kind without one refuses that instruction. */
  void (*number)(UIView *, uint32_t);
  void (*bounds)(UIView *, int32_t, int32_t, int32_t);
  void (*options)(UIView *, NSArray<NSString *> *);
  /* What the controls self-test does to the kind. */
  void (*drive)(UIView *);
} pudu_kind;

static const pudu_kind pudu_kind_table[PUDU_UI_KINDS] = {
  [PUDU_UI_LABEL] = { pudu_make_label, pudu_label_text, NULL, NULL, pudu_itself, NULL, NULL, NULL, pudu_label_shown, pudu_label_paint, pudu_label_style, YES },
  [PUDU_UI_BUTTON] = { pudu_make_button, pudu_button_text, NULL, NULL, pudu_itself, NULL, NULL, pudu_button_press, NULL, pudu_button_paint, pudu_button_style, NO },
  [PUDU_UI_COLUMN] = { pudu_make_column, NULL, NULL, NULL, pudu_itself, pudu_direct_stack, NULL, NULL, NULL, NULL, NULL, NO },
  [PUDU_UI_ROW] = { pudu_make_row, NULL, NULL, NULL, pudu_itself, pudu_direct_stack, NULL, NULL, NULL, NULL, NULL, NO },
  [PUDU_UI_FIELD] = { pudu_make_field, pudu_field_text, pudu_field_hint, NULL, pudu_itself, NULL, pudu_field_fill, NULL, NULL, pudu_field_paint, pudu_field_style, YES },
  [PUDU_UI_TOGGLE] = { pudu_make_toggle, pudu_toggle_text, NULL, pudu_toggle_state, pudu_toggle_control, NULL, pudu_toggle_fill, NULL, NULL, pudu_toggle_paint, pudu_toggle_style, YES },
  [PUDU_UI_SCROLL] = { pudu_make_scroll, NULL, NULL, NULL, pudu_itself, pudu_scroll_stack, NULL, NULL, NULL, NULL, NULL, NO },
  [PUDU_UI_LIST] = { pudu_make_list, NULL, NULL, NULL, pudu_itself, pudu_list_store, NULL, NULL, NULL, NULL, NULL, NO },
  [PUDU_UI_MATERIAL] = { pudu_material_make, NULL, NULL, NULL, pudu_itself, pudu_material_stack, NULL, NULL, NULL, NULL, NULL, NO },
  [PUDU_UI_PROGRESS] = { .make = pudu_make_progress, .control = pudu_itself, .number = pudu_progress_value },
  [PUDU_UI_ACTIVITY] = { pudu_make_activity, NULL, NULL, pudu_activity_state, pudu_itself, NULL, NULL, NULL, NULL, NULL, NULL, NO },
  [PUDU_UI_SLIDER] = { .make = pudu_make_slider, .control = pudu_itself, .number = pudu_slider_number, .bounds = pudu_slider_bounds, .drive = pudu_slider_drive },
  [PUDU_UI_STEPPER] = { .make = pudu_make_stepper, .control = pudu_itself, .number = pudu_stepper_number, .bounds = pudu_stepper_bounds, .drive = pudu_stepper_drive },
  [PUDU_UI_SEGMENTS] = { .make = pudu_make_segments, .control = pudu_itself, .number = pudu_segments_number, .options = pudu_segments_options, .drive = pudu_segments_drive },
  [PUDU_UI_WHEEL] = { .make = pudu_make_wheel, .control = pudu_itself, .number = pudu_wheel_number, .options = pudu_wheel_options, .drive = pudu_wheel_drive },
  [PUDU_UI_DATE] = { .make = pudu_make_date, .control = pudu_itself, .drive = pudu_date_drive },
  [PUDU_UI_TEXT_AREA] = { .make = pudu_make_text_area, .text = pudu_text_area_text, .control = pudu_itself, .fill = pudu_text_area_fill,
                          .paint = pudu_text_area_paint, .style = pudu_text_area_style, .inked = YES, .drive = pudu_text_area_drive },
  [PUDU_UI_SEARCH] = { .make = pudu_make_search, .text = pudu_field_text, .hint = pudu_field_hint, .control = pudu_itself, .fill = pudu_field_fill,
                       .paint = pudu_field_paint, .style = pudu_field_style, .inked = YES, .drive = pudu_search_drive },
  [PUDU_UI_SYMBOL] = { .make = pudu_make_symbol, .text = pudu_symbol_text, .control = pudu_itself, .paint = pudu_symbol_paint, .style = pudu_symbol_style },
  [PUDU_UI_PAGES] = { .make = pudu_make_pages, .control = pudu_itself, .number = pudu_pages_number, .drive = pudu_pages_drive },
  [PUDU_UI_WELL] = { .make = pudu_make_well, .control = pudu_itself, .number = pudu_well_number, .drive = pudu_well_drive },
};

#endif
