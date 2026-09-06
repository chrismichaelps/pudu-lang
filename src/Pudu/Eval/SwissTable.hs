{-| Builtin evaluators for high-performance flat hash tables. -}
module Pudu.Eval.SwissTable
  ( callSwissTableEmpty
  , callSwissTableLookup
  , callSwissTableInsert
  , callSwissTableDelete
  , callSwissTableEntries
  , callSwissTableSize
  ) where

import Data.Bits ((.&.), (.|.), complement, shiftL, shiftR)
import qualified Data.IntMap.Strict as IntMap
import qualified Data.Sequence as Seq
import Data.Word (Word8, Word64)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..), intOf)
import Pudu.IntegerLiteral (IntegerKind (UnsignedKind))
import qualified Pudu.Runtime.SwissTable as Swiss
import Pudu.Source (Span)

someValue :: Value -> Value
someValue v = VariantValue "Some" [v]

noneValue :: Value
noneValue = VariantValue "None" []

emptyWord64 :: Word64
emptyWord64 = 0xFFFFFFFFFFFFFFFF

readCtrlByte :: IntMap.IntMap Value -> Int -> Word8
readCtrlByte ctrlMap slot =
  let wordIdx = slot `shiftR` 3
      byteIdx = slot .&. 7
      w = case IntMap.lookup wordIdx ctrlMap of
            Just (IntValue _ n) -> fromIntegral n :: Word64
            _ -> emptyWord64
   in fromIntegral ((w `shiftR` (byteIdx * 8)) .&. 0xFF)

writeCtrlByte :: IntMap.IntMap Value -> Int -> Word8 -> IntMap.IntMap Value
writeCtrlByte ctrlMap slot b =
  let wordIdx = slot `shiftR` 3
      byteIdx = slot .&. 7
      w = case IntMap.lookup wordIdx ctrlMap of
            Just (IntValue _ n) -> fromIntegral n :: Word64
            _ -> emptyWord64
      cleared = w .&. complement (0xFF `shiftL` (byteIdx * 8))
      newW = cleared .|. (fromIntegral b `shiftL` (byteIdx * 8))
   in IntMap.insert wordIdx (IntValue (UnsignedKind 64) (toInteger newW)) ctrlMap

decodeTable :: Value -> Maybe (Int, Int, IntMap.IntMap Value, IntMap.IntMap Value)
decodeTable (RecordValue "FlatMap" fields) = do
  capVal <- lookup "capacity" fields
  countVal <- lookup "count" fields
  ctrlVal <- lookup "ctrl" fields
  slotsVal <- lookup "slots" fields
  cap <- case capVal of IntValue _ n -> Just (fromIntegral n); _ -> Nothing
  count <- case countVal of IntValue _ n -> Just (fromIntegral n); _ -> Nothing
  ctrl <- case ctrlVal of BucketsValue m -> Just m; _ -> Nothing
  slots <- case slotsVal of BucketsValue m -> Just m; _ -> Nothing
  Just (cap, count, ctrl, slots)
decodeTable _ = Nothing

encodeTable :: Int -> Int -> IntMap.IntMap Value -> IntMap.IntMap Value -> Value
encodeTable cap count ctrl slots =
  RecordValue
    "FlatMap"
    [ ("capacity", intOf (fromIntegral cap))
    , ("count", intOf (fromIntegral count))
    , ("ctrl", BucketsValue ctrl)
    , ("slots", BucketsValue slots)
    ]

callSwissTableEmpty :: Span -> [Value] -> Evaluator Value
callSwissTableEmpty spanValue arguments = case arguments of
  [IntValue _ cap]
    | cap < 0 -> abortAt (Just spanValue) "E7004" "capacity cannot be negative" Nothing
    | otherwise ->
        let actualCap = max 16 (nextPowerOfTwo (fromIntegral cap))
         in pure (encodeTable actualCap 0 IntMap.empty IntMap.empty)
  [_] -> abortAt (Just spanValue) "E7001" "swissTableEmpty expects capacity integer" Nothing
  _ -> abortAt (Just spanValue) "E7003" "swissTableEmpty expects one argument" Nothing
 where
  nextPowerOfTwo n = go 16
   where
    go c = if c >= n then c else go (c * 2)

callSwissTableLookup :: Span -> [Value] -> Evaluator Value
callSwissTableLookup spanValue arguments = case arguments of
  [tableVal, IntValue _ rawKey]
    | rawKey >= 0 && rawKey <= toInteger (maxBound :: Word64) ->
        case decodeTable tableVal of
          Just (cap, count, ctrl, slots)
            | count == 0 -> pure noneValue
            | otherwise ->
                let key = fromIntegral rawKey :: Word64
                    mask = cap - 1
                    h = Swiss.hashWord64 key
                    h2 = Swiss.h2Fingerprint h
                    startSlot = fromIntegral (h .&. fromIntegral mask)
                 in pure (probe cap mask ctrl slots h2 key startSlot 0)
          Nothing -> abortAt (Just spanValue) "E7001" "swissTableLookup expects FlatMap" Nothing
    | otherwise -> pure noneValue
  [_, _] -> abortAt (Just spanValue) "E7001" "swissTableLookup expects FlatMap and UInt64 key" Nothing
  _ -> abortAt (Just spanValue) "E7003" "swissTableLookup expects two arguments" Nothing
 where
  probe cap mask ctrl slots h2 key slot step
    | step >= cap = noneValue
    | otherwise =
        let c = readCtrlByte ctrl slot
         in if c == Swiss.ctrlEmpty
              then noneValue
              else if c == h2
                then case IntMap.lookup slot slots of
                  Just (TupleValue [IntValue _ k, val])
                    | fromIntegral k == key -> someValue val
                  _ -> probe cap mask ctrl slots h2 key ((slot + 1) .&. mask) (step + 1)
                else probe cap mask ctrl slots h2 key ((slot + 1) .&. mask) (step + 1)

callSwissTableInsert :: Span -> [Value] -> Evaluator Value
callSwissTableInsert spanValue arguments = case arguments of
  [tableVal, IntValue _ rawKey, val]
    | rawKey >= 0 && rawKey <= toInteger (maxBound :: Word64) ->
        case decodeTable tableVal of
          Just (cap, count, ctrl, slots) ->
            let key = fromIntegral rawKey :: Word64
             in pure (doInsert cap count ctrl slots key val)
          Nothing -> abortAt (Just spanValue) "E7001" "swissTableInsert expects FlatMap" Nothing
    | otherwise -> abortAt (Just spanValue) "E7004" "key out of UInt64 range" Nothing
  [_, _, _] -> abortAt (Just spanValue) "E7001" "swissTableInsert expects FlatMap, UInt64, and value" Nothing
  _ -> abortAt (Just spanValue) "E7003" "swissTableInsert expects three arguments" Nothing
 where
  doInsert cap count ctrl slots key val
    | (count + 1) * 4 > cap * 3 =
        let newCap = cap * 2
            (newCtrl, newSlots) = rehash newCap slots
         in insertInto newCap count newCtrl newSlots key val
    | otherwise = insertInto cap count ctrl slots key val

  insertInto cap count ctrl slots key val =
    let mask = cap - 1
        h = Swiss.hashWord64 key
        h2 = Swiss.h2Fingerprint h
        startSlot = fromIntegral (h .&. fromIntegral mask)
        slotVal = TupleValue [IntValue (UnsignedKind 64) (toInteger key), val]
        go slot step firstTomb
          | step >= cap = encodeTable cap count ctrl slots
          | otherwise =
              let c = readCtrlByte ctrl slot
               in if c == Swiss.ctrlEmpty
                    then
                      let targetSlot = maybe slot id firstTomb
                          updCtrl = writeCtrlByte ctrl targetSlot h2
                          updSlots = IntMap.insert targetSlot slotVal slots
                       in encodeTable cap (count + 1) updCtrl updSlots
                    else if c == Swiss.ctrlDeleted
                      then
                        let ft = maybe (Just slot) Just firstTomb
                         in go ((slot + 1) .&. mask) (step + 1) ft
                    else if c == h2
                      then case IntMap.lookup slot slots of
                        Just (TupleValue [IntValue _ k, _])
                          | fromIntegral k == key ->
                              let updSlots = IntMap.insert slot slotVal slots
                               in encodeTable cap count ctrl updSlots
                        _ -> go ((slot + 1) .&. mask) (step + 1) firstTomb
                    else go ((slot + 1) .&. mask) (step + 1) firstTomb
     in go startSlot 0 Nothing

  rehash newCap oldSlots =
    let mask = newCap - 1
        insertOne (cMap, sMap) slotVal@(TupleValue [IntValue _ k, _]) =
          let key = fromIntegral k :: Word64
              h = Swiss.hashWord64 key
              h2 = Swiss.h2Fingerprint h
              startSlot = fromIntegral (h .&. fromIntegral mask)
              targetSlot = findEmpty newCap mask startSlot 0 cMap
              newCMap = writeCtrlByte cMap targetSlot h2
              newSMap = IntMap.insert targetSlot slotVal sMap
           in (newCMap, newSMap)
        insertOne acc _ = acc
     in IntMap.foldl' insertOne (IntMap.empty, IntMap.empty) oldSlots

  findEmpty cap mask slot step cMap
    | step >= cap = slot
    | readCtrlByte cMap slot == Swiss.ctrlEmpty = slot
    | otherwise = findEmpty cap mask ((slot + 1) .&. mask) (step + 1) cMap

callSwissTableDelete :: Span -> [Value] -> Evaluator Value
callSwissTableDelete spanValue arguments = case arguments of
  [tableVal, IntValue _ rawKey]
    | rawKey >= 0 && rawKey <= toInteger (maxBound :: Word64) ->
        case decodeTable tableVal of
          Just (cap, count, ctrl, slots)
            | count == 0 -> pure (encodeTable cap count ctrl slots)
            | otherwise ->
                let key = fromIntegral rawKey :: Word64
                    mask = cap - 1
                    h = Swiss.hashWord64 key
                    h2 = Swiss.h2Fingerprint h
                    startSlot = fromIntegral (h .&. fromIntegral mask)
                    go slot step
                      | step >= cap = encodeTable cap count ctrl slots
                      | otherwise =
                          let c = readCtrlByte ctrl slot
                           in if c == Swiss.ctrlEmpty
                                then encodeTable cap count ctrl slots
                                else if c == h2
                                  then case IntMap.lookup slot slots of
                                    Just (TupleValue [IntValue _ k, _])
                                      | fromIntegral k == key ->
                                          let updCtrl = writeCtrlByte ctrl slot Swiss.ctrlDeleted
                                              updSlots = IntMap.delete slot slots
                                           in encodeTable cap (count - 1) updCtrl updSlots
                                    _ -> go ((slot + 1) .&. mask) (step + 1)
                                  else go ((slot + 1) .&. mask) (step + 1)
                 in pure (go startSlot 0)
          Nothing -> abortAt (Just spanValue) "E7001" "swissTableDelete expects FlatMap" Nothing
    | otherwise -> pure tableVal
  [_, _] -> abortAt (Just spanValue) "E7001" "swissTableDelete expects FlatMap and UInt64 key" Nothing
  _ -> abortAt (Just spanValue) "E7003" "swissTableDelete expects two arguments" Nothing

callSwissTableEntries :: Span -> [Value] -> Evaluator Value
callSwissTableEntries spanValue arguments = case arguments of
  [tableVal] -> case decodeTable tableVal of
    Just (_, _, _, slots) -> pure (ArrayValue (Seq.fromList (IntMap.elems slots)))
    Nothing -> abortAt (Just spanValue) "E7001" "swissTableEntries expects FlatMap" Nothing
  _ -> abortAt (Just spanValue) "E7003" "swissTableEntries expects one argument" Nothing

callSwissTableSize :: Span -> [Value] -> Evaluator Value
callSwissTableSize spanValue arguments = case arguments of
  [tableVal] -> case decodeTable tableVal of
    Just (_, count, _, _) -> pure (intOf (fromIntegral count))
    Nothing -> abortAt (Just spanValue) "E7001" "swissTableSize expects FlatMap" Nothing
  _ -> abortAt (Just spanValue) "E7003" "swissTableSize expects one argument" Nothing
