#ifndef PUDU_IOS_MOTION_H
#define PUDU_IOS_MOTION_H

/* Animated groups. A group marked by ANIMATE animates the layout change a
   commit makes to its children with the platform spring, once per commit;
   with Reduce Motion on the change is applied at once. */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static const char pudu_animated_key = 0;
static BOOL pudu_motion_pending;
static NSUInteger pudu_motion_runs;

static void pudu_motion_mark(UIView *group, BOOL on) {
  objc_setAssociatedObject(group, &pudu_animated_key, on ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/* Notes that a commit placed or removed a child of `group`. */
static void pudu_motion_touch(UIView *group) {
  if (group != nil && objc_getAssociatedObject(group, &pudu_animated_key) != nil) pudu_motion_pending = YES;
}

/* At the end of a commit: animates the surface's layout if an animated
   group changed. */
static void pudu_motion_commit(UIView *surface) {
  if (!pudu_motion_pending) return;
  pudu_motion_pending = NO;
  if (UIAccessibilityIsReduceMotionEnabled()) {
    [surface layoutIfNeeded];
    return;
  }
  pudu_motion_runs++;
  [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                   animations:^{ [surface layoutIfNeeded]; }
                   completion:nil];
}

#endif
