{-| @Foreign.Callback.Native — libffi trampoline preparation and context lifetime. -}
module Pudu.Foreign.Callback.Native
  ( CallbackAdapter
  , NativeCallback
  , NativeCallbackCache
  , callbackAdapterCode
  , nativeCallbackCode
  , nativeCallbackContext
  , nativeCallbackBlockCode
  , withBlockLiterals
  , findCallbackAdapter
  , retireNativeCallback
  , newNativeCallbackCache
  , findNativeCallback
  , closeNativeCallbackCache
  , decodeCallbackArguments
  ) where

import Control.Concurrent.MVar (MVar, modifyMVarMasked, newMVar, swapMVar)
import Control.Exception (SomeException, mask, mask_, try)
import Control.Monad (join)
import qualified Data.ByteString as ByteString
import Data.Int (Int32, Int64)
import Data.List (mapAccumL)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text.Encoding as Encoding
import Data.Word (Word8, Word64)
import Foreign.C.Types (CChar, CDouble (..), CInt (..), CSize (..))
import Foreign.Marshal.Alloc (allocaBytesAligned)
import Foreign.Marshal.Array (peekArray, withArray)
import Foreign.Ptr (FunPtr, Ptr, nullPtr, wordPtrToPtr)
import Foreign.StablePtr
  ( castPtrToStablePtr, castStablePtrToPtr, deRefStablePtr, freeStablePtr, newStablePtr )
import Foreign.Storable (poke)
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Foreign.Call
  ( CrossedValue (..), ForeignCallFailure (..), kindCode, leafKinds, rebuildRecord, recordShape )
import Pudu.Foreign.Callback (CallbackParameter (..), CallbackResult (..), CallbackSignature (..))
import Pudu.Foreign.CallbackStore (CallbackKey)
import Pudu.Foreign.Crossing (Crossing (..))

data CallbackAdapter = CallbackAdapter !(Ptr ()) !(Ptr ())

callbackAdapterCode :: CallbackAdapter -> Ptr ()
callbackAdapterCode (CallbackAdapter _ code) = code

data NativeCallback = NativeCallback
  { nativeCallbackCode :: !(Ptr ())
  , nativeCallbackContext :: !(Ptr ())
  , nativeCallbackAdapter :: !(Ptr ())
  }

{-| The invoke entry of a block carrying this registration, when the platform
    has a block runtime and the signature takes its context first. -}
nativeCallbackBlockCode :: NativeCallback -> IO (Maybe (Ptr ()))
nativeCallbackBlockCode native = do
  code <- c_block_code (nativeCallbackAdapter native)
  pure (if code == nullPtr then Nothing else Just code)

{-| Each (position, invoke, key) becomes a stack block living for the action.
    A callee that keeps a block copies it; the copy carries the key. -}
withBlockLiterals :: [(Int, Ptr (), Ptr ())] -> ([(Int, Ptr ())] -> IO a) -> IO (Maybe a)
withBlockLiterals requested action = go requested []
 where
  go [] built = Just <$> action (reverse built)
  go ((position, invoke, key) : rest) built = do
    size <- c_block_size
    allocaBytesAligned (fromIntegral size) 16 $ \storage -> do
      filled <- c_block_fill storage invoke key
      if filled == 0 then pure Nothing else go rest ((position, storage) : built)

{-| The run owns native registrations independently of its immutable adapters.
    Closure state is released by the native registry after an in-flight call. -}
data CallbackCacheEntries = CallbackCacheEntries
  { cachedAdapters :: !(Map.Map (Text, Int) CallbackAdapter)
  , cachedRegistrations :: !(Map.Map CallbackKey NativeCallback)
  }

newtype NativeCallbackCache = NativeCallbackCache (MVar (Maybe CallbackCacheEntries))
  deriving stock (Eq)

newNativeCallbackCache :: IO NativeCallbackCache
newNativeCallbackCache = NativeCallbackCache <$> newMVar (Just (CallbackCacheEntries Map.empty Map.empty))

findNativeCallback
  :: NativeCallbackCache -> CallbackKey -> Text -> Int -> CallbackSignature -> Handler -> IO (Maybe NativeCallback)
findNativeCallback (NativeCallbackCache cache) key owner member signature handler = modifyMVarMasked cache $ \held ->
  case held of
    Nothing -> pure (Nothing, Nothing)
    Just entries -> case Map.lookup key (cachedRegistrations entries) of
      Just existing -> pure (held, Just existing)
      Nothing -> do
        (updated, adapter) <- adapterFor entries owner member signature
        native <- traverse (\valid -> registerNativeCallback valid handler) adapter
        case join native of
          Nothing -> pure (Just updated, Nothing)
          Just registered -> pure
            ( Just updated{cachedRegistrations = Map.insert key registered (cachedRegistrations updated)}
            , Just registered )

findCallbackAdapter :: NativeCallbackCache -> Text -> Int -> CallbackSignature -> IO (Maybe CallbackAdapter)
findCallbackAdapter (NativeCallbackCache cache) owner member signature = modifyMVarMasked cache $ \held ->
  case held of
    Nothing -> pure (Nothing, Nothing)
    Just entries -> do
      (updated, adapter) <- adapterFor entries owner member signature
      pure (Just updated, adapter)

adapterFor :: CallbackCacheEntries -> Text -> Int -> CallbackSignature -> IO (CallbackCacheEntries, Maybe CallbackAdapter)
adapterFor entries owner member signature = case Map.lookup (owner, member) (cachedAdapters entries) of
  Just valid -> pure (entries, Just valid)
  Nothing -> do
    created <- prepareCallbackAdapter owner member signature
    case created of
      Nothing -> pure (entries, Nothing)
      Just valid -> pure (entries{cachedAdapters = Map.insert (owner, member) valid (cachedAdapters entries)}, created)

closeNativeCallbackCache :: NativeCallbackCache -> IO ()
closeNativeCallbackCache (NativeCallbackCache cache) = mask_ $ do
  held <- swapMVar cache Nothing
  mapM_ (mapM_ retireNativeCallback . cachedRegistrations) held

type Dispatch = Ptr () -> Ptr () -> Int32 -> Int32 -> Ptr Int64 -> Ptr CDouble -> Ptr Int64 -> Ptr CDouble -> IO CInt
type Dispose = Ptr () -> IO ()

foreign import ccall safe "pudu_ffi_callback_adapter"
  c_adapter :: Ptr CChar -> Int32 -> Int32 -> Int32 -> Ptr Word8 -> Ptr Int32 -> Int32 -> Ptr Word8
    -> Int32 -> Ptr Word8 -> Word8 -> Int64 -> CDouble -> IO (Ptr ())
foreign import ccall unsafe "pudu_ffi_callback_code"
  c_code :: Ptr () -> IO (Ptr ())
foreign import ccall unsafe "pudu_ffi_callback_register"
  c_register :: Ptr () -> Ptr () -> FunPtr Dispatch -> FunPtr Dispose -> IO (Ptr ())
foreign import ccall safe "pudu_ffi_callback_block_code"
  c_block_code :: Ptr () -> IO (Ptr ())
foreign import ccall unsafe "pudu_ffi_block_size"
  c_block_size :: IO CSize
foreign import ccall unsafe "pudu_ffi_block_fill"
  c_block_fill :: Ptr () -> Ptr () -> Ptr () -> IO CInt
foreign import ccall safe "pudu_ffi_callback_retire"
  c_retire :: Ptr () -> IO ()

foreign export ccall "pudu_hs_callback_dispatch" dispatchCallback :: Dispatch
foreign export ccall "pudu_hs_callback_dispose" disposeCallback :: Dispose
foreign import ccall "&pudu_hs_callback_dispatch" c_dispatch :: FunPtr Dispatch
foreign import ccall "&pudu_hs_callback_dispose" c_dispose :: FunPtr Dispose

type Handler = Int -> Ptr () -> Maybe [(Int64, Double)] -> IO (Maybe (Int64, Double))

newtype DispatchState = DispatchState Handler

prepareCallbackAdapter :: Text -> Int -> CallbackSignature -> IO (Maybe CallbackAdapter)
prepareCallbackAdapter owner member signature =
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
                c_adapter name (fromIntegral member) (fromIntegral (length parameters)) context kindArray countArray
                  (fromIntegral (length leaves)) leafArray (fromIntegral (length shapes)) shapeArray
                  resultKind fallbackInteger (CDouble fallbackDouble)
      code <- c_code adapter
      pure $ if adapter == nullPtr || code == nullPtr then Nothing
        else Just (CallbackAdapter adapter code)
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
registerNativeCallback (CallbackAdapter adapter code) handler = mask_ $ do
  state <- newStablePtr (DispatchState handler)
  context <- c_register adapter (castStablePtrToPtr state) c_dispatch c_dispose
  if context == nullPtr
    then freeStablePtr state >> pure Nothing
    else pure (Just (NativeCallback code context adapter))

retireNativeCallback :: NativeCallback -> IO ()
retireNativeCallback = c_retire . nativeCallbackContext

dispatchCallback :: Dispatch
dispatchCallback opaque scope member count integers doubles returnedInteger returnedDouble = mask $ \restore -> do
  attempted <- try @SomeException $ restore $ do
    DispatchState handler <- deRefStablePtr (castPtrToStablePtr opaque)
    values <- if integers == nullPtr || doubles == nullPtr then pure Nothing else do
      heldIntegers <- peekArray (fromIntegral count) integers
      heldDoubles <- peekArray (fromIntegral count) doubles
      pure (Just (zip heldIntegers [value | CDouble value <- heldDoubles]))
    result <- handler (fromIntegral member) scope values
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
decodeCallbackArguments signature leaves
  | null lengths = go [] [crossing | CallbackValue crossing <- parameters] leaves
  | otherwise = case traverse decodeExtent lengths of
      Nothing -> pure (Left (CallAssemblyFailure "invalid input to a foreign callback"))
      Just checked -> decodeRuns (Map.fromList checked) positions
 where
  parameters = callbackParameters signature
  lengths = callbackByteLengths signature
  (_, positions) = mapAccumL takeLeaves leaves (zip [0 ..] parameters)
  takeLeaves remaining (index, parameter) =
    let count = case parameter of
          CallbackContext -> 0
          CallbackValue crossing -> length (leafKinds crossing)
        (current, rest) = splitAt count remaining
     in (rest, (index, (parameter, current)))
  indexed = Map.fromList positions
  decodeExtent (runIndex, lengthIndex) = do
    (_, [(address, _)]) <- Map.lookup runIndex indexed
    (CallbackValue kind, [(rawLength, _)]) <- Map.lookup lengthIndex indexed
    let count = case kind of
          UnsignedCrossing _ -> toInteger (fromIntegral rawLength :: Word64)
          _ -> toInteger rawLength
        pointer = wordPtrToPtr (fromIntegral address)
    if count < 0 || count > toInteger (maxBound :: Int) || (pointer == nullPtr && count /= 0)
      then Nothing
      else Just (runIndex, (pointer, fromInteger count))
  decodeRuns _ [] = pure (Right [])
  decodeRuns checked ((index, (parameter, current)) : rest) = case parameter of
    CallbackContext -> decodeRuns checked rest
    CallbackValue crossing -> do
      value <- case Map.lookup index checked of
        Just (_, 0) -> pure (Right (CrossedBytes ByteString.empty))
        Just (pointer, count) -> Right . CrossedBytes <$> ByteString.packCStringLen (pointer, count)
        Nothing -> fmap fst <$> rebuildRecord crossing current
      case value of
        Left failure -> pure (Left failure)
        Right one -> fmap (one :) <$> decodeRuns checked rest
  go reversed [] [] = pure (Right (reverse reversed))
  go _ [] _ = pure (Left (CallAssemblyFailure "callback argument storage exceeds its declaration"))
  go reversed (crossing : more) remaining = do
    rebuilt <- rebuildRecord crossing remaining
    case rebuilt of
      Left failure -> pure (Left failure)
      Right (value, rest) -> go (value : reversed) more rest
