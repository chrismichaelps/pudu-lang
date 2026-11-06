/* Drives a platform WebView adapter through its six entry points: a page
   posts to the pudu scheme, the harness answers, an injected script and the
   answer are read back by evaluation, and a navigation outside the allowlist
   is refused; a content rule blocks a request before it reaches the program,
   and the page loads only after the rule list compiled. Runs on whichever
   adapter it is linked with. */
#include "pudu_webview.h"
#include "pudu_webview_records.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *PAGE =
    "<html><body><script>"
    "fetch('pudu://app/blocked').then(function(r){return r.ok?'leaked':'blocked'},function(){return 'blocked'})"
    ".then(function(b){return fetch('pudu://app/.pudu/ipc/echo',{method:'POST',body:'ping:'+b})})"
    ".then(function(r){return r.text()})"
    ".then(function(t){document.title='done:'+t})"
    ".catch(function(e){document.title='error:'+e})"
    ";window.__probe='script ran'"
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
  const char *rules[] = {"view", "1", "rules", "[{\"trigger\":{\"url-filter\":\"blocked\"},\"action\":{\"type\":\"block\"}}]"};
  const char *html[] = {"view", "1", "html", PAGE};
  const char *realize[] = {"view", "1", "realize"};
  const char *second[] = {"view", "2", "create", "1", "0", "0", "200", "100", "0"};
  const char *secondHtml[] = {"view", "2", "html", "<html><head><title>second</title></head></html>"};
  const char *secondRealize[] = {"view", "2", "realize"};
  const char *show[] = {"window", "1", "show"};
  record(&commands, open, 7);
  record(&commands, create, 9);
  record(&commands, inject, 6);
  record(&commands, rules, 4);
  record(&commands, html, 4);
  record(&commands, realize, 3);
  record(&commands, second, 9);
  record(&commands, secondHtml, 4);
  record(&commands, secondRealize, 3);
  record(&commands, show, 3);
  if (send_all(&commands) != PUDU_WEBVIEW_DONE) {
    return 1;
  }

  int answered = 0, evaluated = 0, blocked = 0, sibling = 0;
  int trace = getenv("PUDU_HARNESS_TRACE") != NULL;
  for (int turn = 0; turn < 400 && !(blocked && sibling); turn++) {
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
      if (trace) {
        for (int i = 0; i < count; i++) {
          fprintf(stderr, "%s%.*s", i == 0 ? "event: " : " | ", (int)fields[i].length, (const char *)fields[i].data);
        }
        fprintf(stderr, "\n");
      }
      if (pudu_field_is(fields[0], "request") && count == 8) {
        int64_t id = 0;
        pudu_field_int(fields[2], &id);
        uint8_t body[32] = {0};
        int64_t length = pudu_webview_body(id, body, sizeof body);
        if (fields[4].length >= 7 && memcmp(fields[4].data + fields[4].length - 7, "blocked", 7) == 0) {
          fprintf(stderr, "a blocked request reached the program\n");
          return 1;
        }
        const char *answer = length == 12 && memcmp(body, "ping:blocked", 12) == 0 ? "pong" : "wrong-body";
        const char *head = "Content-Type: text/plain";
        if (pudu_webview_respond(id, 200, (const uint8_t *)head, strlen(head), (const uint8_t *)answer, strlen(answer)) == 0) {
          answered = 1;
        }
      } else if (pudu_field_is(fields[0], "title") && count == 3 && pudu_field_is(fields[1], "2") &&
                 pudu_field_is(fields[2], "second")) {
        sibling = 1;
      } else if (pudu_field_is(fields[0], "title") && count == 3 && fields[2].length > 5 &&
                 memcmp(fields[2].data, "done:", 5) == 0) {
        const char *eval[] = {"view", "1", "eval", "t1", "document.title + ':' + window.injected"};
        record(&commands, eval, 5);
        send_all(&commands);
      } else if (pudu_field_is(fields[0], "eval") && count == 5 && pudu_field_is(fields[2], "probe")) {
        continue;
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
    if (trace && answered && !evaluated && turn % 40 == 0) {
      const char *probe[] = {"view", "1", "eval", "probe", "document.title + ' / ' + (window.__probe || 'no probe')"};
      record(&commands, probe, 5);
      send_all(&commands);
    }
  }
#ifdef __APPLE__
  /* Native components beside the views: a menu bar, and a surface that takes
     a frame of its exact size and refuses any other. */
  const char *menu[] = {"app", "menu", "menu\t0\tFile\nitem\t1\topen\tcmd+o\tOpen\nseparator\t1"};
  record(&commands, menu, 3);
  int native = send_all(&commands) == PUDU_WEBVIEW_DONE;
  const char *surface[] = {"surface", "3", "create", "1", "10", "10", "2", "1"};
  const char *frame[] = {"surface", "3", "present", "2", "1", "/wAA/wD/AP8="};
  record(&commands, surface, 8);
  record(&commands, frame, 6);
  native = native && send_all(&commands) == PUDU_WEBVIEW_DONE;
  const char *wrong[] = {"surface", "3", "present", "3", "1", "/wAA/wD/AP8="};
  record(&commands, wrong, 6);
  native = native && pudu_webview_send(commands.data, commands.length) == PUDU_WEBVIEW_MALFORMED;
  commands.length = 0;
  const char *gone[] = {"surface", "3", "close"};
  record(&commands, gone, 3);
  native = native && send_all(&commands) == PUDU_WEBVIEW_DONE;
  printf("native=%d\n", native);
  if (!native) {
    return 1;
  }
#endif
  const char *close[] = {"window", "1", "close"};
  record(&commands, close, 3);
  send_all(&commands);
  pudu_buffer_clear(&commands);
  printf("answered=%d evaluated=%d blocked=%d sibling=%d\n", answered, evaluated, blocked, sibling);
  return answered && evaluated && blocked && sibling ? 0 : 1;
}
