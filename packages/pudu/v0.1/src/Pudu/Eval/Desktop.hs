{-# LANGUAGE CPP #-}
{-# LANGUAGE ForeignFunctionInterface #-}

{-| @Eval.Desktop — owns real desktop windows for one evaluation. -}
module Pudu.Eval.Desktop
  ( DesktopStore
  , closeDesktop
  , closeDesktopStore
  , newDesktopStore
  , openDesktop
  , presentDesktop
  , pumpDesktop
  ) where

import Control.Concurrent.MVar (MVar, modifyMVar, modifyMVar_, newMVar)
import Control.Exception
  ( SomeAsyncException
  , SomeException
  , displayException
  , fromException
  , throwIO
  , try
  )
import qualified Data.ByteString as Bytes
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Pudu.Eval.Io (IoOutcome (..))

#ifdef PUDU_DARWIN_DESKTOP
import Data.Int (Int32)
import Data.Word (Word64, Word8)
import Foreign.C.Types (CInt (..), CSize (..))
import Foreign.Ptr (Ptr, castPtr, nullPtr)
import GHC.Clock (getMonotonicTimeNSec)
import Pudu.Eval.Signal (stopRequested)
#endif

data DesktopStore = DesktopStore
  { desktopNextToken :: !(MVar Int)
  , desktopWindows :: !(MVar (Map Int NativeWindow))
  }

#ifdef PUDU_DARWIN_DESKTOP
newtype NativeWindow = NativeWindow (Ptr ())
#else
data NativeWindow = NativeWindow
#endif

newDesktopStore :: IO DesktopStore
newDesktopStore = DesktopStore <$> newMVar 1 <*> newMVar Map.empty

openDesktop :: DesktopStore -> Text -> Int -> Int -> Bool -> IO (IoOutcome Int)
#ifdef PUDU_DARWIN_DESKTOP
openDesktop store title width height resizable
  | Text.null title = pure (IoFailed "desktop title is empty")
  | width <= 0 || height <= 0 = pure (IoFailed "desktop dimensions must be positive")
  | width > maxDimension || height > maxDimension = pure (IoFailed "desktop dimensions exceed the platform limit")
  | otherwise = guarded $ do
      let encoded = TextEncoding.encodeUtf8 title
      pointer <- Bytes.useAsCStringLen encoded $ \(bytes, count) ->
        cDesktopOpen
          (castBytes bytes)
          (fromIntegral count)
          (fromIntegral width)
          (fromIntegral height)
          (if resizable then 1 else 0)
      if pointer == nullPtr
        then pure (IoFailed "desktop window could not open on the main display thread")
        else do
          token <- modifyMVar (desktopNextToken store) $ \next -> pure (next + 1, next)
          modifyMVar_ (desktopWindows store) $ \windows ->
            pure (Map.insert token (NativeWindow pointer) windows)
          pure (IoDone token)
 where
  maxDimension = fromIntegral (maxBound :: Int32)
#else
openDesktop _ _ _ _ _ = pure (IoFailed "desktop presentation is unsupported on this platform")
#endif

presentDesktop :: DesktopStore -> Int -> Int -> Int -> Bytes.ByteString -> IO (IoOutcome ())
#ifdef PUDU_DARWIN_DESKTOP
presentDesktop store token width height rgba
  | width <= 0 || height <= 0 = pure (IoFailed "desktop dimensions must be positive")
  | toInteger (Bytes.length rgba) /= toInteger width * toInteger height * 4 =
      pure (IoFailed "desktop frame does not match its dimensions")
  | otherwise = withWindow store token $ \(NativeWindow pointer) -> guarded $ do
      status <- Bytes.useAsCStringLen rgba $ \(bytes, count) ->
        cDesktopPresent
          pointer
          (fromIntegral width)
          (fromIntegral height)
          (castBytes bytes)
          (fromIntegral count)
      pure (unitStatus "present" status)
#else
presentDesktop _ _ _ _ _ = pure (IoFailed "desktop presentation is unsupported on this platform")
#endif

pumpDesktop :: DesktopStore -> Int -> Int -> IO (IoOutcome Bool)
#ifdef PUDU_DARWIN_DESKTOP
pumpDesktop store token milliseconds
  | milliseconds < 0 = pure (IoFailed "desktop pump duration must not be negative")
  | milliseconds > fromIntegral (maxBound :: Int32) = pure (IoFailed "desktop pump duration exceeds the platform limit")
  | otherwise = withWindow store token $ \(NativeWindow pointer) -> guarded $ do
      started <- getMonotonicTimeNSec
      pumpSlices pointer (started + fromIntegral milliseconds * 1000000)
 where
  {- A pump is made of native pumps of at most one slice each. A thread inside
     a foreign call receives no interrupt until the call returns, so one long
     native pump held Ctrl-C for the whole requested duration; between slices
     this thread is back in the runtime, which delivers an interrupt within a
     slice. A stop request the program is watching for ends the pump early too,
     answering whatever the window last reported. -}
  pumpSlices pointer deadline = do
    now <- getMonotonicTimeNSec
    let remaining = if now >= deadline then 0 else (deadline - now) `div` 1000000
        slice = min pumpSliceMilliseconds remaining
    status <- cDesktopPump pointer (fromIntegral slice)
    stopping <- stopRequested
    case status of
      1 -> pure (IoDone True)
      0 | remaining <= pumpSliceMilliseconds || stopping -> pure (IoDone False)
        | otherwise -> pumpSlices pointer deadline
      _ -> pure (IoFailed (statusMessage "pump" status))
#else
pumpDesktop _ _ _ = pure (IoFailed "desktop presentation is unsupported on this platform")
#endif

closeDesktop :: DesktopStore -> Int -> IO (IoOutcome ())
#ifdef PUDU_DARWIN_DESKTOP
closeDesktop store token =
  modifyMVar (desktopWindows store) $ \windows ->
    case Map.lookup token windows of
      Nothing -> pure (windows, IoFailed "desktop session is closed or unknown")
      Just (NativeWindow pointer) -> do
        outcome <- guarded $ unitStatus "close" <$> cDesktopClose pointer
        pure $ case outcome of
          IoDone () -> (Map.delete token windows, outcome)
          IoFailed _ -> (windows, outcome)
#else
closeDesktop _ _ = pure (IoFailed "desktop presentation is unsupported on this platform")
#endif

closeDesktopStore :: DesktopStore -> IO ()
#ifdef PUDU_DARWIN_DESKTOP
closeDesktopStore store = do
  windows <- modifyMVar (desktopWindows store) $ \held -> pure (Map.empty, Map.elems held)
  mapM_ closeOne windows
 where
  closeOne (NativeWindow pointer) = do
    _ <- try (cDesktopClose pointer) :: IO (Either SomeException CInt)
    pure ()
#else
closeDesktopStore _ = pure ()
#endif

withWindow :: DesktopStore -> Int -> (NativeWindow -> IO (IoOutcome a)) -> IO (IoOutcome a)
withWindow store token action =
  modifyMVar (desktopWindows store) $ \windows ->
    case Map.lookup token windows of
      Nothing -> pure (windows, IoFailed "desktop session is closed or unknown")
      Just window -> do
        outcome <- action window
        pure (windows, outcome)

{-| A platform failure as a typed outcome.

    An interrupt or other asynchronous exception is re-raised rather than
    reported as a failure: turning Ctrl-C into `PlatformFailure` let the
    program continue as though the window had merely misbehaved. -}
guarded :: IO (IoOutcome a) -> IO (IoOutcome a)
guarded action = do
  outcome <- try action
  case outcome of
    Left problem
      | Just _ <- (fromException problem :: Maybe SomeAsyncException) -> throwIO problem
      | otherwise -> pure (IoFailed (Text.pack (displayException (problem :: SomeException))))
    Right value -> pure value

#ifdef PUDU_DARWIN_DESKTOP
castBytes :: Ptr a -> Ptr Word8
castBytes = castPtr

unitStatus :: Text -> CInt -> IoOutcome ()
unitStatus operation status
  | status == 0 = IoDone ()
  | otherwise = IoFailed (statusMessage operation status)

-- The longest single native pump. Short enough that an interrupt or a watched
-- stop request is answered well inside a frame, long enough that an idle pump
-- does not spin.
pumpSliceMilliseconds :: Word64
pumpSliceMilliseconds = 16

statusMessage :: Text -> CInt -> Text
statusMessage operation status = case status of
  -1 -> "desktop " <> operation <> " received an invalid argument"
  -2 -> "desktop " <> operation <> " must run on the main display thread"
  -3 -> "desktop " <> operation <> " received malformed frame bytes"
  _ -> "desktop " <> operation <> " failed in the platform adapter"

foreign import ccall unsafe "pudu_desktop_open"
  cDesktopOpen :: Ptr Word8 -> CSize -> CInt -> CInt -> CInt -> IO (Ptr ())

foreign import ccall unsafe "pudu_desktop_present"
  cDesktopPresent :: Ptr () -> CInt -> CInt -> Ptr Word8 -> CSize -> IO CInt

-- Pumping waits for events up to a caller-chosen duration, so it is a safe
-- call: an unsafe one would hold every other capability out of collection
-- for that whole wait. A bound main thread keeps its OS thread either way.
foreign import ccall safe "pudu_desktop_pump"
  cDesktopPump :: Ptr () -> CInt -> IO CInt

foreign import ccall unsafe "pudu_desktop_close"
  cDesktopClose :: Ptr () -> IO CInt
#endif
