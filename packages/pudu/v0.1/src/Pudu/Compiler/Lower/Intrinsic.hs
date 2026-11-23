{-| @Pudu.Compiler.Lower.Intrinsic — callable bodies for prelude values. -}
module Pudu.Compiler.Lower.Intrinsic (lowerIntrinsicValue, specializeIntrinsicValue, annotatedPanic) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Pudu.Compiler.Lower.Arguments as Arguments
import Pudu.Compiler.Lower.Bytes (bytesOfArguments)
import Pudu.Compiler.Lower.Call (outputResult, outputText)
import Pudu.Compiler.Lower.Concurrent (concurrentCallable, concurrentPrimitive)
import Pudu.Compiler.Lower.Convert (charFromCodeCore)
import Pudu.Compiler.Lower.WordMap (wordMapCallable, wordMapMethod)
import Pudu.Compiler.Lower.Decimal (decimalCallable)
import Pudu.Compiler.Lower.Text (textCallable)
import Pudu.Compiler.Lower.Keyed (Blame (AtCaller), keyedBuilderCarrier, keyedFromArray)
import Pudu.Compiler.Lower.Store (storeCallable, storePrimitive)
import Pudu.Compiler.Lower.Kernel (kernelCallable)
import Pudu.Compiler.Lower.Swiss (swissCallable, swissPrimitive)
import Pudu.Compiler.Lower.State (CallableSource (..), CallableTemplate (..), LowerContext (..), LowerState (..), halt, intType, lookupLocal, resolveFunction, startFunction)
import Pudu.Compiler.Lower.Stop (panicBody, untypedConvertBody, wrongPanicBody)
import Pudu.Compiler.Lower.Types (nativeValueType, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..), TypeSyntax (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

lowerIntrinsicValue :: LowerState -> Span -> Text -> Maybe Lowered
lowerIntrinsicValue state at name = intrinsic state at name (typeForSpan (contextTypes (lowerContext state)) at)

specializeIntrinsicValue :: LowerState -> Span -> Text -> CoreType -> [CoreType] -> Maybe Lowered
specializeIntrinsicValue state at name checked supplied = do
  CoreFunctionType inputs result <- Just checked
  if length inputs == length supplied && adaptable name then do
    let actualResult = case supplied of
          [array] | Just (built, _) <- keyedBuilderCarrier (contextTypes (lowerContext state)) name result array -> built
          _ -> result
    (ready, original) <- intrinsic state at name (Just checked)
    case original of
      Nothing -> Just (ready, Nothing)
      Just _ -> intrinsic ready at name (Just (CoreFunctionType supplied actualResult))
  else Nothing

adaptable :: Text -> Bool
adaptable name = name `elem`
  ["display", "show", "print", "printPart", "printError", "printErrorPart", "panic", "mapOf", "setOf", "bytesOf"]
  || case textCallable name of { Just _ -> True; Nothing -> False }

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
        Just kind@(CoreFunctionType [argument] result@(CoreSumType "Result" [CoreUnitType, CoreTextType]))
          | nativeValueType argument ->
              let key = "$builtin:" <> name
                    <> (if argument == CoreTextType then "" else ":" <> Text.pack (show kind))
               in register state at name key kind [argument] result
                    (one (\entered operand ->
                      let (ready, rendered) = outputText at entered operand
                       in outputResult ready at name rendered result))
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
  | Just _ <- wordMapMethod name = Just $ case solved of
      Just kind@(CoreFunctionType arguments result) | Just build <- wordMapCallable name kind ->
        register state at name ("$builtin:" <> name <> ":" <> Text.pack (show kind)) kind arguments result (\entered -> build entered at)
      _ -> halt at "a word-map builtin without its represented callable type" state
  | storePrimitive name = Just $ case solved of
      Just kind@(CoreFunctionType arguments result) | Just build <- storeCallable AtCaller name kind ->
        register state at name ("$builtin:" <> name <> ":" <> Text.pack (show kind)) kind arguments result (\entered -> build entered at)
      _ -> halt at "a store builtin without its represented callable type" state
  | concurrentPrimitive name = Just $ case solved of
      Just kind@(CoreFunctionType arguments result) | Just build <- concurrentCallable name kind ->
        register state at name ("$builtin:" <> name <> ":" <> Text.pack (show kind)) kind arguments result (\entered -> build entered at)
      _ -> halt at "a host builtin without its represented callable type" state
  | swissPrimitive name = Just $ case solved of
      Just kind@(CoreFunctionType arguments result) | Just build <- swissCallable AtCaller (contextTypes (lowerContext state)) name kind ->
        register state at name ("$builtin:" <> name <> ":" <> Text.pack (show kind)) kind arguments result (\entered -> build entered at)
      _ -> halt at "a flat-table builtin without its represented callable type" state
  | Just (kind@(CoreFunctionType arguments result), build) <- kernelCallable (contextTypes (lowerContext state)) name = Just $
      if solved == Just kind
        then register state at name ("$builtin:" <> name <> ":" <> Text.pack (show kind)) kind arguments result
          (\entered -> build entered at)
        else halt at "a kernel builtin without its represented callable type" state
  | Just (CoreFunctionType parameters expected, build) <- textCallable name = Just $ case solved of
      Just kind@(CoreFunctionType arguments result)
        | result == expected, length arguments == length parameters, all nativeValueType arguments ->
            register state at name ("$builtin:" <> name <> ":" <> Text.pack (show kind)) kind arguments result
              (\entered -> build entered at)
      _ -> halt at "a text-view builtin without its represented callable type" state
  | Just (kind@(CoreFunctionType arguments result), build) <- decimalCallable name = Just $
      if solved == Just kind
        then register state at name ("$builtin:" <> name <> ":" <> Text.pack (show kind)) kind arguments result
          (\entered -> build entered at)
        else halt at "a Decimal builtin without its represented callable type" state
  -- Checking binds no type for panic, so its reference reads as an error type
  -- unless the value lands somewhere that names one; fn(Str) -> Never is what
  -- every call of it accepts then.
  | name `elem` ["panic", "convertInteger"] = Just $ case stoppingKind of
      Just kind@(CoreFunctionType arguments result) | all nativeValueType arguments ->
          let body entered operands = case (name, operands) of
                ("panic", [message]) ->
                  let (ready, stopped) = panicBody entered at message
                   in (ready, Just (stopped, CoreNeverType))
                ("panic", _) -> (entered, Just (wrongPanicBody at, CoreNeverType))
                _ -> (entered, Just (untypedConvertBody at, CoreNeverType))
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
                  info = CoreClosureInfo [] name ("builtin " <> name) True False Nothing
                  template = CallableTemplate kind (IntrinsicCallable at name kind)
                  registered = added
                    { contextFunctions = function : contextFunctions added
                    , contextClosures = Map.insert key info (contextClosures added)
                    , contextObservedCallables = if adaptable name
                        then Map.insert key template (contextObservedCallables added)
                        else contextObservedCallables added
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
  ("bytesOf", _, CoreBytesType) ->
    Just (\entered operand -> bytesOfArguments Arguments.AtCaller at entered [operand])
  ("mapOf", CoreArrayType _, CoreMapType _ _) -> keyed
  ("setOf", CoreArrayType _, CoreSetType _) -> keyed
  _ -> Nothing
 where
  keyed = Just (\entered operand ->
    maybe (halt at ("a " <> name <> " value without its collection type") entered) id
      (keyedFromArray entered at name result operand))
