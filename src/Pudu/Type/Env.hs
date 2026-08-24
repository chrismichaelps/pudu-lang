{-| @Type.Env.Module — owns checker state and declared signatures -}
module Pudu.Type.Env
  ( Checker
  , UnsafeFrame (..)
  , enterUnsafe
  , insideUnsafe
  , leaveUnsafe
  , recordComptimeFunction
  , isComptimeFunction
  , inComptime
  , withComptime
  , recordUnsafeFunction
  , unsafeFunctionCapabilities
  , useCapability
  , useUnsafeRegion
  , CheckerProducts (..)
  , DeclaredTypes (..)
  , bindName
  , bindImportedMethod
  , emptyDeclared
  , freshVariable
  , constrainIntegerLiteral
  , finalizeIntegerLiterals
  , finalizeIntegerLiteralsBetween
  , finalizeIntegerLiteralsSince
  , integerLiteralCheckpoint
  , inTypeScope
  , lookupField
  , lookupOwnerVariants
  , lookupTypeParams
  , lookupName
  , isImportedMethod
  , lookupVariant
  , recordExpression
  , report
  , negateIntegerLiteral
  , rigidBoundsOf
  , rigidSatisfies
  , takeObligations
  , warn
  , withRigidBounds
  , implementsTrait
  , ambiguousProviders
  , markAmbiguousMethod
  , methodProvider
  , recordMethodProvider
  , reportedReserved
  , addObligation
  , resolveVariable
  , runChecker
  , setVariable
  , validateIntegerLiteralsSince
  , withDeclared
  ) where

import Data.Bits (finiteBitSize)
import Data.List (partition)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (..)
  , diagnostic
  , mkDiagnosticCode
  , sortDiagnostics
  , withHelp
  )
import Pudu.Frontend.Syntax.Tree (Capability (..))
import Pudu.Source (Span, spanEnd, spanStart, unOffset)
import Pudu.IntegerLiteral (fitsIntegerType)
import Pudu.Type.Value
  ( NominalId (..), Scheme, Type (..), TypeVar (..), integerType, renderType )

{-| @Type.Env.Declared — what the module's declarations contribute.

    Record fields and sum variants are keyed by the names their declarations
    introduced, which is how a construction or a pattern finds its shape. -}
data DeclaredTypes = DeclaredTypes
  { declaredNames :: !(Map Text NominalId)
  , declaredParams :: !(Map NominalId [Text])
  , declaredFields :: !(Map NominalId [(Text, Type)])
  , declaredVariants :: !(Map Text (NominalId, [Text], [Type]))
  , declaredOwners :: !(Map NominalId [Text])
  , declaredImpls :: !(Map NominalId [NominalId])
  , declaredAliases :: !(Map Text Type)
  }
  deriving stock (Eq, Show)

emptyDeclared :: DeclaredTypes
emptyDeclared =
  DeclaredTypes
    { declaredNames = Map.empty
    , declaredParams = Map.empty
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
  , stateImportedMethods :: !(Set Text)
  , stateDeclared :: !DeclaredTypes
  , stateTypes :: ![(SpanKey, Type)]
  , stateMethodProviders :: !(Map Text NominalId)
  , stateAmbiguousMethods :: !(Map Text [NominalId])
  , stateReservedSpans :: ![(Int, Int)]
  , stateUnsafeFrames :: ![UnsafeFrame]
  , stateUnsafeFunctions :: !(Map Text [Capability])
  , stateComptimeFunctions :: ![Text]
  , stateInComptime :: !Bool
  , stateObligations :: ![(Span, Type, NominalId)]
  , stateIntegerLiterals :: ![IntegerConstraint]
  , stateRigidBounds :: !(Map Text [NominalId])
  , stateDiagnosticsRev :: ![Diagnostic]
  }

type SpanKey = (Int, Int)

data IntegerConstraint = IntegerConstraint
  { integerConstraintSpan :: !Span
  , integerConstraintValue :: !Integer
  , integerConstraintVariable :: !TypeVar
  }

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
        { producedTypes =
            reverse (map (fmap (resolveFinal (stateSubstitution finalState))) (stateTypes finalState))
        , producedDiagnostics = sortDiagnostics (reverse (stateDiagnosticsRev finalState))
        }

initialState :: CheckerState
initialState =
  CheckerState
    { stateNext = 0
    , stateSubstitution = Map.empty
    , stateFrames = [Map.empty]
    , stateImportedMethods = Set.empty
    , stateDeclared = emptyDeclared
    , stateTypes = []
    , stateMethodProviders = Map.empty
    , stateAmbiguousMethods = Map.empty
    , stateReservedSpans = []
    , stateUnsafeFrames = []
    , stateUnsafeFunctions = Map.empty
    , stateComptimeFunctions = []
    , stateInComptime = False
    , stateObligations = []
    , stateIntegerLiterals = []
    , stateRigidBounds = Map.empty
    , stateDiagnosticsRev = []
    }

freshVariable :: Checker Type
freshVariable =
  Checker $ \state ->
    (VariableType (TypeVar (stateNext state)), state{stateNext = stateNext state + 1})

constrainIntegerLiteral :: Span -> Integer -> Maybe Text -> Checker Type
constrainIntegerLiteral spanValue value selectedType =
  Checker $ \state ->
    let variable = TypeVar (stateNext state)
        substitutions = case selectedType of
          Nothing -> stateSubstitution state
          Just name ->
            Map.insert variable (NominalType (NominalId Nothing name) []) (stateSubstitution state)
        constraint = IntegerConstraint spanValue value variable
     in ( VariableType variable
        , state
            { stateNext = stateNext state + 1
            , stateSubstitution = substitutions
            , stateIntegerLiterals = constraint : stateIntegerLiterals state
            }
        )

negateIntegerLiteral :: Type -> Checker Bool
negateIntegerLiteral typeValue = case typeValue of
  VariableType variable ->
    Checker $ \state ->
      let (found, constraints) = negateMatching variable (stateIntegerLiterals state)
       in (found, state{stateIntegerLiterals = constraints})
  _ -> pure False

finalizeIntegerLiterals :: Checker ()
finalizeIntegerLiterals = do
  constraints <- takeIntegerConstraints
  mapM_ finalizeIntegerConstraint constraints

integerLiteralCheckpoint :: Checker Int
integerLiteralCheckpoint =
  Checker $ \state -> (stateNext state, state)

finalizeIntegerLiteralsSince :: Int -> Checker ()
finalizeIntegerLiteralsSince checkpoint = do
  constraints <- takeIntegerConstraintsMatching (createdSince checkpoint)
  mapM_ finalizeIntegerConstraint constraints

finalizeIntegerLiteralsBetween :: Int -> Int -> Checker ()
finalizeIntegerLiteralsBetween start end = do
  constraints <- takeIntegerConstraintsMatching (createdBetween start end)
  mapM_ finalizeIntegerConstraint constraints

validateIntegerLiteralsSince :: Int -> Checker ()
validateIntegerLiteralsSince checkpoint = do
  constraints <- takeResolvedIntegerConstraintsSince checkpoint
  mapM_ finalizeIntegerConstraint constraints

finalizeIntegerConstraint :: IntegerConstraint -> Checker ()
finalizeIntegerConstraint constraint = do
  let variable = integerConstraintVariable constraint
      value = integerConstraintValue constraint
      spanValue = integerConstraintSpan constraint
  resolved <- resolveCurrent (VariableType variable)
  selected <- case resolved of
    VariableType unresolved -> do
      setVariable unresolved integerType
      pure integerType
    other -> pure other
  case selected of
    NominalType identity []
      | nominalModule identity == Nothing ->
          case fitsIntegerType (finiteBitSize (0 :: Int)) (nominalName identity) value of
            Just True -> pure ()
            Just False -> do
              report "E3018" spanValue
                ( "integer literal " <> Text.pack (show value)
                    <> " does not fit " <> nominalName identity
                )
                (Just "choose a wider integer type or change the literal")
              setVariable variable ErrorType
            Nothing -> nonInteger spanValue variable selected
    ErrorType -> pure ()
    _ -> nonInteger spanValue variable selected
 where
  nonInteger spanValue variable selected = do
    report "E3001" spanValue
      ("expected " <> renderType selected <> ", found Int")
      (Just "change the value, or change the declared type it must match")
    setVariable variable ErrorType

takeIntegerConstraints :: Checker [IntegerConstraint]
takeIntegerConstraints =
  Checker $ \state ->
    ( reverse (stateIntegerLiterals state)
    , state{stateIntegerLiterals = []}
    )

takeIntegerConstraintsMatching
  :: (IntegerConstraint -> Bool) -> Checker [IntegerConstraint]
takeIntegerConstraintsMatching matches =
  Checker $ \state ->
    let constraints = stateIntegerLiterals state
        (selected, retained) = partition matches constraints
     in (reverse selected, state{stateIntegerLiterals = retained})

takeResolvedIntegerConstraintsSince :: Int -> Checker [IntegerConstraint]
takeResolvedIntegerConstraintsSince checkpoint =
  Checker $ \state ->
    let constraints = stateIntegerLiterals state
        isResolved constraint =
          createdSince checkpoint constraint
            && case resolveFinal (stateSubstitution state)
              (VariableType (integerConstraintVariable constraint)) of
                VariableType _ -> False
                _ -> True
        (selected, retained) = partition isResolved constraints
     in (reverse selected, state{stateIntegerLiterals = retained})

createdSince :: Int -> IntegerConstraint -> Bool
createdSince checkpoint constraint =
  let TypeVar identity = integerConstraintVariable constraint
   in identity >= checkpoint

createdBetween :: Int -> Int -> IntegerConstraint -> Bool
createdBetween start end constraint =
  let TypeVar identity = integerConstraintVariable constraint
   in identity >= start && identity < end

resolveCurrent :: Type -> Checker Type
resolveCurrent typeValue =
  Checker $ \state -> (resolveFinal (stateSubstitution state) typeValue, state)

negateMatching :: TypeVar -> [IntegerConstraint] -> (Bool, [IntegerConstraint])
negateMatching variable constraints = case constraints of
  [] -> (False, [])
  constraint : rest ->
    let (foundRest, updatedRest) = negateMatching variable rest
     in if integerConstraintVariable constraint == variable
          then
            ( True
            , constraint{integerConstraintValue = negate (integerConstraintValue constraint)} : updatedRest
            )
          else (foundRest, constraint : updatedRest)

resolveFinal :: Map TypeVar Type -> Type -> Type
resolveFinal substitutions typeValue = case typeValue of
  VariableType variable -> case Map.lookup variable substitutions of
    Nothing -> typeValue
    Just found -> resolveFinal substitutions found
  NominalType name arguments -> NominalType name (map (resolveFinal substitutions) arguments)
  TupleTypeValue members -> TupleTypeValue (map (resolveFinal substitutions) members)
  FunctionTypeValue asynchronous inputs result ->
    FunctionTypeValue asynchronous
      (map (resolveFinal substitutions) inputs)
      (resolveFinal substitutions result)
  ReferenceTypeValue mutable target ->
    ReferenceTypeValue mutable (resolveFinal substitutions target)
  other -> other

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

bindImportedMethod :: Text -> Scheme -> Checker ()
bindImportedMethod name scheme = do
  bindName name scheme
  Checker $ \state ->
    ((), state{stateImportedMethods = Set.insert name (stateImportedMethods state)})

isImportedMethod :: Text -> Checker Bool
isImportedMethod name =
  Checker $ \state -> (Set.member name (stateImportedMethods state), state)

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

lookupField :: NominalId -> Checker (Maybe [(Text, Type)])
lookupField name =
  Checker $ \state -> (Map.lookup name (declaredFields (stateDeclared state)), state)

{-| The generic parameters a nominal declaration introduced, so a structural
    walk can substitute a use's arguments into its declared components. -}
lookupTypeParams :: NominalId -> Checker (Maybe [Text])
lookupTypeParams owner =
  Checker $ \state -> (Map.lookup owner (declaredParams (stateDeclared state)), state)

{-| Every variant a sum declares, in declaration order. Exhaustiveness reads it
    to know what a match must still cover. -}
lookupOwnerVariants :: NominalId -> Checker (Maybe [Text])
lookupOwnerVariants owner =
  Checker $ \state -> (Map.lookup owner (declaredOwners (stateDeclared state)), state)

lookupVariant :: Text -> Checker (Maybe (NominalId, [Text], [Type]))
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
addObligation :: Span -> Type -> NominalId -> Checker ()
addObligation spanValue typeValue traitText =
  Checker $ \state ->
    ((), state{stateObligations = (spanValue, typeValue, traitText) : stateObligations state})

takeObligations :: Checker [(Span, Type, NominalId)]
takeObligations =
  Checker $ \state -> (reverse (stateObligations state), state{stateObligations = []})

{-| The bounds the enclosing declaration's own parameters carry, which is how a
    generic body may call another generic that demands the same trait. Bounds
    from the parameter list and the `where` clause are merged with `(<>`) so a
    parameter that carries bounds in both places keeps all of them rather than
    the last entry overwriting the first. -}
withRigidBounds :: [(Text, [NominalId])] -> Checker a -> Checker ()
withRigidBounds bounds action = do
  previous <- currentRigidBounds
  setRigidBounds (Map.fromListWith (<>) bounds)
  _ <- action
  setRigidBounds previous

currentRigidBounds :: Checker (Map Text [NominalId])
currentRigidBounds = Checker $ \state -> (stateRigidBounds state, state)

setRigidBounds :: Map Text [NominalId] -> Checker ()
setRigidBounds bounds = Checker $ \state -> ((), state{stateRigidBounds = bounds})

{-| The traits a rigid parameter was declared to satisfy. A method call on it
    is answered by those traits, which is what a bound is for. -}
rigidBoundsOf :: Text -> Checker [NominalId]
rigidBoundsOf name =
  Checker $ \state -> (maybe [] id (Map.lookup name (stateRigidBounds state)), state)

rigidSatisfies :: Text -> NominalId -> Checker Bool
rigidSatisfies name traitText =
  Checker $ \state ->
    (maybe False (elem traitText) (Map.lookup name (stateRigidBounds state)), state)

{-| Which trait supplied a method binding. Two traits providing the same member
    for one type is an ambiguity the reader must resolve, and this is what lets
    the second binding notice the first. -}
recordMethodProvider :: Text -> NominalId -> Checker ()
recordMethodProvider key traitIdentity =
  Checker $ \state ->
    ((), state{stateMethodProviders = Map.insert key traitIdentity (stateMethodProviders state)})

methodProvider :: Text -> Checker (Maybe NominalId)
methodProvider key =
  Checker $ \state -> (Map.lookup key (stateMethodProviders state), state)

{-| @Type.Env.UnsafeFrame — one unsafe region and what it has actually used.

    Granting a capability nothing needs is worth reporting, so a frame records
    both what it offered and what the region reached for. -}
data UnsafeFrame = UnsafeFrame
  { frameGranted :: ![Capability]
  , frameUsed :: ![Capability]
  }
  deriving stock (Eq, Show)

{-| Enter an unsafe region. An empty grant list is the blanket form and offers
    every capability; naming some offers exactly those. -}
enterUnsafe :: [Capability] -> Checker ()
enterUnsafe granted =
  Checker $ \state ->
    ( ()
    , state
        { stateUnsafeFrames =
            UnsafeFrame{frameGranted = granted, frameUsed = []} : stateUnsafeFrames state
        }
    )

{-| Leave the innermost unsafe region, reporting what it granted and used. -}
leaveUnsafe :: Checker (Maybe UnsafeFrame)
leaveUnsafe =
  Checker $ \state -> case stateUnsafeFrames state of
    [] -> (Nothing, state)
    frame : rest -> (Just frame, state{stateUnsafeFrames = rest})

{-| Whether any enclosing region grants the capability, marking it used in the
    innermost region that offers it. -}
useCapability :: Capability -> Checker Bool
useCapability capability =
  Checker $ \state ->
    let (found, frames) = markFirst (stateUnsafeFrames state)
     in (found, state{stateUnsafeFrames = frames})
 where
  markFirst frames = case frames of
    [] -> (False, [])
    frame : rest
      | grants frame ->
          (True, frame{frameUsed = capability : frameUsed frame} : rest)
      | otherwise ->
          let (found, marked) = markFirst rest in (found, frame : marked)
  grants frame = null (frameGranted frame) || capability `elem` frameGranted frame

{-| Whether any unsafe region is open at all, which is what a blanket unsafe
    function requires of its caller. -}
insideUnsafe :: Checker Bool
insideUnsafe = Checker $ \state -> (not (null (stateUnsafeFrames state)), state)

{-| Mark the innermost region as exercised, which is what a blanket unsafe call
    does: it uses the region without naming a capability. A blanket region
    grants everything, so everything counts as used. -}
useUnsafeRegion :: Checker ()
useUnsafeRegion =
  Checker $ \state -> case stateUnsafeFrames state of
    [] -> ((), state)
    frame : rest ->
      let exercised
            | null (frameGranted frame) = [minBound .. maxBound]
            | otherwise = frameGranted frame
       in ((), state{stateUnsafeFrames = frame{frameUsed = exercised <> frameUsed frame} : rest})

{-| Which functions may run at compile time. A compile-time body may call only
    these, which is what makes the guarantee transitive rather than a promise
    each function makes about itself. -}
recordComptimeFunction :: Text -> Checker ()
recordComptimeFunction name =
  Checker $ \state -> ((), state{stateComptimeFunctions = name : stateComptimeFunctions state})

isComptimeFunction :: Text -> Checker Bool
isComptimeFunction name =
  Checker $ \state -> (name `elem` stateComptimeFunctions state, state)

{-| Run an action while checking a compile-time body, restoring the previous
    setting on exit so a nested ordinary declaration is unaffected. -}
withComptime :: Bool -> Checker a -> Checker ()
withComptime inside action = do
  previous <- inComptime
  setComptime inside
  _ <- action
  setComptime previous

inComptime :: Checker Bool
inComptime = Checker $ \state -> (stateInComptime state, state)

setComptime :: Bool -> Checker ()
setComptime inside = Checker $ \state -> ((), state{stateInComptime = inside})

recordUnsafeFunction :: Text -> [Capability] -> Checker ()
recordUnsafeFunction name capabilities =
  Checker $ \state ->
    ((), state{stateUnsafeFunctions = Map.insert name capabilities (stateUnsafeFunctions state)})

unsafeFunctionCapabilities :: Text -> Checker (Maybe [Capability])
unsafeFunctionCapabilities name =
  Checker $ \state -> (Map.lookup name (stateUnsafeFunctions state), state)

{-| Report a reserved type at most once per occurrence. A signature is formed
    both when it is declared and when its body is checked, and one written
    `Decimal` is one mistake however many times the checker walks it. -}
reportedReserved :: Span -> Checker Bool
reportedReserved spanValue =
  Checker $ \state ->
    let key = (unOffset (spanStart spanValue), unOffset (spanEnd spanValue))
        seen = key `elem` stateReservedSpans state
     in (seen, state{stateReservedSpans = key : stateReservedSpans state})

{-| Record that two traits provide the same member for one type. Declaring both
    is legal; only an unqualified call has to choose, so the ambiguity is stored
    here and reported where it is used. -}
markAmbiguousMethod :: Text -> [NominalId] -> Checker ()
markAmbiguousMethod key providers =
  Checker $ \state ->
    ( ()
    , state
        { stateAmbiguousMethods =
            Map.insertWith union' key providers (stateAmbiguousMethods state)
        }
    )
 where
  union' new existing = existing <> filter (`notElem` existing) new

ambiguousProviders :: Text -> Checker [NominalId]
ambiguousProviders key =
  Checker $ \state -> (Map.findWithDefault [] key (stateAmbiguousMethods state), state)

implementsTrait :: NominalId -> NominalId -> Checker Bool
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
