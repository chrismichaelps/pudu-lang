{-| @Semantic.Resolve.Context — owns resolver state and diagnostics -}
module Pudu.Semantic.Resolve.Context
  ( Resolver
  , ResolverProducts (..)
  , declareBuiltin
  , declarePreludeName
  , declareNamed
  , inScope
  , recordVariantSymbol
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
  { stateNext :: !Int
  , stateScopes :: !ScopeStack
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
    { stateNext = 0
    , stateScopes = emptyStack
    , stateSymbolsRev = []
    , stateReferencesRev = []
    , stateDiagnosticsRev = []
    }

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

{-| Variants live in their type's namespace: the symbol exists for later phases
    but is never bound as an unqualified name. -}
recordVariantSymbol :: Located Text -> Resolver ()
recordVariantSymbol name = do
  symbol <-
    freshSymbol ValueSpace VariantOrigin Private False
      (locatedValue name) (Just (locatedSpan name))
  recordSymbol symbol

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
