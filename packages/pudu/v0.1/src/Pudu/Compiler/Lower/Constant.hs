{-| @Compiler.Lower.Constant — compiler-folded data projected into typed Core. -}
module Pudu.Compiler.Lower.Constant (lowerConstant) where

import Data.List (find)
import qualified Data.ByteString as ByteString
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import GHC.Float (castDoubleToWord64)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), halt, lookupConstant)
import Pudu.Compiler.Lower.Types (LowerTypes, recordFields, sumVariants, typeForSpan)
import Pudu.Core
import Pudu.Eval.Frozen (thaw)
import Pudu.Eval.Value (Value (..))
import Pudu.IntegerLiteral (IntegerKind (UnsignedKind), integerKindFits)
import Pudu.Source (Span)

lowerConstant :: LowerState -> Span -> [Text] -> Maybe (LowerState, Maybe (CoreExpression, CoreType))
lowerConstant state at path = lower <$> lookupConstant state path
 where
  types = contextTypes (lowerContext state)
  lower Nothing = halt at "a constant without a portable folded value" state
  lower (Just frozen) = case typeForSpan types at of
    Nothing -> halt at "a constant without represented solved native type facts" state
    Just kind -> case project types at kind (thaw frozen) of
      Just core -> (state, Just (core, kind))
      Nothing -> halt at "a constant without matching native value data" state

{-| Solved types choose identity and layout. Frozen display names only verify
    the selected shape; they never choose a different module's nominal type. -}
project :: LowerTypes -> Span -> CoreType -> Value -> Maybe CoreExpression
project types at kind value = CoreExpression at kind <$> shape
 where
  shape = case (kind, value) of
    (CoreIntegerType expected, IntValue actual number)
      | expected == actual
      , integerKindFits expected number || (number > 0 && integerKindFits expected (negate number)) ->
          Just (CoreIntegerLiteral expected number)
    (CoreFloatType expected, FloatValue actual number)
      | expected == actual -> Just (CoreFloatLiteral expected (castDoubleToWord64 number))
    (CoreBoolType, BoolValue flag) -> Just (CoreBoolLiteral flag)
    (CoreTextType, StrValue text) -> Just (CoreTextLiteral text)
    (CoreBytesType, BytesValue bytes) ->
      let byteKind = UnsignedKind 8
          array = CoreExpression at (CoreArrayType (CoreIntegerType byteKind))
            (CoreArray [CoreExpression at (CoreIntegerType byteKind) (CoreIntegerLiteral byteKind (fromIntegral byte))
              | byte <- ByteString.unpack bytes])
       in Just (CoreBytesMethod BytesOfArray array [])
    (CoreCharType, CharValue character) -> Just (CoreCharLiteral character)
    (CoreUnitType, UnitValue) -> Just (CoreBlockValue (CoreBlock [] Nothing))
    (CoreTupleType kinds, TupleValue members)
      | length kinds == length members -> CoreTuple <$> sequence (zipWith member kinds members)
    (CoreRecordType name _, RecordValue actual fields)
      | displayName name == actual
      , Just declared <- recordFields types kind
      , length declared == length fields
      , Map.size (Map.fromList fields) == length fields ->
          CoreRecord <$> traverse (field (Map.fromList fields)) declared
    (CoreSumType _ _, VariantValue name payload)
      | Just variants <- sumVariants types kind
      , Just variant <- find ((== name) . coreVariantName) variants
      , length (coreVariantFields variant) == length payload ->
          CoreConstruct name <$> sequence
            [ (,) label <$> member fieldKind held
            | ((label, fieldKind), held) <- zip (coreVariantFields variant) payload ]
    _ -> Nothing
  member = project types at
  field fields (name, fieldKind) = do
    held <- Map.lookup name fields
    (,) name <$> member fieldKind held
