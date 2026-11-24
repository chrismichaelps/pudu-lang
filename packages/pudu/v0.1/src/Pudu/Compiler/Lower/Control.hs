{-| @Pudu.Compiler.Lower.Control — numeric lexical loop targets and Never joins.
    Traversal callbacks keep the expression/block recursion owned by Body. -}
module Pudu.Compiler.Lower.Control
  ( lowerWhile, lowerLoop, lowerTransfer, blockType, joinType, joinBranchValues, pushLoop, popLoop
  , ConditionUse (StrictCondition, MatchGuard), lowerCondition
  , printValued, expressionIsPrintValued, droppedTail
  ) where

import Control.Applicative ((<|>))
import Data.List (mapAccumL)
import Data.Maybe (fromMaybe, isJust)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Compiler.Lower.Dynamic
  ( commonAggregateCarrier, isDynamic, joinRuntimeArms, projectRuntimeValue, runtimeCarriers, runtimeResultType )
import Pudu.Compiler.Lower.State
  ( LowerContext (..), LowerState (..), LoopFrame (..), bindLocal, halt, refused )
import Pudu.Compiler.Lower.Types (nativeValueType, sumVariants, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Block (..), Expression, Located (..), Statement (..))
import Pudu.Source (Span)

type ExpressionLowerer = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type BlockLowerer = LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)

data ConditionUse = StrictCondition | MatchGuard

{-| A guard accepts only true. A strict condition diagnoses any non-Bool. -}
lowerCondition :: ConditionUse -> Span -> ExpressionLowerer -> ExpressionLowerer
lowerCondition use at lower state written = case lower state written of
  (after, Nothing) -> refused after
  (after, Just (value, _)) -> select after value
 where
  expression kind shape = CoreExpression at kind shape
  select current held
    | kind `elem` [CoreBoolType, CoreNeverType] = (current, Just (held, kind))
    | isDynamic kind || isJust (runtimeChoiceAlternatives kind) =
        case sumVariants (contextTypes (lowerContext current)) kind >>= traverse payloadOf of
          Nothing -> halt at "a condition without a settled payload layout" current
          Just variants ->
            let (after, arms) = mapAccumL arm current variants
                result = joinRuntimeArms at CoreBoolType held <$> sequence arms
             in (after, (\value -> (value, coreExpressionType value)) <$> result)
    | otherwise = case use of
        StrictCondition ->
          let text = expression CoreTextType
              message = text (CoreBinary CoreAdd (text (CoreTextLiteral "expected a bool, found a "))
                (text (CoreRuntimeKind held)))
           in (current, Just (expression CoreNeverType (CoreFailText "E7001" Nothing message Nothing), CoreNeverType))
        MatchGuard ->
          let effects = [CoreStatement (coreExpressionSpan held) (CoreEvaluate held)]
              value = expression CoreBoolType (CoreBlockValue (CoreBlock effects (Just (expression CoreBoolType (CoreBoolLiteral False)))))
           in (current, Just (value, CoreBoolType))
   where
    kind = coreExpressionType held
  payloadOf variant = case coreVariantFields variant of
    [(_, payload)] -> Just (coreVariantName variant, payload)
    _ -> Nothing
  arm current (tag, kind) =
    let (bound, local) = bindLocal current "" kind
        (after, result) = select bound (expression kind (CoreReadLocal local))
     in (after, (\(body, _) -> CoreArm at (CoreVariantPattern tag [CoreBindPattern local]) Nothing body) <$> result)

lowerWhile :: ExpressionLowerer -> BlockLowerer -> Span -> Maybe (Located Text) -> Located Expression -> Located Block -> LowerState -> (LowerState, Maybe (CoreExpression, CoreType))
lowerWhile lower block spanValue label condition body state =
  case lowerCondition StrictCondition spanValue lower state condition of
    (after, Just stopped@(_, CoreNeverType)) -> (after, Just stopped)
    (afterCondition, Just (coreCondition, _)) ->
      let (pushed, identity) = pushLoop label afterCondition
          (afterBody, coreBody, _) = block pushed (droppedTail body)
       in (popLoop afterBody, Just (CoreExpression spanValue CoreUnitType (CoreWhileValue identity coreCondition coreBody), CoreUnitType))
    (after, Nothing) -> refused after

lowerLoop :: BlockLowerer -> Span -> Maybe (Located Text) -> Located Block -> LowerState -> (LowerState, Maybe (CoreExpression, CoreType))
lowerLoop block spanValue label body state = settle (maybe Set.empty Set.singleton checked) checked
 where
  checked = typeForSpan (contextTypes (lowerContext state)) spanValue
  loopBody = droppedTail body
  settle attempted expected =
    let (pushed, identity) = pushLoopWith expected label state
        (after, coreBody, _) = block pushed loopBody
        back = popLoop after
        breaks = case lowerLoops after of
          frame : _ -> Set.toList (loopBreakTypes frame)
          [] -> []
        done kind = (back, Just (CoreExpression spanValue kind (CoreLoopValue identity coreBody), kind))
     in case breaks of
          [] -> done CoreNeverType
          [kind] -> done kind
          first : _ ->
            let types = contextTypes (lowerContext after)
                guide = fromMaybe first checked
                shared = fromMaybe (runtimeResultType guide (foldMap runtimeCarriers breaks))
                  (commonAggregateCarrier types guide breaks)
             in if Set.member shared attempted
                  then halt spanValue "loop breaks with incompatible native layouts" back
                  else settle (Set.insert shared attempted) (Just shared)

{-| A loop body's value is thrown away each turn, so its tail is just another
    statement. Lowered that way, a tail like `match ... { case _ => print(..) }`
    doesn't have to produce print's Result. -}
droppedTail :: Located Block -> Located Block
droppedTail (Located at (Block statements (Just tail'))) =
  Located at (Block (statements <> [Located (locatedSpan tail') (ExpressionStatement tail')]) Nothing)
droppedTail body = body

pushLoop :: Maybe (Located Text) -> LowerState -> (LowerState, CoreLoopId)
pushLoop = pushLoopWith Nothing

pushLoopWith :: Maybe CoreType -> Maybe (Located Text) -> LowerState -> (LowerState, CoreLoopId)
pushLoopWith expected label state =
  let identity = CoreLoopId (lowerNextLoop state)
      frame = LoopFrame identity (locatedValue <$> label) expected Set.empty
   in (state{lowerNextLoop = lowerNextLoop state + 1, lowerLoops = frame : lowerLoops state}, identity)

popLoop :: LowerState -> LowerState
popLoop state = state{lowerLoops = drop 1 (lowerLoops state)}

{-| The operand finishes before observing this break. In particular a Never
    operand can already transfer to this or an enclosing destination. -}
lowerTransfer :: ExpressionLowerer -> Span -> Maybe (Located Text) -> Maybe (Maybe (Located Expression)) -> LowerState -> (LowerState, Maybe CoreStatement)
lowerTransfer expression spanValue label transfer state = case destination of
  Nothing -> halt spanValue "a loop transfer without a native target" state
  Just frame -> case transfer of
    Nothing -> built state (CoreContinue identity)
    Just Nothing -> projectBreak frame state Nothing
    Just (Just operand) -> case expression state operand of
      (after, Just (coreOperand, _))
        | expressionIsPrintValued coreOperand -> halt (locatedSpan operand) "breaking with a Result[(), Str] value" after
        | otherwise -> projectBreak frame after (Just coreOperand)
      (after, Nothing) -> refused after
    where
      identity = loopIdentity frame
  where
    destination = case [frame | frame <- lowerLoops state, maybe True (\name -> loopLabel frame == Just (locatedValue name)) label] of
      frame : _ -> Just frame
      [] -> Nothing
    built after shape = (after, Just (CoreStatement spanValue shape))
    projectBreak frame after operand
      | kind == CoreNeverType = built ready transfer'
      | nativeValueType kind = built ready{lowerLoops = map observe (lowerLoops ready)} transfer'
      | otherwise = halt (coreExpressionSpan value) ("breaking with a " <> coreTypeName kind <> " value") ready
      where
        unit = CoreExpression spanValue CoreUnitType (CoreBlockValue (CoreBlock [] Nothing))
        value = fromMaybe unit operand
        (ready, projected) = case loopExpectedBreakType frame of
          Nothing -> (after, value)
          Just expected -> projectRuntimeValue (contextTypes (lowerContext after)) after expected value
        kind = coreExpressionType projected
        payload = case operand of
          Nothing | kind == CoreUnitType -> Nothing
          _ -> Just projected
        transfer' = CoreBreak (loopIdentity frame) payload
        observe destinationFrame
          | loopIdentity destinationFrame == loopIdentity frame =
              destinationFrame{loopBreakTypes = Set.insert kind (loopBreakTypes destinationFrame)}
          | otherwise = destinationFrame

joinType :: CoreType -> CoreType -> Maybe CoreType
joinType CoreNeverType right = Just right
joinType left CoreNeverType = Just left
joinType left right | left == right = Just left
joinType _ _ = Nothing

{-| Project returning arms independently so selecting a layout never runs an
    unchosen arm. Divergent arms only carry their transfer. -}
joinBranchValues :: LowerState -> Maybe CoreType -> [CoreExpression]
  -> Maybe (LowerState, CoreType, [CoreExpression])
joinBranchValues state checked values =
  case foldr (\kind previous -> previous >>= joinType kind) (Just CoreNeverType) kinds of
    Just kind -> Just (state, kind, values)
    Nothing -> fromChecked <|> fromHeld
 where
  kinds = map coreExpressionType values
  live = filter (/= CoreNeverType) kinds
  types = contextTypes (lowerContext state)
  fromChecked = checked >>= project
  fromHeld = case live of
    [] -> Nothing
    first : _ ->
      let guide = fromMaybe first checked
          aggregate = commonAggregateCarrier types guide live >>= project
          alternatives = runtimeResultType guide (foldMap runtimeCarriers live)
       in aggregate <|> project alternatives
  project kind =
    let (ready, projected) = mapAccumL (\prior -> projectRuntimeValue types prior kind) state values
     in if all ((`elem` [kind, CoreNeverType]) . coreExpressionType) projected
          then Just (ready, kind, projected)
          else Nothing

blockType :: [CoreStatement] -> Maybe CoreExpression -> CoreType
blockType statements result
  | any terminal statements = CoreNeverType
  | otherwise = maybe CoreUnitType coreExpressionType result
  where
    terminal (CoreStatement _ shape) = case shape of
      CoreReturn _ -> True
      CoreBreak _ _ -> True
      CoreContinue _ -> True
      CoreEvaluate expression -> coreExpressionType expression == CoreNeverType
      CoreDeclare _ expression -> coreExpressionType expression == CoreNeverType
      CoreAssign _ expression -> coreExpressionType expression == CoreNeverType
      CoreIf condition _ _ -> coreExpressionType condition == CoreNeverType

printValued :: CoreBlock -> Bool
printValued block
  | blockType (coreBlockStatements block) (coreBlockResult block) == CoreNeverType = False
  | otherwise = maybe False expressionIsPrintValued (coreBlockResult block)

expressionIsPrintValued :: CoreExpression -> Bool
expressionIsPrintValued expression
  | coreExpressionType expression == CoreNeverType = False
  | otherwise = case coreExpressionShape expression of
      CorePrint _ -> True
      CoreBlockValue block -> printValued block
      CoreIfValue _ thenBlock elseExpression -> printValued thenBlock || expressionIsPrintValued elseExpression
      _ -> False
