{-# LANGUAGE CPP #-}
{-# LANGUAGE ForeignFunctionInterface #-}

{-| @Eval.AudioStream — owns persistent native audio streams for one evaluation. -}
module Pudu.Eval.AudioStream
  ( AudioStreamSnapshot (..)
  , AudioStreamStore
  , closeAudioStream
  , closeAudioStreamStore
  , newAudioStreamStore
  , openAudioStream
  , pauseAudioStream
  , readAudioStreamSnapshot
  , resumeAudioStream
  , setAudioStreamVolume
  , writeAudioStream
  ) where

import qualified Data.ByteString as Bytes
import Pudu.Eval.Io (IoOutcome (..))

#ifdef PUDU_DARWIN_AUDIO
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , modifyMVar_
  , newMVar
  , readMVar
  )
import Control.Exception (displayException)
import Data.Int (Int32)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Word (Word64, Word8)
import Foreign.C.Types (CDouble (..), CInt (..), CSize (..))
import Foreign.Marshal.Alloc (alloca, allocaBytes)
import Foreign.Ptr (Ptr, castPtr, nullPtr)
import Foreign.Storable (peek, peekByteOff)
import Pudu.Eval.Io (trySynchronous)
#endif

#ifdef PUDU_DARWIN_AUDIO
data AudioStreamStore = AudioStreamStore
  { streamNextToken :: !(MVar Integer)
  , streamEntries :: !(MVar (Map Integer StreamEntry))
  }

newtype StreamEntry = StreamEntry (MVar (Maybe NativeAudioStream))

data NativeAudioStreamHandle
newtype NativeAudioStream = NativeAudioStream (Ptr NativeAudioStreamHandle)
#else
{-| A target with no audio stream adapter opens no streams, so its store holds
    nothing and every operation refuses. -}
data AudioStreamStore = AudioStreamStore
#endif

data AudioStreamSnapshot = AudioStreamSnapshot
  { snapshotSubmittedFrames :: !Integer
  , snapshotAcquiredFrames :: !Integer
  , snapshotClockFrames :: !Integer
  , snapshotClockNanoseconds :: !Integer
  , snapshotUnderruns :: !Integer
  , snapshotInterruptions :: !Integer
  , snapshotDeviceChanges :: !Integer
  , snapshotTimelineFailures :: !Integer
  , snapshotState :: !Int
  }
  deriving stock (Eq, Show)

newAudioStreamStore :: IO AudioStreamStore
#ifdef PUDU_DARWIN_AUDIO
newAudioStreamStore = AudioStreamStore <$> newMVar 1 <*> newMVar Map.empty
#else
newAudioStreamStore = pure AudioStreamStore
#endif

openAudioStream
  :: AudioStreamStore
  -> Int
  -> Int
  -> Int
  -> Int
  -> IO (IoOutcome (Integer, Int, Int))
#ifdef PUDU_DARWIN_AUDIO
openAudioStream store sampleRate channels framesPerBuffer bufferCount
  | sampleRate < 8000 || sampleRate > 384000 = invalid "audio stream sample rate is outside 8000 through 384000"
  | channels < 1 || channels > 8 = invalid "audio stream channel count is outside 1 through 8"
  | framesPerBuffer < 16 || framesPerBuffer > 4096 = invalid "audio stream frames per buffer is outside 16 through 4096"
  | bufferCount < 2 || bufferCount > 8 = invalid "audio stream buffer count is outside 2 through 8"
  | otherwise = guarded $ alloca $ \pointerOut -> alloca $ \rateOut -> alloca $ \channelsOut -> do
      status <- cAudioStreamOpen
        (fromIntegral sampleRate)
        (fromIntegral channels)
        (fromIntegral framesPerBuffer)
        (fromIntegral bufferCount)
        pointerOut
        rateOut
        channelsOut
      if status /= 0
        then pure (IoFailed (statusMessage status))
        else do
          pointer <- peek pointerOut
          actualRate <- fromIntegral <$> (peek rateOut :: IO Int32)
          actualChannels <- fromIntegral <$> (peek channelsOut :: IO Int32)
          if pointer == nullPtr
            then pure (IoFailed "audio stream adapter returned no session")
            else do
              allocated <- modifyMVar (streamNextToken store) $ \next ->
                if next > toInteger (maxBound :: Int)
                  then pure (next, Nothing)
                  else pure (next + 1, Just next)
              case allocated of
                Nothing -> do
                  _ <- cAudioStreamClose pointer 0 1
                  pure (IoFailed "audio stream token space is exhausted")
                Just token -> do
                  entry <- StreamEntry <$> newMVar (Just (NativeAudioStream pointer))
                  modifyMVar_ (streamEntries store) $ \entries ->
                    pure (Map.insert token entry entries)
                  pure (IoDone (token, actualRate, actualChannels))
 where
  invalid = pure . IoFailed
#else
openAudioStream _ _ _ _ _ = pure (IoFailed "audio device streaming is unsupported on this platform")
#endif

writeAudioStream
  :: AudioStreamStore
  -> Integer
  -> Int
  -> Int
  -> Bytes.ByteString
  -> Int
  -> IO (IoOutcome (Integer, Int))
#ifdef PUDU_DARWIN_AUDIO
writeAudioStream store token sampleRate channels pcm timeout
  | sampleRate < 8000 || sampleRate > 384000 = invalid "audio stream sample rate is outside 8000 through 384000"
  | channels < 1 || channels > 8 = invalid "audio stream channel count is outside 1 through 8"
  | timeout < 1 || timeout > 60000 = invalid "audio stream write deadline is outside 1 through 60000 milliseconds"
  | Bytes.null pcm = invalid "audio stream write is empty"
  | Bytes.length pcm `mod` (channels * 2) /= 0 = invalid "audio stream PCM ends inside a frame"
  | otherwise = withStream store token $ \(NativeAudioStream pointer) -> guarded $
      alloca $ \acceptedOut -> do
        status <- Bytes.useAsCStringLen pcm $ \(bytes, count) ->
          cAudioStreamWrite
            pointer
            (castPtr bytes)
            (fromIntegral count)
            (fromIntegral timeout)
            acceptedOut
        accepted <- toInteger <$> (peek acceptedOut :: IO Word64)
        pure (IoDone (accepted, fromIntegral status))
 where
  invalid = pure . IoFailed
#else
writeAudioStream _ _ _ _ _ _ = pure (IoFailed "audio device streaming is unsupported on this platform")
#endif

pauseAudioStream :: AudioStreamStore -> Integer -> IO (IoOutcome ())
#ifdef PUDU_DARWIN_AUDIO
pauseAudioStream store token =
  withStream store token $ \(NativeAudioStream pointer) -> guarded $
    unitStatus <$> cAudioStreamPause pointer
#else
pauseAudioStream _ _ = pure (IoFailed "audio device streaming is unsupported on this platform")
#endif

resumeAudioStream :: AudioStreamStore -> Integer -> IO (IoOutcome ())
#ifdef PUDU_DARWIN_AUDIO
resumeAudioStream store token =
  withStream store token $ \(NativeAudioStream pointer) -> guarded $
    unitStatus <$> cAudioStreamResume pointer
#else
resumeAudioStream _ _ = pure (IoFailed "audio device streaming is unsupported on this platform")
#endif

setAudioStreamVolume :: AudioStreamStore -> Integer -> Double -> IO (IoOutcome ())
#ifdef PUDU_DARWIN_AUDIO
setAudioStreamVolume store token volume
  | isNaN volume || isInfinite volume || volume < 0 || volume > 1 =
      pure (IoFailed "audio stream volume is outside 0 through 1")
  | otherwise = withStream store token $ \(NativeAudioStream pointer) -> guarded $
      unitStatus <$> cAudioStreamSetVolume pointer (realToFrac volume)
#else
setAudioStreamVolume _ _ _ = pure (IoFailed "audio device streaming is unsupported on this platform")
#endif

readAudioStreamSnapshot
  :: AudioStreamStore
  -> Integer
  -> IO (IoOutcome AudioStreamSnapshot)
#ifdef PUDU_DARWIN_AUDIO
readAudioStreamSnapshot store token =
  withStream store token $ \(NativeAudioStream pointer) -> guarded $
    allocaBytes snapshotBytes $ \snapshotPointer -> do
      status <- cAudioStreamSnapshot pointer snapshotPointer
      if status /= 0
        then pure (IoFailed (statusMessage status))
        else do
          submitted <- wordAt snapshotPointer 0
          acquired <- wordAt snapshotPointer 8
          clockFrames <- wordAt snapshotPointer 16
          clockNanos <- wordAt snapshotPointer 24
          underruns <- wordAt snapshotPointer 32
          interruptions <- wordAt snapshotPointer 40
          deviceChanges <- wordAt snapshotPointer 48
          timelineFailures <- wordAt snapshotPointer 56
          state <- fromIntegral <$> (peekByteOff snapshotPointer 64 :: IO Int32)
          pure (IoDone AudioStreamSnapshot
            { snapshotSubmittedFrames = toInteger submitted
            , snapshotAcquiredFrames = toInteger acquired
            , snapshotClockFrames = toInteger clockFrames
            , snapshotClockNanoseconds = toInteger clockNanos
            , snapshotUnderruns = toInteger underruns
            , snapshotInterruptions = toInteger interruptions
            , snapshotDeviceChanges = toInteger deviceChanges
            , snapshotTimelineFailures = toInteger timelineFailures
            , snapshotState = state
            })
 where
  wordAt pointer offset = peekByteOff pointer offset :: IO Word64
  snapshotBytes = 72
#else
readAudioStreamSnapshot _ _ = pure (IoFailed "audio device streaming is unsupported on this platform")
#endif

closeAudioStream :: AudioStreamStore -> Integer -> Bool -> Int -> IO (IoOutcome ())
#ifdef PUDU_DARWIN_AUDIO
closeAudioStream store token drain timeout
  | timeout < 1 || timeout > 60000 =
      pure (IoFailed "audio stream close deadline is outside 1 through 60000 milliseconds")
  | otherwise = do
      detached <- modifyMVar (streamEntries store) $ \entries ->
        pure (Map.delete token entries, Map.lookup token entries)
      case detached of
        Nothing -> pure (IoFailed closedMessage)
        Just (StreamEntry entry) -> modifyMVar entry $ \current -> case current of
          Nothing -> pure (Nothing, IoFailed closedMessage)
          Just (NativeAudioStream pointer) -> do
            result <- guarded $ unitStatus <$>
              cAudioStreamClose pointer (if drain then 1 else 0) (fromIntegral timeout)
            pure (Nothing, result)
#else
closeAudioStream _ _ _ _ = pure (IoFailed "audio device streaming is unsupported on this platform")
#endif

closeAudioStreamStore :: AudioStreamStore -> IO ()
#ifdef PUDU_DARWIN_AUDIO
closeAudioStreamStore store = do
  entries <- modifyMVar (streamEntries store) $ \held -> pure (Map.empty, Map.elems held)
  mapM_ closeEntry entries
 where
  closeEntry (StreamEntry entry) = modifyMVar_ entry $ \current -> case current of
    Nothing -> pure Nothing
    Just (NativeAudioStream pointer) -> do
      _ <- trySynchronous (cAudioStreamClose pointer 0 1)
      pure Nothing
#else
closeAudioStreamStore _ = pure ()
#endif

#ifdef PUDU_DARWIN_AUDIO
withStream
  :: AudioStreamStore
  -> Integer
  -> (NativeAudioStream -> IO (IoOutcome a))
  -> IO (IoOutcome a)
withStream store token action = do
  entries <- readMVar (streamEntries store)
  case Map.lookup token entries of
    Nothing -> pure (IoFailed closedMessage)
    Just (StreamEntry entry) -> modifyMVar entry $ \current -> case current of
      Nothing -> pure (Nothing, IoFailed closedMessage)
      Just stream -> do
        outcome <- action stream
        pure (Just stream, outcome)

closedMessage :: Text
closedMessage = "audio stream is closed or unknown"

guarded :: IO (IoOutcome a) -> IO (IoOutcome a)
guarded action = do
  outcome <- trySynchronous action
  pure $ case outcome of
    Left problem -> IoFailed (Text.pack (displayException problem))
    Right value -> value

unitStatus :: CInt -> IoOutcome ()
unitStatus status
  | status == 0 = IoDone ()
  | otherwise = IoFailed (statusMessage status)

statusMessage :: CInt -> Text
statusMessage status = case status of
  -1 -> "audio stream received an invalid argument"
  -2 -> "audio stream operation deadline exceeded"
  -3 -> "audio output stream could not be created"
  -4 -> "audio output stream buffers could not be allocated"
  -5 -> "audio output stream buffer could not be enqueued"
  -6 -> "audio output stream control failed"
  -7 -> "audio output stream could not be released cleanly"
  -8 -> "audio output stream timeline is unavailable"
  _ -> "audio stream failed in the platform adapter"

foreign import ccall safe "pudu_audio_stream_open"
  cAudioStreamOpen :: CInt -> CInt -> CInt -> CInt -> Ptr (Ptr NativeAudioStreamHandle) -> Ptr Int32 -> Ptr Int32 -> IO CInt

foreign import ccall safe "pudu_audio_stream_write"
  cAudioStreamWrite :: Ptr NativeAudioStreamHandle -> Ptr Word8 -> CSize -> CInt -> Ptr Word64 -> IO CInt

foreign import ccall unsafe "pudu_audio_stream_pause"
  cAudioStreamPause :: Ptr NativeAudioStreamHandle -> IO CInt

foreign import ccall unsafe "pudu_audio_stream_resume"
  cAudioStreamResume :: Ptr NativeAudioStreamHandle -> IO CInt

foreign import ccall unsafe "pudu_audio_stream_set_volume"
  cAudioStreamSetVolume :: Ptr NativeAudioStreamHandle -> CDouble -> IO CInt

foreign import ccall unsafe "pudu_audio_stream_snapshot_read"
  cAudioStreamSnapshot :: Ptr NativeAudioStreamHandle -> Ptr () -> IO CInt

foreign import ccall safe "pudu_audio_stream_close"
  cAudioStreamClose :: Ptr NativeAudioStreamHandle -> CInt -> CInt -> IO CInt
#endif
