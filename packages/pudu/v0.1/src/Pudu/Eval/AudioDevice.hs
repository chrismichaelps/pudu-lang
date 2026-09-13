{-# LANGUAGE CPP #-}
{-# LANGUAGE ForeignFunctionInterface #-}

{-| @Eval.AudioDevice — bounded playback through the target's native audio queue. -}
module Pudu.Eval.AudioDevice
  ( playAudioDevice
  ) where

import qualified Data.ByteString as Bytes
import Data.Text (Text)
import Pudu.Eval.Io (IoOutcome (..))

#ifdef PUDU_DARWIN_AUDIO
import Control.Exception (SomeException, displayException, try)
import qualified Data.Text as Text
import Data.Word (Word8, Word64)
import Foreign.C.Types (CInt (..), CSize (..))
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (Ptr, castPtr)
import Foreign.Storable (peek)
#endif

playAudioDevice :: Int -> Int -> Bytes.ByteString -> Int -> Int -> Int -> IO (IoOutcome Int)
playAudioDevice sampleRate channels pcm framesPerBuffer bufferCount timeout
  | sampleRate < 8000 || sampleRate > 384000 = invalid "audio sample rate is outside 8000 through 384000"
  | channels < 1 || channels > 8 = invalid "audio channel count is outside 1 through 8"
  | framesPerBuffer < 16 || framesPerBuffer > 4096 = invalid "audio frames per buffer is outside 16 through 4096"
  | bufferCount < 2 || bufferCount > 8 = invalid "audio buffer count is outside 2 through 8"
  | timeout < 1 || timeout > 60000 = invalid "audio playback deadline is outside 1 through 60000 milliseconds"
  | Bytes.null pcm = invalid "audio clip is empty"
  | Bytes.length pcm `mod` bytesPerFrame /= 0 = invalid "audio PCM ends inside a frame"
  | frameTotal > toInteger (maxBound :: Int) = invalid "audio frame count exceeds the runtime limit"
  | otherwise = playNative
 where
  bytesPerFrame = channels * 2
  frameTotal = toInteger (Bytes.length pcm) `div` toInteger bytesPerFrame
  invalid message = pure (IoFailed message)
#ifdef PUDU_DARWIN_AUDIO
  playNative = do
    outcome <- try $ alloca $ \completedPointer -> do
      status <- Bytes.useAsCStringLen pcm $ \(bytes, count) ->
        cAudioPlay
          (fromIntegral sampleRate)
          (fromIntegral channels)
          (castPtr bytes)
          (fromIntegral count)
          (fromIntegral framesPerBuffer)
          (fromIntegral bufferCount)
          (fromIntegral timeout)
          completedPointer
      completed <- peek completedPointer
      pure $ if status == 0
        then IoDone (fromIntegral completed)
        else IoFailed (statusMessage status)
    pure $ case outcome of
      Left problem -> IoFailed (Text.pack (displayException (problem :: SomeException)))
      Right result -> result
#else
  playNative = pure (IoFailed "audio device playback is unsupported on this platform")
#endif

#ifdef PUDU_DARWIN_AUDIO
statusMessage :: CInt -> Text
statusMessage status = case status of
  -1 -> "audio device playback received an invalid argument"
  -2 -> "audio device playback deadline exceeded"
  -3 -> "audio output queue could not be created"
  -4 -> "audio output buffers could not be allocated"
  -5 -> "audio output buffer could not be enqueued"
  -6 -> "audio output queue could not start"
  -7 -> "audio output queue could not be released cleanly"
  -8 -> "audio output queue could not drain its final buffers"
  _ -> "audio device playback failed in the platform adapter"

foreign import ccall safe "pudu_audio_play"
  cAudioPlay :: CInt -> CInt -> Ptr Word8 -> CSize -> CInt -> CInt -> CInt -> Ptr Word64 -> IO CInt
#endif
