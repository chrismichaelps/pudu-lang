{-| @Backend.Runtime.Kernel.Bytes — byte helpers the kernels share: signed words, checked spans,
    little-endian words, fresh buffers and copies. -}
module Pudu.Backend.Runtime.Kernel.Bytes (bytesKernelParts) where

import Data.Text (Text)

{-| Each part: its name, the parts it needs, and its lines. -}
bytesKernelParts :: [(Text, [Text], [Text])]
bytesKernelParts =
  [ ("kernel_signed", [],
      [ "/* A 64-bit pattern as the signed word it spells. */"
      , "static inline int64_t pudu_kernel_signed(uint64_t bits) {"
      , "  return bits <= (uint64_t)INT64_MAX ? (int64_t)bits : -(int64_t)(~bits) - 1;"
      , "}"
      ])
  , ("kernel_int", ["integer_value"],
      [ "static inline pudu_int pudu_kernel_int(int64_t value) {"
      , "  return (pudu_int){(uint64_t)value, value < 0};"
      , "}"
      ])
  , ("kernel_span", ["text"],
      [ "/* Whether length bytes at offset lie inside the view. */"
      , "static inline int pudu_kernel_span(pudu_text bytes, int64_t offset, int64_t length) {"
      , "  return offset >= 0 && length >= 0 && (uint64_t)offset <= (uint64_t)bytes.length"
      , "    && (uint64_t)length <= (uint64_t)bytes.length - (uint64_t)offset;"
      , "}"
      ])
  , ("kernel_word", [],
      [ "/* Little-endian bytes as a word. */"
      , "static inline uint64_t pudu_kernel_word(const unsigned char *at, int width) {"
      , "  uint64_t word = 0;"
      , "  for (int i = width; i-- > 0;) word = (word << 8) | at[i];"
      , "  return word;"
      , "}"
      ])
  , ("kernel_put", [],
      [ "static inline void pudu_kernel_put(unsigned char *at, uint64_t word, int width) {"
      , "  for (int i = 0; i < width; ++i) at[i] = (unsigned char)(word >> (8 * i));"
      , "}"
      ])
  , ("kernel_read", ["kernel_span", "kernel_word"],
      [ "/* The word at a byte offset, when all eight bytes lie inside. */"
      , "static inline int pudu_kernel_read(pudu_text bytes, int64_t offset, uint64_t *word) {"
      , "  if (!pudu_kernel_span(bytes, offset, 8)) return 0;"
      , "  *word = pudu_kernel_word(bytes.bytes + offset, 8);"
      , "  return 1;"
      , "}"
      ])
  , ("kernel_fresh", ["text_allocate"],
      [ "/* A zeroed buffer. */"
      , "static pudu_text pudu_kernel_fresh(size_t length, unsigned char **bytes) {"
      , "  pudu_text text = pudu_text_allocate(length, bytes);"
      , "  if (length != 0) memset(*bytes, 0, length);"
      , "  return text;"
      , "}"
      ])
  , ("kernel_clone", ["text_allocate"],
      [ "/* A copy of a view, to write into. */"
      , "static pudu_text pudu_kernel_clone(pudu_text source, unsigned char **bytes) {"
      , "  pudu_text text = pudu_text_allocate(source.length, bytes);"
      , "  if (source.length != 0) memcpy(*bytes, source.bytes, source.length);"
      , "  return text;"
      , "}"
      ])
  , ("kernel_pack", ["bytes_wrap", "text_allocate"],
      [ "/* A byte sequence holding a copy of length bytes. */"
      , "static pudu_box *pudu_kernel_pack(const unsigned char *source, size_t length) {"
      , "  unsigned char *bytes;"
      , "  pudu_text text = pudu_text_allocate(length, &bytes);"
      , "  if (length != 0) memcpy(bytes, source, length);"
      , "  return pudu_bytes_wrap(text);"
      , "}"
      ])
  ]
