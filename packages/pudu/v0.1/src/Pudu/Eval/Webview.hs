{-# LANGUAGE CPP #-}
{-# LANGUAGE ForeignFunctionInterface #-}

{-| @Eval.Webview — the evaluator's end of the WebView record channel

    The adapter keeps one process-wide host whose windows and views the
    program names, so this module holds no registry: it frames nothing and
    decides nothing, it only carries bytes across and turns the adapter's
    statuses into outcomes whose leading tag the Pudu side classifies. -}
module Pudu.Eval.Webview
  ( sendWebview
  , pumpWebview
  , drainWebviewEvents
  , webviewRequestBody
  , respondWebview
  ) where

import qualified Data.ByteString as Bytes
import Data.Text (Text)
import Pudu.Eval.Io (IoOutcome (..))

#ifdef PUDU_NATIVE_WEBVIEW
import Control.Exception (displayException)
import Data.Int (Int32, Int64)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Word (Word64, Word8)
import Foreign.C.Types (CInt (..), CSize (..))
import Foreign.Marshal.Alloc (allocaBytes)
import Foreign.Ptr (Ptr, castPtr, nullPtr)
import GHC.Clock (getMonotonicTimeNSec)
import Pudu.Eval.Io (trySynchronous)
import Pudu.Eval.Signal (stopRequested)
#endif

sendWebview :: Text -> IO (IoOutcome ())
pumpWebview :: Int -> IO (IoOutcome Bool)
drainWebviewEvents :: IO (IoOutcome Bytes.ByteString)
webviewRequestBody :: Int -> IO (IoOutcome Bytes.ByteString)
respondWebview :: Int -> Int -> Text -> Bytes.ByteString -> IO (IoOutcome ())

#ifdef PUDU_NATIVE_WEBVIEW
sendWebview records = guarded $ do
  status <- Bytes.useAsCStringLen (TextEncoding.encodeUtf8 records) $ \(bytes, count) ->
    cSend (castPtr bytes) (fromIntegral count)
  if status == 0
    then pure (IoDone ())
    else do
      reason <- measuredCopy cFailure
      pure (IoFailed (statusTag status <> TextEncoding.decodeUtf8Lenient reason))

pumpWebview milliseconds
  | milliseconds < 0 = pure (IoFailed "invalid: a pump duration cannot be negative")
  | milliseconds > fromIntegral (maxBound :: Int32) = pure (IoFailed "invalid: the pump duration exceeds the platform limit")
  | otherwise = guarded $ do
      started <- getMonotonicTimeNSec
      slices (started + fromIntegral milliseconds * 1000000)
 where
  {- A thread inside a foreign call receives no interrupt until it returns,
     so the wait is cut into slices with the runtime in between. -}
  slices deadline = do
    now <- getMonotonicTimeNSec
    let remaining = if now >= deadline then 0 else (deadline - now) `div` 1000000
        slice = min sliceMilliseconds remaining
    status <- cPump (fromIntegral slice)
    stopping <- stopRequested
    case status of
      1 -> pure (IoDone True)
      0 | remaining <= sliceMilliseconds || stopping -> pure (IoDone False)
        | otherwise -> slices deadline
      _ -> pure (IoFailed (statusTag status <> "the platform loop could not run"))

drainWebviewEvents = guarded (IoDone <$> measuredCopy cEvents)

webviewRequestBody request = guarded $ do
  held <- cBody (fromIntegral request) nullPtr 0
  if held < 0
    then pure (IoFailed (statusTag (fromIntegral held) <> "the request is no longer pending"))
    else allocaBytes (max 1 (fromIntegral held)) $ \buffer -> do
      copied <- cBody (fromIntegral request) buffer (fromIntegral held)
      if copied /= held
        then pure (IoFailed "gone: the request changed while it was read")
        else IoDone <$> Bytes.packCStringLen (castPtr buffer, fromIntegral copied)

respondWebview request status headers body
  | status < 100 || status > 599 = pure (IoFailed "invalid: a response status must be between 100 and 599")
  | otherwise = guarded $ do
      answer <- Bytes.useAsCStringLen (TextEncoding.encodeUtf8 headers) $ \(headBytes, headCount) ->
        Bytes.useAsCStringLen body $ \(bodyBytes, bodyCount) ->
          cRespond
            (fromIntegral request)
            (fromIntegral status)
            (castPtr headBytes)
            (fromIntegral headCount)
            (castPtr bodyBytes)
            (fromIntegral bodyCount)
      pure $
        if answer == 0
          then IoDone ()
          else IoFailed (statusTag answer <> "the request could not be answered")

{-| Bytes the adapter measures on a call without a buffer and copies on a
    call whose capacity fits. Bytes queued between the two calls make the
    copy refuse; the second attempt measures again. -}
measuredCopy :: (Ptr Word8 -> CSize -> IO Int64) -> IO Bytes.ByteString
measuredCopy native = attempt (2 :: Int)
 where
  attempt tries = do
    held <- native nullPtr 0
    if held <= 0
      then pure Bytes.empty
      else allocaBytes (fromIntegral held) $ \buffer -> do
        copied <- native buffer (fromIntegral held)
        if copied == held || tries <= 1
          then Bytes.packCStringLen (castPtr buffer, fromIntegral (min copied held))
          else attempt (tries - 1)

{-| A platform failure as a typed outcome; an asynchronous exception such as
    an interrupt is re-raised rather than reported. -}
guarded :: IO (IoOutcome a) -> IO (IoOutcome a)
guarded action = do
  outcome <- trySynchronous action
  pure $ case outcome of
    Left problem -> IoFailed ("platform: " <> Text.pack (displayException problem))
    Right value -> value

statusTag :: CInt -> Text
statusTag status = case status of
  -1 -> "invalid: "
  -2 -> "thread: "
  -3 -> "malformed: "
  -5 -> "unknown: "
  -6 -> "gone: "
  -7 -> "unsupported: "
  _ -> "platform: "

sliceMilliseconds :: Word64
sliceMilliseconds = 16

foreign import ccall unsafe "pudu_webview_send"
  cSend :: Ptr Word8 -> CSize -> IO CInt

-- The pump waits for events, so it is a safe call: an unsafe one would hold
-- every other capability out of collection for the whole wait.
foreign import ccall safe "pudu_webview_pump"
  cPump :: CInt -> IO CInt

foreign import ccall unsafe "pudu_webview_events"
  cEvents :: Ptr Word8 -> CSize -> IO Int64

foreign import ccall unsafe "pudu_webview_body"
  cBody :: Int64 -> Ptr Word8 -> CSize -> IO Int64

foreign import ccall unsafe "pudu_webview_respond"
  cRespond :: Int64 -> CInt -> Ptr Word8 -> CSize -> Ptr Word8 -> CSize -> IO CInt

foreign import ccall unsafe "pudu_webview_failure"
  cFailure :: Ptr Word8 -> CSize -> IO Int64
#else
sendWebview _ = pure unsupported
pumpWebview _ = pure unsupported
drainWebviewEvents = pure unsupported
webviewRequestBody _ = pure unsupported
respondWebview _ _ _ _ = pure unsupported

unsupported :: IoOutcome a
unsupported = IoFailed "unsupported: no WebView adapter is built for this platform"
#endif
