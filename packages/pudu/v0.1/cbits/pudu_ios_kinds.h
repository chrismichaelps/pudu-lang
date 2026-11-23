#ifndef PUDU_IOS_KINDS_H
#define PUDU_IOS_KINDS_H

/* What each control kind is on iOS: the factory that makes it and the
   setters it accepts. An instruction a kind has no entry for is refused. The
   handlers of the value instructions live here because each is a check
   against this table followed by one setter. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include "pudu_ios_controls.h"
#include "pudu_ios_feedback.h"
#include "pudu_ios_image.h"
#include "pudu_ios_layout.h"
#include "pudu_ios_list.h"
#include "pudu_ios_material.h"
#include "pudu_ios_nodes.h"
#include "pudu_ios_stream.h"
#include "pudu_ios_theme.h"
#include "pudu_ios_values.h"
#include "pudu_ios_web.h"

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
  /* A choosing kind's label count, which bounds the index VALUE sets. */
  NSUInteger (*choices)(UIView *);
  /* What the controls self-test does to the kind. */
  void (*drive)(UIView *);
} pudu_kind;

static const pudu_kind pudu_kind_table[PUDU_UI_KINDS] = {
  [PUDU_UI_LABEL] = { .make = pudu_make_label, .text = pudu_label_text, .control = pudu_itself, .shown = pudu_label_shown,
                      .paint = pudu_label_paint, .style = pudu_label_style, .inked = YES },
  [PUDU_UI_BUTTON] = { .make = pudu_make_button, .text = pudu_button_text, .control = pudu_itself, .press = pudu_button_press,
                       .paint = pudu_button_paint, .style = pudu_button_style },
  [PUDU_UI_COLUMN] = { .make = pudu_make_column, .control = pudu_itself, .children = pudu_direct_stack },
  [PUDU_UI_ROW] = { .make = pudu_make_row, .control = pudu_itself, .children = pudu_direct_stack },
  [PUDU_UI_FIELD] = { .make = pudu_make_field, .text = pudu_field_text, .hint = pudu_field_hint, .control = pudu_itself,
                      .fill = pudu_field_fill, .paint = pudu_field_paint, .style = pudu_field_style, .inked = YES },
  [PUDU_UI_TOGGLE] = { .make = pudu_make_toggle, .text = pudu_toggle_text, .state = pudu_toggle_state, .control = pudu_toggle_control,
                       .fill = pudu_toggle_fill, .paint = pudu_toggle_paint, .style = pudu_toggle_style, .inked = YES },
  [PUDU_UI_SCROLL] = { .make = pudu_make_scroll, .control = pudu_itself, .children = pudu_scroll_stack },
  [PUDU_UI_LIST] = { .make = pudu_make_list, .control = pudu_itself, .children = pudu_list_store },
  [PUDU_UI_MATERIAL] = { .make = pudu_material_make, .control = pudu_itself, .children = pudu_material_stack },
  [PUDU_UI_PROGRESS] = { .make = pudu_make_progress, .control = pudu_itself, .number = pudu_progress_value },
  [PUDU_UI_ACTIVITY] = { .make = pudu_make_activity, .state = pudu_activity_state, .control = pudu_itself },
  [PUDU_UI_SLIDER] = { .make = pudu_make_slider, .control = pudu_itself, .number = pudu_slider_number, .bounds = pudu_slider_bounds,
                       .drive = pudu_slider_drive },
  [PUDU_UI_STEPPER] = { .make = pudu_make_stepper, .control = pudu_itself, .number = pudu_stepper_number,
                        .bounds = pudu_stepper_bounds, .drive = pudu_stepper_drive },
  [PUDU_UI_SEGMENTS] = { .make = pudu_make_segments, .control = pudu_itself, .number = pudu_segments_number,
                         .options = pudu_segments_options, .choices = pudu_segments_count, .drive = pudu_segments_drive },
  [PUDU_UI_WHEEL] = { .make = pudu_make_wheel, .control = pudu_itself, .number = pudu_wheel_number, .options = pudu_wheel_options,
                      .choices = pudu_wheel_count, .drive = pudu_wheel_drive },
  [PUDU_UI_DATE] = { .make = pudu_make_date, .control = pudu_itself, .drive = pudu_date_drive },
  [PUDU_UI_TEXT_AREA] = { .make = pudu_make_text_area, .text = pudu_text_area_text, .control = pudu_itself, .paint = pudu_text_area_paint,
                          .style = pudu_text_area_style, .inked = YES, .drive = pudu_text_area_drive },
  [PUDU_UI_SEARCH] = { .make = pudu_make_search, .text = pudu_field_text, .hint = pudu_field_hint, .control = pudu_itself,
                       .fill = pudu_field_fill, .paint = pudu_field_paint, .style = pudu_field_style, .inked = YES,
                       .drive = pudu_search_drive },
  [PUDU_UI_SYMBOL] = { .make = pudu_make_symbol, .text = pudu_symbol_text, .control = pudu_itself, .paint = pudu_symbol_paint },
  [PUDU_UI_PAGES] = { .make = pudu_make_pages, .control = pudu_itself, .number = pudu_pages_number, .drive = pudu_pages_drive },
  [PUDU_UI_WELL] = { .make = pudu_make_well, .control = pudu_itself, .number = pudu_well_number, .drive = pudu_well_drive },
  [PUDU_UI_IMAGE] = { .make = pudu_make_image, .control = pudu_itself },
  [PUDU_UI_WEB] = { .make = pudu_make_web, .control = pudu_itself },
  [PUDU_UI_VIDEO] = { .make = pudu_make_video, .control = pudu_itself },
};

static const pudu_kind *pudu_kind_of(uint32_t kind) {
  if (kind >= PUDU_UI_KINDS || pudu_kind_table[kind].make == NULL) pudu_stream_defect("created unknown kind", kind);
  return &pudu_kind_table[kind];
}

static const pudu_kind *pudu_node_kind(uint32_t node) { return &pudu_kind_table[pudu_kinds[node].unsignedIntValue]; }

/* VALUE: a number for a kind that holds one; a choosing kind's index must
   name one of its labels. */
static void pudu_do_value(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t word = pudu_word(reader);
  const pudu_kind *kind = pudu_node_kind(node);
  if (kind->number == NULL) pudu_stream_defect("set a value on a node that holds none:", node);
  if (kind->choices != NULL && word >= kind->choices(pudu_nodes[node])) pudu_stream_defect("selected past the last option of node", node);
  kind->number(pudu_nodes[node], word);
}

/* BOUNDS: low, high and step as signed words. */
static void pudu_do_bounds(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  int32_t low = (int32_t)pudu_word(reader), high = (int32_t)pudu_word(reader), step = (int32_t)pudu_word(reader);
  if (pudu_node_kind(node)->bounds == NULL) pudu_stream_defect("bounded a node that takes no bounds:", node);
  if (high < low || step < 1) pudu_stream_defect("set an inverted range or a step below one on node", node);
  pudu_node_kind(node)->bounds(pudu_nodes[node], low, high, step);
}

/* OPTIONS: a count, then each label. */
static void pudu_do_options(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t count = pudu_word(reader);
  NSMutableArray<NSString *> *labels = [NSMutableArray arrayWithCapacity:count];
  if (pudu_node_kind(node)->options == NULL) pudu_stream_defect("gave options to a node that takes none:", node);
  if (count == 0) pudu_stream_defect("gave no options to node", node);
  for (uint32_t i = 0; i < count; i++) [labels addObject:pudu_text(reader)];
  pudu_node_kind(node)->options(pudu_nodes[node], labels);
}

static void pudu_do_count(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t total = pudu_word(reader);
  if (pudu_kinds[node].unsignedIntValue != PUDU_UI_PAGES) pudu_stream_defect("counted pages on a node that is not a page indicator:", node);
  pudu_pages_count(pudu_nodes[node], total);
}

/* MOMENT: the mode, then the seconds as the high and low words. */
static void pudu_do_moment(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t mode = pudu_word(reader);
  int64_t high = (int32_t)pudu_word(reader);
  int64_t seconds = (int64_t)((uint64_t)high << 32 | pudu_word(reader));
  if (pudu_kinds[node].unsignedIntValue != PUDU_UI_DATE) pudu_stream_defect("set a moment on a node that is not a date picker:", node);
  if (mode >= PUDU_MOMENTS) pudu_stream_defect("used unknown date mode", mode);
  pudu_date_moment(pudu_nodes[node], mode, seconds);
}

/* SOURCE: the origin (0 an asset, 1 a URL), the scaling, then the name or URL. */
static void pudu_do_source(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t origin = pudu_word(reader);
  uint32_t scaling = pudu_word(reader);
  NSString *location = pudu_text(reader);
  if (pudu_kinds[node].unsignedIntValue != PUDU_UI_IMAGE) pudu_stream_defect("set a source on a node that is not an image:", node);
  if (origin >= PUDU_IMAGE_ORIGINS) pudu_stream_defect("used unknown image origin", origin);
  if (scaling >= PUDU_IMAGE_SCALINGS) pudu_stream_defect("used unknown image scaling", scaling);
  pudu_image_source(pudu_nodes[node], origin, scaling, location);
}

/* Drives every value control once, then calls `done`. */
static void pudu_test_controls(NSArray *nodes, NSArray<NSNumber *> *kinds, void (^done)(void)) {
  for (NSUInteger node = 0; node < nodes.count; node++) {
    const pudu_kind *kind = &pudu_kind_table[kinds[node].unsignedIntValue];
    if (kind->drive != NULL) kind->drive(nodes[node]);
  }
  done();
}

#endif
