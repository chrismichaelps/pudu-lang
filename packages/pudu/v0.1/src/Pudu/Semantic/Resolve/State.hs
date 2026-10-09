{-| @Semantic.Resolve.State — invocation-owned pure resolver state and actions -}
module Pudu.Semantic.Resolve.State
  ( ResolveState (..)
  , Resolver (..)
  , initialState
  ) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Diagnostic (Diagnostic)
import Pudu.Semantic.Scope (ScopeStack, emptyStack)
import Pudu.Semantic.ScopeIndex (Frame (..))
import Pudu.Semantic.Symbol (Namespace, Reference, Symbol, SymbolId)

{-| @Semantic.Resolve.State — the resolver's private working state -}
data ResolveState = ResolveState
  { stateAmbiguous :: ![Text]
  , stateNext :: !Int
  , stateScopes :: !ScopeStack
  , stateLoops :: ![Maybe Text]
  , stateSymbolsRev :: ![Symbol]
  , stateReferencesRev :: ![Reference]
  , stateDiagnosticsRev :: ![Diagnostic]
  {-| The frames open now, innermost first, by the identity each was given. -}
  , stateFrames :: ![Int]
  , stateFramesRev :: ![(Int, Frame)]
  {-| Each binding's frame, the offset it is visible after, and its symbol. -}
  , stateBindingsRev :: ![(Int, Int, SymbolId)]
  {-| Where the bindings being declared now become visible, when that is later
      than their names: a `let` is visible after its statement. -}
  , stateVisibleAfter :: !(Maybe Int)
  {-| Canonical reflection imports, including selections, classified once.
      Uses are checked against the resolved namespace and symbol origin. -}
  , stateReflectionImports :: !(Set (Namespace, Text))
  {-| Whether a derive definition's members are being walked. Compile-time
      reflection is refused everywhere else, because only derivation unrolls
      the code that names it. -}
  , stateInDerive :: !Bool
  , stateCanonicalTypes :: !Bool
  , stateModuleQualifiers :: !(Set SymbolId)
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
    , stateFrames = [0]
    , stateFramesRev = [(0, Frame Nothing Nothing)]
    , stateBindingsRev = []
    , stateVisibleAfter = Nothing
    , stateReflectionImports = Set.empty
    , stateInDerive = False
    , stateCanonicalTypes = False
    , stateModuleQualifiers = Set.empty
    }
