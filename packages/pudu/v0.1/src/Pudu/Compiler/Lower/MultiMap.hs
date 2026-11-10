{-| @Compiler.Lower.MultiMap — `multiMapAdd` and `multiMapContains` over the
    record's two maps, as `Eval.MultiMap` answers them. -}
module Pudu.Compiler.Lower.MultiMap (multiMapBody) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Keyed (Blame, mayHoldFunction, orderable)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType)
import Pudu.Compiler.Lower.Types (recordFields)
import Pudu.Core
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned))
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| The record must be laid out as `groups: Map[K, Array[V]]` and
    `occurrences: Map[(K, V), Int]`. Add tests the key, then the pair, then
    counts with a checked add: the order the interpreter fails in. Both maps
    take the new key's spelling. -}
multiMapBody :: Blame -> Text -> CoreType -> LowerState -> Span -> [CoreExpression] -> Lowered
multiMapBody blame name signature state at arguments = case signature of
  CoreFunctionType [record, key, value] result
    | map coreExpressionType arguments == [record, key, value]
    , recordFields types record == Just [("groups", groupsOf key value), ("occurrences", countsOf key value)] ->
        case name of
          "multiMapAdd" | result == record -> adding record key value
          "multiMapContains" | result == CoreBoolType -> containing record key value
          _ -> wrong
  _ -> wrong
 where
  types = contextTypes (lowerContext state)
  wrong = halt at ("a " <> name <> " value without its MultiMap signature") state
  groupsOf key value = CoreMapType key (CoreArrayType value)
  countsOf key value = CoreMapType (CoreTupleType [key, value]) intType
  expression kind shape = CoreExpression at kind shape
  reading local = expression (coreLocalType local) (CoreReadLocal local)
  declare local core = CoreStatement at (CoreDeclare local core)
  -- The operands, held in the order they ran.
  held record key value =
    let (withMap, mapLocal) = bindLocal state "" record
        (withKey, keyLocal) = bindLocal withMap "" key
        (withValue, valueLocal) = bindLocal withKey "" value
     in (withValue, (mapLocal, keyLocal, valueLocal), zipWith declare [mapLocal, keyLocal, valueLocal] arguments)
  containing record key value =
    let (after, (mapLocal, keyLocal, valueLocal), declares) = held record key value
        pair = expression (CoreTupleType [key, value]) (CoreTuple [reading keyLocal, reading valueLocal])
        counts = expression (countsOf key value) (CoreField "occurrences" (reading mapLocal))
        found = expression CoreBoolType (CoreKeyedMethod KeyedContains counts [pair])
     in (after, Just (expression CoreBoolType (CoreBlockValue (CoreBlock declares (Just found))), CoreBoolType))
  adding record key value =
    let (withOperands, (mapLocal, keyLocal, valueLocal), declares) = held record key value
        pairType = CoreTupleType [key, value]
        groupType = CoreArrayType value
        (withGroups, groupsLocal) = bindLocal withOperands "" (groupsOf key value)
        (withPair, pairLocal) = bindLocal withGroups "" pairType
        (after, countsLocal) = bindLocal withPair "" (countsOf key value)
        keyed kind operation local operands = expression kind (CoreKeyedMethod operation (reading local) operands)
        group = expression groupType (CoreIfValue
          (keyed CoreBoolType KeyedContains groupsLocal [reading keyLocal])
          (CoreBlock [] (Just (expression groupType (CoreArrayMethod ArrayPushValue
            (keyed groupType KeyedLookup groupsLocal [reading keyLocal]) [reading valueLocal]))))
          (expression groupType (CoreArray [reading valueLocal])))
        one = expression intType (CoreIntegerLiteral PlatformSigned 1)
        count = expression intType (CoreIfValue
          (keyed CoreBoolType KeyedContains countsLocal [reading pairLocal])
          (CoreBlock [] (Just (expression intType (CoreBinary CoreAdd
            (keyed intType KeyedLookup countsLocal [reading pairLocal]) one))))
          one)
        statements = declares
          <> [orderable blame at "map key" (reading keyLocal) | mayHoldFunction types key]
          <> [ declare groupsLocal (expression (groupsOf key value) (CoreField "groups" (reading mapLocal)))
             , declare pairLocal (expression pairType (CoreTuple [reading keyLocal, reading valueLocal])) ]
          <> [orderable blame at "map key" (reading pairLocal) | mayHoldFunction types pairType]
          <> [declare countsLocal (expression (countsOf key value) (CoreField "occurrences" (reading mapLocal)))]
        answer = expression record (CoreRecordUpdate (reading mapLocal)
          [ ("groups", keyed (groupsOf key value) KeyedPut groupsLocal [reading keyLocal, group])
          , ("occurrences", keyed (countsOf key value) KeyedPut countsLocal [reading pairLocal, count]) ])
     in (after, Just (expression record (CoreBlockValue (CoreBlock statements (Just answer))), record))
