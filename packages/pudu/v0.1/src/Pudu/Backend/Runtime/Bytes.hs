{-| @Pudu.Backend.Runtime.Bytes — byte sequences, as `Eval.Bytes` answers
    them. A sequence is a box whose one cell is a text view of counted
    storage, so a slice is a view rather than a copy. Every function reads its
    arguments and answers a new reference. Emitted after the frame types. -}
module Pudu.Backend.Runtime.Bytes (bytesRuntimeParts, bytesRuntimeDependencies) where

import Data.Text (Text)

bytesRuntimeParts :: [(Text, [Text])]
bytesRuntimeParts =
  [ ("bytes_wrap",
      [ "/* Takes the view's reference. */"
      , "static pudu_box *pudu_bytes_wrap(pudu_text bytes) {"
      , "  pudu_box *box = pudu_box_new(1);"
      , "  box->fields[0].text = bytes;"
      , "  return box;"
      , "}"
      ])
  , ("bytes_clamp",
      [ "static inline size_t pudu_bytes_clamp(pudu_int value, size_t size) {"
      , "  value = pudu_normal(value);"
      , "  if (value.negative) return 0;"
      , "  return value.bits > (uint64_t)size ? size : (size_t)value.bits;"
      , "}"
      ])
  , ("bytes_from_text",
      [ "static pudu_box *pudu_bytes_from_text(pudu_text text) { return pudu_bytes_wrap(pudu_text_retain(text)); }" ])
  , ("bytes_pack",
      [ "/* bytesOf: an Array[UInt8], one byte per item. */"
      , "static pudu_box *pudu_bytes_pack(pudu_box *array) {"
      , "  pudu_items *items = array->fields[0].items;"
      , "  unsigned char *bytes;"
      , "  pudu_text packed = pudu_text_allocate(items->length, &bytes);"
      , "  for (size_t i = 0; i < items->length; ++i) bytes[i] = (unsigned char)items->cells[i].integer.bits;"
      , "  return pudu_bytes_wrap(packed);"
      , "}"
      ])
  , ("bytes_length",
      [ "static pudu_int pudu_bytes_length(pudu_box *box) { return pudu_make((uint64_t)box->fields[0].text.length, 0); }" ])
  , ("bytes_at",
      [ "/* Only read where the index is known to lie inside. */"
      , "static pudu_int pudu_bytes_at(pudu_box *box, pudu_int index) {"
      , "  return pudu_make(box->fields[0].text.bytes[(size_t)pudu_normal(index).bits], 0);"
      , "}"
      ])
  , ("bytes_slice",
      [ "/* Both ends clamp into the sequence; an end before the start is empty. */"
      , "static pudu_box *pudu_bytes_slice(pudu_box *box, pudu_int from, pudu_int to) {"
      , "  pudu_text bytes = box->fields[0].text;"
      , "  size_t start = pudu_bytes_clamp(from, bytes.length), end = pudu_bytes_clamp(to, bytes.length);"
      , "  if (end < start) end = start;"
      , "  return pudu_bytes_wrap(pudu_text_view(bytes, start, end));"
      , "}"
      ])
  , ("bytes_take",
      [ "static pudu_box *pudu_bytes_take(pudu_box *box, pudu_int count) {"
      , "  pudu_text bytes = box->fields[0].text;"
      , "  return pudu_bytes_wrap(pudu_text_view(bytes, 0, pudu_bytes_clamp(count, bytes.length)));"
      , "}"
      ])
  , ("bytes_drop",
      [ "static pudu_box *pudu_bytes_drop(pudu_box *box, pudu_int count) {"
      , "  pudu_text bytes = box->fields[0].text;"
      , "  return pudu_bytes_wrap(pudu_text_view(bytes, pudu_bytes_clamp(count, bytes.length), bytes.length));"
      , "}"
      ])
  , ("bytes_concat",
      [ "static pudu_box *pudu_bytes_concat(pudu_box *box, pudu_box *other) {"
      , "  return pudu_bytes_wrap(pudu_text_concat(box->fields[0].text, other->fields[0].text));"
      , "}"
      ])
  , ("bytes_index_of",
      [ "static pudu_int pudu_bytes_index_of(pudu_box *box, pudu_box *needle) {"
      , "  size_t found = pudu_text_find(box->fields[0].text, needle->fields[0].text, 0);"
      , "  return found == SIZE_MAX ? pudu_make(1, 1) : pudu_make((uint64_t)found, 0);"
      , "}"
      ])
  , ("bytes_contains",
      [ "static int pudu_bytes_contains(pudu_box *box, pudu_box *needle) {"
      , "  return pudu_text_find(box->fields[0].text, needle->fields[0].text, 0) != SIZE_MAX;"
      , "}"
      ])
  , ("bytes_starts_with",
      [ "static int pudu_bytes_starts_with(pudu_box *box, pudu_box *prefix) {"
      , "  pudu_text bytes = box->fields[0].text, start = prefix->fields[0].text;"
      , "  return start.length <= bytes.length && (start.length == 0 || memcmp(bytes.bytes, start.bytes, start.length) == 0);"
      , "}"
      ])
  , ("bytes_ends_with",
      [ "static int pudu_bytes_ends_with(pudu_box *box, pudu_box *suffix) {"
      , "  pudu_text bytes = box->fields[0].text, end = suffix->fields[0].text;"
      , "  return end.length <= bytes.length && (end.length == 0 || memcmp(bytes.bytes + bytes.length - end.length, end.bytes, end.length) == 0);"
      , "}"
      ])
  , ("bytes_reverse",
      [ "static pudu_box *pudu_bytes_reverse(pudu_box *box) {"
      , "  pudu_text bytes = box->fields[0].text;"
      , "  unsigned char *out;"
      , "  pudu_text turned = pudu_text_allocate(bytes.length, &out);"
      , "  for (size_t i = 0; i < bytes.length; ++i) out[i] = bytes.bytes[bytes.length - 1 - i];"
      , "  return pudu_bytes_wrap(turned);"
      , "}"
      ])
  , ("bytes_to_array",
      [ "static pudu_box *pudu_bytes_to_array(pudu_box *box) {"
      , "  pudu_text bytes = box->fields[0].text;"
      , "  pudu_box *array = pudu_array_new(bytes.length);"
      , "  pudu_items *items = array->fields[0].items;"
      , "  for (size_t i = 0; i < bytes.length; ++i) items->cells[i].integer = pudu_make(bytes.bytes[i], 0);"
      , "  items->length = bytes.length;"
      , "  return array;"
      , "}"
      ])
  , ("bytes_is_text",
      [ "/* Well-formed UTF-8: shortest forms only, no surrogates, nothing past"
      , "   U+10FFFF, nothing cut short. */"
      , "static int pudu_bytes_is_text(pudu_box *box) {"
      , "  const unsigned char *b = box->fields[0].text.bytes;"
      , "  size_t length = box->fields[0].text.length, i = 0;"
      , "  while (i < length) {"
      , "    unsigned char lead = b[i];"
      , "    size_t width;"
      , "    unsigned char low = 0x80, high = 0xBF;"
      , "    if (lead < 0x80) { i += 1; continue; }"
      , "    if (lead >= 0xC2 && lead <= 0xDF) width = 2;"
      , "    else if (lead >= 0xE0 && lead <= 0xEF) {"
      , "      width = 3;"
      , "      if (lead == 0xE0) low = 0xA0;"
      , "      if (lead == 0xED) high = 0x9F;"
      , "    } else if (lead >= 0xF0 && lead <= 0xF4) {"
      , "      width = 4;"
      , "      if (lead == 0xF0) low = 0x90;"
      , "      if (lead == 0xF4) high = 0x8F;"
      , "    } else return 0;"
      , "    if (width > length - i) return 0;"
      , "    if (b[i + 1] < low || b[i + 1] > high) return 0;"
      , "    for (size_t k = 2; k < width; ++k) if (b[i + k] < 0x80 || b[i + k] > 0xBF) return 0;"
      , "    i += width;"
      , "  }"
      , "  return 1;"
      , "}"
      ])
  , ("bytes_as_text",
      [ "static pudu_text pudu_bytes_as_text(pudu_box *box) { return pudu_text_retain(box->fields[0].text); }" ])
  , ("bytes_show",
      [ "/* renderValue: 0x, then each byte as two lowercase hex digits. */"
      , "static pudu_text pudu_bytes_show(pudu_box *box) {"
      , "  static const char digits[] = \"0123456789abcdef\";"
      , "  pudu_text bytes = box->fields[0].text;"
      , "  unsigned char *out;"
      , "  pudu_text shown;"
      , "  if (bytes.length > (SIZE_MAX - 2) / 2) pudu_memory_failure();"
      , "  shown = pudu_text_allocate(2 + bytes.length * 2, &out);"
      , "  out[0] = '0';"
      , "  out[1] = 'x';"
      , "  for (size_t i = 0; i < bytes.length; ++i) {"
      , "    out[2 + 2 * i] = (unsigned char)digits[bytes.bytes[i] >> 4];"
      , "    out[3 + 2 * i] = (unsigned char)digits[bytes.bytes[i] & 15];"
      , "  }"
      , "  return shown;"
      , "}"
      ])
  ]

bytesRuntimeDependencies :: Text -> [Text]
bytesRuntimeDependencies name = maybe [] id (lookup name
  [ ("bytes_wrap", ["text"])
  , ("bytes_clamp", ["normal"])
  , ("bytes_from_text", ["bytes_wrap", "text_retain"])
  , ("bytes_pack", ["bytes_wrap", "array", "text_allocate"])
  , ("bytes_length", ["text", "make"])
  , ("bytes_at", ["text", "make", "normal"])
  , ("bytes_slice", ["bytes_wrap", "bytes_clamp", "text_view"])
  , ("bytes_take", ["bytes_wrap", "bytes_clamp", "text_view"])
  , ("bytes_drop", ["bytes_wrap", "bytes_clamp", "text_view"])
  , ("bytes_concat", ["bytes_wrap", "text_concat"])
  , ("bytes_index_of", ["text_find", "make"])
  , ("bytes_contains", ["text_find"])
  , ("bytes_starts_with", ["text"])
  , ("bytes_ends_with", ["text"])
  , ("bytes_reverse", ["bytes_wrap", "text_allocate"])
  , ("bytes_to_array", ["array", "make"])
  , ("bytes_is_text", ["text"])
  , ("bytes_as_text", ["text_retain"])
  , ("bytes_show", ["text_allocate", "memory_failure"])
  ])
