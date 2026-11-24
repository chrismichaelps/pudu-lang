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
#include "pudu_program.h"
#include "pudu_ios_stream.h"
#include "pudu_ios_layout.h"
#include "pudu_ios_theme.h"
#include "pudu_ios_events.h"
#include "pudu_ios_list.h"
#include "pudu_ios_controls.h"
#include "pudu_ios_material.h"
#include "pudu_ios_gesture.h"
#include "pudu_ios_feedback.h"
#include "pudu_ios_access.h"
#include "pudu_ios_scene.h"
#include "pudu_ios_motion.h"
#include "pudu_ios_nodes.h"
#include "pudu_ios_kinds.h"
#include "pudu_ios_navigation.h"
#include "pudu_ios_tabs.h"
#include "pudu_ios_refresh.h"
#include "pudu_ios_fetch.h"
#include "pudu_ios_system.h"
#include "pudu_ios_permission.h"
#include "pudu_ios_storage.h"
#include "pudu_ios_device.h"
#include "pudu_ios_location.h"
#include "pudu_ios_notify.h"
#include "pudu_ios_media.h"
#include "pudu_ios_pick.h"
#include "pudu_ios_capability_test.h"

/* Each node's color role from COLOR, or PUDU_ROLE_DEFAULT. */
static NSMutableArray<NSNumber *> *pudu_paints;
static UIView *pudu_surface;
static UIView *pudu_shown_root;
static UILayoutGuide *pudu_available;
static double pudu_main_started_ms;
static double pudu_first_frame_ms = -1;

/* Paints a node with its COLOR role, or with Ink when its kind is inked. */
static void pudu_paint(uint32_t node) {
  const pudu_kind *kind = pudu_node_kind(node);
  uint32_t role = pudu_paints[node].unsignedIntValue;
  if (kind->paint == NULL || (role == PUDU_ROLE_DEFAULT && !kind->inked)) return;
  kind->paint(pudu_nodes[node], pudu_roles[role == PUDU_ROLE_DEFAULT ? PUDU_ROLE_INK : role]);
}

/* Instruction handlers, one per code. */
static void pudu_do_create(pudu_reader *reader) {
  uint32_t node = pudu_word(reader);
  uint32_t kind = pudu_word(reader);
  const pudu_kind *made = pudu_kind_of(kind);
  while (pudu_nodes.count <= node) {
    [pudu_nodes addObject:[NSNull null]];
    [pudu_kinds addObject:@0];
    [pudu_paints addObject:@(PUDU_ROLE_DEFAULT)];
  }
  pudu_nodes[node] = made->make();
  pudu_kinds[node] = @(kind);
  pudu_paints[node] = @(PUDU_ROLE_DEFAULT);
  pudu_paint(node);
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

/* The group a placement names, refused when its node holds nothing. */
static UIStackView *pudu_group(pudu_reader *reader) {
  uint32_t parent = pudu_node_id(reader);
  const pudu_kind *kind = pudu_node_kind(parent);
  if (kind->children == NULL) pudu_stream_defect("placed a child in a node that holds nothing:", parent);
  return kind->children(pudu_nodes[parent]);
}

static void pudu_do_append(pudu_reader *reader) {
  UIStackView *group = pudu_group(reader);
  [group addArrangedSubview:pudu_nodes[pudu_node_id(reader)]];
  pudu_motion_touch(group);
}

/* INSERT and MOVE: places a child at an index of its group, refused past
   the group's end. */
static void pudu_place(pudu_reader *reader) {
  UIStackView *group = pudu_group(reader);
  UIView *child = pudu_nodes[pudu_node_id(reader)];
  uint32_t index = pudu_word(reader);
  if (index > group.arrangedSubviews.count) pudu_stream_defect("placed a child past the end of its group at", index);
  /* An arranged child already in the group moves to the index. */
  [group insertArrangedSubview:child atIndex:index];
  pudu_motion_touch(group);
}

/* Detaches a subtree and forgets every node it lists, so a later CREATE may
   reuse those ids. */
static void pudu_do_remove(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t count = pudu_word(reader);
  pudu_motion_touch([(UIView *)pudu_nodes[node] superview]);
  pudu_list_forget(pudu_nodes[node]);
  [(UIView *)pudu_nodes[node] removeFromSuperview];
  for (uint32_t i = 0; i < count; i++) {
    uint32_t gone = pudu_node_id(reader);
    pudu_nodes[gone] = [NSNull null];
    pudu_kinds[gone] = @0;
    pudu_paints[gone] = @(PUDU_ROLE_DEFAULT);
  }
}

static void pudu_do_root(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  UIView *root = pudu_nodes[node];
  [pudu_shown_root removeFromSuperview];
  pudu_shown_root = root;
  root.translatesAutoresizingMaskIntoConstraints = NO;
  [pudu_surface addSubview:root];
  uint32_t kind = pudu_kinds[node].unsignedIntValue;
  pudu_place_root(root, pudu_available, kind == PUDU_UI_SCROLL || kind == PUDU_UI_LIST);
}

static void pudu_do_reset(pudu_reader *reader) {
  (void)reader;
  [pudu_shown_root removeFromSuperview];
  pudu_shown_root = nil;
  [pudu_nodes removeAllObjects];
  [pudu_kinds removeAllObjects];
  [pudu_paints removeAllObjects];
}

/* Replaces every role's tone, then repaints the surface, the tint and every
   shown node; the colors resolve per appearance at draw time. */
static void pudu_do_theme(pudu_reader *reader) {
  uint32_t count = pudu_word(reader);
  if (count != PUDU_ROLES) pudu_stream_defect("set a theme with role count", count);
  for (uint32_t role = 0; role < PUDU_ROLES; role++) {
    uint32_t tone = pudu_word(reader);
    uint32_t light = pudu_word(reader);
    uint32_t dark = pudu_word(reader);
    if (tone > PUDU_TONE_FIXED) pudu_stream_defect("used unknown tone kind", tone);
    pudu_roles[role] = tone == PUDU_TONE_FIXED ? pudu_fixed_tone(light, dark) : pudu_platform_roles[role];
  }
  pudu_surface.backgroundColor = pudu_roles[PUDU_ROLE_SURFACE];
  pudu_surface.window.tintColor = pudu_roles[PUDU_ROLE_ACCENT];
  for (NSUInteger node = 0; node < pudu_nodes.count; node++) {
    if (pudu_nodes[node] != [NSNull null]) pudu_paint((uint32_t)node);
  }
}

static void pudu_do_appearance(pudu_reader *reader) {
  uint32_t code = pudu_word(reader);
  if (code >= PUDU_APPEARANCES) pudu_stream_defect("asked for unknown appearance", code);
  pudu_surface.window.overrideUserInterfaceStyle = pudu_interface_styles[code];
}

static void pudu_do_style(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  UIFontTextStyle style = pudu_text_style(pudu_word(reader));
  if (style == nil) pudu_stream_defect("used unknown text style on node", node);
  if (pudu_node_kind(node)->style == NULL) pudu_stream_defect("styled a node that shows no text:", node);
  pudu_node_kind(node)->style(pudu_nodes[node], [UIFont preferredFontForTextStyle:style]);
}

static void pudu_do_color(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t role = pudu_word(reader);
  if (role >= PUDU_ROLES) pudu_stream_defect("used unknown color role", role);
  if (pudu_node_kind(node)->paint == NULL) pudu_stream_defect("colored a node that shows no text:", node);
  pudu_paints[node] = @(role);
  pudu_paint(node);
}

/* The list a RANGE or COLUMNS names, refused for any other kind. */
static UIView *pudu_list_node(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  if (pudu_kinds[node].unsignedIntValue != PUDU_UI_LIST) pudu_stream_defect("shaped a node that is not a list:", node);
  return pudu_nodes[node];
}

/* RANGE: total, then first. Arguments are read in stream order. */
static void pudu_do_range(pudu_reader *reader) {
  UIView *list = pudu_list_node(reader);
  uint32_t total = pudu_word(reader);
  pudu_list_range(list, total, pudu_word(reader));
}
static void pudu_do_columns(pudu_reader *reader) {
  UIView *list = pudu_list_node(reader);
  uint32_t columns = pudu_word(reader);
  if (columns == 0) pudu_stream_defect("laid a list in zero columns:", 0);
  pudu_list_columns(list, columns);
}

/* MATERIAL: the system material behind a material node. */
static void pudu_do_material(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t code = pudu_word(reader);
  if (pudu_kinds[node].unsignedIntValue != PUDU_UI_MATERIAL) pudu_stream_defect("set a material on a node that is not one:", node);
  if (!pudu_material_set(pudu_nodes[node], code)) pudu_stream_defect("used unknown material", code);
}

/* A text field inside an instruction, read where it stands. */
static NSArray<NSArray *> *pudu_choices(pudu_reader *reader) {
  uint32_t count = pudu_word(reader);
  NSMutableArray<NSArray *> *choices = [NSMutableArray new];
  for (uint32_t i = 0; i < count; i++) {
    uint32_t role = pudu_word(reader);
    [choices addObject:@[ @(role), pudu_text(reader) ]];
  }
  return choices;
}

static UIView *pudu_control_of(uint32_t node) { return pudu_node_kind(node)->control(pudu_nodes[node]); }

static void pudu_do_gestures(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t tag = pudu_word(reader);
  uint32_t mask = pudu_word(reader);
  if (mask >= 32) pudu_stream_defect("used unknown gestures", mask);
  pudu_gestures_attach(pudu_control_of(node), tag, mask);
}

static void pudu_do_alert(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  uint32_t style = pudu_word(reader);
  NSString *title = pudu_text(reader);
  NSString *message = pudu_text(reader);
  if (!pudu_alert_show(tag, style, title, message, pudu_choices(reader))) pudu_stream_defect("showed an alert with an unknown style or role, tag", tag);
}

static void pudu_do_haptic(pudu_reader *reader) {
  uint32_t code = pudu_word(reader);
  if (!pudu_haptic_play(code)) pudu_stream_defect("played unknown haptic", code);
}

static void pudu_do_traits(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t mask = pudu_word(reader);
  if (mask >= (1u << PUDU_TRAITS)) pudu_stream_defect("used unknown accessibility traits", mask);
  pudu_control_of(node).accessibilityTraits = pudu_traits_of(mask);
}

static void pudu_do_access_hint(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  pudu_control_of(node).accessibilityHint = pudu_text(reader);
}

static void pudu_do_access_value(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  pudu_control_of(node).accessibilityValue = pudu_text(reader);
}

static void pudu_do_menu(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t tag = pudu_word(reader);
  NSArray<NSArray *> *choices = pudu_choices(reader);
  for (NSArray *choice in choices) {
    if ([choice[0] unsignedIntValue] >= PUDU_ROLES_KNOWN) pudu_stream_defect("gave a menu item an unknown role, node", node);
  }
  pudu_menu_attach(pudu_control_of(node), tag, choices);
}

static void pudu_do_animate(pudu_reader *reader) {
  UIStackView *group = pudu_group(reader);
  pudu_motion_mark(group, pudu_word(reader) != 0);
}

/* NAVIGATE: read and checked whole, then shown over the screen in place of a ROOT. */
static void pudu_do_navigate(pudu_reader *reader) {
  NSDictionary *desired = pudu_navigation_read(reader);
  pudu_tabs_close();
  [pudu_shown_root removeFromSuperview];
  pudu_shown_root = nil;
  pudu_navigation_show(pudu_surface.window.rootViewController, desired);
}

/* TABS: read and checked whole, then shown over the screen in place of a ROOT or NAVIGATE. */
static void pudu_do_tabs(pudu_reader *reader) {
  NSDictionary *desired = pudu_tabs_read(reader);
  [pudu_shown_root removeFromSuperview];
  pudu_shown_root = nil;
  pudu_tabs_show(pudu_surface.window.rootViewController, desired);
}

static void (*const pudu_instruction_table[PUDU_UI_INSTRUCTIONS])(pudu_reader *) = {
  [PUDU_UI_CREATE] = pudu_do_create, [PUDU_UI_TEXT] = pudu_do_text, [PUDU_UI_APPEND] = pudu_do_append,
  [PUDU_UI_ROOT] = pudu_do_root, [PUDU_UI_TAG] = pudu_do_tag, [PUDU_UI_RESET] = pudu_do_reset,
  [PUDU_UI_STATE] = pudu_do_state, [PUDU_UI_HINT] = pudu_do_hint, [PUDU_UI_NAME] = pudu_do_name,
  [PUDU_UI_INSERT] = pudu_place, [PUDU_UI_REMOVE] = pudu_do_remove, [PUDU_UI_MOVE] = pudu_place,
  [PUDU_UI_THEME] = pudu_do_theme, [PUDU_UI_APPEARANCE] = pudu_do_appearance, [PUDU_UI_STYLE] = pudu_do_style,
  [PUDU_UI_COLOR] = pudu_do_color, [PUDU_UI_RANGE] = pudu_do_range, [PUDU_UI_COLUMNS] = pudu_do_columns,
  [PUDU_UI_MATERIAL_SET] = pudu_do_material, [PUDU_UI_GESTURES] = pudu_do_gestures, [PUDU_UI_ALERT] = pudu_do_alert,
  [PUDU_UI_VALUE] = pudu_do_value, [PUDU_UI_HAPTIC] = pudu_do_haptic, [PUDU_UI_TRAITS] = pudu_do_traits,
  [PUDU_UI_ACCESS_HINT] = pudu_do_access_hint, [PUDU_UI_ACCESS_VALUE] = pudu_do_access_value,
  [PUDU_UI_MENU] = pudu_do_menu, [PUDU_UI_ANIMATE] = pudu_do_animate, [PUDU_UI_NAVIGATE] = pudu_do_navigate,
  [PUDU_UI_REFRESH] = pudu_do_refresh, [PUDU_UI_FETCH] = pudu_do_fetch, [PUDU_UI_CANCEL] = pudu_do_cancel,
  [PUDU_UI_WAKE] = pudu_do_wake, [PUDU_UI_BOUNDS] = pudu_do_bounds, [PUDU_UI_OPTIONS] = pudu_do_options,
  [PUDU_UI_COUNT] = pudu_do_count, [PUDU_UI_MOMENT] = pudu_do_moment, [PUDU_UI_SOURCE] = pudu_do_source,
  [PUDU_UI_OPEN] = pudu_do_open, [PUDU_UI_SHARE] = pudu_do_share, [PUDU_UI_COPY] = pudu_do_copy, [PUDU_UI_PASTE] = pudu_do_paste,
  [PUDU_UI_STATUS] = pudu_do_status, [PUDU_UI_PERMISSIONS] = pudu_do_permissions, [PUDU_UI_PERMISSION] = pudu_do_permission,
  [PUDU_UI_SETTINGS] = pudu_do_settings, [PUDU_UI_TABS] = pudu_do_tabs,
  [PUDU_UI_STORE_READ] = pudu_do_store_read, [PUDU_UI_STORE_WRITE] = pudu_do_store_write, [PUDU_UI_STORE_REMOVE] = pudu_do_store_remove,
  [PUDU_UI_DEVICE] = pudu_do_device, [PUDU_UI_NETWORK] = pudu_do_network, [PUDU_UI_AWAKE] = pudu_do_awake,
  [PUDU_UI_LOCATE] = pudu_do_locate, [PUDU_UI_TRACK] = pudu_do_track,
  [PUDU_UI_NOTIFY] = pudu_do_notify, [PUDU_UI_UNNOTIFY] = pudu_do_unnotify, [PUDU_UI_AUTHENTICATE] = pudu_do_authenticate,
  [PUDU_UI_BROWSE] = pudu_do_browse, [PUDU_UI_SPEAK] = pudu_do_speak, [PUDU_UI_HUSH] = pudu_do_hush,
  [PUDU_UI_BATTERY] = pudu_do_battery, [PUDU_UI_BRIGHTNESS] = pudu_do_brightness, [PUDU_UI_ORIENTATION] = pudu_do_orientation,
  [PUDU_UI_SENSE] = pudu_do_sense, [PUDU_UI_PICK_IMAGE] = pudu_do_pick_image,
  [PUDU_UI_LOAD] = pudu_do_load, [PUDU_UI_MEDIA] = pudu_do_media, [PUDU_UI_AUDIO] = pudu_do_audio,
  [PUDU_UI_KEYBOARD] = pudu_do_keyboard, [PUDU_UI_BACK] = pudu_do_back,
  [PUDU_UI_PICK_CONTACT] = pudu_do_pick_contact, [PUDU_UI_PICK_DOCUMENT] = pudu_do_pick_document,
  [PUDU_UI_TAKE_PHOTO] = pudu_do_take_photo, [PUDU_UI_RECORD] = pudu_do_record, [PUDU_UI_BADGE] = pudu_do_badge,
  [PUDU_UI_SECURE] = pudu_do_secure, [PUDU_UI_TOAST] = pudu_do_toast,
};

/* Applies one commit: every instruction in order, in one call. */
void pudu_ui_apply(const void *stream, uint64_t length) {
  pudu_reader reader = { stream, length, 0 };
  while (reader.at < reader.length) {
    uint32_t code = pudu_word(&reader);
    if (code >= PUDU_UI_INSTRUCTIONS || pudu_instruction_table[code] == NULL) pudu_stream_defect("used unknown instruction", code);
    pudu_instruction_table[code](&reader);
  }
  pudu_list_reload();
  pudu_motion_commit(pudu_surface);
  if (pudu_first_frame_ms < 0) {
    [pudu_surface layoutIfNeeded];
    pudu_first_frame_ms = (CACurrentMediaTime() * 1000.0) - pudu_main_started_ms;
    printf("PUDU_FIRST_FRAME_MS %.1f\n", pudu_first_frame_ms);
    fflush(stdout);
  }
}

/* Prints what each shown node reports, in the order the screen shows them. */
static void pudu_report(UIView *view) {
  NSUInteger node = view == nil ? NSNotFound : [pudu_nodes indexOfObjectIdenticalTo:view];
  const pudu_kind *kind;
  if (node == NSNotFound) return;
  kind = pudu_node_kind((uint32_t)node);
  if (kind->shown != NULL) printf("PUDU_LABEL %s\n", kind->shown(view).UTF8String);
  if (kind->children != NULL) {
    for (UIView *child in kind->children(view).arrangedSubviews) pudu_report(child);
  }
}

/* The self-tests an environment variable selects, the first set one winning;
   each calls `done` once the program may stop. */
typedef struct {
  const char *variable;
  void (*run)(void (^done)(void));
} pudu_self_test;
static void pudu_run_capabilities(void (^done)(void)) { pudu_test_capabilities(pudu_nodes, done); }
static void pudu_run_images(void (^done)(void)) { pudu_test_images([pudu_nodes copy], done); }
static void pudu_run_controls(void (^done)(void)) { pudu_test_controls([pudu_nodes copy], [pudu_kinds copy], done); }
static void pudu_run_fetch(void (^done)(void)) { pudu_test_fetch(pudu_surface, done); }
static void pudu_run_refresh(void (^done)(void)) { pudu_test_refresh(pudu_surface, done); }
static void pudu_run_material(void (^done)(void)) { pudu_test_material(pudu_nodes, done); }
static void pudu_run_list(void (^done)(void)) { pudu_test_list(pudu_nodes, done); }
static void pudu_run_theme(void (^done)(void)) { pudu_test_theme(pudu_surface, pudu_nodes, done); }
static void pudu_run_keyboard(void (^done)(void)) { pudu_test_keyboard(pudu_surface, pudu_shown_root, pudu_nodes, done); }
static const pudu_self_test pudu_self_tests[] = {
  { "PUDU_UI_CAPABILITY_TEST", pudu_run_capabilities }, { "PUDU_UI_LINK_TEST", pudu_test_link },
  { "PUDU_UI_TABS_TEST", pudu_test_tabs }, { "PUDU_UI_PERMISSION_TEST", pudu_test_permissions },
  { "PUDU_UI_SYSTEM_TEST", pudu_test_system }, { "PUDU_UI_IMAGE_TEST", pudu_run_images },
  { "PUDU_UI_CONTROLS_TEST", pudu_run_controls }, { "PUDU_UI_NAVIGATION_TEST", pudu_test_navigation },
  { "PUDU_UI_FETCH_TEST", pudu_run_fetch }, { "PUDU_UI_REFRESH_TEST", pudu_run_refresh },
  { "PUDU_UI_MATERIAL_TEST", pudu_run_material }, { "PUDU_UI_LIST_TEST", pudu_run_list },
  { "PUDU_UI_THEME_TEST", pudu_run_theme }, { "PUDU_UI_KEYBOARD_TEST", pudu_run_keyboard },
  { "PUDU_UI_LOCATION_TEST", pudu_test_location }, { "PUDU_UI_SERVICES_TEST", pudu_test_services },
  { "PUDU_UI_WEB_TEST", pudu_test_web }, { "PUDU_UI_DEVICE_TEST", pudu_test_device },
};

@interface PuduAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
@implementation PuduAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
  (void)application;
  (void)options;
  UIViewController *controller = [PuduRootController new];
  controller.view.backgroundColor = UIColor.systemBackgroundColor;
  pudu_surface = controller.view;
  pudu_nodes = [NSMutableArray new];
  pudu_kinds = [NSMutableArray new];
  pudu_paints = [NSMutableArray new];
  pudu_theme_reset();
  pudu_alert_presenter = controller;
  pudu_observe_lifecycle();
  pudu_observe_memory();
  pudu_notify_launch();
  pudu_target = [PuduTarget new];
  /* Line-buffered output: a report reaches the console as soon as it is
     written, so a reader waiting on a line never waits on the buffer. */
  setvbuf(stdout, NULL, _IOLBF, 0);
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.rootViewController = controller;
  [self.window makeKeyAndVisible];
  pudu_available = pudu_available_area(pudu_surface);
  /* A run-loop timer, not the main queue: Pudu's wait runs the loop, and the
     main queue does not drain while one of its blocks is running. */
  [self performSelector:@selector(run) withObject:nil afterDelay:0];
  if (getenv("PUDU_UI_SELFTEST") != NULL) [self performSelector:@selector(selfTest) withObject:nil afterDelay:0.5];
  /* The link that launched the application, if one did, is its first report. */
  NSURL *launched = options[UIApplicationLaunchOptionsURLKey];
  if (launched != nil) pudu_queue(PUDU_UI_LINKED, 0, launched.absoluteString, 0);
  return YES;
}
/* A link opened while the application runs. */
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary *)options {
  (void)application;
  (void)options;
  pudu_queue(PUDU_UI_LINKED, 0, url.absoluteString, 0);
  return YES;
}
- (void)run {
  int status = pudu_program_run(0, NULL);
  printf("PUDU_PROGRAM_STATUS %d\n", status);
  fflush(stdout);
  if (getenv("PUDU_UI_SELFTEST") != NULL) {
    pudu_report(pudu_tabs != nil ? pudu_tabs_top() : pudu_navigator != nil ? pudu_navigation_top() : pudu_shown_root);
    if (getenv("PUDU_UI_CAPABILITY_TEST") != NULL) pudu_report_capabilities(pudu_nodes);
    fflush(stdout);
    exit(status);
  }
}
/* Types PUDU_UI_TYPE into every field and switches every toggle on when it
   is set, taps every button as many times as PUDU_UI_SELFTEST says, then asks
   the program to stop, exactly as a user's input would arrive. */
- (void)selfTest {
  for (size_t index = 0; index < sizeof pudu_self_tests / sizeof pudu_self_tests[0]; index++) {
    if (getenv(pudu_self_tests[index].variable) == NULL) continue;
    pudu_self_tests[index].run(^{ pudu_queue(PUDU_UI_STOPPED, 0, nil, 0); });
    return;
  }
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
  pudu_queue(PUDU_UI_STOPPED, 0, nil, 0);
}
@end

int main(int argc, char **argv) {
  pudu_main_started_ms = (CACurrentMediaTime() * 1000.0);
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([PuduAppDelegate class]));
  }
}
