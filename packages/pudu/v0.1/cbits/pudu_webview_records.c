#include "pudu_webview_records.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* A length prefix longer than this cannot describe a field in memory. */
#define PUDU_LENGTH_DIGITS 19

int pudu_record_next(
    const uint8_t *bytes,
    size_t length,
    size_t *cursor,
    pudu_field *fields,
    int capacity) {
  size_t at = *cursor;
  if (at >= length) {
    return 0;
  }
  int count = 0;
  while (at < length && bytes[at] != '\n') {
    size_t value = 0;
    int digits = 0;
    while (at < length && bytes[at] >= '0' && bytes[at] <= '9') {
      if (++digits > PUDU_LENGTH_DIGITS) {
        return -1;
      }
      value = value * 10 + (size_t)(bytes[at] - '0');
      at++;
    }
    if (digits == 0 || at >= length || bytes[at] != ':') {
      return -1;
    }
    at++;
    if (value > length - at || length - at - value < 1 || bytes[at + value] != ',') {
      return -1;
    }
    if (count == capacity) {
      return -1;
    }
    fields[count].data = bytes + at;
    fields[count].length = value;
    count++;
    at += value + 1;
  }
  /* An empty record would read as the end of input. */
  if (at >= length || count == 0) {
    return -1;
  }
  *cursor = at + 1;
  return count;
}

static int pudu_buffer_reserve(pudu_buffer *buffer, size_t extra) {
  if (extra > SIZE_MAX - buffer->length) {
    return -1;
  }
  size_t wanted = buffer->length + extra;
  if (wanted <= buffer->capacity) {
    return 0;
  }
  size_t grown = buffer->capacity < 256 ? 256 : buffer->capacity;
  while (grown < wanted) {
    if (grown > SIZE_MAX / 2) {
      grown = wanted;
      break;
    }
    grown *= 2;
  }
  uint8_t *moved = realloc(buffer->data, grown);
  if (moved == NULL) {
    return -1;
  }
  buffer->data = moved;
  buffer->capacity = grown;
  return 0;
}

static int pudu_buffer_raw(pudu_buffer *buffer, const void *data, size_t length) {
  if (pudu_buffer_reserve(buffer, length) != 0) {
    return -1;
  }
  if (length > 0) {
    memcpy(buffer->data + buffer->length, data, length);
  }
  buffer->length += length;
  return 0;
}

int pudu_buffer_field(pudu_buffer *buffer, const void *data, size_t length) {
  char prefix[32];
  int written = snprintf(prefix, sizeof prefix, "%zu:", length);
  size_t saved = buffer->length;
  if (pudu_buffer_raw(buffer, prefix, (size_t)written) != 0 ||
      pudu_buffer_raw(buffer, data, length) != 0 ||
      pudu_buffer_raw(buffer, ",", 1) != 0) {
    buffer->length = saved;
    return -1;
  }
  return 0;
}

int pudu_buffer_text(pudu_buffer *buffer, const char *text) {
  return pudu_buffer_field(buffer, text, text == NULL ? 0 : strlen(text));
}

int pudu_buffer_int(pudu_buffer *buffer, int64_t value) {
  char digits[32];
  int written = snprintf(digits, sizeof digits, "%lld", (long long)value);
  return pudu_buffer_field(buffer, digits, (size_t)written);
}

int pudu_buffer_end(pudu_buffer *buffer) {
  return pudu_buffer_raw(buffer, "\n", 1);
}

int64_t pudu_buffer_drain(pudu_buffer *buffer, uint8_t *out, size_t capacity) {
  int64_t held = (int64_t)buffer->length;
  if (out != NULL && buffer->length <= capacity) {
    if (buffer->length > 0) {
      memcpy(out, buffer->data, buffer->length);
    }
    buffer->length = 0;
  }
  return held;
}

void pudu_buffer_clear(pudu_buffer *buffer) {
  free(buffer->data);
  buffer->data = NULL;
  buffer->length = 0;
  buffer->capacity = 0;
}

int pudu_field_is(pudu_field field, const char *word) {
  size_t length = strlen(word);
  return field.length == length && memcmp(field.data, word, length) == 0;
}

int pudu_field_int(pudu_field field, int64_t *out) {
  size_t at = 0;
  int negative = 0;
  if (field.length > 0 && field.data[0] == '-') {
    negative = 1;
    at = 1;
  }
  if (at == field.length || field.length - at > 18) {
    return -1;
  }
  int64_t value = 0;
  for (; at < field.length; at++) {
    uint8_t digit = field.data[at];
    if (digit < '0' || digit > '9') {
      return -1;
    }
    value = value * 10 + (digit - '0');
  }
  *out = negative ? -value : value;
  return 0;
}

char *pudu_field_copy(pudu_field field) {
  if (memchr(field.data, 0, field.length) != NULL) {
    return NULL;
  }
  char *copy = malloc(field.length + 1);
  if (copy == NULL) {
    return NULL;
  }
  memcpy(copy, field.data, field.length);
  copy[field.length] = 0;
  return copy;
}

/* Where the authority ends: the first '/', '?' or '#' after "://", or the
   end of the text when it has no scheme separator. */
static size_t pudu_authority_end(const char *text) {
  const char *separator = strstr(text, "://");
  if (separator == NULL) {
    return 0;
  }
  size_t at = (size_t)(separator - text) + 3;
  while (text[at] != 0 && text[at] != '/' && text[at] != '?' && text[at] != '#') {
    at++;
  }
  return at;
}

static int pudu_delimits(char c) {
  return c == '/' || c == '?' || c == '#' || c == '@';
}

/* Matches text[0..text_length) in full; when bounded, '*' cannot cross a
   character that ends or delimits an authority. */
static int pudu_glob(const char *pattern, size_t pattern_length, const char *text, size_t text_length, int bounded) {
  size_t p = 0, t = 0, star = (size_t)-1, resume = 0;
  while (t < text_length) {
    char c = text[t];
    if (p < pattern_length && pattern[p] == '*') {
      star = p++;
      resume = t;
    } else if (p < pattern_length && pattern[p] == c) {
      p++;
      t++;
    } else if (star != (size_t)-1 && !(bounded && pudu_delimits(text[resume]))) {
      p = star + 1;
      t = ++resume;
    } else {
      return 0;
    }
  }
  while (p < pattern_length && pattern[p] == '*') {
    p++;
  }
  return p == pattern_length;
}

int pudu_pattern_match(const char *pattern, const char *text) {
  size_t pattern_split = pudu_authority_end(pattern);
  size_t text_split = pudu_authority_end(text);
  if (pattern_split == 0 || text_split == 0) {
    return pattern_split == text_split &&
        pudu_glob(pattern, strlen(pattern), text, strlen(text), 1);
  }
  return pudu_glob(pattern, pattern_split, text, text_split, 1) &&
      pudu_glob(pattern + pattern_split, strlen(pattern + pattern_split),
                text + text_split, strlen(text + text_split), 0);
}
