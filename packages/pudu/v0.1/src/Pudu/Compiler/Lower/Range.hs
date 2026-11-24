{-| @Pudu.Compiler.Lower.Range — ranges as values: built from the ends
    written, and their methods, as `Eval.Range` answers them. The receiver
    runs before arguments. -}
module Pudu.Compiler.Lower.Range (lowerRangeValue, lowerRangeMethod, selectRangeEndpoint, selectRangeItems) where

import Data.List (mapAccumL)
import Data.Text (Text)
import Pudu.Compiler.Lower.Arguments
  ( ArgumentSlot (..), argumentFailure, callWithRuntimeArguments, collectArguments
  , exactPosition, methodArgumentBlame, positionSlot
  )
import Pudu.Compiler.Lower.Dynamic (joinRuntimeArms, mapRuntimeChoice)
import Pudu.Compiler.Lower.Array (LowerCallback, lowerArrayLoop, stopped, stops)
import Pudu.Compiler.Lower.ArrayLoop (CallbackSpecializer)
import Pudu.Compiler.Lower.State (LowerState, bindLocal, halt, intType, refused)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.IntegerLiteral (IntegerKind (BigIntKind, ExactIntKind))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| `a..b` and its other shapes as a value: the start runs, then the end. -}
lowerRangeValue :: LowerExpression -> LowerState -> Span -> Maybe (Located Expression) -> Bool -> Maybe (Located Expression) -> Lowered
lowerRangeValue lower state at low inclusive high =
  case collectArguments lower state (foldMap pure low <> foldMap pure high) of
    (after, Nothing) -> refused after
    (after, Just operands)
      | any stops operands -> (after, Just (stopped at operands, CoreNeverType))
      | all ((== intType) . coreExpressionType) operands -> construct after operands
      | otherwise ->
          let (bound, locals) = mapAccumL (\current operand -> bindLocal current "" (coreExpressionType operand)) after operands
              declarations = zipWith (\local operand -> CoreStatement at (CoreDeclare local operand)) locals operands
              reading local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
              (ready, result) = validate bound [] (map reading locals)
           in (ready, (\(value, kind) -> (CoreExpression at kind (CoreBlockValue (CoreBlock declarations (Just value))), kind)) <$> result)
 where
  validate current done [] = construct current (reverse done)
  validate current done (first : rest) = selectRangeEndpoint at current first
    (\ready held -> validate ready (held : done) rest)
  construct current operands =
    let (start, end) = case (low, high, operands) of
          (Just _, Just _, [l, h]) -> (Just l, Just h)
          (Just _, Nothing, [l]) -> (Just l, Nothing)
          (Nothing, Just _, [h]) -> (Nothing, Just h)
          _ -> (Nothing, Nothing)
        shape = CoreRangeValue (asExact at <$> start) inclusive (asExact at <$> end)
     in (current, Just (CoreExpression at CoreRangeType shape, CoreRangeType))

exactIntegerType :: CoreType
exactIntegerType = CoreIntegerType BigIntKind

exactInt :: CoreType
exactInt = CoreIntegerType ExactIntKind

asExact :: Span -> CoreExpression -> CoreExpression
asExact at operand
  | coreExpressionType operand == exactIntegerType = operand
  | otherwise = CoreExpression at exactIntegerType (CoreIntegerConvert BigIntKind operand)

{-| Endpoint expressions have already run. Validation observes their held kinds. -}
selectRangeEndpoint :: Span -> LowerState -> CoreExpression -> (LowerState -> CoreExpression -> Lowered) -> Lowered
selectRangeEndpoint at state endpoint consume
  | Just selected <- mapRuntimeChoice state at CoreNeverType endpoint
      (\ready held -> fmap (fmap fst) (selectRangeEndpoint at ready held consume)) = selected
  | CoreIntegerType _ <- coreExpressionType endpoint = consume state endpoint
  | otherwise =
      let expression = CoreExpression at
          prefix = expression CoreTextType (CoreTextLiteral "a range end must be a whole number, not a ")
          kind = expression CoreTextType (CoreRuntimeKind endpoint)
          message = expression CoreTextType (CoreBinary CoreAdd prefix kind)
       in (state, Just (expression CoreNeverType (CoreFailText "E7001" Nothing message Nothing), CoreNeverType))

{-| A method of a range value; Nothing when the receiver is not one. -}
lowerRangeMethod :: LowerExpression -> LowerCallback -> CallbackSpecializer -> LowerState -> Span -> CoreExpression -> Text
  -> [Located Expression] -> Lowered
lowerRangeMethod lower lowerCallback specialize state at receiver member arguments = case member of
  _ | member `elem` ["map", "filter", "reduce"], length arguments /= callbackArity ->
      validated (replicate callbackArity AnySlot) (\ready _ -> refused ready)
  _ | member `elem` ["map", "filter", "reduce"] ->
      selectRangeItems at state receiver $ \ready held arrayKind ->
        let items target = CoreExpression at arrayKind (CoreRangeMethod (RangeValuesFor member) target [])
         in lowerArrayLoop lower lowerCallback specialize ready at held member arguments arrayKind items
  "start" -> optional RangeHasStart RangeStartExact
  "end" -> optional RangeHasEnd RangeEndExact
  _ -> case lookup member direct of
    Just (name, parameters, result) -> plain name parameters result
    Nothing -> halt at ("the Range method '" <> member <> "'") state
 where
  numbers = CoreArrayType intType
  direct =
    [ ("length", (RangeLengthOf, [], intType))
    , ("isEmpty", (RangeIsEmptyOf, [], CoreBoolType))
    , ("contains", (RangeContainsValue, [intType], CoreBoolType))
    , ("isInclusive", (RangeIsInclusiveOf, [], CoreBoolType))
    , ("isBounded", (RangeIsBoundedOf, [], CoreBoolType))
    , ("toArray", (RangeValuesFor "toArray", [], numbers))
    , ("reverse", (RangeReversedOf, [], numbers))
    , ("step", (RangeStepBy, [intType], numbers))
    , ("sum", (RangeSumOf, [], intType)) ]
  operands = fmap (fmap (receiver :)) (collectArguments lower state arguments)
  callbackArity = if member == "reduce" then 2 else 1
  failure = argumentFailure (methodArgumentBlame state) at "E7012" ("wrong arguments for " <> member)
  validated slots apply = case operands of
    (after, Nothing) -> refused after
    (after, Just cores) -> callWithRuntimeArguments at failure (ExactSlot CoreRangeType : slots) apply after cores
  plain name parameters result = validated (map positionSlot parameters) invoke
   where
    invoke current (target : rest)
      | result == numbers =
          let (receiving, receiver') = bindLocal current "" (coreExpressionType target)
              (held, locals) = mapAccumL (\ready operand -> bindLocal ready "" (coreExpressionType operand)) receiving rest
              readLocal local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
              declarations = CoreStatement at (CoreDeclare receiver' target)
                : zipWith (\local operand -> CoreStatement at (CoreDeclare local operand)) locals rest
              -- The item selection lowers both materializers; the operands are declared once around them.
              declared (ready, lowered) = (ready, fmap (\(core, kind) ->
                (CoreExpression at kind (CoreBlockValue (CoreBlock declarations (Just core))), kind)) lowered)
           in declared $ selectRangeItems at held (readLocal receiver') $ \ready value arrayKind ->
                (ready, Just (CoreExpression at arrayKind (CoreRangeMethod name value (map (asExact at . readLocal) locals)), arrayKind))
      | otherwise = (current, Just (CoreExpression at result (CoreRangeMethod name target (map (asExact at) rest)), result))
    invoke current _ = refused current
  -- start and end: Some of the end when the range has it, None otherwise.
  optional has value = validated [] buildOption
   where
    buildOption after [core] =
      let (withRange, range) = bindLocal after "" CoreRangeType
          (ready, number) = bindLocal withRange "" exactIntegerType
          expression = CoreExpression at
          read' local = expression (coreLocalType local) (CoreReadLocal local)
          optionOf kind = CoreSumType "Option" [kind]
          option = optionOf intType
          some kind payload = expression (optionOf kind) (CoreConstruct "Some" [("0", payload)])
          none = expression option (CoreConstruct "None" [])
          (fits, narrowed) = exactPosition at (read' number)
          yes = CoreLiteralPattern (expression CoreBoolType (CoreBoolLiteral True))
          available = expression CoreBoolType (CoreRangeMethod has (read' range) [])
          initial = CoreStatement at (CoreDeclare number (expression exactIntegerType (CoreRangeMethod value (read' range) [])))
          ordinary = expression option (CoreIfValue available (CoreBlock [] (Just (some intType narrowed))) none)
          choice = joinRuntimeArms at option fits
            [ CoreArm at yes Nothing ordinary
            , CoreArm at CoreWildcardPattern Nothing (some exactInt (expression exactInt (CoreIntegerConvert ExactIntKind (read' number)))) ]
          carrier = coreExpressionType choice
          declarations = [CoreStatement at (CoreDeclare range core), initial]
       in (ready, Just (expression carrier (CoreBlockValue (CoreBlock declarations (Just choice))), carrier))
    buildOption after _ = refused after

{-| The narrow materializer is valid only when every included member fits Int. -}
selectRangeItems :: Span -> LowerState -> CoreExpression
  -> (LowerState -> CoreExpression -> CoreType -> Lowered) -> Lowered
selectRangeItems at state range consume
  | Just selected <- mapRuntimeChoice state at CoreNeverType range
      (\ready value -> fmap (fmap fst) (selectRangeItems at ready value consume)) = selected
  | coreExpressionType range /= CoreRangeType = halt at "a range operation without a held range" state
  | otherwise =
      let expression = CoreExpression at
          (held, local) = bindLocal state "" CoreRangeType
          reading = expression CoreRangeType (CoreReadLocal local)
          condition = expression CoreBoolType (CoreRangeMethod RangeMembersFitInt reading [])
          (narrow, left) = consume held reading (CoreArrayType intType)
          (ready, right) = consume narrow reading (CoreArrayType exactInt)
          yes = CoreLiteralPattern (expression CoreBoolType (CoreBoolLiteral True))
          declared = CoreStatement at (CoreDeclare local range)
       in (ready, do
            (ordinary, _) <- left
            (exact, _) <- right
            let choice = joinRuntimeArms at CoreNeverType condition
                  [CoreArm at yes Nothing ordinary, CoreArm at CoreWildcardPattern Nothing exact]
                kind = coreExpressionType choice
            pure (expression kind (CoreBlockValue (CoreBlock [declared] (Just choice))), kind))
