{-| @Lsp.Documents — what the server knows about each open document.

    One compile's answers, kept by the URI the editor named them with. The store
    is a value the loop threads rather than a mutable cell, so what a reply says
    and what the server holds cannot disagree part-way through answering. -}
module Pudu.Lsp.Documents
  ( Analysis (..)
  , Documents (..)
  , analysisOf
  , documentOf
  , emptyDocuments
  , forgetDocument
  , rememberAnalysis
  , uriOf
  ) where

import Control.Monad (unless)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program (ProgramResult (..), compileProgramSource, programDocs, rootCompileResult)
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (..)
  , diagnosticCode
  , diagnosticCodeText
  , diagnosticHelp
  , diagnosticMessage
  , diagnosticSeverity
  , diagnosticSpan
  )
import Pudu.Doc (DocEntry (..), DocIndex (..), DocKind (..))
import Pudu.Format (FormatResult (..), formatSource)
import Pudu.Lsp.Feature
  ( completionItems
  , documentSymbols
  , entryAt
  , hoverContents
  , locationOf
  , offsetAt
  , rangeOfOffsets
  , wordAt
  )
import Pudu.Lsp.Json (Json (..), lookupField, textOf)
import Pudu.Lsp.Protocol
  ( Message (..)
  , errorResponse
  , frame
  , notification
  , positionOf
  , rangeJson
  , readMessage
  , response
  )
import Pudu.Source (Source, SourceName (..), newSource, spanEnd, spanStart, unOffset)
import Data.Char (isAlphaNum)
import Data.List (nub, sort)
import Pudu.Eval.Operator (builtinMethodNamesFor)
import Pudu.Type (Type (..), TypeInfo, narrowestAt, renderType)
import Pudu.Type.Value (nominalName)
import System.Directory (getCurrentDirectory)
import System.FilePath (takeDirectory)
import System.IO
  ( BufferMode (NoBuffering)
  , Handle
  , hFlush
  , hSetBinaryMode
  , hSetBuffering
  , stdin
  , stdout
  )

{-| @Lsp.Server.Analysis — everything the compiler said about one open file.

    Held rather than recomputed per request because a hover, a definition, and a
    completion within one keystroke would otherwise compile the program three
    times. The text is kept beside it so a position can be turned into an offset
    without asking the editor again. -}
data Analysis = Analysis
  { analysisText :: !Text
  , analysisSource :: !Source
  , analysisDiagnostics :: ![Diagnostic]
  , analysisIndex :: !DocIndex
  {-| What the checker said each expression is, by span.

      The documentation index holds declarations, so it can only ever answer
      about the function a cursor is inside. A reader hovering a binding is
      asking about the binding. -}
  , analysisTypes :: !(Maybe TypeInfo)
  }

{-| @Lsp.Server.Documents — what the editor says each open file contains.

    The editor's copy is authoritative while a file is open, because it holds
    edits the disk has not seen. Compiling what is on disk instead would report
    diagnostics against text the reader is not looking at, which is worse than
    reporting none. -}
newtype Documents = Documents (Map Text Analysis)

emptyDocuments :: Documents
emptyDocuments = Documents Map.empty

rememberAnalysis :: Text -> Analysis -> Documents -> Documents
rememberAnalysis uri value (Documents store) = Documents (Map.insert uri value store)

forgetDocument :: Text -> Documents -> Documents
forgetDocument uri (Documents store) = Documents (Map.delete uri store)

analysisOf :: Text -> Documents -> Maybe Analysis
analysisOf uri (Documents store) = Map.lookup uri store

documentOf :: Documents -> Json -> Maybe Analysis
documentOf documents parameters = uriOf parameters >>= (`analysisOf` documents)

uriOf :: Json -> Maybe Text
uriOf parameters =
  lookupField "textDocument" parameters >>= lookupField "uri" >>= textOf
