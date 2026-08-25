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

offsetPosition Source{sourceTextValue, sourceScalarLength} (Offset requested)
  | requested < 0 = Nothing
  | requested > sourceScalarLength = Nothing
  | otherwise =
      Just
        ( positionValue
            (Text.foldl' advancePosition initialPositionFold (Text.take requested sourceTextValue))
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
