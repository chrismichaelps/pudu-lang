{-| @Program.Lsp.MethodOwner — the owners a receiver's methods are filed under -}
module Pudu.Lsp.MethodOwner
  ( DeclaredMethod
  , declaredOn
  , receiverOwners
  , traitMembersNamed
  , writtenOwners
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameSegments, moduleNameText, moduleQualifier)
import Pudu.Frontend.Syntax.Tree (Import (..), Module (..), TypeSyntax (..))
import Pudu.Lsp.Context (TypeParameter)
import Pudu.Lsp.Documents (Analysis (..), DeclaredMethod)
import Pudu.Type (Type (..))
import Pudu.Type.Value (nominalKey)

{-| The keys the checker files a receiver's methods under: a nominal type's
    own, a `dynamic` trait's, and for a type parameter the traits its bounds
    name in scope. -}
receiverOwners :: Analysis -> [TypeParameter] -> Type -> [Text]
receiverOwners value parameters receiver = case receiver of
  ReferenceTypeValue _ target -> receiverOwners value parameters target
  NominalType owner _ -> [nominalKey owner]
  DynamicTypeValue trait -> [nominalKey trait]
  AppliedType head' _ -> receiverOwners value parameters head'
  RigidType name ->
    [ key
    | (parameter, bounds) <- parameters
    , parameter == name
    , Located _ (NamedType path _) <- bounds
    , key <- writtenOwners value path
    , Map.member key (analysisMethods value)
    ]
  _ -> []

{-| The canonical keys a written type or trait name may stand for in this
    module: a qualifier names the module it was imported as; a bare name is
    this module's own, or one a selective import brought in. -}
writtenOwners :: Analysis -> ModuleName -> [Text]
writtenOwners value path = case NonEmpty.toList (moduleNameSegments path) of
  [name] -> [own <> "." <> name | Just own <- [rootName]] <> [imported <> "." <> name | imported <- selecting name]
  segments -> [qualified (init segments) <> "." <> last segments]
 where
  rootName = moduleNameText . locatedValue . moduleName <$> analysisModule value
  imports = maybe [] (map locatedValue . moduleImports) (analysisModule value)
  selecting name =
    [moduleNameText (locatedValue (importModule entry)) | entry <- imports, name `elem` map locatedValue (importItems entry)]
  qualified segments =
    let written = Text.intercalate "." segments
     in case [moduleNameText (locatedValue (importModule entry)) | entry <- imports, Just alias <- [importAlias entry], locatedValue alias == written] of
          target : _ -> target
          [] -> case [moduleNameText (locatedValue (importModule entry)) | entry <- imports, null (importItems entry), importAlias entry == Nothing, moduleQualifier (locatedValue (importModule entry)) == written] of
            target : _ -> target
            [] -> written

declaredOn :: Analysis -> Text -> [DeclaredMethod]
declaredOn value key = Map.findWithDefault [] key (analysisMethods value)

{-| The members of that name every trait of the program declares: where a
    type's own key declares nothing, a call may reach a default it inherits. -}
traitMembersNamed :: Analysis -> Text -> [DeclaredMethod]
traitMembersNamed value name =
  [ method
  | key <- Map.keys (analysisTraits value)
  , method@(member, _, _) <- declaredOn value key
  , member == name
  ]
