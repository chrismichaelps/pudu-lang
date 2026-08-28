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

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Diagnostic (Diagnostic)
import Pudu.Doc (DocIndex)
import Pudu.Lsp.Json (Json, lookupField, textOf)
import Pudu.Source (Source)
import Pudu.Type (TypeInfo)

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
