#include "pudu_webview_records.h"

#include <stdio.h>
#include <string.h>

static int failures = 0;

static void expect(int condition, const char *what) {
  if (!condition) {
    failures++;
    fprintf(stderr, "FAILED: %s\n", what);
  }
}

static void framing(void) {
  const char *input = "4:view,1:3,8:navigate,\n0:,2:\n\t,\n";
  size_t cursor = 0;
  pudu_field fields[PUDU_RECORD_FIELDS];
  int count = pudu_record_next((const uint8_t *)input, strlen(input), &cursor, fields, PUDU_RECORD_FIELDS);
  expect(count == 3 && pudu_field_is(fields[0], "view") && pudu_field_is(fields[2], "navigate"), "first record");
  int64_t id = 0;
  expect(pudu_field_int(fields[1], &id) == 0 && id == 3, "integer field");
  count = pudu_record_next((const uint8_t *)input, strlen(input), &cursor, fields, PUDU_RECORD_FIELDS);
  expect(count == 2 && fields[0].length == 0 && fields[1].length == 2 && memcmp(fields[1].data, "\n\t", 2) == 0,
         "empty and control-character fields");
  expect(pudu_record_next((const uint8_t *)input, strlen(input), &cursor, fields, PUDU_RECORD_FIELDS) == 0, "end");

  const char *bad[] = {"x:ab,\n", "5:ab,\n", "2:ab\n", "2:ab,", "\n", "99999999999999999999:a,\n"};
  for (size_t i = 0; i < sizeof bad / sizeof bad[0]; i++) {
    size_t at = 0;
    expect(pudu_record_next((const uint8_t *)bad[i], strlen(bad[i]), &at, fields, PUDU_RECORD_FIELDS) == -1,
           bad[i]);
  }
  size_t at = 0;
  expect(pudu_record_next((const uint8_t *)"1:a,1:b,1:c,\n", 13, &at, fields, 2) == -1, "too many fields");
}

static void buffers(void) {
  pudu_buffer buffer = {0};
  pudu_buffer_text(&buffer, "eval");
  pudu_buffer_int(&buffer, -42);
  pudu_buffer_field(&buffer, "a\nb", 3);
  pudu_buffer_end(&buffer);
  const char *wanted = "4:eval,3:-42,3:a\nb,\n";
  expect(pudu_buffer_drain(&buffer, NULL, 0) == (int64_t)strlen(wanted), "measured");
  uint8_t small[4];
  expect(pudu_buffer_drain(&buffer, small, sizeof small) == (int64_t)strlen(wanted) && buffer.length == strlen(wanted),
         "a short buffer copies nothing");
  uint8_t out[64];
  expect(pudu_buffer_drain(&buffer, out, sizeof out) == (int64_t)strlen(wanted) && memcmp(out, wanted, strlen(wanted)) == 0 &&
             buffer.length == 0,
         "drained");
  pudu_buffer_clear(&buffer);
  pudu_field nul = {(const uint8_t *)"a\0b", 3};
  expect(pudu_field_copy(nul) == NULL, "NUL refused");
}

static void patterns(void) {
  expect(pudu_pattern_match("https://*.example.com/*", "https://docs.example.com/a/b"), "subdomain");
  expect(!pudu_pattern_match("https://*.example.com/*", "https://evil.test/x.example.com/"), "wildcard cannot cross a slash");
  expect(!pudu_pattern_match("https://*.example.com/*", "https://evil.test?.example.com/"), "wildcard cannot cross a query");
  expect(!pudu_pattern_match("https://*.example.com/*", "https://a.example.com@evil.test/"), "wildcard cannot cross userinfo");
  expect(pudu_pattern_match("http://localhost:5173/*", "http://localhost:5173/src/main.js"), "port and path");
  expect(!pudu_pattern_match("http://localhost:5173/*", "http://localhost:51730/"), "port is exact");
  expect(pudu_pattern_match("https://example.com/*", "https://example.com/"), "empty path rest");
  expect(!pudu_pattern_match("https://example.com/docs/*", "https://example.com/other"), "path prefix");
  expect(pudu_pattern_match("about:blank", "about:blank"), "no authority, exact");
  expect(!pudu_pattern_match("about:*", "https://example.com/"), "schemes differ");
}

int main(void) {
  framing();
  buffers();
  patterns();
  if (failures == 0) {
    printf("webview records: all passed\n");
  }
  return failures == 0 ? 0 : 1;
}
