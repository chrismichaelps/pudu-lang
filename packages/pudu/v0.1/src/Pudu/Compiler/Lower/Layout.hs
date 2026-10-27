{-| @Pudu.Compiler.Lower.Layout — the layout of every record and sum a lowered
    module mentions, including those only reachable through other layouts. -}
module Pudu.Compiler.Lower.Layout (moduleLayouts) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Pudu.Compiler.Lower.Types (LowerTypes, layoutOf)
import Data.Text (Text)
import Pudu.Core

{-| A function type lists the lifted functions whose closure parameter has
    that type; one no closure was made for still gets its empty list, so its
    values have helpers like any other. -}
moduleLayouts :: LowerTypes -> Map Text CoreClosureInfo -> [CoreFunction] -> Map CoreType CoreLayout
moduleLayouts types closures functions = close Map.empty (concatMap functionTypes functions)
 where
  lifted =
    [ (kind, (coreFunctionName function, info))
    | function <- functions
    , Just info <- [Map.lookup (coreFunctionName function) closures]
    , CoreParameter (CoreLocal _ _ kind) _ : _ <- [coreFunctionParameters function] ]
  close found [] = found
  close found (kind : rest)
    | Map.member kind found = close found rest
    | otherwise = case kind of
        CoreTupleType members -> close found (members <> rest)
        CoreArrayType element -> close found (element : rest)
        CoreMapType key value -> close found (key : value : CoreTupleType [key, value] : rest)
        CoreSetType member -> close found (member : rest)
        CoreFunctionType inputs result ->
          let layout = CoreClosureLayout [entry | (owner, entry) <- lifted, owner == kind]
           in close (Map.insert kind layout found) (inputs <> [result] <> layoutTypes layout <> rest)
        _ -> case layoutOf types kind of
          Just layout -> close (Map.insert kind layout found) (layoutTypes layout <> rest)
          Nothing -> close found rest

layoutTypes :: CoreLayout -> [CoreType]
layoutTypes layout = case layout of
  CoreRecordLayout fields -> map snd fields
  CoreSumLayout variants -> concatMap (map snd . coreVariantFields) variants
  CoreClosureLayout entries -> concatMap (closureCaptures . snd) entries

functionTypes :: CoreFunction -> [CoreType]
functionTypes function =
  coreFunctionResult function
    : map (coreLocalType . coreParameterLocal) (coreFunctionParameters function)
    <> block (coreFunctionBody function)

block :: CoreBlock -> [CoreType]
block (CoreBlock statements result) = concatMap statement statements <> foldMap expression result

statement :: CoreStatement -> [CoreType]
statement (CoreStatement _ shape) = case shape of
  CoreDeclare local value -> coreLocalType local : expression value
  CoreAssign local value -> coreLocalType local : expression value
  CoreEvaluate value -> expression value
  CoreIf condition yes no -> expression condition <> block yes <> foldMap expression no
  CoreReturn value -> foldMap expression value
  CoreBreak _ value -> foldMap expression value
  CoreContinue _ -> []

expression :: CoreExpression -> [CoreType]
expression (CoreExpression _ kind shape) = kind : case shape of
  CoreNegate operand -> expression operand
  CoreComplement operand -> expression operand
  CoreNot operand -> expression operand
  CoreBinary _ left right -> expression left <> expression right
  CoreDisplay operand -> expression operand
  CoreShow operand -> expression operand
  CoreTextMethod _ receiver arguments -> concatMap expression (receiver : arguments)
  CoreCharCode operand -> expression operand
  CoreIntegerFits _ operand -> expression operand
  CoreIntegerConvert _ operand -> expression operand
  CoreTuple members -> concatMap expression members
  CoreTupleIndex _ operand -> expression operand
  CoreRecord fields -> concatMap (expression . snd) fields
  CoreRecordUpdate base fields -> expression base <> concatMap (expression . snd) fields
  CoreField _ operand -> expression operand
  CoreConstruct _ fields -> concatMap (expression . snd) fields
  CoreMatch subject arms -> expression subject <> concatMap arm arms
  CoreFailText _ _ message help -> expression message <> foldMap expression help
  CoreVariantName operand -> expression operand
  CorePrint operand -> expression operand
  CoreCall _ arguments -> concatMap expression arguments
  CoreClosure _ captures -> concatMap expression captures
  CoreCapture _ operand -> expression operand
  CoreCallValue callee arguments -> concatMap expression (callee : arguments)
  CoreArray members -> concatMap expression members
  CoreArrayMethod _ receiver arguments -> concatMap expression (receiver : arguments)
  CoreKeyedMethod _ receiver arguments -> concatMap expression (receiver : arguments)
  CoreComparable operand -> expression operand
  CoreIndex container index -> expression container <> expression index
  CoreTakeLocal local -> [coreLocalType local]
  CoreOperatorFailure _ operands -> concatMap expression operands
  CoreBlockValue inner -> block inner
  CoreIfValue condition yes no -> expression condition <> block yes <> expression no
  CoreWhileValue _ condition body -> expression condition <> block body
  CoreLoopValue _ body -> block body
  _ -> []
 where
  arm (CoreArm _ pattern' guard' body) = pattern pattern' <> foldMap expression guard' <> expression body

pattern :: CorePattern -> [CoreType]
pattern shape = case shape of
  CoreBindPattern local -> [coreLocalType local]
  CoreLiteralPattern value -> expression value
  CoreRangePattern low _ high -> expression low <> expression high
  CoreTuplePattern members -> concatMap pattern members
  CoreRecordPattern members -> concatMap pattern members
  CoreVariantPattern _ members -> concatMap pattern members
  CoreAlternativePattern members -> concatMap pattern members
  CoreArrayPattern front rest back -> concatMap pattern (front <> back) <> foldMap (foldMap (pure . coreLocalType)) rest
  CoreWildcardPattern -> []
