{-| @Semantic.Resolve.Context — owns resolver state and diagnostics -}
module Pudu.Semantic.Resolve.Context
  ( Resolver
  , ResolverProducts (..)
  , declareBuiltin
  , declarePreludeName
  , declareNamed
  , declareModuleQualifier
  , inScope
  , inScopeOver
  , visibleAfter
  , insideLoop
  , markAmbiguousVariant
  , outsideLoops
  , recordVariantSymbol
  , resolveLoopTarget
  , resolveExpressionName
  , resolveTypeName
  , resolveValueName
  , setReflectionImports
  , declareLoopTypeParameter
  , declareReflectedTypeParameter
  , inDeriveDefinition
  , withDeriveDefinition
  , withCanonicalTypes
  , canonicalTypesInScope
  , runResolver
  ) where

import Data.Maybe (listToMaybe)
import qualified Data.Set as Set
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
import Pudu.Frontend.Syntax.Tree (Import (..), TypeSyntax, Visibility (Private))
import Pudu.Semantic.Resolve.State (ResolveState (..), Resolver (..), initialState)
import Pudu.Semantic.Resolve.Reflection (reflectionImports, fieldTypeParameter)
import Pudu.Semantic.Scope
  ( declareSymbol
  , lookupSymbol
  , popScope
  , pushScope
  )
import Pudu.Semantic.ScopeIndex (Frame (..), ScopeIndex, scopeIndex)
import Pudu.Semantic.Symbol
  ( Namespace (..)
  , Reference (..)
  , Symbol (..)
  , SymbolId (..)
  , SymbolOrigin (..)
  , isShadowWarned
  )
import Pudu.Source (Span, spanStart, unOffset)

{-| @Semantic.Resolve.Products — everything one resolution run produced -}
data ResolverProducts = ResolverProducts
  { producedSymbols :: ![Symbol]
  , producedReferences :: ![Reference]
  , producedDiagnostics :: ![Diagnostic]
  , producedScopes :: !ScopeIndex
  }

runResolver :: Resolver a -> ResolverProducts
runResolver (Resolver action) =
  let (_, finalState) = action initialState
   in ResolverProducts
        { producedSymbols = reverse (stateSymbolsRev finalState)
        , producedReferences = reverse (stateReferencesRev finalState)
        , producedDiagnostics = sortDiagnostics (reverse (stateDiagnosticsRev finalState))
        , producedScopes = scopeIndex (stateFramesRev finalState) (stateBindingsRev finalState)
        }

{-| Labels have an independent stack; duplicate labels warn but select the
    innermost enclosing loop. -}
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

{-| A closure cannot transfer control into the loop enclosing its definition. -}
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

setReflectionImports :: [Located Import] -> Resolver ()
setReflectionImports imports =
  Resolver $ \state -> ((), state{stateReflectionImports = reflectionImports imports})

{-| A repeated constraint augments a type parameter rather than declaring it
    again. Enclosing parameters retain their identity inside nested loops. -}
declareLoopTypeParameter :: Located Text -> Resolver ()
declareLoopTypeParameter name = do
  existing <- lookupCurrent TypeSpace (locatedValue name)
  case existing of
    Just _ -> pure ()
    Nothing -> declareNamed TypeSpace TypeParamOrigin Private False name

declareReflectedTypeParameter :: Located TypeSyntax -> Resolver ()
declareReflectedTypeParameter annotation = case fieldTypeParameter annotation of
  Nothing -> pure ()
  Just (qualifier, parameter) -> do
    found <- lookupCurrent TypeSpace qualifier
    reflection <- Resolver $ \state ->
      (Set.member (TypeSpace, qualifier) (stateReflectionImports state), state)
    case found of
      Just symbol | reflection && symbolOrigin symbol == ImportOrigin -> declareLoopTypeParameter parameter
      _ -> pure ()

inDeriveDefinition :: Resolver Bool
inDeriveDefinition = Resolver $ \state -> (stateInDerive state, state)

modifyDerive :: (Bool -> Bool) -> Resolver ()
modifyDerive transform =
  Resolver $ \state -> ((), state{stateInDerive = transform (stateInDerive state)})

{-| Run an action inside a derive definition, restoring the previous setting
    on exit so a nested ordinary declaration is unaffected. -}
withDeriveDefinition :: Bool -> Resolver a -> Resolver a
withDeriveDefinition inside action = do
  previous <- inDeriveDefinition
  modifyDerive (const inside)
  result <- action
  modifyDerive (const previous)
  pure result

canonicalTypesInScope :: Resolver Bool
canonicalTypesInScope = Resolver $ \state -> (stateCanonicalTypes state, state)

withCanonicalTypes :: Bool -> Resolver a -> Resolver a
withCanonicalTypes formed (Resolver action) = Resolver $ \state ->
  let (result, next) = action state{stateCanonicalTypes = formed}
   in (result, next{stateCanonicalTypes = stateCanonicalTypes state})

{-| Check the symbol actually selected, once, for every expression/type path.
    Syntactic member checks miss selected imports and first-class values. -}
recordResolvedReference :: Span -> Symbol -> Resolver ()
recordResolvedReference at symbol = do
  recordReference (Reference at (symbolId symbol))
  restricted <- reflectionRestricted symbol
  if restricted
    then emit "E2018" Error at
      ("compile-time reflection `" <> symbolName symbol <> "` is only named from derive definitions")
      (Just "move the reflection into a derive body")
    else pure ()

reflectionRestricted :: Symbol -> Resolver Bool
reflectionRestricted symbol = Resolver $ \state ->
    ( not (stateInDerive state)
        && symbolOrigin symbol == ImportOrigin
        && Set.member (symbolNamespace symbol, symbolName symbol) (stateReflectionImports state)
    , state
    )

{-| Run an action inside a fresh lexical frame. The frame is discarded on exit,
    so nothing a nested scope declared can leak outward. -}
inScope :: Resolver a -> Resolver ()
inScope = inScopeOver Nothing

{-| `inScope` for a frame that covers the offsets `extent` names, both ends
    included. The frame is recorded with its extent, so which names are visible
    at a position can be asked after resolution has left it. -}
inScopeOver :: Maybe (Int, Int) -> Resolver a -> Resolver ()
inScopeOver extent action = do
  Resolver $ \state ->
    let frame = maybe 0 ((+ 1) . fst) (listToMaybe (stateFramesRev state))
     in ( ()
        , state
            { stateScopes = pushScope (stateScopes state)
            , stateFrames = frame : stateFrames state
            , stateFramesRev = (frame, Frame (listToMaybe (stateFrames state)) extent) : stateFramesRev state
            }
        )
  _ <- action
  Resolver $ \state ->
    ((), state{stateScopes = popScope (stateScopes state), stateFrames = drop 1 (stateFrames state)})

{-| Declare, inside `action`, bindings that become visible only after `offset`. -}
visibleAfter :: Int -> Resolver a -> Resolver a
visibleAfter offset action = do
  previous <- Resolver $ \state -> (stateVisibleAfter state, state{stateVisibleAfter = Just offset})
  result <- action
  Resolver $ \state -> ((), state{stateVisibleAfter = previous})
  pure result

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

declareModuleQualifier :: Located Text -> Resolver ()
declareModuleQualifier name = do
  declareNamed ValueSpace ImportOrigin Private False name
  found <- lookupCurrent ValueSpace (locatedValue name)
  case found of
    Nothing -> pure ()
    Just symbol -> Resolver $ \state ->
      ((), state{stateModuleQualifiers = Set.insert (symbolId symbol) (stateModuleQualifiers state)})

{-| Introduce a symbol, reporting a same-frame duplicate as `E2001` with the
    first declaration attached, and an outer shadow as `W2001` when the
    displaced binding is one the language warns about. -}
introduce :: Namespace -> SymbolOrigin -> Visibility -> Bool -> Text -> Maybe Span -> Resolver ()
introduce namespace origin visibility mutable name spanValue = do
  symbol <- freshSymbol namespace origin visibility mutable name spanValue
  shadowed <- lookupCurrent namespace name
  previous <- insertSymbol symbol
  recordSymbol symbol
  recordBinding origin symbol
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
        Just symbol -> resolveExpressionReference spanValue symbol
        Nothing -> do
          typeSymbol <- lookupCurrent TypeSpace name
          case typeSymbol of
            Just _ ->
              emit "E2010" Error spanValue (name <> " is a type, not a value")
                (Just "use the type in an annotation or construct one of its values")
            Nothing ->
              emit "E2010" Error spanValue ("unresolved value name " <> name)
                (Just "declare the name, import it, or check the spelling")

resolveExpressionReference :: Span -> Symbol -> Resolver ()
resolveExpressionReference at symbol = do
  qualifier <- Resolver $ \state ->
    (Set.member (symbolId symbol) (stateModuleQualifiers state), state)
  if qualifier
    then do
      restricted <- reflectionRestricted symbol
      if restricted
        then recordResolvedReference at symbol
        else emit "E2010" Error at (symbolName symbol <> " is a module namespace, not a value")
          (Just "select an exported member with the qualifier, or import a named value")
    else recordResolvedReference at symbol

isAmbiguous :: Text -> Resolver Bool
isAmbiguous name = Resolver $ \state -> (name `elem` stateAmbiguous state, state)

resolveUnambiguous :: Span -> Text -> Resolver ()
resolveUnambiguous spanValue name = do
  value <- lookupCurrent ValueSpace name
  case value of
    Just symbol -> recordResolvedReference spanValue symbol
    Nothing -> do
      typeSymbol <- lookupCurrent TypeSpace name
      case typeSymbol of
        Just symbol -> recordResolvedReference spanValue symbol
        Nothing ->
          emit "E2010" Error spanValue ("unresolved value name " <> name)
            (Just "declare the name, import it, or check the spelling")

resolveTypeName :: Span -> Text -> Resolver ()
resolveTypeName spanValue name = do
  found <- lookupCurrent TypeSpace name
  case found of
    Just symbol -> recordResolvedReference spanValue symbol
    Nothing ->
      emit "E2011" Error spanValue ("unresolved type name " <> name)
        (Just "declare the type, import it, or check the spelling")

freshId :: Resolver SymbolId
freshId = Resolver $ \state ->
  (SymbolId (stateNext state), state{stateNext = stateNext state + 1})

{-| Record where a binding lives and from where it is visible. Names the module
    level declares are visible throughout, because the walk is two-pass there. -}
recordBinding :: SymbolOrigin -> Symbol -> Resolver ()
recordBinding origin symbol =
  Resolver $ \state ->
    let visible
          | origin `elem` [ParameterOrigin, LocalOrigin, PatternOrigin, TypeParamOrigin] =
              case stateVisibleAfter state of
                Just offset -> offset
                Nothing -> maybe (-1) (unOffset . spanStart) (symbolSpan symbol)
          | otherwise = -1
        frame = case stateFrames state of
          innermost : _ -> innermost
          [] -> 0
     in ((), state{stateBindingsRev = (frame, visible, symbolId symbol) : stateBindingsRev state})

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
