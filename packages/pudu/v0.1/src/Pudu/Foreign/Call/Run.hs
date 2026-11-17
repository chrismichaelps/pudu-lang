{-| @Foreign.Call.Run — aligned, call-scoped storage for ABI array elements. -}
module Pudu.Foreign.Call.Run
  ( RunLayout
  , PreparedRuns
  , noPreparedRuns
  , runLayout
  , runByteSize
  , prepareRuns
  , withPreparedRuns
  , withInputRun
  , readRun
  ) where

import Control.Exception (bracket)
import qualified Data.ByteString as ByteString
import Data.Int (Int64)
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Word (Word8, Word64)
import Foreign.C.Types (CDouble (..), CInt (..), CSize (..))
import Foreign.Marshal.Alloc (alloca, free, mallocBytes)
import Foreign.Marshal.Array (allocaArray, peekArray, withArray)
import Foreign.Ptr (Ptr, nullPtr, plusPtr)
import Foreign.Storable (peek)
import Pudu.Foreign.Call
  ( CrossedValue (..), ForeignCallFailure (..), ForeignCallResult, leafKinds, rebuildRecord
  , received, recordFields, recordShape )
import Pudu.Foreign.Crossing (Crossing (..), isLoanPointee)
import Pudu.Foreign.Extent (ExtentUnit (..), ForeignBound (..))

foreign import ccall unsafe "pudu_ffi_run_layout"
  c_runLayout :: Ptr Word8 -> CSize -> Ptr Word8 -> CSize -> Ptr CSize -> Ptr CSize -> IO CInt

foreign import ccall unsafe "pudu_ffi_run_fields"
  c_runFields :: Ptr () -> CSize -> Ptr CSize -> Ptr Word8 -> Ptr Int64 -> Ptr CDouble -> CInt -> IO CInt

data RunLayout = RunLayout !Crossing !Int ![Word8] ![CSize]

type NativeArgument = (Crossing, Bool, CrossedValue)

data InputRun = InputRun !RunLayout !Bool ![CrossedValue] !Int !Int

newtype PreparedRuns = PreparedRuns (Map.Map Int InputRun)

noPreparedRuns :: PreparedRuns
noPreparedRuns = PreparedRuns Map.empty

{-| Work out all extents before symbol lookup or any allocation for the inputs. -}
prepareRuns :: [ForeignBound] -> [NativeArgument] -> IO (Either ForeignCallFailure PreparedRuns)
prepareRuns bounds arguments = do
  entries <- traverse prepare
    [ (index, crossing, mutable, elements)
    | (index, (crossing, False, CrossedRun mutable elements)) <- zip [0 ..] arguments ]
  pure $ do
    runs <- Map.fromList <$> sequence entries
    mapM_ (checkBound runs) bounds
    pure (PreparedRuns runs)
 where
  slots = Map.fromList (zip [0 ..] arguments)
  prepare (index, crossing, mutable, elements) = do
    formed <- runLayout crossing
    pure $ do
      layout <- formed
      let count = length elements
      bytes <- maybe (Left ForeignExtentFailure) Right (runByteSize layout (toInteger count))
      pure (index, InputRun layout mutable elements count bytes)
  checkBound runs bound = do
    requested <- case Map.lookup (boundLength bound) slots of
      Just (SignedCrossing _, False, CrossedInteger held) | held >= 0 -> Right (toInteger held)
      Just (UnsignedCrossing _, False, CrossedInteger held) -> Right (toInteger (fromIntegral held :: Word64))
      _ -> Left ForeignExtentFailure
    mapM_ (checkExtent requested runs (boundUnit bound)) (boundTargets bound)
  checkExtent requested runs unit index =
    case Map.lookup index runs of
      Just (InputRun _ _ _ count bytes) ->
        covers requested (case unit of
          ExtentElements -> count
          ExtentBytes -> bytes)
      Nothing -> case Map.lookup index slots of
        Just (BytesCrossing, False, CrossedBytes bytes) -> covers requested (ByteString.length bytes)
        Just (NothingCrossing, False, CrossedPointer pointer) | pointer == nullPtr -> covers requested (0 :: Int)
        _ -> Left ForeignExtentFailure
  covers requested available
    | requested <= toInteger available = Right ()
    | otherwise = Left ForeignExtentFailure

withPreparedRuns
  :: PreparedRuns -> [NativeArgument]
  -> ([NativeArgument] -> IO (Either ForeignCallFailure ForeignCallResult))
  -> IO (Either ForeignCallFailure ForeignCallResult)
withPreparedRuns (PreparedRuns runs) original call
  | Map.null runs = call original
  | otherwise = go [] (zip [0 ..] original)
 where
  go held [] = call (reverse held)
  go held ((index, originalArg) : rest) = case Map.lookup index runs of
    Nothing -> go (originalArg : held) rest
    Just (InputRun layout mutable elements _ _) -> do
      outcome <- withInputRun layout mutable elements $ \pointer ->
        go ((NothingCrossing, False, CrossedPointer pointer) : held) rest
      pure $ case outcome of
        Left problem -> Left problem
        Right (result, _) | not mutable -> result
        Right (result, Right copied) -> mergeCopy index copied result
        Right (result, Left problem) -> case result of
          Left previous -> Left previous
          Right (produced, slots, copies) ->
            Left (PostCallFailure problem (outputHandles produced slots) copies)
  mergeCopy index copied outcome =
    let updated copies = sortOn fst ((index, CrossedRun True copied) : copies)
     in case outcome of
          Right (produced, slots, copies) -> Right (produced, slots, updated copies)
          Left (PostCallFailure problem handles copies) -> Left (PostCallFailure problem handles (updated copies))
          Left problem -> Left problem
  outputHandles produced slots =
    [(Nothing, owner, address) | CrossedHandle owner address <- [produced], address /= 0]
      <> [ (Just index, owner, address)
         | (index, Just (CrossedHandle owner address)) <- zip outputPositions slots, address /= 0 ]
  outputPositions = [index | (index, (_, True, _)) <- zip [0 ..] original]

runLayout :: Crossing -> IO (Either ForeignCallFailure RunLayout)
runLayout kind
  | not (isLoanPointee kind) = pure (Left badLayout)
  | otherwise = withArray shape $ \shapeData ->
      withArray kinds $ \kindData ->
        allocaArray count $ \offsets ->
          alloca $ \stride -> do
            status <- c_runLayout shapeData (fromIntegral (length shape)) kindData (fromIntegral count) offsets stride
            if status /= 0
              then pure (Left badLayout)
              else do
                size <- peek stride
                if toInteger size > toInteger (maxBound :: Int)
                  then pure (Left badLayout)
                  else Right . RunLayout kind (fromIntegral size) kinds <$> peekArray count offsets
 where
  shape = recordShape kind
  kinds = leafKinds kind
  count = length kinds

{-| Bounds are computed before address arithmetic, including when C supplies the count. -}
runByteSize :: RunLayout -> Integer -> Maybe Int
runByteSize (RunLayout _ stride _ _) count
  | count >= 0 && bytes <= toInteger (maxBound :: Int) = Just (fromInteger bytes)
  | otherwise = Nothing
 where
  bytes = count * toInteger stride

withInputRun
  :: RunLayout -> Bool -> [CrossedValue] -> (Ptr () -> IO a)
  -> IO (Either ForeignCallFailure (a, Either ForeignCallFailure [CrossedValue]))
withInputRun layout@(RunLayout kind stride kinds offsets) mutable values call =
  case runByteSize layout count of
    Nothing -> pure (Left ForeignExtentFailure)
    Just bytes -> bracket (mallocBytes (max 1 bytes)) free $ \buffer ->
      withArray offsets $ \offsetData ->
        withArray kinds $ \kindData -> do
          prepared <- copyElements offsetData kindData buffer values
          case prepared of
            Left problem -> pure (Left problem)
            Right () -> do
              result <- call buffer
              held <- if mutable then readRun layout buffer count else pure (Right [])
              pure (Right (result, held))
 where
  count = toInteger (length values)
  copyElements _ _ _ [] = pure (Right ())
  copyElements offsetData kindData element (value : rest) = do
    let fields = case kind of
          RecordCrossing _ _ -> map snd (recordFields kind value)
          _ -> [value]
    case traverse carrier fields of
      Just carriers | length carriers == length kinds -> do
        status <- withArray (map fst carriers) $ \integers ->
          withArray (map (CDouble . snd) carriers) $ \doubles ->
            c_runFields element (fromIntegral (length kinds)) offsetData kindData integers doubles 0
        if status /= 0
          then pure (Left badLayout)
          else copyElements offsetData kindData (element `plusPtr` stride) rest
      _ -> pure (Left badLayout)
  carrier value = case value of
    CrossedInteger held -> Just (held, 0)
    CrossedDouble held -> Just (0, held)
    _ -> Nothing

readRun :: RunLayout -> Ptr () -> Integer -> IO (Either ForeignCallFailure [CrossedValue])
readRun layout@(RunLayout kind stride kinds offsets) buffer count =
  case runByteSize layout count of
    Nothing -> pure (Left ForeignExtentFailure)
    Just _ -> withArray offsets $ \offsetData ->
      withArray kinds $ \kindData ->
        allocaArray fields $ \integers ->
          allocaArray fields $ \doubles -> do
            let collect _ 0 taken = pure (Right (reverse taken))
                collect element remaining taken = do
                  status <- c_runFields element (fromIntegral fields) offsetData kindData integers doubles 1
                  if status /= 0
                    then pure (Left badLayout)
                    else do
                      rawInts <- peekArray fields integers
                      rawDoubles <- peekArray fields doubles
                      decoded <- decode (zip rawInts [held | CDouble held <- rawDoubles])
                      case decoded of
                        Left problem -> pure (Left problem)
                        Right value -> collect (element `plusPtr` stride) (remaining - 1) (value : taken)
            collect buffer (fromInteger count :: Int) []
 where
  fields = length kinds
  decode carriers = case (kind, carriers) of
    (RecordCrossing _ _, _) -> fmap (fmap fst) (rebuildRecord kind carriers)
    (_, [(integer, double)]) -> received kind integer double
    _ -> pure (Left badLayout)

badLayout :: ForeignCallFailure
badLayout = CallAssemblyFailure "the foreign run has no valid ABI layout"

