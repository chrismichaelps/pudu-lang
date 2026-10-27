{-| @Pudu.Compiler.Lower.Intrinsic — callable bodies for prelude values. -}
module Pudu.Compiler.Lower.Intrinsic (lowerIntrinsicValue) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Bytes (bytesFromArray)
import Pudu.Compiler.Lower.Call (outputResult)
import Pudu.Compiler.Lower.Convert (charFromCodeCore)
import Pudu.Compiler.Lower.Keyed (keyedFromArray)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), halt, intType, startFunction)
import Pudu.Compiler.Lower.Types (nativeValueType, typeForSpan)
import Pudu.Core
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

lowerIntrinsicValue :: LowerState -> Span -> Text -> Maybe Lowered
lowerIntrinsicValue state at name
  | name `elem` ["print", "printPart", "printError", "printErrorPart"] = Just $
      case solved of
        Just kind@(CoreFunctionType [CoreTextType] result@(CoreSumType "Result" [CoreUnitType, CoreTextType])) ->
          register state at name ("$builtin:" <> name) kind CoreTextType result
            (\entered operand -> outputResult entered at name operand result)
        _ -> halt at "an output builtin without its represented callable type" state
  | name `elem` ["display", "show"] = Just $ case solved of
      Just kind@(CoreFunctionType [argument] CoreTextType) | nativeValueType argument ->
        let key = "$builtin:" <> name <> ":" <> Text.pack (show kind)
            shape = if name == "display" then CoreDisplay else CoreShow
         in register state at name key kind argument CoreTextType
              (\entered operand -> (entered, Just (CoreExpression at CoreTextType (shape operand), CoreTextType)))
      _ -> halt at "a rendering builtin without its represented callable type" state
  | name `elem` ["charFromCode", "bytesOf", "mapOf", "setOf"] = Just $ case solved of
      Just kind@(CoreFunctionType [argument] result)
        | nativeValueType argument, Just build <- collectionBody at name argument result ->
            register state at name ("$builtin:" <> name <> ":" <> Text.pack (show kind)) kind argument result build
      _ -> halt at "a conversion builtin without its represented callable type" state
  | otherwise = Nothing
 where
  solved = typeForSpan (contextTypes (lowerContext state)) at

register :: LowerState -> Span -> Text -> Text -> CoreType -> CoreType -> CoreType
  -> (LowerState -> CoreExpression -> Lowered) -> Lowered
register state at name key kind argument result build
  | Map.member key (contextClosures (lowerContext state)) = answer state
  | otherwise =
      let parameter = CoreLocal 0 "value" argument
          entered = (startFunction state [CoreParameter parameter at] (Just result)){lowerCurrentKey = key}
          operand = CoreExpression at argument (CoreReadLocal parameter)
       in case build entered operand of
            (after, Just (body, _)) ->
              let function = CoreFunction key [CoreParameter parameter at] result (CoreBlock [] (Just body))
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
