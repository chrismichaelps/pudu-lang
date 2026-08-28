{-| @Source.Text.Module — preserves stable source locations -}
module Pudu.Source
  ( Offset
  , Position (..)
  , Source
  , SourceName (..)
  , Span
  , mergeSpans
  , advanceOffset
  , emptySpan
  , newSource
  , mkSpan
  , offsetFromInt
  , offsetPosition
  , sourceLength
  , sourceName
  , sourceText
  , spanEnd
  , spanSource
  , spanStart
  , unOffset
  , zeroWidthSpan
  , zeroOffset
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Unique (Unique, newUnique)

{-| @Source.Text.Identity — names one immutable source -}
newtype SourceName = SourceName {unSourceName :: Text}
  deriving stock (Eq, Ord, Show)

{-| @Source.Text.Offset — indexes Unicode scalar positions -}
newtype Offset = Offset {unOffset :: Int}
  deriving stock (Eq, Ord, Show)

{-| @Source.Text.Identity — distinguishes every ingestion snapshot -}
data SourceIdentity = SourceIdentity
  { identityUnique :: !Unique
  , identityName :: !SourceName
  }

instance Eq SourceIdentity where
  left == right = identityUnique left == identityUnique right

{-| Sources order by the identity they were given, which is stable within a run
    and means nothing beyond that. It exists so values carrying a span can be
    ordered at all, not because one source precedes another. -}
instance Ord SourceIdentity where
  compare left right = compare (identityUnique left) (identityUnique right)

{-| @Source.Text.Value — pairs an immutable snapshot with cached bounds -}
data Source = Source
  { sourceIdentity :: !SourceIdentity
  , sourceTextValue :: !Text
  , sourceScalarLength :: !Int
  {-| Where each line begins, so a position can be found without counting.

      Finding a line by counting from the start of the text costs what it
      skips, and everything that reports a position asks per token rather than
      once: formatting a file asked for every token it had, which made laying
      out a file cost the square of its size. This is built once, in the pass
      that already reads the text. -}
  , sourceLineStarts :: !(Map Int Int)
  }

{-| @Source.Text.Span — identifies a half-open range in one snapshot -}
data Span = Span
  { spanIdentity :: !SourceIdentity
  , spanStart :: !Offset
  , spanEnd :: !Offset
  }

instance Eq Span where
  left == right =
    spanIdentity left == spanIdentity right
      && spanStart left == spanStart right
      && spanEnd left == spanEnd right

{-| Spans order by where they start and then by where they end, within one
    source. Across two sources the order is by identity and means nothing beyond
    being stable — which is all an ordering on spans is ever asked for, since
    comparing positions in different files is not a question with an answer. -}
instance Ord Span where
  compare left right =
    compare (spanIdentity left) (spanIdentity right)
      <> compare (spanStart left) (spanStart right)
      <> compare (spanEnd left) (spanEnd right)

instance Show Source where
  show source =
    "Source {sourceName = "
      <> show (sourceName source)
      <> ", sourceLength = "
      <> show (sourceLength source)
      <> "}"

instance Show Span where
  show value =
    "Span {spanSource = "
      <> show (spanSource value)
      <> ", spanStart = "
      <> show (spanStart value)
      <> ", spanEnd = "
      <> show (spanEnd value)
      <> "}"

{-| @Source.Text.Position — renders one-based user coordinates -}
data Position = Position
  { positionLine :: !Int
  , positionColumn :: !Int
  }
  deriving stock (Eq, Ord, Show)

newSource :: SourceName -> Text -> IO Source
newSource name textValue = do
  unique <- newUnique
  pure
    Source
      { sourceIdentity = SourceIdentity{identityUnique = unique, identityName = name}
      , sourceTextValue = textValue
      , sourceScalarLength = Text.length textValue
      , sourceLineStarts = lineStartsOf textValue
      }

sourceName :: Source -> SourceName
sourceName = identityName . sourceIdentity

sourceText :: Source -> Text
sourceText = sourceTextValue

emptySpan :: Source -> Span
emptySpan Source{sourceIdentity} =
  Span{spanIdentity = sourceIdentity, spanStart = zeroOffset, spanEnd = zeroOffset}

zeroOffset :: Offset
zeroOffset = Offset 0

offsetFromInt :: Int -> Maybe Offset
offsetFromInt value
  | value < 0 = Nothing
  | otherwise = Just (Offset value)

advanceOffset :: Int -> Offset -> Maybe Offset
advanceOffset amount (Offset value)
  | amount < 0 = Nothing
  | value > maxBound - amount = Nothing
  | otherwise = Just (Offset (value + amount))

mkSpan :: Source -> Offset -> Offset -> Maybe Span
mkSpan Source{sourceIdentity, sourceScalarLength} start@(Offset startValue) end@(Offset endValue)
  | startValue < 0 = Nothing
  | endValue < startValue = Nothing
  | endValue > sourceScalarLength = Nothing
  | otherwise = Just Span{spanIdentity = sourceIdentity, spanStart = start, spanEnd = end}

zeroWidthSpan :: Source -> Offset -> Maybe Span
zeroWidthSpan source offset = mkSpan source offset offset

mergeSpans :: Span -> Span -> Maybe Span
mergeSpans left right
  | spanIdentity left /= spanIdentity right = Nothing
  | otherwise =
      Just
        Span
          { spanIdentity = spanIdentity left
          , spanStart = min (spanStart left) (spanStart right)
          , spanEnd = max (spanEnd left) (spanEnd right)
          }

offsetPosition :: Source -> Offset -> Maybe Position
spanSource :: Span -> SourceName
spanSource = identityName . spanIdentity

offsetPosition Source{sourceLineStarts, sourceScalarLength} (Offset requested)
  | requested < 0 = Nothing
  | requested > sourceScalarLength = Nothing
  | otherwise = case Map.lookupLE requested sourceLineStarts of
      Nothing -> Just (Position 1 (requested + 1))
      Just (start, line) -> Just (Position line (requested - start + 1))

{-| Every offset at which a column returns to one, and the line it begins.

    Read straight off the same rule a count would follow, so the answers agree
    with what counting gave: a carriage return begins a line, a newline after
    one continues it rather than beginning another, and a newline on its own
    begins one. A carriage-return-newline pair therefore records twice — once
    after each half — because a position between them is column one as surely
    as the position after them is. -}
lineStartsOf :: Text -> Map Int Int
lineStartsOf textValue = Map.fromDistinctAscList (reverse collected)
 where
  collected =
    scanCollected (Text.foldl' step (LineScan 0 initialPositionFold [(0, 1)]) textValue)
  {-| The accumulator is a strict record rather than a tuple. `foldl'` forces
      what it accumulates only to weak head normal form, and a tuple is already
      in it, so the offset and the running position would each build a chain of
      unevaluated work as long as the text — paid for at the end, in memory the
      whole way. -}
  step (LineScan index folded acc) value =
    let next = advancePosition folded value
        after = index + 1
     in LineScan
          after
          next
          (if foldColumn next == 1 then (after, foldLine next) : acc else acc)

{-| @Source.Text.LineScan — the state of one walk over a text looking for the
    offsets where a line begins. -}
data LineScan = LineScan !Int !PositionFold ![(Int, Int)]

scanCollected :: LineScan -> [(Int, Int)]
scanCollected (LineScan _ _ collected) = collected

sourceLength :: Source -> Offset
sourceLength = Offset . sourceScalarLength

data PositionFold = PositionFold
  { foldLine :: !Int
  , foldColumn :: !Int
  , foldAfterCarriageReturn :: !Bool
  }

initialPositionFold :: PositionFold
initialPositionFold = PositionFold{foldLine = 1, foldColumn = 1, foldAfterCarriageReturn = False}

advancePosition :: PositionFold -> Char -> PositionFold
advancePosition PositionFold{foldLine, foldColumn, foldAfterCarriageReturn} value =
  case value of
    '\r' -> PositionFold{foldLine = foldLine + 1, foldColumn = 1, foldAfterCarriageReturn = True}
    '\n'
      | foldAfterCarriageReturn ->
          PositionFold{foldLine, foldColumn = 1, foldAfterCarriageReturn = False}
      | otherwise ->
          PositionFold{foldLine = foldLine + 1, foldColumn = 1, foldAfterCarriageReturn = False}
    _ ->
      PositionFold{foldLine, foldColumn = foldColumn + 1, foldAfterCarriageReturn = False}

