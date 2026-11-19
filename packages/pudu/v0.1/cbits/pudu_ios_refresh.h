#ifndef PUDU_IOS_REFRESH_H
#define PUDU_IOS_REFRESH_H

/* Pull to refresh on a scroll or list. A user pull queues REFRESHED with the
   control's tag; the program owns whether it is refreshing and REFRESH sets
   that state. A pull the program did not answer by refreshing ends at the
   next wait after it read the report: the first moment it has handled it,
   and the last at which anything would end the indicator. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdio.h>
#include "pudu_ios_events.h"
#include "pudu_ios_nodes.h"
#include "pudu_ios_stream.h"

@interface PuduRefresh : UIRefreshControl
@property (nonatomic) uint32_t reported;
/* Whether the program asked to be refreshing. */
@property (nonatomic) BOOL wanted;
/* A user pull the program has not yet answered. */
@property (nonatomic) BOOL pulled;
@end

/* Controls with an unanswered pull. */
static NSHashTable<PuduRefresh *> *pudu_pulled;

@implementation PuduRefresh
- (void)pull {
  self.pulled = YES;
  [pudu_pulled addObject:self];
  pudu_queue(PUDU_UI_REFRESHED, self.reported, nil, 0);
}
@end

static BOOL pudu_refresh_pending(uint32_t reported) {
  uint64_t event = (PUDU_UI_REFRESHED << 32) | reported;
  for (NSArray *queued in pudu_events) {
    if ([queued[0] unsignedLongLongValue] == event) return YES;
  }
  return NO;
}

/* Run before each wait: ends every pull whose report the program has read
   without asking to refresh. */
static void pudu_refresh_settle(void) {
  for (PuduRefresh *control in pudu_pulled.allObjects) {
    if (pudu_refresh_pending(control.reported)) continue;
    control.pulled = NO;
    [pudu_pulled removeObject:control];
    if (!control.wanted && control.isRefreshing) [control endRefreshing];
  }
}

/* Gives `scroll` a refresh control reporting `reported`, or updates the one it
   has, and makes the indicator follow `on`. */
static void pudu_refresh_set(UIScrollView *scroll, uint32_t reported, BOOL on) {
  PuduRefresh *control = (PuduRefresh *)scroll.refreshControl;
  if (![control isKindOfClass:PuduRefresh.class]) {
    control = [PuduRefresh new];
    [control addTarget:control action:@selector(pull) forControlEvents:UIControlEventValueChanged];
    scroll.refreshControl = control;
    scroll.alwaysBounceVertical = YES;
  }
  if (pudu_pulled == nil) {
    pudu_pulled = [NSHashTable weakObjectsHashTable];
    pudu_before_wait = pudu_refresh_settle;
  }
  control.reported = reported;
  control.wanted = on;
  if (on && !control.isRefreshing) [control beginRefreshing];
  if (!on && control.isRefreshing && !control.pulled) [control endRefreshing];
}

/* REFRESH: the node, the tag its pulls report, and 1 or 0; refused on a node
   that does not scroll. */
static void pudu_do_refresh(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  uint32_t reported = pudu_word(reader);
  uint32_t on = pudu_word(reader);
  if (!pudu_node_scrolls(node)) pudu_stream_defect("refreshed a node that does not scroll:", node);
  if (on > 1) pudu_stream_defect("set refreshing to", on);
  pudu_refresh_set(pudu_nodes[node], reported, on == 1);
}

/* Starts a pull as the user's gesture would. */
static void pudu_refresh_pull(PuduRefresh *control) {
  [control beginRefreshing];
  [control sendActionsForControlEvents:UIControlEventValueChanged];
}

static PuduRefresh *pudu_refresh_find(UIView *view) {
  if ([view isKindOfClass:UIScrollView.class] && [((UIScrollView *)view).refreshControl isKindOfClass:PuduRefresh.class]) {
    return (PuduRefresh *)((UIScrollView *)view).refreshControl;
  }
  for (UIView *child in view.subviews) {
    PuduRefresh *found = pudu_refresh_find(child);
    if (found != nil) return found;
  }
  return nil;
}

static UIButton *pudu_refresh_button(UIView *view, NSString *title) {
  if ([view isKindOfClass:UIButton.class] && [((UIButton *)view).currentTitle isEqualToString:title]) return (UIButton *)view;
  for (UIView *child in view.subviews) {
    UIButton *found = pudu_refresh_button(child, title);
    if (found != nil) return found;
  }
  return nil;
}

static BOOL pudu_refresh_shows(UIView *view, NSString *prefix) {
  if ([view isKindOfClass:UILabel.class] && [((UILabel *)view).text hasPrefix:prefix]) return YES;
  for (UIView *child in view.subviews) {
    if (pudu_refresh_shows(child, prefix)) return YES;
  }
  return NO;
}

/* Self-test against the Refresh example: the first pull is answered and keeps
   refreshing until Done ends it; the second is not answered and stops by
   itself; the safe-area insets were reported. `done` asks the program to
   stop. */
static void pudu_test_refresh(UIView *surface, void (^done)(void)) {
  __block int step = 0;
  CFTimeInterval deadline = CACurrentMediaTime() + 20;
  [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
    PuduRefresh *control = pudu_refresh_find(surface);
    if (CACurrentMediaTime() >= deadline) {
      fprintf(stderr, "pudu: refresh test timed out at step %d\n", step);
      [timer invalidate];
      done();
      return;
    }
    if (control == nil || pudu_events.count > 0) return;
    if (step == 0 && pudu_refresh_shows(surface, @"Insets: ") && !pudu_refresh_shows(surface, @"Insets: none")) {
      puts("PUDU_REFRESH insets reported");
      pudu_refresh_pull(control);
      step = 1;
    } else if (step == 1 && control.isRefreshing && pudu_refresh_shows(surface, @"Pulls: 1")) {
      puts("PUDU_REFRESH answered pull refreshing");
      [pudu_refresh_button(surface, @"Done") sendActionsForControlEvents:UIControlEventTouchUpInside];
      step = 2;
    } else if (step == 2 && !control.isRefreshing) {
      puts("PUDU_REFRESH finished by the program");
      pudu_refresh_pull(control);
      step = 3;
    } else if (step == 3 && !control.isRefreshing && pudu_refresh_shows(surface, @"Pulls: 2")) {
      puts("PUDU_REFRESH unanswered pull stopped");
      fflush(stdout);
      [timer invalidate];
      done();
    }
  }];
}

#endif
