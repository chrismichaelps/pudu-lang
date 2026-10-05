{-| @Runtime.SeriesMap — persistent constant-payload series with sparse overrides. -}
module Pudu.Runtime.SeriesMap
  ( SeriesMap
  , empty
  , singleton
  , lookup
  , insertLookupWithKey
  , toAscList
  , storedEntryCount
  ) where

import Prelude hiding (lookup)
import Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as IntMap

{-| Constructors preserve a positive stride and a fully populated base series.
    Point cardinality is capped at four, avoiding linear size checks on updates. -}
data SeriesMap a
  = Points !Int !(IntMap a)
  | Series !Int !Int !Int !a !(IntMap a)
  deriving stock (Show)

empty :: SeriesMap a
empty = Points 0 IntMap.empty

singleton :: Int -> a -> SeriesMap a
singleton key value = Points 1 (IntMap.singleton key value)

lookup :: Int -> SeriesMap a -> Maybe a
lookup key (Points _ points) = IntMap.lookup key points
lookup key (Series first lastKey stride base points) = case IntMap.lookup key points of
  Just value -> Just value
  Nothing | inSeries key first lastKey stride -> Just base
  _ -> Nothing

{-| Equivalence must preserve representation, not only semantic equality.
    Duplicate insertion always combines the original payload with the incoming one. -}
insertLookupWithKey :: (a -> a -> Bool) -> (Int -> a -> a -> a)
  -> Int -> a -> SeriesMap a -> (Maybe a, SeriesMap a)
insertLookupWithKey same combine key incoming (Points count points) =
  let (old, next) = IntMap.insertLookupWithKey combine key incoming points
      nextCount = case old of
        Nothing -> min 4 (count + 1)
        Just _ -> count
      result = if nextCount == 3 then promote same next else Points nextCount next
   in (old, result)
insertLookupWithKey same combine key incoming (Series first lastKey stride base points) =
  case IntMap.lookup key points of
    Just old -> replaced old
    Nothing
      | inSeries key first lastKey stride -> replaced base
      | same base incoming && key < first && distance first key == fromIntegral stride ->
          (Nothing, Series key lastKey stride base points)
      | same base incoming && key > lastKey && distance key lastKey == fromIntegral stride ->
          (Nothing, Series first key stride base points)
      | otherwise -> (Nothing, Series first lastKey stride base (IntMap.insert key incoming points))
 where
  replaced old =
    let value = combine key incoming old
     in (Just old, Series first lastKey stride base (IntMap.insert key value points))

promote :: (a -> a -> Bool) -> IntMap a -> SeriesMap a
promote same points = case IntMap.toAscList points of
  [(first, base), (middle, second), (lastKey, third)]
    | let stride = distance middle first
    , stride > 0 && stride <= fromIntegral (maxBound :: Int)
    , stride == distance lastKey middle
    , same base second && same base third ->
        Series first lastKey (fromIntegral stride) base IntMap.empty
  _ -> Points 3 points

inSeries :: Int -> Int -> Int -> Int -> Bool
inSeries key first lastKey stride =
  key >= first && key <= lastKey && distance key first `mod` fromIntegral stride == 0

{-| Ordered signed endpoints can span more than maxBound :: Int; Word holds
    their exact distance without overflowing signed subtraction. -}
distance :: Int -> Int -> Word
distance greater lesser = fromIntegral greater - fromIntegral lesser

toAscList :: SeriesMap a -> [(Int, a)]
toAscList (Points _ points) = IntMap.toAscList points
toAscList (Series first lastKey stride base points) = merge (members first) (IntMap.toAscList points)
 where
  members current = (current, base) :
    if current == lastKey then [] else members (current + stride)
  merge [] sparse = sparse
  merge series [] = series
  merge series@(member@(key, _) : rest) sparse@(point@(other, _) : remaining) =
    case compare key other of
      LT -> member : merge rest sparse
      EQ -> point : merge rest remaining
      GT -> point : merge series remaining

{-| Stored payload entries, excluding represented keys and structural metadata.
    This linear observer supplies deterministic compression evidence, not bytes. -}
storedEntryCount :: SeriesMap a -> Int
storedEntryCount (Points _ points) = IntMap.size points
storedEntryCount (Series _ _ _ _ points) = 1 + IntMap.size points
