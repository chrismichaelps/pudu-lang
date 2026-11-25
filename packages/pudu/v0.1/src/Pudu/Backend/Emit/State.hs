{-| @Pudu.Backend.Emit.State — deterministic output, scalar temporaries,
    byte-safe strings, and interpreter-compatible diagnostic sites. -}
module Pudu.Backend.Emit.State
  ( EmitState (..), emptyEmitState, line, freshTemp, textOfInt, profileLabel
  , shiftSites, overflowSite, divideByZeroSite, callDepthSite, operatorFailureSite, failureSite, helpedFailureSite, textFailureSite, renderSites, byteData, renderByteData, constantCell, renderConstantCells, cString, cStringBytes
  ) where

import qualified Data.ByteString as ByteString
import qualified Data.List as List
import Data.Char (isAsciiLower, isAsciiUpper, isDigit, ord)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Pudu.Core (CoreLoopId, CoreType (..))
import Pudu.Diagnostic.Arithmetic (CheckedOperation, divideByZeroCode, divideByZeroMessage, overflowCode, overflowHelp, overflowMessage, shiftCode, negativeShiftMessage, negativeShiftHelp, wideShiftMessage, wideShiftHelp)
import Pudu.Diagnostic.Evaluation (callDepthCode, callDepthHelp, callDepthMessage, operatorCode)
import Pudu.Diagnostic.Render (Excerpt (..), excerptGeometry)
import Pudu.IntegerLiteral (IntegerKind)
import Pudu.Source (Position (..), Source, Span, offsetPosition, sourceName, spanOrigin, spanSource, spanStart, unSourceName)

{-| @Backend.Emit.Site — one refusal site, flattened for the C table. -}
data Site = Site
  { siteFile :: !Text
  , siteLine :: !Int
  , siteColumn :: !Int
  , siteCode :: !Text
  , siteMessage :: !Text
  , siteHelp :: !(Maybe Text)
  , siteLineText :: !Text
  , siteIndent :: !Int
  , siteWidth :: !Int
  , siteMultiline :: !Bool
  , siteHasExcerpt :: !Bool
  , siteNotes :: ![Text]
  }
  deriving stock (Eq, Show)

{-| @Backend.Emit.State — output lines (reversed), sites (reversed), the
    deterministic counters that name temporaries and index sites, and the
    result type of the function being emitted (so `return` knows whether it
    yields a value). -}
data EmitState = EmitState
  { emitOutput :: ![Text]
  , emitSites :: ![Site]
  , emitNextSite :: !Int
  , emitNextTemp :: !Int
  , emitIndent :: !Int
  , emitSources :: ![Source]
  , emitResultType :: !CoreType
  , emitLoopResults :: !(Map.Map CoreLoopId (Maybe Text))
  , emitBreakTargets :: !(Set.Set CoreLoopId)
  , emitContinueTargets :: !(Set.Set CoreLoopId)
  {-| Each function's number in the frame table, for closures to name. -}
  , emitFunctionIds :: !(Map.Map Text Int)
  {-| Each byte literal's data, newest first; its index names its table. -}
  , emitByteData :: ![ByteString.ByteString]
  {-| Each kept module constant's name, newest first; its index names its cell. -}
  , emitConstants :: ![Text]
  }

emptyEmitState :: [Source] -> EmitState
emptyEmitState sources =
  EmitState
    { emitOutput = []
    , emitSites = []
    , emitNextSite = 0
    , emitNextTemp = 0
    , emitIndent = 0
    , emitSources = sources
    , emitResultType = CoreUnitType
    , emitLoopResults = Map.empty
    , emitBreakTargets = Set.empty
    , emitContinueTargets = Set.empty
    , emitFunctionIds = Map.empty
    , emitByteData = []
    , emitConstants = []
    }

line :: EmitState -> Text -> EmitState
line state text =
  state{emitOutput = (Text.replicate (emitIndent state) " " <> text) : emitOutput state}

freshTemp :: EmitState -> (EmitState, Text)
freshTemp state =
  (state{emitNextTemp = emitNextTemp state + 1}, "pudu_t" <> textOfInt (emitNextTemp state))

textOfInt :: Int -> Text
textOfInt = Text.pack . show

{-| The symbol a generated function is known by to a profiler or debugger:
    its Pudu name, its role, and its index, which keeps two functions of one
    name apart. Written as an assembler label on the function's first
    declaration, so every reference in the C keeps its indexed name. -}
profileLabel :: Text -> Text -> Int -> Text
profileLabel role name identity =
  " __asm__(\"pudu_" <> Text.take 96 (Text.map safe name) <> "_" <> role <> textOfInt identity <> "\")"
 where
  safe c = if isAsciiLower c || isAsciiUpper c || isDigit c then c else '_'

{-| Bake a site for a span: location and excerpt geometry from the program's
    own source, text from the caller. -}
siteAt :: EmitState -> Span -> Text -> Text -> Maybe Text -> (EmitState, Int)
siteAt state spanValue code message help =
  (state{emitSites = site : emitSites state, emitNextSite = emitNextSite state + 1}, emitNextSite state)
 where
  source = case filter ((== spanSource spanValue) . sourceName) (emitSources state) of
    found : _ -> Just found
    [] -> Nothing
  position = source >>= \found -> offsetPosition found (spanStart spanValue)
  excerpt = source >>= \found -> excerptGeometry found spanValue
  site =
    Site
      { siteFile = unSourceName (spanSource spanValue)
      , siteLine = maybe 1 positionLine position
      , siteColumn = maybe 1 positionColumn position
      , siteCode = code
      , siteMessage = message
      , siteHelp = help
      , siteLineText = maybe Text.empty excerptLineText excerpt
      , siteIndent = maybe 0 excerptIndent excerpt
      , siteWidth = maybe 1 excerptWidth excerpt
      , siteMultiline = maybe False excerptMultiline excerpt
      , siteHasExcerpt = case excerpt of
          Just _ -> True
          Nothing -> False
      , siteNotes = case spanOrigin spanValue of
          Just (definition, request, _) ->
            [ "derive definition (" <> located definition <> ")"
            , "derive requested here (" <> located request <> ")" ]
          Nothing -> []
      }
  -- A related span's location as the interpreter's diagnostic note prints it.
  located at =
    let held = filter ((== spanSource at) . sourceName) (emitSources state)
        place = case held of
          found : _ -> offsetPosition found (spanStart at)
          [] -> Nothing
     in unSourceName (spanSource at) <> ":" <> textOfInt (maybe 1 positionLine place)
          <> ":" <> textOfInt (maybe 1 positionColumn place)

overflowSite :: EmitState -> Span -> IntegerKind -> CheckedOperation -> (EmitState, Int)
overflowSite state spanValue kind operation =
  siteAt state spanValue overflowCode (overflowMessage kind operation) (Just overflowHelp)

shiftSites :: EmitState -> Span -> IntegerKind -> (EmitState, Int, Int)
shiftSites state at kind =
  let (afterNegative, negative) = siteAt state at shiftCode negativeShiftMessage (Just negativeShiftHelp)
      (afterWide, wide) = siteAt afterNegative at shiftCode (wideShiftMessage kind) (Just wideShiftHelp)
   in (afterWide, negative, wide)

divideByZeroSite :: EmitState -> Span -> (EmitState, Int)
divideByZeroSite state spanValue =
  siteAt state spanValue divideByZeroCode divideByZeroMessage Nothing

{-| The site a call carries: the evaluator's `E7002` call-depth refusal at the
    call's own span, with [[Pudu.Diagnostic.Evaluation]]'s exact text. -}
callDepthSite :: EmitState -> Span -> (EmitState, Int)
callDepthSite state spanValue =
  siteAt state spanValue callDepthCode callDepthMessage (Just callDepthHelp)

operatorFailureSite :: EmitState -> Span -> Text -> (EmitState, Int)
operatorFailureSite state spanValue message = siteAt state spanValue operatorCode message Nothing

{-| A refusal whose code and message are known when the C is written. -}
failureSite :: EmitState -> Span -> Text -> Text -> (EmitState, Int)
failureSite state spanValue code message = siteAt state spanValue code message Nothing

{-| The same, with help text after it. -}
helpedFailureSite :: EmitState -> Span -> Text -> Text -> Text -> (EmitState, Int)
helpedFailureSite state spanValue code message help = siteAt state spanValue code message (Just help)

{-| A refusal whose message is built when it happens; the site keeps its
    code, help and place. -}
textFailureSite :: EmitState -> Span -> Text -> Maybe Text -> (EmitState, Int)
textFailureSite state spanValue code help = siteAt state spanValue code "" help

renderSites :: [Site] -> [Text]
renderSites [] = []
renderSites sites =
  ["static const pudu_site pudu_sites[] = {"]
    <> map renderSite sites
    <> ["};", ""]
 where
  renderSite site =
    "  { "
      <> cString (siteFile site)
      <> ", "
      <> textOfInt (siteLine site)
      <> ", "
      <> textOfInt (siteColumn site)
      <> ", "
      <> cString (siteCode site)
      <> ", "
      <> cString (siteMessage site)
      <> ", "
      <> maybe "NULL" cString (siteHelp site)
      <> ", "
      <> cString (siteLineText site)
      <> ", "
      <> textOfInt (siteIndent site)
      <> ", "
      <> textOfInt (siteWidth site)
      <> ", "
      <> flag (siteMultiline site)
      <> ", "
      <> flag (siteHasExcerpt site)
      <> ", "
      <> notes (siteNotes site)
      <> " },"
  notes [] = "NULL"
  notes related = cString (Text.concat ["   = note: " <> note <> "\n" | note <- related])
  flag True = "1"
  flag False = "0"

{-| The table holding a byte literal's data, `pudu_byte_data_<index>`: equal
    data shares one table however many places read it. -}
byteData :: ByteString.ByteString -> EmitState -> (EmitState, Int)
byteData bytes state = case List.elemIndex bytes oldest of
  Just index -> (state, index)
  Nothing -> (state{emitByteData = bytes : emitByteData state}, length oldest)
 where
  oldest = reverse (emitByteData state)

{-| File-scope tables for the registered byte literals, oldest first. A table
    is an array initializer rather than a string literal, which has no
    portable length limit; an empty literal keeps one unread byte because C
    has no empty arrays. -}
{-| The cell a kept constant lives in, the same for every read of its name. -}
constantCell :: Text -> EmitState -> (EmitState, Int)
constantCell name state = case List.elemIndex name oldest of
  Just index -> (state, index)
  Nothing -> (state{emitConstants = name : emitConstants state}, length oldest)
 where
  oldest = reverse (emitConstants state)

{-| The kept constants' cells and whether each is built. A cell holds one
    reference for the rest of the run, so its value is never held once and
    an update in place copies it first. Threads take turns through the run
    gate, so a cell is written once and never raced. -}
renderConstantCells :: [Text] -> [Text]
renderConstantCells [] = []
renderConstantCells names =
  [ "static pudu_cell pudu_constants[" <> count <> "];"
  , "static unsigned char pudu_constants_ready[" <> count <> "];" ]
 where
  count = Text.pack (show (length names))

renderByteData :: [ByteString.ByteString] -> [Text]
renderByteData tables = concat (zipWith table [0 :: Int ..] tables)
 where
  table index bytes =
    ["static const unsigned char pudu_byte_data_" <> Text.pack (show index) <> "[] = {"]
      <> map (\row -> "  " <> Text.intercalate ", " (map (Text.pack . show) row) <> ",") (rows (if ByteString.null bytes then [0] else ByteString.unpack bytes))
      <> ["};"]
  rows [] = []
  rows values = let (row, rest) = splitAt 24 values in row : rows rest

{-| A C string literal for exact bytes: printable ASCII verbatim, everything
    else as a three-digit octal escape, so any byte survives any compiler and
    no escape can run into the next character. -}
cString :: Text -> Text
cString text = "\"" <> Text.concat (map escapeByte (ByteString.unpack (Text.encodeUtf8 text))) <> "\""
 where
  escapeByte byte
    | byte == 0x22 = "\\\""
    | byte == 0x5C = "\\\\"
    | byte >= 0x20 && byte <= 0x7E && byte /= 0x3F = Text.singleton (toEnum (fromIntegral byte))
    | otherwise = "\\" <> octal byte
  octal byte =
    let digits = [byte `div` 64, (byte `mod` 64) `div` 8, byte `mod` 8]
     in Text.pack (map (toEnum . (+ ord '0') . fromIntegral) digits)

cStringBytes :: Text -> Int
cStringBytes = ByteString.length . Text.encodeUtf8
