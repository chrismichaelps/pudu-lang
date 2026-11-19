#ifndef PUDU_IOS_EVENTS_H
#define PUDU_IOS_EVENTS_H

/* The host's event queue. Controls queue events while the main loop runs
   inside a wait; Pudu takes them one at a time, then asks for the text,
   detail and words of the event it was handed. */
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Event kinds in the high word of an event; they match Std.Mobile.View. */
static const uint64_t PUDU_UI_TAPPED = 1, PUDU_UI_STOPPED = 2, PUDU_UI_CHANGED = 3, PUDU_UI_SWITCHED_ON = 4,
                      PUDU_UI_SWITCHED_OFF = 5, PUDU_UI_REACHED = 8, PUDU_UI_GESTURED = 9, PUDU_UI_CHOSE = 10,
                      PUDU_UI_RESIZED = 11, PUDU_UI_LIFECYCLE = 12, PUDU_UI_PICKED = 13, PUDU_UI_POPPED = 14,
                      PUDU_UI_DISMISSED = 15, PUDU_UI_REFRESHED = 16, PUDU_UI_INSETS = 17,
                      PUDU_UI_FETCHED = 18, PUDU_UI_WOKE = 19, PUDU_UI_MEMORY = 20, PUDU_UI_VALUED = 21,
                      PUDU_UI_COLORED = 22, PUDU_UI_DATED = 23, PUDU_UI_IMAGED = 24,
                      PUDU_UI_OPENED = 25, PUDU_UI_SHARED = 26, PUDU_UI_PASTED = 27,
                      PUDU_UI_PERMISSIONED = 28, PUDU_UI_SELECTED = 29;

/* Run at the start of each wait, once the program has handled the event it
   was last handed; NULL until a capability needs it. */
static void (*pudu_before_wait)(void);

/* At most this many words travel with one event. */
enum { PUDU_EVENT_WORDS = 4 };

/* Each queued event is its 64-bit value, its text, its detail word and its
   words. */
static NSMutableArray<NSArray *> *pudu_events;
static char *pudu_event_text_bytes;
static uint32_t pudu_event_detail_word;
static uint32_t pudu_event_words[PUDU_EVENT_WORDS];
static uint32_t pudu_event_word_total;

static void pudu_queue_words(uint64_t kind, NSInteger tag, NSString *text, uint32_t detail, NSArray<NSNumber *> *words) {
  if (pudu_events == nil) pudu_events = [NSMutableArray new];
  [pudu_events addObject:@[ @((kind << 32) | (uint32_t)tag), text ?: @"", @(detail), words ?: @[] ]];
}

static void pudu_queue(uint64_t kind, NSInteger tag, NSString *text, uint32_t detail) {
  pudu_queue_words(kind, tag, text, detail, nil);
}

/* Drops queued events of `kind` the program has not read. */
static void pudu_unqueue(uint64_t kind) {
  NSIndexSet *stale = [pudu_events indexesOfObjectsPassingTest:^BOOL(NSArray *queued, NSUInteger index, BOOL *stop) {
    (void)index;
    (void)stop;
    return ([queued[0] unsignedLongLongValue] >> 32) == kind;
  }];
  [pudu_events removeObjectsAtIndexes:stale];
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
  NSArray<NSNumber *> *words;
  if (pudu_events == nil) pudu_events = [NSMutableArray new];
  if (pudu_before_wait != NULL) pudu_before_wait();
  while (pudu_events.count == 0) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, true);
  next = pudu_events.firstObject;
  [pudu_events removeObjectAtIndex:0];
  free(pudu_event_text_bytes);
  pudu_event_text_bytes = strdup([next[1] UTF8String]);
  if (pudu_event_text_bytes == NULL) abort();
  pudu_event_detail_word = [next[2] unsignedIntValue];
  words = next[3];
  pudu_event_word_total = (uint32_t)MIN(words.count, (NSUInteger)PUDU_EVENT_WORDS);
  for (uint32_t i = 0; i < pudu_event_word_total; i++) pudu_event_words[i] = (uint32_t)words[i].intValue;
  return [next[0] unsignedLongLongValue];
}

/* The text the last event carried; valid until the next wait. */
const char *pudu_ui_event_text(void) { return pudu_event_text_bytes != NULL ? pudu_event_text_bytes : ""; }

/* The detail word the last event carried; valid until the next wait. */
uint32_t pudu_ui_event_detail(void) { return pudu_event_detail_word; }

/* How many words the last event carried, and each of them as the bits of a
   signed value; an index past the end reads zero. */
uint32_t pudu_ui_event_word_count(void) { return pudu_event_word_total; }
uint32_t pudu_ui_event_word(uint32_t index) { return index < pudu_event_word_total ? pudu_event_words[index] : 0; }

#endif
