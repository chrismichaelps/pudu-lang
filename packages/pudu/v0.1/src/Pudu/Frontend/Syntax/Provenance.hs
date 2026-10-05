{-# LANGUAGE DefaultSignatures, FlexibleContexts, TypeOperators #-}
{-| @Syntax.Provenance — checks source ownership before deferred cache storage. -}
module Pudu.Frontend.Syntax.Provenance (cacheableModule, cacheableSpan) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import GHC.Generics
  ( Generic, K1 (..), M1 (..), Rep, U1, (:+:) (..), (:*:) (..), from )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Frontend.Syntax.Tree
  ( ArrayRest, Attribute, BindingKind, Block, Capability, ComptimeFor, Constraint
  , Declaration, Derive, DeriveRequest, DeriveShape, Expression, FieldDeclaration
  , FieldInit, FieldPattern, Foreign, ForeignFunction, ForeignParameter, Function
  , FunctionBody, Impl, Import, Literal, Macro, MacroKind, MacroParam, MatchArm
  , Module, Parameter, Pattern, Statement, Trait, TypeDeclarationValue
  , TypeDefinition, TypeParam, TypeSyntax, Variant, VariantPayload, Visibility )
import Pudu.IntegerLiteral (IntegerKind)
import Pudu.Source (Source, Span, emptySpan, sameSpanSource, spanOrigin)

cacheableModule :: Source -> Module -> Bool
cacheableModule source = ownedBy (emptySpan source)

cacheableSpan :: Source -> Span -> Bool
cacheableSpan source = ownedBy (emptySpan source)

class Owned a where
  ownedBy :: Span -> a -> Bool
  default ownedBy :: (Generic a, GOwned (Rep a)) => Span -> a -> Bool
  ownedBy anchor = gowned anchor . from

class GOwned f where
  gowned :: Span -> f a -> Bool

instance GOwned U1 where
  gowned _ _ = True

instance Owned c => GOwned (K1 i c) where
  gowned anchor (K1 value) = ownedBy anchor value

instance GOwned f => GOwned (M1 i c f) where
  gowned anchor (M1 value) = gowned anchor value

instance (GOwned f, GOwned g) => GOwned (f :*: g) where
  gowned anchor (left :*: right) = gowned anchor left && gowned anchor right

instance (GOwned f, GOwned g) => GOwned (f :+: g) where
  gowned anchor (L1 value) = gowned anchor value
  gowned anchor (R1 value) = gowned anchor value

instance Owned Span where
  ownedBy anchor value = sameSpanSource anchor value && spanOrigin value == Nothing

instance Owned a => Owned (Located a) where
  ownedBy anchor (Located at value) = ownedBy anchor at && ownedBy anchor value

instance Owned a => Owned [a] where
  ownedBy anchor = all (ownedBy anchor)

instance Owned a => Owned (NonEmpty a) where
  ownedBy anchor = all (ownedBy anchor)

instance Owned a => Owned (Maybe a) where
  ownedBy anchor = maybe True (ownedBy anchor)

instance Owned Text where ownedBy _ _ = True
instance Owned Int where ownedBy _ _ = True
instance Owned Integer where ownedBy _ _ = True
instance Owned Bool where ownedBy _ _ = True
instance Owned Char where ownedBy _ _ = True
instance Owned ModuleName where ownedBy _ _ = True
instance Owned IntegerKind where ownedBy _ _ = True

instance Owned Module
instance Owned Import
instance Owned Visibility
instance Owned Capability
instance Owned BindingKind
instance Owned Declaration
instance Owned Function
instance Owned TypeParam
instance Owned Constraint
instance Owned TypeDeclarationValue
instance Owned TypeDefinition
instance Owned FieldDeclaration
instance Owned Variant
instance Owned VariantPayload
instance Owned Trait
instance Owned Impl
instance Owned Macro
instance Owned MacroParam
instance Owned MacroKind
instance Owned Attribute
instance Owned DeriveShape
instance Owned Derive
instance Owned DeriveRequest
instance Owned ComptimeFor
instance Owned Parameter
instance Owned TypeSyntax
instance Owned FunctionBody
instance Owned Block
instance Owned Statement
instance Owned Literal
instance Owned Pattern
instance Owned ArrayRest
instance Owned FieldPattern
instance Owned Foreign
instance Owned ForeignFunction
instance Owned ForeignParameter
instance Owned FieldInit
instance Owned MatchArm
instance Owned Expression
