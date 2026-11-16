{-| @Foreign.Callback.Native — libffi trampoline preparation and context lifetime. -}
module Pudu.Foreign.Callback.Native
  ( CallbackAdapter
  , NativeCallback
  , NativeCallbackCache
  , nativeCallbackCode
  , nativeCallbackContext
  , prepareCallbackAdapter
  , registerNativeCallback
  , retireNativeCallback
  , newNativeCallbackCache
  , findNativeCallback
  , closeNativeCallbackCache
  , decodeCallbackArguments
  ) where

import Control.Concurrent.MVar (MVar, modifyMVarMasked, newMVar, swapMVar)
import Control.Exception (SomeException, mask, mask_, try)
import qualified Data.ByteString as ByteString
import Data.Int (Int32, Int64)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text.Encoding as Encoding
import Data.Word (Word8)
import Foreign.C.Types (CChar, CDouble (..), CInt (..))
import Foreign.Marshal.Array (peekArray, withArray)
import Foreign.Ptr (FunPtr, Ptr, nullPtr)
import Foreign.StablePtr
  ( castPtrToStablePtr, castStablePtrToPtr, deRefStablePtr, freeStablePtr, newStablePtr )
import Foreign.Storable (poke)
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Foreign.Call
  ( CrossedValue, ForeignCallFailure (..), kindCode, leafKinds, rebuildRecord, recordShape )
import Pudu.Foreign.Callback (CallbackParameter (..), CallbackResult (..), CallbackSignature (..))
import Pudu.Foreign.CallbackStore (CallbackKey)
import Pudu.Foreign.Crossing (Crossing (..))

data CallbackAdapter = CallbackAdapter !(Ptr ()) !(Ptr ()) !Int

data NativeCallback = NativeCallback
  { nativeCallbackCode :: !(Ptr ())
  , nativeCallbackContext :: !(Ptr ())
  }

{-| The run owns native registrations independently of its immutable adapters.
    Closure state is released by the native registry after an in-flight call. -}
newtype NativeCallbackCache = NativeCallbackCache (MVar (Maybe (Map.Map CallbackKey NativeCallback)))
  deriving stock (Eq)

newNativeCallbackCache :: IO NativeCallbackCache
newNativeCallbackCache = NativeCallbackCache <$> newMVar (Just Map.empty)

findNativeCallback
  :: NativeCallbackCache -> CallbackKey -> IO (Maybe NativeCallback) -> IO (Maybe NativeCallback)
findNativeCallback (NativeCallbackCache cache) key create = modifyMVarMasked cache $ \held ->
  case held of
    Nothing -> pure (Nothing, Nothing)
    Just entries -> case Map.lookup key entries of
      Just existing -> pure (held, Just existing)
      Nothing -> do
        created <- create
        pure (Just (maybe entries (\value -> Map.insert key value entries) created), created)

closeNativeCallbackCache :: NativeCallbackCache -> IO ()
closeNativeCallbackCache (NativeCallbackCache cache) = mask_ $ do
  held <- swapMVar cache Nothing
  mapM_ (mapM_ retireNativeCallback) held

type Dispatch = Ptr () -> Ptr () -> Ptr Int64 -> Ptr CDouble -> Ptr Int64 -> Ptr CDouble -> IO CInt
type Dispose = Ptr () -> IO ()

foreign import ccall safe "pudu_ffi_callback_adapter"
  c_adapter :: Ptr CChar -> Int32 -> Int32 -> Ptr Word8 -> Ptr Int32 -> Int32 -> Ptr Word8
    -> Int32 -> Ptr Word8 -> Word8 -> Int64 -> CDouble -> IO (Ptr ())
foreign import ccall unsafe "pudu_ffi_callback_code"
  c_code :: Ptr () -> IO (Ptr ())
foreign import ccall unsafe "pudu_ffi_callback_register"
  c_register :: Ptr () -> Ptr () -> FunPtr Dispatch -> FunPtr Dispose -> IO (Ptr ())
foreign import ccall safe "pudu_ffi_callback_retire"
  c_retire :: Ptr () -> IO ()

foreign export ccall "pudu_hs_callback_dispatch" dispatchCallback :: Dispatch
foreign export ccall "pudu_hs_callback_dispose" disposeCallback :: Dispose
foreign import ccall "&pudu_hs_callback_dispatch" c_dispatch :: FunPtr Dispatch
foreign import ccall "&pudu_hs_callback_dispose" c_dispose :: FunPtr Dispose

type Handler = Ptr () -> Maybe [(Int64, Double)] -> IO (Maybe (Int64, Double))

data DispatchState = DispatchState !Int !Handler

prepareCallbackAdapter :: Text -> CallbackSignature -> IO (Maybe CallbackAdapter)
prepareCallbackAdapter owner signature =
  case [index | (index, CallbackContext) <- zip [0 ..] parameters] of
    [context] -> do
      let kinds = map parameterKind parameters
          individualLeaves = map parameterLeaves parameters
          counts = map (fromIntegral . length) individualLeaves
          leaves = concat individualLeaves
          shapes = concat [recordShape crossing | CallbackValue crossing <- parameters]
          (resultKind, fallbackInteger, fallbackDouble) = callbackReturn (callbackResult signature)
      adapter <- ByteString.useAsCString (Encoding.encodeUtf8 owner) $ \name ->
        withArray kinds $ \kindArray ->
          withArray counts $ \countArray ->
            withArray leaves $ \leafArray ->
              withArray shapes $ \shapeArray ->
                c_adapter name (fromIntegral (length parameters)) context kindArray countArray
                  (fromIntegral (length leaves)) leafArray (fromIntegral (length shapes)) shapeArray
                  resultKind fallbackInteger (CDouble fallbackDouble)
      code <- c_code adapter
      pure $ if adapter == nullPtr || code == nullPtr then Nothing
        else Just (CallbackAdapter adapter code (length leaves))
    _ -> pure Nothing
 where
  parameters = callbackParameters signature
  parameterKind CallbackContext = 16
  parameterKind (CallbackValue crossing) = kindCode crossing
  parameterLeaves CallbackContext = []
  parameterLeaves (CallbackValue crossing) = leafKinds crossing

callbackReturn :: CallbackResult -> (Word8, Int64, Double)
callbackReturn result = case result of
  CallbackVoid -> (kindCode NothingCrossing, 0, 0)
  CallbackSigned width integer -> (kindCode (SignedCrossing width), fromInteger integer, 0)
  CallbackUnsigned width integer -> (kindCode (UnsignedCrossing width), fromInteger integer, 0)
  CallbackFloat width floating ->
    (kindCode (FloatingCrossing (case width of Float32Width -> 32; Float64Width -> 64)), 0, floating)
  CallbackBool value -> (kindCode BooleanCrossing, if value then 1 else 0, 0)

registerNativeCallback :: CallbackAdapter -> Handler -> IO (Maybe NativeCallback)
registerNativeCallback (CallbackAdapter adapter code leaves) handler = mask_ $ do
  state <- newStablePtr (DispatchState leaves handler)
  context <- c_register adapter (castStablePtrToPtr state) c_dispatch c_dispose
  if context == nullPtr
    then freeStablePtr state >> pure Nothing
    else pure (Just (NativeCallback code context))

retireNativeCallback :: NativeCallback -> IO ()
retireNativeCallback = c_retire . nativeCallbackContext

dispatchCallback :: Dispatch
dispatchCallback opaque scope integers doubles returnedInteger returnedDouble = mask $ \restore -> do
  attempted <- try @SomeException $ restore $ do
    DispatchState count handler <- deRefStablePtr (castPtrToStablePtr opaque)
    values <- if integers == nullPtr || doubles == nullPtr then pure Nothing else do
      heldIntegers <- peekArray count integers
      heldDoubles <- peekArray count doubles
      pure (Just (zip heldIntegers [value | CDouble value <- heldDoubles]))
    result <- handler scope values
    case result of
      Nothing -> pure 0
      Just (integer, floating) -> do
        poke returnedInteger integer
        poke returnedDouble (CDouble floating)
        pure 1
  pure (either (const 0) id attempted)

disposeCallback :: Dispose
disposeCallback opaque = mask_ (freeStablePtr (castPtrToStablePtr @DispatchState opaque))

decodeCallbackArguments
  :: CallbackSignature -> [(Int64, Double)] -> IO (Either ForeignCallFailure [CrossedValue])
decodeCallbackArguments signature = go [] [crossing | CallbackValue crossing <- callbackParameters signature]
 where
  go reversed [] [] = pure (Right (reverse reversed))
  go _ [] _ = pure (Left (CallAssemblyFailure "callback argument storage exceeds its declaration"))
  go reversed (crossing : more) leaves = do
    rebuilt <- rebuildRecord crossing leaves
    case rebuilt of
      Left failure -> pure (Left failure)
      Right (value, rest) -> go (value : reversed) more rest
