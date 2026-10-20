{-| @Pudu.Compiler.Lower.Types — settled checker facts for native representation. -}
module Pudu.Compiler.Lower.Types
  ( LowerTypes, nativeTypes, lookupScheme, typeForSpan, formedCoreType
  , nativeIntegerKind, nativeScalarType, nativeValueType ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Core (CoreType (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned, PlatformUnsigned, SignedKind, UnsignedKind), integerKindOf)
import Pudu.Source (Span)
import Pudu.Type (TypeInfo, typeAt)
import Pudu.Type.Value
  ( NominalId (..), Scheme, Type (..), boolType, charType, stringType )

{-| Facts from one checked module; complete spans retain generated identity. -}
data LowerTypes = LowerTypes !TypeInfo !(Map Text Scheme)

nativeTypes :: Maybe TypeInfo -> [(Text, Scheme)] -> Maybe LowerTypes
nativeTypes info schemes = (\types -> LowerTypes types (Map.fromList schemes)) <$> info

lookupScheme :: LowerTypes -> Text -> Maybe Scheme
lookupScheme (LowerTypes _ schemes) name = Map.lookup name schemes

typeForSpan :: LowerTypes -> Span -> Maybe CoreType
typeForSpan (LowerTypes info _) at = typeAt info at >>= formedCoreType

formedCoreType :: Type -> Maybe CoreType
formedCoreType value
  | NominalType (NominalId Nothing name) [] <- value
  , Just kind <- integerKindOf name
  , nativeIntegerKind kind = Just (CoreIntegerType kind)
  | NominalType (NominalId Nothing "Float64") [] <- value = Just (CoreFloatType Float64Width)
  | NominalType (NominalId Nothing "Float32") [] <- value = Just (CoreFloatType Float32Width)
  | value == boolType = Just CoreBoolType
  | value == stringType = Just CoreTextType
  | value == charType = Just CoreCharType
  | otherwise = case value of
      TupleTypeValue members@(_ : _ : _) -> do
        formed <- traverse formedCoreType members
        if all nativeValueType formed then Just (CoreTupleType formed) else Nothing
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
nativeValueType other = nativeScalarType other
