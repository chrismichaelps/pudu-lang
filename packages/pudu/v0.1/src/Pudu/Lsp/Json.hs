{-| @Program.Lsp.Json.Module — the JSON the language server speaks -}
module Pudu.Lsp.Json
  ( Json (..)
  , array
  , encode
  , field
  , lookupField
  , number
  , object
  , parse
  , text
  , textOf
  , integerOf
  ) where

import Data.Char (chr, isDigit, isHexDigit, digitToInt)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc.Json (escapeJson)

{-| @Lsp.Json.Value — a JSON document.

    Written here rather than taken from a library for the reason [[Doc Json]]
    already gives: the protocol's shape is fixed and small, and a dependency
    would put this project's contract with every editor on somebody else's
    release schedule. The encoder that already existed only wrote JSON; a server
    has to read it too, which is the half this module adds. -}
data Json
  = JsonNull
  | JsonBool !Bool
  | JsonNumber !Double
  | JsonText !Text
  | JsonArray ![Json]
  | JsonObject ![(Text, Json)]
  deriving stock (Eq, Show)

object :: [(Text, Json)] -> Json
object = JsonObject

array :: [Json] -> Json
array = JsonArray

text :: Text -> Json
text = JsonText

number :: Int -> Json
number = JsonNumber . fromIntegral

field :: Text -> Json -> (Text, Json)
field = (,)

{-| A member of an object, or nothing when the value is not an object or has no
    such member. Both are the same answer to a caller reading an optional part
    of a request. -}
lookupField :: Text -> Json -> Maybe Json
lookupField name candidate = case candidate of
  JsonObject entries -> lookup name entries
  _ -> Nothing

textOf :: Json -> Maybe Text
textOf candidate = case candidate of
  JsonText content -> Just content
  _ -> Nothing

{-| A whole number, when the value is one.

    JSON has one numeric type and the protocol uses it for positions, which are
    whole. A fractional position is malformed rather than rounded, because
    rounding one would silently point at a different character. -}
integerOf :: Json -> Maybe Int
integerOf candidate = case candidate of
  JsonNumber content
    | content == fromIntegral rounded -> Just rounded
   where
    rounded = round content
  _ -> Nothing

encode :: Json -> Text
encode candidate = case candidate of
  JsonNull -> "null"
  JsonBool flag -> if flag then "true" else "false"
  JsonNumber content -> encodeNumber content
  JsonText content -> "\"" <> escapeJson content <> "\""
  JsonArray members -> "[" <> Text.intercalate "," (map encode members) <> "]"
  JsonObject members ->
    "{" <> Text.intercalate "," [encode (JsonText name) <> ":" <> encode member | (name, member) <- members] <> "}"

{-| Whole numbers render without a fractional part, because a position written
    `3.0` is legal JSON that some clients read as a float and then reject. -}
encodeNumber :: Double -> Text
encodeNumber content
  | content == fromIntegral rounded = Text.pack (show rounded)
  | otherwise = Text.pack (show content)
 where
  rounded = round content :: Int

{-| Parse a complete JSON document, or nothing when the text is not one.

    Trailing text after a complete value is a failure rather than ignored: a
    message body that carries more than it declared is a framing bug, and
    accepting it would hide one. -}
parse :: Text -> Maybe Json
parse source = case parseValue (skipSpace source) of
  Just (parsed, rest) | Text.null (skipSpace rest) -> Just parsed
  _ -> Nothing

type Parsed = Maybe (Json, Text)

parseValue :: Text -> Parsed
parseValue source = case Text.uncons source of
  Nothing -> Nothing
  Just (scalar, rest) -> case scalar of
    '{' -> parseMembers False (skipSpace rest) []
    '[' -> parseElements False (skipSpace rest) []
    '"' -> do
      (content, remaining) <- quoted rest Text.empty
      pure (JsonText content, remaining)
    't' -> literal "true" (JsonBool True) source
    'f' -> literal "false" (JsonBool False) source
    'n' -> literal "null" JsonNull source
    _ | scalar == '-' || isDigit scalar -> numeric source
    _ -> Nothing

literal :: Text -> Json -> Text -> Parsed
literal spelling result source = do
  rest <- Text.stripPrefix spelling source
  pure (result, rest)

{-| Read an object's members. `required` says a member must follow, which is
    true after a comma and false only at the opening brace — so a trailing comma
    is a failure rather than a silently accepted extra. -}
parseMembers :: Bool -> Text -> [(Text, Json)] -> Parsed
parseMembers required source accumulated = case Text.uncons source of
  Just ('}', rest) | not required -> Just (JsonObject (reverse accumulated), rest)
  _ -> do
    afterQuote <- Text.stripPrefix "\"" source
    (name, afterName) <- quoted afterQuote Text.empty
    afterColon <- Text.stripPrefix ":" (skipSpace afterName)
    (member, afterMember) <- parseValue (skipSpace afterColon)
    let rest = skipSpace afterMember
    case Text.uncons rest of
      Just (',', more) -> parseMembers True (skipSpace more) ((name, member) : accumulated)
      Just ('}', more) -> Just (JsonObject (reverse ((name, member) : accumulated)), more)
      _ -> Nothing

parseElements :: Bool -> Text -> [Json] -> Parsed
parseElements required source accumulated = case Text.uncons source of
  Just (']', rest) | not required -> Just (JsonArray (reverse accumulated), rest)
  _ -> do
    (member, afterMember) <- parseValue source
    let rest = skipSpace afterMember
    case Text.uncons rest of
      Just (',', more) -> parseElements True (skipSpace more) (member : accumulated)
      Just (']', more) -> Just (JsonArray (reverse (member : accumulated)), more)
      _ -> Nothing

{-| Read a string body, the opening quote already consumed. -}
quoted :: Text -> Text -> Maybe (Text, Text)
quoted source accumulated = case Text.uncons source of
  Nothing -> Nothing
  Just ('"', rest) -> Just (accumulated, rest)
  Just ('\\', rest) -> do
    (decoded, remaining) <- escaped rest
    quoted remaining (accumulated <> decoded)
  Just (scalar, rest) -> quoted rest (Text.snoc accumulated scalar)

escaped :: Text -> Maybe (Text, Text)
escaped source = case Text.uncons source of
  Nothing -> Nothing
  Just (scalar, rest) -> case scalar of
    '"' -> Just ("\"", rest)
    '\\' -> Just ("\\", rest)
    '/' -> Just ("/", rest)
    'b' -> Just ("\b", rest)
    'f' -> Just ("\f", rest)
    'n' -> Just ("\n", rest)
    'r' -> Just ("\r", rest)
    't' -> Just ("\t", rest)
    'u' -> unicodeEscape rest
    _ -> Nothing

{-| Decode `\uXXXX`, joining a surrogate pair when one follows.

    A client sending an astral scalar sends it as a pair, and treating the two
    halves as separate scalars would produce text that is not what was sent. -}
unicodeEscape :: Text -> Maybe (Text, Text)
unicodeEscape source = do
  (leading, afterLeading) <- hexQuad source
  if leading >= 0xD800 && leading <= 0xDBFF
    then case Text.stripPrefix "\\u" afterLeading of
      Just afterMarker -> do
        (trailing, afterTrailing) <- hexQuad afterMarker
        if trailing >= 0xDC00 && trailing <= 0xDFFF
          then
            let combined =
                  0x10000 + (leading - 0xD800) * 0x400 + (trailing - 0xDC00)
             in Just (Text.singleton (chr combined), afterTrailing)
          else Nothing
      Nothing -> Nothing
    else
      if leading >= 0xDC00 && leading <= 0xDFFF
        then Nothing
        else Just (Text.singleton (chr leading), afterLeading)

hexQuad :: Text -> Maybe (Int, Text)
hexQuad source
  | Text.length digits == 4, Text.all isHexDigit digits =
      Just (Text.foldl' step 0 digits, Text.drop 4 source)
  | otherwise = Nothing
 where
  digits = Text.take 4 source
  step accumulated scalar = accumulated * 16 + digitToInt scalar

numeric :: Text -> Parsed
numeric source
  | Text.null body = Nothing
  | otherwise = do
      parsed <- readDouble (Text.unpack body)
      pure (JsonNumber parsed, Text.drop (Text.length body) source)
 where
  body = Text.takeWhile numericScalar source
  numericScalar scalar =
    isDigit scalar || scalar `elem` ("-+.eE" :: String)

{-| Read a JSON number without the host's `read`, which accepts spellings JSON
    does not and rejects some it does. -}
readDouble :: String -> Maybe Double
readDouble input = case input of
  '-' : rest -> negate <$> unsigned rest
  _ -> unsigned input
 where
  unsigned candidate = do
    let (whole, afterWhole) = span isDigit candidate
    _ <- if null whole then Nothing else Just ()
    (fraction, afterFraction) <- case afterWhole of
      '.' : rest ->
        let (digits, remaining) = span isDigit rest
         in if null digits then Nothing else Just (digits, remaining)
      _ -> Just ("", afterWhole)
    (exponent', afterExponent) <- case afterFraction of
      marker : rest
        | marker == 'e' || marker == 'E' ->
            let (sign, afterSign) = case rest of
                  '+' : more -> (1 :: Int, more)
                  '-' : more -> (-1, more)
                  _ -> (1, rest)
                (digits, remaining) = span isDigit afterSign
             in if null digits
                  then Nothing
                  else Just (sign * foldl (\a d -> a * 10 + digitToInt d) 0 digits, remaining)
      _ -> Just (0, afterFraction)
    if not (null afterExponent)
      then Nothing
      else
        let mantissa =
              foldl (\a d -> a * 10 + fromIntegral (digitToInt d)) 0 (whole <> fraction)
            scale = exponent' - length fraction
         in Just (mantissa * (10 ** fromIntegral scale))

skipSpace :: Text -> Text
skipSpace = Text.dropWhile (`elem` (" \t\r\n" :: String))
