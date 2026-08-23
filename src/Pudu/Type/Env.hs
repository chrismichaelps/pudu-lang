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
  , lookupOwnerVariants
  , lookupName
  , lookupVariant
  , recordExpression
  , report
  , rigidBoundsOf
  , rigidSatisfies
  , takeObligations
  , warn
  , withRigidBounds
  , implementsTrait
  , addObligation
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
  , Severity (..)
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
  , declaredOwners :: !(Map Text [Text])
  , declaredImpls :: !(Map Text [Text])
  , declaredAliases :: !(Map Text Type)
  }
  deriving stock (Eq, Show)

emptyDeclared :: DeclaredTypes
emptyDeclared =
  DeclaredTypes
    { declaredParams = Map.empty
    , declaredFields = Map.empty
    , declaredVariants = Map.empty
    , declaredOwners = Map.empty
    , declaredImpls = Map.empty
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
  , stateObligations :: ![(Span, Type, Text)]
  , stateRigidBounds :: !(Map Text [Text])
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
    , stateObligations = []
    , stateRigidBounds = Map.empty
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

{-| Every variant a sum declares, in declaration order. Exhaustiveness reads it
    to know what a match must still cover. -}
lookupOwnerVariants :: Text -> Checker (Maybe [Text])
lookupOwnerVariants owner =
  Checker $ \state -> (Map.lookup owner (declaredOwners (stateDeclared state)), state)

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

{-| Record that a type must implement a trait. Obligations are proved after the
    body is checked, when inference has solved what the argument types are. -}
addObligation :: Span -> Type -> Text -> Checker ()
addObligation spanValue typeValue traitText =
  Checker $ \state ->
    ((), state{stateObligations = (spanValue, typeValue, traitText) : stateObligations state})

takeObligations :: Checker [(Span, Type, Text)]
takeObligations =
  Checker $ \state -> (reverse (stateObligations state), state{stateObligations = []})

{-| The bounds the enclosing declaration's own parameters carry, which is how a
    generic body may call another generic that demands the same trait. Bounds
    from the parameter list and the `where` clause are merged with `(<>`) so a
    parameter that carries bounds in both places keeps all of them rather than
    the last entry overwriting the first. -}
withRigidBounds :: [(Text, [Text])] -> Checker a -> Checker ()
withRigidBounds bounds action = do
  previous <- currentRigidBounds
  setRigidBounds (Map.fromListWith (<>) bounds)
  _ <- action
  setRigidBounds previous

currentRigidBounds :: Checker (Map Text [Text])
currentRigidBounds = Checker $ \state -> (stateRigidBounds state, state)

setRigidBounds :: Map Text [Text] -> Checker ()
setRigidBounds bounds = Checker $ \state -> ((), state{stateRigidBounds = bounds})

{-| The traits a rigid parameter was declared to satisfy. A method call on it
    is answered by those traits, which is what a bound is for. -}
rigidBoundsOf :: Text -> Checker [Text]
rigidBoundsOf name =
  Checker $ \state -> (maybe [] id (Map.lookup name (stateRigidBounds state)), state)

rigidSatisfies :: Text -> Text -> Checker Bool
rigidSatisfies name traitText =
  Checker $ \state ->
    (maybe False (elem traitText) (Map.lookup name (stateRigidBounds state)), state)

implementsTrait :: Text -> Text -> Checker Bool
implementsTrait owner traitText =
  Checker $ \state ->
    ( maybe False (elem traitText) (Map.lookup owner (declaredImpls (stateDeclared state)))
    , state
    )

report :: Text -> Span -> Text -> Maybe Text -> Checker ()
report = emitWith Error

{-| A warning does not gate compilation; it is how a rule that is advisory
    rather than prohibitive reaches the reader. -}
warn :: Text -> Span -> Text -> Maybe Text -> Checker ()
warn = emitWith Warning

emitWith :: Severity -> Text -> Span -> Text -> Maybe Text -> Checker ()
emitWith severity code spanValue message help =
  case build severity code spanValue message help of
    Nothing -> pure ()
    Just value ->
      Checker $ \state ->
        ((), state{stateDiagnosticsRev = value : stateDiagnosticsRev state})

build :: Severity -> Text -> Span -> Text -> Maybe Text -> Maybe Diagnostic
build severity code spanValue message help = do
  validCode <- mkDiagnosticCode code
  value <- diagnostic validCode severity spanValue message
  pure (maybe value (`withHelp` value) help)
