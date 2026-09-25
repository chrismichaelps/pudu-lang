{-| @Eval.Program — running a program, and linking what it depends on.

    This is the surface a caller reaches: an entry point, a module folded for
    its constants, and the linking that puts a dependency's declarations where
    the program can see them.

    It depends on the evaluator rather than the other way round, so nothing here
    needs a capability. The recursion the rest of the evaluator carries does not
    reach out this far: a program is run once, and running it never asks to run
    another. -}
module Pudu.Eval.Program
  ( evaluateEntryPoint
  , evaluateModule
  , evaluateInteractiveBlock
  , evaluateProgramEntry
  , evaluateProgramEntryFolded
  , evaluateProgramTallied
  , evaluateProgramTalliedFolded
  , foldModule
  , linkedNames
  ) where

import Control.Monad (unless)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Env
  ( Env (..)
  , withIntegerKinds
  , captureEnvironment
  , currentFrame
  , currentMethods
  , markModuleScope
  , pushFrame
  , replaceFrame
  , replaceMethods
  , Eval (..)
  , Evaluator (..)
  , bind
  , abortAt
  , lookupName
  )
import Pudu.Eval.Frozen (Frozen, freeze, thaw)
import Pudu.Eval.Install
  ( installBuiltinConstructors
  , loadDeclarations
  , loadModuleDeclarations
  , loadModuleDeclarationsWith
  )
import Pudu.Eval.Value
  ( Closure (..)
  , Value (..)
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameText, moduleQualifier)
import Pudu.Frontend.Syntax.Tree
  ( Block
  , Declaration (..)
  , Import (..)
  , Function (..)
  , Module (..)
  )
import Data.IORef (newIORef, readIORef, writeIORef)
import Pudu.Source (Span)
import Pudu.Eval
  ( EvalOutcome (..)
  , awaitTask
  , callClosure
  , evaluate
  , evaluateBlockInFrame
  , runCounted
  , runWithEffects
  , scopeTo
  )

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
evaluateProgramEntry = evaluateProgramEntryFolded Map.empty

{-| Run a program, binding the constants folding already computed — by module
    path, then name — rather than evaluating their initializers again. -}
evaluateProgramEntryFolded
  :: Map.Map Text (Map.Map Text Frozen)
  -> Map.Map Span Text
  -> [(Text, Module)]
  -> Text
  -> Module
  -> IO EvalOutcome
evaluateProgramEntryFolded folded integerKinds dependencies entryName moduleValue =
  runCounted Nothing (programEntry folded integerKinds dependencies entryName moduleValue)

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
evaluateProgramTallied = evaluateProgramTalliedFolded Map.empty

evaluateProgramTalliedFolded
  :: Map.Map Text (Map.Map Text Frozen)
  -> Map.Map Span Text
  -> [(Text, Module)]
  -> Text
  -> Module
  -> IO (EvalOutcome, Map.Map Text Int)
evaluateProgramTalliedFolded folded integerKinds dependencies entryName moduleValue = do
  counters <- newIORef Map.empty
  outcome <- runCounted (Just counters) (programEntry folded integerKinds dependencies entryName moduleValue)
  collected <- readIORef counters
  pure (outcome, collected)

{-| Link the program and call its entry point.

    One action serves both entries, so an ordinary run and a tallied one cannot
    drift apart in what they link, in which order, or in how an asynchronous
    entry is awaited. Only the tallied entry allocates counters; an ordinary
    run passes none, and every tally site costs it one comparison. -}
programEntry
  :: Map.Map Text (Map.Map Text Frozen)
  -> Map.Map Span Text
  -> [(Text, Module)]
  -> Text
  -> Module
  -> Evaluator Value
programEntry folded integerKinds dependencies entryName moduleValue = do
  withIntegerKinds integerKinds
  builtins <- linkDependenciesFolded folded dependencies
  pushFrame builtins
  {-| The root gets a frame of its own so its declarations shadow every
      dependency's rather than sharing a frame with the last one linked. -}
  pushFrame Map.empty
  installImportAliases (moduleImports moduleValue)
  inherited <- currentMethods
  loadModuleDeclarationsWith evaluate
    (foldedFor folded (moduleNameText (locatedValue (moduleName moduleValue))))
    (moduleDeclarations moduleValue)
  {-| The root's own functions are given its environment, exactly as a
      dependency's are.

      Without this a function the root declared worked when the root called
      it and failed when anything else did: a declaration carries no captured
      environment, so it runs in the frame of whoever called it, and a module
      that was handed one has no reason to hold the root's imports. Passing a
      named function to `List.map`, to a route table, or to anything else
      that calls back reported the function's own imports as undefined —
      at run time, having type-checked. -}
  scopeRootDeclarations inherited
  {-| Every frame now on the stack is the program's own. What a call pushes
      above this line holds only names somebody wrote, which is what lets a
      function literal capture the ones it mentions instead of all of them. -}
  markModuleScope
  found <- lookupName entryName
  case found of
    Just (FunctionValue closure) -> do
      result <- callClosure closure [] Nothing
      if functionAsync (closureFunction closure)
        then awaitTask (locatedSpan (functionName (closureFunction closure))) result
        else pure result
    _ -> pure UnitValue

{-| Rebuild declarations below the live local frame without replaying its source.
    Captured values keep their old scopes and literal-kind entries. -}
evaluateInteractiveBlock
  :: Bool -> Map.Map Span Text -> [(Text, Module)] -> Module -> Located Block -> Evaluator Value
evaluateInteractiveBlock reuseDeclarations integerKinds dependencies moduleValue block = do
  Evaluator $ \env -> pure (Done () env
    { envIntegerKinds = Map.union integerKinds (envIntegerKinds env) })
  unless reuseDeclarations $ do
    locals <- currentFrame
    Evaluator $ \env -> pure (Done () env
      { envFrames = [Map.empty], envMethods = Map.empty, envVariantOwners = Map.empty })
    builtins <- linkDependencies dependencies
    pushFrame builtins
    pushFrame Map.empty
    installImportAliases (moduleImports moduleValue)
    inherited <- currentMethods
    loadModuleDeclarations evaluate (moduleDeclarations moduleValue)
    scopeRootDeclarations inherited
    markModuleScope
    pushFrame locals
  let Evaluator execute = evaluateBlockInFrame block
  Evaluator $ \env -> do
    result <- execute env
    case result of
      Unwound _ _ ->
        let Evaluator reject = abortAt (Just (locatedSpan block)) "E7001"
              "an interactive entry must finish without returning, breaking or continuing its outer frame"
              (Just "put early-return control flow inside a named function")
         in reject env
      _ -> pure result

{-| Evaluate a module for its constants alone, with no access to the world.

    This is the compile-time path: [[architecture/SEMANTICS]] makes a
    module-scope `const` a compile-time value, and folding it must not perform
    the effects a run of the program would. -}
{-| A `const` is folded while the compiler runs, so its literals need their
    kinds here for the same reason a program's do: a constant declared `Int8`
    that cannot hold what it computes is a mistake worth naming at compile
    time. -}
evaluateModule :: Map.Map Span Text -> Module -> IO EvalOutcome
evaluateModule integerKinds moduleValue = fst <$> foldModule integerKinds moduleValue

{-| Fold a module's constants: evaluate them with effects denied, and answer
    with what went wrong and with every constant whose value is plain data.

    Folding runs the module alone, with nothing but the language in scope, so a
    constant that compiles is one whose value is fixed by its own module; the
    values answered are what linking would compute, and linking installs them
    instead of computing them again. -}
foldModule :: Map.Map Span Text -> Module -> IO (EvalOutcome, Map.Map Text Frozen)
foldModule integerKinds moduleValue = do
  found <- newIORef Map.empty
  outcome <- runWithEffects False $ do
    withIntegerKinds integerKinds
    loadDeclarations evaluate (moduleDeclarations moduleValue)
    frame <- currentFrame
    Evaluator $ \env -> do
      writeIORef found (Map.mapMaybe freeze (Map.restrictKeys frame constants))
      pure (Done () env)
    pure UnitValue
  folded <- readIORef found
  pure (outcome, if null (outcomeDiagnostics outcome) then folded else Map.empty)
 where
  constants = Set.fromList
    [ locatedValue name
    | Located _ (BindingDeclaration _ _ name _ _) <- moduleDeclarations moduleValue
    ]

foldedFor :: Map.Map Text (Map.Map Text Frozen) -> Text -> Map.Map Text Value
foldedFor folded path = maybe Map.empty (Map.map thaw) (Map.lookup path folded)

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
{-| Give every function the root declared the root's own environment.

    The same treatment `linkDependencies` gives a dependency, for the module
    that has no one to link it. -}
scopeRootDeclarations :: Map.Map Text Value -> Evaluator ()
scopeRootDeclarations inherited = do
  loaded <- currentFrame
  outer <- captureEnvironment
  let scoped = Map.map (scopeTo (scoped : drop 1 outer)) loaded
  replaceFrame scoped
  scopeMethodsDeclaredBy inherited (scoped : drop 1 outer)

{-| Give the methods a module declared the environment that module was loaded in.

    An implementation is global — a fact about a type and a trait, reachable from
    every module in the program — but its *body* belongs to the module that wrote
    it, exactly as a plain function's does. Without this a method ran in the
    frame of whoever called it: a bare call in an impl found the caller's
    namespace, so a module's own private helper was replaced by a later module's
    export of the same name. `Std.App.Metrics`'s private seven-parameter
    `declaring` became `Std.App.Config.declaring`, which takes one, and the
    program aborted on the arity of a call the checker had read correctly.

    This is the same rewrite `scopeTo` performs on a module's frame, applied to
    the methods that module added. Which those are is the difference between the
    implementations the program had before it loaded and the ones it has after:
    keeping impls out of the frame stack is what lets a library dispatch to a
    program's own type, so they cannot simply be scoped along with the frame. -}
scopeMethodsDeclaredBy :: Map.Map Text Value -> [Map.Map Text Value] -> Evaluator ()
scopeMethodsDeclaredBy before environment = do
  after <- currentMethods
  let declaredHere = Map.map (scopeTo environment) (Map.difference after before)
  replaceMethods (Map.union declaredHere after)

{-| Every name linking a program's dependencies binds, in no particular order.

    What linking costs grows with this list, and the program never sees most of
    it, so it is the measure a test holds linking to. -}
linkedNames :: [(Text, Module)] -> IO [Text]
linkedNames dependencies = do
  found <- newIORef []
  _ <- runWithEffects False $ do
    _ <- linkDependencies dependencies
    frames <- captureEnvironment
    Evaluator $ \env -> do
      writeIORef found (concatMap Map.keys frames)
      pure (Done () env)
    pure UnitValue
  readIORef found

{-| Link every dependency, in dependency order, and leave the program's frames
    as the published names over whatever lay beneath.

    Each module is linked in an environment of its own: its declarations, the
    names its imports bind, the language's builtins, and the published names of
    the modules linked before it — every one of them under its canonical path,
    in one frame that is the registry of what has been linked. A module's
    functions are scoped to exactly that, so a name looked up inside one walks
    five frames however large the program is. When every module's frames stayed
    on the stack, a lookup that missed walked three frames for every module
    linked before, and a field access misses once on every evaluation, while the
    longest dotted prefix is tried. Publishing is one insertion per declaration,
    and an import reads the registry by its path rather than every frame. -}
linkDependencies :: [(Text, Module)] -> Evaluator (Map.Map Text Value)
linkDependencies = linkDependenciesFolded Map.empty

linkDependenciesFolded :: Map.Map Text (Map.Map Text Frozen) -> [(Text, Module)] -> Evaluator (Map.Map Text Value)
linkDependenciesFolded folded dependencies = do
  pushFrame Map.empty
  installBuiltinConstructors
  builtins <- currentFrame
  beneath <- drop 1 <$> captureEnvironment
  published <- foldLinks builtins beneath Map.empty dependencies
  setFrames (published : beneath)
  pure builtins
 where
  foldLinks _ _ published [] = pure published
  foldLinks builtins beneath published (dependency : rest) = do
    linked <- linkOne builtins beneath published dependency
    foldLinks builtins beneath linked rest

  linkOne builtins beneath published (path, dependency) = do
    setFrames (Map.empty : builtins : published : beneath)
    installImportAliases (moduleImports dependency)
    {-| The module's own declarations get a frame above its imports, so what is
        published under its path is what it declared. Publishing the whole frame
        also published every alias the module imported, and each importer
        republished those under its own alias in turn: the names grew with the
        depth of the import graph, and a site of sixty modules linked millions
        of them before its first request. -}
    pushFrame Map.empty
    inherited <- currentMethods
    loadModuleDeclarationsWith evaluate (foldedFor folded path) (moduleDeclarations dependency)
    loaded <- currentFrame
    outer <- captureEnvironment
    let scoped = Map.map (scopeTo (scoped : drop 1 outer)) loaded
    replaceFrame scoped
    scopeMethodsDeclaredBy inherited (scoped : drop 1 outer)
    pure (Map.union (Map.mapKeysMonotonic ((path <> ".") <>) scoped) published)

  setFrames frames = Evaluator $ \env -> pure (Done () env{envFrames = frames})

{-| Give a declared function the environment of the module that declared it.

    Only a function needs it. A constant is already a value, and a closure that
    captured something at the point it was written keeps what it captured — a
    lambda's scope is where it was written, not the module it ended up in. -}

{-| Bind the names an import makes available.

    `import M` republishes every name of `M` under `M`'s own last segment,
    `import M as N` under `N`, and `import M { a, b }` binds just those under
    their plain names and no qualifier at all. The values are the ones already
    linked, so an alias and its origin are the same binding rather than two
    copies that could drift.

    The qualifier comes from `moduleQualifier`, which the checker asks too. A
    program the checker admits is one this can find, and the two cannot settle
    a name differently. -}
installImportAliases :: [Located Import] -> Evaluator ()
installImportAliases = mapM_ (installOne . locatedValue)
 where
  installOne value = do
    let path = moduleNameText (locatedValue (importModule value))
        qualifier =
          maybe (moduleQualifier (locatedValue (importModule value))) locatedValue (importAlias value)
    if null (importItems value)
      then republish path (qualifier <> ".")
      else mapM_ (selectOne path . locatedValue) (importItems value)

  selectOne path item = do
    found <- lookupName (path <> "." <> item)
    case found of
      Just value -> bind item value
      Nothing -> pure ()

  republish path prefix = Evaluator $ \env -> pure $
    let qualified = path <> "."
        select frame =
          Map.mapKeysMonotonic (\name -> prefix <> Text.drop (Text.length qualified) name)
            (Map.takeWhileAntitone (Text.isPrefixOf qualified) (snd (Map.split qualified frame)))
        published = Map.unions (map select (envFrames env))
     in case envFrames env of
          current : rest ->
            Done () env{envFrames = Map.union published current : rest}
          [] -> Done () env{envFrames = [published]}



{-| Run with the world available and the work counted where a counter is given.
    Passing no counter is the ordinary path and costs one comparison per step. -}
