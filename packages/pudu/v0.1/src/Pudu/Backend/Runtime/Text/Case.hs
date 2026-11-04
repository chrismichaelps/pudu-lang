{-| @Pudu.Backend.Runtime.Text.Case — trim and case mapping, tabled from the
    same Data.Text the evaluator calls. -}
module Pudu.Backend.Runtime.Text.Case (textCaseRuntimeParts, textCaseRuntimeDependencies) where

import Data.Char (chr, isSpace, ord)
import Data.Text (Text)
import qualified Data.Text as Text

{-| The tables are read off the linked text library rather than a Unicode
    release, so they always match whatever `Text.toUpper` the interpreter in
    this same binary runs. Text 2.1 maps each scalar on its own (no final-sigma
    context), which is what lets a per-scalar table stand in for it. -}
textCaseRuntimeParts :: [(Text, [Text])]
textCaseRuntimeParts =
  [ ("text_encode",
      [ "static size_t pudu_text_encode(uint32_t scalar, unsigned char *out) {"
      , "  if (scalar < 0x80) { out[0] = (unsigned char)scalar; return 1; }"
      , "  if (scalar < 0x800) { out[0] = (unsigned char)(0xC0 | (scalar >> 6)); out[1] = (unsigned char)(0x80 | (scalar & 0x3F)); return 2; }"
      , "  if (scalar < 0x10000) {"
      , "    out[0] = (unsigned char)(0xE0 | (scalar >> 12)); out[1] = (unsigned char)(0x80 | ((scalar >> 6) & 0x3F));"
      , "    out[2] = (unsigned char)(0x80 | (scalar & 0x3F)); return 3;"
      , "  }"
      , "  out[0] = (unsigned char)(0xF0 | (scalar >> 18)); out[1] = (unsigned char)(0x80 | ((scalar >> 12) & 0x3F));"
      , "  out[2] = (unsigned char)(0x80 | ((scalar >> 6) & 0x3F)); out[3] = (unsigned char)(0x80 | (scalar & 0x3F)); return 4;"
      , "}"
      ])
  , ("text_case_map",
      [ "/* Each row is a scalar and its replacements, zero-padded. */"
      , "typedef struct { uint32_t scalar; uint32_t into[" <> width <> "]; } pudu_case_row;"
      , "static const uint32_t *pudu_case_find(const pudu_case_row *rows, size_t count, uint32_t scalar) {"
      , "  size_t low = 0, high = count;"
      , "  while (low < high) {"
      , "    size_t middle = low + (high - low) / 2;"
      , "    if (rows[middle].scalar == scalar) return rows[middle].into;"
      , "    if (rows[middle].scalar < scalar) low = middle + 1; else high = middle;"
      , "  }"
      , "  return NULL;"
      , "}"
      , "static pudu_text pudu_text_case(pudu_text text, const pudu_case_row *rows, size_t count) {"
      , "  unsigned char scratch[4], *bytes;"
      , "  size_t size = 0, offset = 0;"
      , "  pudu_text mapped;"
      , "  while (offset < text.length) {"
      , "    size_t start = offset;"
      , "    const uint32_t *into = pudu_case_find(rows, count, pudu_text_decode(text.bytes, &offset));"
      , "    size_t grow = offset - start;"
      , "    if (into != NULL) { grow = 0; for (size_t k = 0; k < " <> width <> " && into[k] != 0; ++k) grow += pudu_text_encode(into[k], scratch); }"
      , "    if (size > SIZE_MAX - grow) pudu_memory_failure();"
      , "    size += grow;"
      , "  }"
      , "  mapped = pudu_text_allocate(size, &bytes);"
      , "  offset = 0;"
      , "  while (offset < text.length) {"
      , "    size_t start = offset;"
      , "    const uint32_t *into = pudu_case_find(rows, count, pudu_text_decode(text.bytes, &offset));"
      , "    if (into == NULL) { memcpy(bytes, text.bytes + start, offset - start); bytes += offset - start; continue; }"
      , "    for (size_t k = 0; k < " <> width <> " && into[k] != 0; ++k) bytes += pudu_text_encode(into[k], bytes);"
      , "  }"
      , "  return mapped;"
      , "}"
      ])
  , ("text_to_upper", table "pudu_case_upper" upperRows
      <> [ "static pudu_text pudu_text_to_upper(pudu_text text) {"
         , "  return pudu_text_case(text, pudu_case_upper, sizeof pudu_case_upper / sizeof pudu_case_upper[0]);"
         , "}" ])
  , ("text_to_lower", table "pudu_case_lower" lowerRows
      <> [ "static pudu_text pudu_text_to_lower(pudu_text text) {"
         , "  return pudu_text_case(text, pudu_case_lower, sizeof pudu_case_lower / sizeof pudu_case_lower[0]);"
         , "}" ])
  , ("text_trim",
      [ "/* Data.Char.isSpace over every scalar, as Text.strip uses it. */"
      , "static const uint32_t pudu_text_spaces[] = {" <> joined (map (Text.pack . show) spaceScalars) <> "};"
      , "static int pudu_text_is_space(uint32_t scalar) {"
      , "  for (size_t i = 0; i < sizeof pudu_text_spaces / sizeof pudu_text_spaces[0]; ++i) if (pudu_text_spaces[i] == scalar) return 1;"
      , "  return 0;"
      , "}"
      , "static pudu_text pudu_text_trim(pudu_text text) {"
      , "  size_t start = 0, end = text.length;"
      , "  while (start < end) {"
      , "    size_t next = start;"
      , "    if (!pudu_text_is_space(pudu_text_decode(text.bytes, &next))) break;"
      , "    start = next;"
      , "  }"
      , "  while (end > start) {"
      , "    size_t leader = end - 1, probe;"
      , "    while ((text.bytes[leader] & 0xC0) == 0x80) leader -= 1;"
      , "    probe = leader;"
      , "    if (!pudu_text_is_space(pudu_text_decode(text.bytes, &probe))) break;"
      , "    end = leader;"
      , "  }"
      , "  return pudu_text_view(text, start, end);"
      , "}"
      ])
  ]

textCaseRuntimeDependencies :: Text -> [Text]
textCaseRuntimeDependencies name = maybe [] id (lookup name
  [ ("text_encode", [])
  , ("text_case_map", ["text_decode", "text_encode", "text_allocate"])
  , ("text_to_upper", ["text_case_map"])
  , ("text_to_lower", ["text_case_map"])
  , ("text_trim", ["text_decode", "text_view"])
  ])

upperRows, lowerRows :: [(Int, [Int])]
upperRows = caseRows Text.toUpper
lowerRows = caseRows Text.toLower

caseRows :: (Text -> Text) -> [(Int, [Int])]
caseRows convert =
  [ (ord scalar, map ord into)
  | scalar <- scalars
  , let into = Text.unpack (convert (Text.singleton scalar))
  , into /= [scalar]
  ]

table :: Text -> [(Int, [Int])] -> [Text]
table name rows =
  ["static const pudu_case_row " <> name <> "[] = {"]
    <> [ "  " <> joined [row entry | entry <- chunk] <> ","
       | chunk <- chunksOf 6 rows ]
    <> ["};"]
 where
  row (scalar, into) = "{" <> Text.pack (show scalar) <> ", {" <> joined (map (Text.pack . show) (take caseWidth (into <> repeat 0))) <> "}}"

{-| The longest expansion either table needs; rows are padded to it. -}
caseWidth :: Int
caseWidth = maximum (1 : map (length . snd) (upperRows <> lowerRows))

width :: Text
width = Text.pack (show caseWidth)

spaceScalars :: [Int]
spaceScalars = [ord scalar | scalar <- scalars, isSpace scalar]

scalars :: [Char]
scalars = [chr code | code <- [0 .. 0x10FFFF], code < 0xD800 || code > 0xDFFF]

joined :: [Text] -> Text
joined = Text.intercalate ", "

chunksOf :: Int -> [a] -> [[a]]
chunksOf size items = case splitAt size items of
  (chunk, []) -> [chunk]
  (chunk, rest) -> chunk : chunksOf size rest
