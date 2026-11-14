/* The iOS host of a Pudu Native application: it starts the program once
   UIKit has launched, applies each commit's view stream to platform controls,
   and hands events back through a blocking wait that runs the main loop.
   Nothing here calls into Pudu; Pudu calls the functions below.

   Kinds and instructions dispatch through constant tables: a control kind
   names the factory that makes its control and the setters it accepts; an
   instruction code names its handler. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "pudu_program.h"

/* Instruction codes, control kinds and event kinds of the view stream; they
   match Std.Mobile.View. */
enum { PUDU_UI_CREATE = 1, PUDU_UI_TEXT = 2, PUDU_UI_APPEND = 3, PUDU_UI_ROOT = 4, PUDU_UI_TAG = 5, PUDU_UI_RESET = 6,
       PUDU_UI_STATE = 7, PUDU_UI_HINT = 8, PUDU_UI_NAME = 9, PUDU_UI_INSTRUCTIONS = 10 };
enum { PUDU_UI_LABEL = 1, PUDU_UI_BUTTON = 2, PUDU_UI_COLUMN = 3, PUDU_UI_ROW = 4, PUDU_UI_FIELD = 5, PUDU_UI_TOGGLE = 6,
       PUDU_UI_KINDS = 7 };
static const uint64_t PUDU_UI_TAPPED = 1, PUDU_UI_STOPPED = 2, PUDU_UI_CHANGED = 3, PUDU_UI_SWITCHED_ON = 4,
                      PUDU_UI_SWITCHED_OFF = 5;

static NSMutableArray *pudu_nodes;
static NSMutableArray<NSNumber *> *pudu_kinds;
/* Each queued event is its 64-bit value and the text it carries. */
static NSMutableArray<NSArray *> *pudu_events;
static char *pudu_event_text_bytes;
static UIView *pudu_surface;
static UIView *pudu_shown_root;
static double pudu_main_started_ms;
static double pudu_first_frame_ms = -1;

static _Noreturn void pudu_stream_defect(const char *problem, uint32_t value) {
  fprintf(stderr, "pudu: a view stream %s %u\n", problem, value);
  abort();
}

/* Milliseconds on the monotonic clock. */
static double pudu_now_ms(void) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (double)now.tv_sec * 1000.0 + (double)now.tv_nsec / 1e6;
}

static void pudu_queue(uint64_t kind, NSInteger tag, NSString *text) {
  [pudu_events addObject:@[ @((kind << 32) | (uint32_t)tag), text ?: @"" ]];
}

/* A toggle: its title beside the platform switch. */
@interface PuduToggle : UIStackView
@property (strong, nonatomic) UILabel *title;
@property (strong, nonatomic) UISwitch *control;
@end
@implementation PuduToggle
@end

@interface PuduTarget : NSObject
- (void)tapped:(UIButton *)sender;
- (void)edited:(UITextField *)sender;
- (void)switched:(UISwitch *)sender;
@end
@implementation PuduTarget
- (void)tapped:(UIButton *)sender { pudu_queue(PUDU_UI_TAPPED, sender.tag, nil); }
- (void)edited:(UITextField *)sender { pudu_queue(PUDU_UI_CHANGED, sender.tag, sender.text); }
- (void)switched:(UISwitch *)sender { pudu_queue(sender.on ? PUDU_UI_SWITCHED_ON : PUDU_UI_SWITCHED_OFF, sender.tag, nil); }
@end
static PuduTarget *pudu_target;

/* Factories: one control per kind. */
static UIView *pudu_make_label(void) {
  UILabel *label = [UILabel new];
  label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
  label.adjustsFontForContentSizeCategory = YES;
  return label;
}

static UIView *pudu_make_button(void) {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  [button addTarget:pudu_target action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
  return button;
}

static UIStackView *pudu_make_group(UILayoutConstraintAxis axis, CGFloat spacing) {
  UIStackView *group = [UIStackView new];
  group.axis = axis;
  group.alignment = UIStackViewAlignmentCenter;
  group.spacing = spacing;
  return group;
}

static UIView *pudu_make_column(void) { return pudu_make_group(UILayoutConstraintAxisVertical, 16); }

static UIView *pudu_make_row(void) { return pudu_make_group(UILayoutConstraintAxisHorizontal, 12); }

static UIView *pudu_make_field(void) {
  UITextField *field = [UITextField new];
  field.borderStyle = UITextBorderStyleRoundedRect;
  [field.widthAnchor constraintGreaterThanOrEqualToConstant:220].active = YES;
  [field addTarget:pudu_target action:@selector(edited:) forControlEvents:UIControlEventEditingChanged];
  return field;
}

static UIView *pudu_make_toggle(void) {
  PuduToggle *toggle = [PuduToggle new];
  toggle.axis = UILayoutConstraintAxisHorizontal;
  toggle.spacing = 8;
  toggle.title = [UILabel new];
  toggle.control = [UISwitch new];
  [toggle.control addTarget:pudu_target action:@selector(switched:) forControlEvents:UIControlEventValueChanged];
  [toggle addArrangedSubview:toggle.title];
  [toggle addArrangedSubview:toggle.control];
  return toggle;
}

/* Setters a kind accepts; a kind without one refuses that instruction. */
static void pudu_label_text(UIView *view, NSString *text) { ((UILabel *)view).text = text; }

static void pudu_button_text(UIView *view, NSString *text) { [(UIButton *)view setTitle:text forState:UIControlStateNormal]; }

/* A field already showing the text is left alone, so typing keeps its place. */
static void pudu_field_text(UIView *view, NSString *text) {
  UITextField *field = (UITextField *)view;
  if (![field.text isEqualToString:text]) field.text = text;
}

static void pudu_field_hint(UIView *view, NSString *hint) { ((UITextField *)view).placeholder = hint; }

static void pudu_toggle_text(UIView *view, NSString *text) { ((PuduToggle *)view).title.text = text; }

static void pudu_toggle_state(UIView *view, uint32_t state) { ((PuduToggle *)view).control.on = state != 0; }

static UIView *pudu_toggle_control(UIView *view) { return ((PuduToggle *)view).control; }

static UIView *pudu_itself(UIView *view) { return view; }

/* What a self-test does to a kind, and what a kind reports afterward. */
static void pudu_field_fill(UIView *view, NSString *text) {
  ((UITextField *)view).text = text;
  [(UITextField *)view sendActionsForControlEvents:UIControlEventEditingChanged];
}

static void pudu_toggle_fill(UIView *view, NSString *text) {
  (void)text;
  ((PuduToggle *)view).control.on = YES;
  [((PuduToggle *)view).control sendActionsForControlEvents:UIControlEventValueChanged];
}

static void pudu_button_press(UIView *view) { [(UIButton *)view sendActionsForControlEvents:UIControlEventTouchUpInside]; }

static NSString *pudu_label_shown(UIView *view) { return ((UILabel *)view).text; }

typedef struct {
  UIView *(*make)(void);
  void (*text)(UIView *, NSString *);
  void (*hint)(UIView *, NSString *);
  void (*state)(UIView *, uint32_t);
  /* The control that carries the node's tag and accessible name. */
  UIView *(*control)(UIView *);
  int groups;
  void (*fill)(UIView *, NSString *);
  void (*press)(UIView *);
  NSString *(*shown)(UIView *);
} pudu_kind;

static const pudu_kind pudu_kind_table[PUDU_UI_KINDS] = {
  [PUDU_UI_LABEL] = { pudu_make_label, pudu_label_text, NULL, NULL, pudu_itself, 0, NULL, NULL, pudu_label_shown },
  [PUDU_UI_BUTTON] = { pudu_make_button, pudu_button_text, NULL, NULL, pudu_itself, 0, NULL, pudu_button_press, NULL },
  [PUDU_UI_COLUMN] = { pudu_make_column, NULL, NULL, NULL, pudu_itself, 1, NULL, NULL, NULL },
  [PUDU_UI_ROW] = { pudu_make_row, NULL, NULL, NULL, pudu_itself, 1, NULL, NULL, NULL },
  [PUDU_UI_FIELD] = { pudu_make_field, pudu_field_text, pudu_field_hint, NULL, pudu_itself, 0, pudu_field_fill, NULL, NULL },
  [PUDU_UI_TOGGLE] = { pudu_make_toggle, pudu_toggle_text, NULL, pudu_toggle_state, pudu_toggle_control, 0, pudu_toggle_fill, NULL, NULL },
};

static const pudu_kind *pudu_kind_of(uint32_t kind) {
  if (kind >= PUDU_UI_KINDS || pudu_kind_table[kind].make == NULL) pudu_stream_defect("created unknown kind", kind);
  return &pudu_kind_table[kind];
}

/* Reading the stream. */
typedef struct {
  const uint8_t *bytes;
  uint64_t length, at;
} pudu_reader;

static uint32_t pudu_word(pudu_reader *reader) {
  const uint8_t *b = reader->bytes + reader->at;
  if (reader->at + 4 > reader->length) pudu_stream_defect("ended inside an instruction at byte", (uint32_t)reader->at);
  reader->at += 4;
  return (uint32_t)b[0] | (uint32_t)b[1] << 8 | (uint32_t)b[2] << 16 | (uint32_t)b[3] << 24;
}

static NSString *pudu_text(pudu_reader *reader) {
  uint32_t count = pudu_word(reader);
  NSString *text;
  if (reader->at + count > reader->length) pudu_stream_defect("ended inside text of length", count);
  text = [[NSString alloc] initWithBytes:reader->bytes + reader->at length:count encoding:NSUTF8StringEncoding];
  reader->at += count;
  return text;
}

static uint32_t pudu_node_id(pudu_reader *reader) {
  uint32_t node = pudu_word(reader);
  if (node >= pudu_nodes.count || pudu_nodes[node] == [NSNull null]) pudu_stream_defect("named node before creating it:", node);
  return node;
}

static const pudu_kind *pudu_node_kind(uint32_t node) { return &pudu_kind_table[pudu_kinds[node].unsignedIntValue]; }

/* Instruction handlers, one per code. */
static void pudu_do_create(pudu_reader *reader) {
  uint32_t node = pudu_word(reader);
  uint32_t kind = pudu_word(reader);
  const pudu_kind *made = pudu_kind_of(kind);
  while (pudu_nodes.count <= node) {
    [pudu_nodes addObject:[NSNull null]];
    [pudu_kinds addObject:@0];
  }
  pudu_nodes[node] = made->make();
  pudu_kinds[node] = @(kind);
}

static void pudu_do_text(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  NSString *text = pudu_text(reader);
  if (pudu_node_kind(node)->text == NULL) pudu_stream_defect("set text on a node that shows none:", node);
  pudu_node_kind(node)->text(pudu_nodes[node], text);
}

static void pudu_do_hint(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  NSString *hint = pudu_text(reader);
  if (pudu_node_kind(node)->hint == NULL) pudu_stream_defect("set a hint on a node that takes none:", node);
  pudu_node_kind(node)->hint(pudu_nodes[node], hint);
}

static void pudu_do_state(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t state = pudu_word(reader);
  if (pudu_node_kind(node)->state == NULL) pudu_stream_defect("set state on a node that has none:", node);
  pudu_node_kind(node)->state(pudu_nodes[node], state);
}

static void pudu_do_name(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  pudu_node_kind(node)->control(pudu_nodes[node]).accessibilityLabel = pudu_text(reader);
}

static void pudu_do_tag(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  NSInteger tag = (NSInteger)pudu_word(reader);
  ((UIView *)pudu_nodes[node]).tag = tag;
  pudu_node_kind(node)->control(pudu_nodes[node]).tag = tag;
}

static void pudu_do_append(pudu_reader *reader) {
  uint32_t parent = pudu_node_id(reader);
  uint32_t child = pudu_node_id(reader);
  if (!pudu_node_kind(parent)->groups) pudu_stream_defect("appended to a node that holds nothing:", parent);
  [(UIStackView *)pudu_nodes[parent] addArrangedSubview:pudu_nodes[child]];
}

static void pudu_do_root(pudu_reader *reader) {
  UIView *root = pudu_nodes[pudu_node_id(reader)];
  [pudu_shown_root removeFromSuperview];
  pudu_shown_root = root;
  root.translatesAutoresizingMaskIntoConstraints = NO;
  [pudu_surface addSubview:root];
  [NSLayoutConstraint activateConstraints:@[
    [root.centerXAnchor constraintEqualToAnchor:pudu_surface.centerXAnchor],
    [root.centerYAnchor constraintEqualToAnchor:pudu_surface.centerYAnchor] ]];
}

static void pudu_do_reset(pudu_reader *reader) {
  (void)reader;
  [pudu_shown_root removeFromSuperview];
  pudu_shown_root = nil;
  [pudu_nodes removeAllObjects];
  [pudu_kinds removeAllObjects];
}

static void (*const pudu_instruction_table[PUDU_UI_INSTRUCTIONS])(pudu_reader *) = {
  [PUDU_UI_CREATE] = pudu_do_create, [PUDU_UI_TEXT] = pudu_do_text, [PUDU_UI_APPEND] = pudu_do_append,
  [PUDU_UI_ROOT] = pudu_do_root, [PUDU_UI_TAG] = pudu_do_tag, [PUDU_UI_RESET] = pudu_do_reset,
  [PUDU_UI_STATE] = pudu_do_state, [PUDU_UI_HINT] = pudu_do_hint, [PUDU_UI_NAME] = pudu_do_name,
};

/* Applies one commit: every instruction in order, in one call. */
void pudu_ui_apply(const void *stream, uint64_t length) {
  pudu_reader reader = { stream, length, 0 };
  while (reader.at < reader.length) {
    uint32_t code = pudu_word(&reader);
    if (code >= PUDU_UI_INSTRUCTIONS || pudu_instruction_table[code] == NULL) pudu_stream_defect("used unknown instruction", code);
    pudu_instruction_table[code](&reader);
  }
  if (pudu_first_frame_ms < 0) {
    [pudu_surface layoutIfNeeded];
    pudu_first_frame_ms = pudu_now_ms() - pudu_main_started_ms;
    printf("PUDU_FIRST_FRAME_MS %.1f\n", pudu_first_frame_ms);
    fflush(stdout);
  }
}

/* The next event; the main loop runs, and controls queue events, until one
   is waiting. */
uint64_t pudu_ui_wait(void) {
  NSArray *next;
  while (pudu_events.count == 0) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, true);
  next = pudu_events.firstObject;
  [pudu_events removeObjectAtIndex:0];
  free(pudu_event_text_bytes);
  pudu_event_text_bytes = strdup([next[1] UTF8String]);
  if (pudu_event_text_bytes == NULL) abort();
  return [next[0] unsignedLongLongValue];
}

/* The text the last event carried; valid until the next wait. */
const char *pudu_ui_event_text(void) {
  return pudu_event_text_bytes != NULL ? pudu_event_text_bytes : "";
}

@interface PuduAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
@implementation PuduAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
  (void)application;
  (void)options;
  UIViewController *controller = [UIViewController new];
  controller.view.backgroundColor = UIColor.systemBackgroundColor;
  pudu_surface = controller.view;
  pudu_nodes = [NSMutableArray new];
  pudu_kinds = [NSMutableArray new];
  pudu_events = [NSMutableArray new];
  pudu_target = [PuduTarget new];
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.rootViewController = controller;
  [self.window makeKeyAndVisible];
  /* A run-loop timer, not the main queue: Pudu's wait runs the loop, and the
     main queue does not drain while one of its blocks is running. */
  [self performSelector:@selector(run) withObject:nil afterDelay:0];
  if (getenv("PUDU_UI_SELFTEST") != NULL) [self performSelector:@selector(selfTest) withObject:nil afterDelay:0.5];
  return YES;
}
- (void)run {
  int status = pudu_program_run(0, NULL);
  printf("PUDU_PROGRAM_STATUS %d\n", status);
  if (getenv("PUDU_UI_SELFTEST") != NULL) {
    for (NSUInteger node = 0; node < pudu_nodes.count; node++) {
      if (pudu_node_kind((uint32_t)node)->shown != NULL) printf("PUDU_LABEL %s\n", pudu_node_kind((uint32_t)node)->shown(pudu_nodes[node]).UTF8String);
    }
    fflush(stdout);
    exit(status);
  }
}
/* Types PUDU_UI_TYPE into every field and switches every toggle on when it
   is set, taps every button as many times as PUDU_UI_SELFTEST says, then asks
   the program to stop, exactly as a user's input would arrive. */
- (void)selfTest {
  int taps = atoi(getenv("PUDU_UI_SELFTEST"));
  const char *typed = getenv("PUDU_UI_TYPE");
  NSArray *nodes = [pudu_nodes copy];
  NSArray<NSNumber *> *kinds = [pudu_kinds copy];
  for (NSUInteger node = 0; typed != NULL && node < nodes.count; node++) {
    const pudu_kind *kind = &pudu_kind_table[kinds[node].unsignedIntValue];
    if (kind->fill != NULL) kind->fill(nodes[node], @(typed));
  }
  for (int i = 0; i < taps; i++) {
    for (NSUInteger node = 0; node < nodes.count; node++) {
      const pudu_kind *kind = &pudu_kind_table[kinds[node].unsignedIntValue];
      if (kind->press != NULL) kind->press(nodes[node]);
    }
  }
  pudu_queue(PUDU_UI_STOPPED, 0, nil);
}
@end

int main(int argc, char **argv) {
  pudu_main_started_ms = pudu_now_ms();
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([PuduAppDelegate class]));
  }
}
