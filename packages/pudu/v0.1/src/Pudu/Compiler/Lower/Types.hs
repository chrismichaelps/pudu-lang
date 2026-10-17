{-| @Pudu.Compiler.Lower.Types — settled checker facts for native representation. -}
module Pudu.Compiler.Lower.Types
  ( LowerTypes, nativeTypes, lookupScheme, typeForSpan, formedCoreType ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Core (CoreType (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned))
import Pudu.Source (Span)
import Pudu.Type (TypeInfo, typeAt)
import Pudu.Type.Value
  ( Scheme, Type (..), boolType, integerType, stringType )

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
  | value == integerType = Just (CoreIntegerType PlatformSigned)
  | value == boolType = Just CoreBoolType
  | value == stringType = Just CoreTextType
  | otherwise = case value of
      UnitTypeValue -> Just CoreUnitType
      NeverType -> Just CoreNeverType
      _ -> Nothing
