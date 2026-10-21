{-| @Test.Backend.WideFrameSpec — exact wide values through emitted execution frames. -}
module Pudu.Backend.WideFrameSpec (wideFrameProperties) where

import qualified Data.Map.Strict as Map
import Data.Bits ((.&.), (.|.), xor, complement, shiftL, shiftR)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Emit (emitProgram)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Core
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span, SourceName (..), emptySpan, newSource)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

wideFrameProperties :: [(String, IO Property)]
wideFrameProperties = [("native wide frames preserve values, ordering, operations and cleanup", testFrames)]

testFrames :: IO Property
testFrames = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "wide frame checks require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-wide-frames" $ \root -> do
      source <- newSource (SourceName "wide-frame.pudu") "wide overflow\n"
      let at = emptySpan source
          cases = programs at
      outcomes <- traverse (check cc root source) cases
      putStrLn ("[wide frames] executed " <> show (length cases) <> " Core/frame programs")
      pure (conjoin outcomes)
  where
    check cc root source (label, core, expectedStatus, expectedOutput, failure) =
      case lowerFrames core >>= emitProgram "wide-frame-test" [source] of
        Left fault -> pure (counterexample (label <> ": " <> show fault) (False === True))
        Right emitted -> do
          let path = root </> "frames.c"
              binary = root </> "frames"
              narrow = label == "narrow layout"
              layout = if narrow then "_Static_assert(sizeof(pudu_cell) == sizeof(pudu_int), \"narrow cell changed\");\n" else ""
          TextIO.writeFile path (instrument <> emitted <> layout <> trailer)
          (built, output, errors) <- readProcessWithExitCode cc
            ["-std=c11", "-pedantic", "-O2", "-Wall", "-Wextra", "-Werror", path, "-o", binary] ""
          if built /= ExitSuccess || not (null output && null errors)
            then pure (counterexample (label <> ": " <> show built <> output <> errors) (False === True))
            else do
              (status, out, err) <- readProcessWithExitCode binary [] ""
              pure $ counterexample (label <> ": " <> show (status, out, err)) $ conjoin
                [ status === expectedStatus, out === expectedOutput
                , if failure then conjoin
                    [ counterexample "lost overflow code" ("error[E7005]" `Text.isInfixOf` Text.pack err)
                    , counterexample "lost source location" ("wide-frame.pudu:1:1" `Text.isInfixOf` Text.pack err)
                    ] else err === ""
                , counterexample "narrow ABI acquired wide cells" (not narrow || not ("pudu_wide_int wide" `Text.isInfixOf` emitted))
                ]

programs :: Span -> [(String, CoreModule, ExitCode, String, Bool)]
programs at = snapshots <> operators <> small <> failures
  where
    boundary = 2^(127::Int)
    modulus = 2^(128::Int)
    kinds = [SignedKind 128, UnsignedKind 128]
    integer kind n = CoreExpression at (CoreIntegerType kind) (CoreIntegerLiteral kind n)
    readLocal local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
    unit = CoreExpression at CoreUnitType (CoreBlockValue (CoreBlock [] Nothing))
    statement = CoreStatement at
    display value = CoreExpression at CoreTextType (CoreDisplay value)
    printed value = statement (CoreEvaluate (CoreExpression at CoreUnitType (CorePrint (display value))))
    binary result op left right = CoreExpression at result (CoreBinary op left right)
    mainFunction result body = CoreFunction "main" [] result body
    moduleOf functions = CoreModule "Main" "main" functions Map.empty
    status n = if n == 0 then ExitSuccess else ExitFailure (fromInteger (max 1 (min 255 n)))
    snapshots =
      [ let wide = CoreIntegerType kind
            x = CoreLocal 0 "x" wide
            answer = CoreLocal 1 "answer" wide
            p = CoreLocal 0 "value" wide
            marker = CoreLocal 1 "marker" CoreUnitType
            held = CoreFunction "held" [CoreParameter p at, CoreParameter marker at] wide (CoreBlock [] (Just (readLocal p)))
            mutate = CoreExpression at CoreUnitType (CoreBlockValue (CoreBlock [statement (CoreAssign x (integer kind 0))] Nothing))
            call = CoreExpression at wide (CoreCall "held" [readLocal x, mutate])
            body = CoreBlock
              [ statement (CoreDeclare x (integer kind n)), statement (CoreDeclare answer call)
              , printed (readLocal answer), printed (readLocal x), printed (integer PlatformSigned 7), printed unit
              , printed (binary CoreBoolType CoreGreater (readLocal answer) (integer kind 0))
              ] (Just (readLocal answer))
         in (show kind <> " snapshot " <> show n, moduleOf [held, mainFunction wide body], status n,
              show n <> "\n0\n7\n()\n" <> (if n > 0 then "true\n" else "false\n"), False)
      | kind <- kinds
      , n <- if kind == SignedKind 128 then [-boundary,-1,0,1,255,256,boundary-1,boundary]
               else [0,1,255,256,boundary,modulus-1] ]
    operators =
      [ let wide = CoreIntegerType kind
            a = 2^(100::Int)+3
            maxValue = if kind == SignedKind 128 then boundary-1 else modulus-1
            decode n = let bits = n `mod` modulus in if kind == SignedKind 128 && bits >= boundary then bits-modulus else bits
            operation op lhs rhs result = (binary wide op (integer kind lhs) (integer kind rhs), result)
            shift op places result = (binary wide op (integer kind a) (integer PlatformSigned places), result)
            rows = [operation CoreAdd a 3 (a+3), operation CoreSubtract a 3 (a-3)
                   ,operation CoreMultiply a 3 (a*3), operation CoreDivide a 3 (a `quot` 3),operation CoreRemainder a 3 (a `rem` 3)
                   ,operation CoreBitAnd a 3 (a .&. 3),operation CoreBitOr a 4 (a .|. 4),operation CoreBitXor a 3 (xor a 3)
                   ,operation CoreWrapAdd maxValue 1 (decode (maxValue+1)),operation CoreWrapSubtract 0 1 (decode (-1))
                   ,operation CoreWrapMultiply maxValue 2 (decode (maxValue*2))
                   ,operation CoreSaturateAdd maxValue 1 maxValue,operation CoreSaturateSubtract 0 1 (if kind == SignedKind 128 then -1 else 0)
                   ,operation CoreSaturateMultiply maxValue 2 maxValue
                   ,shift CoreShiftLeft 65 (decode (shiftL a 65)),shift CoreShiftRight 65 (shiftR a 65)
                   ,(CoreExpression at wide (CoreComplement (integer kind a)),decode (complement a))]
                   <> [(CoreExpression at wide (CoreNegate (integer kind a)), -a) | kind == SignedKind 128]
            body = CoreBlock (map (printed . fst) rows) (Just (integer kind 0))
         in (show kind <> " operations",moduleOf [mainFunction wide body],ExitSuccess,concatMap ((<> "\n") . show . snd) rows,False)
      | kind <- kinds ]
    literal kind n = moduleOf [mainFunction (CoreIntegerType kind) (CoreBlock [] (Just (integer kind n)))]
    small =
      [ ("wide literal only", literal (UnsignedKind 128) (modulus-1), ExitFailure 255,"",False)
      , ("deferred literal only",literal (SignedKind 128) boundary,ExitFailure 255,"",False)
      , ("wide discarded unit",moduleOf [mainFunction CoreUnitType (CoreBlock [statement (CoreEvaluate (integer (SignedKind 128) boundary))] Nothing)],ExitSuccess,"",False)
      , ("same bits opposite signs",moduleOf [mainFunction CoreUnitType (CoreBlock
          [printed (binary CoreBoolType CoreGreater (integer (SignedKind 128) boundary) (integer (SignedKind 128) (-boundary)))] Nothing)],ExitSuccess,"true\n",False)
      , ("narrow layout",literal PlatformSigned 7,ExitFailure 7,"",False)
      ]
    failures =
      [ let wide = CoreIntegerType kind
            maximumValue = if kind == SignedKind 128 then boundary-1 else modulus-1
            overflow = binary wide CoreAdd (integer kind maximumValue) (integer kind 1)
            crash = CoreFunction "crash" [] wide (CoreBlock [printed (integer PlatformSigned 7)] (Just overflow))
            call = CoreExpression at wide (CoreCall "crash" [])
         in (show kind <> " overflow cleanup",moduleOf [crash,mainFunction wide (CoreBlock [] (Just call))],ExitFailure 1,"7\n",True)
      | kind <- kinds ]

instrument :: Text
instrument = Text.unlines
  [ "#include <stdlib.h>", "#include <stdio.h>"
  , "static size_t test_live = 0;"
  , "static void *test_calloc(size_t count, size_t bytes) {"
  , "  void *answer = calloc(count,bytes); if(answer != NULL) ++test_live; return answer; }"
  , "static void test_free(void *pointer) {"
  , "  if(pointer != NULL) { if(test_live == 0) _Exit(98); --test_live; } free(pointer); }"
  , "static void test_check(void) { if(test_live != 0) { fputs(\"leaked frame\\n\",stderr); _Exit(97); } }"
  , "#define calloc test_calloc", "#define free test_free", "#define main pudu_test_program"
  ]

trailer :: Text
trailer = Text.unlines
  [ "#undef main", "int main(void) {"
  , "  if(atexit(test_check) != 0) abort();", "  return pudu_test_program();", "}" ]
