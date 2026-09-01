{-| @Eval.Call — calling something, reaching a name through a path, and the
    scopes a task is joined in.

    A call's arguments are expressions and an expression may be a call, so what
    this module needs of the evaluator arrives as a record rather than an
    import. -}
module Pudu.Eval.Call
  ( CallNeeds (..)
  , applyFunction
  , awaitTask
  , callClosure
  , evaluateCall
  , evaluateCallee
  , evaluateScope
  , lastPathSegment
  , pathValue
  , readPath
  , runClosure
  , scopeTo
  ) where

import Data.Foldable (toList)
import Data.List (inits)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Builtin
  ( callArrayMethod
  , callCharFromCode
  , callCharMethod
  , callConvertInteger
  , callDecimal
  , callDisplay
  , callEffect
  , callMapMethod
  , callMapOf
  , callPanic
  , callHashing
  , callSetMethod
  , Apply
  , callSetOf
  , callShow
  , callStringMethod
  , isDecimalBuiltin
  )
import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (newEmptyMVar, putMVar)
import Control.Exception (SomeException, try)
import Pudu.Diagnostic (diagnosticMessage)
import Pudu.Eval.Bytes (callBytesMethod, callBytesOf)
import Pudu.Eval.HashMap (callBucketsMethod, callBucketsOf)
import Pudu.Eval.Concurrent (threadRegister)
import Pudu.Eval.Env
  ( tally
  , currentConcurrentStore
  , withCaptured
  , adoptChild
  , closeScope
  , openScope
  , releaseChild
  , Eval (..)
  , Evaluator (..)
  , abortAt
  , effectsAdmitted
  , ascend
  , catchUnwind
  , descend
  , lookupName
  , unwind
  , Unwind (..)
  , withFrame
  )
import Pudu.Eval.Loop
  ( firstBound
  , receiverOwners
  )
import Pudu.Eval.Install (lastSegmentOf)
import Pudu.Eval.Operator (readMember, unwrapTry)
import Pudu.Eval.Render (valueKind)
import Pudu.Eval.Value
  ( Builtin (..)
  , Closure (..)
  , intOf
  , Value (..)
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Expression (..)
  , Function (..)
  , FunctionBody (..)
  , Parameter (..)
  , TypeSyntax (..)
  )
import Pudu.Source (Span)

{-| @Eval.Call.Needs — what a call needs of the evaluator around it.

    An argument is an expression and a function's body is a block. Both reach
    calls again, which is why they arrive rather than being imported. -}
data CallNeeds = CallNeeds
  { callEvaluate :: Located Expression -> Evaluator Value
  , callBlock :: Located Block -> Evaluator Value
  }

{-| A member in callee position prefers a method over a field of the same name,
    matching how the same call is typed: `value.name()` reads as a call, and a
    field holding a function must be parenthesized to be called. -}
evaluateCall :: CallNeeds -> Span -> Located Expression -> [Located Expression] -> Evaluator Value
evaluateCall needs spanValue callee arguments = do
  values <- mapM (callEvaluate needs) arguments
  {-| A type argument is not erased before the call that carries it. Types have
      no run-time form, but the *syntax* the reader wrote is still here, and a
      conversion needs to know which type it was asked for. Reading it is not
      the evaluator knowing about types; it is the evaluator reading the call it
      was given. -}
  case typeArgumentNames (locatedValue callee) of
    Just (names, inner) -> do
      {-| The callee under a type application is read as an ordinary expression
          rather than as a callee, because a qualified name is what carries type
          arguments and reading it as a path is what resolves it. -}
      target <- callEvaluate needs inner
      case target of
        BuiltinValue ConvertIntegerBuiltin -> callConvertInteger spanValue names values
        _ -> dispatchCall needs spanValue target values
    Nothing -> do
      qualified <- qualifiedCallee callee values
      target <- case qualified of
        Just found -> pure found
        Nothing -> evaluateCallee needs callee
      dispatchCall needs spanValue target values

{-| The type arguments a callee carries, and the callee under them. -}

{-| Apply an evaluated callee to evaluated arguments. -}
dispatchCall :: CallNeeds -> Span -> Value -> [Value] -> Evaluator Value
dispatchCall needs spanValue target values =
  case target of
    FunctionValue closure -> callClosure needs closure values (Just spanValue)
    VariantValue name [] -> pure (VariantValue name values)
    BuiltinValue PanicBuiltin -> callPanic spanValue values
    BuiltinValue CharFromCodeBuiltin -> callCharFromCode spanValue values
    BuiltinValue MapOfBuiltin -> callMapOf spanValue values
    BuiltinValue SetOfBuiltin -> callSetOf spanValue values
    BuiltinValue BytesOfBuiltin -> callBytesOf spanValue values
    BuiltinValue BucketsOfBuiltin -> callBucketsOf spanValue values
    BuiltinValue SpawnThreadBuiltin -> callSpawnThread (applyFunction needs) spanValue values
    BuiltinValue hashing
      | isHashingBuiltin hashing -> callHashing spanValue hashing values
    BuiltinValue ShowBuiltin -> callShow spanValue values
    BuiltinValue DisplayBuiltin -> callDisplay spanValue values
    BuiltinValue ConvertIntegerBuiltin -> callConvertInteger spanValue [] values
    BuiltinValue builtin
      | isDecimalBuiltin builtin -> callDecimal spanValue builtin values
    BuiltinValue effect -> callEffect spanValue effect values
    ArrayMethodValue method receiver -> callArrayMethod (applyFunction needs) spanValue method receiver values
    StringMethodValue method receiver -> callStringMethod spanValue method receiver values
    MapMethodValue method receiver -> callMapMethod spanValue method receiver values
    SetMethodValue method receiver -> callSetMethod spanValue method receiver values
    CharMethodValue method receiver -> callCharMethod spanValue method receiver values
    BytesMethodValue method receiver -> callBytesMethod spanValue method receiver values
    BucketsMethodValue method receiver -> callBucketsMethod spanValue method receiver values
    _ -> abortAt (Just spanValue) "E7001" ("cannot call a " <> valueKind target) Nothing

{-| A two-segment path in callee position may select a method explicitly: by the
    type that implements it, as in `Bot.label(bot)`, or by the trait that
    declares it, as in `A.label(bot)`. The trait form dispatches on the first
    argument's type, which is the receiver the method is being called on. -}

{-| Supplied arguments bind left to right; a parameter with no argument uses its
    default, evaluated in the environment the earlier parameters already
    extended. -}
bindArguments :: CallNeeds -> [Located Parameter] -> [Value] -> Maybe Span -> Evaluator [(Text, Value)]
bindArguments needs parameters arguments callSpan = go parameters arguments []
 where
  go [] [] collected = pure (reverse collected)
  go [] (_ : _) collected =
    abortAt callSpan "E7003" "too many arguments in call"
      (Just "pass one argument per declared parameter") >> pure (reverse collected)
  go (Located _ parameter : rest) supplied collected = case supplied of
    value : remaining ->
      go rest remaining ((locatedValue (parameterName parameter), value) : collected)
    [] -> case parameterDefault parameter of
      Just expression -> do
        value <- withFrame (reverse collected) (callEvaluate needs expression)
        go rest [] ((locatedValue (parameterName parameter), value) : collected)
      Nothing -> do
        _ <-
          abortAt callSpan "E7003"
            ("missing argument for parameter " <> locatedValue (parameterName parameter))
            (Just "supply the argument or give the parameter a default")
        pure (reverse collected)

{-| A block evaluates its statements in order and yields its trailing
    expression, or unit when it has none. A control transfer inside it travels
    outward untouched. -}

evaluateCallee :: CallNeeds -> Located Expression -> Evaluator Value
evaluateCallee needs located@(Located calleeSpan expression) = case expression of
  MemberExpression target member -> do
    receiver <- callEvaluate needs target
    owners <- receiverOwners receiver
    method <- firstBound (\owner -> lookupName (owner <> "." <> locatedValue member)) owners
    case method of
      Just (FunctionValue closure) ->
        pure (FunctionValue closure{closureSelf = Just receiver})
      _ -> readMember calleeSpan receiver (locatedValue member)
  _ -> callEvaluate needs located

{-| A two-segment path in callee position may select a method explicitly: by the
    type that implements it, as in `Bot.label(bot)`, or by the trait that
    declares it, as in `A.label(bot)`. The trait form dispatches on the first
    argument's type, which is the receiver the method is being called on. -}
qualifiedCallee :: Located Expression -> [Value] -> Evaluator (Maybe Value)
qualifiedCallee (Located _ expression) values = case qualifiedParts expression of
  Nothing -> pure Nothing
  Just (first, method) -> do
    direct <- lookupName (first <> "." <> method)
    case direct of
      Just found -> pure (Just found)
      Nothing -> case values of
        receiver : _ -> do
          owners <- receiverOwners receiver
          firstBound (\owner -> lookupName (first <> "." <> owner <> "." <> method)) owners
        [] -> pure Nothing

{-| A qualified callee reaches the parser as a member access on a bare name, so
    `A.label` and a two-segment path are the same selection written twice. -}

{-| A qualified callee reaches the parser as a member access on a bare name, so
    `A.label` and a two-segment path are the same selection written twice. -}
qualifiedParts :: Expression -> Maybe (Text, Text)
qualifiedParts expression = case expression of
  NameExpression (first :| [method]) -> Just (first, method)
  MemberExpression (Located _ (NameExpression (first :| []))) member ->
    Just (first, locatedValue member)
  _ -> Nothing

{-| Read a dotted path.

    A path may name a value and then reach into it, or it may name a linked
    module's member: `Std.List.sum` is one binding, while `point.x.y` is three
    reads. The longest resolving prefix decides which, because a module path is
    always fully written and a value's own name never contains a dot — so the
    longer match is the one the reader meant, and preferring it cannot shadow a
    local. -}
readPath :: Span -> NonEmpty Text -> Evaluator Value
readPath spanValue path@(first :| rest) = do
  linked <- longestBinding path
  case linked of
    Just (value, remaining) -> foldMember value remaining
    Nothing -> do
      found <- lookupName first
      base <- case found of
        Just value -> pure value
        Nothing -> abortAt (Just spanValue) "E7001" ("undefined name " <> first) Nothing
      foldMember base rest
 where
  foldMember value segments = case segments of
    [] -> pure value
    segment : remaining -> do
      next <- readMember spanValue value segment
      foldMember next remaining

{-| A member chain read as one dotted name, when every part of it is a plain
    identifier and the whole thing is bound. Anything else is `Nothing`, so an
    ordinary field read is untouched. -}

{-| A member chain read as one dotted name, when every part of it is a plain
    identifier and the whole thing is bound. Anything else is `Nothing`, so an
    ordinary field read is untouched. -}
pathValue :: Expression -> Evaluator (Maybe Value)
pathValue expression = case flattenPath expression of
  Nothing -> pure Nothing
  Just path -> lookupName (Text.intercalate "." path)

{-| The segments of a chain of names and member accesses, or nothing when any
    part of it is a real expression. -}

lastPathSegment :: ModuleName -> Text
lastPathSegment (ModuleName segments) = lastSegmentOf segments

{-| Await starts the retained async body. The tree evaluator has no scheduler,
    but preserving this cold boundary keeps calls and awaits observably ordered. -}
awaitTask :: CallNeeds -> Span -> Value -> Evaluator Value
awaitTask needs spanValue task = case task of
  TaskValue closure bindings callSpan -> do
    releaseChild task
    result <- runClosure needs closure bindings callSpan
    case result of
      VariantValue "Ok" _ -> unwrapTry spanValue result
      VariantValue "Err" _ -> unwrapTry spanValue result
      _ -> pure result
  _ -> abortAt (Just spanValue) "E7008" ("cannot await a " <> valueKind task)
    (Just "await a task returned by an async function")

{-| Apply a predicate function and interpret the result as a boolean. -}
{-| A field written without a value takes the binding with the field's own
    name, exactly as the record pattern's shorthand binds it. -}

{-| Evaluate a structured scope.

    Every task started inside becomes a child of the scope. On normal exit the
    children that were never awaited are joined in the order they started, so no
    task outlives the region that began it and a failure among them is selected
    by position rather than by a race. On a control transfer out of the body the
    children are joined first, which is the cleanup the semantics require before
    the transfer continues. -}
evaluateScope :: CallNeeds -> Span -> Located Block -> Evaluator Value
evaluateScope needs spanValue body = do
  openScope
  outcome <- catchUnwind (callBlock needs body)
  children <- closeScope
  mapM_ (joinChild needs spanValue) children
  case outcome of
    Right value -> pure value
    Left transfer -> unwind transfer

{-| Join one child. A child that already failed propagates its failure, which is
    what keeps a scope from reporting success while a task it owned did not. -}

scopeTo :: [Map Text Value] -> Value -> Value
scopeTo environment value = case value of
  FunctionValue closure
    | closureCaptured closure == Nothing ->
        FunctionValue closure{closureCaptured = Just environment}
  other -> other

{-| The segments of a chain of names and member accesses, or nothing when any
    part of it is a real expression. -}
flattenPath :: Expression -> Maybe [Text]
flattenPath expression = case expression of
  NameExpression names -> Just (toList names)
  MemberExpression (Located _ target) member ->
    (<> [locatedValue member]) <$> flattenPath target
  _ -> Nothing

{-| The longest dotted prefix of a path that is bound, with the segments it did
    not consume. A single segment is not reported here: it is the ordinary case
    and the caller handles it without this search. -}

{-| The longest dotted prefix of a path that is bound, with the segments it did
    not consume. A single segment is not reported here: it is the ordinary case
    and the caller handles it without this search. -}
longestBinding :: NonEmpty Text -> Evaluator (Maybe (Value, [Text]))
longestBinding (first :| rest) = search (reverse (prefixes rest))
 where
  prefixes segments =
    [ (Text.intercalate "." (first : taken), drop (length taken) segments)
    | taken <- drop 1 (inits segments)
    ]

  search [] = pure Nothing
  search ((name, remaining) : shorter) = do
    found <- lookupName name
    case found of
      Just value -> pure (Just (value, remaining))
      Nothing -> search shorter

{-| A member in callee position prefers a method over a field of the same name,
    matching how the same call is typed: `value.name()` reads as a call, and a
    field holding a function must be parenthesized to be called. -}

{-| The type arguments a callee carries, and the callee under them. -}
typeArgumentNames :: Expression -> Maybe ([Text], Located Expression)
typeArgumentNames expression = case expression of
  TypeApplication inner arguments -> Just (map typeArgumentName arguments, inner)
  _ -> Nothing

{-| A written type's name, or empty when it was not a plain nominal one. -}

{-| Start a prepared closure body. Async calls retain these bindings in a cold
    task; ordinary calls enter here immediately. -}
runClosure :: CallNeeds -> Closure -> [(Text, Value)] -> Maybe Span -> Evaluator Value
runClosure needs closure bindings callSpan = do
  let value = closureFunction closure
  deeper <- descend callSpan
  outcome <- withCaptured (closureCaptured closure) $ withFrame bindings $ catchUnwind $ case functionBody value of
    Nothing -> pure UnitValue
    Just (Located _ body) -> case body of
      BlockBody block -> callBlock needs block
      ExpressionBody expression -> callEvaluate needs expression
  ascend deeper
  case outcome of
    Right result -> pure result
    Left (ReturnUnwind result) -> pure result
    Left _ ->
      abortAt callSpan "E7006" "break or continue outside a loop"
        (Just "use break and continue inside while, loop, or for")

{-| Supplied arguments bind left to right; a parameter with no argument uses its
    default, evaluated in the environment the earlier parameters already
    extended. -}

applyFunction :: CallNeeds -> Span -> Value -> [Value] -> Evaluator Value
applyFunction needs spanValue function arguments = case function of
  FunctionValue closure -> callClosure needs closure arguments (Just spanValue)
  ArrayMethodValue method receiver -> callArrayMethod (applyFunction needs) spanValue method receiver arguments
  StringMethodValue method receiver -> callStringMethod spanValue method receiver arguments
  MapMethodValue method receiver -> callMapMethod spanValue method receiver arguments
  SetMethodValue method receiver -> callSetMethod spanValue method receiver arguments
  CharMethodValue method receiver -> callCharMethod spanValue method receiver arguments
  BytesMethodValue method receiver -> callBytesMethod spanValue method receiver arguments
  BucketsMethodValue method receiver -> callBucketsMethod spanValue method receiver arguments
  _ -> abortAt (Just spanValue) "E7001" ("cannot call a " <> valueKind function) Nothing

{-| Evaluate a structured scope.

    Every task started inside becomes a child of the scope. On normal exit the
    children that were never awaited are joined in the order they started, so no
    task outlives the region that began it and a failure among them is selected
    by position rather than by a race. On a control transfer out of the body the
    children are joined first, which is the cleanup the semantics require before
    the transfer continues. -}

{-| Join one child. A child that already failed propagates its failure, which is
    what keeps a scope from reporting success while a task it owned did not. -}
joinChild :: CallNeeds -> Span -> Value -> Evaluator ()
joinChild needs spanValue child = do
  _ <- awaitTask needs spanValue child
  pure ()

{-| Await starts the retained async body. The tree evaluator has no scheduler,
    but preserving this cold boundary keeps calls and awaits observably ordered. -}

{-| A written type's name, or empty when it was not a plain nominal one. -}
typeArgumentName :: Located TypeSyntax -> Text
typeArgumentName located = case locatedValue located of
  NamedType path _ -> moduleNameText path
  _ -> Text.empty

{-| Apply an evaluated callee to evaluated arguments. -}

callClosure :: CallNeeds -> Closure -> [Value] -> Maybe Span -> Evaluator Value
callClosure needs closure arguments callSpan = do
  tally "closure call"
  let value = closureFunction closure
      parameters = functionParameters value
      supplied = maybe arguments (: arguments) (closureSelf closure)
  bindings <- bindArguments needs parameters supplied callSpan
  if functionAsync value
    then do
      let task = TaskValue closure bindings callSpan
      adoptChild task
      pure task
    else runClosure needs closure bindings callSpan

{-| Start a prepared closure body. Async calls retain these bindings in a cold
    task; ordinary calls enter here immediately. -}

{-| Start a thread running a function, and answer the token naming it.

    Dispatched here rather than beside the other effects because starting one
    means calling back into evaluation, and the apply that does it is what this
    module owns. Everything a started thread is afterwards — joining it, and
    what it reports — belongs to [[Eval Concurrent]].

    The thread is given the environment as it stands at the call. That is the
    same environment an ordinary call would run in, and it is safe to share
    because every value in it is immutable: the things two threads can both
    change are the channel, the lock, and the cell, and each of those is a
    token into a table rather than a value.

    A thread that failed reports what it said rather than taking the program
    down with it. A runtime that unwound past a boundary the program cannot see
    would take away the only decision worth having, which is the same rule
    every other effect here follows. -}
callSpawnThread :: Apply -> Span -> [Value] -> Evaluator Value
callSpawnThread apply spanValue arguments = case arguments of
  [action] -> do
    admitted <- effectsAdmitted
    if not admitted
      then
        abortAt (Just spanValue) "E7009" "spawnThread reaches outside the program"
          ( Just
              ( "a compile-time constant is folded while the compiler runs, so it "
                  <> "cannot start a thread"
              )
          )
      else do
        concurrent <- currentConcurrentStore
        Evaluator $ \env -> do
          slot <- newEmptyMVar
          let Evaluator body = apply spanValue action []
          threadId <- forkIO $ do
            outcome <- try (body env) :: IO (Either SomeException (Eval Value))
            putMVar slot (reported outcome)
          token <- threadRegister concurrent threadId slot
          pure (Done (VariantValue "Ok" [intOf (fromIntegral token)]) env)
  _ -> abortAt (Just spanValue) "E7012" "spawnThread expects one function" Nothing
 where
  reported outcome = case outcome of
    Left problem -> Just (Text.pack (show problem))
    Right (Aborted diagnostic) -> Just (diagnosticMessage diagnostic)
    Right _ -> Nothing

{-| Whether a built-in is one of the hashing set, which is dispatched before
    the effects because none of them reaches outside the program: a digest of
    the same bytes is the same digest wherever it is taken, so a constant may
    be folded through one. -}
isHashingBuiltin :: Builtin -> Bool
isHashingBuiltin builtin = case builtin of
  Sha256Builtin -> True
  HmacBuiltin -> True
  DeriveKeyBuiltin -> True
  HashOfBuiltin -> True
  MixHashBuiltin -> True
  _ -> False
