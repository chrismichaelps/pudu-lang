{-| @Test.Backend.TextLeakSpec — every text program frees what it allocates. -}
module Pudu.Backend.TextLeakSpec (textLeakProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Emit (emitProgram)
import Pudu.Backend.TextMethodPrograms (textMethodSuccessPrograms)
import Pudu.Backend.TextViewPrograms (textViewSuccessPrograms)
import Pudu.Backend.BigIntPrograms (bigIntSuccessPrograms)
import Pudu.Backend.DecimalPrograms (decimalLeakPrograms)
import Pudu.Backend.CharPrograms (charSuccessPrograms)
import Pudu.Backend.TuplePrograms (tupleSuccessPrograms)
import Pudu.Backend.RecordPrograms (recordSuccessPrograms)
import Pudu.Backend.SumPrograms (sumSuccessPrograms)
import Pudu.Backend.ModulePrograms (constantPrograms)
import Pudu.Backend.ReferencePrograms (referenceSuccessPrograms)
import Pudu.Backend.MethodPrograms (methodSuccessPrograms)
import Pudu.Backend.GenericPrograms (genericSuccessPrograms)
import Pudu.Backend.TryPrograms (trySuccessPrograms)
import Pudu.Backend.ForPrograms (forSuccessPrograms)
import Pudu.Backend.ClosurePrograms (closureSuccessPrograms)
import Pudu.Backend.ArrayPrograms (arraySuccessPrograms)
import Pudu.Backend.ArrayPatternPrograms (arrayPatternSuccessPrograms)
import Pudu.Backend.TextCollectionPrograms (textCollectionSuccessPrograms)
import Pudu.Backend.ConvertPrograms (convertSuccessPrograms)
import Pudu.Backend.KeyedPrograms (keyedSuccessPrograms)
import Pudu.Backend.ShapePrograms (shapeSuccessPrograms)
import Pudu.Backend.RangePrograms (rangeSuccessPrograms)
import Pudu.Backend.OutputCallablePrograms (outputCallableSuccessPrograms, outputCallableFailureCleanup)
import Pudu.Backend.NamedCallablePrograms (namedCallableSuccessPrograms)
import Pudu.Backend.ExpressionBodyPrograms (expressionBodySuccessPrograms)
import Pudu.Backend.OutputPrograms (outputSuccessPrograms, outputStreamPrograms)
import Pudu.Backend.BytesPrograms (bytesSuccessPrograms)
import Pudu.Backend.WordMapPrograms (wordMapSuccessPrograms)
import Pudu.Backend.StorePrograms (storeSuccessPrograms)
import Pudu.Backend.KernelPrograms (kernelSuccessPrograms)
import Pudu.Backend.AbstractionPrograms (abstractionSuccessPrograms)
import Pudu.Backend.HostPrograms (hostCountedPrograms)
import Pudu.Backend.CryptoPrograms (cryptoSuccessPrograms)
import Pudu.Backend.TextPrograms (textSuccessPrograms)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), compiledNativeModule, lowerProgram)
import Pudu.Diagnostic (hasErrors)
import Pudu.Source (SourceName (..), newSource)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.Info (os)
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

textLeakProperties :: [(String, IO Property)]
textLeakProperties =
  [ ("native text programs release every allocation", testLeaks)
  , ("native output Results release every allocation", testLeaksWithStreams
      ([(label, source, output, "") | (label, source, output) <- outputSuccessPrograms] <> outputStreamPrograms <> outputCallableSuccessPrograms))
  , ("native output callables release failed Results", testFailedOutputLeaks)
  , ("native output callables release every allocation", testLeaksWithStreams outputCallableSuccessPrograms)
  , ("native named callables release every allocation", testLeaksFor (namedCallableSuccessPrograms <> closureSuccessPrograms))
  , ("native expression bodies release every allocation", testLeaksFor expressionBodySuccessPrograms)
  , ("native Bytes programs release every allocation", testLeaksFor bytesSuccessPrograms)
  , ("native word-map algebra releases every allocation", testLeaksFor wordMapSuccessPrograms)
  , ("native indexed stores and MultiMap primitives release every allocation", testLeaksFor storeSuccessPrograms)
  , ("native pure kernels release every allocation", testLeaksFor kernelSuccessPrograms)
  , ("native host services, tasks and scopes release every allocation", testLeaksFor hostCountedPrograms)
  , ("native type parameters, constructors, dynamic values and sequence bindings release every allocation", testLeaksFor abstractionSuccessPrograms)
  , ("native digests and sealing release every allocation", testLeaksFor cryptoSuccessPrograms)
  , ("native text-view reads release every allocation", testLeaksFor textViewSuccessPrograms)
  , ("native folded constants release every allocation", testLeaksFor constantPrograms)
  , ("native Decimal programs release every allocation", testLeaksFor decimalLeakPrograms)
  , ("native foreign handles release each claim exactly once", testForeignHandleLeaks)
  ]

testLeaks :: IO Property
testLeaks = testLeaksFor (textViewSuccessPrograms <> wordMapSuccessPrograms <> namedCallableSuccessPrograms <> expressionBodySuccessPrograms <> textSuccessPrograms <> textMethodSuccessPrograms <> charSuccessPrograms <> bigIntSuccessPrograms <> decimalLeakPrograms <> tupleSuccessPrograms <> recordSuccessPrograms <> sumSuccessPrograms <> constantPrograms <> referenceSuccessPrograms <> methodSuccessPrograms <> genericSuccessPrograms <> trySuccessPrograms <> forSuccessPrograms <> closureSuccessPrograms <> arraySuccessPrograms <> arrayPatternSuccessPrograms <> textCollectionSuccessPrograms <> convertSuccessPrograms <> keyedSuccessPrograms <> shapeSuccessPrograms <> rangeSuccessPrograms <> bytesSuccessPrograms)

testLeaksFor :: [(String, Text, Text)] -> IO Property
testLeaksFor programs = testLeaksWithStreams [(label, source, output, "") | (label, source, output) <- programs]

testLeaksWithStreams :: [(String, Text, Text, Text)] -> IO Property
testLeaksWithStreams = testLeaksWithSetup ""

testFailedOutputLeaks :: IO Property
testFailedOutputLeaks
  | os == "mingw32" = putStrLn "[skip] failed output cleanup requires POSIX pipes; Windows evidence remains pending" >> pure (True === True)
  | otherwise = testLeaksWithSetup setup outputCallableFailureCleanup
 where
  setup = Text.unlines
    [ "  for (int target = 1; target <= 2; ++target) {"
    , "    int descriptors[2];"
    , "    if (pipe(descriptors) != 0 || close(descriptors[0]) != 0) return 96;"
    , "    if (dup2(descriptors[1], target) < 0 || close(descriptors[1]) != 0) return 96;"
    , "  }" ]

testForeignHandleLeaks :: IO Property
testForeignHandleLeaks = testCountedPrograms linkerFlags fixture "" cases
 where
  linkerFlags = ["-pthread", if os == "darwin" then "-Wl,-export_dynamic" else "-Wl,--export-dynamic"]
    <> ["-ldl" | os == "linux"]
  fixture = Text.unlines
    [ "static int test_handles[3];"
    , "void pudu_test_slots(int32_t *first, int32_t value, int32_t *untouched) {"
    , "  if (*untouched != 0) abort();"
    , "  *first = value + 1;"
    , "}"
    , "void *pudu_test_handle(int32_t slot) { return &test_handles[slot]; }"
    , "const char *pudu_test_handle_render(void *handle) {"
    , "  static char rendered[32];"
    , "  snprintf(rendered, sizeof rendered, \"<Handle at 0x%\" PRIxPTR, (uintptr_t)handle);"
    , "  return rendered;"
    , "}"
    , "const char *pudu_test_handle_null_text(void *handle, const char *text) {"
    , "  return handle == &test_handles[0] && strcmp(text, \"probe\") == 0 ? NULL : \"unexpected\";"
    , "}"
    , "void *pudu_test_entry_handle(void) { return (void *)(uintptr_t)1; }"
    , "void pudu_test_release_entry_handle(void *handle) {"
    , "  if ((uintptr_t)handle != 1) abort();"
    , "  puts(\"release entry\");"
    , "  fflush(stdout);"
    , "}"
    , "void pudu_test_text_slots(const char **first, const char **second) {"
    , "  if (*first != NULL || *second != NULL) abort();"
    , "  *first = \"written\";"
    , "}"
    , "typedef struct { double value; uint8_t marker; } test_padded;"
    , "typedef struct { test_padded inner; uint8_t tail; } test_padded_slot;"
    , "void pudu_test_padded_slot(test_padded_slot *slot) {"
    , "  slot->inner.value = 4.0; slot->tail = 7;"
    , "}"
    , "typedef struct { int32_t value; } test_value;"
    , "int32_t pudu_test_record_argument(test_value record) { return record.value; }"
    , "typedef struct { const char *first, *second; } test_pair;"
    , "test_pair pudu_test_handle_text_pair(void *handle, const char *text, uint8_t invalid) {"
    , "  if (handle != &test_handles[0]) return (test_pair){\"unexpected\", \"handle\"};"
    , "  if (invalid) return (test_pair){NULL, \"\\xff\"};"
    , "  return (test_pair){text, NULL};"
    , "}"
    , "int32_t pudu_test_read_handle(void *handle) {"
    , "  int slot = (int)((int *)handle - test_handles);"
    , "  printf(\"read %d\\n\", slot);"
    , "  fflush(stdout);"
    , "  return slot;"
    , "}"
    , "int32_t pudu_test_release_handle(void *handle) {"
    , "  int slot = (int)((int *)handle - test_handles);"
    , "  fprintf(stderr, \"release %d\\n\", slot);"
    , "  fflush(stderr);"
    , "  printf(\"release %d\\n\", slot);"
    , "  fflush(stdout);"
    , "  return slot;"
    , "}"
    ]
  cases =
    [ ("explicit and implicit releases count claims, including two references to one address", program
        [ "let explicit = acquire(0i32)"
        , "let implicit = acquire(1i32)"
        , "let borrowed = borrow(2i32)"
        , "let first = retainHandle(2i32)"
        , "let second = retainHandle(2i32)"
        , "let status = release(explicit)"
        , "release(first)"
        , "let rendered = show(implicit) == renderHandle(implicit)"
        , "rendered && status == 0i32 && readHandle(implicit) == 1i32 && readHandle(borrowed) == 2i32 && readHandle(second) == 2i32"
        ], "release 0\nrelease 2\nread 1\nread 2\nread 2\nrelease 1\nrelease 2\ntrue\n",
        "release 0\nrelease 2\nrelease 1\nrelease 2\n", ExitSuccess)
    , ("duplicate ownership preserves the original release obligation", program
        [ "acquire(0i32)"
        , "acquire(0i32)"
        , "false"
        ], "release 0\n", "release 0\nerror[E7021]: pudu_test_handle returned a Handle already owned\n", ExitFailure 1)
    , ("a reused address never revives the stale claim", program
        [ "let stale = acquire(0i32)"
        , "release(stale)"
        , "acquire(0i32)"
        , "readHandle(stale) == 0i32"
        ], "release 0\nrelease 0\n",
        "release 0\nrelease 0\nerror[E7022]: the Handle passed to pudu_test_read_handle is no longer owned\n", ExitFailure 1)
    , ("a null text result releases the argument copy and the live handle", program
        [ "let live = acquire(0i32)"
        , "nullText(live, \"probe\") == \"unexpected\""
        ], "release 0\n", "release 0\nerror[E7024]: pudu_test_handle_null_text returned no text for result\n", ExitFailure 1)
    , ("a missing record text field releases the argument copy and the live handle", program
        [ "let live = acquire(0i32)"
        , "textPair(live, \"probe\", false).first == \"unexpected\""
        ], "release 0\n",
        "release 0\nerror[E7024]: pudu_test_handle_text_pair returned no text for second\n", ExitFailure 1)
    , ("invalid record text takes priority over an earlier missing field", program
        [ "let live = acquire(0i32)"
        , "textPair(live, \"probe\", true).first == \"unexpected\""
        ], "release 0\n",
        "release 0\nerror[E7025]: pudu_test_handle_text_pair returned text that is not valid UTF-8\n", ExitFailure 1)
    , ("a folded record used only as a foreign argument has a layout", Text.unlines
        [ "module Main"
        , "type Value = { value: Int32 }"
        , "const PROBE: Value = Value{value: 7i32}"
        , "foreign \"c\" { fn read symbol \"pudu_test_record_argument\" (record: Value) -> Int32 }"
        , "fn main() -> Bool { unsafe(foreign) { read(PROBE) == 7i32 } }"
        ], "true\n", "", ExitSuccess)
    , ("out slots interleave with operands and start zeroed", Text.unlines
        [ "module Main"
        , "foreign \"c\" { fn slots symbol \"pudu_test_slots\" (out first: Int32, value: Int32, out untouched: Int32) -> () }"
        , "fn main() -> Bool {"
        , "  let (_, first, untouched) = unsafe(foreign) { slots(7i32) }"
        , "  first == 8i32 && untouched == 0i32"
        , "}"
        ], "true\n", "", ExitSuccess)
    , ("record output slots preserve nested padding and drop temporary boxes", Text.unlines
        [ "module Main"
        , "type Inner = { value: Float64, marker: UInt8 }"
        , "type Written = { inner: Inner, tail: UInt8 }"
        , "foreign \"c\" { fn fill symbol \"pudu_test_padded_slot\" (out written: Written) -> () }"
        , "fn main() -> Bool {"
        , "  let (_, written) = unsafe(foreign) { fill() }"
        , "  written.inner.value == 4.0 && written.inner.marker == 0u8 && written.tail == 7u8"
        , "}"
        ], "true\n", "", ExitSuccess)
    , ("text slots copy Some and preserve None without leaks", Text.unlines
        [ "module Main"
        , "foreign \"c\" { fn fill symbol \"pudu_test_text_slots\" (out first: Str, out second: Str) -> () }"
        , "fn main() -> Bool {"
        , "  let (_, first, second) = unsafe(foreign) { fill() }"
        , "  show(first) == \"Some(\\\"written\\\")\" && show(second) == \"None\""
        , "}"
        ], "true\n", "", ExitSuccess)
    , ("entry reporting uses the handle box after teardown", Text.unlines
        [ "module Main"
        , "foreign \"c\" {"
        , "  type Handle"
        , "  fn acquire symbol \"pudu_test_entry_handle\" () -> owned Handle by release"
        , "  fn release symbol \"pudu_test_release_entry_handle\" (handle: Handle) -> ()"
        , "}"
        , "fn main() -> Handle { unsafe(foreign) { acquire() } }"
        ], "release entry\n<Handle at 0x1\n", "", ExitSuccess)
    ]
  program body = Text.unlines
    ([ "module Main"
     , "type TextPair = { first: Str, second: Str }"
     , "foreign \"c\" {"
     , "  type Handle"
     , "  fn acquire symbol \"pudu_test_handle\" (slot: Int32) -> owned Handle by release"
     , "  fn borrow symbol \"pudu_test_handle\" (slot: Int32) -> borrowed Handle"
     , "  fn retainHandle symbol \"pudu_test_handle\" (slot: Int32) -> counted Handle by release"
     , "  fn readHandle symbol \"pudu_test_read_handle\" (handle: Handle) -> Int32"
     , "  fn release symbol \"pudu_test_release_handle\" (handle: Handle) -> Int32"
     , "  fn renderHandle symbol \"pudu_test_handle_render\" (handle: Handle) -> Str"
     , "  fn nullText symbol \"pudu_test_handle_null_text\" (handle: Handle, text: Str) -> Str"
     , "  fn textPair symbol \"pudu_test_handle_text_pair\" (handle: Handle, text: Str, invalid: Bool) -> TextPair"
     , "}"
     , "fn main() -> Bool {"
     , "  unsafe(foreign) {"
     ] <> map ("    " <>) body <> ["  }", "}"])

testLeaksWithSetup :: Text -> [(String, Text, Text, Text)] -> IO Property
testLeaksWithSetup setup programs =
  testCountedPrograms [] "" setup
    [(label, source, output, errors, ExitSuccess) | (label, source, output, errors) <- programs]

testCountedPrograms :: [String] -> Text -> Text -> [(String, Text, Text, Text, ExitCode)] -> IO Property
testCountedPrograms linkerFlags fixture setup programs = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "text leak checks require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-text-leaks" $ \root -> do
      outcomes <- traverse (check cc root) programs
      putStrLn ("[text leaks] executed " <> show (length outcomes) <> " counted programs")
      pure (conjoin outcomes)
 where
  check cc root (label, text, expected, expectedErrors, expectedStatus) = do
    source <- newSource (SourceName "Main.pudu") text
    checked <- runCompile source
    case (hasErrors (compileDiagnostics checked), compileModule checked) of
      (False, Just parsed) -> case lowerProgram "main" [compiledNativeModule parsed checked] of
        Lowered core -> case lowerFrames core >>= emitProgram "text-leak-test" [source] of
          Left failure -> pure (counterexample (label <> ": " <> show failure) (False === True))
          Right emitted -> do
            let path = root </> "leaks.c"
                binary = root </> "leaks"
            TextIO.writeFile path (instrument <> emitted <> fixture <> trailer setup)
            (built, output, errors) <- readProcessWithExitCode cc
              (["-std=c11", "-pedantic", "-O2", "-Wall", "-Wextra", "-Werror", "-Wno-unused-function", path, "-o", binary, "-lm"] <> linkerFlags) ""
            if built /= ExitSuccess || not (null output && null errors)
              then pure (counterexample (label <> ": " <> show built <> output <> errors) (False === True))
              else do
                (status, out, err) <- readProcessWithExitCode binary [] ""
                let observedErrors = case expectedStatus of
                      ExitSuccess -> Text.pack err
                      ExitFailure _ -> Text.take (Text.length expectedErrors) (Text.pack err)
                pure $ counterexample (label <> ": " <> show (status, err)) $ conjoin
                  [status === expectedStatus, Text.pack out === expected, observedErrors === expectedErrors]
        other -> pure (counterexample (label <> ": " <> show other) (False === True))
      _ -> pure (counterexample (label <> ": " <> show (compileDiagnostics checked)) (False === True))

{-| Counts every live heap block, frames and text alike, and fails the process
    at exit if any is still held. -}
instrument :: Text
instrument = Text.unlines
  [ "#if defined(__linux__)", "#define _DEFAULT_SOURCE 1", "#define _POSIX_C_SOURCE 200809L", "#endif"
  , "#include <stdlib.h>", "#include <stdio.h>"
  , "static size_t test_live = 0;"
  , "static void *test_malloc(size_t bytes) {"
  , "  void *answer = malloc(bytes); if(answer != NULL) ++test_live; return answer; }"
  , "static void *test_calloc(size_t count, size_t bytes) {"
  , "  void *answer = calloc(count,bytes); if(answer != NULL) ++test_live; return answer; }"
  , "static void test_free(void *pointer) {"
  , "  if(pointer != NULL) { if(test_live == 0) _Exit(98); --test_live; } free(pointer); }"
  , "static void test_check(void) { if(test_live != 0) { fprintf(stderr, \"leaked %zu blocks\\n\", test_live); _Exit(97); } }"
  , "#define malloc test_malloc", "#define calloc test_calloc", "#define free test_free"
  , "#define main pudu_test_program"
  ]

trailer :: Text -> Text
trailer setup = Text.unlines
  [ "#undef main", "int main(void) {"
  , "  if(atexit(test_check) != 0) abort();", setup, "  return pudu_test_program();", "}" ]
