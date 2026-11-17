#ifndef PUDU_IOS_STREAM_H
#define PUDU_IOS_STREAM_H

/* Reading the view stream: little-endian words and length-prefixed UTF-8
   text. A stream that ends inside an instruction, or names something the
   host does not know, is a defect in the program that wrote it: the host
   reports it and stops rather than guessing. */
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static _Noreturn void pudu_stream_defect(const char *problem, uint32_t value) {
  fprintf(stderr, "pudu: a view stream %s %u\n", problem, value);
  abort();
}

typedef struct {
  const uint8_t *bytes;
  uint64_t length, at;
} pudu_reader;

static uint32_t pudu_word(pudu_reader *reader) {
  const uint8_t *b = reader->bytes + reader->at;
  if (reader->at + 4 > reader->length) pudu_stream_defect("ended inside an instruction at byte", (uint32_t)reader->at);
  reader->at += 4;
  return (uint32_t)b[0] | (uint32_t)b[1] << 8 | (uint32_t)b[2] << 16 | (uint32_t)b[3] << 24;
}

static NSString *pudu_text(pudu_reader *reader) {
  uint32_t count = pudu_word(reader);
  NSString *text;
  if (reader->at + count > reader->length) pudu_stream_defect("ended inside text of length", count);
  text = [[NSString alloc] initWithBytes:reader->bytes + reader->at length:count encoding:NSUTF8StringEncoding];
  reader->at += count;
  return text;
}

#endif
