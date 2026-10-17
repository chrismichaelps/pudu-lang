{-| @Pudu.Compiler.Lower.Signature — memoized admission of reachable native signatures. -}
module Pudu.Compiler.Lower.Signature (ensureSignature, functionLevelRefusal) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), LowerContext (..), LowerState (..), intType, refuse )
import Pudu.Compiler.Lower.Types (formedCoreType, lookupScheme)
import Pudu.Type.Value (Scheme (..), Type (FunctionTypeRequiring), requiredCount)
import Pudu.Core
import Pudu.Frontend.Syntax
  ( Function (..), FunctionBody (..), Located (..), Parameter (..) )
import Pudu.Source (Span)

{-| Admit each reachable monomorphic signature once, including refusals. -}
ensureSignature :: Located Function -> LowerState -> (LowerState, Maybe CoreSignature)
ensureSignature located state = case Map.lookup name (contextSignatures context) of
  Just memo -> (state, memo)
  Nothing -> case functionLevelRefusal function of
    Just (spanValue, construct) -> memoize (refuse spanValue construct state) Nothing
    Nothing | defaulted : _ <- defaults ->
      memoize (refuse (locatedSpan defaulted) "default parameter values" state) Nothing
    Nothing -> case lookupScheme (contextTypes context) name of
      Just Scheme{schemeParams = [], schemeBounds = [], schemeType = FunctionTypeRequiring False inputs required result}
        | length inputs == length (functionParameters function)
        , requiredCount required == length inputs ->
            let (afterParameters, parameters) = foldl' validateParameter (state, [])
                  (zip3 [0 ..] (map locatedValue (functionParameters function)) inputs)
                (afterReturn, resultType) = validateReturn afterParameters result
                added = length (contextRefusals (lowerContext afterReturn))
                  - length (contextRefusals context)
             in if added == 0
                  then memoize afterReturn (Just (CoreSignature parameters resultType))
                  else memoize afterReturn Nothing
      _ -> memoize (refuse atName "a function without a supported solved monomorphic signature" state) Nothing
  where
    context = lowerContext state
    function = locatedValue located
    name = locatedValue (functionName function)
    atName = locatedSpan (functionName function)
    defaults = [value | parameter <- functionParameters function, Just value <- [parameterDefault (locatedValue parameter)]]
    memoize after memo =
      ( after
          { lowerContext =
              (lowerContext after)
                { contextSignatures = Map.insert name memo (contextSignatures context) }
          }
      , memo
      )

    validateParameter (current, collected) (index, parameter, parameterTypeValue) =
      case parameterDefault parameter of
        Just defaulted -> (refuse (locatedSpan defaulted) "default parameter values" current, collected)
        Nothing -> case formedCoreType parameterTypeValue of
          Just coreType | coreType `elem` [intType, CoreBoolType, CoreUnitType] ->
            ( current
            , collected <> [CoreParameter
                { coreParameterLocal = CoreLocal index (locatedValue (parameterName parameter)) coreType
                , coreParameterSpan = locatedSpan (parameterName parameter)
                }]
            )
          projected ->
            ( refuse (maybe (locatedSpan (parameterName parameter)) locatedSpan (parameterType parameter))
                (maybe "a parameter type outside the native subset" (("a parameter of type " <>) . coreTypeName) projected) current
            , collected
            )

    validateReturn current result = case formedCoreType result of
      Just coreType | coreType `elem` [intType, CoreBoolType, CoreUnitType] -> (current, coreType)
      projected ->
        ( refuse (maybe atName locatedSpan (functionReturn function))
            (maybe "a return type outside the native subset" (("a return type of " <>) . coreTypeName) projected) current
        , intType
        )

functionLevelRefusal :: Function -> Maybe (Span, Text)
functionLevelRefusal function
  | not (null (functionTypeParams function)) = Just (atName, "type parameters")
  | functionAsync function = Just (atName, "async functions")
  | Just _ <- functionUnsafe function = Just (atName, "unsafe functions")
  | functionComptime function = Just (atName, "comptime functions")
  | not (null (functionConstraints function)) = Just (atName, "function constraints")
  | otherwise = case functionBody function of
      Nothing -> Just (atName, "a function without a body")
      Just (Located bodySpan (ExpressionBody _)) -> Just (bodySpan, "an expression-bodied function")
      Just (Located _ (BlockBody _)) -> Nothing
  where
    atName = locatedSpan (functionName function)
