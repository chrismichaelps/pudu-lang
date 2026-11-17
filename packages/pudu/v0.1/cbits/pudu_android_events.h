#ifndef PUDU_ANDROID_EVENTS_H
#define PUDU_ANDROID_EVENTS_H

/* The host's event queue. Listeners on the main thread queue events; the
   program thread takes them one at a time in pudu_ui_wait, then asks for the
   text, detail and words of the event it was handed. The kinds match
   Std.Mobile.Decode, as the iOS host's do. */
#include <jni.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "pudu_android_jni.h"

enum { PUDU_UI_TAPPED = 1, PUDU_UI_STOPPED = 2, PUDU_UI_CHANGED = 3, PUDU_UI_SWITCHED_ON = 4, PUDU_UI_SWITCHED_OFF = 5,
       PUDU_UI_REACHED = 8, PUDU_UI_GESTURED = 9, PUDU_UI_CHOSE = 10, PUDU_UI_RESIZED = 11, PUDU_UI_LIFECYCLE = 12,
       PUDU_UI_PICKED = 13, PUDU_UI_VALUED = 14, PUDU_UI_COLORED = 15, PUDU_UI_DATED = 16 };

/* At most this many words travel with one event. */
enum { PUDU_EVENT_WORDS = 4 };

typedef struct pudu_event {
  uint64_t raw;
  char *text;
  uint32_t detail;
  uint32_t words[PUDU_EVENT_WORDS];
  uint32_t word_total;
  struct pudu_event *next;
} pudu_event;

static pthread_mutex_t pudu_events_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t pudu_events_ready = PTHREAD_COND_INITIALIZER;
static pudu_event *pudu_events_first, *pudu_events_last;
/* The event last handed to the program; its fields stay valid until the next wait. */
static pudu_event *pudu_event_current;

/* Queues an event; `text` is copied. Callable from any thread. */
static void pudu_queue_words(uint64_t kind, uint32_t tag, const char *text, uint32_t detail, const int32_t *words, uint32_t count) {
  pudu_event *event = calloc(1, sizeof *event);
  if (event == NULL) abort();
  event->raw = (kind << 32) | tag;
  event->text = strdup(text != NULL ? text : "");
  if (event->text == NULL) abort();
  event->detail = detail;
  event->word_total = count < PUDU_EVENT_WORDS ? count : PUDU_EVENT_WORDS;
  for (uint32_t i = 0; i < event->word_total; i++) event->words[i] = (uint32_t)words[i];
  pthread_mutex_lock(&pudu_events_lock);
  if (pudu_events_last == NULL) pudu_events_first = event;
  else pudu_events_last->next = event;
  pudu_events_last = event;
  pthread_cond_signal(&pudu_events_ready);
  pthread_mutex_unlock(&pudu_events_lock);
}

static void pudu_queue(uint64_t kind, uint32_t tag, const char *text, uint32_t detail) {
  pudu_queue_words(kind, tag, text, detail, NULL, 0);
}

/* The next event; the program thread sleeps until one is queued. */
uint64_t pudu_ui_wait(void) {
  pudu_event *next;
  pthread_mutex_lock(&pudu_events_lock);
  while (pudu_events_first == NULL) pthread_cond_wait(&pudu_events_ready, &pudu_events_lock);
  next = pudu_events_first;
  pudu_events_first = next->next;
  if (pudu_events_first == NULL) pudu_events_last = NULL;
  pthread_mutex_unlock(&pudu_events_lock);
  if (pudu_event_current != NULL) {
    free(pudu_event_current->text);
    free(pudu_event_current);
  }
  pudu_event_current = next;
  return next->raw;
}

/* The text the last event carried; valid until the next wait. */
const char *pudu_ui_event_text(void) { return pudu_event_current != NULL ? pudu_event_current->text : ""; }

/* The detail word the last event carried; valid until the next wait. */
uint32_t pudu_ui_event_detail(void) { return pudu_event_current != NULL ? pudu_event_current->detail : 0; }

/* How many words the last event carried, and each as the bits of a signed
   value; an index past the end reads zero. */
uint32_t pudu_ui_event_word_count(void) { return pudu_event_current != NULL ? pudu_event_current->word_total : 0; }
uint32_t pudu_ui_event_word(uint32_t index) {
  return pudu_event_current != NULL && index < pudu_event_current->word_total ? pudu_event_current->words[index] : 0;
}

/* PuduBridge.event: a listener's report, with the kind and tag already
   chosen by the Java side that the host configured. */
JNIEXPORT void JNICALL Java_org_pudu_PuduBridge_event(JNIEnv *env, jclass type, jint kind, jint tag, jstring text,
                                                      jint detail, jintArray words) {
  char *bytes = pudu_utf8(env, text);
  jint held[PUDU_EVENT_WORDS] = {0};
  jsize count = words != NULL ? (*env)->GetArrayLength(env, words) : 0;
  (void)type;
  if (count > PUDU_EVENT_WORDS) count = PUDU_EVENT_WORDS;
  if (count > 0) (*env)->GetIntArrayRegion(env, words, 0, count, held);
  pudu_queue_words((uint64_t)(uint32_t)kind, (uint32_t)tag, bytes, (uint32_t)detail, held, (uint32_t)count);
  free(bytes);
}

#endif
