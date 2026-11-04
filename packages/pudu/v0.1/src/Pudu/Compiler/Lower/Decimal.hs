{-| @Pudu.Compiler.Lower.Decimal — the primitives behind `Std.Decimal` and
    `Str.toDecimal`. Arguments run in order into held locals. A primitive
    answering an Option is a test and the conversion the test allows, with
    the Option the checker gave the call, as `callDecimal` answers. -}
module Pudu.Compiler.Lower.Decimal (decimalLiteral, lowerDecimalPrimitive, lowerTextToDecimal) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.DecimalLiteral (Decimal (..), parseDecimalLiteral)
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| What a primitive answers from its held arguments. -}
data Answer
  = Plain !CoreDecimalMethodName !CoreType
  {-| Some of the conversion when the test holds, else None. -}
  | Optional !CoreDecimalMethodName !CoreDecimalMethodName !CoreType
  {-| None when the divisor is zero, else Some of the division. -}
  | Divided

{-| A literal's value; the evaluator reads text no literal could spell as
    nought. -}
decimalLiteral :: Text -> CoreExpressionShape
decimalLiteral text = case parseDecimalLiteral text of
  Just (Decimal coefficient scale) -> CoreDecimalLiteral coefficient scale
  Nothing -> CoreDecimalLiteral 0 0

{-| Nothing for a name that is not a Decimal primitive. -}
lowerDecimalPrimitive :: LowerExpression -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered
lowerDecimalPrimitive lower state at name arguments = do
  (parameters, answer) <- lookup name primitives
  Just (heldCall lower state at name parameters answer arguments)

{-| `text.toDecimal()`, its receiver already lowered. -}
lowerTextToDecimal :: LowerState -> Span -> CoreExpression -> Lowered
lowerTextToDecimal state at receiver = answered state at (Optional DecimalTextParses DecimalParse CoreDecimalType) [receiver]

primitives :: [(Text, ([CoreType], Answer))]
primitives =
  [ ("decimalOf", ([CoreTextType], Optional DecimalParses DecimalParse CoreDecimalType))
  , ("decimalFromInt", ([intType], Plain DecimalFromInt CoreDecimalType))
  , ("decimalScale", ([CoreDecimalType], Plain DecimalScaleOf intType))
  , ("decimalToInt", ([CoreDecimalType], Optional DecimalNamesInt DecimalToInt intType))
  , ("decimalToFloat", ([CoreDecimalType], Plain DecimalToFloat (CoreFloatType Float64Width)))
  , ("decimalDivide", ([CoreDecimalType, CoreDecimalType, intType, intType], Divided))
  , ("decimalRound", ([CoreDecimalType, intType, intType], Plain DecimalRoundTo CoreDecimalType))
  ]

heldCall :: LowerExpression -> LowerState -> Span -> Text -> [CoreType] -> Answer -> [Located Expression] -> Lowered
heldCall lower state at name parameters answer arguments
  | length arguments /= length parameters = halt at ("a call to " <> name <> " with this many arguments") state
  | otherwise = go state [] (zip parameters arguments)
 where
  go current done [] = answered current at answer (reverse done)
  go current done ((expected, argument) : rest) = case lower current argument of
    (next, Nothing) -> refused next
    (next, Just (core, kind))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" next
      | kind == CoreNeverType -> (next, Just (stopped (reverse (core : done)), CoreNeverType))
      | kind /= expected -> halt (locatedSpan argument) ("a " <> name <> " argument of type " <> coreTypeName kind) next
      | otherwise -> go next (core : done) rest
  stopped cores = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
    [CoreStatement (coreExpressionSpan core) (CoreEvaluate core) | core <- cores] Nothing))

answered :: LowerState -> Span -> Answer -> [CoreExpression] -> Lowered
answered state at answer cores = case answer of
  Plain name kind -> finish held kind (method name kind given)
  Optional test conversion kind -> option $ \optionType ->
    CoreIfValue (method test CoreBoolType given)
      (CoreBlock [] (Just (some optionType (method conversion kind given)))) (none optionType)
  Divided -> option $ \optionType -> case given of
    _ : divisor : _ ->
      CoreIfValue (method DecimalIsZero CoreBoolType [divisor])
        (CoreBlock [] (Just (none optionType))) (some optionType (method DecimalDivideWith CoreDecimalType given))
    _ -> CoreConstruct "None" []
 where
  (held, locals) = foldl' hold (state, []) cores
  hold (current, done) core = let (next, local) = bindLocal current "" (coreExpressionType core) in (next, done <> [local])
  declarations = [CoreStatement (coreExpressionSpan core) (CoreDeclare local core) | (local, core) <- zip locals cores]
  given = [CoreExpression at (coreLocalType local) (CoreReadLocal local) | local <- locals]
  expression kind shape = CoreExpression at kind shape
  method name kind operands = expression kind (CoreDecimalMethod name operands)
  some optionType value = expression optionType (CoreConstruct "Some" [("0", value)])
  none optionType = expression optionType (CoreConstruct "None" [])
  finish current kind value = (current, Just (expression kind (CoreBlockValue (CoreBlock declarations (Just value))), kind))
  option build = case typeForSpan (contextTypes (lowerContext state)) at of
    Just optionType@(CoreSumType "Option" [_]) -> finish held optionType (expression optionType (build optionType))
    _ -> halt at "an Option result without a native form" state
