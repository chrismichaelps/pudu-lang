/* Drives a platform WebView adapter through its six entry points: a page
   posts to the pudu scheme, the harness answers, an injected script and the
   answer are read back by evaluation, and a navigation outside the allowlist
   is refused. Runs on whichever adapter it is linked with. */
#include "pudu_webview.h"
#include "pudu_webview_records.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *PAGE =
    "<html><body><script>"
    "fetch('pudu://app/.pudu/ipc/echo',{method:'POST',body:'ping'})"
    ".then(function(r){return r.text()})"
    ".then(function(t){document.title='done:'+t})"
    ".catch(function(e){document.title='error:'+e})"
    "</script></body></html>";

static int send_all(pudu_buffer *buffer) {
  int32_t status = pudu_webview_send(buffer->data, buffer->length);
  buffer->length = 0;
  if (status != PUDU_WEBVIEW_DONE) {
    uint8_t reason[512] = {0};
    pudu_webview_failure(reason, sizeof reason - 1);
    fprintf(stderr, "send refused (%d): %s\n", status, reason);
  }
  return status;
}

static void record(pudu_buffer *buffer, const char *const *fields, int count) {
  for (int i = 0; i < count; i++) {
    pudu_buffer_text(buffer, fields[i]);
  }
  pudu_buffer_end(buffer);
}

int main(void) {
  pudu_buffer commands = {0};
  const char *open[] = {"window", "1", "open", "Harness", "480", "320", "1"};
  const char *create[] = {"view", "1", "create", "1", "0", "0", "0", "0", "1"};
  const char *inject[] = {"view", "1", "script", "window.injected = 42;", "start", "main"};
  const char *html[] = {"view", "1", "html", PAGE};
  const char *realize[] = {"view", "1", "realize"};
  const char *show[] = {"window", "1", "show"};
  record(&commands, open, 7);
  record(&commands, create, 9);
  record(&commands, inject, 6);
  record(&commands, html, 4);
  record(&commands, realize, 3);
  record(&commands, show, 3);
  if (send_all(&commands) != PUDU_WEBVIEW_DONE) {
    return 1;
  }

  int answered = 0, evaluated = 0, blocked = 0;
  for (int turn = 0; turn < 400 && !blocked; turn++) {
    if (pudu_webview_pump(50) < 0) {
      fprintf(stderr, "pump failed\n");
      return 1;
    }
    int64_t size = pudu_webview_events(NULL, 0);
    if (size <= 0) {
      continue;
    }
    uint8_t *events = malloc((size_t)size);
    if (pudu_webview_events(events, (size_t)size) != size) {
      free(events);
      continue;
    }
    size_t cursor = 0;
    pudu_field fields[PUDU_RECORD_FIELDS];
    int count;
    while ((count = pudu_record_next(events, (size_t)size, &cursor, fields, PUDU_RECORD_FIELDS)) > 0) {
      if (pudu_field_is(fields[0], "request") && count == 8) {
        int64_t id = 0;
        pudu_field_int(fields[2], &id);
        uint8_t body[16] = {0};
        int64_t length = pudu_webview_body(id, body, sizeof body);
        const char *answer = length == 4 && memcmp(body, "ping", 4) == 0 ? "pong" : "wrong-body";
        const char *head = "Content-Type: text/plain";
        if (pudu_webview_respond(id, 200, (const uint8_t *)head, strlen(head), (const uint8_t *)answer, strlen(answer)) == 0) {
          answered = 1;
        }
      } else if (pudu_field_is(fields[0], "title") && count == 3 && fields[2].length > 5 &&
                 memcmp(fields[2].data, "done:", 5) == 0) {
        const char *eval[] = {"view", "1", "eval", "t1", "document.title + ':' + window.injected"};
        record(&commands, eval, 5);
        send_all(&commands);
      } else if (pudu_field_is(fields[0], "eval") && count == 5) {
        if (pudu_field_is(fields[3], "ok") && pudu_field_is(fields[4], "done:pong:42")) {
          evaluated = 1;
          const char *away[] = {"view", "1", "navigate", "https://example.invalid/"};
          record(&commands, away, 4);
          send_all(&commands);
        } else {
          fprintf(stderr, "unexpected evaluation: %.*s\n", (int)fields[4].length, (const char *)fields[4].data);
          return 1;
        }
      } else if (pudu_field_is(fields[0], "navigation-blocked") && count == 3) {
        blocked = 1;
      }
    }
    free(events);
  }
  const char *close[] = {"window", "1", "close"};
  record(&commands, close, 3);
  send_all(&commands);
  pudu_buffer_clear(&commands);
  printf("answered=%d evaluated=%d blocked=%d\n", answered, evaluated, blocked);
  return answered && evaluated && blocked ? 0 : 1;
}
