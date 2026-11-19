#ifndef PUDU_IOS_NODES_H
#define PUDU_IOS_NODES_H

/* The view stream's codes and the host's node table. Instruction codes and
   control kinds match Std.Mobile.Stream; a node id indexes the table, and a
   removed node's slot holds NSNull until a CREATE reuses it. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include "pudu_ios_stream.h"

enum { PUDU_UI_CREATE = 1, PUDU_UI_TEXT = 2, PUDU_UI_APPEND = 3, PUDU_UI_ROOT = 4, PUDU_UI_TAG = 5, PUDU_UI_RESET = 6,
       PUDU_UI_STATE = 7, PUDU_UI_HINT = 8, PUDU_UI_NAME = 9, PUDU_UI_INSERT = 10, PUDU_UI_REMOVE = 11, PUDU_UI_MOVE = 12,
       PUDU_UI_THEME = 20, PUDU_UI_APPEARANCE = 21, PUDU_UI_STYLE = 22, PUDU_UI_COLOR = 23, PUDU_UI_RANGE = 24,
       PUDU_UI_COLUMNS = 25, PUDU_UI_MATERIAL_SET = 26, PUDU_UI_GESTURES = 27,
       PUDU_UI_ALERT = 28, PUDU_UI_VALUE = 29, PUDU_UI_HAPTIC = 30, PUDU_UI_TRAITS = 31, PUDU_UI_ACCESS_HINT = 32,
       PUDU_UI_ACCESS_VALUE = 33, PUDU_UI_MENU = 34, PUDU_UI_ANIMATE = 35, PUDU_UI_NAVIGATE = 36, PUDU_UI_REFRESH = 37,
       PUDU_UI_FETCH = 38, PUDU_UI_CANCEL = 39, PUDU_UI_WAKE = 40, PUDU_UI_BOUNDS = 41, PUDU_UI_OPTIONS = 42,
       PUDU_UI_COUNT = 43, PUDU_UI_MOMENT = 44, PUDU_UI_SOURCE = 45, PUDU_UI_OPEN = 46,
       PUDU_UI_SHARE = 47, PUDU_UI_COPY = 48, PUDU_UI_PASTE = 49, PUDU_UI_STATUS = 50,
       PUDU_UI_PERMISSIONS = 51, PUDU_UI_PERMISSION = 52, PUDU_UI_SETTINGS = 53, PUDU_UI_TABS = 54,
       PUDU_UI_INSTRUCTIONS = 55 };
enum { PUDU_UI_LABEL = 1, PUDU_UI_BUTTON = 2, PUDU_UI_COLUMN = 3, PUDU_UI_ROW = 4, PUDU_UI_FIELD = 5, PUDU_UI_TOGGLE = 6,
       PUDU_UI_SCROLL = 7, PUDU_UI_LIST = 8, PUDU_UI_MATERIAL = 9, PUDU_UI_PROGRESS = 10, PUDU_UI_ACTIVITY = 11,
       PUDU_UI_SLIDER = 12, PUDU_UI_STEPPER = 13, PUDU_UI_SEGMENTS = 14, PUDU_UI_WHEEL = 15, PUDU_UI_DATE = 16,
       PUDU_UI_TEXT_AREA = 17, PUDU_UI_SEARCH = 18, PUDU_UI_SYMBOL = 19, PUDU_UI_PAGES = 20, PUDU_UI_WELL = 21,
       PUDU_UI_IMAGE = 22, PUDU_UI_KINDS = 23 };

static NSMutableArray *pudu_nodes;
static NSMutableArray<NSNumber *> *pudu_kinds;

/* The node id an instruction names, refused before the node exists. */
static uint32_t pudu_node_id(pudu_reader *reader) {
  uint32_t node = pudu_word(reader);
  if (node >= pudu_nodes.count || pudu_nodes[node] == [NSNull null]) pudu_stream_defect("named node before creating it:", node);
  return node;
}

/* Whether a node scrolls by itself, and so fills the area it is placed in. */
static BOOL pudu_node_scrolls(uint32_t node) {
  uint32_t kind = pudu_kinds[node].unsignedIntValue;
  return kind == PUDU_UI_SCROLL || kind == PUDU_UI_LIST;
}

#endif
