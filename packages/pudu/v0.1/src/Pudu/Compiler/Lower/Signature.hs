{-| @Pudu.Compiler.Lower.Signature — memoized admission of reachable native signatures. -}
module Pudu.Compiler.Lower.Signature (ensureSignature, functionLevelRefusal) where

import qualified Data.Map.Strict as Map
import Data.Maybe (isNothing)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), Instance (..), LowerContext (..), LowerState (..), intType, refuse )
import Pudu.Compiler.Lower.Types (formedCoreTypeIn, lookupScheme, nativeValueType, typeBindings)
import Pudu.Type.Value (Scheme (..), Type (FunctionTypeRequiring), requiredCount)
import Pudu.Core
import Pudu.Frontend.Syntax
  ( Function (..), FunctionBody (..), Located (..), Parameter (..), TypeParam (..) )
import Pudu.Source (Span)

{-| Admit each reachable monomorphic signature once, including refusals,
    memoized by the function's canonical name. The scheme is read from the
    current module's facts, so the caller enters the function's module first.
    An instance brings its own scheme; its rigid parameters must all be bound
    in the current facts, and then its bounds were already proved by checking
    for the types they are bound to. -}
ensureSignature :: Text -> Located Function -> LowerState -> (LowerState, Maybe CoreSignature)
ensureSignature key located state = case Map.lookup key (contextSignatures context) of
  Just memo -> (state, memo)
  Nothing -> case boundFunctionRefusal (Map.keysSet (typeBindings (contextTypes context))) function of
    Just (spanValue, construct) -> memoize (refuse spanValue construct state) Nothing
    Nothing | misplaced : _ <- requiredAfterDefault ->
      memoize (refuse misplaced "a default before a required parameter" state) Nothing
    Nothing -> case maybe (lookupScheme (contextTypes context) name) (Just . instanceScheme) (Map.lookup key (contextInstances context)) of
      Just Scheme{schemeParams, schemeBounds, schemeType = FunctionTypeRequiring False inputs required result}
        | all ((`Map.member` typeBindings (contextTypes context)) . fst) schemeParams
        , not (null schemeParams) || null schemeBounds
        , length inputs == length (functionParameters function)
        , requiredCount required == length inputs - length defaults ->
            let (afterParameters, given) = foldl' validateParameter (state, [])
                  (zip3 [0 ..] (map locatedValue (functionParameters function)) inputs)
                parameters = given <> [CoreParameter (CoreLocal (length inputs) "" intType) atName | not (null defaults)]
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
    -- Defaults fill from the end; one followed by a required parameter could
    -- not be told apart by a count of supplied arguments.
    requiredAfterDefault =
      [ locatedSpan (parameterName parameter)
      | parameter <- map locatedValue (dropWhile (isNothing . parameterDefault . locatedValue) (functionParameters function))
      , isNothing (parameterDefault parameter) ]
    memoize after memo =
      ( after
          { lowerContext =
              (lowerContext after)
                { contextSignatures = Map.insert key memo (contextSignatures context) }
          }
      , memo
      )

    validateParameter (current, collected) (index, parameter, parameterTypeValue) =
      case formedCoreTypeIn (contextTypes (lowerContext current)) parameterTypeValue of
        Just coreType | nativeValueType coreType ->
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

    validateReturn current result = case formedCoreTypeIn (contextTypes (lowerContext current)) result of
      Just coreType | nativeValueType coreType -> (current, coreType)
      projected ->
        ( refuse (maybe atName locatedSpan (functionReturn function))
            (maybe "a return type outside the native subset" (("a return type of " <>) . coreTypeName) projected) current
        , intType
        )

functionLevelRefusal :: Function -> Maybe (Span, Text)
functionLevelRefusal = boundFunctionRefusal Set.empty

{-| A copy of a generic function knows its type parameters, and checking
    proved its constraints for them, so neither refuses there. -}
boundFunctionRefusal :: Set Text -> Function -> Maybe (Span, Text)
boundFunctionRefusal bound function
  | not specialized = Just (atName, "type parameters")
  | functionAsync function = Just (atName, "async functions")
  | Just _ <- functionUnsafe function = Just (atName, "unsafe functions")
  | functionComptime function = Just (atName, "comptime functions")
  | not (null (functionConstraints function)) && null (functionTypeParams function) = Just (atName, "function constraints")
  | otherwise = case functionBody function of
      Nothing -> Just (atName, "a function without a body")
      Just (Located _ (ExpressionBody _)) -> Nothing
      Just (Located _ (BlockBody _)) -> Nothing
  where
    atName = locatedSpan (functionName function)
    specialized = all ((`Set.member` bound) . locatedValue . typeParamName . locatedValue) (functionTypeParams function)
