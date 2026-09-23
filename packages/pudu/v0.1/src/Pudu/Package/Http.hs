{-| @Package.Http — HTTP/1.1 requests to a package registry

    `send` makes one request on a new connection and reads the whole response.
    `https` goes through `Eval.Tls`, which verifies the certificate chain
    against the system store and the host name asked for. Plain `http` is
    accepted only for a loopback host. Each connection, write, and read has
    `timeoutMillis`; a response body longer than `responseLimit` is refused.
    Bodies are read by `Content-Length`, by chunked transfer coding, or to the
    end of the connection. -}
module Pudu.Package.Http
  ( Request (..)
  , Response (..)
  , request
  , send
  , header
  , responseLimit
  , timeoutMillis
  , Url (..)
  , parseUrl
  ) where

import Control.Exception (IOException, SomeException, bracket, try)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import Data.Char (isDigit, isHexDigit, toLower)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Network.Socket as Net
import qualified Network.Socket.ByteString as NetBytes
import Pudu.Eval.Io (IoOutcome (..))
import Pudu.Eval.Tls (closeTlsStore, newTlsStore, receiveTlsWithin, secureConnectWithin, sendTlsWithin)
import qualified System.Timeout as Timeout

data Request = Request
  { requestMethod :: !ByteString.ByteString
  , requestUrl :: !Text
  , requestHeaders :: ![(ByteString.ByteString, ByteString.ByteString)]
  , requestBody :: !ByteString.ByteString
  }

data Response = Response
  { responseStatus :: !Int
  , responseHeaders :: ![(ByteString.ByteString, ByteString.ByteString)]
  , responseBody :: !ByteString.ByteString
  }

{-| Largest response body accepted, in bytes: 256 MiB. -}
responseLimit :: Int
responseLimit = 268435456

{-| Budget for connecting and for each write and read, in milliseconds. -}
timeoutMillis :: Integer
timeoutMillis = 30000

request :: ByteString.ByteString -> Text -> Request
request method url = Request method url [] ByteString.empty

{-| A header of a response, by case-insensitive name. -}
header :: ByteString.ByteString -> Response -> Maybe ByteString.ByteString
header name response = lookup (Char8.map toLower name) [(Char8.map toLower k, v) | (k, v) <- responseHeaders response]

data Url = Url
  { urlSecure :: !Bool
  , urlHost :: !Text
  , urlPort :: !Int
  , urlTarget :: !Text
  }
  deriving stock (Eq, Show)

{-| Read `http://host[:port]/path` or `https://…`. -}
parseUrl :: Text -> Either Text Url
parseUrl url = do
  (secure, rest) <- case (Text.stripPrefix "https://" url, Text.stripPrefix "http://" url) of
    (Just after, _) -> Right (True, after)
    (_, Just after) -> Right (False, after)
    _ -> Left (url <> " is not an http or https address")
  let (authority, path) = Text.break (== '/') rest
      (host, portText) = case Text.breakOnEnd ":" authority of
        ("", _) -> (authority, "")
        (before, after) -> (Text.dropEnd 1 before, after)
  port <-
    if Text.null portText
      then Right (if secure then 443 else 80)
      else
        if Text.all isDigit portText
          then Right (read (Text.unpack portText))
          else Left (url <> " has an invalid port")
  if Text.null host then Left (url <> " names no host") else Right (Url secure host port (if Text.null path then "/" else path))

loopback :: Text -> Bool
loopback host = host `elem` ["localhost", "127.0.0.1", "[::1]", "::1"]

{-| A connection as the bytes it moves. `receive` answers the empty string at the end. -}
data Transport = Transport
  { transportSend :: ByteString.ByteString -> IO (Either Text ())
  , transportReceive :: IO (Either Text ByteString.ByteString)
  }

send :: Request -> IO (Either Text Response)
send given = case parseUrl (requestUrl given) of
  Left problem -> pure (Left problem)
  Right url
    | not (urlSecure url) && not (loopback (urlHost url)) ->
        pure (Left (requestUrl given <> " is plain HTTP; a registry is reached over HTTPS unless it is on this machine"))
    | urlSecure url -> overTls url
    | otherwise -> overSocket url
 where
  overTls url =
    bracket newTlsStore closeTlsStore $ \store -> do
      opened <- secureConnectWithin store (urlHost url) (urlPort url) timeoutMillis
      case opened of
        IoFailed problem -> pure (Left ("cannot connect to " <> urlHost url <> ": " <> problem))
        IoDone connection ->
          exchange url
            Transport
              { transportSend = \bytes -> outcome <$> sendTlsWithin store connection bytes timeoutMillis
              , transportReceive = fmap (maybe ByteString.empty id) . outcome <$> receiveTlsWithin store connection 65536 timeoutMillis
              }
  overSocket url = do
    let hints = Net.defaultHints{Net.addrSocketType = Net.Stream}
    found <- try (Net.getAddrInfo (Just hints) (Just (Text.unpack (Text.dropAround (`elem` ("[]" :: String)) (urlHost url)))) (Just (show (urlPort url)))) :: IO (Either IOException [Net.AddrInfo])
    case found of
      Left problem -> pure (Left ("cannot resolve " <> urlHost url <> ": " <> Text.pack (show problem)))
      Right [] -> pure (Left ("no address for " <> urlHost url))
      Right (address : _) -> do
        ran <- try . bracket (Net.openSocket address) Net.close $ \socket -> do
          connected <- Timeout.timeout (micro timeoutMillis) (Net.connect socket (Net.addrAddress address))
          case connected of
            Nothing -> pure (Left ("cannot connect to " <> urlHost url <> ": timed out"))
            Just () ->
              exchange url
                Transport
                  { transportSend = \bytes -> timed (NetBytes.sendAll socket bytes)
                  , transportReceive = timed (NetBytes.recv socket 65536)
                  }
        pure $ case ran of
          Left problem -> Left ("cannot reach " <> urlHost url <> ": " <> Text.pack (show (problem :: SomeException)))
          Right result -> result
  outcome value = case value of
    IoDone result -> Right result
    IoFailed problem -> Left problem
  timed action = do
    done <- Timeout.timeout (micro timeoutMillis) action
    pure (maybe (Left "timed out") Right done)
  micro millis = fromIntegral (millis * 1000)
  exchange url transport = do
    let hostHeader = urlHost url <> (if urlPort url `elem` [80, 443] then "" else ":" <> Text.pack (show (urlPort url)))
        lines' =
          [requestMethod given <> " " <> encode (urlTarget url) <> " HTTP/1.1", "Host: " <> encode hostHeader, "Connection: close", "User-Agent: pudu"]
            <> [k <> ": " <> v | (k, v) <- requestHeaders given]
            <> ["Content-Length: " <> Char8.pack (show (ByteString.length (requestBody given))) | not (ByteString.null (requestBody given)) || requestMethod given `elem` ["POST", "PUT", "PATCH"]]
        head' = ByteString.intercalate "\r\n" lines' <> "\r\n\r\n"
    sent <- transportSend transport (head' <> requestBody given)
    case sent of
      Left problem -> pure (Left ("cannot send to " <> urlHost url <> ": " <> problem))
      Right () -> readResponse transport
  encode = TextEncoding.encodeUtf8

readResponse :: Transport -> IO (Either Text Response)
readResponse transport = go ByteString.empty
 where
  go buffered = case ByteString.breakSubstring "\r\n\r\n" buffered of
    (head', rest)
      | not (ByteString.null rest) -> parseHead head' (ByteString.drop 4 rest)
      | ByteString.length buffered > 65536 -> pure (Left "the response head is longer than 64 KiB")
      | otherwise -> do
          more <- transportReceive transport
          case more of
            Left problem -> pure (Left problem)
            Right chunk
              | ByteString.null chunk -> pure (Left "the connection closed before the response head ended")
              | otherwise -> go (buffered <> chunk)
  parseHead head' initial = case Char8.lines (Char8.filter (/= '\r') head') of
    [] -> pure (Left "the response has no status line")
    status : fields -> case Char8.words status of
      _ : code : _ | Char8.all isDigit code -> do
        let headers = [(Char8.strip k, Char8.strip (Char8.drop 1 v)) | line <- fields, let (k, v) = Char8.break (== ':') line, not (ByteString.null v)]
            lookupHeader name = lookup name [(Char8.map toLower k, v) | (k, v) <- headers]
        body <- case (lookupHeader "transfer-encoding", lookupHeader "content-length") of
          (Just coding, _) | "chunked" `ByteString.isInfixOf` Char8.map toLower coding -> dechunk initial
          (_, Just size) | Char8.all isDigit size -> exactly (read (Char8.unpack size)) initial
          _ -> toEnd initial
        pure (Response (read (Char8.unpack code)) headers <$> body)
      _ -> pure (Left "the response has no status code")
  receive = transportReceive transport
  exactly size buffered
    | size > responseLimit = pure (Left "the response is larger than the limit")
    | ByteString.length buffered >= size = pure (Right (ByteString.take size buffered))
    | otherwise = do
        more <- receive
        case more of
          Left problem -> pure (Left problem)
          Right chunk
            | ByteString.null chunk -> pure (Left "the connection closed before the response body ended")
            | otherwise -> exactly size (buffered <> chunk)
  toEnd buffered
    | ByteString.length buffered > responseLimit = pure (Left "the response is larger than the limit")
    | otherwise = do
        more <- receive
        case more of
          Left problem -> pure (Left problem)
          Right chunk
            | ByteString.null chunk -> pure (Right buffered)
            | otherwise -> toEnd (buffered <> chunk)
  dechunk = chunks []
  chunks acc buffered = case ByteString.breakSubstring "\r\n" buffered of
    (line, rest)
      | ByteString.null rest -> refill (chunks acc) buffered
      | otherwise -> do
          let sizeText = Char8.takeWhile isHexDigit line
              size = if ByteString.null sizeText then -1 else hexValue sizeText
              after = ByteString.drop 2 rest
          step size after
   where
    step size after
      | size < 0 = pure (Left "a chunk has no size")
      | size == 0 = pure (Right (ByteString.concat (reverse acc)))
      | sum (map ByteString.length acc) + size > responseLimit = pure (Left "the response is larger than the limit")
      | ByteString.length after >= size + 2 = chunks (ByteString.take size after : acc) (ByteString.drop (size + 2) after)
      | otherwise = refill (chunks acc) buffered
  refill continue buffered = do
    more <- receive
    case more of
      Left problem -> pure (Left problem)
      Right chunk
        | ByteString.null chunk -> pure (Left "the connection closed inside a chunked body")
        | otherwise -> continue (buffered <> chunk)
  hexValue = Char8.foldl' (\n c -> n * 16 + digit c) 0
  digit c
    | isDigit c = fromEnum c - fromEnum '0'
    | c >= 'a' && c <= 'f' = fromEnum c - fromEnum 'a' + 10
    | otherwise = fromEnum c - fromEnum 'A' + 10
