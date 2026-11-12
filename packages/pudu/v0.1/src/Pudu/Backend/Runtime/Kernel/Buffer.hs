{-| @Backend.Runtime.Kernel.Buffer — the buffer primitives, as `Pudu.Runtime.Buffer` answers
    them. A write answers a new buffer. -}
module Pudu.Backend.Runtime.Kernel.Buffer (bufferKernelParts) where

import Data.Text (Text)

{-| Each part: its name, the parts it needs, and its lines. -}
bufferKernelParts :: [(Text, [Text], [Text])]
bufferKernelParts =
  [ ("buffer_alloc", ["kernel_signed", "kernel_fresh", "bytes_wrap"],
      [ "static pudu_box *pudu_buffer_alloc(pudu_int size) {"
      , "  unsigned char *bytes;"
      , "  int64_t wanted = pudu_kernel_signed(size.bits);"
      , "  return pudu_bytes_wrap(pudu_kernel_fresh(wanted <= 0 ? 0 : (size_t)wanted, &bytes));"
      , "}"
      ])
  , ("buffer_fits", ["kernel_signed", "kernel_span"],
      [ "static int pudu_buffer_fits(pudu_box *buffer, pudu_int offset, int width) {"
      , "  return pudu_kernel_span(buffer->fields[0].text, pudu_kernel_signed(offset.bits), width);"
      , "}"
      ])
  , ("buffer_read_u64", ["kernel_signed", "kernel_word", "make"],
      [ "/* Reads run only where buffer_fits allowed them. */"
      , "static pudu_int pudu_buffer_read_u64(pudu_box *buffer, pudu_int offset) {"
      , "  return pudu_make(pudu_kernel_word(buffer->fields[0].text.bytes + pudu_kernel_signed(offset.bits), 8), 0);"
      , "}"
      ])
  , ("buffer_read_i64", ["kernel_signed", "kernel_word", "kernel_int"],
      [ "static pudu_int pudu_buffer_read_i64(pudu_box *buffer, pudu_int offset) {"
      , "  return pudu_kernel_int(pudu_kernel_signed(pudu_kernel_word(buffer->fields[0].text.bytes + pudu_kernel_signed(offset.bits), 8)));"
      , "}"
      ])
  , ("buffer_read_f64", ["kernel_signed", "kernel_word"],
      [ "static uint64_t pudu_buffer_read_f64(pudu_box *buffer, pudu_int offset) {"
      , "  return pudu_kernel_word(buffer->fields[0].text.bytes + pudu_kernel_signed(offset.bits), 8);"
      , "}"
      ])
  , ("buffer_read_u32", ["kernel_signed", "kernel_word", "make"],
      [ "static pudu_int pudu_buffer_read_u32(pudu_box *buffer, pudu_int offset) {"
      , "  return pudu_make(pudu_kernel_word(buffer->fields[0].text.bytes + pudu_kernel_signed(offset.bits), 4), 0);"
      , "}"
      ])
  , ("buffer_write_word", ["kernel_signed", "kernel_clone", "kernel_put", "bytes_wrap"],
      [ "/* A new buffer with the value's low width bytes at the offset. */"
      , "static pudu_box *pudu_buffer_write_word(pudu_box *buffer, pudu_int offset, pudu_int value, int width) {"
      , "  unsigned char *bytes;"
      , "  pudu_text written = pudu_kernel_clone(buffer->fields[0].text, &bytes);"
      , "  pudu_kernel_put(bytes + pudu_kernel_signed(offset.bits), value.bits, width);"
      , "  return pudu_bytes_wrap(written);"
      , "}"
      ])
  , ("buffer_write_f64", ["kernel_signed", "kernel_clone", "kernel_put", "bytes_wrap"],
      [ "static pudu_box *pudu_buffer_write_f64(pudu_box *buffer, pudu_int offset, uint64_t value) {"
      , "  unsigned char *bytes;"
      , "  pudu_text written = pudu_kernel_clone(buffer->fields[0].text, &bytes);"
      , "  pudu_kernel_put(bytes + pudu_kernel_signed(offset.bits), value, 8);"
      , "  return pudu_bytes_wrap(written);"
      , "}"
      ])
  , ("buffer_span_fits", ["kernel_signed", "kernel_span"],
      [ "static int pudu_buffer_span_fits(pudu_box *buffer, pudu_int offset, pudu_int length) {"
      , "  return pudu_kernel_span(buffer->fields[0].text, pudu_kernel_signed(offset.bits), pudu_kernel_signed(length.bits));"
      , "}"
      ])
  , ("buffer_fill", ["kernel_signed", "kernel_clone", "bytes_wrap"],
      [ "static pudu_box *pudu_buffer_fill(pudu_box *buffer, pudu_int offset, pudu_int length, pudu_int byte) {"
      , "  unsigned char *bytes;"
      , "  pudu_text written = pudu_kernel_clone(buffer->fields[0].text, &bytes);"
      , "  size_t count = (size_t)pudu_kernel_signed(length.bits);"
      , "  if (count != 0) memset(bytes + pudu_kernel_signed(offset.bits), (int)(byte.bits & 0xFF), count);"
      , "  return pudu_bytes_wrap(written);"
      , "}"
      ])
  , ("buffer_pair_fits", ["kernel_signed", "kernel_span"],
      [ "/* Whether the same length lies inside both buffers at their offsets. */"
      , "static int pudu_buffer_pair_fits(pudu_box *first, pudu_int first_offset, pudu_box *second, pudu_int second_offset, pudu_int length) {"
      , "  int64_t count = pudu_kernel_signed(length.bits);"
      , "  return pudu_kernel_span(first->fields[0].text, pudu_kernel_signed(first_offset.bits), count)"
      , "    && pudu_kernel_span(second->fields[0].text, pudu_kernel_signed(second_offset.bits), count);"
      , "}"
      ])
  , ("buffer_compare", ["kernel_signed", "kernel_int"],
      [ "static pudu_int pudu_buffer_compare(pudu_box *first, pudu_int first_offset, pudu_box *second, pudu_int second_offset, pudu_int length) {"
      , "  size_t count = (size_t)pudu_kernel_signed(length.bits);"
      , "  int order = count == 0 ? 0 : memcmp(first->fields[0].text.bytes + pudu_kernel_signed(first_offset.bits),"
      , "    second->fields[0].text.bytes + pudu_kernel_signed(second_offset.bits), count);"
      , "  return pudu_kernel_int((order > 0) - (order < 0));"
      , "}"
      ])
  , ("buffer_copy", ["kernel_signed", "kernel_clone", "bytes_wrap"],
      [ "/* A new buffer: the destination with a span of the source written in. */"
      , "static pudu_box *pudu_buffer_copy(pudu_box *source, pudu_int source_offset, pudu_box *target, pudu_int target_offset, pudu_int length) {"
      , "  unsigned char *bytes;"
      , "  pudu_text written = pudu_kernel_clone(target->fields[0].text, &bytes);"
      , "  size_t count = (size_t)pudu_kernel_signed(length.bits);"
      , "  if (count != 0) memcpy(bytes + pudu_kernel_signed(target_offset.bits),"
      , "    source->fields[0].text.bytes + pudu_kernel_signed(source_offset.bits), count);"
      , "  return pudu_bytes_wrap(written);"
      , "}"
      ])
  , ("buffer_scan", ["kernel_signed", "kernel_word", "kernel_int", "make"],
      [ "/* The index of the first word equal to the needle among count words, or -1. */"
      , "static pudu_int pudu_buffer_scan(pudu_box *buffer, pudu_int offset, pudu_int count, pudu_int needle) {"
      , "  pudu_text bytes = buffer->fields[0].text;"
      , "  int64_t start = pudu_kernel_signed(offset.bits), words = pudu_kernel_signed(count.bits);"
      , "  if (start < 0 || words < 0 || (uint64_t)start > (uint64_t)bytes.length"
      , "      || (uint64_t)words > ((uint64_t)bytes.length - (uint64_t)start) / 8) return pudu_make(1, 1);"
      , "  for (int64_t index = 0; index < words; ++index)"
      , "    if (pudu_kernel_word(bytes.bytes + start + index * 8, 8) == needle.bits) return pudu_kernel_int(index);"
      , "  return pudu_make(1, 1);"
      , "}"
      ])
  ]
