{-| @Repl.Session.Module — owns interactive session state -}
module Pudu.Repl.Session
  ( EntryKind (..)
  , EntryResult (..)
  , LoadedModule (..)
  , Session (..)
  , classifyEntry
  , contextSummary
  , inspectSession
  , inspectContext
  , inspectDocs
  , emptySession
  , loadModule
  , sessionDeclaredNames
  , sessionVisibleNames
  , sessionExports
  , submitEntry
  , typeOfEntry
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileContext, CompileResult (..), emptyCompileContext, runCompileWith)
import Pudu.Compiler.Program
  ( ProgramResult (..)
  , compileProgram
  , compileProgramSource
  , programDependencies
  , rootCompileResult
  )
import System.Directory (getCurrentDirectory)
import Pudu.Diagnostic (Diagnostic, hasErrors)
import Pudu.Doc (DocIndex)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Value (Value)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Module (..))
import qualified Pudu.Frontend.Token as Token
import Pudu.Frontend.Token (Keyword (..), Token (..), TokenKind (..), symbolText)
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
  , sessionDependencies :: ![(Text, Module)]
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
    , sessionDependencies = []
    }

{-| Classify a submission by its leading token. `import` and the declaration
    keywords place text at module scope; `let`, `var`, and the jump and loop
    keywords are statements; everything else is an expression.

    A loop's label is not part of that decision. `@outer for ...` is the same
    statement as `for ...`, and classifying it as an expression would evaluate
    it somewhere its assignments could not reach the session's bindings. -}
classifyEntry :: [Token] -> EntryKind
classifyEntry tokens = case afterLabel (dropWhile isEndOfFile tokens) of
  token : rest -> case tokenKind token of
    Keyword KwImport -> ImportEntry
    Keyword KwUnsafe -> if declaresFunction rest then DeclarationEntry else ExpressionEntry
    {-| `fn` declares a function and also opens one written as a value, and the
        name is the only thing that separates them: `fn double(n: Int)` declares,
        `fn(n: Int)` is a literal. Classified as a declaration, a literal typed
        at the prompt was read as a declaration missing its name and answered
        `E1001: expected identifier` — for an entry that names nothing because
        it is not naming anything.

        The same holds after `async`, which additionally opens a scope: `async
        with scope { .. }` is an expression however it ends. -}
    Keyword KwFn | not (namesFunction rest) -> ExpressionEntry
    Keyword KwAsync | not (asyncDeclares rest) -> ExpressionEntry
    Keyword keyword | isDeclarationKeyword keyword -> DeclarationEntry
    Keyword keyword | isStatementKeyword keyword -> StatementEntry
    _ -> ExpressionEntry
  [] -> ExpressionEntry
 where
  isEndOfFile token = tokenKind token == EndOfFile

{-| Skip a leading `@name` so what follows is classified on its own terms. -}
afterLabel :: [Token] -> [Token]
afterLabel tokens = case map tokenKind (take 2 tokens) of
  [labelSigil, Identifier _] | isSymbolKind "@" labelSigil -> drop 2 tokens
  _ -> tokens

{-| Whether what follows `fn` is a name, which is what makes it a declaration
    rather than a function written as a value. -}
namesFunction :: [Token] -> Bool
namesFunction tokens = case map tokenKind (take 1 tokens) of
  Identifier _ : _ -> True
  _ -> False

{-| Whether what follows `async` declares something. Only `async fn name`
    does; `async fn(` is a literal and `async with` opens a scope, and both are
    expressions. -}
asyncDeclares :: [Token] -> Bool
asyncDeclares tokens = case map tokenKind (take 2 tokens) of
  Keyword KwFn : rest -> case rest of
    Identifier _ : _ -> True
    _ -> False
  _ -> False

{-| `unsafe` opens a region in expression position and modifies a declaration in
    declaration position, so the entry is classified by what follows its
    optional capability list. -}
declaresFunction :: [Token] -> Bool
declaresFunction tokens = case map tokenKind (afterCapabilities tokens) of
  Keyword KwFn : _ -> True
  Keyword KwAsync : _ -> True
  _ -> False

afterCapabilities :: [Token] -> [Token]
afterCapabilities tokens = case tokens of
  token : rest
    | isSymbolKind "(" (tokenKind token) -> drop 1 (dropWhile (not . isSymbolKind ")" . tokenKind) rest)
  _ -> tokens

isSymbolKind :: Text -> TokenKind -> Bool
isSymbolKind expected kind = case kind of
  Token.Symbol symbol -> symbolText symbol == expected
  _ -> False

isDeclarationKeyword :: Keyword -> Bool
isDeclarationKeyword keyword =
  keyword `elem` [KwExport, KwConst, KwFn, KwAsync, KwType, KwTrait, KwImpl, KwUnsafe, KwComptime, KwMacro]

isStatementKeyword :: Keyword -> Bool
isStatementKeyword keyword =
  keyword `elem` [KwLet, KwVar, KwReturn, KwBreak, KwContinue, KwWhile, KwFor, KwLoop]

{-| The type of an expression, worked out without running it.

    Completion asks this to know what a receiver is before offering what it
    carries. It must not go through `submitEntry`, which evaluates: a reader
    pressing tab after `removeFile("notes")` has asked what methods a result
    has, not for the file to be removed. Nothing here reaches the evaluator, so
    nothing can happen that the reader did not ask for.

    The session is left exactly as it was, whatever the expression turns out to
    be. -}
typeOfEntry :: Session -> Text -> IO (Maybe Type)
typeOfEntry session entry
  | Text.null (Text.strip entry) = pure Nothing
  | otherwise = do
      probe <- newSource interactiveName entry
      let LexResult{lexTokens} = lexSource probe
          kind = classifyEntry lexTokens
      if kind /= ExpressionEntry
        then pure Nothing
        else do
          let candidate = extend session kind entry
              (buffer, _) = renderBuffer session kind entry
              entryStart = bufferOffsetOf session kind
          source <- newSource interactiveName buffer
          (result, _) <- compileBuffer session candidate source
          pure $
            if hasErrors (compileDiagnostics result)
              then Nothing
              else compileTypes result >>= entryType entryStart (Text.length entry)

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
  (result, dependencies) <- compileBuffer session candidate source
  let compiled = compileDiagnostics result
      staticallyValid = not (hasErrors compiled)
  evaluation <-
    if staticallyValid then evaluateFor dependencies result else pure Nothing
  let runtime = maybe [] outcomeDiagnostics evaluation
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
{-| Evaluate the session's buffer with the loaded program's dependencies
    linked, so a call into an imported module works at the prompt exactly as it
    would in the program that was loaded. -}
evaluateFor :: [(Text, Module)] -> CompileResult -> IO (Maybe EvalOutcome)
evaluateFor dependencies result = case compileModule result of
  Nothing -> pure Nothing
  {-| The entry's own literal kinds go with it, so `let count: Int8 = 127` means
      at the prompt what it means in a file. A session that answered differently
      from the program it loaded would be worse than no session. -}
  Just parsed ->
    Just
      <$> evaluateProgramEntry
        (compileIntegerKinds result)
        dependencies
        sessionFunction
        parsed

{-| Compile the assembled buffer, and say what it must be linked against.

    A session with no imports compiles against its own context, which is what
    `:load` established and what every plain expression needs. A session that
    has imported something is compiled as a *program*: its imports are ordinary
    imports and have to reach the same files on disk a compiled program's would.

    Without that second path the session resolved an import loosely enough to
    type-check and then had nothing to link, so `Std.Math.factorial` was a name
    the checker knew and the evaluator did not. -}
compileBuffer :: Session -> Session -> Source -> IO (CompileResult, [(Text, Module)])
compileBuffer session candidate source
  | null (sessionImports candidate) = do
      result <- runCompileWith (sessionContext session) source
      pure (result, sessionDependencies session)
  | otherwise = do
      root <- getCurrentDirectory
      program <- compileProgramSource root source
      case rootCompileResult program of
        Nothing -> do
          result <- runCompileWith (sessionContext session) source
          pure (result, sessionDependencies session)
        Just result ->
          pure
            ( result{compileDiagnostics = programDiagnostics program}
            , programDependencies program
            )

{-| Compile the session exactly as it stands, with no new entry. `:browse` and
    `:context` use this so inspection cannot alter what the session holds. -}
{-| The session's own documentation index.

    It is produced by the same compile the session would run, so `:doc` and
    `:search` describe exactly the code in front of the reader — including
    entries typed at the prompt a moment earlier, which no pre-built index
    could know about. -}
inspectDocs :: Session -> IO (Maybe DocIndex)
inspectDocs session = do
  let (buffer, _) = renderBuffer session StatementEntry Text.empty
  source <- newSource interactiveName buffer
  compileDocs <$> runCompileWith (sessionContext session) source

inspectSession :: Session -> IO (Maybe Resolution, [Diagnostic])
inspectSession session = do
  (resolution, _, diagnostics) <- inspectContext session
  pure (resolution, diagnostics)

{-| Compile the session as it stands and return its resolution, its parsed
    module, and its diagnostics. Commands that describe the session read the
    module directly, which keeps them answering from the same text the session
    would compile rather than from a second record that could drift. -}
inspectContext :: Session -> IO (Maybe Resolution, Maybe Module, [Diagnostic])
inspectContext session = do
  let (buffer, _) = renderBuffer session StatementEntry Text.empty
  source <- newSource interactiveName buffer
  result <- runCompileWith (sessionContext session) source
  pure (compileResolution result, compileModule result, compileDiagnostics result)

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
  {-| The loaded file's text is one element among lines that `Text.unlines`
      will join, and it carries the newline every file ends with. Left there, it
      becomes a second one — a blank line that the assembled buffer has and that
      counting the elements' lines does not, so every offset after it was short
      by one. Nothing about the *text* was wrong, which is why the buffer
      compiled and ran correctly while `:type` reported the runtime shape of
      whatever the misplaced window happened to land on: `"hello"` came back as
      `string` rather than `Str` for the whole session once a file was loaded. -}
  loadedBody = maybe [] (pure . Text.dropWhileEnd (== '\n') . loadedRest) (sessionLoaded session)
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
        ( \session ->
            session
              { sessionLoaded = Just loaded
              , sessionContext = programContext program
              , sessionDependencies = programDependencies program
              }
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
