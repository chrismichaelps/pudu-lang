{-| @Type.Check.Attribute — every `@name` names a declared attribute.

    An attribute is inert data a derive reads by name, so a misspelled one
    would change nothing and say nothing. Each attribute written on a type,
    field or variant must name a declaration the program loads, with arguments
    of the declared kinds; and a derive may only read names that are declared,
    so a misspelled read is caught where it is written too. -}
module Pudu.Type.Check.Attribute
  ( checkAttributes
  , checkAttributeRead
  ) where

import Control.Monad (unless, when)
import Data.List (minimumBy)
import qualified Data.Map.Strict as Map
import Data.Ord (comparing)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.List.NonEmpty (NonEmpty (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( Attribute (..)
  , AttributeParameter (..)
  , Declaration (..)
  , Expression (..)
  , FieldDeclaration (..)
  , Literal (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , Variant (..)
  , VariantPayload (..)
  )
import Pudu.Source (Span)
import Pudu.Type.Env (Checker, DeclaredTypes (..), inDeriveChecking, lookupRecordedExpression, report)
import Pudu.Type.Unify (zonk)
import Pudu.Type.Value (NominalId, Type (..), canonicalNominal)

{-| Checks every attribute written on the module's types, fields and variants. -}
checkAttributes :: DeclaredTypes -> [Located Declaration] -> Checker ()
checkAttributes declared = mapM_ declaration
 where
  declaration (Located _ value) = case value of
    TypeDeclaration typeValue -> do
      mapM_ (written declared) (typeAttributes typeValue)
      case locatedValue (typeDefinition typeValue) of
        RecordDefinition fields -> mapM_ field fields
        SumDefinition variants -> mapM_ variant variants
        _ -> pure ()
    _ -> pure ()
  field (Located _ value) = mapM_ (written declared) (fieldAttributes value)
  variant (Located _ value) = do
    mapM_ (written declared) (variantAttributes value)
    case variantPayload value of
      RecordPayload fields -> mapM_ field fields
      _ -> pure ()

{-| Checks a derive's `has("name")` or `attributeOr("name", fallback)` read on
    a field or variant: the name must be a declared attribute. -}
checkAttributeRead :: DeclaredTypes -> Located Expression -> [Located Expression] -> Checker ()
checkAttributeRead declared (Located _ callee) arguments = do
  deriving' <- inDeriveChecking
  case (callee, arguments) of
    (MemberExpression target (Located _ member), Located at (LiteralExpression (StringValue name)) : _)
      | deriving', member `elem` ["has", "attributeOr"] -> do
          recorded <- lookupRecordedExpression (locatedSpan target)
          reflected <- maybe (pure False) (fmap isReflected . zonk) recorded
          when (reflected && Map.notMember name (declaredAttributes declared)) $
            unknown declared at name
    _ -> pure ()
 where
  isReflected found = case found of
    NominalType owner _ -> owner `elem` [meta "Field", meta "Variant"]
    _ -> False

-- One written attribute: declared, and its arguments of the declared kinds.
written :: DeclaredTypes -> Located Attribute -> Checker ()
written declared (Located at attribute) = do
  let Located nameAt name = attributeName attribute
      arguments = attributeArguments attribute
  case Map.lookup name (declaredAttributes declared) of
    Nothing -> unknown declared nameAt name
    Just kinds
      | length kinds /= length arguments ->
          report "E3105" at ("@" <> name <> " takes " <> counted (length kinds))
            (Just ("write " <> usage name kinds))
      | otherwise ->
          sequence_
            [ unless (fits kind literal) $
                report "E3105" literalAt ("@" <> name <> " expects " <> kindName kind <> " here")
                  (Just ("write " <> usage name kinds))
            | (kind, Located literalAt literal) <- zip kinds arguments
            ]

unknown :: DeclaredTypes -> Span -> Text -> Checker ()
unknown declared at name =
  report "E3104" at ("unknown attribute @" <> name) (Just (suggestion (Map.keys (declaredAttributes declared))))
 where
  suggestion known = case known of
    [] -> "no attribute is declared; declare it with `attribute " <> name <> "`"
    _ -> "did you mean @" <> nearest known <> "? attributes are declared with `attribute name(...)`"
  nearest = minimumBy (comparing (distance name))

-- Whether a literal is of an argument kind. A number takes an integer too.
fits :: AttributeParameter -> Literal -> Bool
fits kind literal = case (kind, literal) of
  (TextParameter, StringValue {}) -> True
  (IntegerParameter, IntegerValue {}) -> True
  (NumberParameter, FloatValue {}) -> True
  (NumberParameter, IntegerValue {}) -> True
  (DecimalParameter, DecimalValue {}) -> True
  (BoolParameter, BoolValue {}) -> True
  (CharParameter, CharValue {}) -> True
  _ -> False

kindName :: AttributeParameter -> Text
kindName kind = case kind of
  TextParameter -> "Str"
  IntegerParameter -> "Int"
  NumberParameter -> "Float"
  DecimalParameter -> "Decimal"
  BoolParameter -> "Bool"
  CharParameter -> "Char"

usage :: Text -> [AttributeParameter] -> Text
usage name kinds = case kinds of
  [] -> "@" <> name
  _ -> "@" <> name <> "(" <> Text.intercalate ", " (map kindName kinds) <> ")"

counted :: Int -> Text
counted count = case count of
  0 -> "no arguments"
  1 -> "one argument"
  _ -> Text.pack (show count) <> " arguments"

-- The number of single-character edits between two names.
distance :: Text -> Text -> Int
distance left right = last (foldl step [0 .. Text.length left] (Text.unpack right))
 where
  step previous@(first : _) character =
    scanl compute (first + 1) (zip3 (Text.unpack left) previous (drop 1 previous))
   where
    compute leftward (letter, diagonal, above) =
      minimum [leftward + 1, above + 1, diagonal + if letter == character then 0 else 1]
  step [] _ = []

meta :: Text -> NominalId
meta = canonicalNominal (ModuleName ("Std" :| ["Meta"]))
