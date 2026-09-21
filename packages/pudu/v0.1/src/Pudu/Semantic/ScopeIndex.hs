{-| @Semantic.ScopeIndex.Module — which bindings are visible at a position -}
module Pudu.Semantic.ScopeIndex
  ( Frame (..)
  , ScopeIndex
  , delimitedExtent
  , emptyScopeIndex
  , spanExtent
  , spanningExtent
  , scopeIndex
  , visibleAt
  ) where

import Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as IntMap
import Data.List (sortOn)
import Data.Ord (Down (..))
import Pudu.Semantic.Symbol (SymbolId)
import Pudu.Source (Span, spanEnd, spanStart, unOffset)

{-| One lexical frame the resolver opened: the frame it was opened inside, and
    the offsets a cursor may stand at while inside it, both ends included.

    A frame with no extent is the module's own, or one opened around every
    declaration, and is inside wherever its parent is. -}
data Frame = Frame
  { frameParent :: !(Maybe Int)
  , frameExtent :: !(Maybe (Int, Int))
  }
  deriving stock (Eq, Show)

{-| The frames of one resolution and the bindings each holds, with the offset
    from which each binding is visible.

    Resolution discards a frame when it leaves it, which is what makes a block's
    `let` invisible after the block; this keeps the frames, so a question asked
    later about a position gets the answer resolution would have given there. -}
data ScopeIndex = ScopeIndex
  { indexFrames :: !(IntMap Frame)
  {-| Per frame, its bindings latest-visible first. -}
  , indexBindings :: !(IntMap [(Int, SymbolId)])
  }
  deriving stock (Eq, Show)

{-| The extent of a frame whose text is the whole span: an arm, a closure, a
    declaration. A cursor at its end is still writing its last expression. -}
spanExtent :: Span -> Maybe (Int, Int)
spanExtent spanValue = Just (unOffset (spanStart spanValue), unOffset (spanEnd spanValue))

{-| The extent from the start of one span through the end of another: an
    `if let`'s pattern through its block, where what the pattern binds is
    visible. -}
spanningExtent :: Span -> Span -> Maybe (Int, Int)
spanningExtent from through = Just (unOffset (spanStart from), unOffset (spanEnd through))

{-| The extent of a braced block: inside the braces, not before the opening
    one or after the closing one. -}
delimitedExtent :: Span -> Maybe (Int, Int)
delimitedExtent spanValue = Just (unOffset (spanStart spanValue) + 1, unOffset (spanEnd spanValue) - 1)

emptyScopeIndex :: ScopeIndex
emptyScopeIndex = ScopeIndex IntMap.empty IntMap.empty

{-| Assemble the index from the frames and the bindings the resolver recorded,
    each binding as its frame, the offset it becomes visible after, and its
    symbol. A `let` becomes visible after its statement ends, so a cursor still
    writing the initializer is not offered the name being declared. -}
scopeIndex :: [(Int, Frame)] -> [(Int, Int, SymbolId)] -> ScopeIndex
scopeIndex frames bindings =
  ScopeIndex
    (IntMap.fromList frames)
    ( IntMap.map (sortOn (Down . fst))
        (IntMap.fromListWith (<>) [(frame, [(active, symbol)]) | (frame, active, symbol) <- bindings])
    )

{-| Every binding visible at `offset`, nearest frame first and, within a frame,
    the most recently visible first. A caller that keeps the first binding of
    each name therefore sees exactly what resolution would pick: an inner
    binding shadows an outer one, and a binding whose frame the cursor is not
    in — a sibling block's, another arm's — is absent.

    The innermost frame is the deepest one whose extent, and whose every
    ancestor's extent, holds the cursor. -}
visibleAt :: ScopeIndex -> Int -> [SymbolId]
visibleAt index offset = case innermost of
  Nothing -> []
  Just frame -> concatMap visibleIn (chain frame)
 where
  frames = indexFrames index
  innermost =
    case sortOn (Down . snd) [(frame, depth) | frame <- IntMap.keys frames, Just depth <- [openDepth frame]] of
      (frame, _) : _ -> Just frame
      [] -> Nothing
  -- The frame's depth when the cursor is inside it and every ancestor.
  openDepth frame = case IntMap.lookup frame frames of
    Nothing -> Nothing
    Just (Frame parent extent)
      | maybe True holds extent -> case parent of
          Nothing -> Just (0 :: Int)
          Just above -> (+ 1) <$> openDepth above
      | otherwise -> Nothing
  holds (first, final) = first <= offset && offset <= final
  chain frame = frame : maybe [] chain (IntMap.lookup frame frames >>= frameParent)
  visibleIn frame =
    [symbol | (active, symbol) <- IntMap.findWithDefault [] frame (indexBindings index), active < offset]
