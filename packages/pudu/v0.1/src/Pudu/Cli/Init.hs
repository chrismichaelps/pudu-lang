{-| @Pudu.Cli.Init — safely create a canonical Pudu project. -}
module Pudu.Cli.Init
  ( InitError (..)
  , createProject
  , createProjectWith
  , packageNameFrom
  , renderInitError
  ) where

import Control.Exception (IOException, bracket, displayException, try)
import Data.Char (isAscii, isAlphaNum, toLower)
import Data.List (group)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Package.Identity (PackageId (..), defaultRoot, parsePackageId, renderPackageId, validRoot, validSegment)
import Pudu.Version (languageConstraint)
import System.Directory
  ( canonicalizePath
  , createDirectory
  , createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , doesPathExist
  , getCurrentDirectory
  , pathIsSymbolicLink
  , removeDirectoryRecursive
  , renameFile
  )
import System.FilePath (dropTrailingPathSeparator, normalise, takeFileName, (</>))
import System.IO.Error (isAlreadyExistsError, isDoesNotExistError)

{-| A refusal that leaves user-owned project content unchanged. -}
data InitError
  = EmptyProjectPath
  | UnnamedProjectPath FilePath
  | InvalidPackageName String
  | InvalidPackageIdentity Text
  | ReservedPackageName Text
  | SymbolicLinkNotAllowed FilePath
  | ManifestAlreadyExists FilePath
  | DirectoryRequired FilePath
  | RegularFileRequired FilePath
  | InitializationInProgress FilePath
  | PathChangedDuringInitialization FilePath
  | InitIoFailure Text
  deriving stock (Eq, Show)

{-| Render one stable command-line explanation without exposing exception constructors. -}
renderInitError :: InitError -> Text
renderInitError problem = case problem of
  EmptyProjectPath -> "project directory cannot be empty"
  UnnamedProjectPath path -> Text.pack path <> " does not name a project directory"
  InvalidPackageName name ->
    "cannot derive a package name from " <> Text.pack (show name)
  InvalidPackageIdentity message -> message
  ReservedPackageName name -> name <> " is a reserved package name"
  SymbolicLinkNotAllowed path -> Text.pack path <> " must not be a symbolic link"
  ManifestAlreadyExists path -> Text.pack path <> " already exists"
  DirectoryRequired path -> Text.pack path <> " must be a real directory"
  RegularFileRequired path -> Text.pack path <> " must be a regular file"
  InitializationInProgress path ->
    "project initialization is already in progress at " <> Text.pack path
  PathChangedDuringInitialization path ->
    Text.pack path <> " appeared while the project was being initialized"
  InitIoFailure message -> message

{-| Normalize a human directory name to the package identity grammar.

    Every character outside lowercase ASCII letters and digits becomes a
    separator, and a run of separators becomes one. Only separators collapse:
    a doubled letter is part of the name, so `hello` stays `hello`. -}
packageNameFrom :: String -> Either InitError Text
packageNameFrom directoryName =
  let mapped = map normalize directoryName
      collapsed = concatMap separatorsOnce (group mapped)
      packageName = Text.dropAround (== '-') (Text.pack collapsed)
   in if not (validSegment packageName)
        then Left (InvalidPackageName directoryName)
        else
          if case validRoot (defaultRoot (LocalName packageName)) of
               Left _ -> True
               Right _ -> False
            then Left (ReservedPackageName packageName)
            else Right packageName
  where
    normalize character
      | isAscii character && isAlphaNum character = toLower character
      | otherwise = '-'
    separatorsOnce run = case run of
      '-' : _ -> "-"
      _ -> run

{-| Create a project or return one typed refusal. Host failures are translated at
    this boundary; expected collisions never travel as exceptions. -}
createProject :: Maybe FilePath -> IO (Either InitError FilePath)
createProject target = createProjectWith target Nothing False

createProjectWith :: Maybe FilePath -> Maybe Text -> Bool -> IO (Either InitError FilePath)
createProjectWith target identity library = do
  attempted <- try (createProjectIo target identity library) :: IO (Either IOException (Either InitError FilePath))
  pure $ case attempted of
    Left problem -> Left (InitIoFailure (Text.pack (displayException problem)))
    Right result -> result

createProjectIo :: Maybe FilePath -> Maybe Text -> Bool -> IO (Either InitError FilePath)
createProjectIo target identity library = do
  resolved <- resolveInitRoot target identity
  case resolved of
    Left problem -> pure (Left problem)
    Right (root, packageId) -> initialize root packageId library

resolveInitRoot :: Maybe FilePath -> Maybe Text -> IO (Either InitError (FilePath, PackageId))
resolveInitRoot target explicitName = do
  path <- maybe getCurrentDirectory pure target
  if null path
    then pure (Left EmptyProjectPath)
    else case projectDirectoryName (normalise path) of
      "" -> pure (Left (UnnamedProjectPath path))
      directoryName -> case selectedIdentity directoryName explicitName of
        Left problem -> pure (Left problem)
        Right packageId -> do
          linked <- isLinked path
          if linked
            then pure (Left (SymbolicLinkNotAllowed path))
            else do
              createDirectoryIfMissing True path
              root <- canonicalizePath path
              pure (Right (root, packageId))

selectedIdentity :: String -> Maybe Text -> Either InitError PackageId
selectedIdentity directoryName explicitName = case explicitName of
  Just name -> case parsePackageId name of
    Left problem -> Left (InvalidPackageIdentity problem)
    Right package -> checkRoot package
  Nothing -> do
    name <- packageNameFrom directoryName
    case parsePackageId name of
      Left _ -> Left (InvalidPackageName directoryName)
      Right package -> checkRoot package
 where
  checkRoot package = case validRoot (defaultRoot package) of
    Left problem -> Left (InvalidPackageIdentity problem)
    Right _ -> Right package

projectDirectoryName :: FilePath -> String
projectDirectoryName = takeFileName . dropTrailingPathSeparator

initialize :: FilePath -> PackageId -> Bool -> IO (Either InitError FilePath)
initialize root packageId library = do
  let lock = root </> ".pudu-init"
  acquired <- try (createDirectory lock) :: IO (Either IOException ())
  case acquired of
    Left problem
      | isAlreadyExistsError problem -> pure (Left (InitializationInProgress lock))
      | otherwise -> ioError problem
    Right () -> bracket
      (pure ())
      (const (removeDirectoryRecursive lock))
      (const (initializeLocked root lock packageId library))

initializeLocked :: FilePath -> FilePath -> PackageId -> Bool -> IO (Either InitError FilePath)
initializeLocked root staging packageId library = do
  let manifest = root </> "pudu.toml"
      sourceDirectory = root </> "src"
      entry = sourceDirectory </> "Main.pudu"
      appDirectory = sourceDirectory </> "App"
      application = appDirectory </> "Greeting.pudu"
      domainDirectory = sourceDirectory </> "Domain"
      domain = domainDirectory </> "Greeting.pudu"
      testDirectory = root </> "test"
      testAppDirectory = testDirectory </> "App"
      suite = testAppDirectory </> "GreetingTest.pudu"
      ignore = root </> ".gitignore"
      readme = root </> "README.md"
      moduleRoot = defaultRoot packageId
      librarySource = sourceDirectory </> Text.unpack moduleRoot <> ".pudu"
      libraryTest = testDirectory </> Text.unpack moduleRoot <> "Test.pudu"
      libraryChecks = [validateRegularFile librarySource, validateRegularFile libraryTest]
      applicationChecks =
        [ validateDirectory appDirectory, validateDirectory domainDirectory
        , validateDirectory testAppDirectory, validateRegularFile entry
        , validateRegularFile application, validateRegularFile domain
        , validateRegularFile suite
        ]
  validation <- firstProblem
    [ validateAbsent manifest
    , validateDirectory sourceDirectory
    , validateDirectory testDirectory
    , validateRegularFile ignore
    , validateRegularFile readme
    ]
    >>= \problem -> case problem of
      Just _ -> pure problem
      Nothing -> firstProblem (if library then libraryChecks else applicationChecks)
  case validation of
    Just problem -> pure (Left problem)
    Nothing -> do
      createDirectoryIfMissing True sourceDirectory
      createDirectoryIfMissing True testDirectory
      if library then pure () else do
        createDirectoryIfMissing True appDirectory
        createDirectoryIfMissing True domainDirectory
        createDirectoryIfMissing True testAppDirectory
      let applicationPlans =
            [ (staging </> "Main.pudu", entry, mainTemplate)
            , (staging </> "App-Greeting.pudu", application, applicationTemplate)
            , (staging </> "Domain-Greeting.pudu", domain, domainTemplate)
            , (staging </> "GreetingTest.pudu", suite, testTemplate)
            ]
          libraryPlans =
            [ (staging </> "Library.pudu", librarySource, libraryTemplate moduleRoot)
            , (staging </> "LibraryTest.pudu", libraryTest, libraryTestTemplate moduleRoot)
            ]
      installed <- installAll
        ( (if library then libraryPlans else applicationPlans) <>
          [ (staging </> "gitignore", ignore, gitignoreTemplate)
          , (staging </> "README.md", readme, if library then libraryReadmeTemplate (projectDirectoryName root) moduleRoot else readmeTemplate (projectDirectoryName root))
          ] )
      case installed of
        Left problem -> pure (Left problem)
        Right () -> do
          committed <- installRequired
            (staging </> "pudu.toml") manifest (manifestTemplate packageId library)
          pure (root <$ committed)

firstProblem :: [IO (Maybe InitError)] -> IO (Maybe InitError)
firstProblem checks = case checks of
  [] -> pure Nothing
  check : remaining -> do
    result <- check
    maybe (firstProblem remaining) (pure . Just) result

validateAbsent :: FilePath -> IO (Maybe InitError)
validateAbsent path = do
  linked <- isLinked path
  present <- doesPathExist path
  pure $ if linked
    then Just (SymbolicLinkNotAllowed path)
    else if present then Just (ManifestAlreadyExists path) else Nothing

validateDirectory :: FilePath -> IO (Maybe InitError)
validateDirectory path = do
  linked <- isLinked path
  present <- doesPathExist path
  directory <- doesDirectoryExist path
  pure $ if linked
    then Just (SymbolicLinkNotAllowed path)
    else if present && not directory then Just (DirectoryRequired path) else Nothing

validateRegularFile :: FilePath -> IO (Maybe InitError)
validateRegularFile path = do
  linked <- isLinked path
  present <- doesPathExist path
  regular <- doesFileExist path
  pure $ if linked
    then Just (SymbolicLinkNotAllowed path)
    else if present && not regular then Just (RegularFileRequired path) else Nothing

installAll :: [(FilePath, FilePath, Text)] -> IO (Either InitError ())
installAll plans = case plans of
  [] -> pure (Right ())
  (staged, destination, contents) : remaining -> do
    present <- doesPathExist destination
    if present
      then installAll remaining
      else do
        installed <- installRequired staged destination contents
        case installed of
          Left problem -> pure (Left problem)
          Right () -> installAll remaining

installRequired :: FilePath -> FilePath -> Text -> IO (Either InitError ())
installRequired staged destination contents = do
  TextIO.writeFile staged contents
  present <- doesPathExist destination
  linked <- isLinked destination
  if present || linked
    then pure (Left (PathChangedDuringInitialization destination))
    else Right <$> renameFile staged destination

isLinked :: FilePath -> IO Bool
isLinked path = do
  result <- try (pathIsSymbolicLink path) :: IO (Either IOException Bool)
  case result of
    Right linked -> pure linked
    Left problem
      | isDoesNotExistError problem -> pure False
      | otherwise -> ioError problem

manifestTemplate :: PackageId -> Bool -> Text
manifestTemplate packageId library = Text.unlines $
  [ "[package]"
  , "name = \"" <> renderPackageId packageId <> "\""
  , "version = \"0.1.0\""
  , "description = \"\""
  , "license = \"\""
  , "keywords = []"
  , "language = \"" <> languageConstraint <> "\""
  , "source = \"src\""
  ]
    <> ["root = \"" <> defaultRoot packageId <> "\"" | library]
    <> ["", "[dependencies]"]

libraryTemplate :: Text -> Text
libraryTemplate root = Text.unlines
  [ "module " <> root
  , ""
  , "export fn greeting(name: Str) -> Str {"
  , "  if name.isEmpty() { \"Hello, world.\" } else { \"Hello, \" + name + \".\" }"
  , "}"
  ]

libraryTestTemplate :: Text -> Text
libraryTestTemplate root = Text.unlines
  [ "module " <> root <> "Test"
  , ""
  , "import Std.Test as Test"
  , "import " <> root <> " as Library"
  , ""
  , "fn main() -> Int {"
  , "  let checks = Test.suite(\"" <> root <> "\", &["
  , "      Test.equals(\"names somebody\", &Library.greeting(\"Ada\"), &\"Hello, Ada.\")"
  , "    ])"
  , "  Test.report(&Test.run(&checks))"
  , "}"
  ]

libraryReadmeTemplate :: String -> Text -> Text
libraryReadmeTemplate name root = Text.unlines
  [ "# " <> Text.pack name
  , ""
  , "A Pudu library that provides `" <> root <> "`. Fill in the package description and license"
  , "in `pudu.toml` before publication. Its `@owner/repo` name must match its GitHub repository."
  , ""
  , "```bash"
  , "pudu check src/" <> root <> ".pudu"
  , "pudu test"
  , "pudu install"
  , "pudu fmt --check ."
  , "pudu lint src test"
  , "pudu release 0.1.0"
  , "```"
  ]

mainTemplate :: Text
mainTemplate = Text.unlines
  [ "module Main"
  , ""
  , "import Std.Io as Io"
  , "import App.Greeting as Greeting"
  , ""
  , "export fn main() -> Int {"
  , "  match Io.writeLine(Greeting.message(\"\")) {"
  , "    case Ok(_) => 0"
  , "    case Err(_) => 1"
  , "  }"
  , "}"
  ]

applicationTemplate :: Text
applicationTemplate = Text.unlines
  [ "module App.Greeting"
  , ""
  , "import Domain.Greeting as Domain"
  , ""
  , "/// The application use case, depending inward on pure domain policy."
  , "export fn message(name: Str) -> Str { Domain.forName(name) }"
  ]

domainTemplate :: Text
domainTemplate = Text.unlines
  [ "module Domain.Greeting"
  , ""
  , "/// A greeting for somebody, or for the world when nobody was named."
  , "export fn forName(name: Str) -> Str {"
  , "  if name.isEmpty() { \"Hello, world.\" } else { \"Hello, \" + name + \".\" }"
  , "}"
  ]

testTemplate :: Text
testTemplate = Text.unlines
  [ "module App.GreetingTest"
  , ""
  , "import Std.Test as Test"
  , "import App.Greeting as Greeting"
  , "import Domain.Greeting as Domain"
  , ""
  , "fn main() -> Int {"
  , "  let checks = Test.suite(\"greeting\", &["
  , "      Test.equals(\"application names somebody\", &Greeting.message(\"Ada\"), &\"Hello, Ada.\"),"
  , "      Test.equals(\"domain greets the world\", &Domain.forName(\"\"), &\"Hello, world.\")"
  , "    ])"
  , "  Test.report(&Test.run(&checks))"
  , "}"
  ]

readmeTemplate :: String -> Text
readmeTemplate name = Text.unlines
  [ "# " <> Text.pack name
  , ""
  , "The source graph points inward: `Main` composes effects, `App` owns use cases, and `Domain`"
  , "owns pure rules. Neither inner layer imports an outer one."
  , ""
  , "```bash"
  , "pudu run src/Main.pudu          # run it"
  , "pudu run --watch src/Main.pudu  # run it again on every save"
  , "pudu test                       # run the suites under test/"
  , "pudu check src/Main.pudu        # compile without running"
  , "pudu lint src test               # find unsafe or needlessly complex code"
  , "pudu fmt --check .              # verify committed formatting"
  , "pudu build src/Main.pudu        # create a portable bundle"
  , "```"
  ]

gitignoreTemplate :: Text
gitignoreTemplate = Text.unlines
  [ ".pudu/"
  , "deps/"
  , "*.o"
  , ""
  , ".DS_Store"
  , "*.swp"
  ]
