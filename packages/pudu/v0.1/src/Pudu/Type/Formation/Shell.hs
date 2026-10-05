{-| @Type.Formation.Shell — collects nominal identities before forming types. -}
module Pudu.Type.Formation.Shell (addShell, locallyDeclared, paramEntries) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..), Foreign (..), Trait (..), TypeDeclarationValue (..), TypeParam (..) )
import Pudu.Type.Env (DeclaredTypes (..))
import Pudu.Type.Value (canonicalNominal)

{-| The bare names this module declares a type or trait under.

    An alias is recorded under its own module's qualified name and under its
    bare one, and what is collected here carries forward from module to module.
    Without this, `Std.App` writing `type Stage = Lifecycle.Stage` leaves
    `Stage` in the alias table, and `Std.App.Stage` — which declares the real
    `Stage` — then reads its own name through the other module's alias and
    reports its own constructor as a different type than its own signature.

    A name a module declares means what that module declared, so an alias
    reaching it from elsewhere under the same bare name is dropped before the
    module is collected. The qualified spelling is untouched, so `App.Stage`
    still stands for what `App` said it stands for. -}
locallyDeclared :: [Located Declaration] -> Set.Set Text
locallyDeclared = Set.fromList . concatMap named
 where
  named (Located _ declaration) = case declaration of
    TypeDeclaration value -> [locatedValue (typeName value)]
    TraitDeclaration value -> [locatedValue (traitName value)]
    ForeignDeclaration value -> map locatedValue (foreignTypes value)
    _ -> []

addShell :: ModuleName -> Located Declaration -> DeclaredTypes -> DeclaredTypes
addShell owner (Located _ declaration) declared = case declaration of
  TypeDeclaration value ->
    let name = locatedValue (typeName value)
        identity = canonicalNominal owner name
     in declared
      { declaredNames =
          Map.insert (moduleNameText owner <> "." <> name) identity
            (Map.insert name identity (declaredNames declared))
      , declaredParams = Map.insert identity (paramNames value) (declaredParams declared)
      , declaredKinds = Map.insert identity (map snd (paramEntries value)) (declaredKinds declared)
      }
  TraitDeclaration value ->
    let name = locatedValue (traitName value)
        identity = canonicalNominal owner name
     in declared
      { declaredNames =
          Map.insert (moduleNameText owner <> "." <> name) identity
            (Map.insert name identity (declaredNames declared))
      , declaredTraitNames = Set.insert identity (declaredTraitNames declared)
      , declaredKinds = Map.insert identity
          (map (typeParamArity . locatedValue) (traitTypeParams value)) (declaredKinds declared)
      , declaredParams = Map.insert identity
          (map (locatedValue . typeParamName . locatedValue) (traitTypeParams value)) (declaredParams declared)
      }
  ForeignDeclaration value ->
    foldr addHandle declared (foreignTypes value)
   where
    addHandle named accumulated =
      let name = locatedValue named
          identity = canonicalNominal owner name
       in accumulated
        { declaredNames =
            Map.insert (moduleNameText owner <> "." <> name) identity
              (Map.insert name identity (declaredNames accumulated))
        }
  _ -> declared

paramNames :: TypeDeclarationValue -> [Text]
paramNames value = map fst (paramEntries value)

{-| A declaration's parameters beside how many arguments each takes, which is
    what type formation needs to tell an application from a mistake. -}
paramEntries :: TypeDeclarationValue -> [(Text, Int)]
paramEntries value =
  [ (locatedValue (typeParamName param), typeParamArity param)
  | Located _ param <- typeTypeParams value
  ]
