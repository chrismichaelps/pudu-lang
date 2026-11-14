{-| @Compiler.Lower.FunctionBody — entry and named-function body shaping.

    The entry chooses its reported carrier and awaits an async body; a named
    function answers a task when async, otherwise its body widened to its
    settled result. Blocks and expressions stay in Compiler.Lower.Body and
    arrive as callbacks, so this module owns only the function boundary. -}
module Pudu.Compiler.Lower.FunctionBody (lowerEntryBodyWith, lowerFunctionBodyWith) where

import Pudu.Compiler.Lower.Call (outputResult)
import Pudu.Compiler.Lower.Control (printValued)
import Pudu.Compiler.Lower.Dynamic (widenBlock)
import Pudu.Compiler.Lower.Lambda (lowerTask)
import Pudu.Compiler.Lower.Signature (functionLevelRefusal)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), LowerContext (..), LowerState (..), bindLocal, halt, refuse, refused )
import Pudu.Compiler.Lower.Types (nativeIntegerKind, treeType)
import Pudu.Core
import Pudu.Frontend.Syntax
  ( Block (..), Expression, Function (..), FunctionBody (..), Located (..), Parameter (..) )
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned))

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type LowerBlock = LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)

{-| The entry carries an admitted integer, Bool, float, Str, Char, tuple, record, sum or unit; a body that never
    returns uses the unit ABI. Integers become the exit status and every other value is
    printed as `renderValue` writes it, the same split `pudu run` makes. -}
lowerEntryBodyWith :: LowerExpression -> LowerBlock -> Located Function -> LowerState -> (LowerState, Maybe CoreFunction)
lowerEntryBodyWith lowerExpression lowerBlock located state
  -- `pudu run` calls the entry with nothing; the first parameter without a
  -- default stops that call at the entry's name.
  | Located _ first : _ <- functionParameters function, Nothing <- parameterDefault first =
      let missing = "missing argument for parameter " <> locatedValue (parameterName first)
          stop = CoreFailText "E7003" (Just "supply the argument or give the parameter a default")
            (CoreExpression atName CoreTextType (CoreTextLiteral missing)) Nothing
       in built state (CoreBlock [] (Just (CoreExpression atName CoreNeverType stop))) CoreUnitType
  | not (null (functionParameters function)) =
      halt atName "default parameter values on the entry function" state
  | otherwise = case functionLevelRefusal function of
      Just (spanValue, construct) -> halt spanValue construct state
      -- An async entry is awaited as soon as it is called, so its body runs
      -- where a plain entry's would. Awaiting unwraps a Result: the success
      -- is the entry's answer, and a failure is reported as the value it is.
      Nothing | functionAsync function, Just block <- functionBlock function
              , Just result@(CoreSumType "Result" [success, failure]) <- lowerDeclaredResult state
              , (after, Just (task, _)) <- lowerTask lowerExpression lowerBlock state (locatedValue (functionName function)) (CoreFunctionType [] result) function ->
        let (withOutcome, outcome) = bindLocal after "" result
            (withValue, held) = bindLocal withOutcome "" success
            (withFailure, failed) = bindLocal withValue "" failure
            at = locatedSpan block
            expression = CoreExpression at
            reading local = expression (coreLocalType local) (CoreReadLocal local)
            printed core = case outputResult withFailure at "print" (expression CoreTextType (CoreShow core)) (CoreSumType "Result" [CoreUnitType, CoreTextType]) of
              (_, Just (written, _)) -> [CoreStatement at (CoreEvaluate written)]
              _ -> []
            status = case success of
              CoreIntegerType kind | nativeIntegerKind kind -> Just success
              _ -> Nothing
            zero = expression success (CoreIntegerLiteral (case success of CoreIntegerType kind -> kind; _ -> PlatformSigned) 0)
            answer = maybe CoreUnitType id status
            good = case status of
              Just _ -> reading held
              Nothing -> expression CoreUnitType (CoreBlockValue (CoreBlock (if success == CoreUnitType then [] else printed (reading held)) Nothing))
            bad = expression answer (CoreBlockValue (CoreBlock (printed (reading outcome)) (zero <$ status)))
            chosen = expression answer (CoreMatch (reading outcome)
              [ CoreArm at (CoreVariantPattern "Ok" [CoreBindPattern held]) Nothing good
              , CoreArm at (CoreVariantPattern "Err" [CoreBindPattern failed]) Nothing bad ])
            wrapped = CoreBlock [CoreStatement at (CoreDeclare outcome (expression result (CoreCallValue task [])))] (Just chosen)
         in built withFailure wrapped answer
      Nothing -> case functionBlock function of
        Just block ->
          let (after, coreBlock, resultType) = lowerBlock state block
           in case maybe resultType id (lowerFunctionResult after) of
                kind@(CoreIntegerType integerKind) | nativeIntegerKind integerKind -> built after coreBlock kind
                kind@(CoreFloatType _) -> built after coreBlock kind
                CoreBoolType -> built after coreBlock CoreBoolType
                CoreTextType -> built after coreBlock CoreTextType
                CoreCharType -> built after coreBlock CoreCharType
                kind@(CoreTupleType _) -> built after coreBlock kind
                kind@(CoreRecordType _ _) -> built after coreBlock kind
                kind@(CoreSumType _ _) -> built after coreBlock kind
                kind@(CoreFunctionType _ _) -> built after coreBlock kind
                kind@(CoreArrayType _) -> built after coreBlock kind
                kind@(CoreHandleType _ _) -> built after coreBlock kind
                kind | treeType kind -> built after coreBlock kind
                kind | kind `elem` [CoreRangeType, CoreBytesType, CoreDecimalType] -> built after coreBlock kind
                CoreNeverType -> built after coreBlock CoreUnitType
                CoreUnitType
                  | printValued coreBlock ->
                      halt
                        (maybe atName locatedSpan (blockResult (locatedValue block)))
                        "a main function that returns Result[(), Str]"
                        after
                  | otherwise -> built after coreBlock CoreUnitType
                other ->
                  halt
                    (maybe atName locatedSpan (blockResult (locatedValue block)))
                    ("a main function that returns " <> coreTypeName other)
                    after
        _ -> refused state
  where
    function = locatedValue located
    atName = locatedSpan (functionName function)
    built after coreBlock resultType =
      ( after
      , Just
          CoreFunction
            { coreFunctionName = locatedValue (functionName function)
            , coreFunctionParameters = []
            , coreFunctionResult = resultType
            , coreFunctionBody = coreBlock
            }
      )

{-| Lower a non-entry function against its settled signature. The checker
    has already proved result agreement; structural lowering preserves the
    signature without inferring another return type. -}
lowerFunctionBodyWith :: LowerExpression -> LowerBlock -> Located Function -> CoreSignature -> LowerState -> (LowerState, Maybe CoreFunction)
lowerFunctionBodyWith lowerExpression lowerBlock located signature state = case functionBlock function of
  -- An async function answers its body as a task; nothing runs until an await.
  Just _ | functionAsync function ->
    case lowerTask lowerExpression lowerBlock state (locatedValue (functionName function)) (signatureResult signature) function of
      (after, Just (task, _)) ->
        ( after
        , Just CoreFunction
            { coreFunctionName = locatedValue (functionName function)
            , coreFunctionParameters = signatureParameters signature
            , coreFunctionResult = signatureResult signature
            , coreFunctionBody = CoreBlock [] (Just task) } )
      (after, Nothing) -> refused after
  Just block ->
    let (after, lowered, _) = lowerBlock state block
        coreBlock = widenBlock (contextTypes (lowerContext after)) (signatureResult signature) lowered
        final
          | printValued coreBlock = refuse (locatedSpan block) "a function body returning Result[(), Str]" after
          | otherwise = after
     in ( final
        , Just
            CoreFunction
              { coreFunctionName = locatedValue (functionName function)
              , coreFunctionParameters = signatureParameters signature
              , coreFunctionResult = signatureResult signature
              , coreFunctionBody = coreBlock
              }
        )
  _ -> refused state
  where
    function = locatedValue located

functionBlock :: Function -> Maybe (Located Block)
functionBlock function = case functionBody function of
  Just (Located _ (BlockBody block)) -> Just block
  Just (Located at (ExpressionBody expression)) ->
    Just (Located at (Block [] (Just expression)))
  Nothing -> Nothing
