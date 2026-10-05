{-| @Derive.Context — what one residualization knows, and its pure folds. -}
module Pudu.Derive.Context
  ( Context (..), Exits (..), Propagation (..)
  , attributes, descriptor, fieldLabel, foldBinary, reflectedName, shadow, typeArguments
  , variantDescriptor, variantLabel, writtenLiteral
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Derive.Reflection (ReflectionBinding (..))
import Pudu.Derive.Sum (SelectedVariant (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( Attribute (..), DeriveShape, Expression (..), FieldDeclaration (..), Literal (..)
  , TypeSyntax (..), Variant (..) )
import Pudu.Source (Span)

data Context = Context
  { reflectedCalls :: !(Map Span ReflectionBinding)
  , targetSyntax :: !(Located TypeSyntax)
  , targetFields :: ![Located FieldDeclaration]
  , targetShape :: !DeriveShape
  , targetVariants :: ![SelectedVariant]
  , variantDescriptors :: !(Map Text SelectedVariant)
  , fieldVariants :: !(Map Span SelectedVariant)
  , knownValues :: !(Map Text (Located Expression))
  , substitutions :: !(Map Text (Located TypeSyntax))
  , descriptors :: !(Map Text (Located FieldDeclaration))
  , exits :: !(Maybe Exits)
  }

{-| Inside an unrolled field callback, `return` answers the field's value;
    `?` answers the whole build's `Err`, or that field's `None` in a collect.
    Each lowers to a labelled break. -}
data Exits = Exits
  { valueExit :: !Text
  , propagation :: !Propagation
  }

data Propagation = Unpropagated | FailBuild !Text | AnswerNone

descriptor :: Context -> Located Expression -> Maybe (Located FieldDeclaration)
descriptor context (Located _ value) = case value of
  NameExpression (name :| []) -> Map.lookup name (descriptors context)
  UnaryExpression "&" held -> descriptor context held
  _ -> Nothing

reflectedName :: Context -> Located Expression -> Maybe Text
reflectedName context held = case locatedValue held of
  TypeApplication target _ -> reflectedName context target
  MemberExpression target name
    | Map.lookup (locatedSpan target) (reflectedCalls context) == Just MetadataModule ->
        Just (locatedValue name)
  _ -> case Map.lookup (locatedSpan held) (reflectedCalls context) of
    Just (MetadataFunction name) -> Just name
    _ -> Nothing

typeArguments :: Located Expression -> [Located TypeSyntax]
typeArguments (Located _ (TypeApplication _ arguments)) = arguments
typeArguments _ = []

variantDescriptor :: Context -> Located Expression -> Maybe SelectedVariant
variantDescriptor context (Located _ value) = case value of
  NameExpression (name :| []) -> Map.lookup name (variantDescriptors context)
  UnaryExpression "&" held -> variantDescriptor context held
  _ -> Nothing

attributes :: [Located Attribute] -> Text -> [Located Attribute]
attributes values key = filter ((== key) . locatedValue . attributeName . locatedValue) values

shadow :: [Text] -> Context -> Context
shadow names context = context
  { descriptors = foldr Map.delete (descriptors context) names
  , knownValues = foldr Map.delete (knownValues context) names
  , variantDescriptors = foldr Map.delete (variantDescriptors context) names }

foldBinary :: Located Expression -> Text -> Located Expression -> Expression
foldBinary left operator right = case (locatedValue left, operator, locatedValue right) of
  (LiteralExpression (BoolValue a), "&&", LiteralExpression (BoolValue b)) -> known (BoolValue (a && b))
  (LiteralExpression (BoolValue a), "||", LiteralExpression (BoolValue b)) -> known (BoolValue (a || b))
  (LiteralExpression (BoolValue a), "==", LiteralExpression (BoolValue b)) -> known (BoolValue (a == b))
  (LiteralExpression (BoolValue a), "!=", LiteralExpression (BoolValue b)) -> known (BoolValue (a /= b))
  (LiteralExpression (StringValue a), "==", LiteralExpression (StringValue b)) -> known (BoolValue (a == b))
  (LiteralExpression (StringValue a), "!=", LiteralExpression (StringValue b)) -> known (BoolValue (a /= b))
  (LiteralExpression (StringValue a), "+", LiteralExpression (StringValue b)) -> known (StringValue (a <> b))
  _ -> BinaryExpression left operator right
 where
  known = LiteralExpression

{-| An attribute argument read against a text fallback answers its written
    form, so `@default(0)` and `@default("0")` reach a text reader alike. -}
writtenLiteral :: Literal -> Literal
writtenLiteral held = case held of
  StringValue _ -> held
  IntegerValue text -> StringValue text
  ResolvedInteger _ number -> StringValue (Text.pack (show number))
  FloatValue text -> StringValue text
  DecimalValue text -> StringValue text
  CharValue character -> StringValue (Text.singleton character)
  BoolValue flag -> StringValue (if flag then "true" else "false")
  NullValue -> StringValue "null"

{-| A field as a reader names it: `Order.lines`, or `Shape.Circle.0`. -}
fieldLabel :: Context -> Maybe SelectedVariant -> Located FieldDeclaration -> Text
fieldLabel context chosen field =
  maybe (ownerLabel context) (variantLabel context) chosen
    <> "." <> locatedValue (fieldName (locatedValue field))

variantLabel :: Context -> SelectedVariant -> Text
variantLabel context selected =
  ownerLabel context <> "." <> locatedValue (variantName (locatedValue (selectedSyntax selected)))

ownerLabel :: Context -> Text
ownerLabel context = case locatedValue (targetSyntax context) of
  NamedType (ModuleName segments) _ -> NonEmpty.last segments
  _ -> "the target"
