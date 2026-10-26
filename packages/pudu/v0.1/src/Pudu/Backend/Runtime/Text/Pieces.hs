{-| @Pudu.Backend.Runtime.Text.Pieces — the Str methods that answer an array.
    Each piece is a view of the receiver, so only the array is new. These
    build arrays and so are emitted after the frame types, with the array
    runtime. -}
module Pudu.Backend.Runtime.Text.Pieces (textPieceRuntimeParts, textPieceRuntimeDependencies) where

import Data.Text (Text)

textPieceRuntimeParts :: [(Text, [Text])]
textPieceRuntimeParts =
  [ ("text_piece_push",
      [ "static void pudu_text_piece_push(pudu_box *array, pudu_text piece) {"
      , "  pudu_array_reserve(array, pudu_array_length(array) + 1);"
      , "  array->fields[0].items->cells[pudu_array_length(array)++].text = piece;"
      , "}"
      ])
  , ("text_split",
      [ "/* Text.splitOn, or one piece per character for an empty separator. */"
      , "static pudu_box *pudu_text_split(pudu_text text, pudu_text separator) {"
      , "  pudu_box *pieces = pudu_array_new(0);"
      , "  size_t start = 0;"
      , "  if (separator.length == 0) {"
      , "    while (start < text.length) {"
      , "      size_t next = start + pudu_text_width(text.bytes[start]);"
      , "      pudu_text_piece_push(pieces, pudu_text_view(text, start, next));"
      , "      start = next;"
      , "    }"
      , "    return pieces;"
      , "  }"
      , "  for (;;) {"
      , "    size_t found = pudu_text_find(text, separator, start);"
      , "    if (found == SIZE_MAX) break;"
      , "    pudu_text_piece_push(pieces, pudu_text_view(text, start, found));"
      , "    start = found + separator.length;"
      , "  }"
      , "  pudu_text_piece_push(pieces, pudu_text_view(text, start, text.length));"
      , "  return pieces;"
      , "}"
      ])
  , ("text_lines",
      [ "/* Text.lines: break at \\n; a final newline doesn't start another line. */"
      , "static pudu_box *pudu_text_lines(pudu_text text) {"
      , "  pudu_box *lines = pudu_array_new(0);"
      , "  size_t start = 0;"
      , "  while (start < text.length) {"
      , "    const unsigned char *newline = memchr(text.bytes + start, '\\n', text.length - start);"
      , "    size_t end = newline == NULL ? text.length : (size_t)(newline - text.bytes);"
      , "    pudu_text_piece_push(lines, pudu_text_view(text, start, end));"
      , "    start = end + 1;"
      , "  }"
      , "  return lines;"
      , "}"
      ])
  , ("text_chars",
      [ "static pudu_box *pudu_text_chars(pudu_text text) {"
      , "  pudu_box *chars = pudu_array_new(0);"
      , "  size_t offset = 0;"
      , "  while (offset < text.length) {"
      , "    uint32_t scalar = pudu_text_decode(text.bytes, &offset);"
      , "    pudu_array_reserve(chars, pudu_array_length(chars) + 1);"
      , "    chars->fields[0].items->cells[pudu_array_length(chars)++].character = scalar;"
      , "  }"
      , "  return chars;"
      , "}"
      ])
  ]

textPieceRuntimeDependencies :: Text -> [Text]
textPieceRuntimeDependencies name = maybe [] id (lookup name
  [ ("text_piece_push", ["array", "array_reserve"])
  , ("text_split", ["text_piece_push", "text_find", "text_view", "text_width"])
  , ("text_lines", ["text_piece_push", "text_view"])
  , ("text_chars", ["array", "array_reserve", "text_decode"])
  ])
