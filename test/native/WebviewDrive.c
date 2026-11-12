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

#if defined(__APPLE__) || defined(__linux__) || defined(_WIN32)
#ifdef _WIN32
#include <windows.h>
static int64_t monotonic_us(void) { return (int64_t)GetTickCount64() * 1000; }
#else
#include <time.h>

/* Microseconds on a clock that never steps backward, for deadlines. */
static int64_t monotonic_us(void) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (int64_t)now.tv_sec * 1000000 + now.tv_nsec / 1000;
}

#endif

static int evaluate_title(pudu_buffer *commands, const char *view, const char *script, const char *title) {
  const char *evaluate[] = {"view", view, "eval", "authority", script};
  record(commands, evaluate, 5);
  if (send_all(commands) != PUDU_WEBVIEW_DONE) return 0;
  char last_title[128] = "no title event";
  for (int64_t expires = monotonic_us() + 10000000; monotonic_us() < expires;) {
    if (pudu_webview_pump(50) < 0) return 0;
    int64_t size = pudu_webview_events(NULL, 0);
    if (size <= 0) continue;
    uint8_t *events = malloc((size_t)size);
    if (pudu_webview_events(events, (size_t)size) != size) { free(events); continue; }
    size_t at = 0;
    pudu_field fields[PUDU_RECORD_FIELDS];
    int count, matched = 0;
    while ((count = pudu_record_next(events, (size_t)size, &at, fields, PUDU_RECORD_FIELDS)) > 0) {
      if (count == 8 && pudu_field_is(fields[0], "request") && pudu_field_is(fields[4], "pudu://app/shared-route")) {
        int64_t request = 0;
        pudu_field_int(fields[2], &request);
        const char *headers = "Content-Type: text/plain\n";
        pudu_webview_respond(request, 200, (const uint8_t *)headers, strlen(headers), fields[1].data, fields[1].length);
      }
      if (count == 3 && pudu_field_is(fields[0], "title") && pudu_field_is(fields[1], view)) {
        snprintf(last_title, sizeof last_title, "%.*s", (int)fields[2].length, (const char *)fields[2].data);
        if (pudu_field_is(fields[2], title)) matched = 1;
      }
      if (count == 5 && pudu_field_is(fields[0], "eval") && pudu_field_is(fields[1], view) && pudu_field_is(fields[3], "error")) {
        fprintf(stderr, "native evaluation failed: %.*s\n", (int)fields[4].length, (const char *)fields[4].data);
        free(events);
        return 0;
      }
    }
    free(events);
    if (matched) return 1;
  }
  fprintf(stderr, "native page probe did not report %s: %s\n", title, last_title);
  return 0;
}

#endif

#ifdef __linux__
#include <pthread.h>
#include "pudu_webview_gtk.h"

static void *wrong_thread(void *data) {
  int *result = data;
  *result = pudu_webview_send(NULL, 0) == PUDU_WEBVIEW_NOT_MAIN &&
    pudu_webview_respond(0, 200, NULL, 0, NULL, 0) == PUDU_WEBVIEW_NOT_MAIN;
  return NULL;
}

static int authority_probe(pudu_buffer *commands, const char *view, const char *key, const char *origin, int allowed) {
  static int serial;
  char script[1024], title[80];
  snprintf(title, sizeof title, "authority-%d:%s", ++serial, allowed ? "true" : "false");
  snprintf(script, sizeof script,
    "window.webkit.messageHandlers.puduWindowAuthorized.postMessage("
    "'{\"action\":\"toggle-maximize\",\"key\":\"%s\",\"origin\":\"%s\"}')"
    ".then(value=>document.title='authority-%d:'+String(value));void 0", key, origin, serial);
  return evaluate_title(commands, view, script, title);
}

static int shared_stores(pudu_buffer *commands) {
  const char *first[] = {"view", "3", "create", "1", "0", "0", "100", "100", "0"};
  const char *second[] = {"view", "4", "create", "1", "100", "0", "100", "100", "0"};
  const char *store3[] = {"view", "3", "data-store", "pudu-harness-shared"};
  const char *store4[] = {"view", "4", "data-store", "pudu-harness-shared"};
  const char *page3[] = {"view", "3", "html", "<html><head><title>shared-a</title></head><body>A</body></html>"};
  const char *page4[] = {"view", "4", "html", "<html><head><title>shared-b</title></head><body>B</body></html>"};
  const char *realize3[] = {"view", "3", "realize"}, *realize4[] = {"view", "4", "realize"};
  record(commands, first, 9); record(commands, second, 9);
  record(commands, store3, 4); record(commands, store4, 4);
  record(commands, page3, 4); record(commands, page4, 4);
  record(commands, realize3, 3); record(commands, realize4, 3);
  if (send_all(commands) != PUDU_WEBVIEW_DONE) return 0;
  int first_ready = 0, second_ready = 0;
  for (gint64 expires = g_get_monotonic_time() + 10 * G_USEC_PER_SEC; g_get_monotonic_time() < expires && !(first_ready && second_ready);) {
    if (pudu_webview_pump(50) < 0) return 0;
    int64_t size = pudu_webview_events(NULL, 0);
    if (size <= 0) continue;
    uint8_t *events = malloc((size_t)size);
    if (pudu_webview_events(events, (size_t)size) != size) { free(events); continue; }
    size_t at = 0;
    pudu_field fields[PUDU_RECORD_FIELDS];
    int count;
    while ((count = pudu_record_next(events, (size_t)size, &at, fields, PUDU_RECORD_FIELDS)) > 0) {
      if (count != 3 || !pudu_field_is(fields[0], "title")) continue;
      if (pudu_field_is(fields[1], "3") && pudu_field_is(fields[2], "shared-a")) first_ready = 1;
      if (pudu_field_is(fields[1], "4") && pudu_field_is(fields[2], "shared-b")) second_ready = 1;
    }
    free(events);
  }
  if (!(first_ready && second_ready)) return 0;
  char write[256], read[384], expected[64];
  long long nonce = (long long)g_get_monotonic_time();
  snprintf(write, sizeof write, "localStorage.setItem('pudu-harness-shared','%lld');document.title='shared-written';void 0", nonce);
  snprintf(read, sizeof read, "(function poll(){var v=localStorage.getItem('pudu-harness-shared');if(v==='%lld'){document.title='shared-read:'+v}else{document.title='shared-pending:'+v;setTimeout(poll,10)}})();void 0", nonce);
  snprintf(expected, sizeof expected, "shared-read:%lld", nonce);
  if (!evaluate_title(commands, "3", write, "shared-written") || !evaluate_title(commands, "4", read, expected) ||
      !evaluate_title(commands, "4", "fetch('pudu://app/shared-route').then(r=>r.text()).then(id=>document.title='shared-route:'+id);void 0", "shared-route:4")) return 0;
  int64_t old_id = 3;
  PuduView *old = g_hash_table_lookup(pudu_views, &old_id);
  WebKitWebContext *context = g_object_ref(webkit_web_view_get_context(WEBKIT_WEB_VIEW(old->web)));
  const char *clear[] = {"view", "3", "clear-data"}, *close3[] = {"view", "3", "close"}, *close4[] = {"view", "4", "close"};
  const char *reopen[] = {"view", "5", "create", "1", "0", "0", "100", "100", "0"};
  const char *store5[] = {"view", "5", "data-store", "pudu-harness-shared"};
  const char *page5[] = {"view", "5", "html", "<html><head><title>reopened</title></head><body>C</body></html>"};
  const char *realize5[] = {"view", "5", "realize"};
  record(commands, clear, 3); record(commands, close3, 3); record(commands, close4, 3);
  record(commands, reopen, 9); record(commands, store5, 4); record(commands, page5, 4); record(commands, realize5, 3);
  if (send_all(commands) != PUDU_WEBVIEW_DONE) { g_object_unref(context); return 0; }
  int64_t new_id = 5;
  PuduView *fresh = g_hash_table_lookup(pudu_views, &new_id);
  int shared = webkit_web_view_get_context(WEBKIT_WEB_VIEW(fresh->web)) == context;
  g_object_unref(context);
  if (!shared) { fprintf(stderr, "named store was replaced during pending clear\n"); return 0; }
  int cleared = 0, reopened = 0;
  for (gint64 expires = g_get_monotonic_time() + 10 * G_USEC_PER_SEC; g_get_monotonic_time() < expires && !(cleared && reopened);) {
    if (pudu_webview_pump(50) < 0) return 0;
    int64_t size = pudu_webview_events(NULL, 0);
    if (size <= 0) continue;
    uint8_t *events = malloc((size_t)size);
    if (pudu_webview_events(events, (size_t)size) != size) { free(events); continue; }
    size_t at = 0;
    pudu_field fields[PUDU_RECORD_FIELDS];
    int count;
    while ((count = pudu_record_next(events, (size_t)size, &at, fields, PUDU_RECORD_FIELDS)) > 0) {
      if (count == 2 && pudu_field_is(fields[0], "data-cleared") && pudu_field_is(fields[1], "3")) cleared = 1;
      if (count == 3 && pudu_field_is(fields[0], "title") && pudu_field_is(fields[1], "5") && pudu_field_is(fields[2], "reopened")) reopened = 1;
    }
    free(events);
  }
  return cleared && reopened;

}

static int content_size(pudu_buffer *commands, const char *width, const char *height) {
  int64_t last_width = 0, last_height = 0;
  const char *resize[] = {"window", "1", "size", width, height};
  record(commands, resize, 5);
  if (send_all(commands) != PUDU_WEBVIEW_DONE) return 0;
  for (gint64 expires = g_get_monotonic_time() + 10 * G_USEC_PER_SEC; g_get_monotonic_time() < expires;) {
    if (pudu_webview_pump(20) < 0) return 0;
    const char *state[] = {"window", "1", "state"};
    record(commands, state, 3);
    if (send_all(commands) != PUDU_WEBVIEW_DONE) return 0;
    int64_t size = pudu_webview_events(NULL, 0);
    if (size <= 0) continue;
    uint8_t *events = malloc((size_t)size);
    if (pudu_webview_events(events, (size_t)size) != size) { free(events); continue; }
    size_t at = 0;
    pudu_field fields[PUDU_RECORD_FIELDS];
    int count, matched = 0;
    while ((count = pudu_record_next(events, (size_t)size, &at, fields, PUDU_RECORD_FIELDS)) > 0) {
      if (count == 4 && pudu_field_is(fields[0], "resized") && pudu_field_is(fields[1], "1")) {
        pudu_field_int(fields[2], &last_width);
        pudu_field_int(fields[3], &last_height);
        if (pudu_field_is(fields[2], width) && pudu_field_is(fields[3], height)) matched = 1;
      }
    }
    free(events);
    if (matched) return 1;
  }
  fprintf(stderr, "content did not reach %sx%s: observed %lldx%lld\n", width, height, (long long)last_width, (long long)last_height);
  return 0;
}

static int titlebar_styles(pudu_buffer *commands) {
  const char *transparent[] = {"window", "1", "titlebar", "transparent"};
  const char *overlay[] = {"window", "1", "titlebar", "overlay"};
  const char *visible[] = {"window", "1", "titlebar", "visible"};
  record(commands, transparent, 4); record(commands, overlay, 4);
  if (send_all(commands) != PUDU_WEBVIEW_DONE || !content_size(commands, "800", "600")) return 0;
  int64_t id = 1;
  PuduWindow *owner = pudu_window_named(id);
  PuduView *view = g_hash_table_lookup(pudu_views, &id);
  int aligned = 0;
  for (gint64 expires = g_get_monotonic_time() + 10 * G_USEC_PER_SEC; g_get_monotonic_time() < expires && !aligned;) {
    int mx, my, hx, hy, vx, vy;
    aligned = gtk_widget_translate_coordinates(owner->menubar, owner->window, 0, 0, &mx, &my) &&
      gtk_widget_translate_coordinates(owner->overlaybar, owner->window, 0, 0, &hx, &hy) &&
      gtk_widget_translate_coordinates(view->web, owner->window, 0, 0, &vx, &vy) &&
      hy == vy && my + gtk_widget_get_allocated_height(owner->menubar) <= hy;
    if (aligned) break;
    pudu_webview_pump(20);
    int64_t size = pudu_webview_events(NULL, 0);
    if (size > 0) { uint8_t *events = malloc((size_t)size); pudu_webview_events(events, (size_t)size); free(events); }
  }
  if (!aligned) { fprintf(stderr, "overlay controls overlap the native menu\n"); return 0; }
  record(commands, visible, 4);
  return send_all(commands) == PUDU_WEBVIEW_DONE && content_size(commands, "640", "480");
}

static int wait_maximized(pudu_buffer *commands, int wanted) {
  for (gint64 expires = g_get_monotonic_time() + 10 * G_USEC_PER_SEC; g_get_monotonic_time() < expires;) {
    if (pudu_webview_pump(20) < 0) return 0;
    const char *state[] = {"window", "1", "state"};
    record(commands, state, 3);
    if (send_all(commands) != PUDU_WEBVIEW_DONE) return 0;
    int64_t size = pudu_webview_events(NULL, 0);
    if (size <= 0) continue;
    uint8_t *events = malloc((size_t)size);
    if (pudu_webview_events(events, (size_t)size) != size) { free(events); continue; }
    size_t at = 0;
    pudu_field fields[PUDU_RECORD_FIELDS];
    int count, matched = 0;
    while ((count = pudu_record_next(events, (size_t)size, &at, fields, PUDU_RECORD_FIELDS)) > 0)
      if (count == 7 && pudu_field_is(fields[0], "window-state") && pudu_field_is(fields[1], "1") &&
          pudu_field_is(fields[3], wanted ? "1" : "0")) matched = 1;
    free(events);
    if (matched) return 1;
  }
  fprintf(stderr, "window did not reach maximized=%d\n", wanted);
  return 0;
}
#endif

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
  const char *inspectable[] = {"view", "2", "devtools", "1"};
  record(&commands, inspectable, 4);
  record(&commands, secondHtml, 4);
#ifdef __linux__
  const char *authority_config[] = {"view", "2", "window-authority", "toggle-maximize", "pudu://app", "0123456789abcdef0123456789abcdef"};
  record(&commands, authority_config, 6);
#endif
  record(&commands, secondRealize, 3);
  record(&commands, show, 3);
  if (send_all(&commands) != PUDU_WEBVIEW_DONE) {
    return 1;
  }

  if (pudu_webview_respond(0, 200, NULL, 1, NULL, 0) != PUDU_WEBVIEW_INVALID ||
      pudu_webview_respond(0, 200, NULL, 0, NULL, 1) != PUDU_WEBVIEW_INVALID ||
      pudu_webview_respond(0, 99, NULL, 0, NULL, 0) != PUDU_WEBVIEW_INVALID) return 1;
  printf("response-slices=1\n");
  int answered = 0, evaluated = 0, blocked = 0, sibling = 0;
  int trace = getenv("PUDU_HARNESS_TRACE") != NULL;
  for (int turn = 0; turn < 400 && !(blocked && sibling); turn++) {
    if (pudu_webview_pump(50) < 0) {
      fprintf(stderr, "pump failed\n");
      return 1;
    }
    if (trace && answered && !evaluated && turn % 40 == 0) {
      const char *probe[] = {"view", "1", "eval", "probe", "document.title + ' / ' + (window.__probe || 'no probe')"};
      record(&commands, probe, 5);
      send_all(&commands);
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
        if (pudu_webview_respond(id, 200, NULL, 0, (const uint8_t *)answer, strlen(answer)) == 0) {
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
  }
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
#if defined(__APPLE__) || defined(__linux__)
  const char *top[] = {"window", "1", "always-on-top", "1"};
  const char *state[] = {"window", "1", "state"};
  record(&commands, top, 4);
  record(&commands, state, 3);
  if (send_all(&commands) != PUDU_WEBVIEW_DONE) return 1;
  int64_t state_size = pudu_webview_events(NULL, 0);
  uint8_t *state_events = malloc((size_t)state_size);
  if (state_size <= 0 || pudu_webview_events(state_events, (size_t)state_size) != state_size) return 1;
  size_t at = 0;
  int state_seen = 0;
  pudu_field state_fields[PUDU_RECORD_FIELDS];
  int state_count = 0;
  while ((state_count = pudu_record_next(state_events, (size_t)state_size, &at, state_fields, PUDU_RECORD_FIELDS)) > 0) {
    if (state_count == 7 && pudu_field_is(state_fields[0], "window-state")) state_seen = 1;
  }
  free(state_events);
  if (!state_seen) return 1;
  const char *bad_flag[] = {"window", "1", "always-on-top", "yes"};
  const char *bad_style[] = {"window", "1", "titlebar", "unknown"};
  const char *bad_color[] = {"window", "1", "background", "256", "0", "0", "255"};
  const char *inspector[] = {"view", "1", "devtools-toggle"};
  const char *const *invalid[] = {bad_flag, bad_style, bad_color, inspector};
  const int lengths[] = {4, 4, 7, 3};
  for (int i = 0; i < 4; i++) {
    record(&commands, invalid[i], lengths[i]);
    int32_t status = pudu_webview_send(commands.data, commands.length);
    commands.length = 0;
    if (status != (i == 3 ? PUDU_WEBVIEW_UNSUPPORTED : PUDU_WEBVIEW_MALFORMED)) return 1;
  }
  const char *toggle[] = {"view", "2", "devtools-toggle"};
  record(&commands, toggle, 3);
  int32_t inspector_status = pudu_webview_send(commands.data, commands.length);
  commands.length = 0;
  if (inspector_status == PUDU_WEBVIEW_DONE) {
    record(&commands, toggle, 3);
    if (send_all(&commands) != PUDU_WEBVIEW_DONE) return 1;
    printf("inspector-toggle=1\n");
  } else if (inspector_status == PUDU_WEBVIEW_UNSUPPORTED) {
    printf("inspector-toggle=unsupported\n");
  } else return 1;
  printf("window-controls=1\n");
#endif
#if defined(__APPLE__) || defined(_WIN32)
  int isolated = evaluate_title(&commands, "1", "localStorage.setItem('pudu-harness-private','private');document.title='private-written';void 0", "private-written") &&
    evaluate_title(&commands, "2", "document.title='private-isolated:'+(localStorage.getItem('pudu-harness-private')===null);void 0", "private-isolated:true");
  printf("private-isolation=%d\n", isolated);
  if (!isolated) return 1;
#endif
#ifdef __linux__
  pthread_t worker;
  int thread_guard = 0;
  if (pthread_create(&worker, NULL, wrong_thread, &thread_guard) != 0 || pthread_join(worker, NULL) != 0 || !thread_guard) return 1;
  printf("thread-guard=1\n");
  int isolation = evaluate_title(&commands, "1", "localStorage.setItem('pudu-harness-private','private');document.title='private-written';void 0", "private-written") &&
    evaluate_title(&commands, "2", "document.title='private-isolated:'+(localStorage.getItem('pudu-harness-private')===null);void 0", "private-isolated:true") &&
    shared_stores(&commands);
  printf("storage-isolation=%d\n", isolation);
  if (!isolation) return 1;
  const char *bridge_key = "0123456789abcdef0123456789abcdef";
  if (!content_size(&commands, "800", "600") || !content_size(&commands, "640", "480") || !titlebar_styles(&commands)) return 1;
  int authority = authority_probe(&commands, "1", bridge_key, "pudu://app", 0) &&
    authority_probe(&commands, "2", "ffffffffffffffffffffffffffffffff", "pudu://app", 0) &&
    authority_probe(&commands, "2", bridge_key, "https://other.example", 0) &&
    wait_maximized(&commands, 0) &&
    authority_probe(&commands, "2", bridge_key, "pudu://app", 1) && wait_maximized(&commands, 1) &&
    authority_probe(&commands, "2", bridge_key, "pudu://app", 1) && wait_maximized(&commands, 0);
  printf("native-authority=%d\n", authority);
  if (!authority) return 1;
#endif
  const char *close[] = {"window", "1", "close"};
  record(&commands, close, 3);
  send_all(&commands);
  pudu_buffer_clear(&commands);
  printf("answered=%d evaluated=%d blocked=%d sibling=%d\n", answered, evaluated, blocked, sibling);
  return answered && evaluated && blocked && sibling ? 0 : 1;
}
