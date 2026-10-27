{-| @Test.Backend.EmitSpec — lowering refusals and emission shape, without a C
    compiler and without executing anything.

    The two promises pinned here are pure functions of the source: lowering
    refuses exactly what the native subset does not carry, at the construct's
    own span, and emission is deterministic and shaped as documented, with the
    checked-arithmetic text baked verbatim from [[Pudu.Diagnostic.Arithmetic]]
    so the native and interpreted texts are equal by construction. Execution
    is [[Pudu.Backend.NativeSpec]]'s.
-}
module Pudu.Backend.EmitSpec (backendEmitProperties) where

import Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit (emitProgram)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Core.Frame (FrameFault (..))
import Pudu.Diagnostic.Native (nativeRefusal)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Lower.Types (nativeTypes)
import Pudu.Compiler.Lower (LowerResult (..), compiledNativeModule, lowerModule, lowerProgram)
import Pudu.Core
  ( CoreBlock (..)
  , CoreExpressionShape (..)
  , CoreFunction (..)
  , CoreParameter (..)
  , CoreLocal (..)
  , CoreModule (..)
  , CoreStatement (..)
  , CoreStatementShape (..)
  , CoreType (..)
  , closureHasEnvironment
  , coreExpressionShape
  )
import Pudu.Diagnostic
  ( Diagnostic
  , diagnosticCode
  , diagnosticCodeText
  , diagnosticMessage
  , diagnosticSpan
  , hasErrors
  )
import Pudu.Diagnostic.Arithmetic
  ( CheckedOperation (..)
  , divideByZeroCode
  , divideByZeroMessage
  , overflowCode
  , overflowHelp
  , overflowMessage
  )
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source
  ( Position (..)
  , Source
  , SourceName (SourceName)
  , newSource
  , emptySpan
  , offsetFromInt
  , offsetPosition
  , sourceText
  , spanStart
  )
import Pudu.Version (versionText)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

backendEmitProperties :: [(String, IO Property)]
backendEmitProperties =
  [ ("a supported program lowers to the expected core shapes", testSupportedLowering)
  , ("divergent entries lower without execution", testDivergentEntries)
  , ("no-else values lower through the unit boundary", testIfUnit)
  , ("unit literals and parameters lower with their signature", testUnitValues)
  , ("invalid loop transfers fail before lowering", testControlDiagnostics)
  , ("unreachable helpers are omitted", testEntryOnly)
  , ("transitively reachable typed functions lower once", testReachableFunctions)
  , ("unsupported constructs refuse with E6001 at their own span", testRefusals)
  , ("function values lower to closures and indirect calls", testLocalFunctionValue)
  , ("emission is deterministic", testDeterminism)
  , ("sites carry the checked-arithmetic text verbatim", testSiteText)
  , ("one site per checked operation", testSiteCount)
  , ("excerpts come from each program's own source", testExcerptSource)
  , ("generated C avoids #line, extensions, and source identifiers", testHygiene)
  ]

{-| Compile a program from source text through the ordinary compiler, then
    lower it, so refusals are about the real checked tree and not a hand-made
    one. -}
compileAndLower :: Text -> IO (Either [Diagnostic] (Source, CoreModule))
compileAndLower text = do
  source <- newSource (SourceName "emit.pudu") text
  result <- runCompile source
  pure $ if hasErrors (compileDiagnostics result)
    then Left (compileDiagnostics result)
    else case compileModule result of
      Nothing -> Left (compileDiagnostics result)
      Just parsed -> case lowerModule "main" (nativeTypes (compileTypes result) (compileSchemes result)) parsed of
        LowerRefused refusals -> Left refusals
        Lowered core -> Right (source, core)

emitText :: Text -> IO (Either [Diagnostic] Text)
emitText text = do
  compiled <- compileAndLower text
  pure $ case compiled of
    Left refusals -> Left refusals
    Right (source, core) -> case lowerFrames core >>= emitProgram versionText [source] of
      Left failure -> Left [nativeRefusal (maybe (emptySpan source) id (frameFaultSpan failure)) (frameFaultMessage failure)]
      Right emitted -> Right emitted

supportedProgram :: Text
supportedProgram =
  Text.unlines
    [ "module Supported"
    , ""
    , "fn main() -> Int {"
    , "  var total = 0"
    , "  var index = 0"
    , "  while index < 3 {"
    , "    total = total + index * 2"
    , "    index = index + 1"
    , "  }"
    , "  print(\"total\")"
    , "  print(display(total))"
    , "  total"
    , "}"
    ]

testSupportedLowering :: IO Property
testSupportedLowering = do
  compiled <- compileAndLower supportedProgram
  pure $ case compiled of
    Left refusals ->
      counterexample ("lowering refused: " <> show (map diagnosticMessage refusals)) False
    Right (_, core) -> conjoin
      [ coreModuleName core === "Supported"
      , case coreModuleFunctions core of
          [function] -> conjoin
            [ coreFunctionName function === "Supported.main"
            , coreFunctionResult function === CoreIntegerType PlatformSigned
            , property (any declaresLocal (coreBlockStatements (coreFunctionBody function)))
            , property (any isWhile (coreBlockStatements (coreFunctionBody function)))
            , property (any isPrint (coreBlockStatements (coreFunctionBody function)))
            , property (isJustResult (coreFunctionBody function))
            ]
          other ->
            counterexample ("expected one function, got " <> show (length other)) False
      ]
 where
  declaresLocal statement = case coreStatementShape statement of
    CoreDeclare{} -> True
    _ -> False
  isWhile statement = case coreStatementShape statement of
    CoreEvaluate expression -> case coreExpressionShape expression of
      CoreWhileValue{} -> True
      _ -> False
    _ -> False
  isPrint statement = case coreStatementShape statement of
    CoreEvaluate expression -> case coreExpressionShape expression of
      CorePrint{} -> True
      CoreBlockValue block -> any isOutput (coreBlockStatements block)
      _ -> False
    _ -> False
  isOutput statement = case coreStatementShape statement of
    CoreDeclare _ output -> case coreExpressionShape output of
      CoreOutputError{} -> True
      _ -> False
    _ -> False
  isJustResult block = case coreBlockResult block of
    Just _ -> True
    Nothing -> False

testDivergentEntries :: IO Property
testDivergentEntries = conjoin <$> mapM check ["loop {}", "return loop {}"]
 where
  check ending = do
    compiled <- compileAndLower $ Text.unlines
      ["module Divergent", "fn main() -> Int {", "  " <> ending, "}"]
    pure $ case compiled of
      Left diagnostics -> counterexample
        (Text.unpack ending <> ": " <> show diagnostics) False
      Right (_, core) ->
        map coreFunctionName (coreModuleFunctions core) === ["Divergent.main"]

testUnitValues :: IO Property
testUnitValues = do
  compiled <- compileAndLower $ Text.unlines
    [ "module Unit", "fn relay(value: ()) -> () { return value }"
    , "fn main() -> () { print(display(relay(())))\n print(display(relay(()) == ()))\n return relay(()) }"
    ]
  pure $ case compiled of
    Left diagnostics -> counterexample (show diagnostics) False
    Right (_, core) ->
      [ (coreFunctionResult function, map (coreLocalType . coreParameterLocal) (coreFunctionParameters function))
      | function <- coreModuleFunctions core
      ] === [(CoreUnitType, [CoreUnitType]), (CoreUnitType, [])]

testControlDiagnostics :: IO Property
testControlDiagnostics = conjoin <$> mapM check cases
 where
  cases =
    [ ("unknown break label", "loop { break @missing }", "E2017")
    , ("unknown continue label", "loop { continue @missing }", "E2017")
    , ("break value from while", "while true { break 3 }", "E3029")
    , ("break outside loop", "break", "E2016")
    ]
  check (label, statement, code) = do
    source <- newSource (SourceName "control.pudu") $ Text.unlines
      ["module Control", "fn main() -> Int {", "  " <> statement, "  return 0", "}"]
    result <- runCompile source
    let diagnostics = compileDiagnostics result
    pure $ counterexample (label <> ": " <> show diagnostics) $ conjoin
      [ property (hasErrors diagnostics)
      , property (code `elem` map (diagnosticCodeText . diagnosticCode) diagnostics)
      ]

{-| An unsupported but unreachable declaration cannot block the entry. -}
testEntryOnly :: IO Property
testEntryOnly = do
  compiled <- compileAndLower entryWithOther
  pure $ case compiled of
    Left refusals ->
      counterexample ("refused: " <> show (map diagnosticMessage refusals)) False
    Right (_, core) ->
      counterexample "exactly the entry is carried"
        (map coreFunctionName (coreModuleFunctions core) === ["Entryonly.main"])
 where
  entryWithOther =
    Text.unlines
      [ "module Entryonly"
      , ""
      , "fn main() -> Int {"
      , "  return 0"
      , "}"
      , ""
      , "fn other(value: BigInt) -> BigInt {"
      , "  return value"
      , "}"
      ]

testIfUnit :: IO Property
testIfUnit = conjoin <$> mapM check ["7", "true", "print(\"taken\")"]
 where
  check expression = do
    result <- compileAndLower $ Text.unlines
      ["module IfUnit", "fn main() { let token = if true { " <> expression <> " }\n token }"]
    pure $ case result of
      Left diagnostics -> counterexample (show diagnostics) False
      Right (_, core) -> map coreFunctionResult (coreModuleFunctions core) === [CoreUnitType]

testReachableFunctions :: IO Property
testReachableFunctions = do
  compiled <- compileAndLower $ Text.unlines
    [ "module Reachable"
    , "fn second(flag: Bool) -> Bool { return !flag }"
    , "fn unused(value: BigInt) -> BigInt { return value }"
    , "fn main() -> Int { return first(9, second(false)) }"
    , "fn first(value: Int, flag: Bool) -> Int {"
    , "  if second(flag) { return 0 }"
    , "  return value"
    , "}"
    ]
  pure $ case compiled of
    Left refusals -> counterexample (show refusals) False
    Right (_, core) -> conjoin
      [ map coreFunctionName (coreModuleFunctions core) === ["Reachable.second", "Reachable.main", "Reachable.first"]
      , [ (coreFunctionResult function, map (coreLocalType . coreParameterLocal) (coreFunctionParameters function))
        | function <- coreModuleFunctions core
        ] === [(CoreBoolType, [CoreBoolType]), (CoreIntegerType PlatformSigned, []),
               (CoreIntegerType PlatformSigned, [CoreIntegerType PlatformSigned, CoreBoolType])]
      ]

{-| Each case is a program that compiles and a marker whose first occurrence is
    the construct lowering must refuse; the expected position is computed from
    the source itself so the test reads as "the refusal points at the
    construct", not as a hand-counted column. -}
refusalCases :: [(String, Text, Text)]
refusalCases =
  [ ("BigInt parameter", helperProgram "fn helper(value: BigInt) -> Int { return 1 }" "helper(1)", "BigInt")
  , ("Decimal parameter", helperProgram "fn helper(value: Decimal) -> Int { return 1 }" "helper(1.5d)", "Decimal")
  , ("BigInt result", helperProgram "fn helper() -> BigInt { return 1 }" "{ helper()\n  0 }", "BigInt")
  , ("call to entry", statementProgram "main()", "main()\n")
  , ("environment", bindingProgram "var pairs = environment()", "environment()")
  , ("decimal values", bindingProgram "var ratio = 1.5d", "1.5d")
  , ("readLine", bindingProgram "var line = readLine()", "readLine()")
  , ("temporary path", bindingProgram "var path = temporaryPath()", "temporaryPath()")
  , ("mutable borrows", Text.unlines
      [ "module Refuse"
      , ""
      , "fn bump(value: &mut Int) -> () { *value = *value + 1 }"
      , "fn main() -> Int {"
      , "  var value = 1"
      , "  bump(&mut value)"
      , "  return value"
      , "}"
      ], "&mut Int")
  , ("methods that borrow their receiver mutably", Text.unlines
      [ "module Refuse"
      , "trait Bump { fn bump(self: &mut Self) -> () }"
      , "type Count = { mut n: Int }"
      , "impl Bump for Count { fn bump(self: &mut Self) -> () { self.n = self.n + 1 } }"
      , "fn main() -> Int {"
      , "  var count = Count{n: 1}"
      , "  count.bump()"
      , "  return count.n"
      , "}"
      ], "&mut Self) -> () {")
  , ("a generic call at a type without a native form", Text.unlines
      [ "module Refuse"
      , "fn keep[T](value: T) -> Int { 1 }"
      , "fn main() -> Int {"
      , "  let kept = keep(1.5d)"
      , "  return kept"
      , "}"
      ], "keep(1.5d)")
  , ("a module without main", Text.unlines
      [ "module Refuse"
      , ""
      , "fn other() -> Int {"
      , "  return 1"
      , "}"
      ], "other")
      ]
 where
  helperProgram helper call = Text.unlines
    ["module Refuse", helper, "fn main() -> Int {", "  return " <> call, "}"]
  bindingProgram binding = statementProgram binding
  statementProgram statement =
    Text.unlines
      [ "module Refuse"
      , ""
      , "fn main() -> Int {"
      , "  " <> statement
      , "  return 0"
      , "}"
      ]

testRefusals :: IO Property
testRefusals = do
  outcomes <- mapM refusalOutcome refusalCases
  pure (conjoin outcomes)

refusalOutcome :: (String, Text, Text) -> IO Property
refusalOutcome (label, sourceText', marker) = do
  source <- newSource (SourceName "refuse.pudu") sourceText'
  result <- runCompile source
  pure $ case (hasErrors (compileDiagnostics result), compileModule result) of
    (True, _) -> counterexample (label <> ": compile errors: " <> show (compileDiagnostics result)) False
    (_, Nothing) -> counterexample (label <> ": the program did not compile") False
    (False, Just parsed) -> case lowerProgram "main" [compiledNativeModule parsed result] of
      Lowered _ -> counterexample (label <> ": lowered, but a refusal was expected") False
      LowerRefused refusals -> conjoin
        [ counterexample
            (label <> ": " <> show (map diagnosticMessage refusals))
            (property (all ((== "E6001") . diagnosticCodeText . diagnosticCode) refusals))
        , case refusals of
            [refusal] -> case markerPosition source marker of
              Nothing -> counterexample (label <> ": marker is not in the source") False
              Just expected ->
                case offsetPosition source (spanStart (diagnosticSpan refusal)) of
                  Just actual -> counterexample (label <> ": the refusal points elsewhere") (actual === expected)
                  Nothing -> counterexample (label <> ": the refusal span has no position") False
            _ -> counterexample (label <> ": expected exactly one refusal") False
        ]

testLocalFunctionValue :: IO Property
testLocalFunctionValue = do
  source <- newSource (SourceName "indirect.pudu") $ Text.unlines
    [ "module Indirect", "fn helper() -> Int { return 1 }"
    , "fn main() -> Int {", "  let chosen = helper", "  return chosen()", "}"
    ]
  result <- runCompile source
  pure $ case (hasErrors (compileDiagnostics result), compileModule result) of
    (False, Just parsed) -> case lowerModule "main" (nativeTypes (compileTypes result) (compileSchemes result)) parsed of
      Lowered core -> conjoin
        [ counterexample "named callable has the wrong target ABI"
            (maybe False (not . closureHasEnvironment) (Map.lookup "Indirect.helper" (coreModuleClosures core)))
        , map coreFunctionName (coreModuleFunctions core) === ["Indirect.helper", "Indirect.main"]
        , counterexample "no call through the value" ("CoreCallValue" `isInfixOf` show (coreModuleFunctions core))
        ]
      LowerRefused refusals -> counterexample ("refused: " <> show (map diagnosticMessage refusals)) False
    _ -> counterexample ("indirect-call fixture: " <> show (compileDiagnostics result)) False

markerPosition :: Source -> Text -> Maybe Position
markerPosition source marker = do
  offset <- offsetFromInt (Text.length before)
  offsetPosition source offset
 where
  (before, _) = Text.breakOn marker (sourceText source)

testDeterminism :: IO Property
testDeterminism = do
  first <- emitText supportedProgram
  second <- emitText supportedProgram
  pure $ case (first, second) of
    (Right one, Right two) -> one === two
    _ -> counterexample "the supported program did not emit" False

divisionProgram :: Text
divisionProgram =
  Text.unlines
    [ "module Divzero"
    , ""
    , "fn main() -> Int {"
    , "  var value = 10 / 0"
    , "  return value"
    , "}"
    ]

overflowProgram :: Text
overflowProgram =
  Text.unlines
    [ "module Overflow"
    , ""
    , "fn main() -> Int {"
    , "  var value = 9223372036854775807 + 1"
    , "  return value"
    , "}"
    ]

testSiteText :: IO Property
testSiteText = do
  division <- emitText divisionProgram
  overflow <- emitText overflowProgram
  pure $ case (division, overflow) of
    (Right divText, Right overText) -> conjoin
      [ property (Text.isInfixOf divideByZeroCode divText)
      , property (Text.isInfixOf divideByZeroMessage divText)
      , counterexample "division carries its own overflow site"
          (property (Text.isInfixOf (overflowMessage PlatformSigned CheckedDivide) divText))
      , property (Text.isInfixOf overflowCode overText)
      , property (Text.isInfixOf (overflowMessage PlatformSigned CheckedAdd) overText)
      , property (Text.isInfixOf overflowHelp overText)
      , counterexample "an add's words reached a division site"
          (property (not (Text.isInfixOf (overflowMessage PlatformSigned CheckedAdd) divText)))
      ]
    _ -> counterexample "the programs did not emit" False

testSiteCount :: IO Property
testSiteCount = do
  emitted <- emitText twoCheckedOperations
  pure $ case emitted of
    Left refusals -> counterexample (show refusals) False
    Right text -> conjoin
      [ counterexample "one site per checked operation"
          (Text.count overflowCode text === 2)
      , counterexample "no division-by-zero site in a program without division"
          (Text.count divideByZeroCode text === 0)
      ]
 where
  twoCheckedOperations =
    Text.unlines
      [ "module Twosites"
      , ""
      , "fn main() -> Int {"
      , "  var first = 1 + 2"
      , "  var second = first * 3"
      , "  return second"
      , "}"
      ]

{-| Two programs whose division lines start at the same offsets; each emitted
    unit must quote its own line, so excerpts are read from the program being
    emitted and not from whichever source was seen first. -}
testExcerptSource :: IO Property
testExcerptSource = do
  alpha <- emitText (excerptProgram "Excerpta" "alpha" "10")
  bravo <- emitText (excerptProgram "Excerptb" "bravo" "20")
  pure $ case (alpha, bravo) of
    (Right alphaText, Right bravoText) -> conjoin
      [ property (Text.isInfixOf "var alpha = 10 / 0" alphaText)
      , counterexample "the other program's line leaked" (property (not (Text.isInfixOf "bravo" alphaText)))
      , property (Text.isInfixOf "var bravo = 20 / 0" bravoText)
      , counterexample "the other program's line leaked" (property (not (Text.isInfixOf "alpha" bravoText)))
      ]
    _ -> counterexample "the excerpt programs did not emit" False
 where
  excerptProgram moduleName' localName number =
    Text.unlines
      [ "module " <> moduleName'
      , ""
      , "fn main() -> Int {"
      , "  var " <> localName <> " = " <> number <> " / 0"
      , "  return " <> localName
      , "}"
      ]

testHygiene :: IO Property
testHygiene = do
  emitted <- emitText supportedProgram
  pure $ case emitted of
    Left refusals -> counterexample (show refusals) False
    Right text -> conjoin
      [ counterexample "the C preprocessor must not be told about source lines"
          (property (not (Text.isInfixOf "#line" text)))
      , counterexample "a source identifier was used as a C identifier"
          (property (not (Text.isInfixOf "int64_t total" text)))
      , property (Text.isInfixOf "frame->slots[" text)
      , counterexample ("nonstandard includes: " <> show (includesOf text))
          (property (all (`elem` allowedIncludes) (includesOf text)))
      ]
 where
  includesOf value =
    [Text.strip line | line <- Text.lines value, "#include" `Text.isPrefixOf` Text.strip line]
  allowedIncludes =
    [ "#include <sys/event.h>"
    , "#include <sys/epoll.h>"
    , "#include <errno.h>"
    , "#include <limits.h>"
    , "#include <poll.h>"
    , "#include <fcntl.h>"
    , "#include <inttypes.h>"
    , "#include <stdint.h>"
    , "#include <signal.h>"
    , "#include <stdio.h>"
    , "#include <stdlib.h>"
    , "#include <string.h>"
    , "#include <io.h>"
    , "#include <unistd.h>"
    ]
