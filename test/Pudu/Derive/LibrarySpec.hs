{-| @Test.Derive.LibrarySpec — shipped derives, builders and static selection, run. -}
module Pudu.Derive.LibrarySpec (deriveLibraryProperties) where

import Control.Exception (finally)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program
  ( ProgramResult (..), compileProgram, compileProgramSourceOver, programDependencies, programIntegerKinds
  , rootCompileResult )
import Pudu.Derive.Expand (expansionText)
import Pudu.Diagnostic (diagnosticCodeText, diagnosticCode, diagnosticMessage, hasErrors)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Render (renderValue)
import Pudu.Source (SourceName (..), newSource)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

deriveLibraryProperties :: [(String, IO Property)]
deriveLibraryProperties =
  [ ("derived Eq, Hash and Ord agree with their laws over records, sums, generics and recursion", runs "StdOrder"
      "\"TFTFTF|FT|TFTFTF|TFT\"")
  , ("derived Show renders names and fields in declaration order", runs "StdShow"
      "\"Point{x: 1, label: \\\"a\\\"} Box{held: Some(Point{x: 1, label: \\\"a\\\"})} Dot Circle(1.5) Rect{w: 2, h: 3} Node([Leaf, Node([])])\"")
  , ("derived JSON round-trips with renames, skips, defaults and located refusals", runs "StdJson" jsonExpected)
  , ("derived rows read named, renamed and nullable columns strictly", runs "StdRow"
      "\"7AdaNone1.5 Err(WrongKind(\\\"id\\\", \\\"Int64\\\"))\"")
  , ("builds construct records and variants, stopping at the first Err", runs "Builders"
      "\"3beezz;bad int;missing missing;dot,pair11,named4label,no variant Nope,\"")
  , ("static calls through a generic parameter reach the selected owner", runs "StaticSelection"
      "\"4;5/6;67qpairleftqpairright\"")
  , ("a static member answers its own owner rather than its first argument's", runs "StaticMember" "\"3abc\"")
  , ("an inferred type argument selects through an imported trait", runs "InferredSelection"
      "\"1\\\"s\\\"\\\"s\\\"[true]{\\\"x\\\":1,\\\"y\\\":2}\"")
  , ("derived Show escapes quote characters as their literals do", runs "ShowChars"
      "\"Marks{quote: '\\\\'', double: '\\\\\\\"', line: '\\\\n', text: \\\"it's\\\"}\"")
  , ("field callbacks answer only what their construction can hold", refuses "BuildEscape"
      [ ("E3001", "a build callback answers its field type F, or Result[F, E] for an E that is not F, not Result[F, F]")
      , ("E3001", "expected F, found Str")
      , ("E3001", "a collect callback answers Option[E] for an E that is not its field type F, not Str")
      ])
  , ("an unmet field bound names the field and the requiring derive", refuses "UnmetStdField"
      [ ("E3092", "Wrapper.Holder.0: Opaque does not implement Eq, which derive Eq requires of every field")
      , ("E3092", "Wrapper.Named.inner: Opaque does not implement Eq, which derive Eq requires of every field")
      , ("E3092", "Record.held: Opaque does not implement Encode, which derive Encode requires of every field")
      ])
  , ("a JSON value is its own JSON, and Json.encode stays the module's function", runs "StdJsonValue"
      "\"{\\\"id\\\":1,\\\"payload\\\":{\\\"k\\\":\\\"v\\\"},\\\"extra\\\":null,\\\"tags\\\":[2,null]} = null\"")
  , ("a payload read from another variant panics naming the variant", panics "SumMismatch" "expected Shape.Circle")
  , ("a hundred types with six derives each check without exhausting coherence", manyRequests)
  , ("expansion prints exactly the implementations a module requested", expands)
  , ("a same-module expansion written in place of its derives runs the same", expandsInPlace)
  ]

jsonExpected :: Text
jsonExpected = Text.concat
  [ "\"{\\\"order_id\\\":1,\\\"lines\\\":[{\\\"sku\\\":\\\"a\\\",\\\"qty\\\":2}],\\\"note\\\":null,\\\"priority\\\":3}\\n"
  , "13truea\\nok\\nat lines[0].qty: expected an integer, found text\\n"
  , "at order_id: expected an integer, found nothing\\n"
  , "at order_id: expected one value, found a repeated key\\n"
  , "{\\\"Dot\\\":[]}={\\\"circle\\\":[4]}={\\\"Rect\\\":{\\\"w\\\":1,\\\"h\\\":2}}=\\n"
  , "expected a variant name, found \\\"Square\\\"\\n"
  , "{\\\"items\\\":[{\\\"sku\\\":\\\"z\\\",\\\"qty\\\":1}],\\\"next\\\":2} ok\\n"
  , "{\\\"Node\\\":[[{\\\"Leaf\\\":[]},{\\\"Node\\\":[[]]}]]} ok\""
  ]

fixture :: String -> FilePath
fixture name = "test-fixtures/derive/" <> name <> ".pudu"

{-| Both evaluators answer the same rendered value with no diagnostics. -}
runs :: String -> Text -> IO Property
runs name expected = do
  program <- compileProgram (fixture name)
  answers <- case rootCompileResult program >>= compileModule of
    Just unit | not (hasErrors (programDiagnostics program)) -> mapM (\mode -> inMode mode $ do
      outcome <- evaluateProgramEntry (programIntegerKinds program) (programDependencies program) "main" unit
      pure (renderValue <$> outcomeValue outcome, map diagnosticMessage (outcomeDiagnostics outcome))) ["tree", "compiled"]
    _ -> pure [(Nothing, map diagnosticMessage (programDiagnostics program))]
  pure $ counterexample name (answers === [(Just expected, []), (Just expected, [])])

{-| The program is refused with these diagnostics first, in source order. -}
refuses :: String -> [(Text, Text)] -> IO Property
refuses name expected = do
  program <- compileProgram (fixture name)
  let found = [(diagnosticCodeText (diagnosticCode found'), diagnosticMessage found') | found' <- programDiagnostics program]
  pure $ counterexample (name <> ": " <> show found) $ conjoin
    [ take (length expected) found === expected
    , property (hasErrors (programDiagnostics program))
    ]

expands :: IO Property
expands = do
  program <- compileProgram (fixture "Expand")
  printed <- expansionText program
  expected <- TextIO.readFile "test-fixtures/derive/Expand.expected"
  pure $ counterexample (Text.unpack printed) (printed === expected)

{-| Both evaluators stop with this message. -}
panics :: String -> Text -> IO Property
panics name expected = do
  program <- compileProgram (fixture name)
  answers <- case rootCompileResult program >>= compileModule of
    Just unit | not (hasErrors (programDiagnostics program)) -> mapM (\mode -> inMode mode $ do
      outcome <- evaluateProgramEntry (programIntegerKinds program) (programDependencies program) "main" unit
      pure (map diagnosticMessage (outcomeDiagnostics outcome))) ["tree", "compiled"]
    _ -> pure [map diagnosticMessage (programDiagnostics program)]
  pure $ counterexample (name <> ": " <> show answers) (answers === [[expected], [expected]])

{-| The derive definitions and requests of `ExpandLocal` removed and its
    printed expansion appended: the text checks, and both evaluators answer
    what the derived program answers. -}
expandsInPlace :: IO Property
expandsInPlace = do
  let path = fixture "ExpandLocal"
  original <- TextIO.readFile path
  printed <- expansionText =<< compileProgram path
  let written = Text.unlines (withoutDerives (Text.lines original)) <> "\n" <> printed
  source <- newSource (SourceName (Text.pack path)) written
  program <- compileProgramSourceOver Map.empty "test-fixtures/derive" source
  expected <- runs "ExpandLocal" "\"Point x=1 y=2; Dot; Circle 3; Rect 4 5\""
  answers <- case rootCompileResult program >>= compileModule of
    Just unit | not (hasErrors (programDiagnostics program)) -> mapM (\mode -> inMode mode $ do
      outcome <- evaluateProgramEntry (programIntegerKinds program) (programDependencies program) "main" unit
      pure (renderValue <$> outcomeValue outcome)) ["tree", "compiled"]
    _ -> pure [Nothing]
  pure $ conjoin
    [ expected
    , counterexample (Text.unpack written <> show (map diagnosticMessage (programDiagnostics program)))
        (answers === replicate 2 (Just "\"Point x=1 y=2; Dot; Circle 3; Rect 4 5\""))
    ]
 where
  withoutDerives lines' = case lines' of
    [] -> []
    line : rest
      | "derive " `Text.isPrefixOf` line -> withoutDerives (drop 1 (dropWhile (/= "}") rest))
      | otherwise -> Text.replace " derives Describe" "" line : withoutDerives rest

{-| Six hundred requests over records and sums that cannot overlap: coherence
    compares heads that could, so a large valid program is never refused. -}
manyRequests :: IO Property
manyRequests = do
  let derives = " derives Eq, Hash, Ord, Show, Json.Encode, Json.Decode"
      declarations index =
        [ "type R" <> index <> " = { a: Int, b: Str, c: Option[Int] }" <> derives
        , "type S" <> index <> " = A" <> index <> " | B" <> index <> "(Int) | C" <> index <> "{r: R" <> index <> "}" <> derives
        ]
      text = Text.unlines $
        [ "module ManyRequests", "import Std.Json", "import Std.Order {Eq, Hash, Ord}", "import Std.Show {Show}" ]
          <> concatMap (declarations . Text.pack . show) [0 :: Int .. 49]
          <> ["export fn main() -> Int { 0 }"]
  source <- newSource (SourceName "test-fixtures/derive/ManyRequests.pudu") text
  program <- compileProgramSourceOver Map.empty "test-fixtures/derive" source
  pure $ counterexample (show (map diagnosticMessage (programDiagnostics program)))
    (map diagnosticMessage (programDiagnostics program) === [])

inMode :: String -> IO a -> IO a
inMode mode action = do
  previous <- lookupEnv "PUDU_EVAL"
  setEnv "PUDU_EVAL" mode
  action `finally` maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL") previous
