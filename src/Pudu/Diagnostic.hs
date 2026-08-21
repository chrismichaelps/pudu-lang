{-| @Diagnostic.Compiler.Module — stabilizes actionable compiler failures -}
module Pudu.Diagnostic
  ( Diagnostic
  , DiagnosticCode
  , Related (..)
  , Severity (..)
  , diagnostic
  , diagnosticCode
  , diagnosticCodeText
  , diagnosticHelp
  , diagnosticMessage
  , diagnosticRelated
  , diagnosticSeverity
  , diagnosticSpan
  , hasErrors
  , mkDiagnosticCode
  , sortDiagnostics
  , withHelp
  , withRelated
  ) where

import Data.Foldable (toList)
import Data.List (sortOn)
import Data.Sequence (Seq, (|>))
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Source (Offset, SourceName, Span, spanEnd, spanSource, spanStart)

{-| @Diagnostic.Compiler.Code — preserves stable failure identity -}
newtype DiagnosticCode = DiagnosticCode {unDiagnosticCode :: Text}
  deriving stock (Eq, Ord, Show)

{-| @Diagnostic.Compiler.Severity — classifies compiler outcome impact -}
data Severity = Error | Warning | Note
  deriving stock (Eq, Ord, Show, Enum, Bounded)

{-| @Diagnostic.Compiler.Related — links explanatory source context -}
data Related = Related
  { relatedSpan :: !Span
  , relatedMessage :: !Text
  }
  deriving stock (Eq, Show)

{-| @Diagnostic.Compiler.Value — carries structured actionable feedback -}
data Diagnostic = Diagnostic
  { codeValue :: !DiagnosticCode
  , severityValue :: !Severity
  , spanValue :: !Span
  , messageValue :: !Text
  , helpValue :: !(Maybe Text)
  , relatedValues :: !(Seq Related)
  }
  deriving stock (Eq, Show)

mkDiagnosticCode :: Text -> Maybe DiagnosticCode
mkDiagnosticCode code =
  case Text.unpack code of
    [family, group, first, second, third]
      | family `elem` ['E', 'W']
      , group >= '0'
      , group <= '7'
      , all isAsciiDigit [first, second, third] -> Just (DiagnosticCode code)
    _ -> Nothing

diagnosticCodeText :: DiagnosticCode -> Text
diagnosticCodeText = unDiagnosticCode

diagnostic :: DiagnosticCode -> Severity -> Span -> Text -> Maybe Diagnostic
diagnostic code severity spanValue message =
  if supportsSeverity code severity
    then
      Just
        Diagnostic
          { codeValue = code
          , severityValue = severity
          , spanValue
          , messageValue = nonEmptyMessage code message
          , helpValue = Nothing
          , relatedValues = Seq.empty
          }
    else Nothing

diagnosticCode :: Diagnostic -> DiagnosticCode
diagnosticCode = codeValue

diagnosticSeverity :: Diagnostic -> Severity
diagnosticSeverity = severityValue

diagnosticSpan :: Diagnostic -> Span
diagnosticSpan = spanValue

diagnosticMessage :: Diagnostic -> Text
diagnosticMessage = messageValue

diagnosticHelp :: Diagnostic -> Maybe Text
diagnosticHelp = helpValue

diagnosticRelated :: Diagnostic -> [Related]
diagnosticRelated = toList . relatedValues

withHelp :: Text -> Diagnostic -> Diagnostic
withHelp helpText value = value{helpValue = Just helpText}

withRelated :: Related -> Diagnostic -> Diagnostic
withRelated related value =
  value{relatedValues = relatedValues value |> related}

sortDiagnostics :: [Diagnostic] -> [Diagnostic]
sortDiagnostics =
  sortOn
    ( \value ->
        ( spanSource (diagnosticSpan value)
        , spanStart (diagnosticSpan value)
        , spanEnd (diagnosticSpan value)
        , diagnosticSeverity value
        , diagnosticCode value
        , diagnosticMessage value
        , diagnosticHelp value
        , relatedKeys (diagnosticRelated value)
        )
    )

hasErrors :: [Diagnostic] -> Bool
hasErrors = any ((== Error) . diagnosticSeverity)

nonEmptyMessage :: DiagnosticCode -> Text -> Text
nonEmptyMessage (DiagnosticCode code) message
  | Text.null message = "compiler diagnostic " <> code
  | otherwise = message

supportsSeverity :: DiagnosticCode -> Severity -> Bool
supportsSeverity (DiagnosticCode code) severity =
  case (Text.uncons code, severity) of
    (Just ('E', _), Error) -> True
    (Just ('W', _), Warning) -> True
    (Just (family, _), Note) -> family == 'E' || family == 'W'
    _ -> False

isAsciiDigit :: Char -> Bool
isAsciiDigit value = value >= '0' && value <= '9'

relatedKeys :: [Related] -> [(SourceName, Offset, Offset, Text)]
relatedKeys = map relatedKey

relatedKey :: Related -> (SourceName, Offset, Offset, Text)
relatedKey Related{relatedSpan, relatedMessage} =
  (spanSource relatedSpan, spanStart relatedSpan, spanEnd relatedSpan, relatedMessage)
