{-| @Repl.Session.Module — owns interactive session state -}
module Pudu.Repl.Session
  ( EntryKind (..)
  , EntryResult (..)
  , LoadedModule (..)
  , Session (..)
  , classifyEntry
  , contextSummary
  , emptySession
  , inspectContext
  , inspectDocs
  , inspectEntryType
  , inspectSession
  , invalidEntryStart
  , loadModule
  , sessionDeclaredNames
  , sessionExports
  , sessionVisibleNames
  , submitEntry
  , submitEntryInContext
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
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (Error)
  , diagnostic
  , hasErrors
  , mkDiagnosticCode
  , withHelp
  )
import Pudu.Doc (DocIndex)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Context (EvaluationContext)
import Pudu.Repl.Evaluation (declarationUpdateAllowed, evaluateEntry, retainedTypes)
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Value (Value)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Expression.Recovery (prefixDiagnostic, reservedKeywordGuidance)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Module (..))
import qualified Pudu.Frontend.Token as Token
import Pudu.Frontend.Token (Keyword (..), SymbolKind (..), Token (..), TokenKind (..), symbolText)
import Pudu.Semantic (Resolution (..), Symbol (..), boundSymbolNames, moduleSymbolNames)
import Pudu.Type (Type, TypeInfo, widestWithin)
import Pudu.Source (Source, SourceName (SourceName), newSource, spanEnd, unOffset)

{-| @Repl.Session.Loaded — a file compiled as the session context -}
data LoadedModule = LoadedModule
  { loadedPath :: !FilePath, loadedText :: !Text, loadedPrefix :: !Text, loadedRest :: !Text
  } deriving stock (Eq, Show)

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
  , sessionRetainedTypes :: !(Maybe TypeInfo)
  } deriving stock (Eq, Show)

{-| @Repl.Session.EntryKind — how one submission is placed in the buffer -}
data EntryKind = ImportEntry | DeclarationEntry | StatementEntry | ExpressionEntry
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
emptySession = Session [] [] [] Nothing emptyCompileContext [] Nothing

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
    {-| fn and async only declare when followed by an identifier; otherwise expression. -}
    Keyword KwFn | not (namesFunction rest) -> ExpressionEntry
    Keyword KwAsync | not (asyncDeclares rest) -> ExpressionEntry
    Keyword keyword | isDeclarationKeyword keyword -> DeclarationEntry
    Keyword keyword | isStatementKeyword keyword -> StatementEntry
    _ -> if isTopLevelAssignment tokens then StatementEntry else ExpressionEntry
  [] -> ExpressionEntry
 where
  isEndOfFile token = tokenKind token == EndOfFile

{-| Check for an assignment operator at bracket depth 0 outside sub-expressions. -}
isTopLevelAssignment :: [Token] -> Bool
isTopLevelAssignment = go (0 :: Int)
 where
  go depth (token : rest) = case tokenKind token of
    Token.Symbol symbol
      | symbolText symbol `elem` ["(", "[", "{"] -> go (depth + 1) rest
      | symbolText symbol `elem` [")", "]", "}"] -> go (max 0 (depth - 1)) rest
      | symbolText symbol == "=" -> depth == 0 || go depth rest
    _ -> go depth rest
  go _ [] = False

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

{-| Detect an entry whose leading token is not a valid start for any Pudu
    construct (e.g. an orphaned binary operator like `<< 100` or `.foo`),
    preventing it from gluing onto preceding statements in the session buffer. -}
invalidEntryStart :: [Token] -> Maybe Diagnostic
invalidEntryStart tokens = case dropWhile isEndOfFile tokens of
  token : _ -> case tokenKind token of
    Keyword kw
      | isDeclarationKeyword kw || isStatementKeyword kw -> Nothing
      | kw `elem` [KwImport, KwIf, KwMatch, KwTrue, KwFalse, KwNull] -> Nothing
      | Just guidance <- reservedKeywordGuidance kw ->
          mkDiag "E1041" (tokenSpan token) "reserved keyword in expression position" (Just guidance)
      | otherwise ->
          let (msg, help) = prefixDiagnostic token
           in mkDiag "E1040" (tokenSpan token) msg help
    Token.Symbol symbol
      | symbol `elem` validPrefixSymbols -> Nothing
      | otherwise ->
          let (msg, help) = prefixDiagnostic token
           in mkDiag "E1040" (tokenSpan token) msg help
    _ -> Nothing
  [] -> Nothing
 where
  isEndOfFile t = tokenKind t == EndOfFile
  validPrefixSymbols =
    [ SymLeftParen, SymLeftBracket, SymLeftBrace, SymHash, SymAt
    , SymBang, SymMinus, SymAmpersand, SymStar, SymTilde
    ]
  mkDiag codeText spanVal msg help = do
    code <- mkDiagnosticCode codeText
    diag <- diagnostic code Error spanVal msg
    pure (maybe diag (`withHelp` diag) help)

{-| The type of an expression, worked out without running it. -}
typeOfEntry :: Session -> Text -> IO (Maybe Type)
typeOfEntry session entry
  | Text.null (Text.strip entry) = pure Nothing
  | otherwise = do
      (_, _, diagnostics, found) <- inspectEntryType session entry
      pure (if hasErrors diagnostics then Nothing else found)

{-| Compile one entry for inspection without entering the evaluator. The
    returned source and first line are the exact assembled window used by an
    ordinary submission, so commands can render compiler diagnostics against
    what the reader typed without duplicating offset logic. -}
inspectEntryType :: Session -> Text -> IO (Source, Int, [Diagnostic], Maybe Type)
inspectEntryType session entry = do
  probe <- newSource interactiveName entry
  let LexResult{lexTokens} = lexSource probe
  case invalidEntryStart lexTokens of
    Just diag -> pure (probe, 1, [diag], Nothing)
    Nothing -> do
      let kind = classifyEntry lexTokens
      candidate <- extend session kind entry
      let (buffer, firstLine) = renderBuffer candidate kind entry
          entryStart = bufferOffsetOf candidate kind entry
      source <- newSource interactiveName buffer
      (result, _) <- compileBuffer session candidate source
      let diagnostics = compileDiagnostics result
          found =
            if kind == ExpressionEntry && not (hasErrors diagnostics)
              then compileTypes result >>= entryType entryStart (Text.length entry)
              else Nothing
      pure (source, firstLine, diagnostics, found)

{-| Compile one submission against the current session. The session advances
    only when the entry is accepted, so a failed entry can never corrupt the
    context that already worked. -}
submitEntry :: Session -> Text -> IO EntryResult
submitEntry = submitEntryUsing Nothing (const (pure ()))

{-| The publication callback must only store the supplied snapshot without
    throwing or blocking; the runtime invokes it inside its masked commit. -}
submitEntryInContext
  :: EvaluationContext -> (Session -> IO ()) -> Session -> Text -> IO EntryResult
submitEntryInContext context = submitEntryUsing (Just context)

submitEntryUsing
  :: Maybe EvaluationContext -> (Session -> IO ()) -> Session -> Text -> IO EntryResult
submitEntryUsing runtimeContext publish session entry = do
  probe <- newSource interactiveName entry
  let LexResult{lexTokens} = lexSource probe
      kind = classifyEntry lexTokens
  case invalidEntryStart lexTokens of
    Just diag -> pure EntryResult
      { resultSession = session, resultKind = kind, resultSource = probe, resultFirstLine = 1
      , resultDiagnostics = [diag], resultResolution = Nothing, resultValue = Nothing
      , resultType = Nothing, resultAccepted = False
      }
    Nothing -> do
      candidate <- case (runtimeContext, kind) of
        (Just _, StatementEntry) -> pure session{sessionStatements = sessionStatements session <> [entry]}
        _ -> extend session kind entry
      let (buffer, firstLine) = renderBuffer candidate kind entry
          entryStart = bufferOffsetOf candidate kind entry
      source <- newSource interactiveName buffer
      (result, dependencies) <- compileBuffer session candidate source
      let compiled = compileDiagnostics result
          staticallyValid = not (hasErrors compiled)
          acceptedSession = case runtimeContext of
            Nothing -> commit session candidate kind
            Just _ -> candidate
              { sessionStatements = sessionStatements candidate <> [entry | kind == ExpressionEntry]
              , sessionRetainedTypes = retainedTypes result
              , sessionDependencies = dependencies
              }
          publishOutcome outcome = publish $
            if hasErrors (outcomeDiagnostics outcome) then session else acceptedSession
          contextCompatible = null (sessionStatements session)
            || (kind /= ImportEntry
                && (kind /= DeclarationEntry || declarationUpdateAllowed entryStart (Text.length entry) result)
                && show (sessionDependencies session) == show dependencies)
      evaluation <- if not staticallyValid then pure Nothing else case runtimeContext of
        Nothing -> evaluateFor dependencies result
        Just context -> evaluateEntry context (sessionRetainedTypes session) contextCompatible
          (kind == StatementEntry || kind == ExpressionEntry) (kind /= DeclarationEntry && not (null (sessionStatements session))) entryStart (Text.length entry) dependencies result publishOutcome
      let runtime = maybe [] outcomeDiagnostics evaluation
          diagnostics = compiled <> runtime
          accepted = staticallyValid && not (hasErrors runtime) && case evaluation of
            Just _ -> True
            Nothing -> False
      pure EntryResult
        { resultSession = if accepted then acceptedSession else session
        , resultKind = kind, resultSource = source, resultFirstLine = firstLine
        , resultDiagnostics = diagnostics, resultResolution = compileResolution result
        , resultValue = if accepted && kind == ExpressionEntry then evaluation >>= outcomeValue else Nothing
        , resultType = if kind == ExpressionEntry
            then compileTypes result >>= entryType entryStart (Text.length entry)
            else Nothing
        , resultAccepted = accepted
        }

{-| The type of the submission itself: the widest expression the checker typed
    inside the entry's own region of the buffer. -}
entryType :: Int -> Int -> TypeInfo -> Maybe Type
entryType start width info = widestWithin start (start + width) info

{-| Where the submission starts in the assembled buffer, in scalars. -}
bufferOffsetOf :: Session -> EntryKind -> Text -> Int
bufferOffsetOf session kind entry =
  let (buffer, firstLine) = renderBuffer session kind entry
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
    A session with no imports compiles against its own context; one with
    imports compiles as a program linked against resolved dependencies. -}
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

{-| The session's own documentation index. -}
inspectDocs :: Session -> IO (Maybe DocIndex)
inspectDocs session = do
  let (buffer, _) = renderBuffer session StatementEntry Text.empty
  source <- newSource interactiveName buffer
  compileDocs . fst <$> compileBuffer session session source

inspectSession :: Session -> IO (Maybe Resolution, [Diagnostic])
inspectSession session = do
  (resolution, _, diagnostics) <- inspectContext session
  pure (resolution, diagnostics)

{-| Compile the session as it stands and return its resolution, module, and diagnostics. -}
inspectContext :: Session -> IO (Maybe Resolution, Maybe Module, [Diagnostic])
inspectContext session = do
  let (buffer, _) = renderBuffer session StatementEntry Text.empty
  source <- newSource interactiveName buffer
  (result, _) <- compileBuffer session session source
  pure (compileResolution result, compileModule result, compileDiagnostics result)

interactiveName :: SourceName
interactiveName = SourceName "<interactive>"

{-| An expression is compiled but never remembered: it produces no binding, so
    replaying it on the next entry would repeat work without adding context. -}
commit :: Session -> Session -> EntryKind -> Session
commit previous candidate kind = case kind of
  ExpressionEntry -> previous
  _ -> candidate

extend :: Session -> EntryKind -> Text -> IO Session
extend session kind entry = case kind of
  ImportEntry -> pure session{sessionImports = sessionImports session <> [entry]}
  DeclarationEntry -> do
    entries <- replaceOrAppend kind entry (sessionDeclarations session)
    pure session{sessionDeclarations = entries}
  StatementEntry -> do
    entries <- replaceOrAppend kind entry (sessionStatements session)
    pure session{sessionStatements = entries}
  ExpressionEntry -> pure session

{-| Select replacement using real tokens; comments and identifier spelling are
    owned by the lexer rather than a second textual approximation. -}
replaceOrAppend :: EntryKind -> Text -> [Text] -> IO [Text]
replaceOrAppend kind newEntry existing = do
  wanted <- extractEntryName kind newEntry
  case wanted of
    Nothing -> pure (existing <> [newEntry])
    Just name -> do
      names <- mapM (extractEntryName kind) existing
      pure $ if Just name `elem` names
        then zipWith (\old found -> if found == Just name then newEntry else old) existing names
        else existing <> [newEntry]

extractEntryName :: EntryKind -> Text -> IO (Maybe Text)
extractEntryName kind text = do
  source <- newSource interactiveName text
  let LexResult{lexTokens, lexDiagnostics} = lexSource source
      tokens = filter ((/= EndOfFile) . tokenKind) lexTokens
  pure $ if hasErrors lexDiagnostics then Nothing else case kind of
    DeclarationEntry -> if declarationCount tokens == 1 then declaration tokens else Nothing
    StatementEntry -> if length (Text.lines text) == 1 then binding tokens else Nothing
    _ -> Nothing
 where
  declarationCount = countAt (0 :: Int) (0 :: Int)
  countAt _ total [] = total
  countAt depth total (token : rest) = case tokenKind token of
    Token.Symbol symbol
      | symbolText symbol `elem` ["(", "[", "{"] -> countAt (depth + 1) total rest
      | symbolText symbol `elem` [")", "]", "}"] -> countAt (max 0 (depth - 1)) total rest
    Keyword keyword | depth == 0 && keyword `elem` [KwFn, KwConst, KwType, KwTrait, KwMacro] ->
      countAt depth (total + 1) rest
    _ -> countAt depth total rest
  declaration (token : rest) = case tokenKind token of
    Keyword keyword | keyword `elem` [KwExport, KwAsync, KwComptime] -> declaration rest
    Keyword KwUnsafe -> declaration (afterCapabilities rest)
    Keyword keyword | keyword `elem` [KwFn, KwConst, KwType, KwTrait, KwMacro] -> named rest
    _ -> Nothing
  declaration [] = Nothing
  binding (token : rest) = case tokenKind token of
    Keyword keyword | keyword `elem` [KwLet, KwVar] -> case rest of
      nameToken : marker : _ | isSymbolKind "=" (tokenKind marker) || isSymbolKind ":" (tokenKind marker) -> named [nameToken]
      _ -> Nothing
    _ -> Nothing
  binding [] = Nothing
  named (token : _) = case tokenKind token of
    Identifier name -> Just name
    _ -> Nothing
  named [] = Nothing

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
  loadedBody = maybe [] (pure . Text.dropWhileEnd (== '\n') . loadedRest) (sessionLoaded session)
  imports = sessionImports session
  declarations = sessionDeclarations session
  statements = sessionStatements session <> [entry | kind == ExpressionEntry]
  opening = "fn " <> sessionFunction <> "() {"
  whole =
    [header] <> imports <> loadedBody <> declarations <> [opening] <> statements <> ["}"]
  before = case kind of
    ImportEntry -> [header] <> beforeEntry imports
    DeclarationEntry ->
      [header] <> imports <> loadedBody <> beforeEntry declarations
    StatementEntry ->
      [header] <> imports <> loadedBody <> declarations <> [opening] <> beforeEntry (sessionStatements session)
    ExpressionEntry ->
      [header] <> imports <> loadedBody <> declarations <> [opening] <> sessionStatements session

  beforeEntry entries = case reverse entries of
    final : rest | final == entry -> reverse rest
    _ -> takeWhile (/= entry) entries

countLines :: [Text] -> Int
countLines = sum . map ((+ 1) . Text.count "\n")

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
          loaded = LoadedModule path text (Text.take cut text) (Text.drop cut text)
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
sessionExports = map symbolName . resolutionExports

{-| Names the session context declares, with the synthetic entry function
    filtered out: it is an assembly detail, not something the reader wrote. -}
sessionDeclaredNames :: Resolution -> [Text]
sessionDeclaredNames = filter (/= sessionFunction) . moduleSymbolNames

{-| Every name the reader can type at the prompt, including the locals their
    `let` and `var` entries bound. -}
sessionVisibleNames :: Resolution -> [Text]
sessionVisibleNames = filter (/= sessionFunction) . boundSymbolNames

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
