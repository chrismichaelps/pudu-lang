{-| @Pudu.Compiler.Lower.For — `for` over a written range or a type with
    `begin` and `advance`, as an ordinary native loop. -}
module Pudu.Compiler.Lower.For (lowerFor) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Compiler.Lower.Control (droppedTail, expressionIsPrintValued, popLoop, pushLoop)
import Pudu.Compiler.Lower.Match (lowerPattern)
import Pudu.Compiler.Lower.Method (callInstance)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (ownerKeyOf, sumVariants, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Block, Expression (..), Located (..), Pattern)
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type LowerBlock = LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| The loop's value is unit whatever its body does, as `evaluateFor` answers.
    A range written in the head is walked from its two ends, which run once,
    start first; anything else must be a type with `begin` and `advance`. -}
lowerFor :: LowerExpression -> LowerBlock -> LowerState -> Span -> Maybe (Located Text) -> Located Pattern -> Located Expression -> Located Block -> Lowered
lowerFor lower block state at label binder iterated body = case locatedValue iterated of
  RangeExpression (Just start) inclusive (Just end) -> case lowerEnds of
    (after, Nothing) -> refused after
    (after, Just ends@[low, high])
      | any stops ends -> (after, Just (stopped ends, CoreNeverType))
      | all ((== intType) . coreExpressionType) ends -> walkRange after inclusive low high
      | otherwise -> halt (locatedSpan iterated) "a range whose ends are not Int" after
    (after, Just _) -> refused after
   where
    lowerEnds = case lower state start of
      (afterStart, Just (low, _)) | not (expressionIsPrintValued low) -> case lower afterStart end of
        (afterEnd, Just (high, _)) | not (expressionIsPrintValued high) -> (afterEnd, Just [low, high])
        (afterEnd, _) -> (afterEnd, Nothing)
      (afterStart, _) -> (afterStart, Nothing)
  _ -> case typeForSpan (contextTypes (lowerContext state)) (locatedSpan iterated) of
    Just kind@(CoreArrayType itemKind) -> case lower state iterated of
      (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
      (after, Just (core, _)) -> walkArray after core kind itemKind
      (after, Nothing) -> refused after
    -- A map walks its entries, a set its members and a Str its characters,
    -- listed before the body runs.
    Just (CoreMapType key value) -> listed (CoreTupleType [key, value]) (simply (CoreTupleType [key, value]) (\core -> CoreKeyedMethod KeyedEntries core []))
    Just (CoreSetType member) -> listed member (simply member (\core -> CoreKeyedMethod KeyedKeys core []))
    Just CoreTextType -> listed CoreCharType (simply CoreCharType (\core -> CoreTextMethod TextChars core []))
    -- A range value walks its values; one missing an end cannot be walked.
    Just CoreRangeType -> listed intType (simply intType (\core -> CoreRangeMethod RangeIterated core []))
    Just kind@(CoreTupleType members@(first : _))
      | all (== first) members -> listed first (membersOf kind first members)
    Just kind
      | Just owner <- ownerKeyOf kind
      , Just begin <- Map.lookup (owner, "begin") (contextMethods (lowerContext state))
      , Just advance <- Map.lookup (owner, "advance") (contextMethods (lowerContext state)) ->
          case lower state iterated of
            (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
            (after, Just (core, _)) -> walkSequence after core kind begin advance
            (after, Nothing) -> refused after
    -- With no sequence of its own, a sum walks the payload of the variant it
    -- holds, as the evaluator falls back to doing.
    Just kind@(CoreSumType _ _)
      | Just variants <- sumVariants (contextTypes (lowerContext state)) kind
      , (itemKind : others) <- concatMap (map snd . coreVariantFields) variants
      , all (== itemKind) others -> listed itemKind (payloadsOf itemKind variants)
    Just kind -> halt (locatedSpan iterated) ("a for loop over a " <> coreTypeName kind) state
    Nothing -> halt (locatedSpan iterated) "a for loop over this value" state
 where
  listed itemKind toArray = case lower state iterated of
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, _)) ->
      let (ready, array) = toArray after core
       in walkArray ready array (CoreArrayType itemKind) itemKind
    (after, Nothing) -> refused after
  simply itemKind shape current core = (current, expression (CoreArrayType itemKind) (shape core))
  -- The tuple runs once into a local; its members are read from there.
  membersOf kind itemKind members current core =
    let (withTuple, tupleLocal) = hidden current kind
        arrayKind = CoreArrayType itemKind
        held = [expression member (CoreTupleIndex position (reading tupleLocal)) | (position, member) <- zip [0 ..] members]
     in (withTuple, expression arrayKind (CoreBlockValue (CoreBlock [statement (CoreDeclare tupleLocal core)] (Just (expression arrayKind (CoreArray held))))))
  -- One arm per variant, each answering its payload as an array.
  payloadsOf itemKind variants current core =
    let arrayKind = CoreArrayType itemKind
        arm (now, done) variant =
          let fields = coreVariantFields variant
              (next, locals) = foldl (\(here, bound) _ -> let (after', local) = hidden here itemKind in (after', bound <> [local])) (now, []) fields
              answer = expression arrayKind (CoreArray (map reading locals))
           in (next, done <> [CoreArm at (CoreVariantPattern (coreVariantName variant) (map CoreBindPattern locals)) Nothing answer])
        (final, arms) = foldl arm (current, []) variants
     in (final, expression arrayKind (CoreMatch core arms))
  stops core = coreExpressionType core == CoreNeverType
  stopped cores = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock [CoreStatement at (CoreEvaluate core) | core <- cores] Nothing))
  expression kind shape = CoreExpression at kind shape
  reading local = expression (coreLocalType local) (CoreReadLocal local)
  statement shape = CoreStatement at shape
  binary operator kind left right = expression kind (CoreBinary operator left right)
  one = expression intType (CoreIntegerLiteral PlatformSigned 1)
  unit = expression CoreUnitType (CoreBlockValue (CoreBlock [] Nothing))
  opened current = current{lowerScopes = [] : lowerScopes current}
  closed current = current{lowerScopes = drop 1 (lowerScopes current)}
  hidden current kind = bindLocal current "" kind

  -- The element goes through the binder like a match arm; one that does not
  -- match skips the body. The body's value is dropped.
  element current item = case lowerPattern lower (opened current) (coreLocalType item) Map.empty binder of
    (afterPattern, Nothing) -> (closed afterPattern, Nothing)
    (afterPattern, Just (pattern', _)) ->
      let (afterBody, coreBody, bodyType) = block afterPattern (droppedTail body)
          dropped = expression (if bodyType == CoreNeverType then CoreNeverType else CoreUnitType)
            (CoreBlockValue (CoreBlock [statement (CoreEvaluate (expression bodyType (CoreBlockValue coreBody)))] Nothing))
          arms = [CoreArm (locatedSpan binder) pattern' Nothing dropped, CoreArm (locatedSpan binder) CoreWildcardPattern Nothing unit]
       in (closed afterBody, Just (statement (CoreEvaluate (expression CoreUnitType (CoreMatch (reading item) arms)))))

  -- The loop owns its labels; `continue` lands at the top, after the step.
  looped current prefix turn =
    let (pushed, identity) = pushLoop label current
     in case turn pushed identity of
          (afterTurn, Nothing) -> (popLoop afterTurn, Nothing)
          (afterTurn, Just statements) ->
            let finished = expression CoreUnitType (CoreLoopValue identity (CoreBlock statements Nothing))
             in (popLoop afterTurn, Just (expression CoreUnitType (CoreBlockValue (CoreBlock (prefix <> [statement (CoreEvaluate finished)]) Nothing)), CoreUnitType))

  -- `next` is the element about to be taken. An inclusive range checks for
  -- its last element before stepping, so ending at the largest Int does not
  -- overflow, and an exclusive one only steps below its end.
  walkRange current inclusive low high =
    let (withLow, lowLocal) = hidden current intType
        (withHigh, highLocal) = hidden withLow intType
        (withNext, nextLocal) = hidden withHigh intType
        (withMore, moreLocal) = hidden withNext CoreBoolType
        (withItem, itemLocal) = hidden withMore intType
        compare' = if inclusive then CoreLessOrEqual else CoreLess
        prefix =
          [ statement (CoreDeclare lowLocal low), statement (CoreDeclare highLocal high)
          , statement (CoreDeclare nextLocal (reading lowLocal))
          , statement (CoreDeclare moreLocal (binary compare' CoreBoolType (reading lowLocal) (reading highLocal)))
          , statement (CoreDeclare itemLocal (reading lowLocal)) ]
        lastOne = if inclusive then reading highLocal else binary CoreSubtract intType (reading highLocal) one
        turn pushed identity = case element pushed itemLocal of
          (after, Nothing) -> (after, Nothing)
          (after, Just matched) -> (after, Just
            [ statement (CoreIf (expression CoreBoolType (CoreNot (reading moreLocal))) (CoreBlock [statement (CoreBreak identity Nothing)] Nothing) Nothing)
            , statement (CoreAssign itemLocal (reading nextLocal))
            , statement (CoreIf (binary CoreEqual CoreBoolType (reading nextLocal) lastOne)
                (CoreBlock [statement (CoreAssign moreLocal (expression CoreBoolType (CoreBoolLiteral False)))] Nothing)
                (Just (expression CoreUnitType (CoreBlockValue (CoreBlock [statement (CoreAssign nextLocal (binary CoreAdd intType (reading nextLocal) one))] Nothing)))))
            , matched ])
     in looped withItem prefix turn

  -- The array runs once and its length is read once; each turn reads the
  -- next item, as walking the evaluator's list of items does.
  walkArray current core kind itemKind =
    let (withArray, arrayLocal) = hidden current kind
        (withLength, lengthLocal) = hidden withArray intType
        (withNext, nextLocal) = hidden withLength intType
        (withItem, itemLocal) = hidden withNext itemKind
        prefix =
          [ statement (CoreDeclare arrayLocal core)
          , statement (CoreDeclare lengthLocal (expression intType (CoreArrayMethod ArrayLengthOf (reading arrayLocal) [])))
          , statement (CoreDeclare nextLocal (expression intType (CoreIntegerLiteral PlatformSigned 0))) ]
        turn pushed identity = case element pushed itemLocal of
          (after, Nothing) -> (after, Nothing)
          (after, Just matched) -> (after, Just
            [ statement (CoreIf (binary CoreGreaterOrEqual CoreBoolType (reading nextLocal) (reading lengthLocal))
                (CoreBlock [statement (CoreBreak identity Nothing)] Nothing) Nothing)
            , statement (CoreDeclare itemLocal (expression itemKind (CoreIndex (reading arrayLocal) (reading nextLocal))))
            , statement (CoreAssign nextLocal (binary CoreAdd intType (reading nextLocal) one))
            , matched ])
     in looped withItem prefix turn

  -- `begin` runs once; each turn asks `advance` for the next state and item.
  walkSequence current core kind begin advance =
    let (withSequence, sequenceLocal) = hidden current kind
     in case callInstance withSequence at begin Nothing [reading sequenceLocal] of
          (afterBegin, Nothing) -> refused afterBegin
          (afterBegin, Just (started, stateKind)) ->
            let (withState, stateLocal) = hidden afterBegin stateKind
             in case callInstance withState at advance Nothing [reading sequenceLocal, reading stateLocal] of
                  (afterAdvance, Nothing) -> refused afterAdvance
                  (afterAdvance, Just (stepped, CoreSumType "Option" [CoreTupleType [nextKind, itemKind]]))
                    | nextKind == stateKind ->
                        let (withNext, nextLocal) = hidden afterAdvance nextKind
                            (withItem, itemLocal) = hidden withNext itemKind
                            prefix = [statement (CoreDeclare sequenceLocal core), statement (CoreDeclare stateLocal started)]
                            turn pushed identity = case element pushed itemLocal of
                              (after, Nothing) -> (after, Nothing)
                              (after, Just matched) ->
                                let taken = expression CoreUnitType (CoreBlockValue (CoreBlock
                                      [statement (CoreAssign stateLocal (reading nextLocal)), matched] Nothing))
                                    finished = expression CoreNeverType (CoreBlockValue (CoreBlock [statement (CoreBreak identity Nothing)] Nothing))
                                 in (after, Just
                                      [ statement (CoreEvaluate (expression CoreUnitType (CoreMatch stepped
                                          [ CoreArm at (CoreVariantPattern "Some" [CoreTuplePattern [CoreBindPattern nextLocal, CoreBindPattern itemLocal]]) Nothing taken
                                          , CoreArm at (CoreVariantPattern "None" []) Nothing finished ]))) ])
                         in looped withItem prefix turn
                  (afterAdvance, Just (_, other)) -> halt at ("advance answering " <> coreTypeName other) afterAdvance

