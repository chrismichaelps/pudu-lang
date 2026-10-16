{-| @Pudu.Compiler.Lower.Signature — memoized admission of reachable native signatures. -}
module Pudu.Compiler.Lower.Signature (ensureSignature, functionLevelRefusal) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), LowerContext (..), LowerState (..), intType, refuse )
import Pudu.Core
import Pudu.Frontend.Syntax
  ( Function (..), FunctionBody (..), Located (..), Parameter (..), TypeSyntax (..), moduleNameText )
import Pudu.Source (Span)

{-| Validate a non-entry function once and memoize the answer, including a
    refused answer: the function-level rules, then every parameter (an
    annotation must exist and be `Int` or `Bool`, and no default value), then
    the return annotation (`Int`, `Bool`, or `()`). Parameter and return
    refusals aggregate; a function-level failure stops the check. -}
ensureSignature :: Located Function -> LowerState -> (LowerState, Maybe CoreSignature)
ensureSignature located state = case Map.lookup name (contextSignatures context) of
  Just memo -> (state, memo)
  Nothing -> case functionLevelRefusal function of
    Just (spanValue, construct) -> memoize (refuse spanValue construct state) Nothing
    Nothing ->
      let (afterParameters, parameters) = validateParameters
          (afterReturn, resultType) = validateReturn afterParameters
          added =
            length (contextRefusals (lowerContext afterReturn))
              - length (contextRefusals context)
       in if added == 0
            then memoize afterReturn (Just (CoreSignature parameters resultType))
            else memoize afterReturn Nothing
  where
    context = lowerContext state
    function = locatedValue located
    name = locatedValue (functionName function)
    atName = locatedSpan (functionName function)
    memoize after memo =
      ( after
          { lowerContext =
              (lowerContext after)
                { contextSignatures = Map.insert name memo (contextSignatures context) }
          }
      , memo
      )

    validateParameters =
      foldl' step (state, [])
        . zip [0 ..]
        . map locatedValue
        . functionParameters
        $ function
      where
        step (current, collected) (index, parameter) =
          case parameterType parameter of
            Nothing ->
              ( refuse (locatedSpan (parameterName parameter)) "a parameter without a type annotation" current
              , collected
              )
            Just annotation -> case coreTypeOfSyntax (locatedValue annotation) of
              Just annotationType
                | annotationType == intType || annotationType == CoreBoolType ->
                    case parameterDefault parameter of
                      Just defaulted ->
                        ( refuse (locatedSpan defaulted) "default parameter values" current
                        , collected
                        )
                      Nothing ->
                        ( current
                        , collected
                            <> [ CoreParameter
                                   { coreParameterLocal =
                                       CoreLocal
                                         { coreLocalId = index
                                         , coreLocalName = locatedValue (parameterName parameter)
                                         , coreLocalType = annotationType
                                         }
                                   , coreParameterSpan = locatedSpan (parameterName parameter)
                                   }
                               ]
                        )
              Just annotationType ->
                ( refuse (locatedSpan annotation) ("a parameter of type " <> coreTypeName annotationType) current
                , collected
                )
              Nothing ->
                ( refuse (locatedSpan annotation) "a parameter type outside the native subset" current
                , collected
                )

    validateReturn current = case functionReturn function of
      Nothing -> (refuse atName "a function without a declared return type" current, intType)
      Just annotation -> case coreTypeOfSyntax (locatedValue annotation) of
        Just annotationType
          | annotationType == intType
              || annotationType == CoreBoolType
              || annotationType == CoreUnitType ->
              (current, annotationType)
        Just annotationType ->
          (refuse (locatedSpan annotation) ("a return type of " <> coreTypeName annotationType) current, intType)
        Nothing ->
          (refuse (locatedSpan annotation) "a return type outside the native subset" current, intType)

{-| The annotation syntax the native subset carries: `()`; `Int`, `Bool`, and
    `Str` by unqualified name; everything else maps to nothing. -}
coreTypeOfSyntax :: TypeSyntax -> Maybe CoreType
coreTypeOfSyntax syntax = case syntax of
  UnitType -> Just CoreUnitType
  NamedType path [] -> case moduleNameText path of
    "Int" -> Just intType
    "Bool" -> Just CoreBoolType
    "Str" -> Just CoreTextType
    _ -> Nothing
  _ -> Nothing

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
