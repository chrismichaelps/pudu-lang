{-| @Backend.Runtime.Kernel.Blake2 — unkeyed BLAKE2b. -}
module Pudu.Backend.Runtime.Kernel.Blake2 (blake2KernelParts) where

import Data.Text (Text)

{-| Each part: its name, the parts it needs, and its lines. -}
blake2KernelParts :: [(Text, [Text], [Text])]
blake2KernelParts =
  [ ("blake2b", ["rotr64", "kernel_word"],
      [ "/* One BLAKE2b compression: the block, the bytes fed so far, and whether it"
      , "   is the last. Without a block it sets the starting state. */"
      , "static void pudu_blake2b_block(uint64_t *state, const unsigned char *block, uint64_t fed, int last) {"
      , "  static const uint64_t start[8] = { UINT64_C(0x6a09e667f3bcc908), UINT64_C(0xbb67ae8584caa73b), UINT64_C(0x3c6ef372fe94f82b), UINT64_C(0xa54ff53a5f1d36f1), UINT64_C(0x510e527fade682d1), UINT64_C(0x9b05688c2b3e6c1f), UINT64_C(0x1f83d9abfb41bd6b), UINT64_C(0x5be0cd19137e2179) };"
      , "  static const unsigned char order[10][16] = {"
      , "    {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}, {14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3},"
      , "    {11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4}, {7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8},"
      , "    {9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13}, {2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9},"
      , "    {12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11}, {13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10},"
      , "    {6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5}, {10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0} };"
      , "  static const unsigned char lines[8][4] = { {0, 4, 8, 12}, {1, 5, 9, 13}, {2, 6, 10, 14}, {3, 7, 11, 15}, {0, 5, 10, 15}, {1, 6, 11, 12}, {2, 7, 8, 13}, {3, 4, 9, 14} };"
      , "  uint64_t v[16], words[16];"
      , "  if (block == NULL) { memcpy(state, start, sizeof start); return; }"
      , "  memcpy(v, state, 8 * sizeof v[0]);"
      , "  memcpy(v + 8, start, sizeof start);"
      , "  v[12] ^= fed;"
      , "  if (last) v[14] = ~v[14];"
      , "  for (int i = 0; i < 16; ++i) words[i] = pudu_kernel_word(block + 8 * i, 8);"
      , "  for (int round = 0; round < 12; ++round)"
      , "    for (int line = 0; line < 8; ++line) {"
      , "      const unsigned char *at = lines[line], *picked = order[round % 10];"
      , "      v[at[0]] += v[at[1]] + words[picked[2 * line]];"
      , "      v[at[3]] = pudu_rotr64(v[at[3]] ^ v[at[0]], 32);"
      , "      v[at[2]] += v[at[3]];"
      , "      v[at[1]] = pudu_rotr64(v[at[1]] ^ v[at[2]], 24);"
      , "      v[at[0]] += v[at[1]] + words[picked[2 * line + 1]];"
      , "      v[at[3]] = pudu_rotr64(v[at[3]] ^ v[at[0]], 16);"
      , "      v[at[2]] += v[at[3]];"
      , "      v[at[1]] = pudu_rotr64(v[at[1]] ^ v[at[2]], 63);"
      , "    }"
      , "  for (int i = 0; i < 8; ++i) state[i] ^= v[i] ^ v[i + 8];"
      , "}"
      ])
  , ("blake2b_of", ["blake2b", "kernel_pack"],
      [ "/* Unkeyed BLAKE2b at size bytes of output. */"
      , "static pudu_box *pudu_blake2b_of(pudu_box *message, int size) {"
      , "  pudu_text bytes = message->fields[0].text;"
      , "  uint64_t state[8];"
      , "  unsigned char block[128] = {0}, digest[64];"
      , "  size_t at = 0;"
      , "  pudu_blake2b_block(state, NULL, 0, 0);"
      , "  state[0] ^= UINT64_C(0x01010000) ^ (uint64_t)size;"
      , "  while (bytes.length - at > 128) {"
      , "    at += 128;"
      , "    pudu_blake2b_block(state, bytes.bytes + at - 128, (uint64_t)at, 0);"
      , "  }"
      , "  if (bytes.length != at) memcpy(block, bytes.bytes + at, bytes.length - at);"
      , "  pudu_blake2b_block(state, block, (uint64_t)bytes.length, 1);"
      , "  for (int i = 0; i < size; ++i) digest[i] = (unsigned char)(state[i / 8] >> (8 * (i % 8)));"
      , "  return pudu_kernel_pack(digest, (size_t)size);"
      , "}"
      ])
  ]
