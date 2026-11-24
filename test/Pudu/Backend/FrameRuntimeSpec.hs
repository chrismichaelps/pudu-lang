{-| @Test.Backend.FrameRuntimeSpec — production frame allocation and panic cleanup. -}
module Pudu.Backend.FrameRuntimeSpec (frameRuntimeProperties) where

import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Emit (emitProgram)
import Pudu.Backend.Runtime (RuntimePart (..), runtimeParts)
import Pudu.Backend.Runtime.Array (arrayRuntimeParts)
import Pudu.Backend.Runtime.Dependencies (runtimeDependencies)
import Pudu.Backend.Runtime.Frame (frameTypes)
import Pudu.Backend.Runtime.Kernel (kernelRuntimeParts)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), lowerModule)
import Pudu.Compiler.Lower.Types (nativeTypes)
import Pudu.Diagnostic (hasErrors)
import Pudu.Source (SourceName (..), newSource)
import System.Directory (findExecutable)
import System.Environment (getEnvironment, getExecutablePath, lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (CreateProcess (env), proc, readCreateProcessWithExitCode, readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

frameRuntimeProperties :: [(String, IO Property)]
frameRuntimeProperties =
  [ ("frame allocator frees normal returns and failed allocations", testAllocations)
  , ("sequential heap calls reuse released frame storage", testFrameReuse)
  , ("computed array appends reuse a unique receiver", testArrayReuse)
  , ("small arrays use one allocation per box", testInlineArrays)
  , ("local array indexing does not retain the receiver", testIndexedReads)
  , ("JSON unwinds partial values on refusal and allocation failure", testJsonCleanup)
  , ("typed calls preserve floating results and rounding", testFloatingCalls)
  , ("fresh scalar constructor matches do not allocate boxes", testScalarMatches)
  , ("exclusive ordered trees reuse nodes and preserve shared snapshots", testTreeReuse)
  , ("short-lived host objects reuse inline registry storage", testHostRegistry)
  , ("short text and adjacent views reuse stable storage", testShortText)
  , ("small non-suspending entry needs no heap frame", testStartupFrame)
  , ("typed narrow integers preserve overflow, wrap and saturation", testNarrowCalls)
  , ("distinct variants dispatch by tag without changing guard fallback", testVariantSwitch)
  , ("dynamic diagnostics release surviving payload copies", testDiagnosticCopies)
  , ("dynamic diagnostic payload bounds and empty views preserve cleanup", testDiagnosticBounds)
  , ("aggregate joining rejects overflowing separator and label lengths", testJoinOverflow)
  , ("frame allocator unwinds source panics and rejects size overflow", testPanics)
  ]

testFrameReuse :: IO Property
testFrameReuse = withCompiler $ \cc root -> do
  result <- execute cc root source 3 requireLocalBranch
  pure $ result === Right (ExitFailure 7, "", "")
  where
    source = Text.unlines
      [ "module Main", "fn work(n: Int) -> Int {"
      , "  if n == 0 { return 7 }", "  work(n - 1)", "}"
      , "fn main() -> Int {", "  var i = 0", "  var answer = 0"
      , "  while i < 100 {", "    answer = work(0)", "    i = i + 1", "  }"
      , "  answer", "}" ]
    requireLocalBranch emitted
      | " else goto pudu_block_" `Text.isInfixOf` emitted = emitted
      | otherwise = "#error missing local frame branches\n" <> emitted

testArrayReuse :: IO Property
testArrayReuse = withCompiler $ \cc root -> do
  result <- execute cc root source 0 limitBoxes
  pure $ result === Right (ExitSuccess, "", "")
  where
    source = Text.unlines
      [ "module Main", "fn main() -> Int {"
      , "  var items: Array[Int] = []", "  var i = 0"
      , "  while i < 2000 {", "    items = items.push(i % 13)", "    i = i + 1", "  }"
      , "  if items.length() != 2000 { return 8 }"
      , "  items[1999] - 10", "}" ]
    limitBoxes = Text.replace
      "    box = malloc(sizeof(pudu_box) + members * sizeof(pudu_cell));"
      (Text.unlines
        [ "    static size_t test_boxes = 0;"
        , "    if (++test_boxes > 16) pudu_memory_failure();"
        , "    box = malloc(sizeof(pudu_box) + members * sizeof(pudu_cell));" ])

testInlineArrays :: IO Property
testInlineArrays = withCompiler $ \cc root -> do
  result <- execute cc root source 0 limitAllocations
  pure $ result === Right (ExitSuccess, "", "")
  where
    source = Text.unlines
      [ "module Main", "fn main() -> Int {"
      , "  let empty: Array[Int] = []", "  let one = [7]", "  let three = [1, 2, 3]"
      , "  empty.length() + one[0] + three[2] - 10", "}" ]
    limitAllocations = Text.replace
      "static inline pudu_box *pudu_array_allocate(size_t capacity, int report) {"
      "static inline pudu_box *pudu_array_allocate(size_t capacity, int report) {\n  test_malloc_limit = 3;"

testIndexedReads :: IO Property
testIndexedReads = withCompiler $ \cc root -> do
  result <- execute cc root source 0 limitRetains
  pure $ result === Right (ExitSuccess, "", "")
  where
    source = Text.unlines
      [ "module Main", "fn main() -> Int {"
      , "  let items = [1, 2, 3]", "  let position = 2", "  var i = 0", "  var total = 0"
      , "  while i < 2000 {", "    total = total + items[position] + items[0]", "    i = i + 1", "  }"
      , "  total - 8000", "}" ]
    limitRetains = Text.replace
      "static inline pudu_box *pudu_box_retain(pudu_box *box) {"
      (Text.unlines
        [ "static inline pudu_box *pudu_box_retain(pudu_box *box) {"
        , "  static size_t test_retains = 0;"
        , "  if (box != NULL && ++test_retains > 16) _Exit(96);" ])

testJsonCleanup :: IO Property
testJsonCleanup = withCompiler $ \cc root -> do
  let path = root </> "json.c"
      binary = root </> "json"
  TextIO.writeFile path (Text.unlines source)
  (built, out, err) <- readProcessWithExitCode cc
    ["-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror", path, "-o", binary] ""
  if built /= ExitSuccess || not (null out && null err)
    then pure (counterexample (show built <> out <> err) (False === True))
    else do
      refused <- readProcessWithExitCode binary ["0", "trailing"] ""
      partial <- readProcessWithExitCode binary ["0", "trailing", "partial"] ""
      valid <- readProcessWithExitCode binary ["0"] ""
      failures <- traverse (\attempt -> readProcessWithExitCode binary [show attempt] "") [1 .. 18 :: Int]
      pure $ conjoin $
        [refused === (ExitSuccess, "", ""), partial === (ExitSuccess, "", ""), valid === (ExitSuccess, "", "")]
        <> [counterexample ("allocation " <> show attempt) $
             result === (ExitFailure 1, "", "pudu: memory allocation failed\n")
           | (attempt, result) <- zip [1 :: Int ..] failures]
  where
    selected = foldl' add Set.empty ["prelude", "cleanup", "error_io", "json_decode"]
    add seen name
      | Set.member name seen = seen
      | otherwise = foldl' add (Set.insert name seen) (runtimeDependencies name)
    source = instrument 0
      <> [ "#undef main"
         , "static void *test_realloc(void *prior, size_t bytes) {"
         , "  if (++test_malloc_calls == test_malloc_failure) return NULL;"
         , "  return realloc(prior, bytes);"
         , "}", "#define realloc test_realloc" ]
      <> concat [runtimePartLines part | part <- runtimeParts, Set.member (runtimePartName part) selected]
      <> frameTypes False False False True True False
      <> concat [lines' | (name, lines') <- arrayRuntimeParts <> kernelRuntimeParts, Set.member name selected]
      <> [ "int main(int argc, char **argv) {"
         , "  static const unsigned char valid[] = \"{\\\"key\\\":[\\\"hello\\\",1,2,3,4,5,6,7,8]}\";"
         , "  static const unsigned char bad[] = \"{\\\"key\\\":[\\\"hello\\\",1,2]}x\";"
         , "  static const unsigned char partial[] = \"{\\\"key\\\":[\\\"hello\\\",1,2,]}\";"
         , "  pudu_text source = argc > 2 ? (pudu_text){bad, sizeof bad - 1, NULL} : (pudu_text){valid, sizeof valid - 1, NULL};"
         , "  if (argc > 3) source = (pudu_text){partial, sizeof partial - 1, NULL};"
         , "  pudu_json layout = {source.bytes, source.length, 0, 1, 2, 3, 4, 5, 6, 0};"
         , "  (void)test_calloc; (void)pudu_active_frame; (void)pudu_frame_depth; (void)pudu_box_retain;"
         , "  if (atexit(test_check) != 0) abort();"
         , "  test_malloc_failure = strtoul(argv[1], NULL, 10);"
         , "  pudu_box *found = pudu_json_decode(source, 0, 1, 2, 3, 4, 5, 6);"
         , "  if (found == NULL) return argc > 2 ? 0 : 85;"
         , "  pudu_json_discard(&layout, found);"
         , "  return argc > 2 || test_malloc_calls != 18 ? 86 : 0;"
         , "}" ]

testFloatingCalls :: IO Property
testFloatingCalls = withCompiler $ \cc root -> do
  result <- execute cc root source 0 requireTyped
  pure $ result === Right (ExitSuccess, "", "")
  where
    source = Text.unlines
      [ "module Main"
      , "fn sum(left: Float64, right: Float64) -> Float64 { left + right }"
      , "fn reciprocal(value: Float64) -> Float64 { 1.0 / value }"
      , "fn narrow(value: Float32) -> Float32 { value + 1.0f32 }"
      , "fn through(value: Float64) -> Float64 { sum(value, 0.5) }"
      , "fn main() -> Int {"
      , "  if through(4.0) != 4.5 { return 81 }"
      , "  if narrow(16777216.0f32) != 16777216.0f32 { return 82 }"
      , "  if reciprocal(-0.0) > 0.0 { return 83 }"
      , "  0", "}" ]
    requireTyped emitted
      | Text.count "static uint64_t pudu_fast_" emitted >= 8 = emitted
      | otherwise = "#error missing typed floating calls\n" <> emitted

testScalarMatches :: IO Property
testScalarMatches = withCompiler $ \cc root -> do
  direct <- execute cc root directSource 0 forbidBoxes
  guarded <- execute cc root guardedSource 0 id
  pure $ conjoin [direct === Right (ExitSuccess, "", ""), guarded === Right (ExitSuccess, "", "")]
  where
    intro = ["module Main", "type Mark = Off | On(Int, Int)"]
    directSource = Text.unlines $ intro <>
      [ "fn main() -> Int {", "  var index = 0", "  var total = 0"
      , "  while index < 2000 {"
      , "    let answer = match On(index % 13, 2) {"
      , "      case Off => 0", "      case On(value, _) => value", "    }"
      , "    total = total + answer", "    index = index + 1", "  }"
      , "  total - 11989", "}" ]
    guardedSource = Text.unlines $ intro <>
      [ "fn main() -> Int {", "  match On(3, 4) {"
      , "    case On(first, _) if first < 0 => 81"
      , "    case On(first, second) => second - first - 1"
      , "    case Off => 82", "  }", "}" ]
    forbidBoxes = Text.replace "int main(void) {" "int main(void) { test_malloc_failure = 1;"

testTreeReuse :: IO Property
testTreeReuse = withCompiler $ \cc root -> do
  built <- execute cc root bulk 0 capNodes
  updated <- execute cc root shared 0 id
  pure $ conjoin [built === Right (ExitSuccess, "", ""), updated === Right (ExitSuccess, "", "")]
  where
    keys = Text.intercalate ", " [Text.pack (show i) | i <- [1 .. 64 :: Int]]
    bulk = Text.unlines
      [ "module Main", "fn main() -> Int {"
      , "  let keys = setOf([" <> keys <> "])", "  if keys.contains(64) { return keys.size() - 64 }"
      , "  87", "}" ]
    shared = Text.unlines
      [ "module Main", "fn main() -> Int {"
      , "  let original = mapOf([(3, 30), (1, 10), (2, 20), (5, 50), (4, 40)])"
      , "  let changed = original.insert(2, 21).insert(6, 60).remove(3).remove(5)"
      , "  if changed.keys() != [1, 2, 4, 6] { return 88 }"
      , "  if changed.get(2) != Some(21) { return 89 }"
      , "  if original.keys() != [1, 2, 3, 4, 5] { return 90 }"
      , "  if original.get(2) != Some(20) { return 91 }"
      , "  0", "}" ]
    capNodes = Text.replace "  if (node == NULL) node = malloc(sizeof *node);"
      (Text.unlines
        [ "  static size_t test_tree_nodes = 0;"
        , "  if (node == NULL && ++test_tree_nodes > 64) _Exit(96);"
        , "  if (node == NULL) node = malloc(sizeof *node);" ])

testHostRegistry :: IO Property
testHostRegistry = withCompiler $ \cc root -> do
  result <- execute cc root source 0 forbidRegistryGrowth
  pure $ result === Right (ExitSuccess, "", "")
  where
    source = Text.unlines
      [ "module Main", "fn main() -> Int {", "  var previous = 0", "  var i = 0"
      , "  while i < 40 {"
      , "    let token = cellOpen(i)", "    if token != previous + 1 { return 92 }"
      , "    let stale: Result[Int, Str] = cellGet(previous)"
      , "    if let Ok(_) = stale { return 93 }"
      , "    let current: Result[Int, Str] = cellGet(token)"
      , "    if current != Ok(i) { return 94 }"
      , "    if let Err(_) = cellDispose(token) { return 95 }"
      , "    previous = token", "    i = i + 1", "  }", "  0", "}" ]
    forbidRegistryGrowth = Text.replace
      "  void *grown = held == NULL ? malloc(bytes) : realloc(held, bytes);"
      "  _Exit(96);\n  void *grown = held == NULL ? malloc(bytes) : realloc(held, bytes);"

testShortText :: IO Property
testShortText = withCompiler $ \cc root -> do
  digits <- execute cc root source 0 (failAllocation "1")
  views <- execute cc root joined 0 (failAllocation "3")
  pure $ conjoin [digits === Right (ExitSuccess, "", ""), views === Right (ExitSuccess, "", "")]
  where
    source = Text.unlines
      [ "module Main", "fn main() -> Int {", "  var i = 0"
      , "  while i < 100 {"
      , "    let digit = display(i % 10)", "    if digit.length() != 1 { return 81 }"
      , "    if i % 10 == 0 && digit != \"0\" { return 82 }"
      , "    if i % 10 == 9 && digit != \"9\" { return 83 }"
      , "    if i >= 10 && display(i) != display(i / 10) + digit { return 84 }"
      , "    i = i + 1", "  }", "  0", "}" ]
    joined = Text.unlines
      [ "module Main", "fn assemble(seed: Int) -> Str {"
      , "  let text = display(seed) + \"é\\0\""
      , "  text.take(2) + text.drop(2)", "}"
      , "fn main() -> Int {", "  let restored = assemble(314)"
      , "  if restored != \"314é\\0\" { return 85 }", "  0", "}" ]
    failAllocation attempt = Text.replace "int main(void) {"
      ("int main(void) { test_malloc_failure = " <> attempt <> ";")

testStartupFrame :: IO Property
testStartupFrame = withCompiler $ \cc root -> do
  result <- execute cc root "module Main\nfn main() -> Int { 7 }\n" 1 id
  pure $ result === Right (ExitFailure 7, "", "")

testNarrowCalls :: IO Property
testNarrowCalls = withCompiler $ \cc root -> do
  valid <- execute cc root validSource 0 (require "pudu_fast_narrow_wrap(")
  addOverflow <- execute cc root addSource 0 (require "pudu_fast_bounded(")
  divOverflow <- execute cc root divSource 0 (require "pudu_fast_bounded(")
  pure $ conjoin [valid === Right (ExitSuccess, "", ""), overflow addOverflow, overflow divOverflow]
  where
    validSource = Text.unlines
      [ "module Main"
      , "fn wrap(a: Int8, b: Int8) -> Int8 { a &+ b }"
      , "fn saturate(a: Int16, b: Int16) -> Int16 { a *| b }"
      , "fn remain(a: Int32, b: Int32) -> Int32 { a % b }"
      , "fn left(a: Int8, count: Int) -> Int8 { a << count }"
      , "fn right(a: Int8, count: Int) -> Int8 { a >> count }"
      , "fn main() -> Int {"
      , "  if wrap(127i8, 1i8) != -128i8 { return 81 }"
      , "  if saturate(-32768i16, -1i16) != 32767i16 { return 82 }"
      , "  if remain(-2147483648i32, -1i32) != 0i32 { return 83 }"
      , "  if left(64i8, 1) != -128i8 { return 84 }"
      , "  if right(-128i8, 7) != -1i8 { return 85 }"
      , "  0", "}" ]
    addSource = "module Main\nfn add(a: Int8, b: Int8) -> Int8 { a + b }\nfn main() -> Int8 { add(127i8, 1i8) }\n"
    divSource = "module Main\nfn cut(a: Int32, b: Int32) -> Int32 { a / b }\nfn main() -> Int32 { cut(-2147483648i32, -1i32) }\n"
    require helper emitted
      | helper `Text.isInfixOf` emitted = emitted
      | otherwise = "#error missing typed narrow integer operations\n" <> emitted
    overflow result = case result of
      Right (ExitFailure 1, "", diagnostic) -> counterexample (Text.unpack diagnostic) ("E7005" `Text.isInfixOf` diagnostic === True)
      _ -> counterexample (show result) (False === True)

testVariantSwitch :: IO Property
testVariantSwitch = withCompiler $ \cc root -> do
  result <- execute cc root source 0 requireSwitch
  pure $ result === Right (ExitSuccess, "", "")
  where
    source = Text.unlines
      [ "module Main", "type Mark = Positive(Int) | Exact(Int) | Empty"
      , "fn select(value: Mark) -> Int {", "  match value {"
      , "    case Positive(n) if n > 0 => n"
      , "    case Exact(1) => 10", "    case Empty => 20", "    case _ => 30", "  }", "}"
      , "fn main() -> Int {"
      , "  if select(Positive(0)) != 30 { return 81 }"
      , "  if select(Exact(2)) != 30 { return 82 }"
      , "  if select(Exact(1)) != 10 { return 83 }"
      , "  select(Positive(5)) + select(Empty) - 25", "}" ]
    requireSwitch emitted
      | any (\line -> "switch (" `Text.isInfixOf` line && "->fields[0].scalar)" `Text.isInfixOf` line) (Text.lines emitted) = emitted
      | otherwise = "#error missing numeric variant switch\n" <> emitted

testAllocations :: IO Property
testAllocations = withCompiler $ \cc root -> conjoin <$> traverse (check cc root)
  [ (0, "3\n2\n1\n0\n", ExitFailure 7)
  , (1, "", ExitFailure 1), (2, "", ExitFailure 1)
  , (3, "3\n", ExitFailure 1), (5, "3\n2\n1\n", ExitFailure 1)
  ]
  where
    source = Text.unlines
      [ "module Main", "fn recurse(n: Int) -> Int {", "  print(display(n))"
      , "  if n == 0 { return 7 }", "  return recurse(n - 1)", "}"
      , "fn main() -> Int { recurse(3) }" ]
    check cc root (attempt, expected, status) = do
      result <- execute cc root source attempt id
      pure $ counterexample (show result) $ result === Right
        (status, expected, if attempt == 0 then "" else "pudu: memory allocation failed\n")

testPanics :: IO Property
testPanics = withCompiler $ \cc root -> do
  divide <- execute cc root "module Main\nfn crash() -> Int { 1 / 0 }\nfn main() -> Int { crash() }\n" 0 id
  depth <- execute cc root "module Main\nfn recurse(n: Int) -> Int { recurse(n + 1) }\nfn main() -> Int { recurse(0) }\n" 0 id
  addition <- execute cc root "module Main\nfn main() -> Int { 0 }\n" 0
    (Text.replace "{1, 0, 0, 0, NULL" "{SIZE_MAX, 1, 0, 0, NULL")
  multiplication <- execute cc root "module Main\nfn main() -> Int { 0 }\n" 0
    (Text.replace "{1, 0, 0, 0, NULL" "{SIZE_MAX / sizeof(pudu_cell), 0, 0, 0, NULL")
  pure $ conjoin
    [ panic "E7004" divide, panic "E7002" depth
    , addition === Right (ExitFailure 1, "", "pudu: memory allocation failed\n")
    , multiplication === Right (ExitFailure 1, "", "pudu: memory allocation failed\n")
    ]
  where
    panic code result = counterexample (show result) $ case result of
      Right (status, output, errors) -> conjoin
        [ status === ExitFailure 1, output === ""
        , counterexample "wrong runtime failure or leaked frame" (Text.isInfixOf ("error[" <> code <> "]") errors)
        ]
      Left _ -> False === True

testDiagnosticCopies :: IO Property
testDiagnosticCopies = withCompiler $ \cc root -> conjoin <$> traverse (check cc root)
  [ ("E7001", "cannot apply - to a builtin", Nothing,
      "let invalid = -print\n print(show(invalid))")
  , ("E7008", "a builtin cannot be a set member", Just "use a value the language can order",
      "let invalid = setOf([print])\n print(show(invalid))")
  , ("E7004", "slice range out of bounds", Just "it has 1 elements",
      "let items = [1]\n let invalid = items[0..2]\n print(show(invalid))")
  , ("E7004", "slice range out of bounds", Just "it has 2 elements",
      "let text = \"hé\"\n let invalid = text[0..3]\n print(invalid)")
  -- Read through a method receiver, an element fails at its key as it does read as a value.
  , ("E7004", "slice range out of bounds", Just "it has 1 elements",
      "let items = [1]\n print(display(items[0..2].length()))")
  , ("E7004", "slice range out of bounds", Just "it has 2 elements",
      "let text = \"hé\"\n print(text[1..4].trim())")
  , ("E7004", "index out of range", Nothing,
      "let items = [1]\n print(items[3].toText())")
  ]
 where
  check cc root (code, message, help, body) = do
    let source = "module Main\nfn main() -> Int { print(\"before\")\n " <> body <> "\n 0 }\n"
        path = root </> "Main.pudu"
    TextIO.writeFile path source
    result <- execute cc root source 0 id
    oracle <- getExecutablePath
    inherited <- getEnvironment
    parity <- traverse (\engine -> do
      let settings = [("PUDU_EVAL", engine), ("NO_COLOR", "1")]
          process = (proc oracle ["--native-output-oracle", path])
            {env = Just (settings <> filter (\(name, _) -> name `notElem` map fst settings) inherited)}
      (status, output, errors) <- readCreateProcessWithExitCode process ""
      pure $ counterexample (engine <> ": " <> show result) $
        result === Right (status, Text.pack output, Text.pack errors)) ["compiled", "tree"]
    pure $ conjoin (parity <> [counterexample (show result) $ case result of
      Right (status, output, errors) -> conjoin
        [ status === ExitFailure 1, output === "before\n"
        , Text.isInfixOf ("error[" <> code <> "]: " <> message) errors === True
        , maybe True (`Text.isInfixOf` errors) help === True
        , Text.isInfixOf "leaked frame" errors === False
        ]
      Left _ -> False === True])

testDiagnosticBounds :: IO Property
testDiagnosticBounds = withCompiler $ \cc root -> do
  overflow <- injected cc root
    "pudu_fail_text_help(NULL, (pudu_text){NULL, SIZE_MAX, NULL}, (pudu_text){NULL, 1, NULL});"
  empty <- injected cc root
    "pudu_fail_text_help(&pudu_sites[0], (pudu_text){NULL, 0, NULL}, (pudu_text){NULL, 0, NULL});"
  pure $ conjoin
    [ overflow === Right (ExitFailure 1, "", "pudu: memory allocation failed\n")
    , counterexample (show empty) $ case empty of
        Right (status, output, errors) -> conjoin
          [ status === ExitFailure 1, output === ""
          , Text.isInfixOf "error[" errors === True
          , Text.isInfixOf "   = help: \n" errors === True
          , Text.isInfixOf "leaked frame" errors === False ]
        Left _ -> False === True
    ]
 where
  injected cc root probe = execute cc root
    "module Main\nfn main() -> Int { let items = [1]\n print(show(items[0..2]))\n 0 }\n" 0
    (Text.replace "int main(void) {" ("int main(void) { " <> probe))

testJoinOverflow :: IO Property
testJoinOverflow = withCompiler $ \cc root -> conjoin <$> traverse (check cc root)
  [ "pudu_text parts[2] = {{NULL, 0, NULL}, {NULL, SIZE_MAX, NULL}}; (void)pudu_text_join(\"\", NULL, parts, 2, \"\");"
  , "pudu_text parts[1] = {{NULL, SIZE_MAX, NULL}}; const char *labels[1] = {\":\"}; (void)pudu_text_join(\"\", labels, parts, 1, \"\");"
  ]
 where
  check cc root probe = do
    result <- execute cc root "module Main\nfn main() -> (Int, Int) { (1, 2) }\n" 0
      (Text.replace "int main(void) {" ("int main(void) { " <> probe))
    pure $ counterexample (show result) $ result === Right
      (ExitFailure 1, "", "pudu: memory allocation failed\n")

withCompiler :: (FilePath -> FilePath -> IO Property) -> IO Property
withCompiler action = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "frame runtime checks require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-frame-runtime" (action cc)

execute :: FilePath -> FilePath -> Text -> Int -> (Text -> Text)
  -> IO (Either String (ExitCode, Text, Text))
execute cc root sourceText failAt transform = do
  source <- newSource (SourceName (Text.pack (root </> "Main.pudu"))) sourceText
  checked <- runCompile source
  case (hasErrors (compileDiagnostics checked), compileModule checked) of
    (False, Just parsed) -> case lowerModule "main" (nativeTypes (compileTypes checked) (compileSchemes checked)) parsed of
      Lowered core -> case lowerFrames core >>= emitProgram "frame-test" [source] of
        Left failure -> pure (Left (show failure))
        Right emitted -> do
          let cpath = root </> "Main.c"
              binary = root </> "Main"
          TextIO.writeFile cpath (Text.unlines (instrument failAt) <> transform emitted <> trailer)
          (built, output, errors) <- readProcessWithExitCode cc
            ["-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror", cpath, "-o", binary] ""
          if built /= ExitSuccess || not (null output && null errors)
            then pure (Left (show built <> output <> errors))
            else do
              (status, out, err) <- readProcessWithExitCode binary [] ""
              pure (Right (status, Text.pack out, Text.pack err))
      other -> pure (Left (show other))
    _ -> pure (Left (show (compileDiagnostics checked)))

instrument :: Int -> [Text]
instrument attempt =
  -- The runtime's host parts need the POSIX clocks, which glibc declares only
  -- when the feature macros precede the first system header.
  [ "#if defined(__linux__)", "#define _DEFAULT_SOURCE 1", "#define _POSIX_C_SOURCE 200809L", "#endif"
  , "#include <stdlib.h>", "#include <stdio.h>"
  , "static size_t test_live = 0, test_attempt = 0, test_malloc_calls = 0, test_malloc_limit = 0, test_malloc_failure = 0;"
  , "static void *test_malloc(size_t bytes) {"
  , "  if (++test_malloc_calls == test_malloc_failure) return NULL;"
  , "  if (test_malloc_calls > test_malloc_limit && test_malloc_limit != 0) _Exit(96);"
  , "  void *answer = malloc(bytes); if (answer != NULL) ++test_live; return answer;"
  , "}"
  , "static void *test_calloc(size_t count, size_t bytes) {"
  , "  void *answer; ++test_attempt;"
  , "  if (test_attempt == " <> Text.pack (show attempt) <> ") return NULL;"
  , "  answer = calloc(count, bytes); if (answer != NULL) ++test_live; return answer;"
  , "}"
  , "static void test_free(void *pointer) {"
  , "  if (pointer != NULL) { if (test_live == 0) _Exit(98); --test_live; } free(pointer);"
  , "}"
  , "static void test_check(void) { if (test_live != 0) { fputs(\"leaked frame\\n\", stderr); _Exit(97); } }"
  , "#define malloc test_malloc", "#define calloc test_calloc", "#define free test_free", "#define main pudu_test_program"
  ]

trailer :: Text
trailer = Text.unlines
  [ "#undef main", "int main(void) {"
  , "  (void)test_malloc; if (atexit(test_check) != 0) abort(); return pudu_test_program();", "}" ]
