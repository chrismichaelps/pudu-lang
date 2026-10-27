{-| @Test.Backend.FrameSpec — continuation and operand-lifetime contracts. -}
module Pudu.Backend.FrameSpec (frameProperties) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Pudu.Backend.ControlPrograms (controlSuccessPrograms, controlRefusalPrograms)
import Pudu.Backend.FunctionPrograms (functionSuccessPrograms, functionRefusalPrograms)
import Pudu.Backend.IntegerPrograms (integerSuccessPrograms, integerRefusalPrograms)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), lowerModule)
import Pudu.Compiler.Lower.Types (nativeTypes)
import Pudu.Core
  ( CoreBinaryOperator (..), CoreBlock (..), CoreExpression (..)
  , CoreExpressionShape (..), CoreFunction (..), CoreLocal (..), CoreLoopId (..), CoreModule (..)
  , CoreParameter (..), CoreStatement (..), CoreStatementShape (..), CoreType (..) )
import Pudu.Core.Frame
  ( FrameBlock (..), FrameFault (..), FrameFunction (..), FrameInstruction (..)
  , FrameModule (..), FrameSlot (..), FrameTerminator (..), FrameValue (..)
  , FrameValueShape (..), scalarOperator )
import Pudu.Diagnostic (hasErrors)
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned))
import Pudu.Source (SourceName (..), Span, emptySpan, newSource)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

frameProperties :: [(String, IO Property)]
frameProperties =
  [ ("frame lowering snapshots operands before mutation and calls", testSnapshots)
  , ("frame lowering guards logical calls with explicit branches", testLogical)
  , ("frame lowering stops after abrupt operands", testAbrupt)
  , ("frame lowering retains nested call destinations", testNestedCalls)
  , ("frame lowering resolves condition and break operand transfers", testTransfers)
  , ("frame lowering returns located malformed-input faults", testFaults)
  , ("frame lowering admits checked native corpora with closed targets", testCorpus)
  ]

intType :: CoreType
intType = CoreIntegerType PlatformSigned

integer :: Span -> Integer -> CoreExpression
integer at number = CoreExpression at intType (CoreIntegerLiteral PlatformSigned number)

entry :: CoreBlock -> CoreFunction
entry = CoreFunction "main" [] intType

program :: CoreFunction -> [CoreFunction] -> CoreModule
program mainFunction helpers = CoreModule "Main" "main" (mainFunction : helpers) Map.empty Map.empty

site :: IO Span
site = emptySpan <$> newSource (SourceName "frames.pudu") "frame contracts"

testSnapshots :: IO Property
testSnapshots = do
  at <- site
  let local = CoreLocal 47 "mutable" intType
      readValue = CoreExpression at intType (CoreReadLocal local)
      call = CoreExpression at intType (CoreCall "identity" [integer at 9])
      right = CoreExpression at intType (CoreBlockValue (CoreBlock
        [CoreStatement at (CoreAssign local (integer at 7))] (Just call)))
      sumValue = CoreExpression at intType (CoreBinary CoreAdd readValue right)
      parameter = CoreLocal 81 "argument" intType
      helper = CoreFunction "identity" [CoreParameter parameter at] intType
        (CoreBlock [] (Just (CoreExpression at intType (CoreReadLocal parameter))))
      mainFunction = entry (CoreBlock [CoreStatement at (CoreDeclare local (integer at 1))] (Just sumValue))
  pure $ case lowerFrames (program mainFunction [helper]) of
    Right lowered | mainFrame : _ <- frameModuleFunctions lowered
      , [first, second] <- frameFunctionBlocks mainFrame
      , FrameCall callAt "identity" [_] (Just destination) resume <- frameBlockTerminator first
      , [ FrameStore _ _, FrameStore original _, FrameStore snapshot snapshotValue
        , FrameStore _ _, FrameStore changed _, FrameStore _ _ ] <- frameBlockInstructions first
      , FrameRead copied <- frameValueShape snapshotValue
      , FrameStore _ binaryValue : _ <- frameBlockInstructions second
      , FrameBinary _ lhs rhs <- frameValueShape binaryValue -> conjoin
          [ callAt === at, original === changed, copied === original
          , lhs === snapshot, rhs === destination, resume === frameBlockLabel second
          , counterexample "snapshot reused mutable storage" (frameSlotId snapshot /= frameSlotId original)
          ]
    other -> counterexample (show other) (False === True)

testLogical :: IO Property
testLogical = do
  at <- site
  let boolean value = CoreExpression at CoreBoolType (CoreBoolLiteral value)
      helper = CoreFunction "predicate" [] CoreBoolType (CoreBlock [] (Just (boolean True)))
      expression = CoreExpression at CoreBoolType
        (CoreBinary CoreAnd (boolean False) (CoreExpression at CoreBoolType (CoreCall "predicate" [])))
      mainFunction = CoreFunction "main" [] CoreBoolType (CoreBlock [] (Just expression))
  pure $ case lowerFrames (program mainFunction [helper]) of
    Right lowered | mainFrame : _ <- frameModuleFunctions lowered
      , first : _ <- frameFunctionBlocks mainFrame
      , FrameBranch branchAt _ yes no <- frameBlockTerminator first ->
          let calls = [frameBlockLabel block | block <- frameFunctionBlocks mainFrame
                       , FrameCall _ "predicate" [] _ _ <- [frameBlockTerminator block]]
           in conjoin [branchAt === at, calls === [yes], counterexample "unguarded right operand" (yes /= no)]
    other -> counterexample (show other) (False === True)

testAbrupt :: IO Property
testAbrupt = do
  at <- site
  let early = CoreExpression at CoreNeverType (CoreBlockValue
        (CoreBlock [CoreStatement at (CoreReturn (Just (integer at 3)))] Nothing))
      ignored = CoreExpression at intType (CoreCall "missing" [])
      trapped = CoreExpression at CoreNeverType (CoreOperatorFailure "unreachable" [early, ignored])
  pure $ case lowerFrames (program (entry (CoreBlock [] (Just trapped))) []) of
    Right lowered | [mainFrame] <- frameModuleFunctions lowered
      , [block] <- frameFunctionBlocks mainFrame -> case frameBlockTerminator block of
          FrameReturn (Just actual) (Just _) -> conjoin
            [actual === at, length (frameBlockInstructions block) === 1]
          other -> counterexample (show other) (False === True)
    other -> counterexample (show other) (False === True)

testFaults :: IO Property
testFaults = do
  at <- site
  let missing = CoreExpression at intType (CoreReadLocal (CoreLocal 1 "missing" intType))
      source = program (entry (CoreBlock [] (Just missing))) []
  pure $ conjoin
    [ case lowerFrames source of
        Left failure -> frameFaultSpan failure === Just at
        other -> counterexample (show other) (False === True)
    , case lowerFrames source{coreModuleEntry = "absent"} of
        Left failure -> frameFaultMessage failure === "missing Core entry function"
        other -> counterexample (show other) (False === True)
    , case lowerFrames source{coreModuleFunctions = coreModuleFunctions source <> coreModuleFunctions source} of
        Left failure -> frameFaultMessage failure === "duplicate Core function identities"
        other -> counterexample (show other) (False === True)
    , scalarOperator CoreAnd === Nothing
    , scalarOperator CoreOr === Nothing
    ]

testNestedCalls :: IO Property
testNestedCalls = do
  at <- site
  let call name arguments = CoreExpression at intType (CoreCall name arguments)
      parameter identity = CoreLocal identity "parameter" intType
      first = parameter 1
      second = parameter 2
      helpers =
        [ CoreFunction "one" [] intType (CoreBlock [] (Just (integer at 1)))
        , CoreFunction "two" [] intType (CoreBlock [] (Just (integer at 2)))
        , CoreFunction "pair" [CoreParameter first at, CoreParameter second at] intType
            (CoreBlock [] (Just (CoreExpression at intType (CoreReadLocal first))))
        ]
      mainFunction = entry (CoreBlock [] (Just (call "pair" [call "one" [], call "two" []])))
  pure $ case lowerFrames (program mainFunction helpers) of
    Right lowered | mainFrame : _ <- frameModuleFunctions lowered
      , [a, b, c, d] <- frameFunctionBlocks mainFrame
      , FrameCall _ "one" [] (Just x) resumeA <- frameBlockTerminator a
      , FrameCall _ "two" [] (Just y) resumeB <- frameBlockTerminator b
      , FrameCall _ "pair" arguments (Just result) resumeC <- frameBlockTerminator c -> conjoin
          [ resumeA === frameBlockLabel b, resumeB === frameBlockLabel c, resumeC === frameBlockLabel d
          , arguments === [x, y], frameBlockTerminator d === FrameReturn Nothing (Just result)
          , Set.size (Set.fromList (map frameSlotId [x, y, result])) === 3
          ]
    other -> counterexample (show other) (False === True)

testTransfers :: IO Property
testTransfers = do
  at <- site
  let outer = CoreLoopId 1
      inner = CoreLoopId 2
      condition = CoreExpression at CoreNeverType (CoreBlockValue
        (CoreBlock [CoreStatement at (CoreContinue outer)] Nothing))
      while = CoreExpression at CoreUnitType (CoreWhileValue inner condition (CoreBlock [] Nothing))
      loop = CoreExpression at CoreNeverType (CoreLoopValue outer
        (CoreBlock [CoreStatement at (CoreEvaluate while)] Nothing))
      breaking = CoreExpression at CoreNeverType (CoreBlockValue
        (CoreBlock [CoreStatement at (CoreBreak outer (Just (integer at 9)))] Nothing))
      returning = CoreExpression at intType (CoreLoopValue outer
        (CoreBlock [CoreStatement at (CoreBreak outer (Just breaking))] Nothing))
      checkCondition = case lowerFrames (program (entry (CoreBlock [] (Just loop))) []) of
        Right lowered | [function] <- frameModuleFunctions lowered
          , [start, bodyBlock, testBlock] <- frameFunctionBlocks function
          , FrameJump Nothing bodyLabel <- frameBlockTerminator start
          , FrameJump Nothing testLabel <- frameBlockTerminator bodyBlock -> conjoin
              [ bodyLabel === frameBlockLabel bodyBlock, testLabel === frameBlockLabel testBlock
              , frameBlockTerminator testBlock === FrameJump (Just at) bodyLabel
              ]
        other -> counterexample (show other) (False === True)
      checkBreak = case lowerFrames (program (entry (CoreBlock [] (Just returning))) []) of
        Right lowered | [function] <- frameModuleFunctions lowered
          , [_, bodyBlock, exit] <- frameFunctionBlocks function
          , [FrameStore value literal, FrameStore destination copied] <- frameBlockInstructions bodyBlock
          , FrameIntegerLiteral PlatformSigned number <- frameValueShape literal -> conjoin
              [ number === 9, frameValueShape copied === FrameRead value
              , frameBlockTerminator bodyBlock === FrameJump (Just at) (frameBlockLabel exit)
              , frameBlockTerminator exit === FrameReturn Nothing (Just destination)
              ]
        other -> counterexample (show other) (False === True)
  pure (conjoin [checkCondition, checkBreak])

testCorpus :: IO Property
testCorpus = conjoin <$> traverse check sources
  where
    sources = functionSuccessPrograms <> functionRefusalPrograms <> controlSuccessPrograms <> controlRefusalPrograms
      <> [(name, source) | (name, source, _) <- integerSuccessPrograms] <> integerRefusalPrograms
    check (name, text) = do
      source <- newSource (SourceName "Main.pudu") text
      checked <- runCompile source
      pure $ counterexample name $ case (hasErrors (compileDiagnostics checked), compileModule checked) of
        (False, Just parsed) -> case lowerModule "main" (nativeTypes (compileTypes checked) (compileSchemes checked)) parsed of
          Lowered core -> case lowerFrames core of
            Right lowered -> closedTargets lowered
            Left failure -> counterexample (show failure) (False === True)
          other -> counterexample (show other) (False === True)
        _ -> counterexample (show (compileDiagnostics checked)) (False === True)

closedTargets :: FrameModule -> Property
closedTargets source = conjoin (map check (frameModuleFunctions source))
  where
    check function =
      let blocks = frameFunctionBlocks function
          labels = Set.fromList (map frameBlockLabel blocks)
          targets terminator = case terminator of
            FrameJump _ target -> [target]
            FrameBranch _ _ yes no -> [yes, no]
            FrameCall _ _ _ _ resume -> [resume]
            FrameCallValue _ _ _ _ resume -> [resume]
            FrameReturn _ _ -> []
            FrameOperatorFailure _ _ -> []
            FrameFailText{} -> []
            FrameFailCaller{} -> []
       in counterexample (show function) $ conjoin
            [ counterexample "missing block destination" (all (`Set.member` labels)
                (frameFunctionEntry function : concatMap (targets . frameBlockTerminator) blocks))
            , Set.size labels === length blocks
            ]
