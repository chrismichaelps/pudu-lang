{-| @Pudu.Compiler.Lower.Sort — `sortBy` as native loops. The comparison is a
    program's own closure, which may print or fail, so the sort must ask it
    the same questions in the same order as `Eval.Sort.sortWith`: cut the
    items into the runs they already hold, then merge runs in pairs, round
    after round, until one is left. -}
module Pudu.Compiler.Lower.Sort (sortStatements) where

import Pudu.Compiler.Lower.Control (popLoop, pushLoop)
import Pudu.Compiler.Lower.State (LowerState, bindLocal, intType)
import Pudu.Core
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

{-| The statements sorting `items` with `before` (both already evaluated
    into locals) and the local holding the result. `before x y` answers
    whether x goes before y. -}
sortStatements :: LowerState -> Span -> CoreLocal -> CoreLocal -> (LowerState, [CoreStatement], CoreLocal)
sortStatements state at items before =
  let kind = coreLocalType items
      element = case kind of
        CoreArrayType held -> held
        other -> other
      runsKind = CoreArrayType kind
      (s1, count) = hidden state intType
      (s2, runs) = hidden s1 runsKind
      (s3, index) = hidden s2 intType
      (s4, gathered) = hidden s3 kind
      (s5, ahead) = hidden s4 intType
      (s6, falling) = hidden s5 CoreBoolType
      (s7, falls) = hidden s6 CoreBoolType
      (s8, runCount) = hidden s7 intType
      (s9, merged) = hidden s8 runsKind
      (s10, pair) = hidden s9 intType
      (s11, left) = hidden s10 kind
      (s12, right) = hidden s11 kind
      (s13, leftCount) = hidden s12 intType
      (s14, rightCount) = hidden s13 intType
      (s15, fromLeft) = hidden s14 intType
      (s16, fromRight) = hidden s15 intType
      (s17, out) = hidden s16 kind
      (s18, rightFirst) = hidden s17 CoreBoolType
      (s19, result) = hidden s18 kind
      (s20, first) = hidden s19 element
      (s21, second) = hidden s20 element
      (s22, current) = hidden s21 element
      (s23, next) = hidden s22 element
      (s24, leftItem) = hidden s23 element
      (s25, rightItem) = hidden s24 element
      (s26, rising) = hidden s25 element

      (o1, outer) = pushLoop Nothing s26
      (o2, descending) = pushLoop Nothing o1
      (o3, ascending) = pushLoop Nothing (popLoop o2)
      (o4, passes) = pushLoop Nothing (popLoop (popLoop o3))
      (o5, pairs) = pushLoop Nothing o4
      (o6, merging) = pushLoop Nothing o5
      final = popLoop (popLoop (popLoop o6))

      asks x y = expression CoreBoolType (CoreCallValue (reading before) [reading x, reading y])
      push target value = assign target (method (coreLocalType target) ArrayPushValue (taken target) [value])
      runAt position = expression kind (CoreIndex (reading runs) position)
      runEnded run = [push runs run]

      -- runsOf: a falling pair opens a descending run, gathered front first.
      cutting =
        [ when' (compare' CoreGreaterOrEqual (reading index) (reading count)) [stop outer]
        , when' (compare' CoreEqual (reading index) (minus (reading count) one))
            ( runEnded (expression kind (CoreArray [item (reading index)])) <> [stop outer] )
        , declare first (item (reading index))
        , declare second (item (plus (reading index) one))
        , assign falling (asks second first)
        , assign gathered (expression kind (CoreArray [reading first]))
        , declare current (reading second)
        , assign ahead (plus (reading index) two)
        , statement (CoreIf (reading falling)
            (CoreBlock [loopOver descending
              [ when' (compare' CoreGreaterOrEqual (reading ahead) (reading count))
                  ( [push gathered (reading current)]
                    <> runEnded (method kind ArrayReversed (reading gathered) [])
                    <> [assign index (reading count), stop descending] )
              , declare next (item (reading ahead))
              , assign falls (asks next current)
              , statement (CoreIf (reading falls)
                  (CoreBlock [push gathered (reading current), assign current (reading next), assign ahead (plus (reading ahead) one)] Nothing)
                  (Just (block
                    ( [push gathered (reading current)]
                      <> runEnded (method kind ArrayReversed (reading gathered) [])
                      <> [assign index (reading ahead), stop descending] )))) ]] Nothing)
            (Just (block [loopOver ascending
              [ when' (compare' CoreGreaterOrEqual (reading ahead) (reading count))
                  ( [push gathered (reading current)] <> runEnded (reading gathered)
                    <> [assign index (reading count), stop ascending] )
              , declare rising (item (reading ahead))
              , assign falls (asks rising current)
              , statement (CoreIf (reading falls)
                  (CoreBlock ([push gathered (reading current)] <> runEnded (reading gathered)
                    <> [assign index (reading ahead), stop ascending]) Nothing)
                  (Just (block [push gathered (reading current), assign current (reading rising), assign ahead (plus (reading ahead) one)]))) ]])))
        ]

      -- merge: the right item goes first only when it comes before the left.
      mergingTurn =
        [ when' (compare' CoreGreaterOrEqual (reading fromLeft) (reading leftCount))
            [ assign out (method kind ArrayConcatWith (taken out) [method kind ArraySliceOf (reading right) [reading fromRight, reading rightCount]])
            , stop merging ]
        , when' (compare' CoreGreaterOrEqual (reading fromRight) (reading rightCount))
            [ assign out (method kind ArrayConcatWith (taken out) [method kind ArraySliceOf (reading left) [reading fromLeft, reading leftCount]])
            , stop merging ]
        , declare rightItem (part right (reading fromRight))
        , declare leftItem (part left (reading fromLeft))
        , assign rightFirst (asks rightItem leftItem)
        , statement (CoreIf (reading rightFirst)
            (CoreBlock [push out (reading rightItem), assign fromRight (plus (reading fromRight) one)] Nothing)
            (Just (block [push out (reading leftItem), assign fromLeft (plus (reading fromLeft) one)]))) ]

      pairing =
        [ when' (compare' CoreGreaterOrEqual (plus (reading pair) one) (reading runCount)) [stop pairs]
        , assign left (runAt (reading pair))
        , assign right (runAt (plus (reading pair) one))
        , assign leftCount (method intType ArrayLengthOf (reading left) [])
        , assign rightCount (method intType ArrayLengthOf (reading right) [])
        , assign fromLeft zero, assign fromRight zero
        , assign out (expression kind (CoreArray []))
        , loopOver merging mergingTurn
        , push merged (reading out)
        , assign pair (plus (reading pair) two) ]

      passing =
        [ assign runCount (method intType ArrayLengthOf (reading runs) [])
        , when' (compare' CoreLessOrEqual (reading runCount) one) [stop passes]
        , assign merged (expression runsKind (CoreArray []))
        , assign pair zero
        , loopOver pairs pairing
        , when' (compare' CoreLess (reading pair) (reading runCount)) [push merged (runAt (reading pair))]
        , assign runs (reading merged) ]

      statements =
        [ declare count (method intType ArrayLengthOf (reading items) [])
        , declare runs (expression runsKind (CoreArray []))
        , declare index zero
        , declare gathered (expression kind (CoreArray []))
        , declare ahead zero
        , declare falling false', declare falls false'
        , loopOver outer cutting
        , declare runCount zero
        , declare merged (expression runsKind (CoreArray []))
        , declare pair zero
        , declare left (expression kind (CoreArray [])), declare right (expression kind (CoreArray []))
        , declare leftCount zero, declare rightCount zero, declare fromLeft zero, declare fromRight zero
        , declare out (expression kind (CoreArray []))
        , declare rightFirst false'
        , loopOver passes passing
        , declare result (expression kind (CoreIfValue
            (compare' CoreEqual (method intType ArrayLengthOf (reading runs) []) zero)
            (CoreBlock [] (Just (expression kind (CoreArray []))))
            (runAt zero))) ]
   in (final, statements, result)
 where
  hidden current kind = bindLocal current "" kind
  expression kind shape = CoreExpression at kind shape
  statement shape = CoreStatement at shape
  block statements = expression CoreUnitType (CoreBlockValue (CoreBlock statements Nothing))
  reading local = expression (coreLocalType local) (CoreReadLocal local)
  taken local = expression (coreLocalType local) (CoreTakeLocal local)
  declare local value = statement (CoreDeclare local value)
  assign local value = statement (CoreAssign local value)
  method kind name receiver arguments = expression kind (CoreArrayMethod name receiver arguments)
  item index = itemOf items index
  part array index = itemOf array index
  itemOf array index = case coreLocalType array of
    CoreArrayType held -> expression held (CoreIndex (reading array) index)
    other -> expression other (CoreIndex (reading array) index)
  number value = expression intType (CoreIntegerLiteral PlatformSigned value)
  zero = number 0
  one = number 1
  two = number 2
  false' = expression CoreBoolType (CoreBoolLiteral False)
  plus a b = expression intType (CoreBinary CoreAdd a b)
  minus a b = expression intType (CoreBinary CoreSubtract a b)
  compare' operator a b = expression CoreBoolType (CoreBinary operator a b)
  when' condition body = statement (CoreIf condition (CoreBlock body Nothing) Nothing)
  stop identity = statement (CoreBreak identity Nothing)
  loopOver identity body = statement (CoreEvaluate (expression CoreUnitType (CoreLoopValue identity (CoreBlock body Nothing))))
