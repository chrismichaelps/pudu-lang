{-| High-performance flat hash table with 1-byte control metadata and fingerprint matching. -}
module Pudu.Runtime.SwissTable
  ( SwissTable (..)
  , emptyTable
  , insertTable
  , lookupTable
  , deleteTable
  , entriesTable
  , sizeTable
  , ctrlEmpty
  , ctrlDeleted
  , getCtrlByte
  , setCtrlByte
  , hashWord64
  , h2Fingerprint
  ) where

import Data.Bits ((.&.), (.|.), complement, countTrailingZeros, shiftL, shiftR, xor)
import qualified Data.IntMap.Strict as IntMap
import Data.Word (Word8, Word64)

ctrlEmpty :: Word8
ctrlEmpty = 0xFF

ctrlDeleted :: Word8
ctrlDeleted = 0xFE

emptyWord64 :: Word64
emptyWord64 = 0xFFFFFFFFFFFFFFFF

kConstant :: Word64
kConstant = 0x0101010101010101

highBits :: Word64
highBits = 0x8080808080808080

h2Fingerprint :: Word64 -> Word8
h2Fingerprint h = fromIntegral ((h `shiftR` 57) .&. 0x7F)

hashWord64 :: Word64 -> Word64
hashWord64 w =
  let w1 = (w `xor` (w `shiftR` 30)) * 0xBF58476D1CE4E5B9
      w2 = (w1 `xor` (w1 `shiftR` 27)) * 0x94D049BB133111EB
   in w2 `xor` (w2 `shiftR` 31)

matchByte :: Word8 -> Word64 -> Word64
matchByte target w =
  let rep = fromIntegral target * kConstant
      diff = w `xor` rep
   in (diff - kConstant) .&. complement diff .&. highBits

matchEmpty :: Word64 -> Word64
matchEmpty w =
  let emptyDiff = complement w
   in (emptyDiff - kConstant) .&. w .&. highBits

matchDeleted :: Word64 -> Word64
matchDeleted w =
  let rep = 0xFEFEFEFEFEFEFEFE
      diff = w `xor` rep
   in (diff - kConstant) .&. complement diff .&. highBits

getCtrlByte :: IntMap.IntMap Word64 -> Int -> Word8
getCtrlByte ctrl slot =
  let wordIdx = slot `shiftR` 3
      byteIdx = slot .&. 7
      w = IntMap.findWithDefault emptyWord64 wordIdx ctrl
   in fromIntegral ((w `shiftR` (byteIdx * 8)) .&. 0xFF)

setCtrlByte :: IntMap.IntMap Word64 -> Int -> Word8 -> IntMap.IntMap Word64
setCtrlByte ctrl slot b =
  let wordIdx = slot `shiftR` 3
      byteIdx = slot .&. 7
      w = IntMap.findWithDefault emptyWord64 wordIdx ctrl
      cleared = w .&. complement (0xFF `shiftL` (byteIdx * 8))
      newW = cleared .|. (fromIntegral b `shiftL` (byteIdx * 8))
   in IntMap.insert wordIdx newW ctrl

data SwissTable v = SwissTable
  { stCapacity :: !Int
  , stSize     :: !Int
  , stCtrl     :: !(IntMap.IntMap Word64)
  , stSlots    :: !(IntMap.IntMap (Word64, v))
  } deriving (Eq, Show)

emptyTable :: Int -> SwissTable v
emptyTable minCap =
  let cap = max 16 (nextPowerOfTwo minCap)
   in SwissTable
        { stCapacity = cap
        , stSize = 0
        , stCtrl = IntMap.empty
        , stSlots = IntMap.empty
        }

nextPowerOfTwo :: Int -> Int
nextPowerOfTwo n = go 16
 where
  go c = if c >= n then c else go (c * 2)

sizeTable :: SwissTable v -> Int
sizeTable = stSize

entriesTable :: SwissTable v -> [(Word64, v)]
entriesTable = IntMap.elems . stSlots

lookupTable :: Word64 -> SwissTable v -> Maybe v
lookupTable key table
  | stSize table == 0 = Nothing
  | otherwise = probeGroup startGroup 0
 where
  cap = stCapacity table
  ctrl = stCtrl table
  slots = stSlots table
  numGroups = cap `shiftR` 3
  groupMask = numGroups - 1
  h = hashWord64 key
  h2 = h2Fingerprint h
  startGroup = fromIntegral ((h `shiftR` 3) .&. fromIntegral groupMask)

  probeGroup g step
    | step >= numGroups = Nothing
    | otherwise =
        let w = IntMap.findWithDefault emptyWord64 g ctrl
            matches = matchByte h2 w
         in checkMatches matches g (matchEmpty w) step

  checkMatches 0 g emptyMask step
    | emptyMask /= 0 = Nothing
    | otherwise = probeGroup ((g + 1) .&. groupMask) (step + 1)
  checkMatches mask g emptyMask step =
    let bitIdx = countTrailingZeros mask
        byteIdx = bitIdx `shiftR` 3
        slot = (g `shiftL` 3) .|. byteIdx
     in case IntMap.lookup slot slots of
          Just (k, v) | k == key -> Just v
          _ -> checkMatches (mask .&. (mask - 1)) g emptyMask step

insertTable :: Word64 -> v -> SwissTable v -> SwissTable v
insertTable key value table
  | (stSize table + 1) * 4 > stCapacity table * 3 =
      let newCap = stCapacity table * 2
          rehashed = emptyTable newCap
          entries = IntMap.elems (stSlots table)
          inserted = foldl (\t (k, v) -> rawInsert k v t) rehashed entries
       in rawInsert key value inserted
  | otherwise = rawInsert key value table

rawInsert :: Word64 -> v -> SwissTable v -> SwissTable v
rawInsert key value table = probeGroup startGroup 0 Nothing
 where
  cap = stCapacity table
  ctrl = stCtrl table
  slots = stSlots table
  numGroups = cap `shiftR` 3
  groupMask = numGroups - 1
  h = hashWord64 key
  h2 = h2Fingerprint h
  startGroup = fromIntegral ((h `shiftR` 3) .&. fromIntegral groupMask)

  probeGroup g step firstTombstone
    | step >= numGroups = table
    | otherwise =
        let w = IntMap.findWithDefault emptyWord64 g ctrl
            matches = matchByte h2 w
         in checkMatches matches g w step firstTombstone

  checkMatches 0 g w step firstTombstone =
    let emptyMask = matchEmpty w
        tombMask = matchDeleted w
        newFt = case firstTombstone of
          Just _ -> firstTombstone
          Nothing | tombMask /= 0 ->
            let bIdx = countTrailingZeros tombMask `shiftR` 3
             in Just ((g `shiftL` 3) .|. bIdx)
          Nothing -> Nothing
     in if emptyMask /= 0
          then
            let firstEmpty = countTrailingZeros emptyMask `shiftR` 3
                targetSlot = maybe ((g `shiftL` 3) .|. firstEmpty) id newFt
                newCtrl = setCtrlByte ctrl targetSlot h2
                newSlots = IntMap.insert targetSlot (key, value) slots
             in table { stSize = stSize table + 1, stCtrl = newCtrl, stSlots = newSlots }
          else probeGroup ((g + 1) .&. groupMask) (step + 1) newFt

  checkMatches mask g w step firstTombstone =
    let bitIdx = countTrailingZeros mask
        byteIdx = bitIdx `shiftR` 3
        slot = (g `shiftL` 3) .|. byteIdx
     in case IntMap.lookup slot slots of
          Just (existingKey, _) | existingKey == key ->
            table { stSlots = IntMap.insert slot (key, value) slots }
          _ -> checkMatches (mask .&. (mask - 1)) g w step firstTombstone

deleteTable :: Word64 -> SwissTable v -> SwissTable v
deleteTable key table
  | stSize table == 0 = table
  | otherwise = probeGroup startGroup 0
 where
  cap = stCapacity table
  ctrl = stCtrl table
  slots = stSlots table
  numGroups = cap `shiftR` 3
  groupMask = numGroups - 1
  h = hashWord64 key
  h2 = h2Fingerprint h
  startGroup = fromIntegral ((h `shiftR` 3) .&. fromIntegral groupMask)

  probeGroup g step
    | step >= numGroups = table
    | otherwise =
        let w = IntMap.findWithDefault emptyWord64 g ctrl
            matches = matchByte h2 w
         in checkMatches matches g (matchEmpty w) step

  checkMatches 0 g emptyMask step
    | emptyMask /= 0 = table
    | otherwise = probeGroup ((g + 1) .&. groupMask) (step + 1)
  checkMatches mask g emptyMask step =
    let bitIdx = countTrailingZeros mask
        byteIdx = bitIdx `shiftR` 3
        slot = (g `shiftL` 3) .|. byteIdx
     in case IntMap.lookup slot slots of
          Just (existingKey, _) | existingKey == key ->
            let newCtrl = setCtrlByte ctrl slot ctrlDeleted
                newSlots = IntMap.delete slot slots
             in table { stSize = stSize table - 1, stCtrl = newCtrl, stSlots = newSlots }
          _ -> checkMatches (mask .&. (mask - 1)) g emptyMask step
