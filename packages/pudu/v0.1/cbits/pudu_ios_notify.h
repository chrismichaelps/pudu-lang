#ifndef PUDU_IOS_NOTIFY_H
#define PUDU_IOS_NOTIFY_H

/* Local notifications and device-owner authentication. Notifications build
   only when the manifest declares the notifications kind, which also links
   UserNotifications; without it NOTIFY and UNNOTIFY change nothing. A
   notification's identifier is `pudu.<id>`; a tap on one queues NOTIFIED
   with the id, including the tap that launched the application, since the
   delegate is set before launching finishes. AUTHENTICATE answers exactly
   once with AUTHENTICATED. */
#import <LocalAuthentication/LocalAuthentication.h>
#import <UIKit/UIKit.h>
#include <stdint.h>
#include "pudu_ios_events.h"
#include "pudu_ios_stream.h"

/* How many AUTHENTICATED events were queued, and the evaluation waiting on
   the person, for the services self-test. */
static unsigned pudu_authenticated_count;
static LAContext *pudu_authenticating;

/* Cancels the evaluation on screen, as the person dismissing it would; it
   answers false. */
static void pudu_authentication_cancel(void) { [pudu_authenticating invalidate]; }

#if PUDU_PERMISSION_NOTIFICATIONS
#import <UserNotifications/UserNotifications.h>

static NSString *pudu_notification_identifier(uint32_t id) { return [NSString stringWithFormat:@"pudu.%u", id]; }

/* Shows banners while the application is in front, and reports taps. */
@interface PuduNotifications : NSObject <UNUserNotificationCenterDelegate>
@end
@implementation PuduNotifications
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completion {
  (void)center;
  (void)notification;
  completion(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList | UNNotificationPresentationOptionSound);
}
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
             withCompletionHandler:(void (^)(void))completion {
  (void)center;
  NSString *identifier = response.notification.request.identifier;
  if ([identifier hasPrefix:@"pudu."]) {
    long long id = [identifier substringFromIndex:5].longLongValue;
    if (id >= 0 && id <= UINT32_MAX) pudu_queue(PUDU_UI_NOTIFIED, (NSInteger)id, nil, 0);
  }
  completion();
}
@end

static PuduNotifications *pudu_notifications;

static void pudu_notify_launch(void) {
  pudu_notifications = [PuduNotifications new];
  UNUserNotificationCenter.currentNotificationCenter.delegate = pudu_notifications;
}

/* NOTIFY: the id, the delay in seconds, the title, then the body. */
static void pudu_do_notify(pudu_reader *reader) {
  uint32_t id = pudu_word(reader), delay = pudu_word(reader);
  NSString *title = pudu_text(reader), *body = pudu_text(reader);
  UNMutableNotificationContent *content = [UNMutableNotificationContent new];
  content.title = title;
  content.body = body;
  content.sound = UNNotificationSound.defaultSound;
  UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:MAX(delay, 1) repeats:NO];
  UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:pudu_notification_identifier(id) content:content trigger:trigger];
  [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:nil];
}

/* UNNOTIFY: the id. */
static void pudu_do_unnotify(pudu_reader *reader) {
  NSArray *identifiers = @[ pudu_notification_identifier(pudu_word(reader)) ];
  [UNUserNotificationCenter.currentNotificationCenter removePendingNotificationRequestsWithIdentifiers:identifiers];
  [UNUserNotificationCenter.currentNotificationCenter removeDeliveredNotificationsWithIdentifiers:identifiers];
}

#else

static void pudu_notify_launch(void) {}

static void pudu_do_notify(pudu_reader *reader) {
  (void)pudu_word(reader);
  (void)pudu_word(reader);
  (void)pudu_text(reader);
  (void)pudu_text(reader);
}

static void pudu_do_unnotify(pudu_reader *reader) { (void)pudu_word(reader); }

#endif

/* AUTHENTICATE: the tag, then the reason. A device with neither biometrics
   nor a passcode cannot evaluate the policy and answers false at once. */
static void pudu_do_authenticate(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  NSString *reason = pudu_text(reader);
  LAContext *context = [LAContext new];
  void (^answer)(BOOL) = ^(BOOL confirmed) {
    pudu_authenticated_count++;
    pudu_queue(PUDU_UI_AUTHENTICATED, tag, nil, confirmed ? 1 : 0);
  };
  if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:nil]) {
    answer(NO);
    return;
  }
  pudu_authenticating = context;
  [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:reason.length > 0 ? reason : @" " reply:^(BOOL confirmed, NSError *error) {
    (void)error;
    dispatch_async(dispatch_get_main_queue(), ^{
      if (pudu_authenticating == context) pudu_authenticating = nil;
      answer(confirmed);
    });
  }];
}

#endif
