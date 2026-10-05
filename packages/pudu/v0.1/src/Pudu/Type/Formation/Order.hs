{-| @Type.Formation.Order.Module — orders aliases before their stored uses -}
module Pudu.Type.Formation.Order (formationOrder) where

import Data.Graph (flattenSCC, stronglyConnComp)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeParam (..)
  , TypeSyntax (..)
  )

{-| Nominal shells already exist. Only aliases depend on an earlier expansion;
    data shapes and implementation heads are collected once after those. -}
formationOrder :: ModuleName -> [Located Declaration] -> [Located Declaration]
formationOrder owner declarations =
  concatMap flattenSCC (stronglyConnComp aliases) <> remaining
 where
  aliases =
    [ (declaration, locatedValue (typeName value), dependencies value syntax)
    | declaration@(Located _ (TypeDeclaration value)) <- declarations
    , AliasDefinition syntax <- [locatedValue (typeDefinition value)]
    ]
  remaining = filter (not . isAlias . locatedValue) declarations
  dependencies value syntax =
    let parameters = Set.fromList
          [locatedValue (typeParamName parameter) | Located _ parameter <- typeTypeParams value]
     in [ local
        | name <- referencedNames syntax
        , not (Set.member name parameters)
        , let local = maybe name id (Text.stripPrefix (moduleNameText owner <> ".") name)
        ]

isAlias :: Declaration -> Bool
isAlias (TypeDeclaration value) = case locatedValue (typeDefinition value) of
  AliasDefinition _ -> True
  _ -> False
isAlias _ = False

referencedNames :: Located TypeSyntax -> [Text]
referencedNames (Located _ syntax) = case syntax of
  NamedType name arguments -> moduleNameText name : concatMap referencedNames arguments
  ReferenceType _ target -> referencedNames target
  TupleType members -> concatMap referencedNames members
  FunctionType _ inputs result -> concatMap referencedNames (result : inputs)
  UnsafeType _ target -> referencedNames target
  _ -> []
