{-| @Type.Check.Reflection — preserves heterogeneous field and owner identities -}
module Pudu.Type.Check.Reflection (reflectedParameters, checkSequenceElement) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import Pudu.Frontend.Syntax.Tree (TypeSyntax (..))
import Pudu.Semantic.Prelude (wiredInTypeNames)
import Pudu.Source (Span)
import Pudu.Type.Env (Checker, DeclaredTypes (..), report)
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value (NominalId, Type (..), canonicalNominal)

reflectedParameters :: DeclaredTypes -> [(Text, Int)] -> Located TypeSyntax -> [(Text, Int)]
reflectedParameters declared rigid (Located _ syntax) = case syntax of
  NamedType owner [_, Located _ (NamedType (ModuleName (name :| [])) [])]
    | Map.lookup (moduleNameText owner) (declaredNames declared) == Just (meta "Field")
    , name `notElem` map fst rigid
    , name `notElem` wiredInTypeNames
    , Map.notMember name (declaredNames declared) -> [(name, 0)]
  _ -> []

checkSequenceElement :: Span -> DeclaredTypes -> [(Text, Int)] -> Type -> Type -> Checker Type
checkSequenceElement at declared enclosing element source = do
  resolved <- zonk source
  case resolved of
    NominalType owner [target] | owner == meta "Fields" -> case element of
      NominalType field [held, RigidType name]
        | field == meta "Field", name `notElem` map fst enclosing
        , name `notElem` wiredInTypeNames, Map.notMember name (declaredNames declared) ->
        checked (unify at target held)
      ErrorType -> pure ErrorType
      _ -> refuse "a field sequence needs Field[T, F] with an abstract field type F"
    NominalType owner [target] | owner == meta "Variants" -> case element of
      NominalType variant [held] | variant == meta "Variant" ->
        checked (unify at target held)
      ErrorType -> pure ErrorType
      _ -> refuse "a variant sequence needs Variant[T] for the same owner"
    _ -> checked (unify at (NominalType "Array" [element]) resolved)
 where
  checked action = do
    matched <- action
    pure (if matched == ErrorType then ErrorType else element)
  refuse message = do
    report "E3001" at message (Just "iterate metadata with its owner and a fresh field type parameter")
    pure ErrorType

meta :: Text -> NominalId
meta = canonicalNominal (ModuleName ("Std" :| ["Meta"]))
