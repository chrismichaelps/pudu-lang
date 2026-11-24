#ifndef PUDU_IOS_LOCATION_H
#define PUDU_IOS_LOCATION_H

/* Positions. Each LOCATE answers exactly once with LOCATED under its tag;
   TRACK sends LOCATED under tag 0 for each new position while on. The code
   that reads positions builds only when the manifest declares a location
   kind, which also links CoreLocation; without one, every LOCATE answers no
   position and TRACK reports nothing. A LOCATE never prompts the person. */
#import <UIKit/UIKit.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "pudu_ios_events.h"
#include "pudu_ios_stream.h"

enum { PUDU_ACCURACIES = 3 };

/* How many LOCATED events were queued, for the self-test. */
static unsigned pudu_located_count;

static void pudu_located_none(NSInteger tag) {
  pudu_located_count++;
  pudu_queue_words(PUDU_UI_LOCATED, tag, nil, 0, @[]);
}

static uint32_t pudu_location_accuracy(pudu_reader *reader) {
  uint32_t accuracy = pudu_word(reader);
  if (accuracy >= PUDU_ACCURACIES) pudu_stream_defect("used unknown location accuracy", accuracy);
  return accuracy;
}

#if PUDU_PERMISSION_LOCATION || PUDU_PERMISSION_LOCATION_ALWAYS
#import <CoreLocation/CoreLocation.h>

/* The manager reading positions, apart from the one that asks for permission;
   tags waiting on a fix, and whether tracking is on. */
@interface PuduPositions : NSObject <CLLocationManagerDelegate>
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) NSMutableArray<NSNumber *> *pending;
@property (nonatomic) BOOL tracking;
@end

static void pudu_located(NSInteger tag, CLLocation *location) {
  if (location == nil || location.horizontalAccuracy < 0) {
    pudu_located_none(tag);
    return;
  }
  pudu_located_count++;
  NSArray *words = @[ @((int32_t)lround(location.coordinate.latitude * 1e7)), @((int32_t)lround(location.coordinate.longitude * 1e7)),
                      @((int32_t)ceil(location.horizontalAccuracy)), @((int32_t)lround(location.altitude)) ];
  pudu_queue_words(PUDU_UI_LOCATED, tag, nil, 1, words);
}

@implementation PuduPositions
- (void)answer:(CLLocation *)location {
  NSArray<NSNumber *> *waiting = [self.pending copy];
  [self.pending removeAllObjects];
  for (NSNumber *tag in waiting) pudu_located(tag.integerValue, location);
}
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
  (void)manager;
  [self answer:locations.lastObject];
  if (self.tracking) pudu_located(0, locations.lastObject);
}
/* A fix not yet known is transient while tracking: updates continue. */
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
  (void)manager;
  if (self.tracking && error.code == kCLErrorLocationUnknown) return;
  [self answer:nil];
}
@end

static PuduPositions *pudu_positions;

static PuduPositions *pudu_positions_shared(void) {
  if (pudu_positions == nil) {
    pudu_positions = [PuduPositions new];
    pudu_positions.pending = [NSMutableArray new];
    pudu_positions.manager = [CLLocationManager new];
    pudu_positions.manager.delegate = pudu_positions;
  }
  return pudu_positions;
}

static BOOL pudu_location_allowed(CLLocationManager *manager) {
  CLAuthorizationStatus status = manager.authorizationStatus;
  return status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways;
}

/* The platform's accuracy for a code. The platform's values are not
   compile-time constants, so the table is built where it is read. */
static CLLocationAccuracy pudu_accuracy_of(uint32_t code) {
  const CLLocationAccuracy accuracies[PUDU_ACCURACIES] = { kCLLocationAccuracyBest, kCLLocationAccuracyHundredMeters,
                                                           kCLLocationAccuracyKilometer };
  return accuracies[code];
}

/* LOCATE: the tag, then the accuracy. While tracking, the latest fix answers at once. */
static void pudu_do_locate(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader), accuracy = pudu_location_accuracy(reader);
  PuduPositions *positions = pudu_positions_shared();
  if (!pudu_location_allowed(positions.manager) || !CLLocationManager.locationServicesEnabled) {
    pudu_located_none(tag);
    return;
  }
  if (positions.tracking && positions.manager.location != nil) {
    pudu_located(tag, positions.manager.location);
    return;
  }
  [positions.pending addObject:@(tag)];
  if (positions.tracking) return;
  positions.manager.desiredAccuracy = pudu_accuracy_of(accuracy);
  [positions.manager requestLocation];
}

/* TRACK: 1 or 0, the accuracy, then the minimum distance in meters. */
static void pudu_do_track(pudu_reader *reader) {
  uint32_t on = pudu_word(reader);
  if (on > 1) pudu_stream_defect("set location tracking to", on);
  uint32_t accuracy = pudu_location_accuracy(reader), distance = pudu_word(reader);
  PuduPositions *positions = pudu_positions_shared();
  if (on == 0) {
    positions.tracking = NO;
    [positions.manager stopUpdatingLocation];
    return;
  }
  if (!pudu_location_allowed(positions.manager)) return;
  positions.manager.desiredAccuracy = pudu_accuracy_of(accuracy);
  positions.manager.distanceFilter = distance == 0 ? kCLDistanceFilterNone : (CLLocationDistance)distance;
  positions.tracking = YES;
  [positions.manager startUpdatingLocation];
}

#else

static void pudu_do_locate(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  (void)pudu_location_accuracy(reader);
  pudu_located_none(tag);
}

static void pudu_do_track(pudu_reader *reader) {
  uint32_t on = pudu_word(reader);
  if (on > 1) pudu_stream_defect("set location tracking to", on);
  (void)pudu_location_accuracy(reader);
  (void)pudu_word(reader);
}

#endif

/* The location self-test: once a LOCATED has been queued, or after ten
   seconds, it reports how many were and stops. */
static void pudu_test_location(void (^done)(void)) {
  __block int waited = 0;
  __block void (^check)(void);
  check = ^{
    if (pudu_located_count == 0 && waited++ < 100) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), check);
      return;
    }
    printf("PUDU_LOCATION answered %s\n", pudu_located_count > 0 ? "yes" : "no");
    fflush(stdout);
    check = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), done);
  };
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), check);
}

#endif
