#include "pudu_webview.h"
#include "pudu_webview_records.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
static uint64_t now(void) { return GetTickCount64(); }
#else
#include <time.h>
static uint64_t now(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return (uint64_t)t.tv_sec * 1000 + (uint64_t)t.tv_nsec / 1000000;
}
#endif

static void record(pudu_buffer *buffer, const char *const *fields, int count) {
  for (int i = 0; i < count; ++i) pudu_buffer_text(buffer, fields[i]);
  pudu_buffer_end(buffer);
}

static int send_commands(pudu_buffer *buffer) {
  int result = pudu_webview_send(buffer->data, buffer->length);
  buffer->length = 0;
  if (result != PUDU_WEBVIEW_DONE) {
    uint8_t error[1024] = {0};
    pudu_webview_failure(error, sizeof error - 1);
    fprintf(stderr, "network harness command failed %d: %s\n", result, error);
  }
  return result == PUDU_WEBVIEW_DONE;
}

int main(int argc, char **argv) {
  if (argc < 2 || strncmp(argv[1], "http://127.0.0.1:", 17) != 0) return 2;
  char url[256], allowed[256];
  snprintf(url, sizeof url, "%s/policy-page", argv[1]);
  snprintf(allowed, sizeof allowed, "%s/*", argv[1]);
  const char *cookieRule = "[{\"trigger\":{\"url-filter\":\"cookie-protected\",\"resource-type\":[\"raw\"],\"if-domain\":[\"127.0.0.1\"]},\"action\":{\"type\":\"block-cookies\"}},{\"trigger\":{\"url-filter\":\"blocked-endpoint\"},\"action\":{\"type\":\"block\"}}]";
  const char *upgradeRule = "[{\"trigger\":{\"url-filter\":\"upgrade-endpoint\"},\"action\":{\"type\":\"make-https\"}}]";
  pudu_buffer commands = {0};
  const char *open[] = {"window", "1", "open", "Pudu network policy", "480", "320", "1"};
  const char *create[] = {"view", "1", "create", "1", "0", "0", "0", "0", "1"};
  const char *navigation[] = {"view", "1", "navigation-allow", allowed};
  const char *ephemeral[] = {"view", "1", "ephemeral"};
  const char *rules[] = {"view", "1", "rules", cookieRule};
  const char *upgrade[] = {"view", "1", "rules", upgradeRule};
  const char *page[] = {"view", "1", "url", url};
  const char *realize[] = {"view", "1", "realize"};
  const char *show[] = {"window", "1", "show"};
  record(&commands, open, 7); record(&commands, create, 9); record(&commands, navigation, 4);
  record(&commands, ephemeral, 3);
  record(&commands, rules, 4);
  if (argc > 2) record(&commands, upgrade, 4);
  record(&commands, page, 4); record(&commands, realize, 3); record(&commands, show, 3);
  if (!send_commands(&commands)) return 1;
  int passed = 0, failed = 0;
  for (uint64_t deadline = now() + 30000; !passed && !failed && now() < deadline;) {
    if (pudu_webview_pump(100) < 0) break;
    int64_t length = pudu_webview_events(NULL, 0);
    if (length <= 0) continue;
    uint8_t *events = malloc((size_t)length);
    if (events == NULL) break;
    if (pudu_webview_events(events, (size_t)length) != length) { free(events); break; }
    size_t at = 0;
    pudu_field fields[PUDU_RECORD_FIELDS];
    int count;
    while ((count = pudu_record_next(events, (size_t)length, &at, fields, PUDU_RECORD_FIELDS)) > 0) {
      if (count == 3 && pudu_field_is(fields[0], "title")) {
        if (pudu_field_is(fields[2], "policy-network:ok")) passed = 1;
        if (pudu_field_is(fields[2], "policy-network:failed")) failed = 1;
      }
      if (count >= 3 && pudu_field_is(fields[0], "rules") && pudu_field_is(fields[2], "failed")) failed = 1;
      if (count >= 1 && pudu_field_is(fields[0], "crashed")) failed = 1;
    }
    free(events);
  }
  const char *close[] = {"window", "1", "close"};
  record(&commands, close, 3); send_commands(&commands); pudu_buffer_clear(&commands);
  printf("policy-network=%d\n", passed && !failed);
  return passed && !failed ? 0 : 1;
}
