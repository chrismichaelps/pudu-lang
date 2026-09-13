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
import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.MVar (MVar, newEmptyMVar, putMVar, takeMVar, tryTakeMVar)
import Control.Exception
  ( SomeException
  , displayException
  , mask
  , throwIO
  , try
  , uninterruptibleMask_
  )
import Data.Int (Int32)
import qualified Data.Text as Text
import Data.Word (Word8, Word64)
import Foreign.C.Types (CInt (..), CSize (..))
import Foreign.ForeignPtr (ForeignPtr, mallocForeignPtrBytes, withForeignPtr)
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (Ptr, castPtr)
import Foreign.Storable (peek, poke)
import Pudu.Eval.Signal (stopRequested)
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
  {- The native play runs on its own thread while this one waits, because a
     thread inside a foreign call cannot receive an interrupt until the call
     returns: waiting here keeps an interrupt deliverable at once. On an
     interrupt, or when the program has been asked to stop, the token is set,
     the adapter stops and releases its queue within a millisecond, and only
     then does this answer — an interrupt is re-raised rather than turned into
     a playback failure, so the program still stops. -}
  playNative = do
    token <- mallocForeignPtrBytes 4
    withForeignPtr token $ \flag -> poke flag (0 :: Int32)
    finished <- newEmptyMVar
    mask $ \restore -> do
      _ <- forkIO (playInto token finished)
      waited <- try (restore (awaitPlayback token finished))
      case waited of
        Right result -> pure result
        Left interruption -> do
          withForeignPtr token cAudioRequestCancel
          _ <- uninterruptibleMask_ (takeMVar finished)
          throwIO (interruption :: SomeException)

  playInto :: ForeignPtr Int32 -> MVar (IoOutcome Int) -> IO ()
  playInto token finished = do
    outcome <- try $ withForeignPtr token $ \flag -> alloca $ \completedPointer -> do
      status <- Bytes.useAsCStringLen pcm $ \(bytes, count) ->
        cAudioPlay
          (fromIntegral sampleRate)
          (fromIntegral channels)
          (castPtr bytes)
          (fromIntegral count)
          (fromIntegral framesPerBuffer)
          (fromIntegral bufferCount)
          (fromIntegral timeout)
          flag
          completedPointer
      completed <- peek completedPointer
      pure $ if status == 0
        then IoDone (fromIntegral completed)
        else IoFailed (statusMessage status)
    putMVar finished $ case outcome of
      Left problem -> IoFailed (Text.pack (displayException (problem :: SomeException)))
      Right result -> result

  awaitPlayback :: ForeignPtr Int32 -> MVar (IoOutcome Int) -> IO (IoOutcome Int)
  awaitPlayback token finished = do
    done <- tryTakeMVar finished
    case done of
      Just result -> pure result
      Nothing -> do
        stopping <- stopRequested
        if stopping
          then withForeignPtr token cAudioRequestCancel >> takeMVar finished
          else threadDelay stopPollMicroseconds >> awaitPlayback token finished
#else
  playNative = pure (IoFailed "audio device playback is unsupported on this platform")
#endif

#ifdef PUDU_DARWIN_AUDIO
-- How often a waiting play looks for a stop request. Short enough that a
-- supervisor's grace period is spent draining rather than waiting on audio.
stopPollMicroseconds :: Int
stopPollMicroseconds = 5000

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
  -9 -> "audio device playback was cancelled"
  _ -> "audio device playback failed in the platform adapter"

foreign import ccall safe "pudu_audio_play"
  cAudioPlay :: CInt -> CInt -> Ptr Word8 -> CSize -> CInt -> CInt -> CInt -> Ptr Int32 -> Ptr Word64 -> IO CInt

foreign import ccall unsafe "pudu_audio_request_cancel"
  cAudioRequestCancel :: Ptr Int32 -> IO ()
#endif
