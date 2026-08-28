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
  , evaluateProgramEntry
  , evaluateProgramTallied
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
import Data.IORef (IORef, newIORef, readIORef)
import Pudu.Source (Span)
import Pudu.Eval
  ( EvalOutcome (..)
  , awaitTask
  , callClosure
  , evaluate
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


{-| Run with the world available and the work counted where a counter is given.
    Passing no counter is the ordinary path and costs one comparison per step. -}
