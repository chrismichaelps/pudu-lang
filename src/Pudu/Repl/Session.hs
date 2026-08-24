{-| @Repl.Session.Module — owns interactive session state -}
module Pudu.Repl.Session
  ( EntryKind (..)
  , EntryResult (..)
  , LoadedModule (..)
  , Session (..)
  , classifyEntry
  , contextSummary
  , inspectSession
  , emptySession
  , loadModule
  , sessionDeclaredNames
  , sessionVisibleNames
  , sessionExports
  , submitEntry
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileContext, CompileResult (..), emptyCompileContext, runCompileWith)
import Pudu.Compiler.Program
  ( ProgramResult (..)
  , compileProgram
  , rootCompileResult
  )
import Pudu.Diagnostic (Diagnostic, hasErrors)
import Pudu.Eval (EvalOutcome (..), evaluateEntryPoint)
import Pudu.Eval.Value (Value)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Module (..))
import Pudu.Frontend.Token (Keyword (..), Token (..), TokenKind (..))
import Pudu.Semantic (Resolution (..), Symbol (..), boundSymbolNames, moduleSymbolNames)
import Pudu.Type (Type, TypeInfo, widestWithin)
import Pudu.Source (Source, SourceName (SourceName), newSource, spanEnd, unOffset)

{-| @Repl.Session.Loaded — a file compiled as the session context -}
data LoadedModule = LoadedModule
  { loadedPath :: !FilePath
  , loadedText :: !Text
  , loadedPrefix :: !Text
  , loadedRest :: !Text
  }
  deriving stock (Eq, Show)

{-| @Repl.Session.State — everything the session remembers between entries.
    Entries are kept as source text and recompiled together, which is what makes
    a later declaration able to change how an earlier one resolves. -}
data Session = Session
  { sessionImports :: ![Text]
  , sessionDeclarations :: ![Text]
  , sessionStatements :: ![Text]
  , sessionLoaded :: !(Maybe LoadedModule)
  , sessionContext :: !CompileContext
  }
  deriving stock (Eq, Show)

{-| @Repl.Session.EntryKind — how one submission is placed in the buffer -}
data EntryKind
  = ImportEntry
  | DeclarationEntry
  | StatementEntry
  | ExpressionEntry
  deriving stock (Eq, Show)

{-| @Repl.Session.Result — the compiled outcome of one submission -}
data EntryResult = EntryResult
  { resultSession :: !Session
  , resultKind :: !EntryKind
  , resultSource :: !Source
  , resultFirstLine :: !Int
  , resultDiagnostics :: ![Diagnostic]
  , resultResolution :: !(Maybe Resolution)
  , resultValue :: !(Maybe Value)
  , resultType :: !(Maybe Type)
  , resultAccepted :: !Bool
  }

emptySession :: Session
emptySession =
  Session
    { sessionImports = []
    , sessionDeclarations = []
    , sessionStatements = []
    , sessionLoaded = Nothing
    , sessionContext = emptyCompileContext
    }

{-| Classify a submission by its leading token. `import` and the declaration
    keywords place text at module scope; `let`, `var`, and the jump and loop
    keywords are statements; everything else is an expression. -}
classifyEntry :: [Token] -> EntryKind
classifyEntry tokens = case dropWhile isEndOfFile tokens of
  token : _ -> case tokenKind token of
    Keyword KwImport -> ImportEntry
    Keyword keyword | isDeclarationKeyword keyword -> DeclarationEntry
    Keyword keyword | isStatementKeyword keyword -> StatementEntry
    _ -> ExpressionEntry
  [] -> ExpressionEntry
 where
  isEndOfFile token = tokenKind token == EndOfFile

isDeclarationKeyword :: Keyword -> Bool
isDeclarationKeyword keyword =
  keyword `elem` [KwExport, KwConst, KwFn, KwAsync, KwType, KwTrait, KwImpl]

isStatementKeyword :: Keyword -> Bool
isStatementKeyword keyword =
  keyword `elem` [KwLet, KwVar, KwReturn, KwBreak, KwContinue, KwWhile, KwFor, KwLoop]

{-| Compile one submission against the current session. The session advances
    only when the entry is accepted, so a failed entry can never corrupt the
    context that already worked. -}
submitEntry :: Session -> Text -> IO EntryResult
submitEntry session entry = do
  probe <- newSource interactiveName entry
  let LexResult{lexTokens} = lexSource probe
      kind = classifyEntry lexTokens
      candidate = extend session kind entry
      (buffer, firstLine) = renderBuffer session kind entry
      entryStart = bufferOffsetOf session kind
  source <- newSource interactiveName buffer
  let result = runCompileWith (sessionContext session) source
      compiled = compileDiagnostics result
      staticallyValid = not (hasErrors compiled)
      evaluation = if staticallyValid then evaluateFor result kind else Nothing
      runtime = maybe [] outcomeDiagnostics evaluation
      diagnostics = compiled <> runtime
      accepted = staticallyValid && not (hasErrors runtime)
  pure
    EntryResult
      { resultSession = if accepted then commit session candidate kind else session
      , resultKind = kind
      , resultSource = source
      , resultFirstLine = firstLine
      , resultDiagnostics = diagnostics
      , resultResolution = compileResolution result
      , resultValue =
          if accepted && kind == ExpressionEntry then evaluation >>= outcomeValue else Nothing
      , resultType =
          if kind == ExpressionEntry
            then compileTypes result >>= entryType entryStart (Text.length entry)
            else Nothing
      , resultAccepted = accepted
      }

{-| The type of the submission itself: the widest expression the checker typed
    inside the entry's own region of the buffer. -}
entryType :: Int -> Int -> TypeInfo -> Maybe Type
entryType start width info = widestWithin start (start + width) info

{-| Where the submission starts in the assembled buffer, in scalars. -}
bufferOffsetOf :: Session -> EntryKind -> Int
bufferOffsetOf session kind =
  let (buffer, firstLine) = renderBuffer session kind Text.empty
      before = take (firstLine - 1) (Text.lines buffer)
   in sum (map ((+ 1) . Text.length) before)

{-| Only an expression produces a value to show. Declarations and bindings are
    evaluated as part of the buffer so their runtime failures surface, but they
    print nothing when they succeed. -}
evaluateFor :: CompileResult -> EntryKind -> Maybe EvalOutcome
evaluateFor result _ = case compileModule result of
  Nothing -> Nothing
  Just parsed -> Just (evaluateEntryPoint sessionFunction parsed)

{-| Compile the session exactly as it stands, with no new entry. `:browse` and
    `:context` use this so inspection cannot alter what the session holds. -}
inspectSession :: Session -> IO (Maybe Resolution, [Diagnostic])
inspectSession session = do
  let (buffer, _) = renderBuffer session StatementEntry Text.empty
  source <- newSource interactiveName buffer
  let result = runCompileWith (sessionContext session) source
  pure (compileResolution result, compileDiagnostics result)

interactiveName :: SourceName
interactiveName = SourceName "<interactive>"

{-| An expression is compiled but never remembered: it produces no binding, so
    replaying it on the next entry would repeat work without adding context. -}
commit :: Session -> Session -> EntryKind -> Session
commit previous candidate kind = case kind of
  ExpressionEntry -> previous
  _ -> candidate

extend :: Session -> EntryKind -> Text -> Session
extend session kind entry = case kind of
  ImportEntry -> session{sessionImports = sessionImports session <> [entry]}
  DeclarationEntry -> session{sessionDeclarations = sessionDeclarations session <> [entry]}
  StatementEntry -> session{sessionStatements = sessionStatements session <> [entry]}
  ExpressionEntry -> session

{-| Assemble the buffer that is actually compiled, and report the line the
    submission starts on so diagnostics are reported against what the reader
    typed rather than against the generated preamble.

    The buffer is a complete module: the session's imports, then its
    declarations, then one synthetic function holding every statement entered so
    far. Statements and expressions are placed inside that function; imports and
    declarations are placed at module scope. -}
renderBuffer :: Session -> EntryKind -> Text -> (Text, Int)
renderBuffer session kind entry = (Text.unlines whole, countLines before + 1)
 where
  header = maybe defaultHeader loadedPrefix (sessionLoaded session)
  loadedBody = maybe [] (pure . loadedRest) (sessionLoaded session)
  imports = sessionImports session <> [entry | kind == ImportEntry]
  declarations = sessionDeclarations session <> [entry | kind == DeclarationEntry]
  statements = sessionStatements session <> [entry | inFunction kind]
  opening = "fn " <> sessionFunction <> "() {"
  whole =
    [header] <> imports <> loadedBody <> declarations <> [opening] <> statements <> ["}"]
  before = case kind of
    ImportEntry -> [header] <> sessionImports session
    DeclarationEntry ->
      [header] <> imports <> loadedBody <> sessionDeclarations session
    _ ->
      [header] <> imports <> loadedBody <> declarations <> [opening] <> sessionStatements session

{-| Statements and expressions both live inside the synthetic function; only a
    statement is remembered afterwards. -}
inFunction :: EntryKind -> Bool
inFunction kind = kind == StatementEntry || kind == ExpressionEntry

countLines :: [Text] -> Int
countLines = length . concatMap Text.lines

defaultHeader :: Text
defaultHeader = "module Repl.Session"

sessionFunction :: Text
sessionFunction = "__session"

{-| Split a loaded file after its last import so session imports can be inserted
    where the grammar requires them, ahead of every declaration. -}
loadModule :: FilePath -> Text -> IO (Session -> Session, [Diagnostic], Maybe Resolution)
loadModule path text = do
  program <- compileProgram path
  let result = rootCompileResult program
      diagnostics = programDiagnostics program
      resolution = result >>= compileResolution
  case result >>= compileModule of
    Nothing -> pure (id, diagnostics, resolution)
    Just parsed -> do
      let cut = importCut parsed
          prefix = Text.take cut text
          rest = Text.drop cut text
          loaded =
            LoadedModule
              { loadedPath = path
              , loadedText = text
              , loadedPrefix = prefix
              , loadedRest = rest
              }
      pure
        ( \session -> session{sessionLoaded = Just loaded, sessionContext = programContext program}
        , diagnostics
        , resolution
        )

importCut :: Module -> Int
importCut parsed =
  case reverse (moduleImports parsed) of
    Located spanValue _ : _ -> unOffset (spanEnd spanValue)
    [] -> unOffset (spanEnd (locatedSpan (moduleName parsed)))

sessionExports :: Resolution -> [Text]
sessionExports resolution = map symbolName (resolutionExports resolution)

{-| Names the session context declares, with the synthetic entry function
    filtered out: it is an assembly detail, not something the reader wrote. -}
sessionDeclaredNames :: Resolution -> [Text]
sessionDeclaredNames resolution =
  filter (/= sessionFunction) (moduleSymbolNames resolution)

{-| Every name the reader can type at the prompt, including the locals their
    `let` and `var` entries bound. -}
sessionVisibleNames :: Resolution -> [Text]
sessionVisibleNames resolution =
  filter (/= sessionFunction) (boundSymbolNames resolution)

{-| Summarize the context one line per entry. A multi-line entry shows its
    first line with an ellipsis rather than replaying its whole body. -}
contextSummary :: Session -> [Text]
contextSummary session =
  concat
    [ map (("import  " <>) . summarize) (sessionImports session)
    , map (("declare " <>) . summarize) (sessionDeclarations session)
    , map (("bind    " <>) . summarize) (sessionStatements session)
    ]

summarize :: Text -> Text
summarize value = case Text.lines value of
  [single] -> single
  found : _ -> found <> " ..."
  [] -> value
