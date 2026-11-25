{-| @Backend.Runtime.Kernel.Url — a URL component percent-encoded in one pass. -}
module Pudu.Backend.Runtime.Kernel.Url (urlKernelParts) where

import Data.Text (Text)

{-| Each part: its name, the parts it needs, and its lines. -}
urlKernelParts :: [(Text, [Text], [Text])]
urlKernelParts =
  [ ("url_encode", ["text", "text_retain", "text_allocate", "memory_failure"],
      [ "/* A letter, a digit, or one of - _ . ~ stays as written. */"
      , "static int pudu_url_unreserved(unsigned char byte) {"
      , "  return (byte >= 'a' && byte <= 'z') || (byte >= 'A' && byte <= 'Z') || (byte >= '0' && byte <= '9')"
      , "    || byte == '-' || byte == '_' || byte == '.' || byte == '~';"
      , "}"
      , "/* Every other UTF-8 byte as %XX in upper-case hex; text with nothing to"
      , "   escape is the same text. */"
      , "static pudu_text pudu_url_encode(pudu_text text) {"
      , "  static const char digits[] = \"0123456789ABCDEF\";"
      , "  size_t escaped = 0;"
      , "  unsigned char *out;"
      , "  pudu_text encoded;"
      , "  for (size_t i = 0; i < text.length; ++i) escaped += !pudu_url_unreserved(text.bytes[i]);"
      , "  if (escaped == 0) return pudu_text_retain(text);"
      , "  if (escaped > (SIZE_MAX - text.length) / 2) pudu_memory_failure();"
      , "  encoded = pudu_text_allocate(text.length + 2 * escaped, &out);"
      , "  for (size_t i = 0; i < text.length; ++i) {"
      , "    unsigned char byte = text.bytes[i];"
      , "    if (pudu_url_unreserved(byte)) { *out++ = byte; continue; }"
      , "    *out++ = '%';"
      , "    *out++ = (unsigned char)digits[byte >> 4];"
      , "    *out++ = (unsigned char)digits[byte & 15];"
      , "  }"
      , "  return encoded;"
      , "}"
      ])
  ]
