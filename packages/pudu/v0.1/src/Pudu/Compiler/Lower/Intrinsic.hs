{-| @Pudu.Compiler.Lower.Intrinsic — callable bodies for prelude values. -}
module Pudu.Compiler.Lower.Intrinsic (lowerOutputValue) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Compiler.Lower.Call (outputResult)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), halt, startFunction)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.Source (Span)

lowerOutputValue :: LowerState -> Span -> Text -> Maybe (LowerState, Maybe (CoreExpression, CoreType))
lowerOutputValue state at name
  | name `notElem` ["print", "printPart", "printError", "printErrorPart"] = Nothing
  | otherwise = Just $ case typeForSpan (contextTypes context) at of
      Just kind@(CoreFunctionType [CoreTextType] result@(CoreSumType "Result" [CoreUnitType, CoreTextType]))
        | Map.member key (contextClosures context) -> answer state kind
        | otherwise ->
            let parameter = CoreLocal 0 "text" CoreTextType
                entered = (startFunction state [CoreParameter parameter at] (Just result)){lowerCurrentKey = key}
                operand = CoreExpression at CoreTextType (CoreReadLocal parameter)
             in case outputResult entered at name operand result of
                  (after, Just (body, _)) ->
                    let function = CoreFunction key [CoreParameter parameter at] result (CoreBlock [] (Just body))
                        added = lowerContext after
                        info = CoreClosureInfo [] name ("builtin " <> name) True False
                        registered = added
                          { contextFunctions = function : contextFunctions added
                          , contextClosures = Map.insert key info (contextClosures added)
                          }
                     in answer state{lowerContext = registered} kind
                  (after, Nothing) -> (state{lowerContext = lowerContext after}, Nothing)
      _ -> halt at "an output builtin without its represented callable type" state
 where
  context = lowerContext state
  key = "$builtin:" <> name
  answer after kind = (after, Just (CoreExpression at kind (CoreClosure key []), kind))
