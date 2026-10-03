{-| @Type.Check.Derive — validates ordinary trait contracts at generic definitions -}
module Pudu.Type.Check.Derive (checkDeriveContracts) where

import Control.Monad (foldM, unless, when)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..), Derive (..), Function (..), Module (..), Parameter (..)
  , Trait (..), TypeParam (..), requiredParameterCount )
import Pudu.Source (Span)
import Pudu.Type.Check.Method (declareBounds, functionRigid, traitTable)
import Pudu.Type.Env (Checker, DeclaredTypes (..), lookupName, report)
import Pudu.Type.Formation (declaredParameterType, formOptionalType, formTraitReference)
import Pudu.Type.Interface
  ( interfaceDeclarations, interfaceDefaults, interfaceModule )
import Pudu.Type.Interface.Graph (ImportTypes (..))
import Pudu.Type.Substitute (substituteRigid)
import Pudu.Type.Value
  ( NominalId, Scheme (..), Type (..), canonicalNominal, capabilitiesOf
  , nominalKey )

checkDeriveContracts :: DeclaredTypes -> ImportTypes -> Module -> Checker ()
checkDeriveContracts declared imported moduleValue = do
  _ <- foldM checkOne Set.empty (moduleDeclarations moduleValue)
  pure ()
 where
  local = moduleDeclarations moduleValue
  catalog = Map.union localTraits importedTraits
  localTraits = Map.fromList
    [(canonicalNominal (locatedValue (moduleName moduleValue)) (locatedValue (traitName value)), value)
    | Located _ (TraitDeclaration value) <- local]
  importedTraits = Map.fromList
    [(canonicalNominal (interfaceModule interface) (locatedValue (traitName value)), value)
    | interface <- importedInterfaces imported
    , Located _ (TraitDeclaration value) <- interfaceDeclarations interface]
  defaults = Set.unions (map interfaceDefaults (importedInterfaces imported))
    <> Set.fromList
      [(owner, locatedValue (functionName member))
      | (owner, members) <- Map.toList (traitTable declared local)
      , Located _ member <- members, functionBody member /= Nothing]
  checkOne seen (Located _ (DeriveDeclaration value)) = do
    let target = locatedValue (deriveParameter value)
    head' <- formTraitReference declared [(target, 0)] (deriveTrait value)
    case head' of
      NominalType owner arguments -> case Map.lookup owner catalog of
        Just trait -> do
          let key = (owner, locatedValue (deriveShape value))
          when (Set.member key seen) $
            refuse (locatedSpan (deriveTrait value)) "this trait already has a derive for this shape"
          if length arguments /= length (traitTypeParams trait)
            then refuse (locatedSpan (deriveTrait value)) "the derive trait has the wrong number of type arguments"
            else checkMembers declared defaults owner arguments trait value
          pure (Set.insert key seen)
        Nothing -> invalidHead value >> pure seen
      ErrorType -> pure seen
      _ -> invalidHead value >> pure seen
  checkOne seen _ = pure seen
  invalidHead value = refuse (locatedSpan (deriveTrait value)) "a derive must implement a declared trait"

checkMembers
  :: DeclaredTypes -> Set.Set (NominalId, Text) -> NominalId -> [Type]
  -> Trait -> Derive -> Checker ()
checkMembers declared defaults owner arguments trait value = do
  let required = Set.fromList
        [name | name <- Map.keys members, Set.notMember (owner, name) defaults]
      supplied = Set.fromList (map (locatedValue . functionName . locatedValue) (deriveFunctions value))
      missing = Set.toAscList (required Set.\\ supplied)
  unless (null missing) $
    refuse (locatedSpan (deriveTrait value)) ("the derive is missing required members: " <> Text.intercalate ", " missing)
  _ <- foldM checkMember Set.empty (deriveFunctions value)
  pure ()
 where
  members = Map.fromList [(locatedValue (functionName member), member) | Located _ member <- traitMembers trait]
  targetName = locatedValue (deriveParameter value)
  target = RigidType targetName
  traitBindings = zip (map (locatedValue . typeParamName . locatedValue) (traitTypeParams trait)) arguments
  checkMember seen (Located _ member) = do
    let name = locatedValue (functionName member)
        at = locatedSpan (functionName member)
    if Set.member name seen
      then refuse at "a derive member may be defined once"
      else case Map.lookup name members of
        Nothing -> refuse at ("the trait declares no member called " <> name)
        Just expected -> do
          when (functionBody member == Nothing) $ refuse at "a provided derive member needs a body"
          when (complete member && complete expected) $ do
            scheme <- lookupName (nominalKey owner <> "." <> name)
            case scheme of
              Nothing -> refuse at "the trait member has no checked signature"
              Just contract -> checkSignature expected member contract at
    pure (Set.insert name seen)
  checkSignature expected actual contract at = do
    let expectedParams = functionRigid expected
        actualParams = functionRigid actual
        normalized = [RigidType ("$derive" <> Text.pack (show index)) | index <- [0 .. length actualParams - 1]]
        expectedBindings = ("Self", target) : traitBindings <> zip (map fst expectedParams) normalized
        actualBindings = zip (map fst actualParams) normalized
        rigid = (targetName, 0) : actualParams
    inputs <- mapM (declaredParameterType declared rigid) (functionParameters actual)
    result <- formOptionalType declared rigid (functionReturn actual)
    let actualType = substituteRigid actualBindings (FunctionTypeValue (functionAsync actual) inputs result)
        expectedType = substituteRigid expectedBindings (schemeType contract)
        allowed = (target, owner) : boundPairs expectedBindings (schemeBounds contract)
        requested = boundPairs actualBindings (declareBounds declared actual)
        signatureMatches = actualType == expectedType
          && map snd actualParams == map snd expectedParams
          && requiredParameterCount actual == requiredParameterCount expected
          && fmap (capabilitiesOf . map locatedValue) (functionUnsafe actual)
            == fmap (capabilitiesOf . map locatedValue) (functionUnsafe expected)
        boundsMatch = all (`elem` allowed) requested
    unless (containsError actualType || containsError expectedType) $ do
      unless signatureMatches $ refuse at "the derive member does not match the trait signature"
      when (signatureMatches && not boundsMatch) $ refuse at "the derive member requires bounds absent from the trait contract"

boundPairs :: [(Text, Type)] -> [(Text, [NominalId])] -> [(Type, NominalId)]
boundPairs replacements bounds =
  [(substituteRigid replacements (RigidType name), trait) | (name, traits) <- bounds, trait <- traits]

complete :: Function -> Bool
complete value = functionReturn value /= Nothing
  && all ((/= Nothing) . parameterType . locatedValue) (functionParameters value)

containsError :: Type -> Bool
containsError value = case value of
  ErrorType -> True
  NominalType _ arguments -> any containsError arguments
  TupleTypeValue members -> any containsError members
  FunctionTypeValue _ inputs result -> any containsError inputs || containsError result
  ReferenceTypeValue _ target -> containsError target
  AppliedType head' arguments -> containsError head' || any containsError arguments
  RestrictedType _ target -> containsError target
  _ -> False

refuse :: Span -> Text -> Checker ()
refuse at message = report "E3091" at message
  (Just "make the derive implement the ordinary trait contract for every target type")
