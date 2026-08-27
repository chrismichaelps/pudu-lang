{-| @Eval.Module — evaluates a resolved module -}
module Pudu.Eval
  ( EvalOutcome (..)
  , evaluateEntryPoint
  , evaluateProgramEntry
  , evaluateProgramTallied
  , evaluateModule
  , runWithEffects
  ) where

import Data.Foldable (toList)
import Data.List (inits)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic)
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
  , callSetMethod
  , callSetOf
  , callShow
  , callStringMethod
  , isDecimalBuiltin
  )
import Pudu.Eval.Env
  ( Env (..)
  , effectsAdmitted
  , integerKindAt
  , tally
  , withTally
  , withIntegerKinds
  , variantOwner
  , captureEnvironment
  , currentFrame
  , withCaptured
  , pushFrame
  , replaceFrame
  , Eval (..)
  , adoptChild
  , closeScope
  , openScope
  , releaseChild
  , Evaluator (..)
  , abortAt
  , ascend
  , bind
  , catchUnwind
  , descend
  , emptyEnv
  , expectBool
  , lookupName
  , unwind
  , Unwind (..)
  , update
  , withFrame
  , withNewFrame
  )
import Pudu.Eval.Install (lastSegmentOf, loadDeclarations)
import Pudu.Eval.Match (integerLiteralValue, literalValue, matchPattern)
import Pudu.Eval.Operator (applyUnary, combine, nominalNameOf, readIndex, readMember, unwrapTry)
import Pudu.Eval.Value
  ( Builtin (..)
  , Closure (..)
  , Value (..)
  , renderValue
  , valueKind
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Literal (IntegerValue)
  , Import (..)
  , Block (..)
  , lambdaName
  , FieldInit (..)
  , Declaration (..)
  , Expression (..)
  , Function (..)
  , FunctionBody (..)
  , MatchArm (..)
  , Module (..)
  , Parameter (..)
  , Pattern
  , Statement (..)
  , TypeSyntax (..)
  )
import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import Pudu.Source (Span)

{-| @Eval.Outcome — a value or the diagnostic that stopped evaluation -}
data EvalOutcome = EvalOutcome
  { outcomeValue :: !(Maybe Value)
  , outcomeDiagnostics :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

{-| Evaluate a module and return the value of its entry point. Module constants
    are evaluated in declaration order, so a constant that reads one declared
    later is a runtime diagnostic rather than a silent default. -}
evaluateEntryPoint :: Map.Map Span Text -> Text -> Module -> IO EvalOutcome
evaluateEntryPoint integerKinds = evaluateProgramEntry integerKinds []

{-| Evaluate a module that imports others, with its dependencies linked in.

    Each dependency is loaded in its own frame and its bindings are then
    installed under the module's dotted path, so `Std.List.sum` is a name in the
    environment rather than a member access on a value that does not exist. The
    importing module's own `as` and `{ ... }` forms add aliases to the same
    values; nothing is copied, and no dependency's plain names leak into the
    importer's scope.

    Dependencies arrive in dependency order, so a module's own imports are
    already linked when it loads. -}
{-| Every caller says what inference settled on for each integer literal.

    A literal written without a suffix is not a platform `Int` merely because it
    was written plainly, and only the checker knows what it became. This is an
    argument rather than a default because a caller that forgets it gets a
    program whose declared widths are not enforced, and nothing says so — which
    is what happened to the one caller that was allowed to forget. An empty map
    is a caller saying it has not checked the program, not a caller that failed
    to pass what it had. -}
evaluateProgramEntry
  :: Map.Map Span Text -> [(Text, Module)] -> Text -> Module -> IO EvalOutcome
evaluateProgramEntry integerKinds dependencies entryName moduleValue =
  fst <$> evaluateProgramTallied integerKinds dependencies entryName moduleValue

{-| The same, and what running it cost.

    A program has no machine code to read, so the honest account of what it does
    is what the evaluator did: how many names it looked up, how many closures it
    called, how many expressions of each kind it walked. That is the audit a
    reader optimising this compiler can act on, and it is the layer where the
    costs actually live. -}
evaluateProgramTallied
  :: Map.Map Span Text
  -> [(Text, Module)]
  -> Text
  -> Module
  -> IO (EvalOutcome, Map.Map Text Int)
evaluateProgramTallied integerKinds dependencies entryName moduleValue = do
  counters <- newIORef Map.empty
  outcome <- runCounted (Just counters) $ do
    withIntegerKinds integerKinds
    linkDependencies dependencies
    {-| The root gets a frame of its own so its declarations shadow every
        dependency's rather than sharing a frame with the last one linked. -}
    pushFrame Map.empty
    installImportAliases (moduleImports moduleValue)
    loadDeclarations evaluate (moduleDeclarations moduleValue)
    found <- lookupName entryName
    case found of
      Just (FunctionValue closure) -> do
        result <- callClosure closure [] Nothing
        if functionAsync (closureFunction closure)
          then awaitTask (locatedSpan (functionName (closureFunction closure))) result
          else pure result
      _ -> pure UnitValue
  collected <- readIORef counters
  pure (outcome, collected)

{-| Evaluate a module for its constants alone, with no access to the world.

    This is the compile-time path: [[architecture/SEMANTICS]] makes a
    module-scope `const` a compile-time value, and folding it must not perform
    the effects a run of the program would. -}
{-| A `const` is folded while the compiler runs, so its literals need their
    kinds here for the same reason a program's do: a constant declared `Int8`
    that cannot hold what it computes is a mistake worth naming at compile
    time. -}
evaluateModule :: Map.Map Span Text -> Module -> IO EvalOutcome
evaluateModule integerKinds moduleValue =
  runWithEffects
    False
    ( withIntegerKinds integerKinds
        >> loadDeclarations evaluate (moduleDeclarations moduleValue)
        >> pure UnitValue
    )

{-| Load each dependency in a frame of its own and republish it under its dotted
    path.

    **Each module's functions capture the module they were declared in.** They
    are loaded first, so a sibling is an ordinary name while loading, and then
    rewritten to hold the environment that load produced. Without it every
    module shared one namespace: dependencies are linked onto a single stack, so
    the last one linked shadowed every earlier one *for everybody*, and a
    module's own private helper could be replaced by a later module's export of
    the same name. `Std.Random`'s private `orElse` became `Std.Option.orElse`
    that way, and `below` answered with a function where a number belonged.

    The rewrite ties a knot: the captured environment contains the frame whose
    functions capture it, which is exactly what makes a sibling call work. It is
    built lazily, so nothing forces the frame while it is still being defined.

    The frame stays on the stack as well. Nothing depends on it for correctness
    now that closures carry their own scope, and name resolution has already
    rejected any unqualified use of a name the importer did not import.

    A dependency's private declarations are published under the qualified path
    too. Visibility is resolution's decision and it has already been made: a
    private name is unreachable because no importer can write it, and
    re-deciding it here would put one rule in two places. -}
linkDependencies :: [(Text, Module)] -> Evaluator ()
linkDependencies = mapM_ linkOne
 where
  linkOne (path, dependency) = do
    pushFrame Map.empty
    installImportAliases (moduleImports dependency)
    loadDeclarations evaluate (moduleDeclarations dependency)
    loaded <- currentFrame
    outer <- captureEnvironment
    let scoped = Map.map (scopeTo (scoped : drop 1 outer)) loaded
    replaceFrame scoped
    mapM_ (publish path) (Map.toList scoped)

  publish path (name, value) = bind (path <> "." <> name) value

{-| Give a declared function the environment of the module that declared it.

    Only a function needs it. A constant is already a value, and a closure that
    captured something at the point it was written keeps what it captured — a
    lambda's scope is where it was written, not the module it ended up in. -}
scopeTo :: [Map Text Value] -> Value -> Value
scopeTo environment value = case value of
  FunctionValue closure
    | closureCaptured closure == Nothing ->
        FunctionValue closure{closureCaptured = Just environment}
  other -> other

{-| Bind the names an import makes available without qualification.

    `import M as N` republishes every name of `M` under `N`, and
    `import M { a, b }` republishes just those under their plain names. The
    values are the ones already linked, so an alias and its origin are the same
    binding rather than two copies that could drift. -}
installImportAliases :: [Located Import] -> Evaluator ()
installImportAliases = mapM_ (installOne . locatedValue)
 where
  installOne value = do
    let path = moduleNameText (locatedValue (importModule value))
    case importAlias value of
      Just alias -> republish path (locatedValue alias <> ".")
      Nothing -> pure ()
    mapM_ (selectOne path . locatedValue) (importItems value)

  selectOne path item = do
    found <- lookupName (path <> "." <> item)
    case found of
      Just value -> bind item value
      Nothing -> pure ()

  {-| Rebinding by prefix needs the whole environment, because an alias covers
      every name the module published and the importer never enumerates them. -}
  republish path prefix = Evaluator $ \env -> pure $
    let published =
          [ (prefix <> Text.drop (Text.length path + 1) name, value)
          | frame <- envFrames env
          , (name, value) <- Map.toList frame
          , Text.isPrefixOf (path <> ".") name
          ]
     in case envFrames env of
          current : rest ->
            Done () env{envFrames = Map.union (Map.fromList published) current : rest}
          [] -> Done () env{envFrames = [Map.fromList published]}

{-| A control transfer that reaches the top has left every construct that could
    own it, which the entry point reports as a value of unit rather than losing
    the run. -}
run :: Evaluator Value -> IO EvalOutcome
run = runWithEffects True

{-| Run with the world available and the work counted where a counter is given.
    Passing no counter is the ordinary path and costs one comparison per step. -}
runCounted :: Maybe (IORef (Map.Map Text Int)) -> Evaluator Value -> IO EvalOutcome
runCounted counters (Evaluator action) = do
  outcome <- action emptyEnv{envEffects = True, envTally = counters}
  pure (outcomeOf outcome)

{-| Run an evaluation, choosing whether the program may reach the world.

    Compile-time folding passes `False`: a constant is evaluated while the
    compiler runs, and letting it read a file or print would make compilation
    depend on the world the compiler happened to be in, and would produce output
    nobody asked for. -}
runWithEffects :: Bool -> Evaluator Value -> IO EvalOutcome
runWithEffects effects (Evaluator action) = do
  outcome <- action emptyEnv{envEffects = effects}
  pure (outcomeOf outcome)

{-| What a finished evaluation answers with. A control transfer that reached the
    top is the value it carried; only an abort has nothing to answer. -}
outcomeOf :: Eval Value -> EvalOutcome
outcomeOf outcome = case outcome of
  Done value _ -> EvalOutcome{outcomeValue = Just value, outcomeDiagnostics = []}
  Unwound (ReturnUnwind value) _ ->
    EvalOutcome{outcomeValue = Just value, outcomeDiagnostics = []}
  Unwound _ _ -> EvalOutcome{outcomeValue = Just UnitValue, outcomeDiagnostics = []}
  Aborted stop -> EvalOutcome{outcomeValue = Nothing, outcomeDiagnostics = [stop]}

callClosure :: Closure -> [Value] -> Maybe Span -> Evaluator Value
callClosure closure arguments callSpan = do
  tally "closure call"
  let value = closureFunction closure
      parameters = functionParameters value
      supplied = maybe arguments (: arguments) (closureSelf closure)
  bindings <- bindArguments parameters supplied callSpan
  if functionAsync value
    then do
      let task = TaskValue closure bindings callSpan
      adoptChild task
      pure task
    else runClosure closure bindings callSpan

{-| Start a prepared closure body. Async calls retain these bindings in a cold
    task; ordinary calls enter here immediately. -}
runClosure :: Closure -> [(Text, Value)] -> Maybe Span -> Evaluator Value
runClosure closure bindings callSpan = do
  let value = closureFunction closure
  deeper <- descend callSpan
  outcome <- withCaptured (closureCaptured closure) $ withFrame bindings $ catchUnwind $ case functionBody value of
    Nothing -> pure UnitValue
    Just (Located _ body) -> case body of
      BlockBody block -> evaluateBlock block
      ExpressionBody expression -> evaluate expression
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
bindArguments :: [Located Parameter] -> [Value] -> Maybe Span -> Evaluator [(Text, Value)]
bindArguments parameters arguments callSpan = go parameters arguments []
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
        value <- withFrame (reverse collected) (evaluate expression)
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
evaluateBlock :: Located Block -> Evaluator Value
evaluateBlock (Located _ block) = withNewFrame $ do
  mapM_ evaluateStatement (blockStatements block)
  case blockResult block of
    Nothing -> pure UnitValue
    Just expression -> evaluate expression

evaluateStatement :: Located Statement -> Evaluator ()
evaluateStatement (Located _ statement) = case statement of
  DeclarationStatement (Located _ (BindingDeclaration _ _ name _ value)) -> do
    evaluated <- evaluate value
    bind (locatedValue name) evaluated
  DeclarationStatement _ -> pure ()
  ExpressionStatement expression -> evaluate expression >> pure ()
  ReturnStatement Nothing -> unwind (ReturnUnwind UnitValue)
  ReturnStatement (Just expression) -> do
    value <- evaluate expression
    unwind (ReturnUnwind value)
  BreakStatement label value -> do
    carried <- maybe (pure UnitValue) evaluate value
    unwind (BreakUnwind (fmap locatedValue label) carried)
  ContinueStatement label -> unwind (ContinueUnwind (fmap locatedValue label))
  InvalidStatement -> pure ()

{-| Evaluation is not counted per expression.

    A tally on every node of every program costs more than it reports: measured
    on a quarter-megabyte parse, a bind there took the run from 0.93s to 1.50s,
    and writing it against the environment directly still left it at 1.30s.
    `evaluate` is the hottest function in the evaluator and nothing belongs in
    it that the program did not ask for.

    What is counted is counted where the evaluator already stops: a name lookup,
    which every way of reaching a name goes through, and the constructs that
    already open a block to do their work. Those are the costs worth knowing and
    they are free to take. -}
evaluate :: Located Expression -> Evaluator Value
evaluate = evaluateHere

evaluateHere :: Located Expression -> Evaluator Value
evaluateHere (Located spanValue expression) = case expression of
  {-| A literal is built as the type inference gave it, not as it was spelled.
      A suffix says the kind outright; without one the checker's answer for this
      span is the kind, and only where it has none is the platform integer the
      right default. -}
  LiteralExpression literal -> case literal of
    IntegerValue _ -> do
      selected <- integerKindAt spanValue
      pure (integerLiteralValue selected literal)
    _ -> pure (literalValue literal)
  NameExpression names -> readPath spanValue names
  UnaryExpression operator operand -> evaluate operand >>= applyUnary spanValue operator
  BinaryExpression left operator right -> applyBinary spanValue left operator right
  CallExpression callee arguments -> evaluateCall spanValue callee arguments
  MemberExpression target member -> do
    tally "member"
    {-| A member access on a linked module is a name, not a read: `Std.Char.toUpper`
        is one binding, while `record.field.inner` is two reads. Trying the whole
        chain as a path first is what lets a module's function be passed as a
        value, which is how `mapChars(text, Char.toUpper)` works at all. -}
    linked <- pathValue expression
    case linked of
      Just value -> pure value
      Nothing -> do
        value <- evaluate target
        readMember spanValue value (locatedValue member)
  IndexExpression target index -> do
    tally "index"
    container <- evaluate target
    key <- evaluate index
    readIndex spanValue container key
  TryExpression target -> do
    value <- evaluate target
    unwrapTry spanValue value
  AwaitExpression target -> evaluate target >>= awaitTask spanValue
  TupleExpression members -> case members of
    [] -> pure UnitValue
    _ -> TupleValue <$> mapM evaluate members
  ArrayExpression members -> ArrayValue . Seq.fromList <$> mapM evaluate members
  UnsafeExpression _ body -> evaluateBlock body
  MacroCall _ _ ->
    abortAt (Just spanValue) "E7001" "macro call reached evaluation unexpanded" Nothing
  {-| Types are erased at run time, so a type application evaluates to what it
      was applied to. It exists to tell the checker which instantiation was
      meant, and the checker has already been told by the time this runs. -}
  TypeApplication target _ -> evaluate target
  LambdaExpression value -> do
    {-| A literal captures the environment it was written in, so calling it
        later means what it meant then. A declaration does not, and the two
        cases are distinguished by this field rather than by asking what kind
        of function it is. -}
    captured <- captureEnvironment
    pure (FunctionValue (Closure lambdaName value Nothing (Just captured)))
  ScopeExpression body -> evaluateScope spanValue body
  RecordExpression path fields -> do
    values <- mapM (evaluateFieldInit spanValue) fields
    pure (RecordValue (lastPathSegment path) values)
  BlockExpression block -> evaluateBlock block
  IfExpression condition thenBlock elseBranch -> do
    test <- evaluate condition
    truth <- expectBool spanValue test
    if truth
      then evaluateBlock thenBlock
      else case elseBranch of
        Nothing -> pure UnitValue
        Just branch -> evaluate branch
  MatchExpression scrutinee arms -> do
    subject <- evaluate scrutinee
    evaluateArms spanValue subject arms
  WhileExpression label condition body ->
    evaluateWhile spanValue (fmap locatedValue label) condition body
  LoopExpression label body -> evaluateLoop spanValue (fmap locatedValue label) body
  ForExpression label binder iterated body -> do
    sequence' <- evaluate iterated
    evaluateFor spanValue (fmap locatedValue label) binder sequence' body
  InvalidExpression -> abortAt (Just spanValue) "E7001" "cannot evaluate invalid syntax" Nothing

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
pathValue :: Expression -> Evaluator (Maybe Value)
pathValue expression = case flattenPath expression of
  Nothing -> pure Nothing
  Just path -> lookupName (Text.intercalate "." path)

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
evaluateCall :: Span -> Located Expression -> [Located Expression] -> Evaluator Value
evaluateCall spanValue callee arguments = do
  values <- mapM evaluate arguments
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
      target <- evaluate inner
      case target of
        BuiltinValue ConvertIntegerBuiltin -> callConvertInteger spanValue names values
        _ -> dispatchCall spanValue target values
    Nothing -> do
      qualified <- qualifiedCallee callee values
      target <- case qualified of
        Just found -> pure found
        Nothing -> evaluateCallee callee
      dispatchCall spanValue target values

{-| The type arguments a callee carries, and the callee under them. -}
typeArgumentNames :: Expression -> Maybe ([Text], Located Expression)
typeArgumentNames expression = case expression of
  TypeApplication inner arguments -> Just (map typeArgumentName arguments, inner)
  _ -> Nothing

{-| A written type's name, or empty when it was not a plain nominal one. -}
typeArgumentName :: Located TypeSyntax -> Text
typeArgumentName located = case locatedValue located of
  NamedType path _ -> moduleNameText path
  _ -> Text.empty

{-| Apply an evaluated callee to evaluated arguments. -}
dispatchCall :: Span -> Value -> [Value] -> Evaluator Value
dispatchCall spanValue target values =
  case target of
    FunctionValue closure -> callClosure closure values (Just spanValue)
    VariantValue name [] -> pure (VariantValue name values)
    BuiltinValue PanicBuiltin -> callPanic spanValue values
    BuiltinValue CharFromCodeBuiltin -> callCharFromCode spanValue values
    BuiltinValue MapOfBuiltin -> callMapOf spanValue values
    BuiltinValue SetOfBuiltin -> callSetOf spanValue values
    BuiltinValue ShowBuiltin -> callShow spanValue values
    BuiltinValue DisplayBuiltin -> callDisplay spanValue values
    BuiltinValue ConvertIntegerBuiltin -> callConvertInteger spanValue [] values
    BuiltinValue builtin
      | isDecimalBuiltin builtin -> callDecimal spanValue builtin values
    BuiltinValue effect -> callEffect spanValue effect values
    ArrayMethodValue method receiver -> callArrayMethod applyFunction spanValue method receiver values
    StringMethodValue method receiver -> callStringMethod spanValue method receiver values
    MapMethodValue method receiver -> callMapMethod spanValue method receiver values
    SetMethodValue method receiver -> callSetMethod spanValue method receiver values
    CharMethodValue method receiver -> callCharMethod spanValue method receiver values
    _ -> abortAt (Just spanValue) "E7001" ("cannot call a " <> valueKind target) Nothing

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
qualifiedParts :: Expression -> Maybe (Text, Text)
qualifiedParts expression = case expression of
  NameExpression (first :| [method]) -> Just (first, method)
  MemberExpression (Located _ (NameExpression (first :| []))) member ->
    Just (first, locatedValue member)
  _ -> Nothing

{-| The names a receiver may have its methods written under.

    A value names the variant it is, and an implementation is written for the
    type that declares the variant, so a `Circle` finds `impl Shaped for Round`
    only by asking what `Circle` belongs to. The variant's own name comes first
    because a record type is its own owner and must not be looked past. -}
receiverOwners :: Value -> Evaluator [Text]
receiverOwners value = case receiverOwner value of
  Nothing -> pure []
  Just owner -> do
    declaring <- variantOwner owner
    pure (owner : maybe [] pure declaring)

{-| The first of these names that binds something. -}
firstBound :: (Text -> Evaluator (Maybe a)) -> [Text] -> Evaluator (Maybe a)
firstBound look names = case names of
  [] -> pure Nothing
  name : rest -> do
    found <- look name
    case found of
      Just value -> pure (Just value)
      Nothing -> firstBound look rest

{-| The nominal name a runtime value carries, which is how a trait-qualified
    call finds the implementation for the receiver it was given. -}
receiverOwner :: Value -> Maybe Text
receiverOwner value = case value of
  RecordValue owner _ -> Just owner
  VariantValue owner _ -> Just owner
  _ -> nominalNameOf value

{-| Call a value as a function, whether it is a closure or an array method
    value. This is used by `map`, `filter`, and `reduce` to invoke the
    callback. -}
applyFunction :: Span -> Value -> [Value] -> Evaluator Value
applyFunction spanValue function arguments = case function of
  FunctionValue closure -> callClosure closure arguments (Just spanValue)
  ArrayMethodValue method receiver -> callArrayMethod applyFunction spanValue method receiver arguments
  StringMethodValue method receiver -> callStringMethod spanValue method receiver arguments
  MapMethodValue method receiver -> callMapMethod spanValue method receiver arguments
  SetMethodValue method receiver -> callSetMethod spanValue method receiver arguments
  CharMethodValue method receiver -> callCharMethod spanValue method receiver arguments
  _ -> abortAt (Just spanValue) "E7001" ("cannot call a " <> valueKind function) Nothing

{-| Evaluate a structured scope.

    Every task started inside becomes a child of the scope. On normal exit the
    children that were never awaited are joined in the order they started, so no
    task outlives the region that began it and a failure among them is selected
    by position rather than by a race. On a control transfer out of the body the
    children are joined first, which is the cleanup the semantics require before
    the transfer continues. -}
evaluateScope :: Span -> Located Block -> Evaluator Value
evaluateScope spanValue body = do
  openScope
  outcome <- catchUnwind (evaluateBlock body)
  children <- closeScope
  mapM_ (joinChild spanValue) children
  case outcome of
    Right value -> pure value
    Left transfer -> unwind transfer

{-| Join one child. A child that already failed propagates its failure, which is
    what keeps a scope from reporting success while a task it owned did not. -}
joinChild :: Span -> Value -> Evaluator ()
joinChild spanValue child = do
  _ <- awaitTask spanValue child
  pure ()

{-| Await starts the retained async body. The tree evaluator has no scheduler,
    but preserving this cold boundary keeps calls and awaits observably ordered. -}
awaitTask :: Span -> Value -> Evaluator Value
awaitTask spanValue task = case task of
  TaskValue closure bindings callSpan -> do
    releaseChild task
    result <- runClosure closure bindings callSpan
    case result of
      VariantValue "Ok" _ -> unwrapTry spanValue result
      VariantValue "Err" _ -> unwrapTry spanValue result
      _ -> pure result
  _ -> abortAt (Just spanValue) "E7008" ("cannot await a " <> valueKind task)
    (Just "await a task returned by an async function")

{-| Apply a predicate function and interpret the result as a boolean. -}
{-| A field written without a value takes the binding with the field's own
    name, exactly as the record pattern's shorthand binds it. -}
evaluateFieldInit :: Span -> Located FieldInit -> Evaluator (Text, Value)
evaluateFieldInit recordSpan (Located _ field) = do
  let name = locatedValue (fieldInitName field)
  value <- case fieldInitValue field of
    Just expression -> evaluate expression
    Nothing -> do
      found <- lookupName name
      case found of
        Just existing -> pure existing
        Nothing -> abortAt (Just recordSpan) "E7001" ("undefined name " <> name) Nothing
  pure (name, value)

lastPathSegment :: ModuleName -> Text
lastPathSegment (ModuleName segments) = lastSegmentOf segments


evaluateCallee :: Located Expression -> Evaluator Value
evaluateCallee located@(Located calleeSpan expression) = case expression of
  MemberExpression target member -> do
    receiver <- evaluate target
    owners <- receiverOwners receiver
    method <- firstBound (\owner -> lookupName (owner <> "." <> locatedValue member)) owners
    case method of
      Just (FunctionValue closure) ->
        pure (FunctionValue closure{closureSelf = Just receiver})
      _ -> readMember calleeSpan receiver (locatedValue member)
  _ -> evaluate located

evaluateArms :: Span -> Value -> [Located MatchArm] -> Evaluator Value
evaluateArms spanValue subject arms = case arms of
  [] ->
    abortAt (Just spanValue) "E7011" ("no match arm accepted " <> renderValue subject)
      (Just "add a case that covers this value")
  Located _ arm : rest -> case matchPattern (armPattern arm) subject of
    Nothing -> evaluateArms spanValue subject rest
    Just bindings -> do
      guarded <- withFrame bindings (evaluateGuard (armGuard arm))
      if guarded
        then withFrame bindings (evaluate (armBody arm))
        else evaluateArms spanValue subject rest

evaluateGuard :: Maybe (Located Expression) -> Evaluator Bool
evaluateGuard guard = case guard of
  Nothing -> pure True
  Just expression -> do
    value <- evaluate expression
    case value of
      BoolValue flag -> pure flag
      _ -> pure False

evaluateWhile :: Span -> Maybe Text -> Located Expression -> Located Block -> Evaluator Value
evaluateWhile spanValue label condition body = loop (0 :: Int)
 where
  loop iterations = do
    stop <- exceededStepLimit iterations
    if stop
      then
        abortAt (Just spanValue) "E7002" "loop exceeded the evaluation step limit"
          (Just "a constant is folded while the compiler runs; restructure the loop")
      else do
        test <- evaluate condition
        truth <- expectBool spanValue test
        if not truth
          then pure UnitValue
          else do
            outcome <- catchUnwind (evaluateBlock body)
            case transferFor label outcome of
              Stop _ -> pure UnitValue
              Again -> loop (iterations + 1)
              Escape transfer -> unwind transfer
              Finished -> loop (iterations + 1)

evaluateLoop :: Span -> Maybe Text -> Located Block -> Evaluator Value
evaluateLoop spanValue label body = loop (0 :: Int)
 where
  loop iterations = do
    stop <- exceededStepLimit iterations
    if stop
      then
        abortAt (Just spanValue) "E7002" "loop exceeded the evaluation step limit"
          (Just "a constant is folded while the compiler runs; add a break")
      else do
        outcome <- catchUnwind (evaluateBlock body)
        case transferFor label outcome of
          Stop carried -> pure carried
          Again -> loop (iterations + 1)
          Escape transfer -> unwind transfer
          Finished -> loop (iterations + 1)

{-| Iterate a value.

    The shapes the evaluator can enumerate directly — arrays, tuples, strings,
    a variant's payload — are walked as a list. Anything else is asked whether
    it is a sequence: a type carrying `begin` and `advance` produces its items
    one at a time, which is how a user type becomes iterable without the
    evaluator knowing anything about it.

    The protocol passes state rather than mutating it. `begin` answers the
    state to start from and `advance` answers the next item and the state after
    it, so an iterator is an ordinary value in a language whose values are
    ordinary. -}
evaluateFor :: Span -> Maybe Text -> Located Pattern -> Value -> Located Block -> Evaluator Value
evaluateFor spanValue label binder iterated body = case elements of
  Just values -> step values
  Nothing -> do
    sequenced <- sequenceMethods iterated
    case sequenced of
      Just (begin, advance) -> do
        start <- callClosureValue spanValue begin [iterated]
        walk advance start (0 :: Int)
      {-| Only once nothing implements the protocol does a sum fall back to the
          payload its matched variant carries. The checker decides the binder's
          type in exactly this order, and taking the payload first made the two
          disagree: a program with its own `Sequence` type checked against the
          implementation and then ran against the payload. -}
      Nothing -> case variantElements of
        Just values -> step values
        Nothing ->
          abortAt (Just spanValue) "E7001"
            ("cannot iterate a " <> valueKind iterated)
            ( Just
                ( "implement Std.Iter.Sequence for it, which is begin and advance, "
                    <> "or convert it to an array first"
                )
            )
 where
  {-| Walk a sequence one item at a time, threading the state each `advance`
      answers with. The step limit is the loop's, because a sequence that never
      ends is a loop that never ends. -}
  walk advance state iterations = do
    stop <- exceededStepLimit iterations
    if stop
      then
        abortAt (Just spanValue) "E7002" "loop exceeded the evaluation step limit"
          (Just "a constant is folded while the compiler runs; end the sequence or break")
      else do
        stepped <- callClosureValue spanValue advance [iterated, state]
        case stepped of
          VariantValue "None" _ -> pure UnitValue
          VariantValue "Some" [TupleValue [nextState, item]] ->
            case matchPattern binder item of
              Nothing -> walk advance nextState (iterations + 1)
              Just bindings -> do
                outcome <- withFrame bindings (catchUnwind (evaluateBlock body))
                case transferFor label outcome of
                  Stop _ -> pure UnitValue
                  Again -> walk advance nextState (iterations + 1)
                  Escape transfer -> unwind transfer
                  Finished -> walk advance nextState (iterations + 1)
          other ->
            abortAt (Just spanValue) "E7001"
              ("advance must answer Option[(State, Item)], not a " <> valueKind other)
              Nothing

  elements = case iterated of
    TupleValue members -> Just members
    ArrayValue members -> Just (toList members)
    StrValue text -> Just (map CharValue (Text.unpack text))
    _ -> Nothing

  variantElements = case iterated of
    VariantValue _ payload -> Just payload
    _ -> Nothing
  step values = case values of
    [] -> pure UnitValue
    value : rest -> case matchPattern binder value of
      Nothing -> step rest
      Just bindings -> do
        outcome <- withFrame bindings (catchUnwind (evaluateBlock body))
        case transferFor label outcome of
          Stop _ -> pure UnitValue
          Again -> step rest
          Escape transfer -> unwind transfer
          Finished -> step rest

{-| The `begin` and `advance` a value's own type provides, when it provides
    both. A type with only one of them is not a sequence, and saying so here
    keeps the failure at the `for` rather than inside it. -}
sequenceMethods :: Value -> Evaluator (Maybe (Value, Value))
sequenceMethods value = receiverOwners value >>= firstBound methodsUnder
 where
  methodsUnder owner = do
    begin <- lookupName (owner <> ".begin")
    advance <- lookupName (owner <> ".advance")
    pure ((,) <$> begin <*> advance)

{-| Apply a method value the evaluator found by name. -}
callClosureValue :: Span -> Value -> [Value] -> Evaluator Value
callClosureValue spanValue callee arguments = case callee of
  FunctionValue closure -> callClosure closure arguments (Just spanValue)
  other ->
    abortAt (Just spanValue) "E7001"
      ("a sequence method must be a function, not a " <> valueKind other) Nothing

{-| @Eval.LoopTransfer — what a loop body's outcome means to the loop. -}
data LoopTransfer
  = Stop !Value
  | Again
  | Escape !Unwind
  | Finished

{-| Read a loop body's outcome as this loop's own business or someone else's.

    A break or a continue belongs to this loop when it named this loop's label,
    or when it named nothing at all and so meant the innermost — which, from
    inside the body, is this one. Anything else is addressed to a loop further
    out and travels on untouched, which is what makes `break @outer` from a
    nested loop leave the outer one rather than the nearest. -}
transferFor :: Maybe Text -> Either Unwind a -> LoopTransfer
transferFor label outcome = case outcome of
  Right _ -> Finished
  Left transfer -> case transfer of
    BreakUnwind target carried
      | addressed target -> Stop carried
    ContinueUnwind target
      | addressed target -> Again
    other -> Escape other
 where
  addressed target = case target of
    Nothing -> True
    Just name -> label == Just name

{-| Whether a loop that has run this long should be stopped.

    The compiler must terminate; a program need not. A `const` initialiser runs
    while the compiler runs, so a loop that never ends there is a build that
    never ends, and bounding it is what keeps one from happening. A program the
    reader asked to run is bounded by the machine, exactly as it would be in any
    other language — stopping it at a fixed count is not a safety property, it
    is a language that cannot read a file, because a file of any size needs more
    steps than any constant this module could pick.

    The two are told apart by whether effects are admitted, which is already how
    the language distinguishes compile-time evaluation from running. -}
exceededStepLimit :: Int -> Evaluator Bool
exceededStepLimit iterations
  | iterations <= iterationLimit = pure False
  | otherwise = not <$> effectsAdmitted

iterationLimit :: Int
iterationLimit = 100000

{-| Assignment writes to an existing binding; `&&` and `||` short-circuit; every
    other operator evaluates both operands left to right. -}
applyBinary :: Span -> Located Expression -> Text -> Located Expression -> Evaluator Value
applyBinary spanValue left operator right = case operator of
  "=" -> do
    value <- evaluate right
    assign spanValue left value
  "&&" -> do
    leftValue <- evaluate left
    truth <- expectBool spanValue leftValue
    if not truth then pure (BoolValue False) else evaluate right >>= expectBoolValue spanValue
  "||" -> do
    leftValue <- evaluate left
    truth <- expectBool spanValue leftValue
    if truth then pure (BoolValue True) else evaluate right >>= expectBoolValue spanValue
  _ -> do
    leftValue <- evaluate left
    rightValue <- evaluate right
    combine spanValue operator leftValue rightValue

expectBoolValue :: Span -> Value -> Evaluator Value
expectBoolValue spanValue value = BoolValue <$> expectBool spanValue value

assign :: Span -> Located Expression -> Value -> Evaluator Value
assign spanValue target value = case locatedValue target of
  NameExpression (name :| []) -> do
    existing <- lookupName name
    case existing of
      Nothing -> abortAt (Just spanValue) "E7001" ("undefined name " <> name) Nothing
      Just _ -> update name value >> pure UnitValue
  _ -> abortAt (Just spanValue) "E7001" "assignment target is not a place" Nothing
