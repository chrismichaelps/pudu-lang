{-| @Pudu.Compiler.Lower.Intrinsic — callable bodies for prelude values. -}
module Pudu.Compiler.Lower.Intrinsic (lowerIntrinsicValue, annotatedPanic) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Bytes (bytesFromArray)
import Pudu.Compiler.Lower.Call (outputResult)
import Pudu.Compiler.Lower.Convert (charFromCodeCore)
import Pudu.Compiler.Lower.Keyed (keyedFromArray)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), halt, intType, lookupLocal, resolveFunction, startFunction)
import Pudu.Compiler.Lower.Stop (panicBody, untypedConvertBody, wrongPanicBody)
import Pudu.Compiler.Lower.Types (nativeValueType, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..), TypeSyntax (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

lowerIntrinsicValue :: LowerState -> Span -> Text -> Maybe Lowered
lowerIntrinsicValue state at name = intrinsic state at name (typeForSpan (contextTypes (lowerContext state)) at)

{-| `let stop: fn(Str) -> Never = panic`. Checking gives panic no type (#634),
    so the binding and the name both read as the error type and only the
    written annotation says what the value is. Only panic's own signature is
    taken from it; any other annotation stays refused, since nothing checked
    that the calls through it agree. -}
annotatedPanic :: LowerState -> Maybe (Located TypeSyntax) -> Located Expression -> Maybe Lowered
annotatedPanic state annotation value = case (annotation, value) of
  (Just (Located _ written), Located at (NameExpression ("panic" :| [])))
    | Nothing <- lookupLocal state "panic"
    , Nothing <- resolveFunction state ["panic"]
    , Nothing <- typeForSpan (contextTypes (lowerContext state)) at
    , panicSignature written -> intrinsic state at "panic" (Just (CoreFunctionType [CoreTextType] CoreNeverType))
  _ -> Nothing
 where
  panicSignature written = case written of
    FunctionType False [Located _ argument] (Located _ result) -> builtin "Str" argument && builtin "Never" result
    _ -> False
  builtin name written = written == NamedType (ModuleName (name :| [])) []

intrinsic :: LowerState -> Span -> Text -> Maybe CoreType -> Maybe Lowered
intrinsic state at name solved
  | name `elem` ["print", "printPart", "printError", "printErrorPart"] = Just $
      case solved of
        Just kind@(CoreFunctionType [CoreTextType] result@(CoreSumType "Result" [CoreUnitType, CoreTextType])) ->
          register state at name ("$builtin:" <> name) kind [CoreTextType] result
            (one (\entered operand -> outputResult entered at name operand result))
        _ -> halt at "an output builtin without its represented callable type" state
  | name `elem` ["display", "show"] = Just $ case solved of
      Just kind@(CoreFunctionType [argument] CoreTextType) | nativeValueType argument ->
        let key = "$builtin:" <> name <> ":" <> Text.pack (show kind)
            shape = if name == "display" then CoreDisplay else CoreShow
         in register state at name key kind [argument] CoreTextType
              (one (\entered operand -> (entered, Just (CoreExpression at CoreTextType (shape operand), CoreTextType))))
      _ -> halt at "a rendering builtin without its represented callable type" state
  | name `elem` ["charFromCode", "bytesOf", "mapOf", "setOf"] = Just $ case solved of
      Just kind@(CoreFunctionType [argument] result)
        | nativeValueType argument, Just build <- collectionBody at name argument result ->
            register state at name ("$builtin:" <> name <> ":" <> Text.pack (show kind)) kind [argument] result (one build)
      _ -> halt at "a conversion builtin without its represented callable type" state
  -- Checking binds no type for panic, so its reference reads as an error type
  -- unless the value lands somewhere that names one; fn(Str) -> Never is what
  -- every call of it accepts then.
  | name `elem` ["panic", "convertInteger"] = Just $ case stoppingKind of
      Just kind@(CoreFunctionType arguments result) | all nativeValueType arguments ->
          let body entered operands = (entered, Just (stopping operands, CoreNeverType))
              stopping operands = case (name, operands) of
                ("panic", [message]) | coreExpressionType message == CoreTextType -> panicBody at message
                ("panic", _) -> wrongPanicBody at
                _ -> untypedConvertBody at
           in register state at name ("$builtin:" <> name <> ":" <> Text.pack (show kind)) kind arguments result body
      _ -> halt at "a stopping builtin without its represented callable type" state
  | otherwise = Nothing
 where
  stoppingKind = case solved of
    Just kind@(CoreFunctionType _ _) -> Just kind
    _ | name == "panic" -> Just (CoreFunctionType [CoreTextType] CoreNeverType)
    _ -> Nothing

one :: (LowerState -> CoreExpression -> Lowered) -> LowerState -> [CoreExpression] -> Lowered
one build entered operands = case operands of
  [operand] -> build entered operand
  _ -> (entered, Nothing)

register :: LowerState -> Span -> Text -> Text -> CoreType -> [CoreType] -> CoreType
  -> (LowerState -> [CoreExpression] -> Lowered) -> Lowered
register state at name key kind arguments result build
  | Map.member key (contextClosures (lowerContext state)) = answer state
  | otherwise =
      let locals = [CoreLocal index (parameterName index) argument | (index, argument) <- zip [0 ..] arguments]
          parameters = [CoreParameter local at | local <- locals]
          entered = (startFunction state parameters (Just result)){lowerCurrentKey = key}
          operands = [CoreExpression at (coreLocalType local) (CoreReadLocal local) | local <- locals]
       in case build entered operands of
            (after, Just (body, _)) ->
              let function = CoreFunction key parameters result (CoreBlock [] (Just body))
                  added = lowerContext after
                  info = CoreClosureInfo [] name ("builtin " <> name) True False
                  registered = added
                    { contextFunctions = function : contextFunctions added
                    , contextClosures = Map.insert key info (contextClosures added)
                    }
               in answer state{lowerContext = registered}
            (after, Nothing) -> (state{lowerContext = lowerContext after}, Nothing)
 where
  answer after = (after, Just (CoreExpression at kind (CoreClosure key []), kind))
  parameterName index = if index == (0 :: Int) then "value" else "value" <> Text.pack (show index)

{-| The same Core the direct call builds, over the parameter. Nothing when the
    solved signature is not one this builtin has. -}
collectionBody :: Span -> Text -> CoreType -> CoreType -> Maybe (LowerState -> CoreExpression -> Lowered)
collectionBody at name argument result = case (name, argument, result) of
  ("charFromCode", _, CoreSumType _ [CoreCharType]) | argument == intType ->
    Just (\entered operand -> charFromCodeCore entered at result operand)
  ("bytesOf", CoreArrayType (CoreIntegerType (UnsignedKind 8)), CoreBytesType) ->
    Just (\entered operand -> (entered, Just (bytesFromArray at operand, CoreBytesType)))
  ("mapOf", CoreArrayType (CoreTupleType [key, value]), CoreMapType key' value')
    | key == key' && value == value' -> keyed
  ("setOf", CoreArrayType member, CoreSetType member') | member == member' -> keyed
  _ -> Nothing
 where
  keyed = Just (\entered operand ->
    maybe (halt at ("a " <> name <> " value without its collection type") entered) id
      (keyedFromArray entered at name result operand))
