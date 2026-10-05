{-| @Derive.Sum — lowers selected variants to ordinary patterns and payload reads. -}
module Pudu.Derive.Sum
  ( SelectedVariant (..), variantFields, variantPattern, matchesVariant, readField ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import Pudu.Derive.State (Residual, generated, refuse)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameSegments)
import Pudu.Frontend.Syntax.Tree
  ( Block (..), Expression (..), FieldDeclaration (..)
  , FieldPattern (..), Literal (..), Pattern (..), Statement (..), TypeSyntax (..)
  , Variant (..), VariantPayload (..) )
import Pudu.Source (Span)

data SelectedVariant = SelectedVariant
  { selectedIndex :: !Int
  , selectedSyntax :: !(Located Variant)
  }

variantFields :: SelectedVariant -> [Located FieldDeclaration]
variantFields selected = case variantPayload (locatedValue (selectedSyntax selected)) of
  UnitPayload -> []
  RecordPayload fields -> fields
  TuplePayload members ->
    [ Located at (FieldDeclaration False [] (Located at (Text.pack (show index))) written)
    | (index, written@(Located at _)) <- zip [0 :: Int ..] members ]

variantPattern
  :: Span -> Located TypeSyntax -> SelectedVariant -> Maybe (Located FieldDeclaration)
  -> Residual (Located Pattern)
variantPattern at target selected chosen = do
  path <- case locatedValue target of
    NamedType owner _ -> pure (ModuleName (moduleNameSegments owner <>
      NonEmpty.singleton (locatedValue (variantName value))))
    _ -> refuse at "a sum pattern requires a canonical nominal owner"
  case variantPayload value of
    UnitPayload -> generated at (ConstructorPattern path [])
    TuplePayload _ -> do
      members <- mapM positional (variantFields selected)
      generated at (ConstructorPattern path members)
    RecordPayload _ -> do
      fields <- case chosen of
        Nothing -> pure []
        Just field -> do
          name <- generated at (locatedValue (fieldName (locatedValue field)))
          held <- binding
          pure <$> generated at (FieldPattern name (Just held))
      generated at (RecordPattern (Just path) fields True)
 where
  value = locatedValue (selectedSyntax selected)
  binding = generated at "__derive_payload" >>= generated at . BindingPattern
  positional field = case chosen of
    Just held | locatedValue (fieldName (locatedValue held)) == locatedValue (fieldName (locatedValue field)) -> binding
    _ -> generated at WildcardPattern

matchesVariant
  :: Span -> Located TypeSyntax -> SelectedVariant -> Located Expression
  -> Residual (Located Expression)
matchesVariant at target selected subject = do
  pat <- variantPattern at target selected Nothing
  yes <- generated at (LiteralExpression (BoolValue True))
  no <- generated at (LiteralExpression (BoolValue False))
  body <- generated at (Block [] (Just yes))
  generated at (IfLetExpression pat subject body (Just no))

{-| A selected variant's field, read the way a person writes it: a `let … else`
    that takes the payload apart and panics, naming the variant, when the
    value is another one. -}
readField
  :: Span -> Located TypeSyntax -> SelectedVariant -> Located FieldDeclaration
  -> Located Expression -> Residual (Located Expression)
readField at target selected field subject = do
  pat <- variantPattern at target selected (Just field)
  callee <- generated at (NameExpression (NonEmpty.singleton "panic"))
  message <- generated at (LiteralExpression (StringValue mismatch))
  refusal <- generated at (CallExpression callee [message])
  fallback <- generated at (Block [] (Just refusal))
  binding <- generated at (LetElseStatement pat subject fallback)
  result <- generated at (NameExpression (NonEmpty.singleton "__derive_payload"))
  body <- generated at (Block [binding] (Just result))
  generated at (BlockExpression body)
 where
  mismatch = "expected " <> owner <> locatedValue (variantName (locatedValue (selectedSyntax selected)))
  owner = case locatedValue target of
    NamedType path _ -> NonEmpty.last (moduleNameSegments path) <> "."
    _ -> ""
