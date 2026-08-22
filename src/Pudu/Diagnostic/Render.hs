{-| @Diagnostic.Render.Module — renders diagnostics for people -}
module Pudu.Diagnostic.Render
  ( RenderConfig (..)
  , RenderStyle (..)
  , defaultRenderConfig
  , interactiveRenderConfig
  , renderDiagnostic
  , renderDiagnosticWith
  , renderDiagnostics
  , renderDiagnosticsWith
  , renderSummary
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Diagnostic
  , Related (..)
  , Severity (..)
  , diagnosticCodeText
  , diagnosticCode
  , diagnosticHelp
  , diagnosticMessage
  , diagnosticRelated
  , diagnosticSeverity
  , diagnosticSpan
  )
import Pudu.Source
  ( Position (..)
  , Source
  , Span
  , offsetPosition
  , sourceName
  , sourceText
  , spanEnd
  , spanSource
  , spanStart
  , unOffset
  , unSourceName
  )

{-| @Diagnostic.Render.Style — colour is an explicit caller decision -}
data RenderStyle = PlainStyle | ColorStyle
  deriving stock (Eq, Show)

{-| @Diagnostic.Render.Config — how one batch of diagnostics is presented.
    A REPL entry is compiled inside a larger buffer, so it reports its own
    display name and subtracts the lines that precede the entry. -}
data RenderConfig = RenderConfig
  { renderStyle :: !RenderStyle
  , renderDisplayName :: !(Maybe Text)
  , renderFirstLine :: !Int
  }
  deriving stock (Eq, Show)

defaultRenderConfig :: RenderStyle -> RenderConfig
defaultRenderConfig style =
  RenderConfig{renderStyle = style, renderDisplayName = Nothing, renderFirstLine = 1}

{-| Present spans relative to an entry that starts at the given buffer line. -}
interactiveRenderConfig :: RenderStyle -> Text -> Int -> RenderConfig
interactiveRenderConfig style displayName firstLine =
  RenderConfig
    { renderStyle = style
    , renderDisplayName = Just displayName
    , renderFirstLine = max 1 firstLine
    }

renderDiagnostics :: RenderStyle -> Source -> [Diagnostic] -> Text
renderDiagnostics style = renderDiagnosticsWith (defaultRenderConfig style)

renderDiagnosticsWith :: RenderConfig -> Source -> [Diagnostic] -> Text
renderDiagnosticsWith config source values =
  Text.intercalate "\n" (map (renderDiagnosticWith config source) values)

{-| Render one diagnostic as headline, location, excerpt with caret, related
    notes, and help. Every part is derived from the diagnostic and the snapshot
    it points into; nothing is inferred from the environment. -}
renderDiagnostic :: RenderStyle -> Source -> Diagnostic -> Text
renderDiagnostic style = renderDiagnosticWith (defaultRenderConfig style)

renderDiagnosticWith :: RenderConfig -> Source -> Diagnostic -> Text
renderDiagnosticWith config source value =
  Text.intercalate "\n" (headline : locationLine : excerpt <> notes <> helpLines)
 where
  style = renderStyle config
  severity = diagnosticSeverity value
  code = diagnosticCodeText (diagnosticCode value)
  spanValue = diagnosticSpan value
  headline =
    paint style (severityColor severity) (severityLabel severity <> "[" <> code <> "]")
      <> ": " <> diagnosticMessage value
  locationLine = "  --> " <> locationText config source spanValue
  excerpt = renderExcerpt config source spanValue
  notes = map (renderRelated config source) (diagnosticRelated value)
  helpLines = case diagnosticHelp value of
    Nothing -> []
    Just help -> ["   = " <> paint style cyan "help" <> ": " <> help]

renderRelated :: RenderConfig -> Source -> Related -> Text
renderRelated config source related =
  "   = note: " <> relatedMessage related
    <> " (" <> locationText config source (relatedSpan related) <> ")"

{-| A span from another snapshot still reports its location, but never borrows a
    line of unrelated text to quote. -}
renderExcerpt :: RenderConfig -> Source -> Span -> [Text]
renderExcerpt config source spanValue
  | spanSource spanValue /= sourceName source = []
  | otherwise = case positionsOf source spanValue of
      Nothing -> []
      Just (start, end) ->
        let lineNumber = positionLine start
            style = renderStyle config
            gutter = Text.pack (show (displayLine config lineNumber))
            pad = Text.replicate (Text.length gutter) " "
            lineText = expandTabs (sourceLine source lineNumber)
            sameLine = positionLine end == lineNumber
            startColumn = expandedColumn (sourceLine source lineNumber) (positionColumn start)
            endColumn
              | sameLine = expandedColumn (sourceLine source lineNumber) (positionColumn end)
              | otherwise = Text.length lineText + 1
            width = max 1 (endColumn - startColumn)
            caret = Text.replicate (max 0 (startColumn - 1)) " " <> Text.replicate width "^"
            continuation = if sameLine then Text.empty else " ..."
         in [ " " <> pad <> " |"
            , " " <> gutter <> " | " <> lineText
            , " " <> pad <> " | " <> paint style (severityColorOf style) caret <> continuation
            ]
 where
  severityColorOf _ = red

positionsOf :: Source -> Span -> Maybe (Position, Position)
positionsOf source spanValue = do
  start <- offsetPosition source (spanStart spanValue)
  end <- offsetPosition source (spanEnd spanValue)
  pure (start, end)

locationText :: RenderConfig -> Source -> Span -> Text
locationText config source spanValue =
  displayName <> ":" <> position
 where
  displayName = case renderDisplayName config of
    Just name -> name
    Nothing -> unSourceName (spanSource spanValue)
  position = case offsetPosition source (spanStart spanValue) of
    Just found ->
      Text.pack (show (displayLine config (positionLine found)))
        <> ":" <> Text.pack (show (positionColumn found))
    Nothing -> "offset " <> Text.pack (show (unOffset (spanStart spanValue)))

{-| Translate a buffer line into the line the reader typed. Lines before the
    entry clamp to the first line rather than going negative. -}
displayLine :: RenderConfig -> Int -> Int
displayLine config lineNumber = max 1 (lineNumber - renderFirstLine config + 1)

sourceLine :: Source -> Int -> Text
sourceLine source lineNumber =
  case drop (lineNumber - 1) (splitLines (sourceText source)) of
    found : _ -> found
    [] -> Text.empty

{-| Split on every newline convention the lexer admits, so the quoted line
    matches the line the position model counted. -}
splitLines :: Text -> [Text]
splitLines = Text.splitOn "\n" . Text.replace "\r\n" "\n" . Text.replace "\r" "\n"

{-| Tabs expand in the quoted line and in the caret row identically, so the
    caret cannot drift away from what it points at. -}
expandTabs :: Text -> Text
expandTabs = Text.replace "\t" tabStop

expandedColumn :: Text -> Int -> Int
expandedColumn original column =
  let prefix = Text.take (max 0 (column - 1)) original
      tabs = Text.count "\t" prefix
   in column + tabs * (Text.length tabStop - 1)

tabStop :: Text
tabStop = "    "

renderSummary :: [Diagnostic] -> Text
renderSummary values =
  case (errors, warnings) of
    (0, 0) -> "no diagnostics"
    _ -> Text.intercalate ", " (countText "error" errors <> countText "warning" warnings)
 where
  errors = length (filter ((== Error) . diagnosticSeverity) values)
  warnings = length (filter ((== Warning) . diagnosticSeverity) values)
  countText label total
    | total == 0 = []
    | total == 1 = ["1 " <> label]
    | otherwise = [Text.pack (show total) <> " " <> label <> "s"]

severityLabel :: Severity -> Text
severityLabel severity = case severity of
  Error -> "error"
  Warning -> "warning"
  Note -> "note"

severityColor :: Severity -> Text
severityColor severity = case severity of
  Error -> red
  Warning -> yellow
  Note -> cyan

paint :: RenderStyle -> Text -> Text -> Text
paint style color value = case style of
  PlainStyle -> value
  ColorStyle -> color <> value <> reset

red :: Text
red = "\ESC[31m"

yellow :: Text
yellow = "\ESC[33m"

cyan :: Text
cyan = "\ESC[36m"

reset :: Text
reset = "\ESC[0m"
