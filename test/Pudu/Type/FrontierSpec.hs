{-| @Test.Type.Frontier — ordered pending work and deferred numeric context laws. -}
module Pudu.Type.FrontierSpec (frontierProperties) where

import Data.List (nub, sort)
import Pudu.Type.Check.Common (codes)
import Pudu.Type.Frontier (splitSince, splitBetween)
import Test.QuickCheck
  ( Property, chooseInt, conjoin, counterexample, forAll, listOf, (===) )

frontierProperties :: [(String, IO Property)]
frontierProperties =
  [ ("literal frontier selection preserves ordered pending work", selection)
  , ("literal frontier selection never walks an unrelated older suffix", boundedWork)
  , ("literal frontier selection preserves enclosing integer contexts", contexts)
  ]

selection :: IO Property
selection = pure $ forAll (listOf (chooseInt (0, 2000))) $ \identities ->
  forAll (chooseInt (0, 2001)) $ \start ->
    forAll (chooseInt (0, 2001)) $ \end ->
      let pending = reverse (sort (nub identities))
          inInterval value = start <= value && value < end
       in conjoin
            [ splitSince id start pending ===
                (filter (>= start) pending, filter (< start) pending)
            , splitBetween id start end pending ===
                (filter inInterval pending, filter (not . inInterval) pending)
            ]

boundedWork :: IO Property
boundedWork =
  let older = (-1) : error "literal frontier traversed an unrelated suffix"
      (recent, retained) = splitSince id 1 ([5, 3, 2] <> older)
      (interval, untouched) = splitBetween id 1 3 ([5, 3, 2, 1] <> older)
   in pure $ conjoin
        [ recent === [5, 3, 2]
        , take 1 retained === [-1]
        , interval === [2, 1]
        , take 3 untouched === [5, 3, -1]
        , take 2 (snd (splitBetween id 4 2 ([5, 3] <> older))) === [5, 3]
        ]

contexts :: IO Property
contexts = do
  results <- traverse codes
    [ ["module M", "fn run() -> (Int16, Int8) { (300, if true { 127 } else { 0 }) }"]
    , ["module M", "fn run() -> (Int16, Int8) {",
        "(300, match true {", "case true => 127", "case false => 0", "})", "}"]
    , ["module M", "fn run() -> (Int16, Int8) {",
        "(300, if true { if false { -128 } else { 127 } } else { 0 })", "}"]
    , ["module M", "fn run() -> (Int16, Int8) { (300, if true { 128 } else { 0 }) }"]
    , ["module M", "fn run() -> (Int16, Int8) { (300, -129) }"]
    ]
  pure $ counterexample "frontier selection retains width context and overflow diagnostics"
    (results === [[], [], [], ["E3018"], ["E3018"]])
