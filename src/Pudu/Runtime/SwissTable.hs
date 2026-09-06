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

import Data.Bits ((.&.), (.|.), complement, shiftL, shiftR, xor)
import qualified Data.IntMap.Strict as IntMap
import Data.Word (Word8, Word64)

ctrlEmpty :: Word8
ctrlEmpty = 0xFF

ctrlDeleted :: Word8
ctrlDeleted = 0xFE

emptyWord64 :: Word64
emptyWord64 = 0xFFFFFFFFFFFFFFFF

h2Fingerprint :: Word64 -> Word8
h2Fingerprint h = fromIntegral ((h `shiftR` 57) .&. 0x7F)

hashWord64 :: Word64 -> Word64
hashWord64 w =
  let w1 = (w `xor` (w `shiftR` 30)) * 0xBF58476D1CE4E5B9
      w2 = (w1 `xor` (w1 `shiftR` 27)) * 0x94D049BB133111EB
   in w2 `xor` (w2 `shiftR` 31)

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
  | otherwise = probe startSlot 0
 where
  cap = stCapacity table
  ctrl = stCtrl table
  slots = stSlots table
  mask = cap - 1
  h = hashWord64 key
  h2 = h2Fingerprint h
  startSlot = fromIntegral (h .&. fromIntegral mask)

  probe slot step
    | step >= cap = Nothing
    | otherwise =
        let c = getCtrlByte ctrl slot
         in if c == ctrlEmpty
              then Nothing
              else if c == h2
                then case IntMap.lookup slot slots of
                  Just (k, v) | k == key -> Just v
                  _ -> probe ((slot + 1) .&. mask) (step + 1)
                else probe ((slot + 1) .&. mask) (step + 1)

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
rawInsert key value table = go startSlot 0 Nothing
 where
  cap = stCapacity table
  ctrl = stCtrl table
  slots = stSlots table
  mask = cap - 1
  h = hashWord64 key
  h2 = h2Fingerprint h
  startSlot = fromIntegral (h .&. fromIntegral mask)

  go slot step firstTombstone
    | step >= cap = table
    | otherwise =
        let c = getCtrlByte ctrl slot
         in if c == ctrlEmpty
              then
                let targetSlot = maybe slot id firstTombstone
                    newCtrl = setCtrlByte ctrl targetSlot h2
                    newSlots = IntMap.insert targetSlot (key, value) slots
                 in table
                      { stSize = stSize table + 1
                      , stCtrl = newCtrl
                      , stSlots = newSlots
                      }
              else if c == ctrlDeleted
                then
                  let ft = maybe (Just slot) Just firstTombstone
                   in go ((slot + 1) .&. mask) (step + 1) ft
              else if c == h2
                then case IntMap.lookup slot slots of
                  Just (k, _) | k == key ->
                    table { stSlots = IntMap.insert slot (key, value) slots }
                  _ -> go ((slot + 1) .&. mask) (step + 1) firstTombstone
              else go ((slot + 1) .&. mask) (step + 1) firstTombstone

deleteTable :: Word64 -> SwissTable v -> SwissTable v
deleteTable key table
  | stSize table == 0 = table
  | otherwise = go startSlot 0
 where
  cap = stCapacity table
  ctrl = stCtrl table
  slots = stSlots table
  mask = cap - 1
  h = hashWord64 key
  h2 = h2Fingerprint h
  startSlot = fromIntegral (h .&. fromIntegral mask)

  go slot step
    | step >= cap = table
    | otherwise =
        let c = getCtrlByte ctrl slot
         in if c == ctrlEmpty
              then table
              else if c == h2
                then case IntMap.lookup slot slots of
                  Just (k, _) | k == key ->
                    table
                      { stSize = stSize table - 1
                      , stCtrl = setCtrlByte ctrl slot ctrlDeleted
                      , stSlots = IntMap.delete slot slots
                      }
                  _ -> go ((slot + 1) .&. mask) (step + 1)
                else go ((slot + 1) .&. mask) (step + 1)
