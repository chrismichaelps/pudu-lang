{-| @Pudu.Eval.UrlEncode — `urlEncodeComponent(text)`: each UTF-8 byte that is
    not a letter, a digit, or one of `- _ . ~` written as `%XX` in upper-case
    hex, as `Std.Url.encodeComponent` answers. -}
module Pudu.Eval.UrlEncode (callUrlEncode) where

import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Builder as Builder
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Text (Text)
import qualified Data.Text.Encoding as Encoding
import Data.Word (Word8)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..))
import Pudu.Source (Span)

callUrlEncode :: Span -> [Value] -> Evaluator Value
callUrlEncode spanValue arguments = case arguments of
  [StrValue text] -> pure (StrValue (encodeComponent text))
  _ -> abortAt (Just spanValue) "E7012" "wrong arguments for urlEncodeComponent" Nothing

encodeComponent :: Text -> Text
encodeComponent text
  | ByteString.all unreserved bytes = text
  | otherwise = Encoding.decodeUtf8 (LazyByteString.toStrict (Builder.toLazyByteString (ByteString.foldr (\byte rest -> piece byte <> rest) mempty bytes)))
 where
  bytes = Encoding.encodeUtf8 text
  piece byte
    | unreserved byte = Builder.word8 byte
    | otherwise = Builder.word8 37 <> Builder.word8 (digit (byte `div` 16)) <> Builder.word8 (digit (byte `mod` 16))
  digit value = if value < 10 then 48 + value else 55 + value

unreserved :: Word8 -> Bool
unreserved byte =
  (byte >= 97 && byte <= 122) || (byte >= 65 && byte <= 90) || (byte >= 48 && byte <= 57)
    || byte == 45 || byte == 95 || byte == 46 || byte == 126
