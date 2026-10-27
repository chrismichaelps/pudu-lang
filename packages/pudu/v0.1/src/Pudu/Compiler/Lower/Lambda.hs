{-| @Pudu.Compiler.Lower.Lambda — lambdas, functions used as values, and calls
    through a function value. A lambda becomes a lifted function whose first
    parameter is its own closure. -}
module Pudu.Compiler.Lower.Lambda (lowerLambda, lowerFunctionValue, lowerValueCall) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Control (expressionIsPrintValued, printValued)
import Pudu.Compiler.Lower.Generic (admitCallee)
import Pudu.Compiler.Lower.State
  ( LowerContext (..), LowerState (..), bindLocal, halt, lookupLocal, refused, startFunction )
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.Eval.Capture (reachableNames)
import Pudu.Frontend.Syntax (Block, Expression, Function (..), FunctionBody (..), Located (..), Parameter (..))
import Pudu.Source (Span (..), spanSource, unOffset, unSourceName)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type LowerBlock = LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| The closure copies what the lambda mentions from the enclosing locals,
    when the lambda is evaluated, as the evaluator's capture does. Its body is
    lowered as a function of its own, keyed by the body it was written in, so
    each copy of a generic body gets its own lambda. -}
lowerLambda :: LowerExpression -> LowerBlock -> LowerState -> Span -> Function -> Lowered
lowerLambda lower block state at function
  | functionAsync function = halt at "async lambdas" state
  | otherwise = case typeForSpan (contextTypes (lowerContext state)) at of
      Just kind@(CoreFunctionType inputs result)
        | length inputs == length (functionParameters function) ->
            let key = lowerCurrentKey state <> "#" <> Text.pack (show (unOffset (spanStart at)))
                captured =
                  [ local | name <- Set.toAscList (reachableNames function), Just local <- [lookupLocal state name] ]
                env = CoreLocal 0 "" kind
                parameters =
                  [ CoreParameter (CoreLocal index (locatedValue (parameterName parameter)) input) (locatedSpan (parameterName parameter))
                  | (index, Located _ parameter, input) <- zip3 [1 ..] (functionParameters function) inputs ]
                entered = (startFunction state (CoreParameter env at : parameters) (Just result)){lowerCurrentKey = key, lowerDeclaredResult = Nothing}
                (withCaptures, prologue) = foldl' capture (entered, []) (zip [0 ..] captured)
                capture (current, done) (index, local) =
                  let (next, inner) = bindLocal current (coreLocalName local) (coreLocalType local)
                      read' = CoreExpression at kind (CoreReadLocal env)
                   in (next, done <> [CoreStatement at (CoreDeclare inner (CoreExpression at (coreLocalType local) (CoreCapture index read')))])
                (afterBody, body) = lowered withCaptures
                lowered current = case functionBody function of
                  Just (Located _ (BlockBody written)) ->
                    let (next, coreBlock, _) = block current written
                     in (next, Just coreBlock)
                  Just (Located _ (ExpressionBody written)) -> case lower current written of
                    (next, Just (core, _)) -> (next, Just (CoreBlock [] (Just core)))
                    (next, Nothing) -> (next, Nothing)
                  Nothing -> (current, Nothing)
                restored context = state{lowerContext = context}
             in case body of
                  Nothing -> refused (restored (lowerContext afterBody))
                  Just coreBlock
                    | printValued coreBlock -> halt at "a lambda returning Result[(), Str]" (restored (lowerContext afterBody))
                    | otherwise ->
                        let lifted = CoreFunction key (CoreParameter env at : parameters) result
                              (coreBlock{coreBlockStatements = prologue <> coreBlockStatements coreBlock})
                            info = CoreClosureInfo (map coreLocalType captured) "<fn>" (siteOf at) False True
                            context = registered key lifted info (lowerContext afterBody)
                            captureReads = [CoreExpression at (coreLocalType local) (CoreReadLocal local) | local <- captured]
                         in (restored context, Just (CoreExpression at kind (CoreClosure key captureReads), kind))
      Just other -> halt at ("a lambda of type " <> coreTypeName other) state
      Nothing -> halt at "a lambda without a native function type" state

{-| Named values keep the target's own parameter ABI and call depth. -}
lowerFunctionValue :: LowerState -> Span -> Text -> (Text, Located Function) -> Lowered
lowerFunctionValue state at key entry = case typeForSpan (contextTypes (lowerContext state)) at of
  Just kind@(CoreFunctionType _ _) -> case admitCallee state key at entry of
    (admitted, Nothing) -> refused admitted
    (admitted, Just (target, _)) ->
      let name = locatedValue (functionName (locatedValue (snd entry)))
          context = lowerContext admitted
          info = CoreClosureInfo [] name ("fn " <> target) False False
          next = context
            { contextClosures = Map.insert target info (contextClosures context)
            , contextQueue = target : contextQueue context
            }
       in (admitted{lowerContext = next}, Just (CoreExpression at kind (CoreClosure target []), kind))
  _ -> halt at "a function value without a native function type" state

{-| `callee(arguments)` through a value. The arguments run first, then the
    callee, as `evaluateCall` does, so each argument is held in a temporary. -}
lowerValueCall :: LowerExpression -> LowerState -> Span -> Located Expression -> [Located Expression] -> Lowered
lowerValueCall lower state at callee arguments = case collect state [] arguments of
  (after, Nothing) -> refused after
  (after, Just cores) -> case lower after callee of
    (final, Nothing) -> refused final
    (final, Just (target, kind)) -> case kind of
      _ | any stops (cores <> [target]) -> (final, Just (stopped (cores <> [target]), CoreNeverType))
      CoreFunctionType inputs result
        | length inputs == length cores ->
            let pushed = final{lowerScopes = [] : lowerScopes final}
                (bound, temporaries) = foldl' hold (pushed, []) cores
                popped = bound{lowerScopes = drop 1 (lowerScopes bound)}
                declarations = [CoreStatement (coreExpressionSpan core) (CoreDeclare local core) | (local, core) <- zip temporaries cores]
                temporaryReads = [CoreExpression (coreExpressionSpan core) (coreLocalType local) (CoreReadLocal local) | (local, core) <- zip temporaries cores]
                call = CoreExpression at result (CoreCallValue target temporaryReads)
             in (popped, Just (CoreExpression at result (CoreBlockValue (CoreBlock declarations (Just call))), result))
      _ -> halt at ("a call through a " <> coreTypeName kind <> " value") final
 where
  stops core = coreExpressionType core == CoreNeverType
  stopped cores = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
    [CoreStatement (coreExpressionSpan core) (CoreEvaluate core) | core <- cores] Nothing))
  hold (current, held) core =
    let (next, local) = bindLocal current "" (coreExpressionType core)
     in (next, held <> [local])
  collect current done [] = (current, Just (reverse done))
  collect current done (argument : rest) = case lower current argument of
    (next, Just (core, _))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" next
      | otherwise -> collect next (core : done) rest
    (next, Nothing) -> (next, Nothing)

-- One key, one function: the body a lambda was written in is lowered once
-- per copy, but a key already seen keeps its first lowering.
registered :: Text -> CoreFunction -> CoreClosureInfo -> LowerContext -> LowerContext
registered key lifted info context
  | Map.member key (contextClosures context) = context
  | otherwise = context
      { contextFunctions = lifted : contextFunctions context
      , contextClosures = Map.insert key info (contextClosures context)
      }

siteOf :: Span -> Text
siteOf at = unSourceName (spanSource at) <> ":" <> Text.pack (show (unOffset (spanStart at))) <> "-" <> Text.pack (show (unOffset (spanEnd at)))
