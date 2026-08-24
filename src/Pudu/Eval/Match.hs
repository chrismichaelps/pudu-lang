{-| @Eval.Match.Module — matches values against patterns -}
module Pudu.Eval.Match
  ( literalValue
  , matchPattern
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Value (Value (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree (FieldPattern (..), Pattern (..))
import Pudu.IntegerLiteral (ParsedInteger (..), parseIntegerLiteral)

{-| Pattern matching is total: it either produces the bindings the pattern
    introduces or reports that the pattern did not apply. -}
matchPattern :: Located Pattern -> Value -> Maybe [(Text, Value)]
matchPattern (Located _ pattern') value = case pattern' of
  WildcardPattern -> Just []
  BindingPattern name -> Just [(locatedValue name, value)]
  LiteralPattern literal -> if literalValue literal == value then Just [] else Nothing
  RangePattern lower inclusive upper -> matchRange (literalValue lower) inclusive (literalValue upper) value
  TuplePattern members -> case value of
    TupleValue values | length values == length members ->
      concat <$> sequence (zipWith matchPattern members values)
    _ -> Nothing
  ConstructorPattern (ModuleName segments) arguments -> case value of
    VariantValue name payload
      | name == lastSegment segments && length payload == length arguments ->
          concat <$> sequence (zipWith matchPattern arguments payload)
    _ -> Nothing
  RecordPattern _ fields _ -> case value of
    RecordValue _ present -> concat <$> mapM (matchField present) fields
    _ -> Nothing
  AlternativePattern alternatives -> firstMatch alternatives
  InvalidPattern -> Nothing
 where
  firstMatch alternatives = case alternatives of
    [] -> Nothing
    alternative : rest -> case matchPattern alternative value of
      Just bindings -> Just bindings
      Nothing -> firstMatch rest
  matchField present (Located _ field) =
    let name = locatedValue (fieldPatternName field)
     in case lookup name present of
          Nothing -> Nothing
          Just fieldValue -> case fieldPatternValue field of
            Nothing -> Just [(name, fieldValue)]
            Just nested -> matchPattern nested fieldValue

lastSegment :: NonEmpty Text -> Text
lastSegment (first :| rest) = last (first : rest)

matchRange :: Value -> Bool -> Value -> Value -> Maybe [(Text, Value)]
matchRange lower inclusive upper value =
  case (lower, upper, value) of
    (IntValue low, IntValue high, IntValue actual) -> check inclusive low high actual
    (CharValue low, CharValue high, CharValue actual) -> check inclusive low high actual
    (FloatValue low, FloatValue high, FloatValue actual) -> check inclusive low high actual
    _ -> Nothing

check :: Ord a => Bool -> a -> a -> a -> Maybe [(Text, Value)]
check inclusive low high actual
  | actual >= low && (if inclusive then actual <= high else actual < high) = Just []
  | otherwise = Nothing

literalValue :: Tree.Literal -> Value
literalValue literal = case literal of
  Tree.IntegerValue text -> case parseIntegerLiteral text of
    Just ParsedInteger{parsedIntegerValue} -> IntValue parsedIntegerValue
    Nothing -> IntValue 0
  Tree.FloatValue text -> FloatValue (readDouble text)
  Tree.StringValue text -> StrValue text
  Tree.CharValue character -> CharValue character
  Tree.BoolValue flag -> BoolValue flag
  Tree.NullValue -> NullValue

readDouble :: Text -> Double
readDouble text = case reads (Text.unpack (Text.filter (/= '_') text)) of
  (value, _) : _ -> value
  [] -> 0
