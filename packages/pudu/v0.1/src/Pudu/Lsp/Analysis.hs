{-| @Program.Lsp.Analysis — one document compiled as the program it is -}
module Pudu.Lsp.Analysis
  ( analyse
  , analyseIn
  , analyseOver
  , documentSourceRoot
  , fileUriPath
  , pathOf
  ) where

import qualified Data.ByteString as ByteString
import Data.List (isPrefixOf, sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Ord (Down (..))
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Pudu.Compiler (CompileContext (..), CompileResult (..), recoveredSyntax)
import Pudu.Doc (DocIndex, buildIndexFrom)
import Pudu.Frontend.Expand (expandModule)
import Pudu.Frontend.Syntax.Tree (Module)
import Pudu.Frontend.Token (Token (..), TokenKind (..))
import Pudu.Semantic (Resolution, resolveModule, resolveModuleWith)
import Pudu.Type (TypeInfo, deriveDefinitionTypes, overlayTypes)
import Pudu.Type.Interface.Graph (importsFor)
import Pudu.Compiler.Program
  ( ProgramResult (..)
  , compileProgramSourceOver
  , programDocs
  , rootCompileResult
  , sourceRootFor
  )
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Lsp.Context (declaredModule)
import Pudu.Lsp.Diagnostics (elsewhereFor)
import Pudu.Lsp.Documents (Analysis (..), DeclaredMethod)
import Pudu.Lsp.Shapes (programRecords, programSums, programTraits)
import Pudu.Source (Source, SourceName (..), newSource, sourceName)
import Pudu.Type.Value (nominalKey)
import System.Directory (doesDirectoryExist, doesFileExist, getCurrentDirectory)
import System.FilePath (addTrailingPathSeparator, normalise, takeDirectory, (</>))

{-| Compile one document's text as the program it is, under the source root
    its own path and module name give it.

    The compile is the ordinary one, so an editor sees exactly what `pudu check`
    would print — the same codes, spans, and help — and `pudu doc` and the
    editor agree about every signature. A second implementation for the editor
    would drift from the first within a release. -}
analyse :: Text -> Text -> IO Analysis
analyse uri content = do
  root <- documentSourceRoot [] uri content
  analyseIn root uri content

analyseIn :: FilePath -> Text -> Text -> IO Analysis
analyseIn = analyseOver Map.empty

{-| `analyseIn` with the text of other open documents, by normalised path,
    read in place of the disk for any module the program imports. -}
analyseOver :: Map FilePath Text -> FilePath -> Text -> Text -> IO Analysis
analyseOver overlay root uri content = do
  source <- newSource (SourceName (pathOf uri)) content
  program <- compileProgramSourceOver overlay root source
  -- Only a document whose root did not parse needs the recovered tree, and
  -- only then is it built.
  let recovered = recoveredSyntax source
      compiledRoot = rootCompileResult program
      tokens = maybe (fst recovered) compileTokens compiledRoot
      authored = compiledRoot >>= authoredView source tokens (programContext program)
      written = case authored of
        Just view -> Just (authoredTree view)
        Nothing -> maybe (snd recovered) compileSyntax compiledRoot
  elsewhere <- elsewhereFor source written program
  pure
    Analysis
      { analysisText = content
      , analysisSource = source
      , analysisDiagnostics = programDiagnostics program
      , analysisElsewhere = elsewhere
      , analysisFileIndex = case authored of
          Just view -> authoredDocs view
          Nothing -> fromMaybe mempty (compiledRoot >>= compileDocs)
      , analysisProgramIndex = programDocs program
      , analysisResolution = case authored of
          Just view -> Just (authoredResolution view)
          Nothing -> compiledRoot >>= compileResolution
      , analysisTypes = case (authored, compiledRoot >>= compileTypes) of
          (Just view, Just checked) -> Just (overlayTypes checked (authoredTypes view))
          (_, checked) -> checked
      , analysisTokens = tokens
      , analysisModule = written
      , analysisSums = programSums program
      , analysisRecords = programRecords program
      , analysisTraits = programTraits program
      , analysisMethods = programMethods program
      , analysisExports = contextExports (programContext program)
      , analysisDependencies =
          Set.fromList
            [ normalise (Text.unpack (unSourceName (sourceName dependency)))
            | dependency <- Map.elems (programNamedSources program)
            , sourceName dependency /= sourceName source
            ]
      }

{-| The document as written, when it uses derive syntax: its tree with the
    `derive` declarations and `derives` clauses elaboration removes before
    checking, resolved and indexed the way the compile resolves and indexes
    the checked tree. A cursor is on authored text, so hover, definition,
    references, and completion context answer from this; types and methods
    still come from the checked program. A document without derive syntax
    has nothing elaboration removed and reuses the compile's own products. -}
data AuthoredView = AuthoredView
  { authoredTree :: !Module
  , authoredResolution :: !Resolution
  , authoredDocs :: !DocIndex
  {-| What each template expression was checked as, once and generically. -}
  , authoredTypes :: !TypeInfo
  }

authoredView :: Source -> [Token] -> CompileContext -> CompileResult -> Maybe AuthoredView
authoredView source tokens context compiled
  | not (any derives tokens) = Nothing
  | Nothing <- compileSyntax compiled = Nothing
  | otherwise = do
      parsed <- snd (recoveredSyntax source)
      let (expanded, _) = expandModule parsed
          (resolution, _) =
            if contextStrictImports context
              then resolveModuleWith (contextExports context) expanded
              else resolveModule expanded
      pure AuthoredView
        { authoredTree = expanded
        , authoredResolution = resolution
        , authoredDocs = buildIndexFrom tokens (compileSchemes compiled) expanded
        , authoredTypes = deriveDefinitionTypes (importsFor (contextTypes context) expanded) expanded
        }
 where
  derives token = case tokenKind token of
    Identifier word -> word == "derive" || word == "derives"
    _ -> False

{-| The methods every module of the program declared, by the canonical key of
    their owner. Each module's check publishes only its own, so the program's
    are the union, gathered once per analysis. -}
programMethods :: ProgramResult -> Map Text [DeclaredMethod]
programMethods program =
  Map.fromListWith (flip (<>))
    [ (nominalKey owner, [(name, scheme, at)])
    | compiled <- Map.elems (programModules program)
    , (owner, name, scheme, at) <- compileMethods compiled
    ]

{-| The module source root a document's imports are resolved from.

    A file that declares its module is rooted exactly as `pudu check` roots it:
    its path with the module's segments taken off the end, so
    `workspace/src/App/Main.pudu` declaring `App.Main` is rooted at
    `workspace/src`, whatever folder the editor opened. The module name is read
    from the header's tokens, which exist while the rest of the text does not
    parse. Each document is rooted on its own, so two programs in one workspace
    never read each other's modules.

    A file whose header is not written yet is rooted at the most specific
    workspace folder holding it, or failing that at the nearest directory with
    a project marker (`pudu.toml`, `pudu.cabal`, `.git`, `lib`), within a few
    levels, or its own directory. A document that is not a file — an untitled
    buffer — is rooted at the first workspace folder, or the working
    directory. -}
documentSourceRoot :: [FilePath] -> Text -> Text -> IO FilePath
documentSourceRoot folders uri content = case fileUriPath uri of
  Nothing -> maybe getCurrentDirectory pure (firstFolder folders)
  Just path -> do
    source <- newSource (SourceName (Text.pack path)) (headerOf content)
    case declaredModule (lexTokens (lexSource source)) of
      Just name -> pure (fst (sourceRootFor path name))
      Nothing -> case holding (takeDirectory path) of
        Just folder -> pure folder
        Nothing -> nearestMarked (takeDirectory path)
 where
  firstFolder candidates = case candidates of
    folder : _ -> Just folder
    [] -> Nothing
  holding directory =
    firstFolder
      [ folder
      | folder <- sortOn (Down . length) folders
      , addTrailingPathSeparator (normalise folder) `isPrefixOf` addTrailingPathSeparator (normalise directory)
      ]
  nearestMarked directory = walk directory (8 :: Int)
   where
    walk current depth
      | depth <= 0 = pure directory
      | otherwise = do
          marked <- or <$> sequence
            [ doesFileExist (current </> "pudu.toml")
            , doesFileExist (current </> "pudu.cabal")
            , doesDirectoryExist (current </> ".git")
            , doesDirectoryExist (current </> "lib")
            ]
          let parent = takeDirectory current
          if marked
            then pure current
            else if parent == current then pure directory else walk parent (depth - 1)

{-| The start of a document, where its `module` header is: a header comes
    before any declaration, after at most a leading comment, so lexing the
    whole document to find it would be work thrown away. A header after 64
    lines of comment is not found, and the document is rooted as one without
    a header. -}
headerOf :: Text -> Text
headerOf = Text.unlines . take 64 . Text.lines

{-| The filesystem path a `file:` URI names, percent-decoded; nothing for any
    other scheme. -}
fileUriPath :: Text -> Maybe FilePath
fileUriPath uri = Text.unpack . decodeUri <$> Text.stripPrefix "file://" uri

pathOf :: Text -> Text
pathOf uri = maybe uri decodeUri (Text.stripPrefix "file://" uri)

{-| Turn `%20` and friends back into the scalars they stand for. -}
decodeUri :: Text -> Text
decodeUri input = either (const input) id (Encoding.decodeUtf8' (ByteString.pack (go input)))
 where
  go rest = case Text.uncons rest of
    Nothing -> []
    Just ('%', remaining)
      | Text.length hex == 2, Just value <- hexValue hex ->
          fromIntegral value : go (Text.drop 2 remaining)
     where
      hex = Text.take 2 remaining
    Just (scalar, remaining) -> ByteString.unpack (Encoding.encodeUtf8 (Text.singleton scalar)) <> go remaining

  hexValue hex = Text.foldl' step (Just 0) hex
  step accumulated scalar = do
    total <- accumulated
    digit <- hexDigit scalar
    pure (total * 16 + digit)
  hexDigit scalar
    | scalar >= '0' && scalar <= '9' = Just (fromEnum scalar - fromEnum '0')
    | scalar >= 'a' && scalar <= 'f' = Just (fromEnum scalar - fromEnum 'a' + 10)
    | scalar >= 'A' && scalar <= 'F' = Just (fromEnum scalar - fromEnum 'A' + 10)
    | otherwise = Nothing
