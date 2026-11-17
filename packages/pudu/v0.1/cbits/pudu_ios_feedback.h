#ifndef PUDU_IOS_FEEDBACK_H
#define PUDU_IOS_FEEDBACK_H

/* Alerts, haptics and indicators. One alert is shown at a time; later ones
   wait their turn. A choice reports CHOSE with the alert's tag and the
   choice's index. Haptics run on the platform's feedback generators. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "pudu_ios_events.h"

enum { PUDU_ROLES_KNOWN = 3, PUDU_HAPTICS = 8 };

/* A pending alert: its controller, and each choice's handler in order. */
@interface PuduAlert : NSObject
@property (strong, nonatomic) UIAlertController *controller;
@property (strong, nonatomic) NSArray<void (^)(void)> *handlers;
@end
@implementation PuduAlert
@end

static NSMutableArray<PuduAlert *> *pudu_alerts;
static PuduAlert *pudu_shown_alert;
static UIViewController *pudu_alert_presenter;

static void pudu_alert_next(void) {
  if (pudu_shown_alert != nil || pudu_alerts.count == 0 || pudu_alert_presenter == nil) return;
  pudu_shown_alert = pudu_alerts.firstObject;
  [pudu_alerts removeObjectAtIndex:0];
  UIAlertController *controller = pudu_shown_alert.controller;
  /* An action sheet on a large screen needs an anchor. */
  controller.popoverPresentationController.sourceView = pudu_alert_presenter.view;
  controller.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(pudu_alert_presenter.view.bounds),
                                                                   CGRectGetMaxY(pudu_alert_presenter.view.bounds), 1, 1);
  [pudu_alert_presenter presentViewController:controller animated:YES completion:nil];
}

/* Queues an alert; `choices` are role and label pairs. A style or role
   outside the known ones answers NO and nothing is queued. */
static BOOL pudu_alert_show(NSInteger tag, uint32_t style, NSString *title, NSString *message, NSArray<NSArray *> *choices) {
  if (style > 1) return NO;
  static const UIAlertControllerStyle styles[] = { UIAlertControllerStyleAlert, UIAlertControllerStyleActionSheet };
  static const UIAlertActionStyle roles[PUDU_ROLES_KNOWN] = {
    UIAlertActionStyleDefault, UIAlertActionStyleCancel, UIAlertActionStyleDestructive,
  };
  UIAlertController *controller = [UIAlertController
    alertControllerWithTitle:title message:message
              preferredStyle:styles[style]];
  NSMutableArray<void (^)(void)> *handlers = [NSMutableArray new];
  if (pudu_alerts == nil) pudu_alerts = [NSMutableArray new];
  for (NSUInteger index = 0; index < choices.count; index++) {
    uint32_t role = [choices[index][0] unsignedIntValue];
    if (role >= PUDU_ROLES_KNOWN) return NO;
    void (^chosen)(void) = ^{
      pudu_queue(PUDU_UI_CHOSE, tag, nil, (uint32_t)index);
      pudu_shown_alert = nil;
      dispatch_async(dispatch_get_main_queue(), ^{ pudu_alert_next(); });
    };
    [handlers addObject:chosen];
    [controller addAction:[UIAlertAction actionWithTitle:choices[index][1] style:roles[role]
                                                 handler:^(UIAlertAction *action) { (void)action; chosen(); }]];
  }
  PuduAlert *alert = [PuduAlert new];
  alert.controller = controller;
  alert.handlers = handlers;
  [pudu_alerts addObject:alert];
  pudu_alert_next();
  return YES;
}

/* Takes choice `index` of the shown alert as a person would; answers the
   alert's title, or nil when none is shown. */
static NSString *pudu_alert_choose(NSUInteger index) {
  PuduAlert *alert = pudu_shown_alert;
  if (alert == nil || index >= alert.handlers.count) return nil;
  NSString *title = alert.controller.title;
  [alert.controller dismissViewControllerAnimated:NO completion:nil];
  alert.handlers[index]();
  return title;
}

/* One player per HAPTIC code; zero is never written. */
static void pudu_haptic_selection(void) { [[UISelectionFeedbackGenerator new] selectionChanged]; }
static void pudu_haptic_impact(UIImpactFeedbackStyle style) { [[[UIImpactFeedbackGenerator alloc] initWithStyle:style] impactOccurred]; }
static void pudu_haptic_light(void) { pudu_haptic_impact(UIImpactFeedbackStyleLight); }
static void pudu_haptic_medium(void) { pudu_haptic_impact(UIImpactFeedbackStyleMedium); }
static void pudu_haptic_heavy(void) { pudu_haptic_impact(UIImpactFeedbackStyleHeavy); }
static void pudu_haptic_outcome(UINotificationFeedbackType type) { [[UINotificationFeedbackGenerator new] notificationOccurred:type]; }
static void pudu_haptic_success(void) { pudu_haptic_outcome(UINotificationFeedbackTypeSuccess); }
static void pudu_haptic_warning(void) { pudu_haptic_outcome(UINotificationFeedbackTypeWarning); }
static void pudu_haptic_failure(void) { pudu_haptic_outcome(UINotificationFeedbackTypeError); }
static void (*const pudu_haptic_players[PUDU_HAPTICS])(void) = {
  NULL, pudu_haptic_selection, pudu_haptic_light, pudu_haptic_medium, pudu_haptic_heavy,
  pudu_haptic_success, pudu_haptic_warning, pudu_haptic_failure,
};

/* Plays a haptic; answers NO for a code outside the known ones. */
static BOOL pudu_haptic_play(uint32_t code) {
  if (code >= PUDU_HAPTICS || pudu_haptic_players[code] == NULL) return NO;
  pudu_haptic_players[code]();
  if (getenv("PUDU_UI_SELFTEST") != NULL) printf("PUDU_HAPTIC %u\n", code);
  return YES;
}

/* Indicators: a determinate progress bar and an activity indicator. */
static UIView *pudu_make_progress(void) {
  UIProgressView *bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
  [bar.widthAnchor constraintGreaterThanOrEqualToConstant:200].active = YES;
  return bar;
}

static void pudu_progress_value(UIView *view, uint32_t permille) {
  ((UIProgressView *)view).progress = (float)MIN(permille, 1000u) / 1000.0f;
}

static UIView *pudu_make_activity(void) {
  UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  spinner.hidesWhenStopped = NO;
  return spinner;
}

static void pudu_activity_state(UIView *view, uint32_t on) {
  if (on) [(UIActivityIndicatorView *)view startAnimating];
  else [(UIActivityIndicatorView *)view stopAnimating];
}

#endif
