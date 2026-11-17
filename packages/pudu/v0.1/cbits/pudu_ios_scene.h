#ifndef PUDU_IOS_SCENE_H
#define PUDU_IOS_SCENE_H

/* The scene as Pudu sees it: its size in points and size class per axis,
   reported as RESIZED whenever either changes, and lifecycle transitions
   reported as LIFECYCLE in the order the platform posts them. Layout adapts
   to these values, never to a device model. */
#import <UIKit/UIKit.h>
#include <math.h>
#include <stdint.h>
#include "pudu_ios_events.h"

enum { PUDU_LIFECYCLE_ACTIVE = 1, PUDU_LIFECYCLE_INACTIVE = 2, PUDU_LIFECYCLE_BACKGROUND = 3,
       PUDU_LIFECYCLE_FOREGROUND = 4 };

/* The size class code of a trait value: 1 compact, 2 regular. */
static int32_t pudu_size_class(UIUserInterfaceSizeClass value) {
  return value == UIUserInterfaceSizeClassRegular ? 2 : 1;
}

/* The root controller: it reports its view's size and size classes once
   laid out, and again only when they change. */
@interface PuduRootController : UIViewController
@property (copy, nonatomic) NSArray<NSNumber *> *reported;
@end
@implementation PuduRootController
- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  CGSize size = self.view.bounds.size;
  NSArray<NSNumber *> *words = @[
    @((int32_t)lround(size.width)), @((int32_t)lround(size.height)),
    @(pudu_size_class(self.traitCollection.horizontalSizeClass)), @(pudu_size_class(self.traitCollection.verticalSizeClass)),
  ];
  if (size.width <= 0 || [words isEqualToArray:self.reported]) return;
  self.reported = words;
  pudu_queue_words(PUDU_UI_RESIZED, 0, nil, 0, words);
}
@end

/* Lifecycle notifications and the code each reports. */
static void pudu_observe_lifecycle(void) {
  NSDictionary<NSNotificationName, NSNumber *> *phases = @{
    UIApplicationDidBecomeActiveNotification : @(PUDU_LIFECYCLE_ACTIVE),
    UIApplicationWillResignActiveNotification : @(PUDU_LIFECYCLE_INACTIVE),
    UIApplicationDidEnterBackgroundNotification : @(PUDU_LIFECYCLE_BACKGROUND),
    UIApplicationWillEnterForegroundNotification : @(PUDU_LIFECYCLE_FOREGROUND),
  };
  for (NSNotificationName name in phases) {
    uint32_t code = phases[name].unsignedIntValue;
    [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
      (void)note;
      pudu_queue(PUDU_UI_LIFECYCLE, 0, nil, code);
    }];
  }
}

#endif
