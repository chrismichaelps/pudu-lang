{-| @Type.Check.Bound — admits complete generic evidence before bodies assume it. -}
module Pudu.Type.Check.Bound (checkBounds, checkDeclarationBounds) where

import Control.Monad (unless)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Comptime.Limits (callDepthLimit)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Constraint (..), Declaration (..), Derive (..), Function (..), Impl (..)
  , Trait (..), TypeDeclarationValue (..), TypeParam (..), TypeSyntax )
import Pudu.Source (Span)
import Pudu.Type.Env (Checker, DeclaredTypes (..), report, reportedAt)
import Pudu.Type.Formation (formBoundFor, formBoundType)
import Pudu.Type.Formation.Builtin (builtinKinds, builtinTypeNames)
import Pudu.Type.Value (NominalId (..), Type (..), nominalKey, renderType)

checkDeclarationBounds :: DeclaredTypes -> Located Declaration -> Checker Bool
checkDeclarationBounds declared (Located _ declaration) = case declaration of
  FunctionDeclaration value -> function [] value
  TypeDeclaration value -> header (entries (typeTypeParams value)) (typeTypeParams value) []
  TraitDeclaration value -> do
    let rigid = ("Self", 0) : entries (traitTypeParams value)
    admitted <- header rigid (traitTypeParams value) (traitConstraints value)
    members <- mapM (function rigid . locatedValue) (traitMembers value)
    pure (admitted && and members)
  ImplDeclaration value -> do
    let rigid = ("Self", 0) : entries (implTypeParams value)
    admitted <- header rigid (implTypeParams value) (implConstraints value)
    headAdmitted <- checkApplication declared rigid (implTrait value)
      (formBoundType declared rigid (implTrait value))
    members <- mapM (function rigid . locatedValue) (implFunctions value)
    pure (admitted && headAdmitted && and members)
  DeriveDeclaration value ->
    and <$> mapM (function [(locatedValue (deriveParameter value), 0)] . locatedValue)
      (deriveFunctions value)
  _ -> pure True
 where
  header rigid parameters constraints = checkBounds declared rigid
    ([(locatedValue (typeParamName parameter), typeParamBounds parameter)
      | Located _ parameter <- parameters]
      <> [(locatedValue (constraintSubject constraint), constraintBounds constraint)
         | Located _ constraint <- constraints])
  function enclosing value = header (enclosing <> entries (functionTypeParams value))
    (functionTypeParams value) (functionConstraints value)

checkBounds :: DeclaredTypes -> [(Text, Int)] -> [(Text, [Located TypeSyntax])] -> Checker Bool
checkBounds declared rigid bounds = and <$> mapM checkSubject bounds
 where
  checkSubject (subject, written) = and <$> mapM (checkOne subject) written
  checkOne subject written
    | subject `notElem` map fst rigid =
        refuse (locatedSpan written) "a bound's subject must be a declared type parameter"
    | otherwise = checkApplication declared rigid written
        (formBoundFor declared rigid subject written)

checkApplication :: DeclaredTypes -> [(Text, Int)] -> Located TypeSyntax -> Type -> Checker Bool
checkApplication declared rigid written formed = case formed of
  ErrorType -> pure False
  NominalType owner arguments
    | Set.member owner (declaredTraitNames declared) || marker owner ->
        case checkArguments 0 (kinds owner) arguments of
          Left reason -> refuse at (renderType formed <> ": " <> reason)
          Right () -> pure True
    {-| An isolated editor buffer may carry opaque import names without an
        interface. It cannot decide their kinds; the loaded graph can. -}
    | not (known owner) -> pure True
  _ -> refuse at (renderType formed <> " is not a trait application")
 where
  at = locatedSpan written
  marker owner = nominalModule owner == Nothing
    && nominalName owner `elem` ["Copy", "Send", "Sync"]
  known owner = Map.member owner (declaredKinds declared)
    || owner `elem` Map.elems (declaredNames declared)
    || nominalModule owner == Nothing && nominalName owner `elem` builtinTypeNames
  kinds owner = Map.findWithDefault (builtinKinds owner) owner (declaredKinds declared)
  checkArguments depth expected arguments
    | depth >= callDepthLimit = Left "bound validation exhausted its type-depth budget"
    | length expected /= length arguments = Left
        ("expected " <> count (length expected) <> " arguments, found " <> count (length arguments))
    | otherwise = mapM_ (checkArgument (depth + 1)) (zip expected arguments)
  checkArgument depth (expected, argument) = do
    actual <- arity depth argument
    case actual of
      Just found | expected /= found -> Left
        (renderType argument <> " has constructor arity " <> count found
          <> "; expected " <> count expected)
      _ -> Right ()
  arity depth value
    | depth >= callDepthLimit = Left "bound validation exhausted its type-depth budget"
    | otherwise = case value of
        ErrorType -> Right Nothing
        VariableType _ -> Right Nothing
        RigidType name -> Right (lookup name rigid)
        NominalType owner arguments
          | Set.member owner (declaredTraitNames declared) || marker owner ->
              Left (nominalKey owner <> " is a trait, not a type argument")
          | null arguments -> Right (Just (length (kinds owner)))
          | otherwise -> checkArguments depth (kinds owner) arguments >> Right (Just 0)
        AppliedType head' arguments -> do
          headArity <- arity (depth + 1) head'
          if null arguments then pure headArity else do
            case headArity of
              Just required -> checkArguments depth (replicate required 0) arguments
              Nothing -> pure ()
            Right (Just 0)
        ReferenceTypeValue _ target -> values depth [target]
        TupleTypeValue members -> values depth members
        FunctionTypeValue _ inputs result -> values depth (result : inputs)
        RestrictedType _ target -> arity (depth + 1) target
        _ -> Right (Just 0)
  values depth members = checkArguments depth (replicate (length members) 0) members >> Right (Just 0)

entries :: [Located TypeParam] -> [(Text, Int)]
entries parameters =
  [(locatedValue (typeParamName parameter), typeParamArity parameter)
  | Located _ parameter <- parameters]

count :: Int -> Text
count = Text.pack . show

refuse :: Span -> Text -> Checker Bool
refuse at message = do
  seen <- reportedAt at "E3048"
  unless seen $ report "E3048" at message
    (Just "name a trait with its declared arguments; constructors must have the receiving parameter's arity")
  pure False
