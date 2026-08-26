{-| @Eval.Env.Module — owns evaluation state and abort diagnostics -}
module Pudu.Eval.Env
  ( Env (..)
  , Evaluator (..)
  , Eval (..)
  , Unwind (..)
  , abortAt
  , adoptChild
  , closeScope
  , insideScope
  , openScope
  , releaseChild
  , catchUnwind
  , ascend
  , bind
  , bindMethod
  , callLimit
  , captureEnvironment
  , currentFrame
  , withCaptured
  , descend
  , effectsAdmitted
  , emptyEnv
  , recordVariantOwner
  , variantOwner
  , performEffect
  , withoutEffects
  , expectBool
  , lookupName
  , popFrame
  , pushFrame
  , replaceFrame
  , update
  , withFrame
  , withNewFrame
  , unwind
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (Error)
  , diagnostic
  , mkDiagnosticCode
  , withHelp
  )
import Pudu.Eval.Value (Value (..), valueKind)
import Pudu.Source (Span)

{-| @Eval.Env — name-keyed frames, innermost first -}
data Env = Env
  { envFrames :: ![Map Text Value]
  , envMethods :: !(Map Text Value)
  , envVariantOwners :: !(Map Text Text)
  , envDepth :: !Int
  , envScopes :: ![[Value]]
  , envEffects :: !Bool
  }

{-| Open a structured task scope. Every child started inside it is recorded so
    the scope can join them before it yields. -}
openScope :: Evaluator ()
openScope = Evaluator $ \env -> pure (Done () env{envScopes = [] : envScopes env})

{-| Close the innermost scope, returning the children it started in the order
    they were started. Deterministic order is what makes failure selection
    predictable rather than a race. -}
closeScope :: Evaluator [Value]
closeScope =
  Evaluator $ \env -> pure $ case envScopes env of
    [] -> Done [] env
    children : rest -> Done (reverse children) env{envScopes = rest}

{-| Record a child in the innermost open scope, if any. A task started outside
    every scope stays cold, which is what keeps a detached task impossible. -}
adoptChild :: Value -> Evaluator ()
adoptChild child =
  Evaluator $ \env -> pure $ case envScopes env of
    [] -> Done () env
    children : rest -> Done () env{envScopes = (child : children) : rest}

{-| Drop a child from the innermost scope because it was awaited explicitly, so
    the scope does not run it a second time at exit. -}
releaseChild :: Value -> Evaluator ()
releaseChild child =
  Evaluator $ \env -> pure $ case envScopes env of
    [] -> Done () env
    children : rest -> Done () env{envScopes = filter (/= child) children : rest}

insideScope :: Evaluator Bool
insideScope = Evaluator $ \env -> pure (Done (not (null (envScopes env))) env)

{-| @Eval.Unwind — a control transfer in flight.

    `return`, `break`, and `continue` are not values, so they travel as an
    unwind that the construct owning them catches: a call catches a return, a
    loop catches a break or a continue. This is what makes a `return` inside a
    nested block leave its function instead of becoming that block's value.

    A break and a continue carry the label they were written with, if any. A
    loop catches one addressed to it — by name, or by being the innermost when
    no name was given — and lets every other one keep travelling outward, which
    is exactly how leaving a loop from inside a nested one works. A break also
    carries the value the loop it leaves will produce; a break that named none
    carries unit. -}
data Unwind
  = ReturnUnwind !Value
  | BreakUnwind !(Maybe Text) !Value
  | ContinueUnwind !(Maybe Text)
  deriving stock (Eq, Show)

{-| Evaluation produces a value, transfers control, or aborts with one runtime
    diagnostic; there is no partial state to inspect afterwards. -}
data Eval a
  = Done !a !Env
  | Unwound !Unwind !Env
  | Aborted !Diagnostic

{-| @Eval.Evaluator — evaluation threaded through the environment, over `IO`.

    Evaluation performs effects: a program reads a file, writes to its output,
    and asks its environment questions. Running over `IO` is what lets it,
    rather than a second interpreter existing beside this one for the effectful
    half of the language.

    Compile-time evaluation runs the same interpreter with `envEffects` off, so
    a constant that tried to read a file is refused at the boundary rather than
    quietly performing the read while the compiler runs. -}
newtype Evaluator a = Evaluator (Env -> IO (Eval a))

instance Functor Evaluator where
  fmap transform (Evaluator action) =
    Evaluator $ \env -> do
      outcome <- action env
      pure $ case outcome of
        Done value next -> Done (transform value) next
        Unwound transfer next -> Unwound transfer next
        Aborted stop -> Aborted stop

instance Applicative Evaluator where
  pure value = Evaluator $ \env -> pure (Done value env)
  Evaluator leftAction <*> Evaluator rightAction =
    Evaluator $ \env -> do
      left <- leftAction env
      case left of
        Aborted stop -> pure (Aborted stop)
        Unwound transfer next -> pure (Unwound transfer next)
        Done transform afterLeft -> do
          right <- rightAction afterLeft
          pure $ case right of
            Aborted stop -> Aborted stop
            Unwound transfer next -> Unwound transfer next
            Done value afterRight -> Done (transform value) afterRight

instance Monad Evaluator where
  Evaluator action >>= continue =
    Evaluator $ \env -> do
      outcome <- action env
      case outcome of
        Aborted stop -> pure (Aborted stop)
        Unwound transfer next -> pure (Unwound transfer next)
        Done value next -> let Evaluator continued = continue value in continued next

{-| Run an effect, when the environment admits effects at all.

    Compile-time evaluation does not: a constant is folded while the compiler
    runs, and letting it read a file would make compilation depend on the world
    the compiler happened to be in. The refusal names the boundary rather than
    the operation, because every operation behind it is refused for one
    reason. -}
performEffect :: Diagnostic -> IO a -> Evaluator a
performEffect refusal action =
  Evaluator $ \env ->
    if envEffects env
      then do
        value <- action
        pure (Done value env)
      else pure (Aborted refusal)

{-| Whether the environment admits effects. -}
effectsAdmitted :: Evaluator Bool
effectsAdmitted = Evaluator $ \env -> pure (Done (envEffects env) env)

{-| Run an action with effects denied, whatever the caller admitted. -}
withoutEffects :: Evaluator a -> Evaluator a
withoutEffects (Evaluator action) =
  Evaluator $ \env -> do
    outcome <- action env{envEffects = False}
    pure $ case outcome of
      Done value next -> Done value next{envEffects = envEffects env}
      Unwound transfer next -> Unwound transfer next{envEffects = envEffects env}
      Aborted stop -> Aborted stop

{-| Start a control transfer. It travels outward until a construct catches it. -}
unwind :: Unwind -> Evaluator a
unwind transfer = Evaluator $ \env -> pure (Unwound transfer env)

{-| Catch a control transfer at the construct that owns it. A transfer this
    construct does not own is returned so the caller can pass it along. -}
catchUnwind :: Evaluator a -> Evaluator (Either Unwind a)
catchUnwind (Evaluator action) =
  Evaluator $ \env -> do
    outcome <- action env
    pure $ case outcome of
      Done value next -> Done (Right value) next
      Unwound transfer next -> Done (Left transfer) next
      Aborted stop -> Aborted stop

emptyEnv :: Env
emptyEnv =
  Env
    { envFrames = [Map.empty]
    , envMethods = Map.empty
    , envVariantOwners = Map.empty
    , envDepth = 0
    , envScopes = []
    , envEffects = True
    }

bind :: Text -> Value -> Evaluator ()
bind name value =
  Evaluator $ \env -> pure $ case envFrames env of
    [] -> Done () env{envFrames = [Map.singleton name value]}
    current : rest -> Done () env{envFrames = Map.insert name value current : rest}

{-| Assignment writes the binding where it was declared rather than creating a
    new one in the innermost frame. -}
update :: Text -> Value -> Evaluator ()
update name value = Evaluator $ \env -> pure (Done () env{envFrames = go (envFrames env)})
 where
  go frames = case frames of
    [] -> []
    current : rest
      | Map.member name current -> Map.insert name value current : rest
      | otherwise -> current : go rest

{-| Find a name: lexically first, then among the program's implementations.

    The two namespaces are separate because their scoping rules are opposite. A
    function belongs to the module that declared it, and a module's own name
    must win over another module's. An **implementation is global** — a fact
    about a type and a trait, true everywhere in a program once it exists
    anywhere in it, which is what the orphan rule is for — so it cannot live in
    a frame that only the module declaring it can see. Keeping impls out of the
    frame stack is what lets a library's adapter dispatch to a program's own
    type, which was linked long after the library was. -}
lookupName :: Text -> Evaluator (Maybe Value)
lookupName name =
  Evaluator $ \env ->
    pure (Done (maybe (Map.lookup name (envMethods env)) Just (search (envFrames env))) env)
 where
  search frames = case frames of
    [] -> Nothing
    current : rest -> case Map.lookup name current of
      Just found -> Just found
      Nothing -> search rest

{-| Record an implementation's method, where every module can reach it. -}
bindMethod :: Text -> Value -> Evaluator ()
bindMethod name value =
  Evaluator $ \env -> pure (Done () env{envMethods = Map.insert name value (envMethods env)})

{-| Record which sum a variant belongs to.

    A runtime value names the variant it is, not the type that declares it, and
    an implementation is written for the type. Without this, asking whether a
    `Cons` is a sequence looks for `Cons.begin` and finds nothing, while the
    implementation the program wrote sits under `List`. -}
recordVariantOwner :: Text -> Text -> Evaluator ()
recordVariantOwner variant owner =
  Evaluator $ \env ->
    pure (Done () env{envVariantOwners = Map.insert variant owner (envVariantOwners env)})

{-| The sum a variant belongs to, when the variant is one. -}
variantOwner :: Text -> Evaluator (Maybe Text)
variantOwner variant =
  Evaluator $ \env -> pure (Done (Map.lookup variant (envVariantOwners env)) env)

withFrame :: [(Text, Value)] -> Evaluator a -> Evaluator a
withFrame bindings (Evaluator action) =
  Evaluator $ \env -> do
    outcome <- action env{envFrames = Map.fromList bindings : envFrames env}
    pure $ case outcome of
      Done value next -> Done value (dropInnermostFrame next)
      Unwound transfer next -> Unwound transfer (dropInnermostFrame next)
      Aborted stop -> Aborted stop

{-| The environment as it stands, for a function literal to carry away.

    A literal captures every frame in scope rather than only the names its body
    mentions. Capturing selectively would need the resolver's answer about free
    names, and the two would have to agree forever; capturing the environment
    means they cannot disagree. -}
captureEnvironment :: Evaluator [Map Text Value]
captureEnvironment = Evaluator $ \env -> pure (Done (envFrames env) env)

{-| Run an action in a captured environment, restoring the caller's afterwards.

    A declaration passes `Nothing` and runs where it was called, which is what
    lets a module's functions see each other. A literal passes the frames it
    captured, so a free name means what it meant where the literal was
    written — not what it happens to mean where it is finally called. -}
withCaptured :: Maybe [Map Text Value] -> Evaluator a -> Evaluator a
withCaptured Nothing action = action
withCaptured (Just frames) (Evaluator action) =
  Evaluator $ \env -> do
    outcome <- action env{envFrames = frames}
    pure $ case outcome of
      Done value next -> Done value next{envFrames = envFrames env}
      Unwound transfer next -> Unwound transfer next{envFrames = envFrames env}
      Aborted stop -> Aborted stop

{-| Remove the lexical frame a `withFrame` introduced while retaining every
    other part of the nested evaluator's state. Nested frame combinators clean
    their own frames before returning, including during an unwind, so this is
    always the frame owned by the current combinator. -}
dropInnermostFrame :: Env -> Env
dropInnermostFrame env = case envFrames env of
  _ : rest@(_ : _) -> env{envFrames = rest}
  _ -> env

withNewFrame :: Evaluator a -> Evaluator a
withNewFrame = withFrame []

pushFrame :: Map Text Value -> Evaluator ()
pushFrame frame = Evaluator $ \env -> pure (Done () env{envFrames = frame : envFrames env})

{-| What the innermost frame currently holds.

    Linking an imported module needs it: the module's declarations are loaded
    into a frame of their own, and republishing them under a qualified path
    means reading back exactly what that load produced. -}
currentFrame :: Evaluator (Map Text Value)
currentFrame =
  Evaluator $ \env -> pure $ case envFrames env of
    current : _ -> Done current env
    [] -> Done Map.empty env

{-| Replace what the innermost frame holds.

    Linking a module needs it: the module's functions are loaded first so they
    can see each other, and then rewritten to capture the environment they were
    loaded into. -}
replaceFrame :: Map Text Value -> Evaluator ()
replaceFrame frame =
  Evaluator $ \env -> pure $ case envFrames env of
    _ : rest -> Done () env{envFrames = frame : rest}
    [] -> Done () env{envFrames = [frame]}

popFrame :: Evaluator ()
popFrame =
  Evaluator $ \env -> pure $ case envFrames env of
    _ : rest@(_ : _) -> Done () env{envFrames = rest}
    _ -> Done () env

descend :: Maybe Span -> Evaluator Int
descend callSpan = do
  depth <- currentDepth
  if depth > callLimit
    then abortAt callSpan "E7002" "call depth exceeded the evaluation limit"
      (Just "the interactive evaluator bounds recursion") >> pure depth
    else setDepth (depth + 1) >> pure depth

ascend :: Int -> Evaluator ()
ascend = setDepth

currentDepth :: Evaluator Int
currentDepth = Evaluator $ \env -> pure (Done (envDepth env) env)

setDepth :: Int -> Evaluator ()
setDepth depth = Evaluator $ \env -> pure (Done () env{envDepth = depth})

callLimit :: Int
callLimit = 4096

abortAt :: Maybe Span -> Text -> Text -> Maybe Text -> Evaluator a
abortAt spanValue code message help =
  Evaluator $ \_ -> pure $ case buildDiagnostic spanValue code message help of
    Just value -> Aborted value
    Nothing -> Aborted (fallbackDiagnostic spanValue)

buildDiagnostic :: Maybe Span -> Text -> Text -> Maybe Text -> Maybe Diagnostic
buildDiagnostic spanValue code message help = do
  position <- spanValue
  validCode <- mkDiagnosticCode code
  value <- diagnostic validCode Error position message
  pure (maybe value (`withHelp` value) help)

fallbackDiagnostic :: Maybe Span -> Diagnostic
fallbackDiagnostic spanValue =
  case buildDiagnostic spanValue "E7001" "evaluation failed" Nothing of
    Just value -> value
    Nothing -> error "fallbackDiagnostic: evaluation reported no location"

expectBool :: Span -> Value -> Evaluator Bool
expectBool spanValue value = case value of
  BoolValue flag -> pure flag
  _ ->
    abortAt (Just spanValue) "E7001"
      ("expected a bool, found a " <> valueKind value) Nothing >> pure False
