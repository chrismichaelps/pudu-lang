{-| @Program.Lsp.Protocol.Module — frames and shapes the wire carries -}
module Pudu.Lsp.Protocol
  ( Message (..)
  , Position (..)
  , Range (..)
  , errorResponse
  , frame
  , notification
  , positionOf
  , rangeJson
  , readMessage
  , response
  , positionJson
  ) where

import qualified Data.ByteString as ByteString
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Data.Word (Word8)
import Pudu.Lsp.Json (Json (..), encode, integerOf, lookupField, parse, textOf)
import System.IO (Handle, hIsEOF)

{-| @Lsp.Protocol.Message — one message read off the wire.

    A request carries an identifier and expects an answer; a notification does
    not and must never be answered. The two are separated here rather than
    checked later, because replying to a notification is the one protocol error
    a client cannot recover from — it will wait for a response to a request it
    never made. -}
data Message
  = Request !Json !Text !Json
  | Notification !Text !Json
  deriving stock (Eq, Show)

{-| @Lsp.Protocol.Position — a zero-based line and UTF-16 offset within it.

    The protocol counts a line's offset in UTF-16 code units, not scalars and
    not bytes, which matters the moment a file holds an emoji: an editor's
    cursor after one is at offset 2. Converting is the server's job and it is
    done at the edges, so nothing inside the compiler has to know. -}
data Position = Position
  { positionLine :: !Int
  , positionCharacter :: !Int
  }
  deriving stock (Eq, Ord, Show)

data Range = Range
  { rangeStart :: !Position
  , rangeEnd :: !Position
  }
  deriving stock (Eq, Show)

positionJson :: Position -> Json
positionJson value =
  JsonObject
    [ ("line", JsonNumber (fromIntegral (positionLine value)))
    , ("character", JsonNumber (fromIntegral (positionCharacter value)))
    ]

rangeJson :: Range -> Json
rangeJson value =
  JsonObject
    [ ("start", positionJson (rangeStart value))
    , ("end", positionJson (rangeEnd value))
    ]

positionOf :: Json -> Maybe Position
positionOf value = do
  line <- lookupField "line" value >>= integerOf
  character <- lookupField "character" value >>= integerOf
  pure (Position line character)

{-| Read one message, or nothing when the input ends.

    The header block is read line by line and only `Content-Length` is acted
    on: `Content-Type` is permitted by the protocol and says nothing this server
    needs, and an unknown header must be skipped rather than refused so a newer
    client can still talk to an older server.

    Everything here is bytes. `Content-Length` counts UTF-8 bytes, and reading
    that many *characters* instead would desynchronise the stream the first time
    a client sent a non-ASCII identifier — after which every later message is
    read from the wrong offset. -}
readMessage :: Handle -> IO (Maybe Message)
readMessage handle = do
  headers <- readHeaders handle []
  case headers >>= contentLength of
    Nothing -> pure Nothing
    Just size -> do
      body <- ByteString.hGet handle size
      pure (parse (Encoding.decodeUtf8Lenient body) >>= decodeMessage)

readHeaders :: Handle -> [Text] -> IO (Maybe [Text])
readHeaders handle accumulated = do
  line <- readLine handle
  case line of
    Nothing -> pure (if null accumulated then Nothing else Just (reverse accumulated))
    Just content
      | Text.null (Text.strip content) -> pure (Just (reverse accumulated))
      | otherwise -> readHeaders handle (content : accumulated)

contentLength :: [Text] -> Maybe Int
contentLength headers = case [value | header <- headers, Just value <- [lengthOf header]] of
  size : _ -> Just size
  [] -> Nothing
 where
  lengthOf header = do
    rest <- Text.stripPrefix "content-length:" (Text.toLower header)
    readDigits (Text.strip rest)

readDigits :: Text -> Maybe Int
readDigits content
  | Text.null content = Nothing
  | Text.all (\scalar -> scalar >= '0' && scalar <= '9') content =
      Just (Text.foldl' (\total scalar -> total * 10 + fromEnum scalar - fromEnum '0') 0 content)
  | otherwise = Nothing

{-| Read one header line, stopping at the newline and dropping a carriage
    return.

    A header is ASCII, so reading it byte by byte is reading it correctly. The
    protocol specifies CRLF; a client that sends a bare LF is still understood
    rather than hung up on. -}
readLine :: Handle -> IO (Maybe Text)
readLine handle = go []
 where
  go accumulated = do
    finished <- hIsEOF handle
    if finished
      then pure (if null accumulated then Nothing else Just (render accumulated))
      else do
        byte <- ByteString.hGet handle 1
        case ByteString.uncons byte of
          Nothing -> pure (if null accumulated then Nothing else Just (render accumulated))
          Just (value, _)
            | value == newlineByte -> pure (Just (render accumulated))
            | otherwise -> go (value : accumulated)
  render = Text.dropWhileEnd (== '\r') . Encoding.decodeUtf8Lenient . ByteString.pack . reverse

newlineByte :: Word8
newlineByte = 10

decodeMessage :: Json -> Maybe Message
decodeMessage value = do
  method <- lookupField "method" value >>= textOf
  let parameters = maybe (JsonObject []) id (lookupField "params" value)
  pure $ case lookupField "id" value of
    Just identity -> Request identity method parameters
    Nothing -> Notification method parameters

{-| Wrap a body in the header block the protocol requires.

    The length counts what the transport will carry. This server writes and
    reads text through a handle whose encoding is set to UTF-8 by the caller,
    and the count here is of UTF-8 bytes, which is what `Content-Length`
    means. -}
frame :: Text -> Text
frame body =
  "Content-Length: " <> Text.pack (show (utf8Length body)) <> "\r\n\r\n" <> body

{-| The byte length of text once encoded as UTF-8, counted without building the
    encoding. Getting this wrong by even one byte desynchronises the stream for
    every message after it. -}
utf8Length :: Text -> Int
utf8Length = Text.foldl' (\total scalar -> total + width (fromEnum scalar)) 0
 where
  width point
    | point < 0x80 = 1
    | point < 0x800 = 2
    | point < 0x10000 = 3
    | otherwise = 4

response :: Json -> Json -> Text
response identity result =
  encode
    (JsonObject [("jsonrpc", JsonText "2.0"), ("id", identity), ("result", result)])

errorResponse :: Json -> Int -> Text -> Text
errorResponse identity code message =
  encode
    ( JsonObject
        [ ("jsonrpc", JsonText "2.0")
        , ("id", identity)
        , ( "error"
          , JsonObject
              [("code", JsonNumber (fromIntegral code)), ("message", JsonText message)]
          )
        ]
    )

notification :: Text -> Json -> Text
notification method parameters =
  encode
    ( JsonObject
        [ ("jsonrpc", JsonText "2.0")
        , ("method", JsonText method)
        , ("params", parameters)
        ]
    )
