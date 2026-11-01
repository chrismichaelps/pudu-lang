{-| @Eval.Record — prepares canonical construction after ordered field effects. -}
module Pudu.Eval.Record (recordConstructor) where

import Data.List (sortOn)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Eval.Value (Value (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)

{-| Choose immutable identity and storage order before executing initializers.
    Sorting completed fields never changes the order of their effects. -}
recordConstructor :: ModuleName -> [Text] -> ([(Text, Value)] -> Value)
recordConstructor path authored = case path of
  ModuleName ("::sum::" :| (owner : label : declared)) ->
    let arrange
          | authored == declared = id
          | otherwise =
              let ranks = Map.fromList (zip declared [0 :: Int ..])
               in sortOn (\(name, _) -> Map.findWithDefault maxBound name ranks)
     in NamedSumValue owner label . arrange
  _ -> RecordValue (moduleNameText path)
