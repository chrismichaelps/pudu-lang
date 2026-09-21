{-| @Test.Compiler.Program.CacheSpec — compiled products reused across runs -}
module Pudu.Compiler.Program.CacheSpec
  ( testCacheCorruption
  , testCacheEquivalence
  , testCacheInvalidation
  , testFoldedConstants
  ) where

import Control.Monad (forM_)
import qualified Data.ByteString as ByteString
import Data.Text (Text)
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Cache (disabledCache, openProductCacheAt)
import Pudu.Compiler.Program
  ( ProgramResult (..)
  , compileProgramCached
  , programDependencies
  , programFolded
  , programIntegerKinds
  , rootCompileResult
  )
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText, diagnosticMessage)
import Pudu.Eval (EvalOutcome (..))
import qualified Data.Map.Strict as Map
import Pudu.Eval.Program
  ( evaluateProgramEntry
  , evaluateProgramEntryFolded
  , evaluateProgramTallied
  , evaluateProgramTalliedFolded
  )
import Pudu.Eval.Render (renderValue)
import Pudu.Frontend.Syntax.Name (moduleNameText)
import System.Directory (createDirectoryIfMissing, getModificationTime, listDirectory, setModificationTime)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

{-| What a compile answers with that a user can observe: what it reported,
    the order it would link in, and what running `main` gives. -}
observed :: ProgramResult -> IO ([(Text, Text)], [Text], Maybe Text)
observed program = do
  ran <- case rootCompileResult program >>= compileModule of
    Nothing -> pure Nothing
    Just parsed -> do
      outcome <-
        evaluateProgramEntryFolded (programFolded program)
          (programIntegerKinds program) (programDependencies program) "main" parsed
      pure (renderValue <$> outcomeValue outcome)
  pure (map described (programDiagnostics program), map moduleNameText (programOrder program), ran)
 where
  described :: Diagnostic -> (Text, Text)
  described value = (diagnosticCodeText (diagnosticCode value), diagnosticMessage value)

{-| A stored product gives exactly what compiling from source gives: the same
    diagnostics, the same link order, the same result — on the first run that
    stores, and on the run after it that only reads. -}
testCacheEquivalence :: IO Property
testCacheEquivalence = withSystemTempDirectory "pudu-cache" $ \root -> do
  results <- mapM (compareRuns root) programs
  pure (conjoin results)
 where
  programs =
    [ "test-fixtures/interfacegraph/Cycle.pudu"
    , "test-fixtures/interfacegraph/Main.pudu"
    , "test-fixtures/program29/B.pudu"
    , "test-fixtures/program29/AmbiguousRoot.pudu"
    , "test-fixtures/aliasfield/Main.pudu"
    , "test-fixtures/stdlib/UsesAll.pudu"
    , "test-fixtures/folded/Main.pudu"
    , "test-fixtures/comptimehigher/Main.pudu"
    ]
  compareRuns root path = do
    fresh <- observed =<< compileProgramCached disabledCache path
    cache <- openProductCacheAt root
    cold <- observed =<< compileProgramCached cache path
    rereading <- openProductCacheAt root
    warm <- observed =<< compileProgramCached rereading path
    pure $ conjoin
      [ counterexample (path <> ": the storing run matches compiling from source") (cold === fresh)
      , counterexample (path <> ": the reading run matches compiling from source") (warm === fresh)
      ]

{-| A stored product is only ever the product of exactly this input.

    The library's text changes but keeps its length and its timestamp, so
    nothing but its content can say it changed. Its function's body changes
    first, which leaves its interface alone; then its signature, which changes
    what the module importing it must be checked against. -}
testCacheInvalidation :: IO Property
testCacheInvalidation = withSystemTempDirectory "pudu-cache-edit" $ \root -> do
  let project = root </> "project"
      cacheRoot = root </> "cache"
      library = project </> "Lib.pudu"
      entry = project </> "Main.pudu"
  createDirectoryIfMissing True project
  writeProject project "export fn answer() -> Int { 41 }"
  first <- observed =<< (openProductCacheAt cacheRoot >>= (`compileProgramCached` entry))
  stamp <- getModificationTime library
  TextIO.writeFile library (libraryText "export fn answer() -> Int { 42 }")
  setModificationTime library stamp
  second <- observed =<< (openProductCacheAt cacheRoot >>= (`compileProgramCached` entry))
  TextIO.writeFile library (libraryText "export fn answer() -> Str { \"x\" }")
  third <- observed =<< (openProductCacheAt cacheRoot >>= (`compileProgramCached` entry))
  fresh <- observed =<< compileProgramCached disabledCache entry
  let codes (reported, _, _) = map fst reported
      value (_, _, ran) = ran
  pure $ conjoin
    [ counterexample "the first run runs" (value first === Just "41")
    , counterexample "a changed body is seen though the timestamp did not move" (value second === Just "42")
    , counterexample "a changed signature re-checks the module importing it"
        (codes third === ["E3001"])
    , counterexample "and reports what compiling from source reports" (third === fresh)
    ]
 where
  writeProject project body = do
    TextIO.writeFile (project </> "Lib.pudu") (libraryText body)
    TextIO.writeFile (project </> "Main.pudu")
      "module Main\n\nimport Lib\n\nfn main() -> Int { Lib.answer() }\n"
  libraryText :: Text -> Text
  libraryText body = "module Lib\n\n" <> body <> "\n"

{-| An entry cut short or damaged on disk is a miss, never a wrong answer: the
    compile falls back to the source and stores a good entry in its place. -}
testCacheCorruption :: IO Property
testCacheCorruption = withSystemTempDirectory "pudu-cache-damage" $ \root -> do
  let path = "test-fixtures/interfacegraph/Cycle.pudu"
  fresh <- observed =<< compileProgramCached disabledCache path
  _ <- observed =<< (openProductCacheAt root >>= (`compileProgramCached` path))
  directories <- listDirectory root
  forM_ directories $ \directory -> do
    entries <- listDirectory (root </> directory)
    forM_ (zip [0 :: Int ..] entries) $ \(index, name) -> do
      let file = root </> directory </> name
      bytes <- ByteString.readFile file
      ByteString.writeFile file $
        if even index
          then ByteString.take (ByteString.length bytes `div` 2) bytes
          else ByteString.map (+ 1) bytes
  damaged <- observed =<< (openProductCacheAt root >>= (`compileProgramCached` path))
  repaired <- observed =<< (openProductCacheAt root >>= (`compileProgramCached` path))
  pure $ conjoin
    [ counterexample "damaged entries fall back to compiling from source" (damaged === fresh)
    , counterexample "and are replaced by entries that read" (repaired === fresh)
    , property True
    ]

{-| A constant folding computed is bound from the fold when the program links,
    not evaluated again, and only when it is plain data.

    `TOTAL` sums two hundred numbers in a compile-time loop, so evaluating it a
    second time is work a tally can see. `STEP` is a function, which carries
    the environment it was made in and is always evaluated where it links. -}
testFoldedConstants :: IO Property
testFoldedConstants = do
  let path = "test-fixtures/folded/Main.pudu"
  program <- compileProgramCached disabledCache path
  let folded = Map.findWithDefault Map.empty "Main" (programFolded program)
      plain =
        [ "TOTAL", "SMALL", "WIDE", "RATIO", "PRICE", "NAME", "LETTER", "ORIGIN", "SHAPE"
        , "PAIR", "DAYS", "LIMITS"
        ]
  case rootCompileResult program >>= compileModule of
    Nothing -> pure (counterexample "the fixture compiles" False)
    Just parsed -> do
      let kinds = programIntegerKinds program
          dependencies = programDependencies program
      reused <- evaluateProgramEntryFolded (programFolded program) kinds dependencies "main" parsed
      evaluated <- evaluateProgramEntry kinds dependencies "main" parsed
      (_, reusedWork) <- evaluateProgramTalliedFolded (programFolded program) kinds dependencies "main" parsed
      (_, evaluatedWork) <- evaluateProgramTallied kinds dependencies "main" parsed
      let answer = fmap renderValue . outcomeValue
      pure $ conjoin
        [ counterexample "every plain-data constant is folded" (filter (`Map.notMember` folded) plain === [])
        , counterexample "a function constant is not" (Map.member "STEP" folded === False)
        , counterexample "the program runs from folded constants" (answer reused === Just "13")
        , counterexample "and agrees with evaluating them again" (answer reused === answer evaluated)
        , counterexample ("linking does less work: " <> show (sum reusedWork, sum evaluatedWork))
            (sum reusedWork < sum evaluatedWork)
        ]
