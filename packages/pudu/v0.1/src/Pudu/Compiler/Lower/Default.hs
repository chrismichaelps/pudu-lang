{-| @Pudu.Compiler.Lower.Default — functions with default parameter values.
    Such a function takes one more parameter: how many arguments the call
    supplied. Its body opens by giving every parameter the call did not reach
    its default, in order, so a default sees the parameters before it. -}
module Pudu.Compiler.Lower.Default
  ( takesSuppliedCount, trailingDefaults, suppliedArguments, callArityFailure
  , withCallableArity, lowerDefaultedBody ) where

import Control.Applicative ((<|>))
import Data.List (mapAccumL)
import qualified Data.Map.Strict as Map
import Data.Maybe (isJust)
import Data.Text (Text)
import Pudu.Compiler.Lower.Arguments (ArgumentBlame (AtCaller), argumentFailureWith)
import Pudu.Compiler.Lower.Dynamic (joinRuntimeArms, projectRuntimeValue)
import Pudu.Compiler.Lower.State
  ( CallableSource (..), CallableTemplate (..), CoreSignature (..), Instance (instanceFunction)
  , LowerContext (..), LowerState (..), bindLocal, intType, refuse, refused )
import Pudu.Compiler.Lower.Types (ownerKeyOf, selectedMember)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Function (..), Located (..), Parameter (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)
import Pudu.Type.Value (Type (FunctionTypeRequiring), requiredCount)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type LowerBody = Located Function -> CoreSignature -> LowerState -> (LowerState, Maybe CoreFunction)
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

takesSuppliedCount :: CoreSignature -> Bool
takesSuppliedCount = any ((== suppliedCountName) . coreLocalName . coreParameterLocal) . signatureParameters

{-| Each parameter's default when it belongs to the trailing run a call may
    omit. A default written before a parameter without one is never used: the
    checker requires an argument there. -}
trailingDefaults :: Function -> [Maybe (Located Expression)]
trailingDefaults function = map (const Nothing) required <> map (parameterDefault . locatedValue) (reverse omissible)
 where
  (omissible, required) = span (isJust . parameterDefault . locatedValue) (reverse (functionParameters function))

{-| What a call passes to a function with defaults: the arguments it wrote,
    a zero for each parameter it left out, then how many it wrote. The types
    are the callee's parameters, the count's included. -}
suppliedArguments :: Span -> [CoreType] -> [CoreExpression] -> [CoreExpression]
suppliedArguments at parameterTypes given =
  given
    <> [CoreExpression at kind CoreAbsent | kind <- drop (length given) (take (length parameterTypes - 1) parameterTypes)]
    <> [CoreExpression at intType (CoreIntegerLiteral PlatformSigned (toInteger (length given)))]

callArityFailure :: ArgumentBlame -> Span -> CoreSignature -> Int -> Maybe CoreExpression
callArityFailure blame at signature supplied
  | supplied > written = Just (tooManyArguments blame at)
  | defaulted = Nothing
  | parameter : _ <- drop supplied (signatureParameters signature) =
      let name = coreLocalName (coreParameterLocal parameter)
       in Just (missingArgument blame at name)
  | otherwise = Nothing
 where
  defaulted = takesSuppliedCount signature
  written = length (signatureParameters signature) - if defaulted then 1 else 0

tooManyArguments :: ArgumentBlame -> Span -> CoreExpression
tooManyArguments blame at = argumentFailureWith blame at "E7003"
  (Just "pass one argument per declared parameter")
  (CoreExpression at CoreTextType (CoreTextLiteral "too many arguments in call"))

missingArgument :: ArgumentBlame -> Span -> Text -> CoreExpression
missingArgument blame at name = argumentFailureWith blame at "E7003"
  (Just "supply the argument or give the parameter a default")
  (CoreExpression at CoreTextType (CoreTextLiteral ("missing argument for parameter " <> name)))

{-| The hidden count shares an ordinary integer slot, so the selected
    closure's identity determines whether that slot belongs to the caller. -}
withCallableArity :: ArgumentBlame -> Span -> LowerState -> Bool -> CoreExpression
  -> [CoreType] -> CoreType -> [CoreExpression]
  -> (LowerState -> Bool -> CoreExpression -> [CoreExpression] -> Lowered) -> Lowered
withCallableArity blame at state checkedDefault target inputs result given invoke
  | CoreClosure key _ <- coreExpressionShape target
  , Just profile <- Map.lookup key known >>= callableArity context =
      if invalid profile then retained (apply profile) else apply profile demanded target given
  | null alternatives, not (invalid fallback) = apply fallback demanded target given
  | otherwise = retained $ \current held arguments ->
      let makeArm prior (key, profile) =
            let (next, outcome) = apply profile prior held arguments
                matches = CoreExpression at CoreBoolType (CoreClosureIs key held)
             in (next, (\(value, _) -> CoreArm at CoreWildcardPattern (Just matches) value) <$> outcome)
          (ready, arms) = mapAccumL makeArm current alternatives
          (after, answer) = apply fallback ready held arguments
       in case (sequence arms, answer) of
            (Just selected, Just (otherwise', _)) ->
              let subject = CoreExpression at CoreUnitType (CoreBlockValue (CoreBlock [] Nothing))
                  joined = joinRuntimeArms at result subject
                    (selected <> [CoreArm at CoreWildcardPattern Nothing otherwise'])
               in (after, Just (joined, coreExpressionType joined))
            _ -> refused after
 where
  context = lowerContext state
  supplied = length given
  known = Map.filter ((== coreExpressionType target) . callableTemplateType)
    (Map.union (contextObservedCallables context) (contextKnownCallables context))
  fallback = (replicate (length inputs - fromEnum checkedDefault) "argument", checkedDefault)
  invalid (names, defaulted) = supplied > length names || not defaulted && supplied < length names
  alternatives =
    [(key, profile) | (key, template) <- Map.toAscList known
    , Just profile <- [callableArity context template]
    , snd profile /= checkedDefault || invalid profile]
  couldHaveCount = case reverse inputs of
    count : _ : _ -> count == intType
    _ -> False
  demanded = state{lowerContext = context{contextNeedsCallableReplay =
    contextNeedsCallableReplay context || checkedDefault || couldHaveCount || invalid fallback}}
  apply (names, defaulted) current held arguments
    | supplied > length names = failed current (tooManyArguments blame at)
    | not defaulted, name : _ <- drop supplied names = failed current (missingArgument blame at name)
    | otherwise = invoke current defaulted held arguments
  failed current value = (current, Just (value, CoreNeverType))
  retained select =
    let operands = target : given
        (ready, locals) = mapAccumL (\prior value -> bindLocal prior "" (coreExpressionType value)) demanded operands
        declarations = zipWith (\local value -> CoreStatement (coreExpressionSpan value) (CoreDeclare local value)) locals operands
        readLocal local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
        reblock (value, kind) = (CoreExpression at kind (CoreBlockValue (CoreBlock declarations (Just value))), kind)
     in case map readLocal locals of
          held : arguments -> fmap (fmap reblock) (select ready held arguments)
          [] -> refused ready

callableArity :: LowerContext -> CallableTemplate -> Maybe ([Text], Bool)
callableArity context template = case callableTemplateSource template of
  NamedCallable (_, declaration) signature _ -> Just (names (locatedValue declaration), takesSuppliedCount signature)
  LiftedCallable _ _ _ _ function _ _ _ -> Just (names function, False)
  MethodCallable _ _ _ _ member bound (CoreFunctionType arguments _) (FunctionTypeRequiring _ written required _) ->
    let receiver = bound <|> case arguments of
          self : _ -> Just self
          [] -> Nothing
        (provider, plain) = selectedMember member
        declared = do
          owner <- receiver >>= ownerKeyOf
          let qualified = provider >>= \trait -> Map.lookup (trait, owner, plain) (contextTraitMethods context)
          key <- qualified <|> Map.lookup (owner, plain) (contextMethods context)
          found <- Map.lookup key (contextInstances context)
          pure (drop (fromEnum (isJust bound)) (names (locatedValue (instanceFunction found))))
        parameters = take (length written) (maybe [] id declared <> repeat "argument")
     in Just (parameters, requiredCount required < length written)
  _ -> Nothing
 where
  names = map (locatedValue . parameterName . locatedValue) . functionParameters

{-| The body with its defaults in front. A default is lowered in the
    callee, after the parameters before it are in scope. -}
lowerDefaultedBody :: LowerExpression -> LowerBody -> LowerBody
lowerDefaultedBody lower lowerBody located signature state =
  case reverse (map coreParameterLocal (signatureParameters signature)) of
    supplied : parameters
      | coreLocalName supplied == suppliedCountName ->
          let bindings = zip3 [0 :: Integer ..] (reverse parameters) (functionParameters (locatedValue located))
           in case foldl' (fill supplied) (state, Just []) bindings of
                (after, Nothing) -> (after, Nothing)
                (after, Just prologue) -> case lowerBody located signature after of
                  (final, Just lowered) ->
                    let body = coreFunctionBody lowered
                     in (final, Just lowered{coreFunctionBody = body{coreBlockStatements = reverse prologue <> coreBlockStatements body}})
                  other -> other
    _ -> lowerBody located signature state
 where
  fill _ (current, Nothing) _ = (current, Nothing)
  fill supplied (current, Just done) (index, local, Located parameterAt parameter) =
    case parameterDefault parameter of
      Nothing ->
        let name = locatedValue (parameterName parameter)
            message = CoreExpression parameterAt CoreTextType (CoreTextLiteral ("missing argument for parameter " <> name))
            failure = argumentFailureWith AtCaller parameterAt "E7003"
              (Just "supply the argument or give the parameter a default") message
         in (current, Just (whenMissing supplied parameterAt index (CoreEvaluate failure) : done))
      Just value -> case lower current value of
        (after, Nothing) -> (after, Nothing)
        (after, Just (lowered, _)) ->
          let at = locatedSpan value
              (ready, core) = projectRuntimeValue (contextTypes (lowerContext after)) after (coreLocalType local) lowered
              kind = coreExpressionType core
           in if kind == coreLocalType local || kind == CoreNeverType
                then (ready, Just (whenMissing supplied at index (CoreAssign local core) : done))
                else (refuse at ("a default of type " <> coreTypeName kind) ready, Nothing)
  whenMissing supplied at index action =
    let count = CoreExpression at intType (CoreReadLocal supplied)
        position = CoreExpression at intType (CoreIntegerLiteral PlatformSigned index)
        missing = CoreExpression at CoreBoolType (CoreBinary CoreLessOrEqual count position)
     in CoreStatement at (CoreIf missing (CoreBlock [CoreStatement at action] Nothing) Nothing)
