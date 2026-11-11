{-| @Pudu.Compiler.Lower.Lambda — lambdas, functions used as values, and calls
    through a function value. A lambda becomes a lifted function whose first
    parameter is its own closure. -}
module Pudu.Compiler.Lower.Lambda (lowerLambda, lowerTask, lowerFunctionValue, lowerValueCall) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Control (expressionIsPrintValued, printValued)
import Pudu.Compiler.Lower.Default (suppliedArguments)
import Pudu.Compiler.Lower.Generic (admitCallee)
import Pudu.Compiler.Lower.Loan (Callee (..), Operand (..), closeLoaned, lowerLoanedOperands, valueSignature)
import Pudu.Compiler.Lower.State
  ( LowerContext (..), LowerState (..), bindLocal, halt, lookupLocal, refused, startFunction )
import Pudu.Compiler.Lower.Types (loanedInputs, nativeValueType, typeFactAt, typeForSpan)
import Pudu.Core
import Pudu.Eval.Capture (reachableNames)
import Pudu.Frontend.Syntax (Block, Expression, Function (..), FunctionBody (..), Located (..), Parameter (..))
import Pudu.Source (Span (..), spanSource, unOffset, unSourceName)
import Pudu.Type.Value (Type (FunctionTypeRequiring), requiredCount)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type LowerBlock = LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| The closure copies what the lambda mentions from the enclosing locals,
    when the lambda is evaluated, as the evaluator's capture does. Its body is
    lowered as a function of its own, keyed by the body it was written in, so
    each copy of a generic body gets its own lambda. -}
lowerLambda :: LowerExpression -> LowerBlock -> LowerState -> Span -> Function -> Lowered
lowerLambda lower block state at function = case typeForSpan (contextTypes (lowerContext state)) at of
  Just kind -> liftFunction lower block state at kind "<fn>" True function
  Nothing -> halt at "a lambda without a native function type" state

{-| The task an async body is until it is awaited: a function of nothing
    over the names the body mentions, lifted beside the body it was written
    in and shown under the task's name. -}
lowerTask :: LowerExpression -> LowerBlock -> LowerState -> Text -> CoreType -> Function -> Lowered
lowerTask lower block state name kind function = case functionBody function of
  Just (Located at _) ->
    case liftFunction lower block state at kind ("<task " <> name <> ">") False function{functionAsync = False, functionParameters = []} of
      (after, Just (task, made)) ->
        let key = lowerCurrentKey state <> "#" <> Text.pack (show (unOffset (spanStart at)))
            (offered, held) = adopted after at key task
         in (offered, Just (held, made))
      refusal -> refusal
  Nothing -> halt (locatedSpan (functionName function)) "a function without a body" state

{-| A function lifted at a known type. A written lambda may lend `&mut`
    parameters; a task has none. -}
liftFunction :: LowerExpression -> LowerBlock -> LowerState -> Span -> CoreType -> Text -> Bool -> Function -> Lowered
liftFunction lower block state at solved display lends function = case solved of
      kind@(CoreFunctionType inputs result)
        | length inputs == length (functionParameters function) ->
            let key = lowerCurrentKey state <> "#" <> Text.pack (show (unOffset (spanStart at)))
                captured =
                  [ local | name <- Set.toAscList (reachableNames function), Just local <- [lookupLocal state name] ]
                env = CoreLocal 0 "" kind
                parameters =
                  [ CoreParameter (CoreLocal index (locatedValue (parameterName parameter)) input) (locatedSpan (parameterName parameter))
                  | (index, Located _ parameter, input) <- zip3 [1 ..] (functionParameters function) inputs ]
                -- A lambda with `&mut` parameters answers their finals beside
                -- its declared result on every way out.
                loaned = if lends then maybe [] loanedInputs (typeFactAt (contextTypes (lowerContext state)) at) else []
                declared = case result of
                  CoreTupleType (own : _) | not (null loaned) -> own
                  _ -> result
                entered = (startFunction state (CoreParameter env at : parameters) (Just declared)){lowerCurrentKey = key, lowerDeclaredResult = Nothing}
                (withCaptures, prologue) = foldl' capture (entered, []) (zip [0 ..] captured)
                capture (current, done) (index, local) =
                  let (next, inner) = bindLocal current (coreLocalName local) (coreLocalType local)
                      read' = CoreExpression at kind (CoreReadLocal env)
                   in (next, done <> [CoreStatement at (CoreDeclare inner (CoreExpression at (coreLocalType local) (CoreCapture index read')))])
                (afterLowering, loweredBody) = lowered withCaptures{lowerLoaned = [coreParameterLocal parameter | (index, parameter) <- zip [0 ..] parameters, index `elem` loaned]}
                (afterBody, body) = case loweredBody of
                  Just coreBlock | not (null loaned) -> Just <$> closeLoaned afterLowering at coreBlock
                  _ -> (afterLowering, loweredBody)
                lowered current = case functionBody function of
                  -- An async lambda's body is the task it answers.
                  Just _ | functionAsync function -> case lowerTask lower block current "<fn>" result function of
                    (next, Just (core, _)) -> (next, Just (CoreBlock [] (Just core)))
                    (next, Nothing) -> (next, Nothing)
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
                            info = CoreClosureInfo (map coreLocalType captured) display (siteOf at) False True Nothing
                            context = registered key lifted info (lowerContext afterBody)
                            captureReads = [CoreExpression at (coreLocalType local) (CoreReadLocal local) | local <- captured]
                         in (restored context, Just (CoreExpression at kind (CoreClosure key captureReads), kind))
      other -> halt at ("a lambda of type " <> coreTypeName other) state

{-| A task just made, offered to the innermost open scope beside the function
    that joins it: the joiner runs the task and says whether it failed,
    leaving the failure where the scope's function finds it. -}
adopted :: LowerState -> Span -> Text -> CoreExpression -> (LowerState, CoreExpression)
adopted state at key task = case coreExpressionType task of
  kind@(CoreFunctionType [] answered) ->
    let (bound, held) = bindLocal state "" kind
        joinKey = key <> "$join"
        env = CoreLocal 0 "" (CoreFunctionType [] CoreBoolType)
        inner = CoreExpression at kind (CoreCapture 0 (CoreExpression at (CoreFunctionType [] CoreBoolType) (CoreReadLocal env)))
        ran = CoreExpression at answered (CoreCallValue inner [])
        body = case answered of
          CoreSumType "Result" [success, failure] | nativeValueType failure ->
            let value = CoreLocal 1 "" success
                problem = CoreLocal 2 "" failure
                kept = CoreExpression at (CoreTupleType [failure]) (CoreTuple [readLocal at problem])
                failed = CoreExpression at CoreBoolType (CoreBlockValue (CoreBlock [hostEffect at "scope_stash" [kept]] (Just (boolean at True))))
             in CoreBlock [] (Just (CoreExpression at CoreBoolType (CoreMatch ran
                  [ CoreArm at (CoreVariantPattern "Ok" [CoreBindPattern value]) Nothing (boolean at False)
                  , CoreArm at (CoreVariantPattern "Err" [CoreBindPattern problem]) Nothing failed ])))
          _ -> CoreBlock [CoreStatement at (CoreEvaluate ran)] (Just (boolean at False))
        lifted = CoreFunction joinKey [CoreParameter env at] CoreBoolType body
        info = CoreClosureInfo [kind] "<fn>" (siteOf at) False True Nothing
        joiner = CoreExpression at (CoreFunctionType [] CoreBoolType) (CoreClosure joinKey [readLocal at held])
        offered = CoreBlock
          [ CoreStatement at (CoreDeclare held task), hostEffect at "scope_adopt" [readLocal at held, joiner] ]
          (Just (readLocal at held))
     in (bound{lowerContext = registered joinKey lifted info (lowerContext bound)}, CoreExpression at kind (CoreBlockValue offered))
  _ -> (state, task)

hostEffect :: Span -> Text -> [CoreExpression] -> CoreStatement
hostEffect at name operands = CoreStatement at (CoreEvaluate (CoreExpression at CoreBoolType (CoreKernel (KernelHost name) [] operands)))

readLocal :: Span -> CoreLocal -> CoreExpression
readLocal at local = CoreExpression at (coreLocalType local) (CoreReadLocal local)

boolean :: Span -> Bool -> CoreExpression
boolean at value = CoreExpression at CoreBoolType (CoreBoolLiteral value)

{-| Named values keep the target's own parameter ABI and call depth. -}
lowerFunctionValue :: LowerState -> Span -> Text -> (Text, Located Function) -> Lowered
lowerFunctionValue state at key entry = case typeForSpan (contextTypes (lowerContext state)) at of
  Just kind@(CoreFunctionType _ _) -> case admitCallee state key at entry of
    (admitted, Nothing) -> refused admitted
    (admitted, Just (target, _)) ->
      let name = locatedValue (functionName (locatedValue (snd entry)))
          context = lowerContext admitted
          info = CoreClosureInfo [] name ("fn " <> target) False False Nothing
          next = context
            { contextClosures = Map.insert target info (contextClosures context)
            , contextQueue = target : contextQueue context
            }
       in (admitted{lowerContext = next}, Just (CoreExpression at kind (CoreClosure target []), kind))
  _ -> halt at "a function value without a native function type" state

{-| `callee(arguments)` through a value. The arguments run first, then the
    callee, as `evaluateCall` does, so each argument is held in a temporary. -}
lowerValueCall :: LowerExpression -> LowerState -> Span -> Located Expression -> [Located Expression] -> Lowered
lowerValueCall lower state at callee arguments
  | loaned@(_ : _) <- maybe [] loanedInputs (typeFactAt (contextTypes (lowerContext state)) (locatedSpan callee))
  , Just (CoreFunctionType inputs (CoreTupleType (result : _))) <- typeForSpan (contextTypes (lowerContext state)) (locatedSpan callee) =
      lowerLoanedOperands lower state at (Through callee) (valueSignature at inputs result loaned) defaulted
        [(index, Argument, argument) | (index, argument) <- zip [0 ..] arguments]
  | otherwise = case collect state [] arguments of
  (after, Nothing) -> refused after
  (after, Just cores) -> case lower after callee of
    (final, Nothing) -> refused final
    (final, Just (target, kind)) -> case kind of
      _ | any stops (cores <> [target]) -> (final, Just (stopped (cores <> [target]), CoreNeverType))
      CoreFunctionType inputs result
        | defaulted, length cores < length inputs -> call final target result (suppliedArguments at inputs cores)
        | length inputs == length cores -> call final target result cores
      _ -> halt at ("a call through a " <> coreTypeName kind <> " value") final
 where
  -- A value of a function with defaults was formed with the count of supplied
  -- arguments as its last parameter; checking says how many a call must give.
  defaulted = case typeFactAt (contextTypes (lowerContext state)) (locatedSpan callee) of
    Just (FunctionTypeRequiring _ inputs required _) -> requiredCount required < length inputs
    _ -> False
  call final target result cores =
    let pushed = final{lowerScopes = [] : lowerScopes final}
        (bound, temporaries) = foldl' hold (pushed, []) cores
        popped = bound{lowerScopes = drop 1 (lowerScopes bound)}
        declarations = [CoreStatement (coreExpressionSpan core) (CoreDeclare local core) | (local, core) <- zip temporaries cores]
        temporaryReads = [CoreExpression (coreExpressionSpan core) (coreLocalType local) (CoreReadLocal local) | (local, core) <- zip temporaries cores]
        invoked = CoreExpression at result (CoreCallValue target temporaryReads)
     in (popped, Just (CoreExpression at result (CoreBlockValue (CoreBlock declarations (Just invoked))), result))
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
