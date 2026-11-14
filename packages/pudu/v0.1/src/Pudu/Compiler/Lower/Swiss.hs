{-| @Compiler.Lower.Swiss — the six flat-table primitives over a record of
    two stores, as direct calls and as callable bodies. -}
module Pudu.Compiler.Lower.Swiss (lowerSwissPrimitive, swissCallable, swissPrimitive) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Array (stopped)
import Pudu.Compiler.Lower.Keyed (Blame (..))
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (LowerTypes, recordFields, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

swissPrimitive :: Text -> Bool
swissPrimitive name = name `elem`
  ["swissTableEmpty", "swissTableLookup", "swissTableInsert", "swissTableDelete", "swissTableEntries", "swissTableSize"]

{-| A direct call: operands run once in source order, and one that never
    returns ends the call before later operands run. -}
lowerSwissPrimitive :: (LowerState -> Located Expression -> Lowered)
  -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered
lowerSwissPrimitive lower state at name arguments
  | swissPrimitive name = Just (go state [] arguments)
  | otherwise = Nothing
 where
  go current done [] = case typeForSpan (contextTypes (lowerContext current)) at of
    Just result
      | let cores = reverse done
      , Just build <- swissCallable AtCall (contextTypes (lowerContext current)) name
          (CoreFunctionType (map coreExpressionType cores) result) -> build current at cores
    _ -> halt at ("a call to " <> name <> " without its flat-table signature") current
  go current done (argument : rest) = case lower current argument of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (stopped at (reverse (core : done)), CoreNeverType))
    (after, Just (core, _)) -> go after (core : done) rest

{-| The body for an exact signature over operands already in hand. The table
    must be laid out as capacity, count, the control store and the slot
    store; the slot store's value type is the table's. -}
swissCallable :: Blame -> LowerTypes -> Text -> CoreType -> Maybe (LowerState -> Span -> [CoreExpression] -> Lowered)
swissCallable blame types name signature = case (name, signature) of
  ("swissTableEmpty", CoreFunctionType [capacity] table)
    | capacity == intType, Just held <- valueOf table -> Just (body table (emptied table held))
  ("swissTableSize", CoreFunctionType [table] result)
    | result == intType, Just _ <- valueOf table -> Just (body result (\_ table' _ -> ([], field intType "count" table')))
  ("swissTableEntries", CoreFunctionType [table] result@(CoreArrayType pair))
    | Just held <- valueOf table, pair == slotOf held ->
        Just (body result (\_ table' _ -> ([], keyed result KeyedValues (field (CoreStoreType pair) "slots" table') [])))
  ("swissTableLookup", CoreFunctionType [table, key] result@(CoreSumType "Option" [held]))
    | key == word, valueOf table == Just held -> Just (looked result held)
  ("swissTableInsert", CoreFunctionType [table, key, value] result)
    | result == table, key == word, valueOf table == Just value ->
        Just (body result (\at table' rest -> ([], CoreExpression at result (CoreKernel KernelSwissInsert []
          [table', CoreExpression at (slotOf value) (CoreTuple rest)]))))
  ("swissTableDelete", CoreFunctionType [table, key] result)
    | result == table, key == word, Just _ <- valueOf table ->
        Just (body result (\at table' rest -> ([], CoreExpression at result (CoreKernel KernelSwissDelete [] (table' : rest)))))
  _ -> Nothing
 where
  word = CoreIntegerType (UnsignedKind 64)
  slotOf held = CoreTupleType [word, held]
  valueOf table = case recordFields types table of
    Just [("capacity", capacity), ("count", count), ("ctrl", CoreStoreType control), ("slots", CoreStoreType (CoreTupleType [key, held]))]
      | capacity == intType, count == intType, control == word, key == word -> Just held
    _ -> Nothing
  field kind label operand = CoreExpression (coreExpressionSpan operand) kind (CoreField label operand)
  keyed kind method receiver operands = CoreExpression (coreExpressionSpan receiver) kind (CoreKeyedMethod method receiver operands)
  -- Operands go into locals in the order they ran; the answer reads them.
  body result build state at cores =
    let (held, locals) = foldl' hold (state, []) cores
        hold (current, done) core = let (next, local) = bindLocal current "" (coreExpressionType core) in (next, done <> [local])
        declarations = [CoreStatement (coreExpressionSpan core) (CoreDeclare local core) | (local, core) <- zip locals cores]
        given = [CoreExpression at (coreLocalType local) (CoreReadLocal local) | local <- locals]
     in case given of
          first : rest ->
            let (extra, answer) = build at first rest
             in (held, Just (CoreExpression at result (CoreBlockValue (CoreBlock (declarations <> extra) (Just answer))), result))
          [] -> halt at "a flat-table builtin without its operands" state
  emptied table held at capacity _ =
    let expression kind shape = CoreExpression at kind shape
        number value = expression intType (CoreIntegerLiteral PlatformSigned value)
        store kind = expression (CoreStoreType kind) (CoreKeyedMethod KeyedFromArray
          (expression (CoreArrayType (CoreTupleType [intType, kind])) (CoreArray [])) [])
        message = expression CoreTextType (CoreTextLiteral "capacity cannot be negative")
        failure = expression CoreNeverType $ case blame of
          AtCall -> CoreFailText "E7004" Nothing message Nothing
          AtCaller -> CoreFailCaller "E7004" Nothing message
        guard = CoreStatement at (CoreIf (expression CoreBoolType (CoreBinary CoreLess capacity (number 0)))
          (CoreBlock [CoreStatement at (CoreEvaluate failure)] Nothing) Nothing)
     in ([guard], expression table (CoreRecord
          [ ("capacity", expression intType (CoreKernel KernelSwissCapacity [] [capacity]))
          , ("count", number 0), ("ctrl", store word), ("slots", store (slotOf held)) ]))
  -- The find kernel answers the slot; the pair there holds the value.
  looked result held state at cores =
    let (withSlot, slot) = bindLocal state "" intType
        build _ table' rest =
          let expression kind shape = CoreExpression at kind shape
              found = expression intType (CoreReadLocal slot)
              pair = keyed (slotOf held) KeyedLookup (field (CoreStoreType (slotOf held)) "slots" table') [found]
              some = expression result (CoreConstruct "Some" [("0", expression held (CoreTupleIndex 1 pair))])
              present = expression CoreBoolType (CoreBinary CoreGreaterOrEqual found (expression intType (CoreIntegerLiteral PlatformSigned 0)))
           in ( [CoreStatement at (CoreDeclare slot (expression intType (CoreKernel KernelSwissFind [] (table' : rest))))]
              , expression result (CoreIfValue present (CoreBlock [] (Just some)) (expression result (CoreConstruct "None" []))) )
     in body result build withSlot at cores
