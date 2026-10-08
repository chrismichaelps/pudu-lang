{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeOperators #-}

{-| @Compiler.Literals — resolves checked facts into syntax once, after checking

    A literal's kind and value are fixed once checking has run, so the module
    the evaluator runs carries them as `ResolvedInteger` rather than as text to
    parse on every evaluation. The kind is chosen by the evaluator's own rule,
    `integerLiteralValue`, so the rewritten module means what the parsed one
    did. A literal that does not parse is left for the evaluator to answer.

    A reference that chose types for parameters bounded by a trait with a
    static member is rewritten to apply them explicitly, in the declaration's
    parameter order, so the call carries the selection erasure would lose. -}
module Pudu.Compiler.Literals
  ( resolveOwnerSelections
  , resolveLiterals
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Type.Equality ((:~:) (..))
import Data.Typeable (Typeable, eqT)
import GHC.Generics
import Pudu.Eval.Match (integerLiteralValue)
import Pudu.Eval.Value (Value (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
import Pudu.IntegerLiteral (IntegerKind, parseIntegerLiteral)
import Pudu.Source (Span)
import Pudu.Type.Value (Type (..), nominalKey)

{-| The module with every integer literal in expression position resolved to
    the kind checking gave its span. -}
resolveLiterals :: Map Span Text -> Map Span [Type] -> Module -> Module
resolveLiterals kinds selections = walk (Facts kinds selections False)

{-| Lower only generated owner annotations into printable ordinary applications. -}
resolveOwnerSelections :: Map Span [Type] -> Module -> Module
resolveOwnerSelections selections
  | Map.null selections = id
  | otherwise = walk (Facts Map.empty selections True)

data Facts = Facts
  { factKinds :: !(Map Span Text)
  , factSelections :: !(Map Span [Type])
  , factOwnersOnly :: !Bool
  }

{-| The reference with its selection applied. An explicit application already
    carries the written prefix of the same list, so it is replaced whole. -}
select :: Span -> [Type] -> Expression -> Expression
select spanValue chosen value = TypeApplication target written
 where
  target = stripOwner $ case value of
    TypeApplication inner _ -> inner
    _ -> Located spanValue value
  stripOwner (Located _ (MemberExpression (Located ownerAt (TypeApplication owner _)) member)) =
    Located ownerAt (MemberExpression owner member)
  stripOwner other = other
  written = map (typeSyntax spanValue) chosen

hasSelectedOwner :: Expression -> Bool
hasSelectedOwner value = case value of
  MemberExpression (Located _ TypeApplication{}) _ -> True
  TypeApplication inner _ -> hasSelectedOwner (locatedValue inner)
  _ -> False

{-| A settled type as the syntax naming it. A nominal keeps its full key, so
    only a parameter is written with one segment; what has no name is invalid
    and selects nothing. -}
typeSyntax :: Span -> Type -> Located TypeSyntax
typeSyntax spanValue held = Located spanValue $ case held of
  NominalType owner arguments -> case Text.splitOn "." (nominalKey owner) of
    first : rest -> NamedType (ModuleName (first :| rest)) (map recurse arguments)
    [] -> InvalidType
  RigidType name -> NamedType (ModuleName (NonEmpty.singleton name)) []
  TupleTypeValue members -> TupleType (map recurse members)
  ReferenceTypeValue mutable target -> ReferenceType mutable (recurse target)
  UnitTypeValue -> UnitType
  _ -> InvalidType
 where
  recurse = typeSyntax spanValue

{-| A literal as the evaluator would build it, when its text parses. -}
resolveOne :: Map Span Text -> Span -> Literal -> Literal
resolveOne kinds spanValue literal = case literal of
  IntegerValue text
    | Just _ <- parseIntegerLiteral text
    , IntValue kind number <- integerLiteralValue (Map.lookup spanValue kinds) literal ->
        ResolvedInteger kind number
  _ -> literal

class Walk a where
  walk :: Facts -> a -> a
  default walk :: (Generic a, GWalk (Rep a)) => Facts -> a -> a
  walk kinds = to . gwalk kinds . from

class GWalk f where
  gwalk :: Facts -> f p -> f p

instance GWalk V1 where
  gwalk _ value = value

instance GWalk U1 where
  gwalk _ value = value

instance Walk c => GWalk (K1 i c) where
  gwalk kinds (K1 value) = K1 (walk kinds value)

instance GWalk f => GWalk (M1 i c f) where
  gwalk kinds (M1 value) = M1 (gwalk kinds value)

instance (GWalk f, GWalk g) => GWalk (f :+: g) where
  gwalk kinds (L1 value) = L1 (gwalk kinds value)
  gwalk kinds (R1 value) = R1 (gwalk kinds value)

instance (GWalk f, GWalk g) => GWalk (f :*: g) where
  gwalk kinds (left :*: right) = gwalk kinds left :*: gwalk kinds right

{-| The one place the walk changes anything: an expression that is an integer
    literal, where the span that keys its kind is at hand. -}
instance (Walk a, Typeable a) => Walk (Located a) where
  walk kinds (Located spanValue value) = case eqT :: Maybe (a :~: Expression) of
    Just Refl
      | not (factOwnersOnly kinds), LiteralExpression literal <- value ->
          Located spanValue (LiteralExpression (resolveOne (factKinds kinds) spanValue literal))
      | not (factOwnersOnly kinds) || hasSelectedOwner value
      , Just chosen <- Map.lookup spanValue (factSelections kinds) ->
          Located spanValue (select spanValue chosen (walk kinds value))
    _ -> Located spanValue (walk kinds value)

instance Walk a => Walk (Maybe a) where
  walk kinds = fmap (walk kinds)

instance Walk a => Walk [a] where
  walk kinds = fmap (walk kinds)

instance Walk a => Walk (NonEmpty a) where
  walk kinds = fmap (walk kinds)

instance Walk Text where
  walk _ value = value

instance Walk Bool where
  walk _ value = value

instance Walk Char where
  walk _ value = value

instance Walk Int where
  walk _ value = value

instance Walk Integer where
  walk _ value = value

instance Walk Span where
  walk _ value = value

instance Walk IntegerKind where
  walk _ value = value

instance Walk ModuleName where
  walk _ value = value

instance Walk Literal where
  walk _ value = value

instance Walk Module
instance Walk Import
instance Walk Visibility
instance Walk Capability
instance Walk BindingKind
instance Walk Declaration
instance Walk Function
instance Walk TypeParam
instance Walk Constraint
instance Walk TypeDeclarationValue
instance Walk TypeDefinition
instance Walk FieldDeclaration
instance Walk Variant
instance Walk VariantPayload
instance Walk Trait
instance Walk Impl
instance Walk Macro
instance Walk MacroParam
instance Walk MacroKind
instance Walk Attribute
instance Walk DeriveShape
instance Walk Derive
instance Walk DeriveRequest
instance Walk ComptimeFor
instance Walk Parameter
instance Walk TypeSyntax
instance Walk FunctionBody
instance Walk Block
instance Walk Statement
instance Walk Pattern
instance Walk ArrayRest
instance Walk FieldPattern
instance Walk Foreign
instance Walk ForeignFunction
instance Walk ForeignParameter
instance Walk FieldInit
instance Walk MatchArm
instance Walk Expression
