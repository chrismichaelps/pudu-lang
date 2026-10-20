{-| @Pudu.Compiler.Lower.Types — settled checker facts for native representation. -}
module Pudu.Compiler.Lower.Types
  ( LowerTypes, nativeTypes, withRecords, lookupScheme, typeForSpan, formedCoreType, formedCoreTypeIn
  , nativeIntegerKind, nativeScalarType, nativeValueType ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Core (CoreType (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned, PlatformUnsigned, SignedKind, UnsignedKind), integerKindOf)
import Pudu.Source (Span)
import Pudu.Type (TypeInfo (..), typeAt)
import Pudu.Type.Value
  ( NominalId (..), Scheme, Type (..), boolType, charType, stringType )

{-| Facts from one checked module; complete spans retain generated identity.
    The records are the root module's own, by nominal identity, with fields
    as checking formed them. -}
data LowerTypes = LowerTypes !TypeInfo !(Map Text Scheme) !(Map NominalId ([Text], [(Text, Type)]))

nativeTypes :: Maybe TypeInfo -> [(Text, Scheme)] -> Maybe LowerTypes
nativeTypes info schemes = (\types -> LowerTypes types (Map.fromList schemes) Map.empty) <$> info

withRecords :: Map NominalId ([Text], [(Text, Type)]) -> LowerTypes -> LowerTypes
withRecords records (LowerTypes info schemes _) = LowerTypes info schemes records

lookupScheme :: LowerTypes -> Text -> Maybe Scheme
lookupScheme (LowerTypes _ schemes _) name = Map.lookup name schemes

typeForSpan :: LowerTypes -> Span -> Maybe CoreType
typeForSpan types@(LowerTypes info _ _) at = typeAt info at >>= formedCoreTypeIn types

{-| Builtins only; no record is known. -}
formedCoreType :: Type -> Maybe CoreType
formedCoreType = formedCoreTypeIn (LowerTypes (TypeInfo Map.empty Map.empty) Map.empty Map.empty)

formedCoreTypeIn :: LowerTypes -> Type -> Maybe CoreType
formedCoreTypeIn (LowerTypes _ _ records) = formed []
 where
  -- A record reached from inside itself has no finite layout here.
  formed seen value
    | NominalType identity [] <- value
    , Just ([], fields) <- Map.lookup identity records
    , identity `notElem` seen = do
        laid <- traverse (\(name, field) -> (,) name <$> formed (identity : seen) field) fields
        if all (nativeValueType . snd) laid then Just (CoreRecordType (nominalName identity) laid) else Nothing
    | TupleTypeValue members@(_ : _ : _) <- value = do
        formedMembers <- traverse (formed seen) members
        if all nativeValueType formedMembers then Just (CoreTupleType formedMembers) else Nothing
    | otherwise = builtin value

builtin :: Type -> Maybe CoreType
builtin value
  | NominalType (NominalId Nothing name) [] <- value
  , Just kind <- integerKindOf name
  , nativeIntegerKind kind = Just (CoreIntegerType kind)
  | NominalType (NominalId Nothing "Float64") [] <- value = Just (CoreFloatType Float64Width)
  | NominalType (NominalId Nothing "Float32") [] <- value = Just (CoreFloatType Float32Width)
  | value == boolType = Just CoreBoolType
  | value == stringType = Just CoreTextType
  | value == charType = Just CoreCharType
  | otherwise = case value of
      UnitTypeValue -> Just CoreUnitType
      NeverType -> Just CoreNeverType
      _ -> Nothing

nativeIntegerKind :: IntegerKind -> Bool
nativeIntegerKind PlatformSigned = True
nativeIntegerKind PlatformUnsigned = True
nativeIntegerKind (SignedKind width) = width `elem` [8, 16, 32, 64, 128]
nativeIntegerKind (UnsignedKind width) = width `elem` [8, 16, 32, 64, 128]
nativeIntegerKind _ = False

nativeScalarType :: CoreType -> Bool
nativeScalarType (CoreIntegerType kind) = nativeIntegerKind kind
nativeScalarType (CoreFloatType _) = True
nativeScalarType CoreBoolType = True
nativeScalarType CoreCharType = True
nativeScalarType CoreUnitType = True
nativeScalarType _ = False

{-| What a native slot can hold: the scalars plus owned text and tuples. -}
nativeValueType :: CoreType -> Bool
nativeValueType CoreTextType = True
nativeValueType (CoreTupleType members) = length members >= 2 && all nativeValueType members
nativeValueType (CoreRecordType _ fields) = all (nativeValueType . snd) fields
nativeValueType other = nativeScalarType other
