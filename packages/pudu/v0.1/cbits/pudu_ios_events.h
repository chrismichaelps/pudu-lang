#ifndef PUDU_IOS_EVENTS_H
#define PUDU_IOS_EVENTS_H

/* The host's event queue. Controls queue events while the main loop runs
   inside a wait; Pudu takes them one at a time, then asks for the text and
   detail of the event it was handed. */
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Event kinds in the high word of an event; they match Std.Mobile.View. */
static const uint64_t PUDU_UI_TAPPED = 1, PUDU_UI_STOPPED = 2, PUDU_UI_CHANGED = 3, PUDU_UI_SWITCHED_ON = 4,
                      PUDU_UI_SWITCHED_OFF = 5, PUDU_UI_REACHED = 8;

/* Each queued event is its 64-bit value, its text and its detail word. */
static NSMutableArray<NSArray *> *pudu_events;
static char *pudu_event_text_bytes;
static uint32_t pudu_event_detail_word;

static void pudu_queue(uint64_t kind, NSInteger tag, NSString *text, uint32_t detail) {
  if (pudu_events == nil) pudu_events = [NSMutableArray new];
  [pudu_events addObject:@[ @((kind << 32) | (uint32_t)tag), text ?: @"", @(detail) ]];
}

/* The list self-test must let queued viewport reports settle before stopping. */
static BOOL pudu_reached_pending(NSInteger tag) {
  uint64_t event = (PUDU_UI_REACHED << 32) | (uint32_t)tag;
  for (NSArray *queued in pudu_events) {
    if ([queued[0] unsignedLongLongValue] == event) return YES;
  }
  return NO;
}

/* The next event; the main loop runs, and controls queue events, until one
   is waiting. */
uint64_t pudu_ui_wait(void) {
  NSArray *next;
  if (pudu_events == nil) pudu_events = [NSMutableArray new];
  while (pudu_events.count == 0) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, true);
  next = pudu_events.firstObject;
  [pudu_events removeObjectAtIndex:0];
  free(pudu_event_text_bytes);
  pudu_event_text_bytes = strdup([next[1] UTF8String]);
  if (pudu_event_text_bytes == NULL) abort();
  pudu_event_detail_word = [next[2] unsignedIntValue];
  return [next[0] unsignedLongLongValue];
}

/* The text the last event carried; valid until the next wait. */
const char *pudu_ui_event_text(void) { return pudu_event_text_bytes != NULL ? pudu_event_text_bytes : ""; }

/* The detail word the last event carried; valid until the next wait. */
uint32_t pudu_ui_event_detail(void) { return pudu_event_detail_word; }

#endif
