{-| @Pudu.Backend.Emit.State — deterministic output, scalar temporaries,
    byte-safe strings, and interpreter-compatible diagnostic sites. -}
module Pudu.Backend.Emit.State
  ( EmitState (..), emptyEmitState, line, freshTemp, textOfInt
  , shiftSites, overflowSite, divideByZeroSite, callDepthSite, operatorFailureSite, failureSite, renderSites, cString, cStringBytes
  ) where

import qualified Data.ByteString as ByteString
import Data.Char (ord)
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
import Pudu.Source (Position (..), Source, Span, offsetPosition, sourceName, spanSource, spanStart, unSourceName)

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
    }

line :: EmitState -> Text -> EmitState
line state text =
  state{emitOutput = (Text.replicate (emitIndent state) " " <> text) : emitOutput state}

freshTemp :: EmitState -> (EmitState, Text)
freshTemp state =
  (state{emitNextTemp = emitNextTemp state + 1}, "pudu_t" <> textOfInt (emitNextTemp state))

textOfInt :: Int -> Text
textOfInt = Text.pack . show

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
      }

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
      <> " },"
  flag True = "1"
  flag False = "0"

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
