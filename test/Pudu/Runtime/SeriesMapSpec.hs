{-| @Test.Runtime.SeriesMapSpec — persistent insertion and signed-boundary oracles. -}
module Pudu.Runtime.SeriesMapSpec (testSeriesMaps) where

import qualified Data.IntMap.Strict as IntMap
import qualified Pudu.Runtime.SeriesMap as SeriesMap
import Test.QuickCheck (Property, chooseInt, conjoin, counterexample, forAll, listOf, (===))

type Payload = (Int, Int)
type Operation = (Int, Payload)

testSeriesMaps :: IO Property
testSeriesMaps = pure $ conjoin
  [ forAll (listOf operation) $ \operations -> conjoin
      [ history (prefix <> operations) | prefix <- prefixes ]
  , conjoin (map history boundaries)
  , counterexample "ascending and descending runs retain one base payload" $ conjoin
      [ let series = build keys
         in conjoin
              [ SeriesMap.storedEntryCount series === 1
              , SeriesMap.toAscList series === IntMap.toAscList (IntMap.fromList [(key, (1, 0)) | key <- keys])
              ]
      | keys <- [[-5000 .. 5000], reverse [-5000 .. 5000]] ]
  , let base = build [-20, -18 .. 20]
        (_, edited) = SeriesMap.insertLookupWithKey (==) combine 0 (1, 9) base
        (_, gap) = SeriesMap.insertLookupWithKey (==) combine 1 (1, 0) edited
     in counterexample "sparse changes share the original series" $ conjoin
          [ SeriesMap.storedEntryCount base === 1
          , SeriesMap.storedEntryCount edited === 2
          , SeriesMap.storedEntryCount gap === 3
          , SeriesMap.lookup 0 base === Just (1, 0)
          , SeriesMap.lookup 0 edited === Just (2, 9)
          , SeriesMap.lookup 1 base === Nothing
          , SeriesMap.lookup 1 gap === Just (1, 0)
          ]
  ]
 where
  operation = do
    key <- chooseInt (-100, 100)
    count <- chooseInt (1, 4)
    representative <- chooseInt (0, 3)
    pure (key, (count, representative))
  prefixes = [[], [(key, (1, 0)) | key <- [-40, -38 .. 40]], [(key, (1, 0)) | key <- [40, 38 .. -40]]]
  boundaries =
    [ [(2, (1, 0)), (-2, (1, 0)), (0, (1, 0)), (3, (1, 0)), (4, (2, 7)), (4, (1, 0)), (6, (1, 0))]
    , [(key, (1, 0)) | key <- [minBound, minBound + 1, minBound + 2, minBound + 3, -1, maxBound]]
    , [(key, (1, 0)) | key <- [maxBound, maxBound - 1, maxBound - 2, maxBound - 3, 0, minBound]]
    , [(key, (1, 0)) | key <- [minBound, -1, maxBound - 1, 0, maxBound, minBound + 1]]
    , [(0, (1, 0)), (2, (1, 0)), (4, (1, 0)), (8, (1, 7)), (6, (1, 0)), (8, (1, 0))]
    , [(0, (1, 0)), (2, (1, 7)), (4, (1, 0)), (2, (1, 0)), (6, (1, 0))]
    ]

combine :: Int -> Payload -> Payload -> Payload
combine _ (delta, representative) (count, _) = (count + delta, representative)

build :: [Int] -> SeriesMap.SeriesMap Payload
build = foldl' (\held key -> snd (SeriesMap.insertLookupWithKey (==) combine key (1, 0) held)) SeriesMap.empty

history :: [Operation] -> Property
history operations = conjoin checks
 where
  (_, _, _, checks) = foldl' step (SeriesMap.empty, IntMap.empty, [], []) operations
  step (held, ordinary, snapshots, previousChecks) (key, incoming) =
    let (old, next) = SeriesMap.insertLookupWithKey (==) combine key incoming held
        (expectedOld, expected) = IntMap.insertLookupWithKey combine key incoming ordinary
        retained = (next, expected) : snapshots
        currentChecks =
          [ counterexample "touched original payload" (old === expectedOld)
          , conjoin [SeriesMap.lookup probe next === IntMap.lookup probe expected
              | probe <- [key, minBound, maxBound, -3, 0, 3]]
          , conjoin [SeriesMap.toAscList snapshot === IntMap.toAscList oracle | (snapshot, oracle) <- retained]
          ]
     in (next, expected, retained, currentChecks <> previousChecks)
