{-| @Pudu.Compiler.Lower.TailMove — the final read of a counted local in a
    function's tail becomes a move, so a value the function holds alone
    reaches the next call or update with no extra reference.

    The tail block is read from its result backwards through its statements,
    with the locals read later carried along. A shape not read precisely
    counts as reading every local, so nothing before it moves. -}
module Pudu.Compiler.Lower.TailMove (moveTailReads) where

import qualified Data.Set as Set
import Pudu.Core

-- | The locals read after a point; Nothing when that is not known.
type Later = Maybe (Set.Set Int)

moveTailReads :: CoreFunction -> CoreFunction
moveTailReads function =
  function{coreFunctionBody = fst (block (Just Set.empty) (coreFunctionBody function))}

block :: Later -> CoreBlock -> (CoreBlock, Later)
block later (CoreBlock statements result) =
  let (result', beforeResult) = case result of
        Just value -> let (moved, earlier) = expression later value in (Just moved, earlier)
        Nothing -> (Nothing, later)
      step current (done, after) = let (moved, earlier) = statement after current in (moved : done, earlier)
      (statements', beforeAll) = foldr step ([], beforeResult) statements
   in (CoreBlock statements' result', beforeAll)

statement :: Later -> CoreStatement -> (CoreStatement, Later)
statement later current@(CoreStatement at shape) = case shape of
  CoreDeclare local value -> bound CoreDeclare local value
  CoreAssign local value -> bound CoreAssign local value
  CoreEvaluate value -> let (moved, earlier) = expression later value in (CoreStatement at (CoreEvaluate moved), earlier)
  _ -> (current, Nothing)
 where
  -- The binding's earlier value is not read past this point.
  bound build local value =
    let (moved, earlier) = expression (Set.delete (coreLocalId local) <$> later) value
     in (CoreStatement at (build local moved), earlier)

expression :: Later -> CoreExpression -> (CoreExpression, Later)
expression later current = case coreExpressionShape current of
  CoreReadLocal local
    | movable (coreLocalType local), maybe False (Set.notMember (coreLocalId local)) later ->
        (current{coreExpressionShape = CoreTakeLocal local}, Set.insert (coreLocalId local) <$> later)
    | otherwise -> (current, Set.insert (coreLocalId local) <$> later)
  CoreTakeLocal local -> (current, Set.insert (coreLocalId local) <$> later)
  CoreIntegerLiteral{} -> (current, later)
  CoreFloatLiteral{} -> (current, later)
  CoreDecimalLiteral{} -> (current, later)
  CoreBoolLiteral{} -> (current, later)
  CoreTextLiteral{} -> (current, later)
  CoreBytesLiteral{} -> (current, later)
  CoreCharLiteral{} -> (current, later)
  CoreCall name arguments -> rebuilt (CoreCall name) (operands later arguments)
  CoreTuple items -> rebuilt CoreTuple (operands later items)
  CoreArray items -> rebuilt CoreArray (operands later items)
  CoreRecord fields -> rebuilt (CoreRecord . zip (map fst fields)) (operands later (map snd fields))
  CoreConstruct tag fields -> rebuilt (CoreConstruct tag . zip (map fst fields)) (operands later (map snd fields))
  CoreField name value -> rebuilt (CoreField name) (expression later value)
  CoreTupleIndex index value -> rebuilt (CoreTupleIndex index) (expression later value)
  CoreBinary operator left right ->
    let (right', afterLeft) = expression later right
     in rebuilt (\left' -> CoreBinary operator left' right') (expression afterLeft left)
  CoreRecordUpdate base fields ->
    let (values, afterBase) = operands later (map snd fields)
     in rebuilt (\base' -> CoreRecordUpdate base' (zip (map fst fields) values)) (expression afterBase base)
  CoreArrayMethod name receiver arguments ->
    let (arguments', afterReceiver) = operands later arguments
     in rebuilt (\receiver' -> CoreArrayMethod name receiver' arguments') (expression afterReceiver receiver)
  CoreKeyedMethod name receiver arguments ->
    let (arguments', afterReceiver) = operands later arguments
     in rebuilt (\receiver' -> CoreKeyedMethod name receiver' arguments') (expression afterReceiver receiver)
  CoreBlockValue inner -> rebuilt CoreBlockValue (block later inner)
  _ -> (current, Nothing)
 where
  rebuilt :: (a -> CoreExpressionShape) -> (a, Later) -> (CoreExpression, Later)
  rebuilt build (moved, earlier) = (current{coreExpressionShape = build moved}, earlier)

-- | Operands run left to right, so they are read right to left.
operands :: Later -> [CoreExpression] -> ([CoreExpression], Later)
operands later = foldr step ([], later)
 where
  step operand (done, after) = let (moved, earlier) = expression after operand in (moved : done, earlier)

-- | Only counted aggregates gain from a move; scalars are copied either way.
movable :: CoreType -> Bool
movable kind = case kind of
  CoreArrayType{} -> True
  CoreMapType{} -> True
  CoreSetType{} -> True
  CoreStoreType{} -> True
  CoreRecordType{} -> True
  _ -> False
