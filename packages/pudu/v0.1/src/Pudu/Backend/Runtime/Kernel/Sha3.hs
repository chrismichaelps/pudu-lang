{-| @Backend.Runtime.Kernel.Sha3 — the Keccak permutation and the SHA-3 sponge. -}
module Pudu.Backend.Runtime.Kernel.Sha3 (sha3KernelParts) where

import Data.Text (Text)

{-| Each part: its name, the parts it needs, and its lines. -}
sha3KernelParts :: [(Text, [Text], [Text])]
sha3KernelParts =
  [ ("keccak", [],
      [ "/* The Keccak-f[1600] permutation over 25 lanes. */"
      , "static void pudu_keccak(uint64_t *lanes) {"
      , "  static const uint64_t rounds[24] = {"
      , "    UINT64_C(0x0000000000000001), UINT64_C(0x0000000000008082), UINT64_C(0x800000000000808a), UINT64_C(0x8000000080008000),"
      , "    UINT64_C(0x000000000000808b), UINT64_C(0x0000000080000001), UINT64_C(0x8000000080008081), UINT64_C(0x8000000000008009),"
      , "    UINT64_C(0x000000000000008a), UINT64_C(0x0000000000000088), UINT64_C(0x0000000080008009), UINT64_C(0x000000008000000a),"
      , "    UINT64_C(0x000000008000808b), UINT64_C(0x800000000000008b), UINT64_C(0x8000000000008089), UINT64_C(0x8000000000008003),"
      , "    UINT64_C(0x8000000000008002), UINT64_C(0x8000000000000080), UINT64_C(0x000000000000800a), UINT64_C(0x800000008000000a),"
      , "    UINT64_C(0x8000000080008081), UINT64_C(0x8000000000008080), UINT64_C(0x0000000080000001), UINT64_C(0x8000000080008008) };"
      , "  static const unsigned char turns[24] = {1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44};"
      , "  static const unsigned char moves[24] = {10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1};"
      , "  for (int round = 0; round < 24; ++round) {"
      , "    uint64_t column[5], held;"
      , "    for (int i = 0; i < 5; ++i) column[i] = lanes[i] ^ lanes[i + 5] ^ lanes[i + 10] ^ lanes[i + 15] ^ lanes[i + 20];"
      , "    for (int i = 0; i < 5; ++i) {"
      , "      uint64_t mixed = column[(i + 4) % 5] ^ ((column[(i + 1) % 5] << 1) | (column[(i + 1) % 5] >> 63));"
      , "      for (int j = 0; j < 25; j += 5) lanes[j + i] ^= mixed;"
      , "    }"
      , "    held = lanes[1];"
      , "    for (int i = 0; i < 24; ++i) {"
      , "      uint64_t next = lanes[moves[i]];"
      , "      lanes[moves[i]] = (held << turns[i]) | (held >> (64 - turns[i]));"
      , "      held = next;"
      , "    }"
      , "    for (int j = 0; j < 25; j += 5) {"
      , "      for (int i = 0; i < 5; ++i) column[i] = lanes[j + i];"
      , "      for (int i = 0; i < 5; ++i) lanes[j + i] ^= ~column[(i + 1) % 5] & column[(i + 2) % 5];"
      , "    }"
      , "    lanes[0] ^= rounds[round];"
      , "  }"
      , "}"
      ])
  , ("sha3_of", ["keccak", "kernel_pack"],
      [ "/* SHA3 at size bytes of output: the sponge at rate 200 - 2 * size. */"
      , "static pudu_box *pudu_sha3_of(pudu_box *message, int size) {"
      , "  pudu_text bytes = message->fields[0].text;"
      , "  uint64_t lanes[25] = {0};"
      , "  unsigned char digest[64];"
      , "  size_t rate = 200 - 2 * (size_t)size, held = 0;"
      , "  for (size_t i = 0; i < bytes.length; ++i) {"
      , "    lanes[held / 8] ^= (uint64_t)bytes.bytes[i] << (8 * (held % 8));"
      , "    if (++held == rate) { pudu_keccak(lanes); held = 0; }"
      , "  }"
      , "  lanes[held / 8] ^= UINT64_C(0x06) << (8 * (held % 8));"
      , "  lanes[(rate - 1) / 8] ^= UINT64_C(0x80) << (8 * ((rate - 1) % 8));"
      , "  pudu_keccak(lanes);"
      , "  for (int i = 0; i < size; ++i) digest[i] = (unsigned char)(lanes[i / 8] >> (8 * (i % 8)));"
      , "  return pudu_kernel_pack(digest, (size_t)size);"
      , "}"
      ])
  ]
