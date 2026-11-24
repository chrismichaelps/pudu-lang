{-| @Pudu.Compiler.Lower.Scalar — scalar operators and ordered runtime refusals. -}
module Pudu.Compiler.Lower.Scalar (lowerUnary, lowerBinary, eagerType, namedFailure) where

import Data.List (mapAccumL)
import Data.Maybe (isJust)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Control (ConditionUse (StrictCondition), expressionIsPrintValued, lowerCondition)
import Pudu.Compiler.Lower.Arguments (clampedPosition)
import Pudu.Compiler.Lower.Dynamic (mapRuntimeChoice, runtimeCarriers, widen)
import Pudu.Compiler.Lower.Keyed (setMembership)
import Pudu.Compiler.Lower.Reference (lowerReference)
import Pudu.Compiler.Lower.State
  ( LowerContext (..), LowerState (..), bindLocal, halt, intType, refused )
import Pudu.Compiler.Lower.Types (LowerTypes, isDynamic, sumVariants, typeForSpan, nativeIntegerKind, nativeValueType)
import Pudu.Core
import Pudu.Diagnostic.Arithmetic (CheckedOperation (..), overflowCode, overflowHelp, overflowMessage
  , shiftCode, negativeShiftMessage, negativeShiftHelp, wideShiftMessage, wideShiftHelp)
import Pudu.Diagnostic.Evaluation
  ( cannotApplyBinaryMessage, cannotApplyUnaryMessage, operatorCode, unsupportedOperatorMessage )
import Pudu.Frontend.Syntax (Expression (ArrayExpression, LiteralExpression), Literal (ResolvedInteger), Located (..))
import Pudu.IntegerLiteral (IntegerKind (BigIntKind, ExactIntKind, PlatformSigned), integerKindBounds, integerKindFits, integerKindMeet, integerKindSigned, integerKindWidth)
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

lowerUnary :: LowerExpression -> LowerState -> Span -> Text -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
lowerUnary lower state at operator operand
  | operator `elem` ["&", "*"] = lowerReference lower state at operator operand
  | operator `notElem` ["-", "!", "~"] = halt at ("the operator '" <> operator <> "'") state
  | operator == "-"
  , LiteralExpression (ResolvedInteger kind number) <- locatedValue operand
  , nativeIntegerKind kind, integerKindFits kind (negate number) =
      built state at (CoreIntegerLiteral kind (negate number)) (CoreIntegerType kind)
  | otherwise = case lower state operand of
      (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
      (after, Just (core, kind))
        | expressionIsPrintValued core -> halt at "an operator on a Result[(), Str] value" after
        | containsExactInt kind -> exactUnary after at operator core
        | Just operation <- unaryOperation operator core -> built after at operation kind
        | isDynamic kind, settled after operand core -> dynamicUnary after at operator core
        | isJust (runtimeChoiceAlternatives kind) -> dynamicUnary after at operator core
        | nativeValueType kind, settled after operand core ->
            (after, Just (unaryFailure at operator core, CoreNeverType))
        | otherwise -> halt at ("the operator '" <> operator <> "' on a " <> coreTypeName kind <> " value") after
      (after, Nothing) -> refused after

unaryOperation :: Text -> CoreExpression -> Maybe CoreExpressionShape
unaryOperation operator operand
  | operator == "-", integerType kind || floatType kind || kind == CoreDecimalType = Just (CoreNegate operand)
  | operator == "~", integerType kind = Just (CoreComplement operand)
  | operator == "!", kind == CoreBoolType = Just (CoreNot operand)
  | otherwise = Nothing
 where
  kind = coreExpressionType operand

unaryFailure :: Span -> Text -> CoreExpression -> CoreExpression
unaryFailure at operator operand = CoreExpression at CoreNeverType $
  if dynamicKind kind
    then CoreFailText operatorCode Nothing (text (CoreBinary CoreAdd prefix heldKind)) Nothing
    else CoreOperatorFailure (cannotApplyUnaryMessage operator (coreStaticRuntimeKind kind)) [operand]
 where
  kind = coreExpressionType operand
  text = CoreExpression at CoreTextType
  prefix = text (CoreTextLiteral (cannotApplyUnaryMessage operator ""))
  heldKind = text (CoreRuntimeKind operand)

dynamicUnary :: LowerState -> Span -> Text -> CoreExpression -> (LowerState, Maybe (CoreExpression, CoreType))
dynamicUnary state at operator operand =
  let (after, answer) = withDynamicValue types at result state operand lower
   in (after, fmap (\core -> (core, result)) answer)
 where
  types = contextTypes (lowerContext state)
  result = if operator == "!" then CoreBoolType else coreExpressionType operand
  lower current held
    | containsExactInt (coreExpressionType held) =
        let (ready, value) = exactUnary current at operator held
         in case value of
              Just (answer, _) -> wrapDynamicResult types at result ready answer
              Nothing -> refused ready
    | otherwise = case unaryOperation operator held of
        Nothing -> (current, Just (unaryFailure at operator held))
        Just operation -> wrapDynamicResult types at result current
          (CoreExpression at (coreExpressionType held) operation)

lowerBinary :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
lowerBinary lower state at left operator right
  | operator == "=" = halt at "an assignment used as a value" state
  | operator `elem` ["&&", "||"] = case condition state left of
      (after, Nothing) -> refused after
      (after, Just stopped@(_, CoreNeverType)) -> (after, Just stopped)
      (afterLeft, Just (lhs, _)) -> case condition afterLeft right of
        (after, Nothing) -> refused after
        (after, Just (rhs, _)) ->
          built after at (CoreBinary (if operator == "&&" then CoreAnd else CoreOr) lhs rhs) CoreBoolType
  | otherwise = case lowerLeft of
      (afterLeft, Just (coreLeft, leftType)) -> case lowerOperand afterLeft right (Just leftType) of
        (after, Just (coreRight, rightType))
          | CoreNeverType `elem` [leftType, rightType] ->
              built after at (CoreBlockValue (CoreBlock
                [CoreStatement (coreExpressionSpan core) (CoreEvaluate core) | core <- [coreLeft, coreRight]] Nothing)) CoreNeverType
          | expressionIsPrintValued coreLeft -> halt (locatedSpan left) "comparing or operating on a Result[(), Str] value" after
          | expressionIsPrintValued coreRight -> halt (locatedSpan right) "comparing or operating on a Result[(), Str] value" after
          | operator == "in", CoreSetType{} <- rightType ->
              setMembership after at coreLeft coreRight
          | any containsExactInt [leftType, rightType] -> exactBinary after at operator coreLeft coreRight
          | heldAlternatives leftType || heldAlternatives rightType -> dynamicBinary after at operator coreLeft coreRight
          | Just (operation, result) <- represented operator leftType rightType ->
              built after at (CoreBinary operation coreLeft coreRight) result
          | all nativeValueType [leftType, rightType]
          , settled after left coreLeft && settled after right coreRight
          , not (integerType leftType && integerType rightType)
          , dynamicKind leftType || dynamicKind rightType ->
              namedFailure after at (\kinds -> case kinds of
                [leftKind, rightKind] -> cannotApplyBinaryMessage operator leftKind rightKind
                _ -> cannotApplyUnaryMessage operator (mconcat kinds)) [coreLeft, coreRight]
          | all nativeValueType [leftType, rightType]
          , settled after left coreLeft && settled after right coreRight
          , not (integerType leftType && integerType rightType) ->
              let message
                    | leftType == rightType && (leftType `elem` [CoreBoolType, CoreTextType, CoreCharType, CoreDecimalType] || floatType leftType) = unsupportedOperatorMessage operator
                    | otherwise = cannotApplyBinaryMessage operator (coreStaticRuntimeKind leftType) (coreStaticRuntimeKind rightType)
               in failure after at message [coreLeft, coreRight]
          | otherwise -> halt at ("the operator '" <> operator <> "' outside the native scalar subset") after
        (after, Nothing) -> refused after
      (after, Nothing) -> refused after
 where
  condition = lowerCondition StrictCondition at lower
  -- An empty array literal holds no element, so it takes the other
  -- operand's array type where checking left its element open.
  lowerOperand current (Located spanValue (ArrayExpression [])) (Just kind@(CoreArrayType _)) =
    (current, Just (CoreExpression spanValue kind (CoreArray []), kind))
  lowerOperand current operand _ = lower current operand
  -- An empty literal on the left runs nothing, so the right operand's
  -- lowered type can settle it without changing what runs first.
  lowerLeft = case locatedValue left of
    ArrayExpression [] | (_, Just (_, kind@(CoreArrayType _))) <- lower state right -> lowerOperand state left (Just kind)
    _ -> lower state left

containsExactInt :: CoreType -> Bool
containsExactInt = Set.member (CoreIntegerType ExactIntKind) . runtimeCarriers

exactUnary :: LowerState -> Span -> Text -> CoreExpression -> (LowerState, Maybe (CoreExpression, CoreType))
exactUnary state at operator operand
  | Just selected <- mapRuntimeChoice state at CoreNeverType operand
      (\ready held -> fmap (fmap fst) (exactUnary ready at operator held)) = selected
  | kind == CoreIntegerType ExactIntKind, operator == "-" =
      let (ready, local) = bindLocal state "" big
          exact = expression big (CoreNegate (expression big (CoreIntegerConvert BigIntKind operand)))
          held = readLocal at local
          checked = checkedIntegerResult at PlatformSigned CheckedNegate held
       in built ready at (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare local exact)] (Just checked))) intType
  | kind == CoreIntegerType ExactIntKind, operator == "~" =
      built state at (CoreComplement (expression intType (CoreIntegerConvert PlatformSigned operand))) intType
  | Just operation <- unaryOperation operator operand = built state at operation kind
  | otherwise = (state, Just (unaryFailure at operator operand, CoreNeverType))
 where
  kind = coreExpressionType operand
  big = CoreIntegerType BigIntKind
  expression = CoreExpression at

exactBinary :: LowerState -> Span -> Text -> CoreExpression -> CoreExpression -> (LowerState, Maybe (CoreExpression, CoreType))
exactBinary state at operator left right =
  let (withLeft, lhs) = bindLocal state "" (coreExpressionType left)
      (withRight, rhs) = bindLocal withLeft "" (coreExpressionType right)
      (ready, selected) = select withRight (readLocal at lhs) (readLocal at rhs)
      declarations = [CoreStatement at (CoreDeclare lhs left), CoreStatement at (CoreDeclare rhs right)]
   in (ready, (\(answer, kind) -> (CoreExpression at kind (CoreBlockValue (CoreBlock declarations (Just answer))), kind)) <$> selected)
 where
  select current a b
    | Just chosen <- mapRuntimeChoice current at CoreNeverType a
        (\ready held -> fmap (fmap fst) (select ready held b)) = chosen
    | Just chosen <- mapRuntimeChoice current at CoreNeverType b
        (\ready held -> fmap (fmap fst) (select ready a held)) = chosen
    | any (isDynamic . coreExpressionType) [a, b] =
        dynamicBinary current at operator a b
    | CoreIntegerType leftKind <- coreExpressionType a
    , CoreIntegerType rightKind <- coreExpressionType b
    , operator `elem` ["<<", ">>"], ExactIntKind `elem` [leftKind, rightKind] =
        exactShift current at operator (integerKindMeet leftKind rightKind) a b
    | CoreIntegerType leftKind <- coreExpressionType a
    , CoreIntegerType rightKind <- coreExpressionType b
    , ExactIntKind `elem` [leftKind, rightKind]
    , Just (ready, answer) <- mixedInteger current at operator (integerKindMeet leftKind rightKind) a b =
        (ready, Just (answer, coreExpressionType answer))
    | Just (tag, kind) <- represented operator (coreExpressionType a) (coreExpressionType b) =
        built current at (CoreBinary tag a b) kind
    | CoreIntegerType leftKind <- coreExpressionType a
    , CoreIntegerType rightKind <- coreExpressionType b
    , Just (ready, answer) <- mixedInteger current at operator (integerKindMeet leftKind rightKind) a b =
        (ready, Just (answer, coreExpressionType answer))
    | operator `elem` ["==", "!="] = built current at (CoreBoolLiteral (operator == "!=")) CoreBoolType
    | otherwise = namedFailure current at invalidOperands [a, b]
  invalidOperands [a, b] = cannotApplyBinaryMessage operator a b
  invalidOperands _ = unsupportedOperatorMessage operator

dynamicPayloads :: LowerTypes -> CoreType -> Maybe [(Text, CoreType)]
dynamicPayloads types kind = sumVariants types kind >>= traverse payloadType
 where
  payloadType variant = case coreVariantFields variant of
    [(_, member)] -> Just (coreVariantName variant, member)
    _ -> Nothing

dynamicBinary :: LowerState -> Span -> Text -> CoreExpression -> CoreExpression -> (LowerState, Maybe (CoreExpression, CoreType))
dynamicBinary state at operator left right
  | equality, leftType == rightType
  , Just variants <- dynamicPayloads types leftType
  , length (filter (integerType . snd) variants) <= 1 =
      built state at (CoreBinary equalityOperator left right) CoreBoolType
  | otherwise =
      let (withLeft, savedLeft) = bindLocal state "" leftType
          (withBoth, savedRight) = bindLocal withLeft "" rightType
          (after, answer) = withDynamicValue types at result withBoth (readLocal at savedLeft) $ \leftValueState leftValue ->
            withDynamicValue types at result leftValueState (readLocal at savedRight) $ \rightValueState rightValue ->
              operation rightValueState leftValue rightValue
          held = [CoreStatement at (CoreDeclare savedLeft left), CoreStatement at (CoreDeclare savedRight right)]
       in case answer of
            Nothing -> refused after
            Just core -> built after at (CoreBlockValue (CoreBlock held (Just core))) result
 where
  types = contextTypes (lowerContext state)
  leftType = coreExpressionType left
  rightType = coreExpressionType right
  equality = operator `elem` ["==", "!="]
  equalityOperator = if operator == "==" then CoreEqual else CoreNotEqual
  result = if operator `elem` ["==", "!=", "<", "<=", ">", ">="] then CoreBoolType else leftType
  operation current a b
    | all integerType [aType, bType]
    , any containsExactInt [aType, bType] =
        case exactBinary current at operator a b of
          (ready, Just (value, _)) -> wrap ready value
          (ready, Nothing) -> refused ready
    | Just (tag, kind) <- represented operator aType bType =
        wrap current (CoreExpression at kind (CoreBinary tag a b))
    | CoreIntegerType aKind <- aType, CoreIntegerType bKind <- bType
    , Just (next, answer) <- mixedInteger current at operator (integerKindMeet aKind bKind) a b =
        wrap next answer
    | equality, common : _ <- filter heldAlternatives [leftType, rightType]
    , let heldA = widen types common a
          heldB = widen types common b
    , all ((== common) . coreExpressionType) [heldA, heldB] =
        (current, Just (CoreExpression at CoreBoolType (CoreBinary equalityOperator heldA heldB)))
    | equality = (current, Just (CoreExpression at CoreBoolType (CoreBoolLiteral (operator == "!="))))
    | aType == bType, comparisonOnlyType aType =
        (current, Just (CoreExpression at CoreNeverType (CoreOperatorFailure (unsupportedOperatorMessage operator) [a, b])))
    | dynamicKind aType || dynamicKind bType =
        let (after, answer) = namedFailure current at names [a, b]
         in (after, fst <$> answer)
    | otherwise = (current, Just (CoreExpression at CoreNeverType
        (CoreOperatorFailure (cannotApplyBinaryMessage operator (coreStaticRuntimeKind aType) (coreStaticRuntimeKind bType)) [a, b])))
   where
    aType = coreExpressionType a
    bType = coreExpressionType b
    names [aName, bName] = cannotApplyBinaryMessage operator aName bName
    names _ = unsupportedOperatorMessage operator
  wrap = wrapDynamicResult types at result

withDynamicValue :: LowerTypes -> Span -> CoreType -> LowerState -> CoreExpression
  -> (LowerState -> CoreExpression -> (LowerState, Maybe CoreExpression))
  -> (LowerState, Maybe CoreExpression)
withDynamicValue types at result state value use
  | not (heldAlternatives kind) = use state value
  | otherwise = case dynamicPayloads types kind of
      Nothing -> halt at "a dynamic operand without a settled payload layout" state
      Just variants ->
        let (after, arms) = mapAccumL arm state variants
         in (after, CoreExpression at result . CoreMatch value <$> sequence arms)
 where
  kind = coreExpressionType value
  arm current (name, member) =
    let (withPayload, local) = bindLocal current "" member
        (after, body) = use withPayload (readLocal at local)
     in (after, CoreArm at (CoreVariantPattern name [CoreBindPattern local]) Nothing <$> body)

heldAlternatives :: CoreType -> Bool
heldAlternatives kind = isDynamic kind || isJust (runtimeChoiceAlternatives kind)

wrapDynamicResult :: LowerTypes -> Span -> CoreType -> LowerState -> CoreExpression -> (LowerState, Maybe CoreExpression)
wrapDynamicResult types at result state answer
  | coreExpressionType widened == result = (state, Just widened)
  | otherwise = halt at "a dynamic operator result without a payload variant" state
 where
  widened = widen types result answer

readLocal :: Span -> CoreLocal -> CoreExpression
readLocal at local = CoreExpression at (coreLocalType local) (CoreReadLocal local)

mixedInteger :: LowerState -> Span -> Text -> IntegerKind -> CoreExpression -> CoreExpression
  -> Maybe (LowerState, CoreExpression)
mixedInteger state at operator kind left right = do
  (tag, answer) <- represented operator big big
  pure (select tag answer)
 where
  select tag answer
    | answer == CoreBoolType || kind == BigIntKind = (state, exact answer tag)
    | Just checked <- lookup tag checkedTags = withExact state tag (checkedResult checked)
    | Just arithmetic <- lookup tag saturatingTags
    , Just (low, high) <- integerKindBounds kind = withExact state arithmetic (saturated low high)
    | tag == CoreRemainder =
        let resultKind = if kind == PlatformSigned && any (containsExactInt . coreExpressionType) [left, right]
              then ExactIntKind else kind
         in (state, convert resultKind (exact big tag))
    | otherwise = (state, expression target (CoreBinary tag (convert kind left) (convert kind right)))
  target = CoreIntegerType kind
  big = CoreIntegerType BigIntKind
  expression = CoreExpression at
  exact result tag = expression result (CoreBinary tag (convert BigIntKind left) (convert BigIntKind right))
  convert to value = expression (CoreIntegerType to) (CoreIntegerConvert to value)
  checkedTags = [(CoreAdd, CheckedAdd), (CoreSubtract, CheckedSubtract), (CoreMultiply, CheckedMultiply), (CoreDivide, CheckedDivide)]
  saturatingTags = [(CoreSaturateAdd, CoreAdd), (CoreSaturateSubtract, CoreSubtract), (CoreSaturateMultiply, CoreMultiply)]
  withExact current tag finish =
    let (after, local) = bindLocal current "" big
        held = CoreStatement at (CoreDeclare local (exact big tag))
     in (after, expression target (CoreBlockValue (CoreBlock [held] (Just (finish (readLocal at local))))))
  checkedResult = checkedIntegerResult at kind
  saturated low high held =
    choose (bound CoreLess low) (limited low) (choose (bound CoreGreater high) (limited high) (convert kind held))
   where
    bound tag value = expression CoreBoolType (CoreBinary tag held (expression big (CoreIntegerLiteral BigIntKind value)))
    limited = expression target . CoreIntegerLiteral kind
  choose test leftValue rightValue = expression target (CoreIfValue test (CoreBlock [] (Just leftValue)) rightValue)

exactShift :: LowerState -> Span -> Text -> IntegerKind -> CoreExpression -> CoreExpression
  -> (LowerState, Maybe (CoreExpression, CoreType))
exactShift state at operator kind left right =
  let target = CoreIntegerType kind
      big = CoreIntegerType BigIntKind
      expression = CoreExpression at
      number kind' n = expression (CoreIntegerType kind') (CoreIntegerLiteral kind' n)
      count = clampedPosition at right
      toBig operand = expression big (CoreIntegerConvert BigIntKind operand)
      wrap value = expression target (CoreBinary CoreWrapAdd
        (expression target (CoreIntegerConvert kind value)) (number kind 0))
      input | integerKindSigned kind = toBig left
            | otherwise = toBig (wrap left)
      tag = if operator == "<<" then CoreShiftLeft else CoreShiftRight
      moved = expression big (CoreBinary tag input count)
      nonnegative = expression CoreBoolType (CoreBinary CoreGreaterOrEqual count (number PlatformSigned 0))
      invalidShift message help = expression CoreNeverType
        (CoreFailText shiftCode (Just help) (expression CoreTextType (CoreTextLiteral message)) Nothing)
      choose condition yes no = expression target (CoreIfValue condition (CoreBlock [] (Just yes)) no)
      bounded = case integerKindWidth kind of
        Nothing -> moved
        Just width ->
          let inside = expression CoreBoolType (CoreBinary CoreLess count (number PlatformSigned (toInteger width)))
           in choose inside (wrap moved) (invalidShift (wideShiftMessage kind) wideShiftHelp)
      result = choose nonnegative bounded (invalidShift negativeShiftMessage negativeShiftHelp)
   in (state, Just (result, target))

checkedIntegerResult :: Span -> IntegerKind -> CheckedOperation -> CoreExpression -> CoreExpression
checkedIntegerResult at kind checked held =
  let expression = CoreExpression at
      target = CoreIntegerType kind
      fits = expression CoreBoolType (CoreIntegerFits kind held)
      converted = expression target (CoreIntegerConvert kind held)
      message = expression CoreTextType (CoreTextLiteral (overflowMessage kind checked))
      stopped = expression CoreNeverType (CoreFailText overflowCode (Just overflowHelp) message Nothing)
   in expression target (CoreIfValue fits (CoreBlock [] (Just converted)) stopped)

comparisonOnlyType :: CoreType -> Bool
comparisonOnlyType kind =
  integerType kind || floatType kind || kind `elem` [CoreBoolType, CoreTextType, CoreCharType, CoreDecimalType]

represented :: Text -> CoreType -> CoreType -> Maybe (CoreBinaryOperator, CoreType)
represented operator left right
  | integerType left, right == intType, Just operation <- lookup operator shifts = Just (operation, left)
  | left /= right = Nothing
  | integerType left, Just operation <- lookup operator arithmetic = Just (operation, left)
  | floatType left, Just operation <- lookup operator floating = Just (operation, left)
  | left == CoreDecimalType, Just operation <- lookup operator floating = Just (operation, left)
  | left == CoreTextType, operator == "+" = Just (CoreAdd, CoreTextType)
  | integerType left || floatType left || tupleType left || left `elem` [CoreBoolType, CoreTextType, CoreCharType, CoreDecimalType], Just operation <- lookup operator ordering = Just (operation, CoreBoolType)
  | nativeValueType left, Just operation <- lookup operator equality = Just (operation, CoreBoolType)
  | otherwise = Nothing
 where
  arithmetic =
    [ ("+", CoreAdd), ("-", CoreSubtract), ("*", CoreMultiply), ("/", CoreDivide), ("%", CoreRemainder)
    , ("&", CoreBitAnd), ("|", CoreBitOr), ("^", CoreBitXor)
    , ("&+", CoreWrapAdd), ("&-", CoreWrapSubtract), ("&*", CoreWrapMultiply)
    , ("+|", CoreSaturateAdd), ("-|", CoreSaturateSubtract), ("*|", CoreSaturateMultiply)
    ]
  floating = [("+", CoreAdd), ("-", CoreSubtract), ("*", CoreMultiply), ("/", CoreDivide)]
  shifts = [("<<", CoreShiftLeft), (">>", CoreShiftRight)]
  ordering = [("<", CoreLess), ("<=", CoreLessOrEqual), (">", CoreGreater), (">=", CoreGreaterOrEqual)]
  equality = [("==", CoreEqual), ("!=", CoreNotEqual)]

integerType :: CoreType -> Bool
integerType (CoreIntegerType kind) = nativeIntegerKind kind
integerType _ = False

floatType :: CoreType -> Bool
floatType (CoreFloatType _) = True
floatType _ = False

tupleType :: CoreType -> Bool
tupleType (CoreTupleType _) = True
tupleType _ = False

settled :: LowerState -> Located Expression -> CoreExpression -> Bool
settled state syntax core =
  typeForSpan (contextTypes (lowerContext state)) (locatedSpan syntax) == Just (coreExpressionType core)

dynamicKind :: CoreType -> Bool
dynamicKind (CoreSumType _ _) = True
dynamicKind (CoreFunctionType _ _) = True
dynamicKind _ = False

{-| Sums and callables get their diagnostic kind from the saved value.
    Each operand runs once, in order, into a temporary; the message is the
    shared wording, with each dynamic kind read from its temporary. -}
namedFailure :: LowerState -> Span -> ([Text] -> Text) -> [CoreExpression] -> (LowerState, Maybe (CoreExpression, CoreType))
namedFailure state at render operands =
  let (after, locals) = foldl temporary (state, []) operands
      held = reverse locals
      marks = [Text.pack ['\0', toEnum (48 + position)] | position <- [0 .. length held - 1]]
      pieces = splitMarks marks (render marks)
      kindOf local
        | dynamicKind (coreLocalType local) = expression CoreTextType (CoreRuntimeKind (expression (coreLocalType local) (CoreReadLocal local)))
        | otherwise = expression CoreTextType (CoreTextLiteral (coreStaticRuntimeKind (coreLocalType local)))
      joined = foldl1 (\left right -> expression CoreTextType (CoreBinary CoreAdd left right))
        (concat [ [expression CoreTextType (CoreTextLiteral text) | not (Text.null text)] <> maybe [] (pure . kindOf) local
                | (text, local) <- zip pieces (map Just held <> [Nothing]) ] <> [expression CoreTextType (CoreTextLiteral "") | null pieces])
      declares = [CoreStatement (coreExpressionSpan core) (CoreDeclare local core) | (local, core) <- zip held operands]
   in built after at (CoreBlockValue (CoreBlock declares (Just (expression CoreNeverType (CoreFailText "E7001" Nothing joined Nothing))))) CoreNeverType
 where
  expression = CoreExpression at
  temporary (current, done) core =
    let local = CoreLocal{coreLocalId = lowerNextLocal current, coreLocalName = "$operand", coreLocalType = coreExpressionType core}
     in (current{lowerNextLocal = lowerNextLocal current + 1}, local : done)
  splitMarks marks text = go marks text
   where
    go [] rest = [rest]
    go (mark : others) rest = let (before, after) = Text.breakOn mark rest in before : go others (Text.drop (Text.length mark) after)

failure :: LowerState -> Span -> Text -> [CoreExpression] -> (LowerState, Maybe (CoreExpression, CoreType))
failure state at message operands = built state at (CoreOperatorFailure message operands) CoreNeverType

built :: LowerState -> Span -> CoreExpressionShape -> CoreType -> (LowerState, Maybe (CoreExpression, CoreType))
built state at shape kind = (state, Just (CoreExpression at kind shape, kind))

{-| A guarded right operand does not determine the whole expression's reachability. -}
eagerType :: CoreType -> [CoreExpression] -> CoreType
eagerType result operands
  | any ((== CoreNeverType) . coreExpressionType) operands = CoreNeverType
  | otherwise = result
