#ifndef PUDU_IOS_FETCH_H
#define PUDU_IOS_FETCH_H

/* Requests the program describes, sent on the platform's URL session. The
   session's protocol cache revalidates with ETag and Last-Modified without
   the program asking. Each request runs under the generation the program gave
   it, and its answer is queued as FETCHED: the generation, the status (0 when
   nothing arrived), the body as text, and the Retry-After delay in
   milliseconds as one word, -1 when absent. A cancelled generation is never
   answered, even when its answer was already queued. WAKE keeps one timer;
   the platform's memory warnings are queued as MEMORY. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include "pudu_ios_events.h"
#include "pudu_ios_stream.h"

static NSURLSession *pudu_session;
/* Tasks by generation; a generation leaves this table when it is answered
   or cancelled, whichever comes first. */
static NSMutableDictionary<NSNumber *, NSURLSessionDataTask *> *pudu_flights;
static NSTimer *pudu_wake_timer;

/* Answers arrive on the main queue, which the wait's run loop drains. */
static NSURLSession *pudu_fetch_session(void) {
  if (pudu_session == nil) {
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.defaultSessionConfiguration;
    configuration.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
    pudu_session = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:NSOperationQueue.mainQueue];
    pudu_flights = [NSMutableDictionary new];
  }
  return pudu_session;
}

/* Retry-After in milliseconds, from delay seconds or an HTTP date; -1 when
   absent or unreadable. */
static int32_t pudu_retry_after(NSHTTPURLResponse *response) {
  NSString *value = [response valueForHTTPHeaderField:@"Retry-After"];
  long long seconds = 0;
  if (value.length == 0) return -1;
  NSScanner *scanner = [NSScanner scannerWithString:value];
  if ([scanner scanLongLong:&seconds] && scanner.isAtEnd) return (int32_t)MIN(MAX(seconds, 0LL) * 1000LL, (long long)INT32_MAX);
  NSDateFormatter *format = [NSDateFormatter new];
  format.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  format.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss zzz";
  NSDate *date = [format dateFromString:value];
  if (date == nil) return -1;
  return (int32_t)MIN(MAX(date.timeIntervalSinceNow, 0.0) * 1000.0, (double)INT32_MAX);
}

/* Drops an answer for `generation` that is queued but not yet read. */
static void pudu_fetch_unqueue(uint32_t generation) {
  uint64_t event = (PUDU_UI_FETCHED << 32) | generation;
  NSIndexSet *stale = [pudu_events indexesOfObjectsPassingTest:^BOOL(NSArray *queued, NSUInteger index, BOOL *stop) {
    (void)index;
    (void)stop;
    return [queued[0] unsignedLongLongValue] == event;
  }];
  [pudu_events removeObjectsAtIndexes:stale];
}

/* FETCH: the generation, method, URL, header count, each header's name and
   value, then the body. A generation already in flight, generation 0, or a URL
   without a scheme is a defect of the program. */
static void pudu_do_fetch(pudu_reader *reader) {
  uint32_t generation = pudu_word(reader);
  NSString *method = pudu_text(reader);
  NSURL *url = [NSURL URLWithString:pudu_text(reader)];
  uint32_t count = pudu_word(reader);
  NSMutableURLRequest *request = url == nil ? nil : [NSMutableURLRequest requestWithURL:url];
  for (uint32_t i = 0; i < count; i++) {
    NSString *name = pudu_text(reader);
    [request setValue:pudu_text(reader) forHTTPHeaderField:name];
  }
  NSString *body = pudu_text(reader);
  if (generation == 0) pudu_stream_defect("sent a request without a generation", generation);
  if (url == nil || url.scheme == nil) pudu_stream_defect("sent a request to an unreadable URL, generation", generation);
  NSURLSession *session = pudu_fetch_session();
  if (pudu_flights[@(generation)] != nil) pudu_stream_defect("sent two requests under generation", generation);
  request.HTTPMethod = method;
  if (body.length > 0) request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
  NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if (pudu_flights[@(generation)] == nil) return;
    [pudu_flights removeObjectForKey:@(generation)];
    NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
    uint32_t status = error != nil || http == nil ? 0 : (uint32_t)http.statusCode;
    NSString *text = error != nil ? error.localizedDescription
                                  : ([[NSString alloc] initWithData:data ?: [NSData data] encoding:NSUTF8StringEncoding] ?: @"");
    pudu_queue_words(PUDU_UI_FETCHED, generation, text, status, @[ @(http == nil ? -1 : pudu_retry_after(http)) ]);
  }];
  pudu_flights[@(generation)] = task;
  [task resume];
}

/* CANCEL: the generation; unknown or already answered generations are
   ignored, since the program may cancel what has just landed. */
static void pudu_do_cancel(pudu_reader *reader) {
  uint32_t generation = pudu_word(reader);
  NSURLSessionDataTask *task = pudu_flights[@(generation)];
  [pudu_flights removeObjectForKey:@(generation)];
  [task cancel];
  pudu_fetch_unqueue(generation);
}

/* WAKE: milliseconds until one WOKE event, replacing any earlier wake. */
static void pudu_do_wake(pudu_reader *reader) {
  uint32_t delay = pudu_word(reader);
  [pudu_wake_timer invalidate];
  pudu_wake_timer = [NSTimer scheduledTimerWithTimeInterval:delay / 1000.0 repeats:NO block:^(NSTimer *timer) {
    (void)timer;
    pudu_wake_timer = nil;
    pudu_queue(PUDU_UI_WOKE, 0, nil, 0);
  }];
}

static BOOL pudu_fetch_shows(UIView *view, NSString *prefix) {
  if ([view isKindOfClass:UILabel.class] && [((UILabel *)view).text hasPrefix:prefix]) return YES;
  for (UIView *child in view.subviews) {
    if (pudu_fetch_shows(child, prefix)) return YES;
  }
  return NO;
}

/* Self-test against the Remote example and the test server: stop once both
   lines show a loaded result, so the server can count what was sent. */
static void pudu_test_fetch(UIView *surface, void (^done)(void)) {
  CFTimeInterval deadline = CACurrentMediaTime() + 30;
  [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
    BOOL loaded = pudu_fetch_shows(surface, @"Profile: 200") && pudu_fetch_shows(surface, @"Limited: 200");
    if (!loaded && CACurrentMediaTime() < deadline) return;
    if (loaded) puts("PUDU_FETCH loaded");
    else fprintf(stderr, "pudu: fetch test timed out\n");
    fflush(stdout);
    [timer invalidate];
    done();
  }];
}

static void pudu_observe_memory(void) {
  [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:nil
                                              usingBlock:^(NSNotification *note) {
    (void)note;
    pudu_queue(PUDU_UI_MEMORY, 0, nil, 0);
  }];
}

#endif
