{-| @Pudu.Compiler.Lower.For — `for` over a written range or a type with
    `begin` and `advance`, as an ordinary native loop. -}
module Pudu.Compiler.Lower.For (lowerFor) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued, popLoop, pushLoop)
import Pudu.Compiler.Lower.Match (lowerPattern)
import Pudu.Compiler.Lower.Method (callInstance)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (ownerKeyOf, typeForSpan)
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
  RangeExpression{} -> halt (locatedSpan iterated) "a for loop over a range without both ends" state
  _ -> case typeForSpan (contextTypes (lowerContext state)) (locatedSpan iterated) of
    Just kind
      | Just owner <- ownerKeyOf kind
      , Just begin <- Map.lookup (owner, "begin") (contextMethods (lowerContext state))
      , Just advance <- Map.lookup (owner, "advance") (contextMethods (lowerContext state)) ->
          case lower state iterated of
            (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
            (after, Just (core, _)) -> walkSequence after core kind begin advance
            (after, Nothing) -> refused after
    Just kind -> halt (locatedSpan iterated) ("a for loop over a " <> coreTypeName kind) state
    Nothing -> halt (locatedSpan iterated) "a for loop over this value" state
 where
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
      let (afterBody, coreBody, bodyType) = block afterPattern body
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

