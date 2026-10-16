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

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit (emitProgram)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Lower (LowerResult (..), lowerProgram)
import Pudu.Core
  ( CoreBlock (..)
  , CoreExpressionShape (..)
  , CoreFunction (..)
  , CoreModule (..)
  , CoreStatement (..)
  , CoreStatementShape (..)
  , CoreType (..)
  , coreExpressionShape
  )
import Pudu.Diagnostic
  ( Diagnostic
  , diagnosticCode
  , diagnosticCodeText
  , diagnosticMessage
  , diagnosticSpan
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
  , ("only the entry function is emitted", testEntryOnly)
  , ("unsupported constructs refuse with E6001 at their own span", testRefusals)
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
  pure $ case compileModule result of
    Nothing -> Left (compileDiagnostics result)
    Just parsed -> case lowerProgram "main" parsed of
      LowerRefused refusals -> Left refusals
      Lowered core -> Right (source, core)

emitText :: Text -> IO (Either [Diagnostic] Text)
emitText text = do
  compiled <- compileAndLower text
  pure $ case compiled of
    Left refusals -> Left refusals
    Right (source, core) -> Right (emitProgram versionText [source] core)

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
            [ coreFunctionName function === "main"
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
    CoreWhile{} -> True
    _ -> False
  isPrint statement = case coreStatementShape statement of
    CoreEvaluate expression -> case coreExpressionShape expression of
      CorePrint{} -> True
      _ -> False
    _ -> False
  isJustResult block = case coreBlockResult block of
    Just _ -> True
    Nothing -> False

{-| A declaration the entry cannot reach does not block the build: calls are
    refused in this milestone, so an uncalled function is unreachable and only
    the entry is carried. A module with no `main` refuses instead, naming its
    first declaration. -}
testEntryOnly :: IO Property
testEntryOnly = do
  compiled <- compileAndLower entryWithOther
  pure $ case compiled of
    Left refusals ->
      counterexample ("refused: " <> show (map diagnosticMessage refusals)) False
    Right (_, core) ->
      counterexample "exactly the entry is carried"
        (map coreFunctionName (coreModuleFunctions core) === ["main"])
 where
  entryWithOther =
    Text.unlines
      [ "module Entryonly"
      , ""
      , "fn main() -> Int {"
      , "  return 0"
      , "}"
      , ""
      , "fn other() -> Int {"
      , "  return 1"
      , "}"
      ]

{-| Each case is a program that compiles and a marker whose first occurrence is
    the construct lowering must refuse; the expected position is computed from
    the source itself so the test reads as "the refusal points at the
    construct", not as a hand-counted column. -}
refusalCases :: [(String, Text, Text)]
refusalCases =
  [ ("arrays", bindingProgram "var items = [1, 2, 3]", "[1, 2, 3]")
  , ("floating-point values", bindingProgram "var ratio = 1.5", "1.5")
  , ("break", statementProgram "while true { break }", "break")
  , ("bindings of type Str", bindingProgram "var greeting = \"hello\"", "var greeting")
  , ("match expressions", bindingProgram "var chosen = match 1 { case _ => 0 }", "match")
  , ("borrows", Text.unlines
      [ "module Refuse"
      , ""
      , "fn main() -> Int {"
      , "  var value = 1"
      , "  var borrowed = &value"
      , "  return value"
      , "}"
      ], "&value")
  , ("a module without main", Text.unlines
      [ "module Refuse"
      , ""
      , "fn other() -> Int {"
      , "  return 1"
      , "}"
      ], "other")
      ]
 where
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
  pure $ case compileModule result of
    Nothing ->
      counterexample (label <> ": the program did not compile") False
    Just parsed -> case lowerProgram "main" parsed of
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
      , property (Text.isInfixOf "pudu_v" text)
      , counterexample ("nonstandard includes: " <> show (includesOf text))
          (property (all (`elem` allowedIncludes) (includesOf text)))
      ]
 where
  includesOf value =
    [Text.strip line | line <- Text.lines value, "#include" `Text.isPrefixOf` Text.strip line]
  allowedIncludes =
    [ "#include <inttypes.h>"
    , "#include <stdint.h>"
    , "#include <stdio.h>"
    , "#include <stdlib.h>"
    , "#include <string.h>"
    , "#include <io.h>"
    , "#include <unistd.h>"
    ]
