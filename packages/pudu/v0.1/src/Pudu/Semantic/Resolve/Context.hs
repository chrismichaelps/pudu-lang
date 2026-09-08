{-| @Semantic.Resolve.Context — owns resolver state and diagnostics -}
module Pudu.Semantic.Resolve.Context
  ( Resolver
  , ResolverProducts (..)
  , declareBuiltin
  , declarePreludeName
  , declareNamed
  , inScope
  , insideLoop
  , markAmbiguousVariant
  , outsideLoops
  , recordVariantSymbol
  , resolveLoopTarget
  , resolveExpressionName
  , resolveTypeName
  , resolveValueName
  , runResolver
  ) where

import Data.Text (Text)
import Pudu.Diagnostic
  ( Diagnostic
  , Related (..)
  , Severity (Error, Warning)
  , diagnostic
  , mkDiagnosticCode
  , sortDiagnostics
  , withHelp
  , withRelated
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Visibility (Private))
import Pudu.Semantic.Scope
  ( ScopeStack
  , declareSymbol
  , emptyStack
  , lookupSymbol
  , popScope
  , pushScope
  )
import Pudu.Semantic.Symbol
  ( Namespace (..)
  , Reference (..)
  , Symbol (..)
  , SymbolId (..)
  , SymbolOrigin (..)
  , isShadowWarned
  )
import Pudu.Source (Span)

{-| @Semantic.Resolve.State — the resolver's private working state -}
data ResolveState = ResolveState
  { stateAmbiguous :: ![Text]
  , stateNext :: !Int
  , stateScopes :: !ScopeStack
  , stateLoops :: ![Maybe Text]
  , stateSymbolsRev :: ![Symbol]
  , stateReferencesRev :: ![Reference]
  , stateDiagnosticsRev :: ![Diagnostic]
  }

{-| @Semantic.Resolve.Products — everything one resolution run produced -}
data ResolverProducts = ResolverProducts
  { producedSymbols :: ![Symbol]
  , producedReferences :: ![Reference]
  , producedDiagnostics :: ![Diagnostic]
  }

{-| @Semantic.Resolve.Action — threads resolver state explicitly -}
newtype Resolver a = Resolver (ResolveState -> (a, ResolveState))

instance Functor Resolver where
  fmap transform (Resolver action) =
    Resolver $ \state -> let (value, next) = action state in (transform value, next)

instance Applicative Resolver where
  pure value = Resolver $ \state -> (value, state)
  Resolver leftAction <*> Resolver rightAction =
    Resolver $ \state ->
      let (transform, afterLeft) = leftAction state
          (value, afterRight) = rightAction afterLeft
       in (transform value, afterRight)

instance Monad Resolver where
  Resolver action >>= continue =
    Resolver $ \state ->
      let (value, next) = action state
          Resolver continued = continue value
       in continued next

runResolver :: Resolver a -> ResolverProducts
runResolver (Resolver action) =
  let (_, finalState) = action initialState
   in ResolverProducts
        { producedSymbols = reverse (stateSymbolsRev finalState)
        , producedReferences = reverse (stateReferencesRev finalState)
        , producedDiagnostics = sortDiagnostics (reverse (stateDiagnosticsRev finalState))
        }

initialState :: ResolveState
initialState =
  ResolveState
    { stateAmbiguous = []
    , stateNext = 0
    , stateScopes = emptyStack
    , stateLoops = []
    , stateSymbolsRev = []
    , stateReferencesRev = []
    , stateDiagnosticsRev = []
    }

{-| Run an action inside one more enclosing loop.

    Labels live on their own stack rather than in the ordinary scope, because
    they are not names: nothing evaluates a label, nothing shadows a value with
    one, and a label is legal only in the two statements that can name it. The
    stack runs innermost first, which is the order `break` searches.

    A label repeating one already enclosing it is a warning rather than an
    error. The program still means something definite — the inner label wins,
    since it is nearer — but the outer loop has become unreachable by name, and
    that is almost always a mistake in the making rather than a plan. -}
insideLoop :: Maybe (Located Text) -> Resolver a -> Resolver a
insideLoop label action = do
  enclosing <- readLoops
  case label of
    Just (Located spanValue name)
      | Just name `elem` enclosing ->
          emit "W2002" Warning spanValue ("label @" <> name <> " shadows an enclosing label")
            (Just "give one of the two loops a different label")
    _ -> pure ()
  modifyLoops (fmap locatedValue label :)
  result <- action
  modifyLoops (drop 1)
  pure result

{-| Check that a `break` or `continue` has a loop to act on.

    Both failures are reported here rather than left to run time. A `break`
    outside every loop is not a program that might work on some input: there is
    no loop to leave on any path, and the reader learns that sooner from the
    compiler than from a program that ran halfway first. -}
resolveLoopTarget :: Text -> Span -> Maybe (Located Text) -> Resolver ()
resolveLoopTarget keyword spanValue label = do
  enclosing <- readLoops
  case (enclosing, label) of
    ([], _) ->
      emit "E2016" Error spanValue (keyword <> " is not inside a loop")
        (Just ("write " <> keyword <> " inside `loop`, `while`, or `for`"))
    (_, Nothing) -> pure ()
    (_, Just (Located labelSpan name))
      | Just name `elem` enclosing -> pure ()
      | otherwise ->
          emit "E2017" Error labelSpan ("no enclosing loop is labelled @" <> name)
            (Just "label the loop you meant, or drop the label to leave the nearest one")

{-| Run an action with no enclosing loop, whatever surrounds it.

    A function body is not inside the loop that happens to contain its
    definition. A closure written in a loop and called long after it has
    finished cannot leave a loop that is no longer running, so `break` inside
    one is out of every loop even when the text around it is not. -}
outsideLoops :: Resolver a -> Resolver a
outsideLoops action = do
  enclosing <- readLoops
  modifyLoops (const [])
  result <- action
  modifyLoops (const enclosing)
  pure result

readLoops :: Resolver [Maybe Text]
readLoops = Resolver $ \state -> (stateLoops state, state)

modifyLoops :: ([Maybe Text] -> [Maybe Text]) -> Resolver ()
modifyLoops transform =
  Resolver $ \state -> ((), state{stateLoops = transform (stateLoops state)})

{-| Run an action inside a fresh lexical frame. The frame is discarded on exit,
    so nothing a nested scope declared can leak outward. -}
inScope :: Resolver a -> Resolver ()
inScope action = do
  modifyScopes pushScope
  _ <- action
  modifyScopes popScope

modifyScopes :: (ScopeStack -> ScopeStack) -> Resolver ()
modifyScopes transform =
  Resolver $ \state -> ((), state{stateScopes = transform (stateScopes state)})

declareBuiltin :: Namespace -> Text -> Resolver ()
declareBuiltin namespace name =
  introduce namespace BuiltinOrigin Private False name Nothing

{-| A prelude name is an ordinary library binding: it may be shadowed by a
    module declaration without conflict or warning. -}
declarePreludeName :: Namespace -> Text -> Resolver ()
declarePreludeName namespace name =
  introduce namespace PreludeOrigin Private False name Nothing

declareNamed :: Namespace -> SymbolOrigin -> Visibility -> Bool -> Located Text -> Resolver ()
declareNamed namespace origin visibility mutable name =
  introduce namespace origin visibility mutable (locatedValue name) (Just (locatedSpan name))

{-| Introduce a symbol, reporting a same-frame duplicate as `E2001` with the
    first declaration attached, and an outer shadow as `W2001` when the
    displaced binding is one the language warns about. -}
introduce :: Namespace -> SymbolOrigin -> Visibility -> Bool -> Text -> Maybe Span -> Resolver ()
introduce namespace origin visibility mutable name spanValue = do
  symbol <- freshSymbol namespace origin visibility mutable name spanValue
  shadowed <- lookupCurrent namespace name
  previous <- insertSymbol symbol
  recordSymbol symbol
  case (previous, spanValue) of
    (Just earlier, Just here) -> duplicateDeclaration name here (symbolSpan earlier)
    _ -> case (shadowed, spanValue) of
      (Just outer, Just here) | isShadowWarned outer -> shadowWarning name here
      _ -> pure ()

{-| A variant is namespaced by its type and is additionally bound unqualified
    while that spelling is unambiguous, which is the rule [[grammar/pudu]]
    states: qualification is required only when two types share a variant name. -}
recordVariantSymbol :: Located Text -> Resolver ()
recordVariantSymbol name =
  introduce ValueSpace VariantOrigin Private False (locatedValue name) (Just (locatedSpan name))

{-| Record that a variant spelling is declared by more than one type. A use of
    it reports `E2012` and asks for qualification instead of resolving to
    whichever declaration happened to be seen last. -}
markAmbiguousVariant :: Text -> Resolver ()
markAmbiguousVariant name =
  Resolver $ \state -> ((), state{stateAmbiguous = name : stateAmbiguous state})

freshSymbol
  :: Namespace -> SymbolOrigin -> Visibility -> Bool -> Text -> Maybe Span -> Resolver Symbol
freshSymbol namespace origin visibility mutable name spanValue = do
  identifier <- freshId
  pure
    Symbol
      { symbolId = identifier
      , symbolName = name
      , symbolNamespace = namespace
      , symbolOrigin = origin
      , symbolMutable = mutable
      , symbolVisibility = visibility
      , symbolSpan = spanValue
      }

{-| A value name may resolve through the type namespace, which is how a
    qualified path such as `Outcome.Ok` reaches its declaring type. -}
resolveValueName :: Span -> Text -> Resolver ()
resolveValueName spanValue name = do
  ambiguous <- isAmbiguous name
  if ambiguous
    then
      emit "E2012" Error spanValue ("ambiguous variant name " <> name)
        (Just "qualify the variant with its type, as in Type.Variant")
    else resolveUnambiguous spanValue name

{-| Resolve a name that must itself produce a runtime value.

    Constructor paths use the more permissive operation above because their
    first segment intentionally names a type. A plain expression has no such
    reading: recording a type reference here would let checking succeed even
    though evaluation has no value binding to read. -}
resolveExpressionName :: Span -> Text -> Resolver ()
resolveExpressionName spanValue name = do
  ambiguous <- isAmbiguous name
  if ambiguous
    then
      emit "E2012" Error spanValue ("ambiguous variant name " <> name)
        (Just "qualify the variant with its type, as in Type.Variant")
    else do
      value <- lookupCurrent ValueSpace name
      case value of
        Just symbol -> recordReference (Reference spanValue (symbolId symbol))
        Nothing -> do
          typeSymbol <- lookupCurrent TypeSpace name
          case typeSymbol of
            Just _ ->
              emit "E2010" Error spanValue (name <> " is a type, not a value")
                (Just "use the type in an annotation or construct one of its values")
            Nothing ->
              emit "E2010" Error spanValue ("unresolved value name " <> name)
                (Just "declare the name, import it, or check the spelling")

isAmbiguous :: Text -> Resolver Bool
isAmbiguous name = Resolver $ \state -> (name `elem` stateAmbiguous state, state)

resolveUnambiguous :: Span -> Text -> Resolver ()
resolveUnambiguous spanValue name = do
  value <- lookupCurrent ValueSpace name
  case value of
    Just symbol -> recordReference (Reference spanValue (symbolId symbol))
    Nothing -> do
      typeSymbol <- lookupCurrent TypeSpace name
      case typeSymbol of
        Just symbol -> recordReference (Reference spanValue (symbolId symbol))
        Nothing ->
          emit "E2010" Error spanValue ("unresolved value name " <> name)
            (Just "declare the name, import it, or check the spelling")

resolveTypeName :: Span -> Text -> Resolver ()
resolveTypeName spanValue name = do
  found <- lookupCurrent TypeSpace name
  case found of
    Just symbol -> recordReference (Reference spanValue (symbolId symbol))
    Nothing ->
      emit "E2011" Error spanValue ("unresolved type name " <> name)
        (Just "declare the type, import it, or check the spelling")

freshId :: Resolver SymbolId
freshId = Resolver $ \state ->
  (SymbolId (stateNext state), state{stateNext = stateNext state + 1})

recordSymbol :: Symbol -> Resolver ()
recordSymbol symbol =
  Resolver $ \state -> ((), state{stateSymbolsRev = symbol : stateSymbolsRev state})

insertSymbol :: Symbol -> Resolver (Maybe Symbol)
insertSymbol symbol =
  Resolver $ \state ->
    let (previous, scopes) = declareSymbol symbol (stateScopes state)
     in (previous, state{stateScopes = scopes})

lookupCurrent :: Namespace -> Text -> Resolver (Maybe Symbol)
lookupCurrent namespace name =
  Resolver $ \state -> (lookupSymbol namespace name (stateScopes state), state)

recordReference :: Reference -> Resolver ()
recordReference reference =
  Resolver $ \state ->
    ((), state{stateReferencesRev = reference : stateReferencesRev state})

duplicateDeclaration :: Text -> Span -> Maybe Span -> Resolver ()
duplicateDeclaration name here earlier =
  case build "E2001" Error here ("duplicate declaration of " <> name) duplicateHelp of
    Nothing -> pure ()
    Just value ->
      pushDiagnostic
        ( case earlier of
            Nothing -> value
            Just previous -> withRelated (Related previous "first declared here") value
        )

duplicateHelp :: Maybe Text
duplicateHelp = Just "rename one declaration; a name may be declared once per scope"

shadowWarning :: Text -> Span -> Resolver ()
shadowWarning name spanValue =
  emit "W2001" Warning spanValue ("declaration of " <> name <> " shadows an outer binding")
    (Just "shadowing a var, parameter, import, or type name is discouraged")

emit :: Text -> Severity -> Span -> Text -> Maybe Text -> Resolver ()
emit code severity spanValue message help =
  case build code severity spanValue message help of
    Nothing -> pure ()
    Just value -> pushDiagnostic value

build :: Text -> Severity -> Span -> Text -> Maybe Text -> Maybe Diagnostic
build code severity spanValue message help = do
  validCode <- mkDiagnosticCode code
  value <- diagnostic validCode severity spanValue message
  pure (maybe value (`withHelp` value) help)

pushDiagnostic :: Diagnostic -> Resolver ()
pushDiagnostic value =
  Resolver $ \state -> ((), state{stateDiagnosticsRev = value : stateDiagnosticsRev state})
