{-| @Eval.Drop — runs `drop` for values whose ownership ends -}
module Pudu.Eval.Drop
  ( dropValue
  , implementsDropAnywhere
  ) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Call (CallNeeds, callClosureLending)
import Pudu.Eval.Env (Evaluator, lookupMethod)
import Pudu.Eval.Loop (firstBound, receiverOwners)
import Pudu.Eval.Place (Lent (..))
import Pudu.Eval.TypeWitness (withSelf)
import Pudu.Eval.Value (Value (..))

{-| A value's own `drop` runs first, with the value still whole; its parts are
    dropped after it, in the order the declaration lists them. Ownership
    checking admits a value that needs drop only where it has one owner, so
    each value reached here is dropped once. -}
dropValue :: CallNeeds -> Value -> Evaluator ()
dropValue needs value = case value of
  RecordValue _ fields -> own >> mapM_ (dropValue needs . snd) fields
  SumValue _ _ payload -> own >> mapM_ (dropValue needs) payload
  NamedSumValue _ _ fields -> own >> mapM_ (dropValue needs . snd) fields
  TupleValue members -> mapM_ (dropValue needs) members
  _ -> pure ()
 where
  own = do
    owners <- receiverOwners value
    found <- firstBound (\owner -> fmap ((,) owner) <$> lookupMethod (dropKey owner)) owners
    case found of
      Just (owner, FunctionValue closure) -> do
        let selected = withSelf (TypeWitnessValue owner []) closure
        _ <- callClosureLending needs selected [value] (Lent Nothing [Nothing]) Nothing
        pure ()
      _ -> pure ()

{-| The key an implementation of the prelude `Drop` installs its member under. -}
dropKey :: Text -> Text
dropKey owner = dropPrefix <> owner <> ".drop"

dropPrefix :: Text
dropPrefix = "Drop."

{-| Whether any installed implementation is one of `Drop`, so a program that
    has none pays nothing for scopes. -}
implementsDropAnywhere :: Map.Map Text Value -> Bool
implementsDropAnywhere = any (Text.isPrefixOf dropPrefix) . Map.keys
