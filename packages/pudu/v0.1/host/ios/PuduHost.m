/* The iOS host of a Pudu Native application: it starts the program once
   UIKit has launched, applies each commit's view stream to platform controls,
   and hands events back through a blocking wait that runs the main loop.
   Nothing here calls into Pudu; Pudu calls the two functions below. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "pudu_program.h"

/* Instruction codes and control kinds of the view stream; they match
   Std.Mobile.View. */
enum { PUDU_UI_CREATE = 1, PUDU_UI_TEXT = 2, PUDU_UI_APPEND = 3, PUDU_UI_ROOT = 4, PUDU_UI_TAG = 5, PUDU_UI_RESET = 6 };
enum { PUDU_UI_LABEL = 1, PUDU_UI_BUTTON = 2, PUDU_UI_COLUMN = 3 };
/* Event kinds in the high word of a host event. */
static const uint64_t PUDU_UI_TAPPED = 1, PUDU_UI_STOPPED = 2;

static NSMutableArray *pudu_nodes;
static NSMutableArray<NSNumber *> *pudu_events;
static UIView *pudu_surface;
static UIView *pudu_shown_root;
static double pudu_first_frame_ms = -1;

@interface PuduTarget : NSObject
- (void)tapped:(UIButton *)sender;
@end
@implementation PuduTarget
- (void)tapped:(UIButton *)sender {
  [pudu_events addObject:@((PUDU_UI_TAPPED << 32) | (uint32_t)sender.tag)];
}
@end
static PuduTarget *pudu_target;

/* Milliseconds on the monotonic clock since main began. */
static double pudu_main_started_ms;
static double pudu_now_ms(void) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (double)now.tv_sec * 1000.0 + (double)now.tv_nsec / 1e6;
}

static uint32_t pudu_word(const uint8_t *bytes, uint64_t length, uint64_t *at) {
  uint32_t value;
  if (*at + 4 > length) {
    fprintf(stderr, "pudu: a view stream ended inside an instruction\n");
    abort();
  }
  value = (uint32_t)bytes[*at] | (uint32_t)bytes[*at + 1] << 8 | (uint32_t)bytes[*at + 2] << 16 | (uint32_t)bytes[*at + 3] << 24;
  *at += 4;
  return value;
}

static id pudu_node(uint32_t node) {
  if (node >= pudu_nodes.count || pudu_nodes[node] == [NSNull null]) {
    fprintf(stderr, "pudu: a view stream named node %u before creating it\n", node);
    abort();
  }
  return pudu_nodes[node];
}

static UIView *pudu_created(uint32_t kind) {
  if (kind == PUDU_UI_LABEL) {
    UILabel *label = [UILabel new];
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
    label.adjustsFontForContentSizeCategory = YES;
    return label;
  }
  if (kind == PUDU_UI_BUTTON) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button addTarget:pudu_target action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
    return button;
  }
  if (kind == PUDU_UI_COLUMN) {
    UIStackView *column = [UIStackView new];
    column.axis = UILayoutConstraintAxisVertical;
    column.alignment = UIStackViewAlignmentCenter;
    column.spacing = 16;
    return column;
  }
  fprintf(stderr, "pudu: a view stream created unknown kind %u\n", kind);
  abort();
}

static void pudu_text(UIView *view, NSString *text) {
  if ([view isKindOfClass:[UILabel class]]) ((UILabel *)view).text = text;
  else if ([view isKindOfClass:[UIButton class]]) [(UIButton *)view setTitle:text forState:UIControlStateNormal];
}

/* Applies one commit: every instruction in order, in one call. */
void pudu_ui_apply(const void *stream, uint64_t length) {
  const uint8_t *bytes = stream;
  uint64_t at = 0;
  while (at < length) {
    uint32_t code = pudu_word(bytes, length, &at);
    if (code == PUDU_UI_CREATE) {
      uint32_t node = pudu_word(bytes, length, &at);
      uint32_t kind = pudu_word(bytes, length, &at);
      while (pudu_nodes.count <= node) [pudu_nodes addObject:[NSNull null]];
      pudu_nodes[node] = pudu_created(kind);
    } else if (code == PUDU_UI_TEXT) {
      uint32_t node = pudu_word(bytes, length, &at);
      uint32_t count = pudu_word(bytes, length, &at);
      if (at + count > length) {
        fprintf(stderr, "pudu: a view stream ended inside text\n");
        abort();
      }
      pudu_text(pudu_node(node), [[NSString alloc] initWithBytes:bytes + at length:count encoding:NSUTF8StringEncoding]);
      at += count;
    } else if (code == PUDU_UI_APPEND) {
      UIStackView *parent = pudu_node(pudu_word(bytes, length, &at));
      [parent addArrangedSubview:pudu_node(pudu_word(bytes, length, &at))];
    } else if (code == PUDU_UI_ROOT) {
      UIView *root = pudu_node(pudu_word(bytes, length, &at));
      [pudu_shown_root removeFromSuperview];
      pudu_shown_root = root;
      root.translatesAutoresizingMaskIntoConstraints = NO;
      [pudu_surface addSubview:root];
      [NSLayoutConstraint activateConstraints:@[
        [root.centerXAnchor constraintEqualToAnchor:pudu_surface.centerXAnchor],
        [root.centerYAnchor constraintEqualToAnchor:pudu_surface.centerYAnchor] ]];
    } else if (code == PUDU_UI_TAG) {
      UIView *view = pudu_node(pudu_word(bytes, length, &at));
      view.tag = (NSInteger)pudu_word(bytes, length, &at);
    } else if (code == PUDU_UI_RESET) {
      [pudu_shown_root removeFromSuperview];
      pudu_shown_root = nil;
      [pudu_nodes removeAllObjects];
    } else {
      fprintf(stderr, "pudu: a view stream used unknown instruction %u\n", code);
      abort();
    }
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
  NSNumber *next;
  while (pudu_events.count == 0) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, true);
  next = pudu_events.firstObject;
  [pudu_events removeObjectAtIndex:0];
  return next.unsignedLongLongValue;
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
    for (id view in pudu_nodes) {
      if ([view isKindOfClass:[UILabel class]]) printf("PUDU_LABEL %s\n", ((UILabel *)view).text.UTF8String);
    }
    fflush(stdout);
    exit(status);
  }
}
/* Taps every button as many times as PUDU_UI_SELFTEST says, then asks the
   program to stop, exactly as a user's taps would arrive. */
- (void)selfTest {
  int taps = atoi(getenv("PUDU_UI_SELFTEST"));
  for (int i = 0; i < taps; i++) {
    for (id view in [pudu_nodes copy]) {
      if ([view isKindOfClass:[UIButton class]]) [(UIButton *)view sendActionsForControlEvents:UIControlEventTouchUpInside];
    }
  }
  [pudu_events addObject:@(PUDU_UI_STOPPED << 32)];
}
@end

int main(int argc, char **argv) {
  pudu_main_started_ms = pudu_now_ms();
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([PuduAppDelegate class]));
  }
}
