#ifndef PUDU_IOS_GESTURE_H
#define PUDU_IOS_GESTURE_H

/* Gesture recognizers a Pudu control carries. Each recognizer reports one
   event: kind GESTURED with the wrapper's tag, the recognizer's bit as
   detail, and its phase and values as words. A swipe carries one recognizer
   per direction. */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <math.h>
#include <stdint.h>
#include "pudu_ios_events.h"

enum { PUDU_GESTURE_PRESS = 1, PUDU_GESTURE_PAN = 2, PUDU_GESTURE_PINCH = 4, PUDU_GESTURE_ROTATION = 8,
       PUDU_GESTURE_SWIPE = 16 };
enum { PUDU_PHASE_BEGAN = 1, PUDU_PHASE_CHANGED = 2, PUDU_PHASE_ENDED = 3, PUDU_PHASE_CANCELLED = 4 };

/* Reports a gesture the way a recognizer does. */
static void pudu_gesture_fire(NSInteger tag, uint32_t bit, int32_t first, int32_t second, int32_t third) {
  pudu_queue_words(PUDU_UI_GESTURED, tag, nil, bit, @[ @(first), @(second), @(third) ]);
}

/* The phase code of a recognizer state, or zero for states never reported. */
static int32_t pudu_gesture_phase(UIGestureRecognizerState state) {
  static const int32_t phases[] = {
    [UIGestureRecognizerStateBegan] = PUDU_PHASE_BEGAN, [UIGestureRecognizerStateChanged] = PUDU_PHASE_CHANGED,
    [UIGestureRecognizerStateEnded] = PUDU_PHASE_ENDED, [UIGestureRecognizerStateCancelled] = PUDU_PHASE_CANCELLED,
  };
  return (NSUInteger)state < sizeof phases / sizeof phases[0] ? phases[state] : 0;
}

@interface PuduGestureTarget : NSObject
@property (nonatomic) NSInteger tag;
@end
@implementation PuduGestureTarget
- (void)pressed:(UILongPressGestureRecognizer *)recognizer {
  int32_t phase = pudu_gesture_phase(recognizer.state);
  if (phase != 0) pudu_gesture_fire(self.tag, PUDU_GESTURE_PRESS, phase, 0, 0);
}
- (void)panned:(UIPanGestureRecognizer *)recognizer {
  CGPoint moved = [recognizer translationInView:recognizer.view];
  int32_t phase = pudu_gesture_phase(recognizer.state);
  if (phase != 0) pudu_gesture_fire(self.tag, PUDU_GESTURE_PAN, phase, (int32_t)lround(moved.x), (int32_t)lround(moved.y));
}
- (void)pinched:(UIPinchGestureRecognizer *)recognizer {
  int32_t phase = pudu_gesture_phase(recognizer.state);
  if (phase != 0) pudu_gesture_fire(self.tag, PUDU_GESTURE_PINCH, phase, (int32_t)lround(recognizer.scale * 1000), 0);
}
- (void)rotated:(UIRotationGestureRecognizer *)recognizer {
  int32_t phase = pudu_gesture_phase(recognizer.state);
  if (phase != 0) pudu_gesture_fire(self.tag, PUDU_GESTURE_ROTATION, phase, (int32_t)lround(recognizer.rotation * 1000), 0);
}
- (void)swiped:(UISwipeGestureRecognizer *)recognizer {
  static const int32_t directions[] = {
    [UISwipeGestureRecognizerDirectionLeft] = 1, [UISwipeGestureRecognizerDirectionRight] = 2,
    [UISwipeGestureRecognizerDirectionUp] = 3, [UISwipeGestureRecognizerDirectionDown] = 4,
  };
  pudu_gesture_fire(self.tag, PUDU_GESTURE_SWIPE, directions[recognizer.direction], 0, 0);
}
@end

static const char pudu_gesture_key = 0;

/* Replaces a control's Pudu recognizers with those in `mask`. */
static void pudu_gestures_attach(UIView *control, uint32_t tag, uint32_t mask) {
  PuduGestureTarget *target = [PuduGestureTarget new];
  NSMutableArray<UIGestureRecognizer *> *made = [NSMutableArray new];
  for (UIGestureRecognizer *old in objc_getAssociatedObject(control, &pudu_gesture_key)) [control removeGestureRecognizer:old];
  target.tag = tag;
  if (mask & PUDU_GESTURE_PRESS) [made addObject:[[UILongPressGestureRecognizer alloc] initWithTarget:target action:@selector(pressed:)]];
  if (mask & PUDU_GESTURE_PAN) [made addObject:[[UIPanGestureRecognizer alloc] initWithTarget:target action:@selector(panned:)]];
  if (mask & PUDU_GESTURE_PINCH) [made addObject:[[UIPinchGestureRecognizer alloc] initWithTarget:target action:@selector(pinched:)]];
  if (mask & PUDU_GESTURE_ROTATION) [made addObject:[[UIRotationGestureRecognizer alloc] initWithTarget:target action:@selector(rotated:)]];
  if (mask & PUDU_GESTURE_SWIPE) {
    const UISwipeGestureRecognizerDirection directions[] = {
      UISwipeGestureRecognizerDirectionLeft, UISwipeGestureRecognizerDirectionRight,
      UISwipeGestureRecognizerDirectionUp, UISwipeGestureRecognizerDirectionDown,
    };
    for (size_t i = 0; i < sizeof directions / sizeof directions[0]; i++) {
      UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:target action:@selector(swiped:)];
      swipe.direction = directions[i];
      [made addObject:swipe];
    }
  }
  for (UIGestureRecognizer *recognizer in made) [control addGestureRecognizer:recognizer];
  control.userInteractionEnabled = control.userInteractionEnabled || made.count > 0;
  /* The target lives as long as its recognizers. */
  objc_setAssociatedObject(control, &pudu_gesture_key, made, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(made, &pudu_gesture_key, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#endif
