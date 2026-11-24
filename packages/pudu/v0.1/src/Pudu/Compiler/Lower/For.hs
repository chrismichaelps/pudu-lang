{-| @Pudu.Compiler.Lower.For — `for` over a written range or a type with
    `begin` and `advance`, as an ordinary native loop. -}
module Pudu.Compiler.Lower.For (lowerFor) where

import Data.List (mapAccumL)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Compiler.Lower.Arguments (ArgumentBlame (AtInvocation), argumentFailureWith, collectArguments, exactPosition)
import Pudu.Compiler.Lower.Control (droppedTail, popLoop, pushLoop)
import Pudu.Compiler.Lower.Dynamic (mapRuntimeChoice, projectRuntimeValue, runtimeCarriers, runtimeResultType)
import Pudu.Compiler.Lower.Match (impossiblePattern, lowerPattern)
import Pudu.Compiler.Lower.Method (callInstance)
import Pudu.Compiler.Lower.Range (selectRangeEndpoint, selectRangeItems)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (ownerKeyOf, sumVariants)
import Pudu.Core
import Pudu.Frontend.Syntax (Block, Expression (..), Located (..), Pattern)
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type LowerBlock = LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| The loop's value is unit whatever its body does, as `evaluateFor` answers.
    A range written in the head is walked from its two ends, which run once,
    start first. Other sources are walked according to their held layout. -}
lowerFor :: LowerExpression -> LowerBlock -> LowerState -> Span -> Maybe (Located Text) -> Located Pattern -> Located Expression -> Located Block -> Lowered
lowerFor lower block state at label binder iterated body = case locatedValue iterated of
  RangeExpression (Just start) inclusive (Just end) ->
    case collectArguments lower state [start, end] of
      (after, Nothing) -> refused after
      (after, Just bounds)
        | any stops bounds -> (after, Just (stopped bounds, CoreNeverType))
        | [low, high] <- bounds
        , all ((== intType) . coreExpressionType) bounds -> walkRange after inclusive low high
        | [low, high] <- bounds -> writtenRange after inclusive low high
        | otherwise -> refused after
  _ -> case lower state iterated of
    (after, Nothing) -> refused after
    (after, Just (core, _)) -> selectIterable after core
 where
  selectIterable current core
    | Just selected <- mapRuntimeChoice current at CoreUnitType core
        (\after held -> fmap (fmap fst) (selectIterable after held)) = selected
    | otherwise = case coreExpressionType core of
        CoreNeverType -> (current, Just (core, CoreNeverType))
        kind@(CoreArrayType itemKind) -> walkArray current core kind itemKind
        CoreMapType key value -> walkKeyed current core (CoreTupleType [key, value]) KeyedEntries
        CoreSetType member -> walkKeyed current core member KeyedKeys
        CoreTextType ->
          let kind = CoreArrayType CoreCharType
           in walkArray current (expression kind (CoreTextMethod TextChars core [])) kind CoreCharType
        CoreRangeType -> walkStoredRange current core
        kind@(CoreTupleType members) -> walkTuple current core kind members
        kind
          | Just owner <- ownerKeyOf kind
          , let methods = contextMethods (lowerContext current)
          , Just begin <- Map.lookup (owner, "begin") methods
          , Just advance <- Map.lookup (owner, "advance") methods ->
              walkSequence current core kind begin advance
        kind
          | Just variants <- sumVariants (contextTypes (lowerContext current)) kind ->
              walkPayload current core variants
        _ ->
          let message = binary CoreAdd CoreTextType
                (expression CoreTextType (CoreTextLiteral "cannot iterate a "))
                (expression CoreTextType (CoreRuntimeKind core))
           in (current, Just (iterationFailure message, CoreNeverType))
  iterationFailure = argumentFailureWith AtInvocation at "E7001"
    (Just "implement Std.Iter.Sequence for it, which is begin and advance, or convert it to an array first")
  walkKeyed current core member method =
    let kind = CoreArrayType member
     in walkArray current (expression kind (CoreKeyedMethod method core [])) kind member
  walkTuple current core kind members = case members of
    [] -> emptyIterable current core
    first : _ ->
      let itemKind = runtimeResultType first (foldMap runtimeCarriers members)
          (withTuple, tupleLocal) = hidden current kind
          held = [expression member (CoreTupleIndex position (reading tupleLocal)) | (position, member) <- zip [0 ..] members]
          (ready, items) = itemArray withTuple itemKind held
          array = expression (coreExpressionType items) (CoreBlockValue
            (CoreBlock [statement (CoreDeclare tupleLocal core)] (Just items)))
       in walkArray ready array (coreExpressionType array) itemKind
  walkPayload current core variants = case concatMap (map snd . coreVariantFields) variants of
    [] -> emptyIterable current core
    kinds@(first : _) ->
      let itemKind = runtimeResultType first (foldMap runtimeCarriers kinds)
          arrayKind = CoreArrayType itemKind
          arm now variant =
            let (bound, locals) = mapAccumL (\here (_, kind) -> hidden here kind) now (coreVariantFields variant)
                (afterItems, answer) = itemArray bound itemKind (map reading locals)
                pattern' = CoreVariantPattern (coreVariantName variant) (map CoreBindPattern locals)
             in (afterItems, CoreArm at pattern' Nothing answer)
          (ready, arms) = mapAccumL arm current variants
       in walkArray ready (expression arrayKind (CoreMatch core arms)) arrayKind itemKind
  itemArray current itemKind held =
    let types = contextTypes (lowerContext current)
        (ready, items) = mapAccumL (\prior -> projectRuntimeValue types prior itemKind) current held
     in (ready, expression (CoreArrayType itemKind) (CoreArray items))
  emptyIterable current core =
    (current, Just (expression CoreUnitType (CoreBlockValue (CoreBlock [statement (CoreEvaluate core)] Nothing)), CoreUnitType))
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
    (afterPattern, Just (pattern', _))
      | impossiblePattern pattern' -> (closed afterPattern, Just (statement (CoreEvaluate unit)))
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

  writtenRange current inclusive low high =
    let (withLow, start) = hidden current (coreExpressionType low)
        (withHigh, end) = hidden withLow (coreExpressionType high)
        atRange = locatedSpan iterated
        declarations = [statement (CoreDeclare start low), statement (CoreDeclare end high)]
        (ready, result) = selectRangeEndpoint atRange withHigh (reading start) $ \held first ->
          selectRangeEndpoint atRange held (reading end) $ \valid last' ->
            let range = expression CoreRangeType (CoreRangeValue (Just (asExact first)) inclusive (Just (asExact last')))
             in walkStoredRange valid range
     in (ready, (\(value, kind) -> (expression kind (CoreBlockValue (CoreBlock declarations (Just value))), kind)) <$> result)

  exactKind = CoreIntegerType BigIntKind
  asExact value
    | coreExpressionType value == exactKind = value
    | otherwise = expression exactKind (CoreIntegerConvert BigIntKind value)

  walkStoredRange current core = selectRangeItems at current core $ \ready range arrayKind -> case arrayKind of
    CoreArrayType itemKind -> walkExactRange ready range itemKind
    _ -> refused ready

  walkExactRange current range itemKind =
    let (withNext, next) = hidden current exactKind
        (withHigh, high) = hidden withNext exactKind
        (withEndMode, endMode) = hidden withHigh CoreBoolType
        (withItem, item) = hidden withEndMode itemKind
        field kind name = expression kind (CoreRangeMethod name range [])
        within = expression CoreBoolType (CoreIfValue (reading endMode)
          (CoreBlock [] (Just (binary CoreLessOrEqual CoreBoolType (reading next) (reading high))))
          (binary CoreLess CoreBoolType (reading next) (reading high)))
        oneExact = expression exactKind (CoreIntegerLiteral BigIntKind 1)
        payload = if itemKind == intType then snd (exactPosition at (reading next)) else expression itemKind (CoreIntegerConvert ExactIntKind (reading next))
        unbounded = iterationFailure (expression CoreTextType (CoreTextLiteral "cannot iterate a range"))
        prefix =
          [ statement (CoreIf (expression CoreBoolType (CoreNot (field CoreBoolType RangeIsBoundedOf)))
              (CoreBlock [statement (CoreEvaluate unbounded)] Nothing) Nothing)
          , statement (CoreDeclare next (field exactKind RangeStartExact))
          , statement (CoreDeclare high (field exactKind RangeEndExact))
          , statement (CoreDeclare endMode (field CoreBoolType RangeIsInclusiveOf)) ]
        turn pushed identity = case element pushed item of
          (after, Nothing) -> (after, Nothing)
          (after, Just matched) -> (after, Just
            [ statement (CoreIf (expression CoreBoolType (CoreNot within))
                (CoreBlock [statement (CoreBreak identity Nothing)] Nothing) Nothing)
            , statement (CoreDeclare item payload)
            , statement (CoreAssign next (binary CoreAdd exactKind (reading next) oneExact))
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
        source = statement (CoreDeclare sequenceLocal core)
     in case callInstance withSequence at begin Nothing [reading sequenceLocal] of
          (afterBegin, Nothing) -> refused afterBegin
          (afterBegin, Just (started, CoreNeverType)) ->
            (afterBegin, Just (expression CoreNeverType (CoreBlockValue (CoreBlock [source] (Just started))), CoreNeverType))
          (afterBegin, Just (started, stateKind)) ->
            prepareSequence afterBegin source (reading sequenceLocal) advance started stateKind

  prepareSequence current source receiver advance started stateKind =
    let (withState, stateLocal) = hidden current stateKind
        callStep prior held
          | Just selected <- mapRuntimeChoice prior at CoreNeverType held
              (\ready payload -> fmap (fmap fst) (callStep ready payload)) = selected
          | otherwise = callInstance prior at advance Nothing [receiver, held]
     in case callStep withState (reading stateLocal) of
          (afterAdvance, Nothing) -> refused afterAdvance
          (afterAdvance, Just (stepped, stepKind))
            | let types = contextTypes (lowerContext afterAdvance)
                  known = runtimeCarriers stateKind
                  returned = nextStateCarriers types stepKind
            , not (returned `Set.isSubsetOf` known) ->
                prepareSequence (current{lowerContext = lowerContext afterAdvance}) source receiver advance started
                  (runtimeResultType (coreExpressionType started) (known <> returned))
            | otherwise ->
                let types = contextTypes (lowerContext afterAdvance)
                    (ready, seed) = projectRuntimeValue types afterAdvance stateKind started
                    prefix = [source, statement (CoreDeclare stateLocal seed)]
                    turn pushed identity =
                      fmap (fmap (\value -> [statement (CoreEvaluate value)])) (decodeStep pushed identity stateLocal stepped)
                 in if coreExpressionType seed == stateKind
                      then looped ready prefix turn
                      else halt at "a sequence with incompatible initial state layouts" ready

  nextStateCarriers types stepKind = Set.unions
    [ runtimeCarriers nextKind
    | held <- Set.toList (runtimeCarriers stepKind)
    , variant <- variantsFor types held "Some"
    , [(_, payload)] <- [coreVariantFields variant]
    , CoreTupleType [nextKind, _] <- Set.toList (runtimeCarriers payload)
    ]

  variantsFor types kind tag =
    [ variant
    | variant <- maybe [] id (sumVariants types kind)
    , not (coreVariantRecord variant)
    , coreVariantName variant == tag
    ]

  decodeStep current identity stateLocal value
    | stops value = (current, Just value)
    | Just selected <- mapRuntimeChoice current at CoreUnitType value
        (\ready held -> decodeStep ready identity stateLocal held) = fmap (fmap fst) selected
    | otherwise =
        let kind = coreExpressionType value
            types = contextTypes (lowerContext current)
            (withResult, resultLocal) = hidden current kind
            held = reading resultLocal
            finish = expression CoreNeverType (CoreBlockValue (CoreBlock [statement (CoreBreak identity Nothing)] Nothing))
            none =
              [ CoreArm at (CoreVariantPattern "None" (map (const CoreWildcardPattern) (coreVariantFields variant))) Nothing finish
              | variant <- variantsFor types kind "None"
              ]
            some = [payload | variant <- variantsFor types kind "Some", [(_, payload)] <- [coreVariantFields variant]]
            malformed = CoreArm at CoreWildcardPattern Nothing (advanceFailure held)
            select arms = expression CoreUnitType (CoreBlockValue (CoreBlock
              [statement (CoreDeclare resultLocal value)] (Just (expression CoreUnitType (CoreMatch held (none <> arms <> [malformed]))))))
         in case some of
              payload : _ ->
                let (withPair, pairLocal) = hidden withResult payload
                    pattern' = CoreVariantPattern "Some" [CoreBindPattern pairLocal]
                    (ready, answer) = decodePair withPair stateLocal held (reading pairLocal)
                 in (ready, (\taken -> select [CoreArm at pattern' Nothing taken]) <$> answer)
              [] | null none -> (current, Just (advanceFailure value))
                 | otherwise -> (withResult, Just (select []))

  decodePair current stateLocal result pair
    | Just selected <- mapRuntimeChoice current at CoreUnitType pair
        (\ready held -> decodePair ready stateLocal result held) = fmap (fmap fst) selected
    | CoreTupleType [nextKind, itemKind] <- coreExpressionType pair =
        let (withNext, nextLocal) = hidden current nextKind
            (withItem, itemLocal) = hidden withNext itemKind
            types = contextTypes (lowerContext withItem)
            (projected, next) = projectRuntimeValue types withItem (coreLocalType stateLocal) (reading nextLocal)
         in if coreExpressionType next /= coreLocalType stateLocal
              then halt at "a sequence with incompatible next state layouts" projected
              else case element projected itemLocal of
                (ready, Nothing) -> refused ready
                (ready, Just matched) ->
                  let taken = expression CoreUnitType (CoreBlockValue (CoreBlock
                        [statement (CoreAssign stateLocal next), matched] Nothing))
                      pattern' = CoreTuplePattern [CoreBindPattern nextLocal, CoreBindPattern itemLocal]
                   in (ready, Just (expression CoreUnitType (CoreMatch pair [CoreArm at pattern' Nothing taken])))
    | otherwise = (current, Just (advanceFailure result))

  advanceFailure held = argumentFailureWith AtInvocation at "E7001" Nothing
    (binary CoreAdd CoreTextType
      (expression CoreTextType (CoreTextLiteral "advance must answer Option[(State, Item)], not a "))
      (expression CoreTextType (CoreRuntimeKind held)))

