{-| @Semantic.Scope.Module — owns pure lexical frames -}
module Pudu.Semantic.Scope
  ( ScopeStack
  , declareSymbol
  , emptyStack
  , lookupSymbol
  , popScope
  , pushScope
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Semantic.Symbol (Namespace, Symbol (..))

{-| @Semantic.Scope.Frame — one lexical level -}
type Frame = Map (Namespace, Text) Symbol

{-| @Semantic.Scope.Stack — innermost frame first -}
newtype ScopeStack = ScopeStack [Frame]
  deriving stock (Eq, Show)

emptyStack :: ScopeStack
emptyStack = ScopeStack [Map.empty]

pushScope :: ScopeStack -> ScopeStack
pushScope (ScopeStack frames) = ScopeStack (Map.empty : frames)

{-| Popping the last frame yields an empty stack rather than failing; the
    resolver's structure keeps pushes and pops balanced, and a partial function
    here would turn a recovery path into a crash. -}
popScope :: ScopeStack -> ScopeStack
popScope (ScopeStack frames) = case frames of
  _ : rest@(_ : _) -> ScopeStack rest
  _ -> emptyStack

{-| Insert into the innermost frame, reporting only a same-frame predecessor.
    Shadowing an outer frame is legal and is classified by the caller. -}
declareSymbol :: Symbol -> ScopeStack -> (Maybe Symbol, ScopeStack)
declareSymbol symbol (ScopeStack frames) = case frames of
  [] -> (Nothing, ScopeStack [Map.singleton (key symbol) symbol])
  current : rest ->
    ( Map.lookup (key symbol) current
    , ScopeStack (Map.insert (key symbol) symbol current : rest)
    )

lookupSymbol :: Namespace -> Text -> ScopeStack -> Maybe Symbol
lookupSymbol namespace name (ScopeStack frames) =
  case frames of
    [] -> Nothing
    current : rest ->
      case Map.lookup (namespace, name) current of
        Just found -> Just found
        Nothing -> lookupSymbol namespace name (ScopeStack rest)

key :: Symbol -> (Namespace, Text)
key symbol = (symbolNamespace symbol, symbolName symbol)
