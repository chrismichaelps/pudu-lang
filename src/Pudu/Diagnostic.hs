{-| @Diagnostic.Compiler.Module — stabilizes actionable compiler failures -}
module Pudu.Diagnostic
  ( Diagnostic
  , DiagnosticCode (..)
  , Related (..)
  , Severity (..)
  , diagnostic
  , diagnosticCode
  , diagnosticHelp
  , diagnosticMessage
  , diagnosticRelated
  , diagnosticSeverity
  , diagnosticSpan
  , hasErrors
  , sortDiagnostics
  , withHelp
  , withRelated
  ) where

import Data.List (sortOn)
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
  , relatedValues :: ![Related]
  }
  deriving stock (Eq, Show)

diagnostic :: DiagnosticCode -> Severity -> Span -> Text -> Diagnostic
diagnostic code severity spanValue message =
  Diagnostic
    { codeValue = code
    , severityValue = severity
    , spanValue
    , messageValue = nonEmptyMessage code message
    , helpValue = Nothing
    , relatedValues = []
    }

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
diagnosticRelated = relatedValues

withHelp :: Text -> Diagnostic -> Diagnostic
withHelp helpText value = value{helpValue = Just helpText}

withRelated :: Related -> Diagnostic -> Diagnostic
withRelated related value =
  value{relatedValues = relatedValues value <> [related]}

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

relatedKeys :: [Related] -> [(SourceName, Offset, Offset, Text)]
relatedKeys = map relatedKey

relatedKey :: Related -> (SourceName, Offset, Offset, Text)
relatedKey Related{relatedSpan, relatedMessage} =
  (spanSource relatedSpan, spanStart relatedSpan, spanEnd relatedSpan, relatedMessage)
