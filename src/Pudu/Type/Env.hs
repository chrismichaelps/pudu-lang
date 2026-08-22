{-| @Type.Env.Module — owns checker state and declared signatures -}
module Pudu.Type.Env
  ( Checker
  , CheckerProducts (..)
  , DeclaredTypes (..)
  , bindName
  , emptyDeclared
  , freshVariable
  , inTypeScope
  , lookupField
  , lookupName
  , lookupVariant
  , recordExpression
  , report
  , resolveVariable
  , runChecker
  , setVariable
  , withDeclared
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (Error)
  , diagnostic
  , mkDiagnosticCode
  , sortDiagnostics
  , withHelp
  )
import Pudu.Source (Span, spanEnd, spanStart, unOffset)
import Pudu.Type.Value (Scheme, Type (..), TypeVar (..))

{-| @Type.Env.Declared — what the module's declarations contribute.

    Record fields and sum variants are keyed by the names their declarations
    introduced, which is how a construction or a pattern finds its shape. -}
data DeclaredTypes = DeclaredTypes
  { declaredParams :: !(Map Text [Text])
  , declaredFields :: !(Map Text [(Text, Type)])
  , declaredVariants :: !(Map Text (Text, [Text], [Type]))
  , declaredAliases :: !(Map Text Type)
  }
  deriving stock (Eq, Show)

emptyDeclared :: DeclaredTypes
emptyDeclared =
  DeclaredTypes
    { declaredParams = Map.empty
    , declaredFields = Map.empty
    , declaredVariants = Map.empty
    , declaredAliases = Map.empty
    }

{-| @Type.Env.State — the checker's working state.

    The checker keeps its own name frames rather than reusing the resolver's
    symbol table: the two phases walk the same tree in the same order, and a
    shared resolved representation is the slice that removes this duplication. -}
data CheckerState = CheckerState
  { stateNext :: !Int
  , stateSubstitution :: !(Map TypeVar Type)
  , stateFrames :: ![Map Text Scheme]
  , stateDeclared :: !DeclaredTypes
  , stateTypes :: ![(SpanKey, Type)]
  , stateDiagnosticsRev :: ![Diagnostic]
  }

type SpanKey = (Int, Int)

{-| @Type.Env.Products — the types a run recorded and what it diagnosed -}
data CheckerProducts = CheckerProducts
  { producedTypes :: ![(SpanKey, Type)]
  , producedDiagnostics :: ![Diagnostic]
  }

newtype Checker a = Checker (CheckerState -> (a, CheckerState))

instance Functor Checker where
  fmap transform (Checker action) =
    Checker $ \state -> let (value, next) = action state in (transform value, next)

instance Applicative Checker where
  pure value = Checker $ \state -> (value, state)
  Checker leftAction <*> Checker rightAction =
    Checker $ \state ->
      let (transform, afterLeft) = leftAction state
          (value, afterRight) = rightAction afterLeft
       in (transform value, afterRight)

instance Monad Checker where
  Checker action >>= continue =
    Checker $ \state ->
      let (value, next) = action state
          Checker continued = continue value
       in continued next

runChecker :: Checker a -> CheckerProducts
runChecker (Checker action) =
  let (_, finalState) = action initialState
   in CheckerProducts
        { producedTypes = reverse (stateTypes finalState)
        , producedDiagnostics = sortDiagnostics (reverse (stateDiagnosticsRev finalState))
        }

initialState :: CheckerState
initialState =
  CheckerState
    { stateNext = 0
    , stateSubstitution = Map.empty
    , stateFrames = [Map.empty]
    , stateDeclared = emptyDeclared
    , stateTypes = []
    , stateDiagnosticsRev = []
    }

freshVariable :: Checker Type
freshVariable =
  Checker $ \state ->
    (VariableType (TypeVar (stateNext state)), state{stateNext = stateNext state + 1})

{-| Read what an inference variable has been solved to, if anything. -}
resolveVariable :: TypeVar -> Checker (Maybe Type)
resolveVariable variable =
  Checker $ \state -> (Map.lookup variable (stateSubstitution state), state)

setVariable :: TypeVar -> Type -> Checker ()
setVariable variable typeValue =
  Checker $ \state ->
    ((), state{stateSubstitution = Map.insert variable typeValue (stateSubstitution state)})

bindName :: Text -> Scheme -> Checker ()
bindName name scheme =
  Checker $ \state -> case stateFrames state of
    [] -> ((), state{stateFrames = [Map.singleton name scheme]})
    current : rest -> ((), state{stateFrames = Map.insert name scheme current : rest})

lookupName :: Text -> Checker (Maybe Scheme)
lookupName name = Checker $ \state -> (search (stateFrames state), state)
 where
  search frames = case frames of
    [] -> Nothing
    current : rest -> case Map.lookup name current of
      Just found -> Just found
      Nothing -> search rest

{-| Run an action in a fresh name frame; the frame is discarded on exit. -}
inTypeScope :: Checker a -> Checker ()
inTypeScope action = do
  push
  _ <- action
  pop
 where
  push = Checker $ \state -> ((), state{stateFrames = Map.empty : stateFrames state})
  pop =
    Checker $ \state -> case stateFrames state of
      _ : rest@(_ : _) -> ((), state{stateFrames = rest})
      _ -> ((), state)

withDeclared :: DeclaredTypes -> Checker ()
withDeclared declared = Checker $ \state -> ((), state{stateDeclared = declared})

lookupField :: Text -> Checker (Maybe [(Text, Type)])
lookupField name =
  Checker $ \state -> (Map.lookup name (declaredFields (stateDeclared state)), state)

lookupVariant :: Text -> Checker (Maybe (Text, [Text], [Type]))
lookupVariant name =
  Checker $ \state -> (Map.lookup name (declaredVariants (stateDeclared state)), state)

{-| Record the type an expression was given, so tooling can report it. -}
recordExpression :: Span -> Type -> Checker ()
recordExpression spanValue typeValue =
  Checker $ \state ->
    ((), state{stateTypes = (keyOf spanValue, typeValue) : stateTypes state})

keyOf :: Span -> SpanKey
keyOf spanValue = (unOffset (spanStart spanValue), unOffset (spanEnd spanValue))

report :: Text -> Span -> Text -> Maybe Text -> Checker ()
report code spanValue message help =
  case build code spanValue message help of
    Nothing -> pure ()
    Just value ->
      Checker $ \state ->
        ((), state{stateDiagnosticsRev = value : stateDiagnosticsRev state})

build :: Text -> Span -> Text -> Maybe Text -> Maybe Diagnostic
build code spanValue message help = do
  validCode <- mkDiagnosticCode code
  value <- diagnostic validCode Error spanValue message
  pure (maybe value (`withHelp` value) help)
