{-| @Eval.Match.Module — matches values against patterns -}
module Pudu.Eval.Match
  ( literalValue
  , matchPattern
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Eval.Value (Value (..), intOf)
import Pudu.DecimalLiteral (decimalFromInteger, parseDecimalLiteral)
import Pudu.FloatLiteral
  ( FloatWidth (Float64Width), ParsedFloat (..), parseFloatLiteral )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree (FieldPattern (..), Pattern (..))
import Pudu.IntegerLiteral
  ( IntegerKind (..)
  , IntegerSuffix (..)
  , ParsedInteger (..)
  , defaultIntegerKind
  , parseIntegerLiteral
  )

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
  {-| A record pattern that names something must match that name.

      A record type has one shape, so its own pattern could ignore the tag and
      nothing depended on it. A variant that names its payload does not: `Add`
      and `Mul` may declare the same fields, and matching on fields alone let
      the first arm accept the other's value — a program that read
      `case Add{left, right}` and computed a product. -}
  RecordPattern path fields _ -> case value of
    RecordValue name present
      | maybe True (== name) (patternName path) ->
          concat <$> mapM (matchField present) fields
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

{-| The name a record pattern writes before its braces, when it writes one. -}
patternName :: Maybe ModuleName -> Maybe Text
patternName path = case path of
  Nothing -> Nothing
  Just (ModuleName segments) -> Just (lastSegment segments)

lastSegment :: NonEmpty Text -> Text
lastSegment (first :| rest) = last (first : rest)

matchRange :: Value -> Bool -> Value -> Value -> Maybe [(Text, Value)]
matchRange lower inclusive upper value =
  case (lower, upper, value) of
    (IntValue _ low, IntValue _ high, IntValue _ actual) -> check inclusive low high actual
    (CharValue low, CharValue high, CharValue actual) -> check inclusive low high actual
    (FloatValue lowWidth low, FloatValue highWidth high, FloatValue actualWidth actual)
      | lowWidth == highWidth && highWidth == actualWidth ->
          check inclusive low high actual
    _ -> Nothing

check :: Ord a => Bool -> a -> a -> a -> Maybe [(Text, Value)]
check inclusive low high actual
  | actual >= low && (if inclusive then actual <= high else actual < high) = Just []
  | otherwise = Nothing

{-| The kind a literal's suffix names. -}
kindOfSuffix :: Maybe IntegerSuffix -> IntegerKind
kindOfSuffix suffix = case suffix of
  Just (SignedSuffix width) -> SignedKind width
  Just (UnsignedSuffix width) -> UnsignedKind width
  Nothing -> defaultIntegerKind

literalValue :: Tree.Literal -> Value
literalValue literal = case literal of
  {-| A literal's suffix selects its kind. Without one it is a platform `Int`,
      which is what the checker defaults an unconstrained literal to. -}
  Tree.IntegerValue text -> case parseIntegerLiteral text of
    Just ParsedInteger{parsedIntegerValue, parsedIntegerSuffix} ->
      IntValue (kindOfSuffix parsedIntegerSuffix) parsedIntegerValue
    Nothing -> intOf 0
  Tree.FloatValue text -> case parseFloatLiteral text of
    Just ParsedFloat{parsedFloatValue, parsedFloatWidth} ->
      FloatValue parsedFloatWidth parsedFloatValue
    Nothing -> FloatValue Float64Width 0
  Tree.DecimalValue text -> case parseDecimalLiteral text of
    Just number -> DecimalValue number
    Nothing -> DecimalValue (decimalFromInteger 0)
  Tree.StringValue text -> StrValue text
  Tree.CharValue character -> CharValue character
  Tree.BoolValue flag -> BoolValue flag
  Tree.NullValue -> NullValue
