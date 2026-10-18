{-| @Pudu.Compiler.Lower.Types — settled checker facts for native representation. -}
module Pudu.Compiler.Lower.Types
  ( LowerTypes, nativeTypes, lookupScheme, typeForSpan, formedCoreType
  , nativeIntegerKind, nativeScalarType ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Core (CoreType (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned, PlatformUnsigned, SignedKind, UnsignedKind), integerKindOf)
import Pudu.Source (Span)
import Pudu.Type (TypeInfo, typeAt)
import Pudu.Type.Value
  ( NominalId (..), Scheme, Type (..), boolType, stringType )

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
  | value == boolType = Just CoreBoolType
  | value == stringType = Just CoreTextType
  | otherwise = case value of
      UnitTypeValue -> Just CoreUnitType
      NeverType -> Just CoreNeverType
      _ -> Nothing

nativeIntegerKind :: IntegerKind -> Bool
nativeIntegerKind PlatformSigned = True
nativeIntegerKind PlatformUnsigned = True
nativeIntegerKind (SignedKind width) = width `elem` [8, 16, 32, 64]
nativeIntegerKind (UnsignedKind width) = width `elem` [8, 16, 32, 64]
nativeIntegerKind _ = False

nativeScalarType :: CoreType -> Bool
nativeScalarType (CoreIntegerType kind) = nativeIntegerKind kind
nativeScalarType CoreBoolType = True
nativeScalarType CoreUnitType = True
nativeScalarType _ = False
