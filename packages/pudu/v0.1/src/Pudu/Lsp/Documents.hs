{-| @Lsp.Documents — what the server knows about each open document.

    One compile's answers, kept by the URI the editor named them with. The store
    is a value the loop threads rather than a mutable cell, so what a reply says
    and what the server holds cannot disagree part-way through answering. -}
module Pudu.Lsp.Documents
  ( Analysis (..)
  , Documents (..)
  , allDocuments
  , analysisOf
  , documentOf
  , emptyDocuments
  , forgetDocument
  , rememberAnalysis
  , setWorkspaceFolders
  , uriOf
  , workspaceFolders
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import Data.Text (Text)
import Pudu.Diagnostic (Diagnostic)
import Pudu.Doc (DocIndex)
import Pudu.Frontend.Syntax.Tree (Module)
import Pudu.Frontend.Token (Token)
import Pudu.Lsp.Shapes (RecordShape, SumShape)
import Pudu.Lsp.Json (Json, lookupField, textOf)
import Pudu.Source (Source)
import Pudu.Semantic.Interface (ExportIndex)
import Pudu.Semantic.Resolve (Resolution)
import Pudu.Type (TypeInfo)
import Pudu.Type.Value (Scheme)

data Analysis = Analysis
  { analysisText :: !Text
  , analysisSource :: !Source
  , analysisDiagnostics :: ![Diagnostic]
  {-| The documented names of this file alone.

      A `DocEntry` carries a span, and a span is an offset into the file it was
      read from. Anything that starts from a cursor — hover, the outline, the
      classification of a token — must ask this index, because an offset means
      nothing in any other module's file and would match a declaration the
      reader is nowhere near. -}
  , analysisFileIndex :: !DocIndex
  {-| The documented names of the whole program, dependencies included.

      Answers keyed by name rather than by position — what may be completed
      here, what the call being written expects — belong to this one: an
      imported function is as callable as a local one. -}
  , analysisProgramIndex :: !DocIndex
  , analysisResolution :: !(Maybe Resolution)
  {-| What the checker said each expression is, by span.

      The documentation index holds declarations, so it can only ever answer
      about the function a cursor is inside. A reader hovering a binding is
      asking about the binding. -}
  , analysisTypes :: !(Maybe TypeInfo)
  , analysisTokens :: ![Token]
  {-| The document's own tree, when it compiled, for questions about what
      construct a position is in. -}
  , analysisModule :: !(Maybe Module)
  {-| Every sum type the program can see, by its canonical name — the
      declaring module and the type's name — with its variants. -}
  , analysisSums :: !(Map Text SumShape)
  {-| Every record type the program can see, keyed the same way. -}
  , analysisRecords :: !(Map Text RecordShape)
  {-| Every method the program's modules declare, by the canonical key of the
      type or trait that owns it, with the scheme the checker gave it. -}
  , analysisMethods :: !(Map Text [(Text, Scheme)])
  {-| What each module of the program exports, as imports see it. -}
  , analysisExports :: !ExportIndex
  {-| Every module file the program read besides this document, transitive
      imports included, by normalised path: what an edit elsewhere must be
      checked against to know whether this analysis is stale. -}
  , analysisDependencies :: !(Set FilePath)
  }

{-| @Lsp.Server.Documents — what the editor says each open file contains.

    The editor's copy is authoritative while a file is open, because it holds
    edits the disk has not seen. Compiling what is on disk instead would report
    diagnostics against text the reader is not looking at, which is worse than
    reporting none. -}
data Documents = Documents
  {-| The folders the editor opened, most specific first. They say which
      files the session owns; a document's module source root is derived from
      its own path and module name, as the command line derives it. -}
  { docWorkspaceFolders :: ![FilePath]
  , docMap           :: !(Map Text Analysis)
  }

emptyDocuments :: Documents
emptyDocuments = Documents [] Map.empty

setWorkspaceFolders :: [FilePath] -> Documents -> Documents
setWorkspaceFolders folders docs = docs { docWorkspaceFolders = folders }

workspaceFolders :: Documents -> [FilePath]
workspaceFolders = docWorkspaceFolders

allDocuments :: Documents -> [(Text, Analysis)]
allDocuments (Documents _ store) = Map.toList store

rememberAnalysis :: Text -> Analysis -> Documents -> Documents
rememberAnalysis uri value docs = docs { docMap = Map.insert uri value (docMap docs) }

forgetDocument :: Text -> Documents -> Documents
forgetDocument uri docs = docs { docMap = Map.delete uri (docMap docs) }

analysisOf :: Text -> Documents -> Maybe Analysis
analysisOf uri docs = Map.lookup uri (docMap docs)

documentOf :: Documents -> Json -> Maybe Analysis
documentOf documents parameters = uriOf parameters >>= (`analysisOf` documents)

uriOf :: Json -> Maybe Text
uriOf parameters =
  lookupField "textDocument" parameters >>= lookupField "uri" >>= textOf
