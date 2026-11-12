#include "pudu_webview.h"
#include "pudu_webview_records.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
extern HANDLE pudu_storage_browser(int64_t id);
extern int pudu_storage_mode(int64_t id, int expected, const char *identity);
extern int pudu_storage_replay(int64_t id, int64_t source, const char *name);
static uint64_t now(void) { return GetTickCount64(); }

static int wait_browser(HANDLE browser, uint64_t deadline) {
  for (uint64_t current = now(); current < deadline; current = now()) {
    uint64_t remaining = deadline - current;
    DWORD ready = MsgWaitForMultipleObjectsEx(1, &browser, (DWORD)remaining, QS_ALLINPUT, MWMO_INPUTAVAILABLE);
    if (ready == WAIT_OBJECT_0) return 1;
    if (ready != WAIT_OBJECT_0 + 1) break;
    MSG message;
    if (PeekMessageW(&message, NULL, 0, 0, PM_REMOVE)) {
      TranslateMessage(&message);
      DispatchMessageW(&message);
    }
  }
  fprintf(stderr, "browser exit could not be verified\n");
  return 0;
}
#else
#include <time.h>
static uint64_t now(void) {
  struct timespec value;
  clock_gettime(CLOCK_MONOTONIC, &value);
  return (uint64_t)value.tv_sec * 1000 + (uint64_t)value.tv_nsec / 1000000;
}
#endif

static int record(pudu_buffer *buffer, const char *const *fields, int count) {
  for (int i = 0; i < count; ++i)
    if (pudu_buffer_text(buffer, fields[i]) != 0) return 0;
  return pudu_buffer_end(buffer) == 0;
}

static int send_commands(pudu_buffer *buffer) {
  int status = pudu_webview_send(buffer->data, buffer->length);
  buffer->length = 0;
  if (status != PUDU_WEBVIEW_DONE) {
    uint8_t reason[512] = {0};
    pudu_webview_failure(reason, sizeof reason - 1);
    fprintf(stderr, "storage command refused (%d): %s\n", status, reason);
  }
  return status == PUDU_WEBVIEW_DONE;
}

static int add_view(pudu_buffer *commands, const char *id, const char *label,
                    int ephemeral, const char *nonce, int reading, int persistent, int realize_now) {
  char page[2048];
  const char *expected = reading && persistent ? nonce : "";
  /* A private writer uses a different marker, so aliasing also corrupts the persistent assertion. */
  const char *written = persistent ? nonce : "private-marker";
  snprintf(page, sizeof page,
    "<html><head><script>try{const k='pudu-storage-probe';"
    "if((localStorage.getItem(k)||'')!=='%s')throw Error('unexpected initial value');"
    "document.title='storage-ok:%s'}catch(e){document.title='storage-failed:'+String(e)}</script></head></html>",
    expected, id);
  if (!reading) {
    snprintf(page, sizeof page,
      "<html><head><script>try{const k='pudu-storage-probe';"
      "if(localStorage.getItem(k)!==null)throw Error('store was not fresh');"
      "localStorage.setItem(k,'%s');"
      "if(localStorage.getItem(k)!=='%s')throw Error('write readback failed');"
      "document.title='storage-ok:%s'}catch(e){document.title='storage-failed:'+String(e)}</script></head></html>",
      written, written, id);
  }
  const char *create[] = {"view", id, "create", "1", "0", "0", "120", "80", "0"};
  const char *store[] = {"view", id, "data-store", label};
  const char *private_view[] = {"view", id, "ephemeral"};
  const char *html[] = {"view", id, "html", page};
  const char *realize[] = {"view", id, "realize"};
  return record(commands, create, 9) && (label == NULL || record(commands, store, 4)) &&
    (!ephemeral || record(commands, private_view, 3)) && record(commands, html, 4) && (!realize_now || record(commands, realize, 3));
}

static int wait_views(unsigned expected, unsigned *seen) {
  int failed = 0;
  for (uint64_t deadline = now() + 60000; !failed && *seen != expected && now() < deadline;) {
    if (pudu_webview_pump(50) < 0) { failed = 1; break; }
    int64_t length = pudu_webview_events(NULL, 0);
    if (length < 0) { failed = 1; break; }
    if (length == 0) continue;
    uint8_t *events = malloc((size_t)length);
    if (events == NULL) { failed = 1; break; }
    if (pudu_webview_events(events, (size_t)length) != length) { free(events); failed = 1; break; }
    size_t at = 0;
    pudu_field fields[PUDU_RECORD_FIELDS];
    int count;
    while ((count = pudu_record_next(events, (size_t)length, &at, fields, PUDU_RECORD_FIELDS)) > 0) {
      if (pudu_field_is(fields[0], "refused") || pudu_field_is(fields[0], "crashed")) failed = 1;
      if (count == 3 && pudu_field_is(fields[0], "title")) {
        int matched = 0;
        for (unsigned i = 0; i < 6u; ++i) {
          char title[32], id[4];
          snprintf(id, sizeof id, "%u", i + 1);
          snprintf(title, sizeof title, "storage-ok:%s", id);
          if (pudu_field_is(fields[1], id) && pudu_field_is(fields[2], title)) { *seen |= 1u << i; matched = 1; }
        }
        if (!matched && fields[2].length >= 15 && memcmp(fields[2].data, "storage-failed:", 15) == 0) failed = 1;
      }
      if (failed) {
        for (int i = 0; i < count; ++i)
          fprintf(stderr, "%s%.*s", i == 0 ? "storage event: " : " | ", (int)fields[i].length, (const char *)fields[i].data);
        fprintf(stderr, "\n");
      }
    }
    if (count < 0) failed = 1;
    free(events);
  }
  return !failed && *seen == expected;
}

int main(int argc, char **argv) {
  if (argc != 3 || (strcmp(argv[1], "write") != 0 && strcmp(argv[1], "read") != 0) || strlen(argv[2]) != 32 ||
      strspn(argv[2], "0123456789abcdef") != 32) {
    fprintf(stderr, "usage: storage write|read <32 lowercase hex characters>\n");
    return 2;
  }
  int reading = strcmp(argv[1], "read") == 0;
  char label[80], other[88];
  snprintf(label, sizeof label, "pudu-storage-%s", argv[2]);
  snprintf(other, sizeof other, "%s-other", label);
  pudu_buffer commands = {0};
  const char *open[] = {"window", "1", "open", "Pudu storage", "480", "320", "1"};
  const char *show[] = {"window", "1", "show"};
  int failed = !record(&commands, open, 7) ||
    !add_view(&commands, "1", label, 0, argv[2], reading, 1, 1) ||
    !add_view(&commands, "2", label, 1, argv[2], reading, 0, 1) ||
    !add_view(&commands, "3", NULL, 0, argv[2], reading, 0, 1) ||
    (reading && !add_view(&commands, "4", other, 0, argv[2], 1, 0, 1)) ||
    !record(&commands, show, 3) || !send_commands(&commands);
  unsigned seen = 0, expected = reading ? 15 : 7;
  if (!failed && !wait_views(expected, &seen)) failed = 1;
#ifdef _WIN32
  if (!failed && (!pudu_storage_mode(1, 0, NULL) || !pudu_storage_mode(2, 1, NULL) || !pudu_storage_mode(3, 1, NULL) ||
                 (reading && !pudu_storage_mode(4, 0, NULL)))) failed = 1;
  if (!failed && reading) {
    expected = 63;
    failed = !add_view(&commands, "5", NULL, 0, argv[2], 1, 0, 0) ||
      !add_view(&commands, "6", NULL, 0, argv[2], 1, 0, 0) || !send_commands(&commands) ||
      !pudu_storage_replay(5, 2, getenv("PUDU_STORAGE_PROFILE2")) ||
      !pudu_storage_replay(6, 3, getenv("PUDU_STORAGE_PROFILE3")) ||
      !wait_views(expected, &seen) || !pudu_storage_mode(5, 0, getenv("PUDU_STORAGE_PROFILE2")) || !pudu_storage_mode(6, 0, getenv("PUDU_STORAGE_PROFILE3"));
  }
  HANDLE browsers[6] = {0};
  unsigned browser_count = reading ? 6 : 3;
  if (!failed) {
    for (unsigned i = 0; i < browser_count; ++i) {
      browsers[i] = pudu_storage_browser((int64_t)i + 1);
      if (browsers[i] == NULL) failed = 1;
    }
  }
#endif
  const char *close[] = {"window", "1", "close"};
  commands.length = 0;
  if (!record(&commands, close, 3) || !send_commands(&commands)) failed = 1;
#ifdef _WIN32
  uint64_t deadline = now() + 30000;
  for (unsigned i = 0; i < browser_count; ++i) {
    if (browsers[i] == NULL) continue;
    if (!failed && !wait_browser(browsers[i], deadline)) failed = 1;
    CloseHandle(browsers[i]);
  }
  if (!failed) printf("storage-browser-exited=1\n");
#endif
  pudu_buffer_clear(&commands);
  int passed = !failed && seen == expected;
  printf("storage-%s=%d views=%u\n", argv[1], passed, seen);
  return passed ? 0 : 1;
}
