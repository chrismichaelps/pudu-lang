{-| @Type.Ownership.Declaration — the shape an implementation of `Drop` must have -}
module Pudu.Type.Ownership.Declaration (checkDropImplementation) where

import Control.Monad (unless, when)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
import Pudu.Semantic.Prelude (wiredInTypeNames)
import Pudu.Type.Drop (dropTrait)
import Pudu.Type.Env (Checker, report)

{-| `drop` runs with the value still whole and leaves nothing behind, so its
    only member takes `self: &mut Self` and returns unit. It belongs to a
    record or sum the program declares: a builtin type or a type parameter
    has no single declaration whose values it could clean up. -}
checkDropImplementation :: Located Declaration -> Checker ()
checkDropImplementation (Located at value) = case value of
  ImplDeclaration implementation -> do
    isDrop <- namesDrop (locatedValue (implTrait implementation))
    when isDrop $ do
      unless (declaredTarget (locatedValue (implTarget implementation))) $
        report "E4008" (locatedSpan (implTarget implementation))
          "Drop can only be implemented for a record or sum this program declares"
          (Just "implement Drop for the declared type that holds the resource")
      case implFunctions implementation of
        [Located memberAt function] -> unless (validDrop function) $
          report "E4008" memberAt "Drop declares exactly fn drop(self: &mut Self) -> ()"
            (Just "write the member as fn drop(self: &mut Self) -> () { ... }")
        _ -> report "E4008" at "Drop declares exactly fn drop(self: &mut Self) -> ()"
          (Just "give the implementation exactly one member, drop")
  _ -> pure ()

namesDrop :: TypeSyntax -> Checker Bool
namesDrop written = case written of
  NamedType (ModuleName segments) [] -> case NonEmpty.toList segments of
    ["Drop"] -> (/= Nothing) <$> dropTrait
    ["Core", "Prelude", "Drop"] -> pure True
    _ -> pure False
  _ -> pure False

declaredTarget :: TypeSyntax -> Bool
declaredTarget written = case written of
  NamedType (ModuleName segments) _ -> NonEmpty.last segments `notElem` ("Self" : wiredInTypeNames)
  _ -> False

validDrop :: Function -> Bool
validDrop function =
  locatedValue (functionName function) == "drop"
    && not (functionAsync function)
    && null (functionTypeParams function)
    && unitResult (functionReturn function)
    && case functionParameters function of
      [Located _ parameter] ->
        locatedValue (parameterName parameter) == "self"
          && maybe False (exclusiveSelf . locatedValue) (parameterType parameter)
      _ -> False
 where
  unitResult written = case written of
    Nothing -> True
    Just (Located _ UnitType) -> True
    _ -> False
  exclusiveSelf written = case written of
    ReferenceType True (Located _ (NamedType (ModuleName ("Self" :| [])) [])) -> True
    _ -> False
