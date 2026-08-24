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
  , callLimit
  , descend
  , emptyEnv
  , expectBool
  , lookupName
  , popFrame
  , pushFrame
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
  , envDepth :: !Int
  , envScopes :: ![[Value]]
  }

{-| Open a structured task scope. Every child started inside it is recorded so
    the scope can join them before it yields. -}
openScope :: Evaluator ()
openScope = Evaluator $ \env -> Done () env{envScopes = [] : envScopes env}

{-| Close the innermost scope, returning the children it started in the order
    they were started. Deterministic order is what makes failure selection
    predictable rather than a race. -}
closeScope :: Evaluator [Value]
closeScope =
  Evaluator $ \env -> case envScopes env of
    [] -> Done [] env
    children : rest -> Done (reverse children) env{envScopes = rest}

{-| Record a child in the innermost open scope, if any. A task started outside
    every scope stays cold, which is what keeps a detached task impossible. -}
adoptChild :: Value -> Evaluator ()
adoptChild child =
  Evaluator $ \env -> case envScopes env of
    [] -> Done () env
    children : rest -> Done () env{envScopes = (child : children) : rest}

{-| Drop a child from the innermost scope because it was awaited explicitly, so
    the scope does not run it a second time at exit. -}
releaseChild :: Value -> Evaluator ()
releaseChild child =
  Evaluator $ \env -> case envScopes env of
    [] -> Done () env
    children : rest -> Done () env{envScopes = filter (/= child) children : rest}

insideScope :: Evaluator Bool
insideScope = Evaluator $ \env -> Done (not (null (envScopes env))) env

{-| @Eval.Unwind — a control transfer in flight.

    `return`, `break`, and `continue` are not values, so they travel as an
    unwind that the construct owning them catches: a call catches a return, a
    loop catches a break or a continue. This is what makes a `return` inside a
    nested block leave its function instead of becoming that block's value. -}
data Unwind
  = ReturnUnwind !Value
  | BreakUnwind
  | ContinueUnwind
  deriving stock (Eq, Show)

{-| Evaluation produces a value, transfers control, or aborts with one runtime
    diagnostic; there is no partial state to inspect afterwards. -}
data Eval a
  = Done !a !Env
  | Unwound !Unwind !Env
  | Aborted !Diagnostic

newtype Evaluator a = Evaluator (Env -> Eval a)

instance Functor Evaluator where
  fmap transform (Evaluator action) =
    Evaluator $ \env -> case action env of
      Done value next -> Done (transform value) next
      Unwound transfer next -> Unwound transfer next
      Aborted stop -> Aborted stop

instance Applicative Evaluator where
  pure value = Evaluator $ \env -> Done value env
  Evaluator leftAction <*> Evaluator rightAction =
    Evaluator $ \env -> case leftAction env of
      Aborted stop -> Aborted stop
      Unwound transfer next -> Unwound transfer next
      Done transform afterLeft -> case rightAction afterLeft of
        Aborted stop -> Aborted stop
        Unwound transfer next -> Unwound transfer next
        Done value afterRight -> Done (transform value) afterRight

instance Monad Evaluator where
  Evaluator action >>= continue =
    Evaluator $ \env -> case action env of
      Aborted stop -> Aborted stop
      Unwound transfer next -> Unwound transfer next
      Done value next -> let Evaluator continued = continue value in continued next

{-| Start a control transfer. It travels outward until a construct catches it. -}
unwind :: Unwind -> Evaluator a
unwind transfer = Evaluator $ \env -> Unwound transfer env

{-| Catch a control transfer at the construct that owns it. A transfer this
    construct does not own is returned so the caller can pass it along. -}
catchUnwind :: Evaluator a -> Evaluator (Either Unwind a)
catchUnwind (Evaluator action) =
  Evaluator $ \env -> case action env of
    Done value next -> Done (Right value) next
    Unwound transfer next -> Done (Left transfer) next
    Aborted stop -> Aborted stop

emptyEnv :: Env
emptyEnv = Env{envFrames = [Map.empty], envDepth = 0, envScopes = []}

bind :: Text -> Value -> Evaluator ()
bind name value =
  Evaluator $ \env -> case envFrames env of
    [] -> Done () env{envFrames = [Map.singleton name value]}
    current : rest -> Done () env{envFrames = Map.insert name value current : rest}

{-| Assignment writes the binding where it was declared rather than creating a
    new one in the innermost frame. -}
update :: Text -> Value -> Evaluator ()
update name value = Evaluator $ \env -> Done () env{envFrames = go (envFrames env)}
 where
  go frames = case frames of
    [] -> []
    current : rest
      | Map.member name current -> Map.insert name value current : rest
      | otherwise -> current : go rest

lookupName :: Text -> Evaluator (Maybe Value)
lookupName name = Evaluator $ \env -> Done (search (envFrames env)) env
 where
  search frames = case frames of
    [] -> Nothing
    current : rest -> case Map.lookup name current of
      Just found -> Just found
      Nothing -> search rest

withFrame :: [(Text, Value)] -> Evaluator a -> Evaluator a
withFrame bindings action = do
  pushFrame (Map.fromList bindings)
  value <- action
  popFrame
  pure value

withNewFrame :: Evaluator a -> Evaluator a
withNewFrame = withFrame []

pushFrame :: Map Text Value -> Evaluator ()
pushFrame frame = Evaluator $ \env -> Done () env{envFrames = frame : envFrames env}

popFrame :: Evaluator ()
popFrame =
  Evaluator $ \env -> case envFrames env of
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
currentDepth = Evaluator $ \env -> Done (envDepth env) env

setDepth :: Int -> Evaluator ()
setDepth depth = Evaluator $ \env -> Done () env{envDepth = depth}

callLimit :: Int
callLimit = 4096

abortAt :: Maybe Span -> Text -> Text -> Maybe Text -> Evaluator a
abortAt spanValue code message help =
  Evaluator $ \_ -> case buildDiagnostic spanValue code message help of
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
