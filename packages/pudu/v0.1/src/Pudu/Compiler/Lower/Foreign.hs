{-| @Compiler.Lower.Foreign — a call to a foreign function the module declares
    or imports: its arguments in order, then the call through the declared
    library and symbol. -}
module Pudu.Compiler.Lower.Foreign (lowerForeignCall) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Array (collect, stops, stopped)
import Pudu.Compiler.Lower.State (ForeignTarget (..), LowerContext (..), LowerState (..), halt, lookupForeign, refused)
import Pudu.Compiler.Lower.Types (LowerTypes, recordFields, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located)
import Pudu.IntegerLiteral (IntegerKind (SignedKind, UnsignedKind))
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| Nothing unless the name reaches a foreign declaration. The crossing types
    come from the checked arguments and the call's own result. -}
lowerForeignCall :: (LowerState -> Located Expression -> Lowered) -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered
lowerForeignCall lower state at name arguments = do
  target <- lookupForeign state name
  Just $ case collect lower state arguments of
    (after, Nothing) -> refused after
    (after, Just cores)
      | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
      | otherwise -> case typeForSpan (contextTypes (lowerContext after)) at of
          Just result
            | all (parameterCrossing types) parameters, resultCrossing types result ->
                let declared = CoreForeign (targetLibrary target) (targetVersion target) (targetSymbol target) parameters result
                 in (after, Just (CoreExpression at result (CoreForeignCall declared cores), result))
          _ -> halt at "a foreign call crossing handles or slots" after
      where
        parameters = map coreExpressionType cores
        types = contextTypes (lowerContext after)

{-| A parameter crosses as a number, Bool, text, a lent run of bytes or a
    record of those (bytes excepted). -}
parameterCrossing :: LowerTypes -> CoreType -> Bool
parameterCrossing types kind = kind == CoreBytesType || fieldCrossing types kind

{-| A result crosses as a number, Bool, text, unit or such a record. -}
resultCrossing :: LowerTypes -> CoreType -> Bool
resultCrossing types kind = kind == CoreUnitType || fieldCrossing types kind

{-| What a record field may be: a number, Bool, text, or a record of those,
    the record holding between one and thirty-two fields. -}
fieldCrossing :: LowerTypes -> CoreType -> Bool
fieldCrossing types kind
  | scalarCrossing kind || kind == CoreTextType = True
  | otherwise = case recordFields types kind of
      Just fields -> not (null fields) && length fields <= 32 && all (fieldCrossing types . snd) fields
      Nothing -> False

{-| The numeric and Bool crossings: fixed-width integers, both float widths
    and Bool. -}
scalarCrossing :: CoreType -> Bool
scalarCrossing kind = case kind of
  CoreIntegerType (SignedKind width) -> width `elem` [8, 16, 32, 64]
  CoreIntegerType (UnsignedKind width) -> width `elem` [8, 16, 32, 64]
  CoreFloatType _ -> True
  CoreBoolType -> True
  _ -> False
