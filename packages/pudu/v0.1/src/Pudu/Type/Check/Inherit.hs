{-| @Type.Check.Inherit.Module — selects inherited trait defaults and keeps their parameters apart -}
module Pudu.Type.Check.Inherit
  ( inheritedMembers
  , renameApart
  , selfArguments
  ) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Pudu.Frontend.Syntax.Tree (Function (..), Impl (..), Trait (..))
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Type.Value (NominalId (..), Type (..))

{-| The trait's defaults this implementation does not provide itself.

    A default is a member with a body, or one an interface records as a default
    after stripping its body. -}
inheritedMembers :: Set (NominalId, Text) -> NominalId -> Trait -> Impl -> [Located Function]
inheritedMembers defaults identity trait value =
  [ member
  | member@(Located _ method) <- traitMembers trait
  , isDefault method
  , locatedValue (functionName method) `notElem` provided
  ]
 where
  provided = map (locatedValue . functionName . locatedValue) (implFunctions value)
  isDefault method =
    functionBody method /= Nothing
      || Set.member (identity, locatedValue (functionName method)) defaults

{-| Rename the parameters whose names are taken, priming each until it is free.

    Answers the parameters as renamed, with their arities, beside the
    replacements that turn the old rigid names into the new ones. -}
renameApart :: [Text] -> [(Text, Int)] -> ([(Text, Int)], [(Text, Type)])
renameApart taken parameters = (map rename parameters, replacements)
 where
  occupied = taken <> map fst parameters
  fresh name = until (`notElem` occupied) (<> "'") (name <> "'")
  renamedTo name
    | name `elem` taken = fresh name
    | otherwise = name
  rename (name, arity) = (renamedTo name, arity)
  replacements =
    [ (name, RigidType (renamedTo name))
    | (name, _) <- parameters
    , name `elem` taken
    ]

{-| The arguments `Self` carries inside an implementation.

    For `impl[T] Holds[T] for Boxed[T]`, `Self` is `Boxed[T]` with the impl's
    own `T` — not a bare `Boxed`. Aliasing it without its arguments made the
    type's parameter and the implementation's parameter two different rigid
    types that happened to share a name, so `self.value` had a type the method's
    declared result could not match and the checker reported `expected T, found
    T` about them.

    An argument naming one of the implementation's parameters becomes that rigid
    parameter; anything else is formed as it was written, which is what makes
    `impl Sequence[Int, Int] for Range` and the generic form agree. -}
selfArguments :: [Text] -> Impl -> [Type]
selfArguments parameters value = case locatedValue (implTarget value) of
  Tree.NamedType _ arguments ->
    map (argumentType parameters . locatedValue) arguments
  _ -> []

argumentType :: [Text] -> Tree.TypeSyntax -> Type
argumentType parameters syntax = case syntax of
  Tree.NamedType path []
    | segment `elem` parameters -> RigidType segment
    | otherwise -> NominalType (NominalId Nothing segment) []
   where
    segment = moduleNameText path
  Tree.NamedType path arguments ->
    NominalType (NominalId Nothing (moduleNameText path))
      (map (argumentType parameters . locatedValue) arguments)
  _ -> ErrorType
