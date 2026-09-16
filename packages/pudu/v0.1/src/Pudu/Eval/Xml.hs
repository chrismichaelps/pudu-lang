{-| @Eval.Xml — reads XML documents into `Std.Xml` values natively. -}
module Pudu.Eval.Xml
  ( callXmlDecode
  , decodeDocument
  , unescape
  ) where

import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import qualified Data.ByteString.Unsafe as Unsafe
import Data.Char (chr, isSpace)
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Data.Word (Word8)

import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..))
import Pudu.Source (Span)

{-| `xmlDecode(source)`: the root element of a document, or `None` when this
    reader leaves the document to `Std.Xml.decode`'s own reading.

    `None` is not a verdict that the document is malformed. It is answered for
    every document this reader does not read exactly as the library does, and
    the library then reads it, so a refusal keeps the error its callers see. -}
callXmlDecode :: Span -> [Value] -> Evaluator Value
callXmlDecode spanValue arguments = case arguments of
  [StrValue source] -> pure $ case decodeDocument (Encoding.encodeUtf8 source) of
    Just tag -> VariantValue "Some" [tag]
    Nothing -> VariantValue "None" []
  _ -> abortAt (Just spanValue) "E7012" "wrong arguments for xmlDecode" Nothing

{-| The most elements one document may nest, as `Std.Xml` bounds them. -}
maxDepth :: Int
maxDepth = 512

{-| The root element of a document as a `Std.Xml.Tag` value.

    Before the root, declarations, instructions, and comments are skipped and a
    document type declaration is refused. Inside an element, comments and
    instructions are dropped, CDATA is kept as written, text that is only
    whitespace is dropped, and other text and attribute values have their
    entities decoded. Anything after the root element is not read. Every
    structural character is ASCII, so the scan works on the document's UTF-8
    bytes and decodes each name, value, and run of text once. -}
decodeDocument :: ByteString.ByteString -> Maybe Value
decodeDocument input = do
  start <- prolog 0
  let root = skipSpace start
  if root >= size then Nothing else fst <$> element root 1
 where
  size = ByteString.length input

  byteAt :: Int -> Word8
  byteAt = Unsafe.unsafeIndex input

  skipSpace position
    | position < size && isSpaceByte (byteAt position) = skipSpace (position + 1)
    | otherwise = position

  startsAt position marker = ByteString.isPrefixOf marker (ByteString.drop position input)

  {-| The position just past the first `marker` at or after `position`. -}
  pastMarker position marker =
    let (before, found) = ByteString.breakSubstring marker (ByteString.drop position input)
     in if ByteString.null found
          then Nothing
          else Just (position + ByteString.length before + ByteString.length marker)

  nameEndAt position = position + ByteString.length (ByteString.takeWhile isNameByte (ByteString.drop position input))

  bytesOf from to = ByteString.take (to - from) (ByteString.drop from input)

  textOf from to = Encoding.decodeUtf8Lenient (bytesOf from to)

  prolog position =
    let here = skipSpace position
     in if here + 1 >= size || byteAt here /= 60
          then Just here
          else case byteAt (here + 1) of
            63 -> pastMarker here closeInstruction >>= prolog
            33
              | startsAt here openComment -> pastMarker here closeComment >>= prolog
              | otherwise -> Nothing
            _ -> Just here

  element from depth
    | from >= size || byteAt from /= 60 = Nothing
    | nameEnd == nameStart = Nothing
    | otherwise = attributesAt nameEnd Seq.empty
   where
    nameStart = from + 1
    nameEnd = nameEndAt nameStart
    name = textOf nameStart nameEnd
    nameBytes = bytesOf nameStart nameEnd

    attributesAt position held
      | here >= size = Nothing
      | byteAt here == 47 =
          if here + 1 < size && byteAt (here + 1) == 62
            then Just (tagValue name held Seq.empty, here + 2)
            else Nothing
      | byteAt here == 62 = contentAt (here + 1) held Seq.empty
      | attributeEnd == here = Nothing
      | equals >= size || byteAt equals /= 61 = Nothing
      | open >= size || (byteAt open /= 34 && byteAt open /= 39) = Nothing
      | otherwise = do
          offset <- ByteString.elemIndex (byteAt open) (ByteString.drop (open + 1) input)
          let valueEnd = open + 1 + offset
              pair = TupleValue [StrValue (textOf here attributeEnd), StrValue (unescape (textOf (open + 1) valueEnd))]
          attributesAt (valueEnd + 1) (held Seq.|> pair)
     where
      here = skipSpace position
      attributeEnd = nameEndAt here
      equals = skipSpace attributeEnd
      open = skipSpace (equals + 1)

    contentAt position attributes children
      | position >= size = Nothing
      | startsAt position closeTagOpen =
          let closeEnd = nameEndAt (position + 2)
              closeAfter = skipSpace closeEnd
           in if bytesOf (position + 2) closeEnd /= nameBytes || closeAfter >= size || byteAt closeAfter /= 62
                then Nothing
                else Just (tagValue name attributes children, closeAfter + 1)
      | startsAt position openComment = do
          next <- pastMarker position closeComment
          contentAt next attributes children
      | startsAt position openCdata = do
          end <- pastMarker position closeCdata
          contentAt end attributes (children Seq.|> contentValue (textOf (position + 9) (end - 3)))
      | startsAt position openInstruction = do
          next <- pastMarker position closeInstruction
          contentAt next attributes children
      | byteAt position == 60 =
          if depth >= maxDepth
            then Nothing
            else do
              (nested, next) <- element position (depth + 1)
              contentAt next attributes (children Seq.|> VariantValue "Element" [nested])
      | otherwise =
          let textEnd = maybe size (+ position) (ByteString.elemIndex 60 (ByteString.drop position input))
              raw = textOf position textEnd
              kept = if Text.all isSpace raw then children else children Seq.|> contentValue (unescape raw)
           in contentAt textEnd attributes kept

tagValue :: Text -> Seq.Seq Value -> Seq.Seq Value -> Value
tagValue name attributes children =
  RecordValue "Tag"
    [ ("name", StrValue name)
    , ("attributes", ArrayValue attributes)
    , ("children", ArrayValue children)
    ]

contentValue :: Text -> Value
contentValue text = VariantValue "Content" [StrValue text]

{-| The five entities the format defines and numeric character references.

    An `&` whose `;` is not among the next twelve characters is kept, as is an
    entity nothing defines. A numeric reference that names no scalar value is
    dropped. -}
unescape :: Text -> Text
unescape value
  | not (Text.any (== '&') value) = value
  | otherwise = Text.concat (pieces value)
 where
  pieces remaining = case Text.break (== '&') remaining of
    (plain, rest)
      | Text.null rest -> [plain]
      | otherwise ->
          let afterAmp = Text.drop 1 rest
           in case Text.findIndex (== ';') (Text.take 12 afterAmp) of
                Just semicolon ->
                  plain : entityOf (Text.take semicolon afterAmp) : pieces (Text.drop (semicolon + 1) afterAmp)
                Nothing -> plain : Text.singleton '&' : pieces afterAmp

entityOf :: Text -> Text
entityOf named = case named of
  "lt" -> "<"
  "gt" -> ">"
  "amp" -> "&"
  "quot" -> "\""
  "apos" -> "'"
  _ -> case Text.stripPrefix "#" named of
    Nothing -> unknown
    Just reference ->
      let (base, digits) = case Text.uncons reference of
            Just (marker, rest) | marker == 'x' || marker == 'X' -> (16, rest)
            _ -> (10, reference)
       in case codeOf base digits of
            Nothing -> unknown
            Just code
              | code <= 0x10FFFF && not (code >= 0xD800 && code <= 0xDFFF) -> Text.singleton (chr (fromInteger code))
              | otherwise -> Text.empty
 where
  unknown = "&" <> named <> ";"

codeOf :: Integer -> Text -> Maybe Integer
codeOf base digits
  | Text.null digits = Nothing
  | otherwise = Text.foldl' step (Just 0) digits
 where
  step total character = do
    sofar <- total
    digit <- digitValue character
    if digit >= base then Nothing else Just (sofar * base + digit)
  digitValue character
    | character >= '0' && character <= '9' = Just (toInteger (fromEnum character - fromEnum '0'))
    | character >= 'a' && character <= 'f' = Just (toInteger (fromEnum character - fromEnum 'a' + 10))
    | character >= 'A' && character <= 'F' = Just (toInteger (fromEnum character - fromEnum 'A' + 10))
    | otherwise = Nothing

isSpaceByte :: Word8 -> Bool
isSpaceByte byte = byte == 32 || byte == 9 || byte == 10 || byte == 13

{-| A byte that may be part of a name: anything but whitespace and the
    characters that end one. -}
isNameByte :: Word8 -> Bool
isNameByte byte =
  not (isSpaceByte byte)
    && byte /= 60 && byte /= 62 && byte /= 47 && byte /= 61
    && byte /= 34 && byte /= 39 && byte /= 63 && byte /= 33

openComment, closeComment, openCdata, closeCdata, openInstruction, closeInstruction, closeTagOpen :: ByteString.ByteString
openComment = Char8.pack "<!--"
closeComment = Char8.pack "-->"
openCdata = Char8.pack "<![CDATA["
closeCdata = Char8.pack "]]>"
openInstruction = Char8.pack "<?"
closeInstruction = Char8.pack "?>"
closeTagOpen = Char8.pack "</"
