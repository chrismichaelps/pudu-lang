{-| @Backend.Runtime.Kernel.Checksum — CRC-32, CRC-32C, CRC-64 and FNV-1a, chained from a
    previous result. -}
module Pudu.Backend.Runtime.Kernel.Checksum (checksumKernelParts) where

import Data.Text (Text)

{-| Each part: its name, the parts it needs, and its lines. -}
checksumKernelParts :: [(Text, [Text], [Text])]
checksumKernelParts =
  [ ("checksum_known", [],
      [ "static int pudu_checksum_known(pudu_int code) {"
      , "  return !code.negative && code.bits <= 4;"
      , "}"
      ])
  , ("checksum", ["make"],
      [ "/* The checksum after previous: CRC-32 IEEE (0), CRC-32C (1), CRC-64 ECMA (2),"
      , "   FNV-1a 32 (3) or FNV-1a 64 (4). A CRC's previous value is its finished"
      , "   result, inverted back into the register. */"
      , "static pudu_int pudu_checksum(pudu_int code, pudu_int previous, pudu_box *message) {"
      , "  pudu_text bytes = message->fields[0].text;"
      , "  uint64_t state = previous.bits;"
      , "  if (code.bits <= 1) {"
      , "    uint32_t polynomial = code.bits == 0 ? UINT32_C(0xedb88320) : UINT32_C(0x82f63b78), held = ~(uint32_t)state;"
      , "    for (size_t i = 0; i < bytes.length; ++i) {"
      , "      held ^= bytes.bytes[i];"
      , "      for (int bit = 0; bit < 8; ++bit) held = (held & 1) != 0 ? (held >> 1) ^ polynomial : held >> 1;"
      , "    }"
      , "    return pudu_make((uint32_t)~held, 0);"
      , "  }"
      , "  if (code.bits == 2) {"
      , "    state = ~state;"
      , "    for (size_t i = 0; i < bytes.length; ++i) {"
      , "      state ^= bytes.bytes[i];"
      , "      for (int bit = 0; bit < 8; ++bit) state = (state & 1) != 0 ? (state >> 1) ^ UINT64_C(0xc96c5795d7870f42) : state >> 1;"
      , "    }"
      , "    return pudu_make(~state, 0);"
      , "  }"
      , "  if (code.bits == 3) {"
      , "    uint32_t held = (uint32_t)state;"
      , "    for (size_t i = 0; i < bytes.length; ++i) held = (held ^ bytes.bytes[i]) * UINT32_C(0x01000193);"
      , "    return pudu_make(held, 0);"
      , "  }"
      , "  for (size_t i = 0; i < bytes.length; ++i) state = (state ^ bytes.bytes[i]) * UINT64_C(0x100000001b3);"
      , "  return pudu_make(state, 0);"
      , "}"
      ])
  ]
