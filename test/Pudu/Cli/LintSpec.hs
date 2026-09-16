{-| @Test.Pudu.Cli.LintSpec — production lint command boundaries. -}
module Pudu.Cli.LintSpec (lintCommandProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Cli.Lint (LintCommandResult (..), lintCommand)
import Pudu.Diagnostic.Render (RenderStyle (PlainStyle))
import System.Directory
  ( canonicalizePath
  , createDirectoryIfMissing
  , executable
  , getPermissions
  , setOwnerExecutable
  , setPermissions
  )
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

lintCommandProperties :: [(String, IO Property)]
lintCommandProperties =
  [ ("lint JSON exposes stable typed fixes", testJson)
  , ("lint fix replaces atomically and recompiles clean", testFix)
  , ("lint fix preserves source permissions", testFixPermissions)
  , ("project lint policy suppresses an allowed rule", testProjectAllow)
  , ("source lint directives have exact scope", testSourceAllow)
  , ("malformed lint policy is a visible failure", testMalformedPolicy)
  , ("compiler errors remain in machine lint output", testCompilerError)
  , ("directory lint output follows canonical path order", testDirectoryOrder)
  ]

testJson :: IO Property
testJson = withSource boolSource $ \_ path -> do
  result <- lintCommand PlainStyle ["--json", path]
  pure $ conjoin
    [ lintCommandSuccess result === False
    , property (Text.isInfixOf "\"code\":\"W7101\"" (lintCommandStdout result))
    , property (Text.isInfixOf "\"applicability\":\"safe\"" (lintCommandStdout result))
    , lintCommandStderr result === Text.empty
    ]

testFix :: IO Property
testFix = withSource boolSource $ \_ path -> do
  canonical <- canonicalizePath path
  result <- lintCommand PlainStyle ["--json", "--fix", path]
  contents <- TextIO.readFile path
  second <- lintCommand PlainStyle ["--json", path]
  pure $ conjoin
    [ lintCommandSuccess result === True
    , lintCommandChanged result === [canonical]
    , property (Text.isInfixOf "{ value }" contents)
    , property (not (Text.isInfixOf "== true" contents))
    , lintCommandStdout result === "[]\n"
    , lintCommandSuccess second === True
    ]

testFixPermissions :: IO Property
testFixPermissions = withSource boolSource $ \_ path -> do
  before <- getPermissions path
  setPermissions path (setOwnerExecutable True before)
  result <- lintCommand PlainStyle ["--fix", path]
  after <- getPermissions path
  pure $ conjoin
    [ lintCommandSuccess result === True
    , executable after === True
    ]

testProjectAllow :: IO Property
testProjectAllow = withlish $ \root -> do
  let sourceDirectory = root </> "src"
      path = sourceDirectory </> "Main.pudu"
  createDirectoryIfMissing True sourceDirectory
  TextIO.writeFile (root </> "pudu.toml") (Text.unlines
    [ "[package]"
    , "name = \"lint-project\""
    , "source = \"src\""
    , ""
    , "[lint]"
    , "allow = [\"W7101\"] # lint policy comment"
    ])
  TextIO.writeFile path boolSource
  result <- lintCommand PlainStyle ["--json", path]
  pure $ conjoin
    [ lintCommandSuccess result === True
    , lintCommandStdout result === "[]\n"
    ]

testSourceAllow :: IO Property
testSourceAllow = withlish $ \root -> do
  let nextPath = root </> "Next.pudu"
      filePath = root </> "File.pudu"
  TextIO.writeFile nextPath (Text.unlines
    [ "module Next"
    , "// pudu-lint: allow-next W7101"
    , "fn one(value: Bool) -> Bool { value == true }"
    , "fn two(value: Bool) -> Bool { value == true }"
    ])
  TextIO.writeFile filePath (Text.unlines
    [ "module File"
    , "// pudu-lint: allow-file W7101"
    , "fn one(value: Bool) -> Bool { value == true }"
    , "fn two(value: Bool) -> Bool { value == true }"
    ])
  next <- lintCommand PlainStyle ["--json", nextPath]
  whole <- lintCommand PlainStyle ["--json", filePath]
  pure $ conjoin
    [ count "\"code\":\"W7101\"" (lintCommandStdout next) === 1
    , lintCommandSuccess next === False
    , lintCommandStdout whole === "[]\n"
    , lintCommandSuccess whole === True
    ]

testMalformedPolicy :: IO Property
testMalformedPolicy = withlish $ \root -> do
  let path = root </> "Main.pudu"
  TextIO.writeFile path boolSource
  TextIO.writeFile (root </> "pudu.toml") (Text.unlines
    [ "[lint]"
    , "allow = [\"W7102\"]"
    ])
  result <- lintCommand PlainStyle [path]
  pure $ conjoin
    [ lintCommandSuccess result === False
    , property (Text.isInfixOf "unknown warning code" (lintCommandStderr result))
    ]

testCompilerError :: IO Property
testCompilerError = withSource (Text.unlines
  [ "module Main"
  , "fn main() -> Int { missing }"
  ]) $ \_ path -> do
    result <- lintCommand PlainStyle ["--json", path]
    pure $ conjoin
      [ lintCommandSuccess result === False
      , property (Text.isInfixOf "\"code\":\"E2010\"" (lintCommandStdout result))
      , property (Text.isInfixOf "\"rule\":\"compiler\"" (lintCommandStdout result))
      ]

testDirectoryOrder :: IO Property
testDirectoryOrder = withlish $ \root -> do
  let first = root </> "A.pudu"
      second = root </> "B.pudu"
      source name = Text.unlines
        [ "module " <> name
        , "fn check(value: Bool) -> Bool { value == true }"
        ]
  TextIO.writeFile second (source "B")
  TextIO.writeFile first (source "A")
  result <- lintCommand PlainStyle ["--json", root]
  let output = lintCommandStdout result
      firstAt = Text.breakOn "A.pudu" output
      secondAt = Text.breakOn "B.pudu" output
  pure $ counterexample (Text.unpack output) $ conjoin
    [ property (not (Text.null (snd firstAt)))
    , property (not (Text.null (snd secondAt)))
    , property (Text.length (fst firstAt) < Text.length (fst secondAt))
    ]

withSource :: Text -> (FilePath -> FilePath -> IO Property) -> IO Property
withSource contents action = withlish $ \root -> do
  let path = root </> "Main.pudu"
  TextIO.writeFile path contents
  action root path

withlish :: (FilePath -> IO Property) -> IO Property
withlish = withSystemTempDirectory "pudu-lint"

boolSource :: Text
boolSource = Text.unlines
  [ "module Main"
  , "fn check(value: Bool) -> Bool { value == true }"
  ]

count :: Text -> Text -> Int
count needle = length . Text.breakOnAll needle
