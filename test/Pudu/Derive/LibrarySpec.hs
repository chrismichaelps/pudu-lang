{-| @Test.Derive.LibrarySpec — shipped derives, builders and static selection, run. -}
module Pudu.Derive.LibrarySpec (deriveLibraryProperties) where

import Control.Exception (finally)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program
  ( ProgramResult (..), compileProgram, programDependencies, programIntegerKinds, rootCompileResult )
import Pudu.Derive.Expand (expansionText)
import Pudu.Diagnostic (diagnosticCodeText, diagnosticCode, diagnosticMessage, hasErrors)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Render (renderValue)
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
  , ("field callbacks answer only what their construction can hold", refuses "BuildEscape"
      [ ("E3001", "a build callback answers its field type F or Result[F, E]")
      , ("E3001", "expected F, found Str")
      , ("E3001", "a collect callback answers Option[E] for an E that is not its field type")
      ])
  , ("an unmet field bound names the field and the requiring derive", refuses "UnmetStdField"
      [ ("E3092", "Wrapper.Holder.0: Opaque does not implement Eq, which derive Eq requires of every field")
      , ("E3092", "Wrapper.Named.inner: Opaque does not implement Eq, which derive Eq requires of every field")
      , ("E3092", "Record.held: Opaque does not implement Encode, which derive Encode requires of every field")
      ])
  , ("expansion prints exactly the implementations a module requested", expands)
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

inMode :: String -> IO a -> IO a
inMode mode action = do
  previous <- lookupEnv "PUDU_EVAL"
  setEnv "PUDU_EVAL" mode
  action `finally` maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL") previous
