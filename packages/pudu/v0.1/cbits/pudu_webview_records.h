#ifndef PUDU_WEBVIEW_RECORDS_H
#define PUDU_WEBVIEW_RECORDS_H

#include <stddef.h>
#include <stdint.h>

/* The most fields any command or event carries. */
#define PUDU_RECORD_FIELDS 16

typedef struct {
  const uint8_t *data;
  size_t length;
} pudu_field;

/* Reads the record starting at *cursor into fields, advancing *cursor past
   it. Answers the field count, 0 at the end of input, -1 when malformed. */
int pudu_record_next(
    const uint8_t *bytes,
    size_t length,
    size_t *cursor,
    pudu_field *fields,
    int capacity);

typedef struct {
  uint8_t *data;
  size_t length;
  size_t capacity;
} pudu_buffer;

int pudu_buffer_field(pudu_buffer *buffer, const void *data, size_t length);
int pudu_buffer_text(pudu_buffer *buffer, const char *text);
int pudu_buffer_int(pudu_buffer *buffer, int64_t value);
int pudu_buffer_end(pudu_buffer *buffer);
/* Answers the contents' byte count and copies and clears them only when
   they fit in capacity. */
int64_t pudu_buffer_drain(pudu_buffer *buffer, uint8_t *out, size_t capacity);
void pudu_buffer_clear(pudu_buffer *buffer);

int pudu_field_is(pudu_field field, const char *word);
/* A decimal integer with an optional leading '-'; 0 on success. */
int pudu_field_int(pudu_field field, int64_t *out);
/* A NUL-terminated copy the caller frees; NULL when the field holds NUL. */
char *pudu_field_copy(pudu_field field);

/* Whether text matches pattern in full; '*' matches any run of bytes. */
int pudu_pattern_match(const char *pattern, const char *text);

#endif
