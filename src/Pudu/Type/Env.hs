{-| @Type.Env.Module — owns checker state and declared signatures -}
module Pudu.Type.Env
  ( Checker
  , LoopFrame (..)
  , UnsafeFrame (..)
  , enterLoop
  , enterUnsafe
  , leaveLoop
  , loopTarget
  , markLoopBroken
  , withoutLoops
  , insideUnsafe
  , leaveUnsafe
  , recordComptimeFunction
  , isComptimeFunction
  , inComptime
  , withComptime
  , recordRequiredArity
  , requiredArityOf
  , recordUnsafeFunction
  , unsafeFunctionCapabilities
  , inheritRestrictions
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
  , insideClosure
  , capturedFromOutside
  , inTypeScopeWith
  , lookupField
  , lookupOwnerVariants
  , lookupTypeParams
  , lookupName
  , qualifiesSomething
  , isImportedMethod
  , lookupVariant
  , lookupVariantIn
  , lookupVariantFields
  , lookupRecordedExpression
  , recordExpression
  , report
  , reportedAt
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
  ( NominalId (..), Scheme (..), Type (..), TypeVar (..), integerType, renderType )

{-| @Type.Env.Declared — what the module's declarations contribute.

    Record fields and sum variants are keyed by the names their declarations
    introduced, which is how a construction or a pattern finds its shape. -}
data DeclaredTypes = DeclaredTypes
  { declaredNames :: !(Map Text NominalId)
  , declaredParams :: !(Map NominalId [Text])
  , declaredFields :: !(Map NominalId [(Text, Type)])
  , declaredVariants :: !(Map Text (NominalId, [Text], [Type]))
  {-| The same variants, keyed by the type that owns them as well as by their
      name.

      Two modules may each declare a variant called `Text`, and a bare-name
      table can only hold one of them — so a pattern would match against
      whichever module happened to be loaded last, which is not a property of
      the module being checked. Keyed by owner there is no collision to
      resolve. -}
  , declaredOwnedVariants :: !(Map (NominalId, Text) (NominalId, [Text], [Type]))
  , declaredVariantFields :: !(Map Text [Text])
  , declaredOwners :: !(Map NominalId [Text])
  , declaredImpls :: !(Map NominalId [NominalId])
  , declaredAliases :: !(Map Text ([Text], Type))
  , declaredTraitNames :: !(Set NominalId)
  {-| The module qualifiers whose interface was found.

      A qualified type name is only worth judging when the module it names is
      one the compiler actually read. Absent from here means nothing could be
      known about it, and silence is the honest answer. -}
  , declaredQualifiers :: !(Set Text)
  }
  deriving stock (Eq, Show)

emptyDeclared :: DeclaredTypes
emptyDeclared =
  DeclaredTypes
    { declaredNames = Map.empty
    , declaredParams = Map.empty
    , declaredFields = Map.empty
    , declaredVariants = Map.empty
    , declaredOwnedVariants = Map.empty
    , declaredVariantFields = Map.empty
    , declaredOwners = Map.empty
    , declaredImpls = Map.empty
    , declaredAliases = Map.empty
    , declaredTraitNames = Set.empty
    , declaredQualifiers = Set.empty
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
  , stateUnsafeFrames :: ![UnsafeFrame]
  , stateLoopFrames :: ![LoopFrame]
  {-| How deep the name frames were when each enclosing closure began.

      A closure captures what it can see, and the copy it captures is its own.
      An assignment to a name from outside therefore writes the closure's copy
      and leaves the original alone, so the depth is kept in order to tell a
      name the closure declared from one it only captured. -}
  , stateClosureDepths :: ![Int]
  , stateReportedSpans :: ![((Int, Int), Text)]
  , stateUnsafeFunctions :: !(Map Text [Capability])
  {-| Whether each declared function may run at compile time.

      A map rather than a list of the compile-time ones, because the question
      asked at a call is three-way. A name recorded `True` may be called from a
      compile-time body; one recorded `False` is a declared function that may
      not, and is refused early with a good diagnostic. A name absent from the
      map is a parameter, a local, or a built-in — nothing here knows what it
      holds, and refusing it made higher-order compile-time code unwritable
      while adding no guarantee, since an effect reached while folding is
      refused then and there. -}
  , stateComptimeFunctions :: !(Map Text Bool)
  {-| How many arguments a declared function must be given.

      The parameters without defaults. A function type records what each
      parameter takes and not whether it has to be supplied, so a call missing
      one was accepted and became a runtime fault; the count that decides it is
      known where the declaration is read and is kept here under its name. A
      name absent from the map is a parameter, a local, or a value obtained some
      other way, about which nothing is claimed. -}
  , stateRequiredArity :: !(Map Text (Int, Int))
  , stateInComptime :: !Bool
  , stateObligations :: ![(Span, Type, NominalId)]
  , stateIntegerLiterals :: ![IntegerConstraint]
  , stateIntegerKinds :: ![(Span, Text)]
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
  , producedSchemes :: ![(Text, Scheme)]
  , producedDiagnostics :: ![Diagnostic]
  {-| The type inference settled on for each integer literal.

      A literal written without a suffix is not a platform `Int` merely because
      it was written plainly: `let count: Int8 = 127` makes it an `Int8`, and so
      does passing it to a parameter declared one. Only the checker knows, and
      without this nothing downstream could — the evaluator built every
      suffixless literal as a platform integer, so the width a declaration
      promised was never enforced on it. -}
  , producedIntegerKinds :: ![(Span, Text)]
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
        , producedSchemes = finalSchemes finalState
        , producedDiagnostics = sortDiagnostics (reverse (stateDiagnosticsRev finalState))
        , producedIntegerKinds = reverse (stateIntegerKinds finalState)
        }

{-| The module frame as inference left it, with every variable resolved.

    Documentation and search read this rather than the written annotations,
    so an unannotated declaration still has the signature the compiler gave
    it, and an annotated one is reported exactly as the compiler understood
    it rather than as it was spelled. -}
finalSchemes :: CheckerState -> [(Text, Scheme)]
finalSchemes state = case reverse (stateFrames state) of
  [] -> []
  moduleFrame : _ -> map resolveScheme (Map.toList moduleFrame)
 where
  resolveScheme (name, scheme) =
    (name, scheme{schemeType = resolveFinal (stateSubstitution state) (schemeType scheme)})

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
    , stateUnsafeFrames = []
    , stateLoopFrames = []
    , stateClosureDepths = []
    , stateReportedSpans = []
    , stateUnsafeFunctions = Map.empty
    , stateComptimeFunctions = Map.empty
    , stateRequiredArity = Map.empty
    , stateInComptime = False
    , stateObligations = []
    , stateIntegerLiterals = []
    , stateIntegerKinds = []
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

{-| Remember what inference settled on for a literal, so evaluation can build
    it as the type it is rather than as the type it was spelled. -}
{-| The whole span is the key, not its offsets. Two files hold a literal at the
    same offsets all the time, and the evaluator reads one table for a program
    and every module it depends on. -}
recordIntegerKind :: Span -> Text -> Checker ()
recordIntegerKind spanValue name =
  Checker $ \state ->
    ((), state{stateIntegerKinds = (spanValue, name) : stateIntegerKinds state})

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
  resolved <- resolveRemembering variable
  selected <- case resolved of
    VariableType unresolved -> do
      setVariable unresolved integerType
      pure integerType
    other -> pure other
  case selected of
    NominalType identity []
      | nominalModule identity == Nothing -> do
          recordIntegerKind spanValue (nominalName identity)
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

{-| What a variable stands for, remembering it for every link on the way.

    The companion to the compression in [[Type Unify]]'s `shallow`, and needed
    with it rather than instead of it: one walks chains through the checker's
    state and the other through `resolveFinal`, which is an ordinary function
    and cannot write anything back. Shortening either alone leaves the other
    walking the same chains, which is why neither showed a gain on its own. -}
resolveRemembering :: TypeVar -> Checker Type
resolveRemembering variable = do
  solved <- resolveVariable variable
  case solved of
    Nothing -> pure (VariableType variable)
    Just (VariableType next) -> do
      endpoint <- resolveRemembering next
      case endpoint of
        VariableType other | other == variable -> pure endpoint
        _ -> do
          setVariable variable endpoint
          pure endpoint
    Just found -> pure found


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

{-| Whether any name is bound beneath this qualifier.

    A module alias has no type of its own, so the only way to tell
    `Std.Text.thing` — a member that does not exist — from `value.thing` on an
    unresolved value is to ask whether anything at all is bound under the
    qualifier. If something is, the qualifier names a module and the member is
    the mistake. -}
qualifiesSomething :: Text -> Checker Bool
qualifiesSomething qualifier =
  Checker $ \state -> (any covered (stateFrames state), state)
 where
  prefix = qualifier <> "."
  covered frame = any (Text.isPrefixOf prefix) (Map.keys frame)

{-| Run an action as the body of a closure, remembering how deep the name
    frames were when it began. -}
insideClosure :: Checker a -> Checker a
insideClosure action = do
  push
  value <- action
  pop
  pure value
 where
  push =
    Checker $ \state ->
      ((), state{stateClosureDepths = length (stateFrames state) : stateClosureDepths state})
  pop =
    Checker $ \state -> case stateClosureDepths state of
      _ : rest -> ((), state{stateClosureDepths = rest})
      [] -> ((), state)

{-| Whether this name was declared outside the closure now being checked.

    Frames are innermost first, so the frames belonging to everything outside
    the closure are the last ones — as many as there were when it began. A name
    found among those was captured rather than declared here. -}
capturedFromOutside :: Text -> Checker Bool
capturedFromOutside name = Checker $ \state ->
  case stateClosureDepths state of
    [] -> (False, state)
    depth : _ ->
      let frames = stateFrames state
          found = [index | (index, frame) <- zip [0 ..] frames, Map.member name frame]
       in case found of
            [] -> (False, state)
            index : _ -> (index >= length frames - depth, state)

{-| Run an action in a fresh name frame; the frame is discarded on exit. -}
inTypeScope :: Checker a -> Checker ()
inTypeScope action = () <$ inTypeScopeWith action

{-| A scope that answers with what its action produced.

    A function literal needs this: its type is computed inside the scope its
    parameters live in, and discarding the answer would mean recomputing it
    outside where the parameters are gone. -}
inTypeScopeWith :: Checker a -> Checker a
inTypeScopeWith action = do
  push
  value <- action
  pop
  pure value
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

{-| A variant of one named type.

    Asked when the type is already known, which is the case wherever the
    constructor was reached through a name that was in scope. Two modules
    declaring a variant of the same name are then two different questions with
    two different answers rather than one question whose answer depends on load
    order. -}
lookupVariantIn :: NominalId -> Text -> Checker (Maybe (NominalId, [Text], [Type]))
lookupVariantIn owner name =
  Checker $ \state ->
    (Map.lookup (owner, name) (declaredOwnedVariants (stateDeclared state)), state)

{-| The names a variant declared for its payload, when it declared any.

    A variant written `Circle{ r: Int }` carries the same positional payload a
    variant written `Circle(Int)` does; the names are how a construction and a
    pattern may say which element they mean. A variant with no names is absent
    here rather than present and empty, because writing `Circle{}` for a
    positional variant is a different mistake from leaving a field out. -}
lookupVariantFields :: Text -> Checker (Maybe [Text])
lookupVariantFields name =
  Checker $ \state -> (Map.lookup name (declaredVariantFields (stateDeclared state)), state)

{-| Record the type an expression was given, so tooling can report it. -}
recordExpression :: Span -> Type -> Checker ()
recordExpression spanValue typeValue =
  Checker $ \state ->
    ((), state{stateTypes = (keyOf spanValue, typeValue) : stateTypes state})

{-| Read the type recorded for an expression while inference is still live.
    Deferred collection checks use the original type variable here, then
    `zonk` it after the surrounding expression has supplied its context. -}
lookupRecordedExpression :: Span -> Checker (Maybe Type)
lookupRecordedExpression spanValue =
  Checker $ \state -> (lookup (keyOf spanValue) (stateTypes state), state)

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

{-| @Type.Env.LoopFrame — one enclosing loop, as `break` sees it.

    `frameResult` is the type the loop produces, which every `break` that
    leaves it must agree on. `frameCarries` says whether a value may be carried
    at all: `loop` produces what its breaks carry, while `while` and `for` can
    finish without reaching a `break` and so have nothing to produce. -}
data LoopFrame = LoopFrame
  { frameLabel :: !(Maybe Text)
  , frameResult :: !Type
  , frameCarries :: !Bool
  , frameBroken :: !Bool
  }
  deriving stock (Eq, Show)

{-| Enter a loop, and leave it reporting whether anything broke out of it. -}
enterLoop :: Maybe Text -> Type -> Bool -> Checker ()
enterLoop label result carries =
  Checker $ \state ->
    ( ()
    , state
        { stateLoopFrames =
            LoopFrame{frameLabel = label, frameResult = result, frameCarries = carries, frameBroken = False}
              : stateLoopFrames state
        }
    )

leaveLoop :: Checker Bool
leaveLoop =
  Checker $ \state -> case stateLoopFrames state of
    [] -> (False, state)
    frame : rest -> (frameBroken frame, state{stateLoopFrames = rest})

{-| The loop a `break` or `continue` acts on: the one its label names, or the
    innermost when it names none. -}
loopTarget :: Maybe Text -> Checker (Maybe LoopFrame)
loopTarget label =
  Checker $ \state -> (pick (stateLoopFrames state), state)
 where
  pick frames = case label of
    Nothing -> case frames of
      [] -> Nothing
      frame : _ -> Just frame
    Just name -> case filter ((== Just name) . frameLabel) frames of
      [] -> Nothing
      frame : _ -> Just frame

{-| Record that some `break` left the loop a label names, so a `loop` whose
    body never breaks can be told apart from one that does. -}
markLoopBroken :: Maybe Text -> Checker ()
markLoopBroken label =
  Checker $ \state -> ((), state{stateLoopFrames = map mark (stateLoopFrames state)})
 where
  mark frame
    | matches frame = frame{frameBroken = True}
    | otherwise = frame
  matches frame = case label of
    Nothing -> True
    Just name -> frameLabel frame == Just name

{-| Type-check an action as though no loop encloses it.

    A function body written inside a loop is not inside it: the closure may
    outlive the loop entirely, so a `break` in one leaves nothing. -}
withoutLoops :: Checker a -> Checker a
withoutLoops action = do
  saved <- Checker $ \state -> (stateLoopFrames state, state{stateLoopFrames = []})
  result <- action
  Checker $ \state -> ((), state{stateLoopFrames = saved})
  pure result

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
{-| Record a declared function and whether it may run at compile time. -}
recordComptimeFunction :: Text -> Bool -> Checker ()
recordComptimeFunction name folds =
  Checker $ \state ->
    ((), state{stateComptimeFunctions = Map.insert name folds (stateComptimeFunctions state)})

{-| Record how many arguments a declared name must be given, and how many it
    declares in all.

    Both, because the table is keyed by the bare name and a parameter may carry
    the same one as a declaration elsewhere. The total is what identifies which
    of them a call actually reached: a predicate parameter named `holds` takes
    one argument where the declaration named `holds` takes two, and checking the
    first against the second refused correct code. -}
recordRequiredArity :: Text -> (Int, Int) -> Checker ()
recordRequiredArity name counts =
  Checker $ \state ->
    ((), state{stateRequiredArity = Map.insert name counts (stateRequiredArity state)})

{-| How many arguments this name must be given and how many it declares, where
    that is known. -}
requiredArityOf :: Text -> Checker (Maybe (Int, Int))
requiredArityOf name =
  Checker $ \state -> (Map.lookup name (stateRequiredArity state), state)

{-| What is known about calling this name from a compile-time body.

    `Nothing` means nothing is known, which is the answer for a parameter or a
    local and is not the same as "no". -}
isComptimeFunction :: Text -> Checker (Maybe Bool)
isComptimeFunction name =
  Checker $ \state -> (Map.lookup name (stateComptimeFunctions state), state)

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

{-| Give a second name for a function the restrictions the first one carries.

    A name reached through its module is the same function as the name reached
    directly, and what it is allowed to do cannot depend on how it was spelled.
    Without this, an unsafe function stopped being unsafe the moment it was
    imported, and a compile-time one stopped being compile-time — the boundary
    held inside a module and dissolved at its edge, which is the edge that
    matters. -}
inheritRestrictions :: Text -> Text -> Checker ()
inheritRestrictions from to =
  Checker $ \state ->
    let carried = case Map.lookup from (stateUnsafeFunctions state) of
          Just capabilities -> Map.insert to capabilities (stateUnsafeFunctions state)
          Nothing -> stateUnsafeFunctions state
        folded = case Map.lookup from (stateComptimeFunctions state) of
          Just known -> Map.insert to known (stateComptimeFunctions state)
          Nothing -> stateComptimeFunctions state
     in ((), state{stateUnsafeFunctions = carried, stateComptimeFunctions = folded})

{-| Whether this span has already carried a diagnostic of its own.

    A signature is formed twice — once when the module declares it, once when
    the body is checked against it — and a mistake written in a signature is
    one mistake however many times the checker walks it.

    Keyed by code as well as span, so suppressing a repeat of one diagnostic
    never hides a different one that happens to point at the same text. -}
reportedAt :: Span -> Text -> Checker Bool
reportedAt spanValue code =
  Checker $ \state ->
    let key = ((unOffset (spanStart spanValue), unOffset (spanEnd spanValue)), code)
        seen = key `elem` stateReportedSpans state
     in (seen, state{stateReportedSpans = key : stateReportedSpans state})

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
