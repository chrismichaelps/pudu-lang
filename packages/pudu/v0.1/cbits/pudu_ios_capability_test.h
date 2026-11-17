#ifndef PUDU_IOS_CAPABILITY_TEST_H
#define PUDU_IOS_CAPABILITY_TEST_H

/* Self-test of the capability headers. It acts as a person and the system
   would, in a fixed order, through the same paths real input takes: it takes
   the shown alert's second choice, fires each gesture on the first control
   carrying recognizers, picks a context menu's second item, posts a resign
   and a return to active, and taps Add twice. What the program made of it
   is reported after the program ends. */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdio.h>
#include "pudu_ios_access.h"
#include "pudu_ios_feedback.h"
#include "pudu_ios_gesture.h"
#include "pudu_ios_motion.h"

static void pudu_test_capabilities(NSArray *nodes, void (^done)(void)) {
  NSString *title = pudu_alert_choose(1);
  if (title != nil) printf("PUDU_ALERT %s\n", title.UTF8String);
  for (NSObject *node in nodes) {
    if (![node isKindOfClass:UIView.class]) continue;
    UIView *view = (UIView *)node;
    NSArray *recognizers = objc_getAssociatedObject(view, &pudu_gesture_key);
    PuduGestureTarget *target = recognizers != nil ? objc_getAssociatedObject(recognizers, &pudu_gesture_key) : nil;
    if (target != nil) {
      pudu_gesture_fire(target.tag, PUDU_GESTURE_PRESS, PUDU_PHASE_BEGAN, 0, 0);
      pudu_gesture_fire(target.tag, PUDU_GESTURE_PAN, PUDU_PHASE_CHANGED, 12, -7);
      pudu_gesture_fire(target.tag, PUDU_GESTURE_PINCH, PUDU_PHASE_CHANGED, 1500, 0);
      pudu_gesture_fire(target.tag, PUDU_GESTURE_ROTATION, PUDU_PHASE_CHANGED, 785, 0);
      pudu_gesture_fire(target.tag, PUDU_GESTURE_SWIPE, 2, 0, 0);
    }
    [pudu_menu_of(view) pick:1];
  }
  [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
  [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
  for (int tap = 0; tap < 2; tap++) {
    for (NSObject *node in nodes) {
      if ([node isKindOfClass:UIButton.class] && [[(UIButton *)node titleForState:UIControlStateNormal] isEqualToString:@"Add"]) {
        [(UIButton *)node sendActionsForControlEvents:UIControlEventTouchUpInside];
      }
    }
  }
  done();
}

/* After the program ends: the first control with an accessibility hint, and
   whether an animated group animated. */
static void pudu_report_capabilities(NSArray *nodes) {
  for (NSObject *node in nodes) {
    if ([node isKindOfClass:UIView.class] && ((UIView *)node).accessibilityHint.length > 0) {
      UIView *view = (UIView *)node;
      printf("PUDU_ACCESS header=%s hint=%s value=%s\n", (view.accessibilityTraits & UIAccessibilityTraitHeader) ? "yes" : "no",
             view.accessibilityHint.UTF8String, view.accessibilityValue.UTF8String);
      break;
    }
  }
  if (pudu_motion_runs > 0) puts("PUDU_MOTION animated");
}

#endif
