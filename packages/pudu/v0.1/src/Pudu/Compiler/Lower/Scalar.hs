{-| @Pudu.Compiler.Lower.Scalar — scalar operators and ordered runtime refusals. -}
module Pudu.Compiler.Lower.Scalar (lowerUnary, lowerBinary, eagerType) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.Reference (lowerReference)
import Pudu.Compiler.Lower.State
  ( LowerContext (..), LowerState (..), halt, intType, refused )
import Pudu.Compiler.Lower.Types (typeForSpan, nativeIntegerKind, nativeValueType)
import Pudu.Core
import Pudu.Diagnostic.Evaluation
  ( cannotApplyBinaryMessage, cannotApplyUnaryMessage, unsupportedOperatorMessage )
import Pudu.Frontend.Syntax (Expression (LiteralExpression), Literal (ResolvedInteger), Located (..))
import Pudu.IntegerLiteral (integerKindFits)
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
        | operator == "-", integerType kind || floatType kind -> built after at (CoreNegate core) kind
        | operator == "~", integerType kind -> built after at (CoreComplement core) kind
        | operator == "!", kind == CoreBoolType -> built after at (CoreNot core) CoreBoolType
        | dynamicKind kind, settled after operand core ->
            namedFailure after at (\kinds -> cannotApplyUnaryMessage operator (mconcat kinds)) [core]
        | kind `elem` [CoreUnitType, CoreBoolType, CoreTextType, CoreCharType, CoreBytesType] || floatType kind || tupleType kind || recordType kind
        , settled after operand core ->
            failure after at (cannotApplyUnaryMessage operator (runtimeKind kind)) [core]
        | otherwise -> halt at ("the operator '" <> operator <> "' on a " <> coreTypeName kind <> " value") after
      (after, Nothing) -> refused after

lowerBinary :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
lowerBinary lower state at left operator right
  | operator == "=" = halt at "an assignment used as a value" state
  | otherwise = case lower state left of
      (afterLeft, Just (coreLeft, leftType)) -> case lower afterLeft right of
        (after, Just (coreRight, rightType))
          | operator `elem` ["&&", "||"] ->
              if all (`elem` [CoreBoolType, CoreNeverType]) [leftType, rightType]
                then built after at (CoreBinary (if operator == "&&" then CoreAnd else CoreOr) coreLeft coreRight)
                  (eagerType CoreBoolType [coreLeft])
                else halt at "a logical operation outside Bool" after
          | CoreNeverType `elem` [leftType, rightType] ->
              built after at (CoreBlockValue (CoreBlock
                [CoreStatement (coreExpressionSpan core) (CoreEvaluate core) | core <- [coreLeft, coreRight]] Nothing)) CoreNeverType
          | expressionIsPrintValued coreLeft -> halt (locatedSpan left) "comparing or operating on a Result[(), Str] value" after
          | expressionIsPrintValued coreRight -> halt (locatedSpan right) "comparing or operating on a Result[(), Str] value" after
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
                    | leftType == rightType && (leftType `elem` [CoreBoolType, CoreTextType, CoreCharType] || floatType leftType) = unsupportedOperatorMessage operator
                    | otherwise = cannotApplyBinaryMessage operator (runtimeKind leftType) (runtimeKind rightType)
               in failure after at message [coreLeft, coreRight]
          | otherwise -> halt at ("the operator '" <> operator <> "' outside the native scalar subset") after
        (after, Nothing) -> refused after
      (after, Nothing) -> refused after

represented :: Text -> CoreType -> CoreType -> Maybe (CoreBinaryOperator, CoreType)
represented operator left right
  | integerType left, right == intType, Just operation <- lookup operator shifts = Just (operation, left)
  | left /= right = Nothing
  | integerType left, Just operation <- lookup operator arithmetic = Just (operation, left)
  | floatType left, Just operation <- lookup operator floating = Just (operation, left)
  | left == CoreTextType, operator == "+" = Just (CoreAdd, CoreTextType)
  | integerType left || floatType left || tupleType left || left `elem` [CoreBoolType, CoreTextType, CoreCharType], Just operation <- lookup operator ordering = Just (operation, CoreBoolType)
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

recordType :: CoreType -> Bool
recordType (CoreRecordType _ _) = True
recordType _ = False

settled :: LowerState -> Located Expression -> CoreExpression -> Bool
settled state syntax core =
  typeForSpan (contextTypes (lowerContext state)) (locatedSpan syntax) == Just (coreExpressionType core)

runtimeKind :: CoreType -> Text
runtimeKind CoreUnitType = "unit"
runtimeKind CoreBoolType = "bool"
runtimeKind (CoreFloatType _) = "float"
runtimeKind CoreTextType = "string"
runtimeKind CoreCharType = "char"
runtimeKind (CoreTupleType _) = "tuple"
runtimeKind (CoreRecordType name _) = displayName name
runtimeKind (CoreArrayType _) = "array"
runtimeKind (CoreMapType _ _) = "map"
runtimeKind (CoreSetType _) = "set"
runtimeKind CoreRangeType = "range"
runtimeKind CoreBytesType = "bytes"
runtimeKind (CoreFunctionType _ _) = "function"
runtimeKind kind = coreTypeName kind

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
        | otherwise = expression CoreTextType (CoreTextLiteral (runtimeKind (coreLocalType local)))
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
