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
  , mkSource
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

import Data.Text (Text)
import qualified Data.Text as Text

{-| @Source.Text.Identity — names one immutable source -}
newtype SourceName = SourceName {unSourceName :: Text}
  deriving stock (Eq, Ord, Show)

{-| @Source.Text.Offset — indexes Unicode scalar positions -}
newtype Offset = Offset {unOffset :: Int}
  deriving stock (Eq, Ord, Show)

{-| @Source.Text.Snapshot — distinguishes same-name content revisions -}
data SourceSnapshot = SourceSnapshot
  { snapshotName :: !SourceName
  , snapshotText :: !Text
  }
  deriving stock (Eq, Ord, Show)

{-| @Source.Text.Value — pairs an immutable snapshot with cached bounds -}
data Source = Source
  { sourceSnapshot :: !SourceSnapshot
  , sourceScalarLength :: !Int
  }
  deriving stock (Eq, Show)

{-| @Source.Text.Span — identifies a half-open range in one snapshot -}
data Span = Span
  { spanSnapshot :: !SourceSnapshot
  , spanStart :: !Offset
  , spanEnd :: !Offset
  }
  deriving stock (Eq, Ord, Show)

{-| @Source.Text.Position — renders one-based user coordinates -}
data Position = Position
  { positionLine :: !Int
  , positionColumn :: !Int
  }
  deriving stock (Eq, Ord, Show)

mkSource :: SourceName -> Text -> Source
mkSource name textValue =
  Source
    { sourceSnapshot = SourceSnapshot{snapshotName = name, snapshotText = textValue}
    , sourceScalarLength = Text.length textValue
    }

sourceName :: Source -> SourceName
sourceName = snapshotName . sourceSnapshot

sourceText :: Source -> Text
sourceText = snapshotText . sourceSnapshot

emptySpan :: Source -> Span
emptySpan Source{sourceSnapshot} =
  Span{spanSnapshot = sourceSnapshot, spanStart = zeroOffset, spanEnd = zeroOffset}

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
mkSpan Source{sourceSnapshot, sourceScalarLength} start@(Offset startValue) end@(Offset endValue)
  | startValue < 0 = Nothing
  | endValue < startValue = Nothing
  | endValue > sourceScalarLength = Nothing
  | otherwise = Just Span{spanSnapshot = sourceSnapshot, spanStart = start, spanEnd = end}

zeroWidthSpan :: Source -> Offset -> Maybe Span
zeroWidthSpan source offset = mkSpan source offset offset

mergeSpans :: Span -> Span -> Maybe Span
mergeSpans left right
  | spanSnapshot left /= spanSnapshot right = Nothing
  | otherwise =
      Just
        Span
          { spanSnapshot = spanSnapshot left
          , spanStart = min (spanStart left) (spanStart right)
          , spanEnd = max (spanEnd left) (spanEnd right)
          }

offsetPosition :: Source -> Offset -> Maybe Position
spanSource :: Span -> SourceName
spanSource = snapshotName . spanSnapshot

offsetPosition Source{sourceSnapshot, sourceScalarLength} (Offset requested)
  | requested < 0 = Nothing
  | requested > sourceScalarLength = Nothing
  | otherwise =
      Just
        ( positionValue
            (Text.foldl' advancePosition initialPositionFold (Text.take requested (snapshotText sourceSnapshot)))
        )

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

positionValue :: PositionFold -> Position
positionValue PositionFold{foldLine, foldColumn} = Position foldLine foldColumn
