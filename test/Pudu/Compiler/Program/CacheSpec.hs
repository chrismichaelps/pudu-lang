{-| @Test.Compiler.Program.CacheSpec — compiled products reused across runs -}
module Pudu.Compiler.Program.CacheSpec
  ( testCacheCorruption
  , testCacheEquivalence
  , testCacheInvalidation
  , testFoldedConstants
  , testImportedConstants
  , testProductPublication
  ) where

import Control.Monad (forM_)
import qualified Data.ByteString as ByteString
import Data.Text (Text)
import qualified Data.Text.IO as TextIO
import Data.Maybe (isJust, isNothing)
import Pudu.Compiler (CompileResult (..), FrontendResult (..))
import Pudu.Compiler.Cache (disabledCache, openProductCacheAt)
import Pudu.Compiler.Product (ProductUse (..), frontendFor)
import Pudu.Compiler.Program
  ( ProgramResult (..)
  , compileProgram
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
import Pudu.Source (SourceName (..), newSource)
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
    fresh <- observed =<< compileProgram path
    cache <- openProductCacheAt root
    cold <- observed =<< compileProgramCached cache path
    rereading <- openProductCacheAt root
    warm <- observed =<< compileProgramCached rereading path
    pure $ conjoin
      [ counterexample (path <> ": the storing run matches compiling from source") (cold === fresh)
      , counterexample (path <> ": the reading run matches compiling from source") (warm === fresh)
      ]

testProductPublication :: IO Property
testProductPublication = withSystemTempDirectory "pudu-products" $ \root -> do
  let entry = root </> "Main.pudu"
      cacheRoot = root </> "cache"
  TextIO.writeFile entry
    "module Main\n/// A narrow constant retains its checked width.\nconst SMALL: Int8 = 7\nexport fn main() -> Int8 { SMALL }\n"
  analysis <- compileProgram entry
  uncached <- compileProgramCached disabledCache entry
  cold <- openProductCacheAt cacheRoot >>= (`compileProgramCached` entry)
  warm <- openProductCacheAt cacheRoot >>= (`compileProgramCached` entry)
  answers <- traverse observed [analysis, uncached, cold, warm]
  TextIO.writeFile entry "module Main\nfn main() -> Int8 { true }\n"
  rejected <- traverse (\compile -> compile entry >>= observed)
    [compileProgram, compileProgramCached disabledCache]
  frontendProducts <- traverse (compareFrontends cacheRoot)
    [ "module Main\n/// Keep the comment for analysis.\nfn main() -> Int { 7 }\n"
    , "module Main\nfn main() -> Int { § }\n"
    , "module Main\nfn main() -> Int { 7\n"
    ]
  pure $ conjoin
    [ conjoin frontendProducts
    , counterexample "full analysis retains every editor product"
        (all analysisPublished (Map.elems (programModules analysis)))
    , counterexample "execution drops analysis products even when the cache is cold"
        (all executionPublished (concatMap (Map.elems . programModules) [uncached, cold, warm]))
    , counterexample "publication retains checked execution and link order"
        (answers === replicate 4 ([], ["Main"], Just "7"))
    , counterexample "literal width survives every publication mode"
        (map (Map.elems . programIntegerKinds) [analysis, uncached, cold, warm]
          === replicate 4 ["Int8"])
    , counterexample "rejected source retains diagnostics without an executable product"
        (rejected === replicate 2 ([ ("E3001", "expected Int8, found Bool") ], ["Main"], Nothing))
    ]
 where
  compareFrontends cacheRoot text = do
    source <- newSource (SourceName "Frontend.pudu") text
    cache <- openProductCacheAt cacheRoot
    analysis <- frontendFor AnalysisProducts disabledCache source
    uncached <- frontendFor ExecutionProducts disabledCache source
    cold <- frontendFor ExecutionProducts cache source
    warm <- frontendFor ExecutionProducts cache source
    retained <- frontendFor AnalysisProducts cache source
    pure $ conjoin
      [ counterexample "execution releases tokens before discovery, preserving recovery"
          ([uncached, cold, warm] === replicate 3 analysis{frontendTokens = []})
      , counterexample "analysis against a populated cache retains lossless tokens"
          (retained === analysis)
      , counterexample "analysis includes at least its canonical EOF token"
          (not (null (frontendTokens retained)))
      ]
  analysisPublished compiled =
    not (null (compileTokens compiled)) && isJust (compileResolution compiled)
      && isJust (compileTypes compiled) && isJust (compileDocs compiled)
  executionPublished compiled =
    null (compileTokens compiled) && isNothing (compileResolution compiled)
      && isNothing (compileTypes compiled) && isNothing (compileDocs compiled)
      && null (compileMethods compiled) && compileSyntax compiled == compileModule compiled

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

{-| Imported constructors and pure calls fold in their declaration scopes across
    all import forms, including transitive constants and reused checked products. -}
testImportedConstants :: IO Property
testImportedConstants = withSystemTempDirectory "pudu-imported-constants" $ \root -> do
  let project = root </> "project"
      entry = project </> "Main.pudu"
      cacheRoot = root </> "cache"
  createDirectoryIfMissing True (project </> "Lib")
  TextIO.writeFile (project </> "Lib" </> "Colors.pudu")
    "module Lib.Colors\nexport type Color = Red | Green\nexport const BASE: Int = 20\nexport fn show() -> Int { 7 }\n"
  TextIO.writeFile (project </> "Lib" </> "Palette.pudu")
    "module Lib.Palette\nimport Lib.Colors as C\nexport const SIZE: Int = C.BASE + 1\nexport fn answer() -> Int { SIZE * 2 }\n"
  TextIO.writeFile entry
    "module Main\nimport Lib.Colors as C\nimport Lib.Colors\nimport Lib.Colors {BASE, show}\nimport Lib.Palette as P\nconst ALL: Array[C.Color] = [C.Red, C.Green]\nconst OTHERS: Array[Colors.Color] = [Colors.Green, Colors.Red]\nconst TOTAL: Int = P.answer() + BASE + show()\nfn main() -> Int { ALL.length() + OTHERS.length() + TOTAL }\n"
  freshProgram <- compileProgramCached disabledCache entry
  fresh <- observed freshProgram
  coldProgram <- openProductCacheAt cacheRoot >>= (`compileProgramCached` entry)
  cold <- observed coldProgram
  warmProgram <- openProductCacheAt cacheRoot >>= (`compileProgramCached` entry)
  warm <- observed warmProgram
  TextIO.writeFile (project </> "Lib" </> "Effects.pudu")
    "module Lib.Effects\nexport fn read() -> Result[Str, Str] { readFile(\"must-not-be-read\") }\n"
  TextIO.writeFile entry
    "module Main\nimport Lib.Effects as E\nconst BAD: Result[Str, Str] = E.read()\nfn main() -> Int { 0 }\n"
  refused <- compileProgramCached disabledCache entry
  let folded = Map.findWithDefault Map.empty "Main" (programFolded freshProgram)
      codes = map (diagnosticCodeText . diagnosticCode) . programDiagnostics
  pure $ conjoin
    [ counterexample "aliases, default qualifiers, selected imports and transitive calls fold"
        (fresh === ([], ["Lib.Colors", "Lib.Palette", "Main"], Just "73"))
    , counterexample "imported constructor arrays and pure calls produce frozen values"
        (filter (`Map.notMember` folded) ["ALL", "OTHERS", "TOTAL"] === [])
    , counterexample "a cold cache agrees with a fresh compile" (cold === fresh)
    , counterexample "a warm cache retains imported frozen values" (warm === fresh)
    , counterexample "an imported call cannot perform IO during folding"
        (codes refused === ["E7009"])
    , counterexample "an effectful initializer never produces an executable module"
        (case rootCompileResult refused >>= compileModule of Nothing -> True; Just _ -> False)
    ]
