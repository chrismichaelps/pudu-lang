#ifndef PUDU_IOS_PERMISSION_H
#define PUDU_IOS_PERMISSION_H

/* Permissions. Each kind's code is compiled only when the application
   declares it (PUDU_PERMISSION_<KIND>), so an application never carries an
   API, framework or usage key it does not use. Requests are serialized: one
   system prompt at a time, started only while the application is active.
   Every answer reports PERMISSIONED with the kind and its state; returning to
   the foreground re-checks every kind the program has heard about and
   reports those that changed, so a change made in Settings reaches the
   program without it asking. iOS shows a prompt once, so a refusal is
   Blocked; Restricted (parental or device management) is Unavailable. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdio.h>
#include "pudu_ios_events.h"
#include "pudu_ios_nodes.h"
#include "pudu_ios_stream.h"
#if PUDU_PERMISSION_CAMERA || PUDU_PERMISSION_MICROPHONE
#import <AVFoundation/AVFoundation.h>
#endif
#if PUDU_PERMISSION_PHOTOS || PUDU_PERMISSION_PHOTOS_ADD
#import <Photos/Photos.h>
#endif
#if PUDU_PERMISSION_LOCATION || PUDU_PERMISSION_LOCATION_ALWAYS
#import <CoreLocation/CoreLocation.h>
#endif
#if PUDU_PERMISSION_NOTIFICATIONS
#import <UserNotifications/UserNotifications.h>
#endif
#if PUDU_PERMISSION_CONTACTS
#import <Contacts/Contacts.h>
#endif
#if PUDU_PERMISSION_CALENDAR
#import <EventKit/EventKit.h>
#endif
#if PUDU_PERMISSION_BLUETOOTH
#import <CoreBluetooth/CoreBluetooth.h>
#endif
#if PUDU_PERMISSION_MOTION
#import <CoreMotion/CoreMotion.h>
#endif

/* Kind and state codes; they match Std.Mobile.Permission. */
enum { PUDU_CAMERA, PUDU_MICROPHONE, PUDU_PHOTOS, PUDU_PHOTOS_ADD, PUDU_LOCATION, PUDU_LOCATION_ALWAYS, PUDU_NOTIFICATIONS,
       PUDU_CONTACTS, PUDU_CALENDAR, PUDU_BLUETOOTH, PUDU_MOTION, PUDU_PERMISSION_KINDS };
enum { PUDU_NOT_ASKED, PUDU_GRANTED, PUDU_LIMITED, PUDU_PROVISIONAL, PUDU_DENIED, PUDU_BLOCKED, PUDU_UNAVAILABLE };

typedef void (^pudu_answer)(uint32_t state);

/* One kind: where it stands, and asking the person, each answering a state. */
typedef struct {
  void (*status)(pudu_answer);
  void (*request)(pudu_answer);
} pudu_permission;

/* The common platform states: not determined, restricted, denied, allowed. */
static uint32_t pudu_permission_plain(NSInteger raw, NSInteger undetermined, NSInteger restricted, NSInteger denied) {
  if (raw == undetermined) return PUDU_NOT_ASKED;
  if (raw == restricted) return PUDU_UNAVAILABLE;
  if (raw == denied) return PUDU_BLOCKED;
  return PUDU_GRANTED;
}

/* Answers on the main queue, whatever queue the platform answered on. */
static void pudu_permission_main(pudu_answer answer, uint32_t state) {
  dispatch_async(dispatch_get_main_queue(), ^{ answer(state); });
}

#if PUDU_PERMISSION_CAMERA || PUDU_PERMISSION_MICROPHONE
static uint32_t pudu_capture_state(AVMediaType media) {
  return pudu_permission_plain([AVCaptureDevice authorizationStatusForMediaType:media], AVAuthorizationStatusNotDetermined,
                               AVAuthorizationStatusRestricted, AVAuthorizationStatusDenied);
}
static void pudu_capture_request(AVMediaType media, pudu_answer answer) {
  [AVCaptureDevice requestAccessForMediaType:media completionHandler:^(BOOL granted) {
    (void)granted;
    pudu_permission_main(answer, pudu_capture_state(media));
  }];
}
#endif
#if PUDU_PERMISSION_CAMERA
static void pudu_camera_status(pudu_answer answer) { answer(pudu_capture_state(AVMediaTypeVideo)); }
static void pudu_camera_request(pudu_answer answer) { pudu_capture_request(AVMediaTypeVideo, answer); }
#endif
#if PUDU_PERMISSION_MICROPHONE
static void pudu_microphone_status(pudu_answer answer) { answer(pudu_capture_state(AVMediaTypeAudio)); }
static void pudu_microphone_request(pudu_answer answer) { pudu_capture_request(AVMediaTypeAudio, answer); }
#endif

#if PUDU_PERMISSION_PHOTOS || PUDU_PERMISSION_PHOTOS_ADD
static uint32_t pudu_photo_state(PHAuthorizationStatus raw) {
  return raw == PHAuthorizationStatusLimited ? PUDU_LIMITED
                                             : pudu_permission_plain(raw, PHAuthorizationStatusNotDetermined, PHAuthorizationStatusRestricted,
                                                                     PHAuthorizationStatusDenied);
}
static void pudu_photo_request(PHAccessLevel level, pudu_answer answer) {
  [PHPhotoLibrary requestAuthorizationForAccessLevel:level handler:^(PHAuthorizationStatus raw) {
    pudu_permission_main(answer, pudu_photo_state(raw));
  }];
}
#endif
#if PUDU_PERMISSION_PHOTOS
static void pudu_photos_status(pudu_answer answer) {
  answer(pudu_photo_state([PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite]));
}
static void pudu_photos_request(pudu_answer answer) { pudu_photo_request(PHAccessLevelReadWrite, answer); }
#endif
#if PUDU_PERMISSION_PHOTOS_ADD
static void pudu_photos_add_status(pudu_answer answer) {
  answer(pudu_photo_state([PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly]));
}
static void pudu_photos_add_request(pudu_answer answer) { pudu_photo_request(PHAccessLevelAddOnly, answer); }
#endif

#if PUDU_PERMISSION_LOCATION || PUDU_PERMISSION_LOCATION_ALWAYS
/* The location manager's delegate answers the request waiting on it. An
   upgrade to always that the person declines changes nothing, so it also
   ends when the application becomes active again after the prompt. */
@interface PuduLocation : NSObject <CLLocationManagerDelegate>
@property (strong, nonatomic) CLLocationManager *manager;
@property (copy, nonatomic) void (^waiting)(void);
@end
@implementation PuduLocation
- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
  (void)manager;
  void (^waiting)(void) = self.waiting;
  self.waiting = nil;
  if (waiting != nil) waiting();
}
@end
static PuduLocation *pudu_location;
/* Whether always was asked for once; iOS never asks again after that. */
static NSString *const pudu_always_asked = @"org.pudu.permission.always-asked";

static CLLocationManager *pudu_location_manager(void) {
  if (pudu_location == nil) {
    pudu_location = [PuduLocation new];
    pudu_location.manager = [CLLocationManager new];
    pudu_location.manager.delegate = pudu_location;
  }
  return pudu_location.manager;
}
static uint32_t pudu_location_state(BOOL always) {
  CLLocationManager *manager = pudu_location_manager();
  CLAuthorizationStatus raw = manager.authorizationStatus;
  if (raw == kCLAuthorizationStatusNotDetermined) return PUDU_NOT_ASKED;
  if (raw == kCLAuthorizationStatusRestricted) return PUDU_UNAVAILABLE;
  if (raw == kCLAuthorizationStatusDenied) return PUDU_BLOCKED;
  if (always && raw == kCLAuthorizationStatusAuthorizedWhenInUse) {
    return [NSUserDefaults.standardUserDefaults boolForKey:pudu_always_asked] ? PUDU_BLOCKED : PUDU_DENIED;
  }
  return manager.accuracyAuthorization == CLAccuracyAuthorizationReducedAccuracy ? PUDU_LIMITED : PUDU_GRANTED;
}
#endif
#if PUDU_PERMISSION_LOCATION
static void pudu_location_status(pudu_answer answer) { answer(pudu_location_state(NO)); }
static void pudu_location_request(pudu_answer answer) {
  if (pudu_location_state(NO) != PUDU_NOT_ASKED) {
    answer(pudu_location_state(NO));
    return;
  }
  pudu_location.waiting = ^{ answer(pudu_location_state(NO)); };
  [pudu_location_manager() requestWhenInUseAuthorization];
}
#endif
#if PUDU_PERMISSION_LOCATION_ALWAYS
static void pudu_location_always_status(pudu_answer answer) { answer(pudu_location_state(YES)); }
/* Always is asked in two steps: while using first, then the upgrade. */
static void pudu_location_always_request(pudu_answer answer) {
  CLLocationManager *manager = pudu_location_manager();
  uint32_t state = pudu_location_state(YES);
  if (state != PUDU_NOT_ASKED && state != PUDU_DENIED) {
    answer(state);
    return;
  }
  if (manager.authorizationStatus == kCLAuthorizationStatusNotDetermined) {
    pudu_location.waiting = ^{ pudu_location_always_request(answer); };
    [manager requestWhenInUseAuthorization];
    return;
  }
  [NSUserDefaults.standardUserDefaults setBool:YES forKey:pudu_always_asked];
  __block id observer = nil;
  void (^finish)(void) = ^{
    if (observer != nil) [NSNotificationCenter.defaultCenter removeObserver:observer];
    observer = nil;
    pudu_location.waiting = nil;
    answer(pudu_location_state(YES));
  };
  pudu_location.waiting = finish;
  observer = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil
                                                              queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
    (void)note;
    if (pudu_location.waiting == finish) finish();
  }];
  [manager requestAlwaysAuthorization];
}
#endif

#if PUDU_PERMISSION_NOTIFICATIONS
static uint32_t pudu_notification_state(UNAuthorizationStatus raw) {
  switch (raw) {
    case UNAuthorizationStatusNotDetermined: return PUDU_NOT_ASKED;
    case UNAuthorizationStatusDenied: return PUDU_BLOCKED;
    case UNAuthorizationStatusProvisional: return PUDU_PROVISIONAL;
    default: return PUDU_GRANTED;
  }
}
static void pudu_notifications_status(pudu_answer answer) {
  [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
    pudu_permission_main(answer, pudu_notification_state(settings.authorizationStatus));
  }];
}
static void pudu_notifications_request(pudu_answer answer) {
  UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound;
  [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError *error) {
    (void)granted;
    (void)error;
    pudu_notifications_status(answer);
  }];
}
#endif

#if PUDU_PERMISSION_CONTACTS
static uint32_t pudu_contacts_state(void) {
  CNAuthorizationStatus raw = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
  /* Partial access, granted by the person on iOS 18 and later. */
  if ((NSInteger)raw == 4) return PUDU_LIMITED;
  return pudu_permission_plain(raw, CNAuthorizationStatusNotDetermined, CNAuthorizationStatusRestricted, CNAuthorizationStatusDenied);
}
static void pudu_contacts_status(pudu_answer answer) { answer(pudu_contacts_state()); }
static void pudu_contacts_request(pudu_answer answer) {
  [[CNContactStore new] requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError *error) {
    (void)granted;
    (void)error;
    pudu_permission_main(answer, pudu_contacts_state());
  }];
}
#endif

#if PUDU_PERMISSION_CALENDAR
static uint32_t pudu_calendar_state(void) {
  EKAuthorizationStatus raw = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
  /* Write-only access, iOS 17 and later. */
  if ((NSInteger)raw == 4) return PUDU_LIMITED;
  return pudu_permission_plain(raw, EKAuthorizationStatusNotDetermined, EKAuthorizationStatusRestricted, EKAuthorizationStatusDenied);
}
static EKEventStore *pudu_calendar_store;
static void pudu_calendar_status(pudu_answer answer) { answer(pudu_calendar_state()); }
static void pudu_calendar_request(pudu_answer answer) {
  if (pudu_calendar_store == nil) pudu_calendar_store = [EKEventStore new];
  void (^done)(BOOL, NSError *) = ^(BOOL granted, NSError *error) {
    (void)granted;
    (void)error;
    pudu_permission_main(answer, pudu_calendar_state());
  };
  if (@available(iOS 17.0, *)) [pudu_calendar_store requestFullAccessToEventsWithCompletion:done];
  else [pudu_calendar_store requestAccessToEntityType:EKEntityTypeEvent completion:done];
}
#endif

#if PUDU_PERMISSION_BLUETOOTH
/* Bluetooth is asked by starting a central manager; its first state update
   follows the person's answer. */
@interface PuduBluetooth : NSObject <CBCentralManagerDelegate>
@property (strong, nonatomic) CBCentralManager *central;
@property (copy, nonatomic) pudu_answer waiting;
@end
static uint32_t pudu_bluetooth_state(void) {
  return pudu_permission_plain(CBManager.authorization, CBManagerAuthorizationNotDetermined, CBManagerAuthorizationRestricted,
                               CBManagerAuthorizationDenied);
}
@implementation PuduBluetooth
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
  (void)central;
  pudu_answer waiting = self.waiting;
  self.waiting = nil;
  if (waiting != nil) waiting(pudu_bluetooth_state());
}
@end
static PuduBluetooth *pudu_bluetooth;
static void pudu_bluetooth_status(pudu_answer answer) { answer(pudu_bluetooth_state()); }
static void pudu_bluetooth_request(pudu_answer answer) {
  if (pudu_bluetooth_state() != PUDU_NOT_ASKED) {
    answer(pudu_bluetooth_state());
    return;
  }
  pudu_bluetooth = [PuduBluetooth new];
  pudu_bluetooth.waiting = answer;
  pudu_bluetooth.central = [[CBCentralManager alloc] initWithDelegate:pudu_bluetooth queue:nil
                                                              options:@{ CBCentralManagerOptionShowPowerAlertKey : @NO }];
}
#endif

#if PUDU_PERMISSION_MOTION
static uint32_t pudu_motion_state(void) {
  if (!CMMotionActivityManager.isActivityAvailable) return PUDU_UNAVAILABLE;
  return pudu_permission_plain(CMMotionActivityManager.authorizationStatus, CMAuthorizationStatusNotDetermined,
                               CMAuthorizationStatusRestricted, CMAuthorizationStatusDenied);
}
static CMMotionActivityManager *pudu_motion_manager;
static void pudu_motion_status(pudu_answer answer) { answer(pudu_motion_state()); }
/* Motion is asked by a query; its answer follows the person's. */
static void pudu_motion_request(pudu_answer answer) {
  if (pudu_motion_state() != PUDU_NOT_ASKED) {
    answer(pudu_motion_state());
    return;
  }
  if (pudu_motion_manager == nil) pudu_motion_manager = [CMMotionActivityManager new];
  NSDate *now = [NSDate date];
  [pudu_motion_manager queryActivityStartingFromDate:now toDate:now toQueue:NSOperationQueue.mainQueue
                                         withHandler:^(NSArray *activities, NSError *error) {
    (void)activities;
    (void)error;
    answer(pudu_motion_state());
  }];
}
#endif

/* Each declared kind's operations; an undeclared kind has none. */
static const pudu_permission pudu_permissions[PUDU_PERMISSION_KINDS] = {
#if PUDU_PERMISSION_CAMERA
  [PUDU_CAMERA] = { pudu_camera_status, pudu_camera_request },
#endif
#if PUDU_PERMISSION_MICROPHONE
  [PUDU_MICROPHONE] = { pudu_microphone_status, pudu_microphone_request },
#endif
#if PUDU_PERMISSION_PHOTOS
  [PUDU_PHOTOS] = { pudu_photos_status, pudu_photos_request },
#endif
#if PUDU_PERMISSION_PHOTOS_ADD
  [PUDU_PHOTOS_ADD] = { pudu_photos_add_status, pudu_photos_add_request },
#endif
#if PUDU_PERMISSION_LOCATION
  [PUDU_LOCATION] = { pudu_location_status, pudu_location_request },
#endif
#if PUDU_PERMISSION_LOCATION_ALWAYS
  [PUDU_LOCATION_ALWAYS] = { pudu_location_always_status, pudu_location_always_request },
#endif
#if PUDU_PERMISSION_NOTIFICATIONS
  [PUDU_NOTIFICATIONS] = { pudu_notifications_status, pudu_notifications_request },
#endif
#if PUDU_PERMISSION_CONTACTS
  [PUDU_CONTACTS] = { pudu_contacts_status, pudu_contacts_request },
#endif
#if PUDU_PERMISSION_CALENDAR
  [PUDU_CALENDAR] = { pudu_calendar_status, pudu_calendar_request },
#endif
#if PUDU_PERMISSION_BLUETOOTH
  [PUDU_BLUETOOTH] = { pudu_bluetooth_status, pudu_bluetooth_request },
#endif
#if PUDU_PERMISSION_MOTION
  [PUDU_MOTION] = { pudu_motion_status, pudu_motion_request },
#endif
};

/* The last state reported for each kind, or -1 before the first report;
   requests waiting their turn; and whether one is on screen. */
static int64_t pudu_permission_known[PUDU_PERMISSION_KINDS] = { -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 };
static NSMutableArray<NSNumber *> *pudu_permission_waiting;
static BOOL pudu_permission_asking;

static void pudu_permission_report(uint32_t kind, uint32_t state) {
  pudu_permission_known[kind] = state;
  pudu_queue(PUDU_UI_PERMISSIONED, kind, nil, state);
}

/* Asks the next waiting kind while the application is active. */
static void pudu_permission_next(void) {
  if (pudu_permission_asking || pudu_permission_waiting.count == 0) return;
  if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
  uint32_t kind = pudu_permission_waiting.firstObject.unsignedIntValue;
  [pudu_permission_waiting removeObjectAtIndex:0];
  pudu_permission_asking = YES;
  pudu_permissions[kind].request(^(uint32_t state) {
    pudu_permission_asking = NO;
    pudu_permission_report(kind, state);
    pudu_permission_next();
  });
}

/* Returning to the foreground: re-check every kind heard about, report the
   changed, then ask what is waiting. */
static void pudu_permission_observe(void) {
  static BOOL observing = NO;
  if (observing) return;
  observing = YES;
  pudu_permission_waiting = [NSMutableArray new];
  [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue
                                              usingBlock:^(NSNotification *note) {
    (void)note;
    for (uint32_t kind = 0; kind < PUDU_PERMISSION_KINDS; kind++) {
      if (pudu_permission_known[kind] < 0 || pudu_permissions[kind].status == NULL) continue;
      pudu_permissions[kind].status(^(uint32_t state) {
        if ((int64_t)state != pudu_permission_known[kind]) pudu_permission_report(kind, state);
      });
    }
    pudu_permission_next();
  }];
}

/* The kind an instruction names, refused when the application did not declare it. */
static uint32_t pudu_permission_kind(pudu_reader *reader) {
  uint32_t kind = pudu_word(reader);
  if (kind >= PUDU_PERMISSION_KINDS) pudu_stream_defect("named unknown permission", kind);
  if (pudu_permissions[kind].status == NULL) pudu_stream_defect("named a permission the application does not declare:", kind);
  return kind;
}

/* PERMISSIONS: a count, then each kind; each reports where it stands. */
static void pudu_do_permissions(pudu_reader *reader) {
  uint32_t count = pudu_word(reader);
  pudu_permission_observe();
  for (uint32_t i = 0; i < count; i++) {
    uint32_t kind = pudu_permission_kind(reader);
    pudu_permissions[kind].status(^(uint32_t state) { pudu_permission_report(kind, state); });
  }
}

/* PERMISSION: one kind, asked in its turn. */
static void pudu_do_permission(pudu_reader *reader) {
  uint32_t kind = pudu_permission_kind(reader);
  pudu_permission_observe();
  [pudu_permission_waiting addObject:@(kind)];
  pudu_permission_next();
}

/* SETTINGS: the application's page in Settings. */
static void pudu_do_settings(pudu_reader *reader) {
  (void)reader;
  [UIApplication.sharedApplication openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
}

/* The permission self-test: once every kind the program asked about has
   reported, prints each as `PUDU_PERMISSION <kind> <state>` and stops. */
static void pudu_test_permissions(void (^done)(void)) {
  __block int waited = 0;
  __block void (^check)(void);
  check = ^{
    BOOL settled = !pudu_permission_asking && pudu_permission_waiting.count == 0;
    if (!settled && waited++ < 50) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), check);
      return;
    }
    for (uint32_t kind = 0; kind < PUDU_PERMISSION_KINDS; kind++) {
      if (pudu_permission_known[kind] >= 0) printf("PUDU_PERMISSION %u %lld\n", kind, pudu_permission_known[kind]);
    }
    fflush(stdout);
    check = nil;
    done();
  };
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), check);
}

#endif
