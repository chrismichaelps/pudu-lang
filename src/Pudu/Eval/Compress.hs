{-| @Eval.Compress — bounded gzip conversion through zlib's incremental API. -}
module Pudu.Eval.Compress
  ( compressGzip
  , decompressGzip
  ) where

import qualified Codec.Compression.Zlib.Internal as Zlib
import Control.Exception (SomeAsyncException, SomeException, fromException, tryJust)
import qualified Data.ByteString as Bytes
import qualified Data.Text as Text
import Pudu.Eval.Io (IoOutcome (..))

compressGzip :: Bytes.ByteString -> Integer -> Integer -> IO (IoOutcome Bytes.ByteString)
compressGzip input level chunkSize
  | level < 0 || level > 9 = pure (IoFailed "invalid compression level")
  | otherwise = synchronous $ encode input [] (Zlib.compressIO Zlib.gzipFormat parameters)
 where
  parameters = Zlib.defaultCompressParams
    { Zlib.compressLevel = Zlib.compressionLevel (fromInteger level)
    , Zlib.compressBufferSize = fromInteger (max 1024 (min 65535 chunkSize))
    }
  encode remaining chunks stream = case stream of
    Zlib.CompressInputRequired next -> do
      let (piece, rest) = Bytes.splitAt 32768 remaining
      next piece >>= encode rest chunks
    Zlib.CompressOutputAvailable piece next -> next >>= encode remaining (piece : chunks)
    Zlib.CompressStreamEnd -> pure (IoDone (Bytes.concat (reverse chunks)))

{-| Check the budget before retaining each output chunk. The inflater's own
    output buffer is fixed-size, independent of the advertised gzip ISIZE. -}
decompressGzip :: Bytes.ByteString -> Integer -> IO (IoOutcome Bytes.ByteString)
decompressGzip input limit
  | limit < 0 = pure (IoFailed "negative decompression limit")
  | otherwise = synchronous $ decode input False 0 [] (Zlib.decompressIO Zlib.gzipFormat parameters)
 where
  parameters = Zlib.defaultDecompressParams
    { Zlib.decompressBufferSize = 32768
    , Zlib.decompressAllMembers = False
    }
  decode remaining ended total chunks stream = case stream of
    Zlib.DecompressInputRequired next
      | ended -> pure (IoFailed "truncated gzip stream")
      | otherwise -> do
          let (piece, rest) = Bytes.splitAt 32768 remaining
          next piece >>= decode rest (Bytes.null piece) total chunks
    Zlib.DecompressOutputAvailable piece next -> do
      let size = toInteger (Bytes.length piece)
      if size > limit - total
        then pure (IoFailed "decompressed output limit exceeded")
        else next >>= decode remaining ended (total + size) (piece : chunks)
    Zlib.DecompressStreamEnd unused
      | Bytes.null unused && Bytes.null remaining -> pure (IoDone (Bytes.concat (reverse chunks)))
      | otherwise -> pure (IoFailed "trailing bytes after gzip member")
    Zlib.DecompressStreamError problem -> pure (IoFailed (Text.pack (show problem)))

synchronous :: IO (IoOutcome a) -> IO (IoOutcome a)
synchronous action = do
  outcome <- tryJust synchronousOnly action
  pure $ case outcome of
    Left problem -> IoFailed (Text.pack (show problem))
    Right value -> value
 where
  synchronousOnly :: SomeException -> Maybe SomeException
  synchronousOnly problem = case fromException problem :: Maybe SomeAsyncException of
    Just _ -> Nothing
    Nothing -> Just problem
