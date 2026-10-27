{-| @Pudu.Compiler.Lower.Stop — builtins that only end the program: `panic`,
    and `convertInteger` without the type to convert to. The arguments run
    first, then the program stops at the call, as `Eval.Builtin` does it. -}
module Pudu.Compiler.Lower.Stop (lowerPanic, lowerUntypedConvert, panicBody, wrongPanicBody, untypedConvertBody) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Array (collect, stopped, stops)
import Pudu.Compiler.Lower.State (LowerState, refused)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| `panic(message)`: E7007 with the message as written, and no help.
    Checking gives panic no signature, so anything else gets through to here
    and refuses as the interpreter does, once every argument has run. -}
lowerPanic :: LowerExpression -> LowerState -> Span -> [Located Expression] -> Lowered
lowerPanic lower state at arguments = case collect lower state arguments of
  (after, Nothing) -> refused after
  (after, Just cores)
    | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
    | [message] <- cores, coreExpressionType message == CoreTextType ->
        (after, Just (never at (CoreFailText panicCode Nothing message Nothing), CoreNeverType))
    | otherwise -> (after, Just (runThen at cores (CoreFailText panicCode (Just panicHelp) (text at "panic") Nothing), CoreNeverType))

{-| `convertInteger(value)` with no type argument: the value runs, then E7012. -}
lowerUntypedConvert :: LowerExpression -> LowerState -> Span -> [Located Expression] -> Lowered
lowerUntypedConvert lower state at arguments = case collect lower state arguments of
  (after, Nothing) -> refused after
  (after, Just cores)
    | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
    | otherwise -> (after, Just (runThen at cores (CoreFailText convertCode (Just convertHelp) (text at convertMessage) Nothing), CoreNeverType))

runThen :: Span -> [CoreExpression] -> CoreExpressionShape -> CoreExpression
runThen at cores failure = never at (CoreBlockValue (CoreBlock
  ([CoreStatement (coreExpressionSpan core) (CoreEvaluate core) | core <- cores] <> [CoreStatement at (CoreEvaluate (never at failure))]) Nothing))

{-| A `panic` value's body: the same refusal, pointing at the value call. -}
panicBody :: Span -> CoreExpression -> CoreExpression
panicBody at message = never at (CoreFailCaller panicCode Nothing message)

{-| A `panic` value called with anything but one Str. -}
wrongPanicBody :: Span -> CoreExpression
wrongPanicBody at = never at (CoreFailCaller panicCode (Just panicHelp) (text at "panic"))

{-| An untyped `convertInteger` value's body. The caller already ran the value. -}
untypedConvertBody :: Span -> CoreExpression
untypedConvertBody at = never at (CoreFailCaller convertCode (Just convertHelp) (text at convertMessage))

panicCode, panicHelp, convertCode, convertMessage, convertHelp :: Text
panicCode = "E7007"
panicHelp = "panic takes one string argument"
convertCode = "E7012"
convertMessage = "convertInteger needs the type to convert to"
convertHelp = "write it as a type argument, as in convertInteger[UInt8](value)"

never :: Span -> CoreExpressionShape -> CoreExpression
never at = CoreExpression at CoreNeverType

text :: Span -> Text -> CoreExpression
text at value = CoreExpression at CoreTextType (CoreTextLiteral value)
