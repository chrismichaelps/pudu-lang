{-| @Compiler.Lower.FunctionBody — entry and named-function body shaping.

    The entry chooses its reported carrier and awaits an async body; a named
    function answers a task when async, otherwise its body widened to its
    settled result. Blocks and expressions stay in Compiler.Lower.Body and
    arrive as callbacks, so this module owns only the function boundary. -}
module Pudu.Compiler.Lower.FunctionBody (lowerEntryBodyWith, lowerFunctionBodyWith) where

import Pudu.Compiler.Lower.Call (outputResult)
import Pudu.Compiler.Lower.Control (printValued)
import Pudu.Compiler.Lower.Dynamic (mapRuntimeChoice, projectRuntimeValue, widenTo)
import Pudu.Compiler.Lower.Lambda (lowerTask)
import Pudu.Compiler.Lower.Signature (functionLevelRefusal)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), LowerContext (..), LowerState (..), bindLocal, halt, refuse, refused )
import Pudu.Compiler.Lower.Types (formedCoreTypeIn, lookupScheme, nativeIntegerKind, nativeValueType, sumVariants, treeType)
import Pudu.Core
import Pudu.Frontend.Syntax
  ( Block (..), Expression, Function (..), FunctionBody (..), Located (..), Parameter (..) )
import Pudu.Type.Value (Scheme (..), Type (FunctionTypeRequiring, RestrictedType))

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type LowerBlock = LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)

{-| The entry carries an admitted integer, Bool, float, Str, Char, tuple, record, sum or unit; a body that never
    returns uses the unit ABI. Integers become the exit status and every other value is
    printed as `renderValue` writes it, the same split `pudu run` makes. -}
lowerEntryBodyWith :: LowerExpression -> LowerBlock -> Located Function -> LowerState -> (LowerState, Maybe CoreFunction)
lowerEntryBodyWith lowerExpression lowerBlock located state
  -- An argument-free invocation stops at the first required entry parameter.
  | Located _ first : _ <- parameters, Nothing <- parameterDefault first =
      missing state first
  | Just (spanValue, construct) <- functionLevelRefusal function = halt spanValue construct state
  | null parameters = entryBody state
  | Just Scheme{schemeType} <- lookupScheme (contextTypes (lowerContext state)) (locatedValue (functionName function))
  , FunctionTypeRequiring _ inputs _ _ <- unrestricted schemeType
  , length inputs == length parameters =
      defaults state (zip parameters inputs)
  | otherwise = halt atName "an entry without a supported solved signature" state
  where
    function = locatedValue located
    parameters = functionParameters function
    atName = locatedSpan (functionName function)
    unrestricted (RestrictedType _ inner) = inner
    unrestricted kind = kind
    missing current parameter =
      let message = "missing argument for parameter " <> locatedValue (parameterName parameter)
          stop = CoreFailText "E7003" (Just "supply the argument or give the parameter a default")
            (CoreExpression atName CoreTextType (CoreTextLiteral message)) Nothing
       in built current (CoreBlock [] (Just (CoreExpression atName CoreNeverType stop))) CoreUnitType
    -- The entry has no ABI arguments. Bind each default before the body or task
    -- captures it, with only earlier parameters visible.
    defaults current [] = entryBody current
    defaults current ((Located _ parameter, input) : rest) = case parameterDefault parameter of
      Nothing -> missing current parameter
      Just written
        | Just expected <- formedCoreTypeIn (contextTypes (lowerContext current)) input
        , nativeValueType expected -> case lowerExpression current written of
            (after, Nothing) -> refused after
            (after, Just lowered) ->
              let (value, kind) = widenTo (contextTypes (lowerContext after)) expected lowered
                  at = locatedSpan written
               in if kind == CoreNeverType
                    then built after (CoreBlock [CoreStatement at (CoreEvaluate value)] Nothing) CoreUnitType
                    else if kind == expected
                      then let (bound, local) = bindLocal after (locatedValue (parameterName parameter)) expected
                               (final, entry) = defaults bound rest
                               prepend found = found
                                 { coreFunctionBody = (coreFunctionBody found)
                                     { coreBlockStatements = CoreStatement at (CoreDeclare local value)
                                         : coreBlockStatements (coreFunctionBody found) }
                                 }
                            in (final, prepend <$> entry)
                      else halt at "a default outside its entry parameter type" after
        | otherwise -> halt (locatedSpan (parameterName parameter)) "an entry parameter without a native representation" current

    entryBody current
      | functionAsync function
      , Just result@(CoreSumType "Result" [success, _]) <- lowerDeclaredResult current =
          case lowerTask lowerExpression lowerBlock current{lowerFlexibleResult = True}
              (locatedValue (functionName function)) (CoreFunctionType [] result) function of
            (after, Just (task, CoreFunctionType [] answered)) ->
              let at = coreExpressionSpan task
                  expression = CoreExpression at
                  status = case success of
                    CoreIntegerType kind | nativeIntegerKind kind -> Just success
                    _ -> Nothing
                  answer = maybe CoreUnitType id status
                  ran = expression answered (CoreCallValue task [])
               in case presentAsync at answer after ran of
                    (ready, Just presented) -> built ready (CoreBlock [] (Just presented)) answer
                    (ready, Nothing) -> refused ready
            (after, Nothing) -> refused after
            (after, Just _) -> halt atName "an async entry without its task result" after
      | otherwise = case functionBlock function of
        Just block ->
          let (after, coreBlock, resultType) = lowerBlock current block
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
                kind@CoreCallbackType{} -> built after coreBlock kind
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
        _ -> refused current

    presentAsync at answer current result
      | Just selected <- mapRuntimeChoice current at answer result (presentAsync at answer) = fmap (fmap fst) selected
      | CoreSumType "Result" _ <- coreExpressionType result
      , Just variants <- sumVariants (contextTypes (lowerContext current)) (coreExpressionType result)
      , [success] <- [held | variant <- variants, coreVariantName variant == "Ok", (_, held) <- coreVariantFields variant] =
          let expression = CoreExpression at
              (withOutcome, outcome) = bindLocal current "" (coreExpressionType result)
              (bound, held) = bindLocal withOutcome "" success
              reading local = expression (coreLocalType local) (CoreReadLocal local)
              zero = case answer of
                CoreIntegerType kind -> Just (expression answer (CoreIntegerLiteral kind 0))
                _ -> Nothing
              printed prior value = case outputResult prior at "print"
                (expression CoreTextType (CoreShow value)) (CoreSumType "Result" [CoreUnitType, CoreTextType]) of
                  (ready, Just (written, _)) ->
                    (ready, expression answer (CoreBlockValue (CoreBlock [CoreStatement at (CoreEvaluate written)] zero)))
                  (ready, Nothing) -> (ready, expression answer (CoreBlockValue (CoreBlock [] zero)))
              (withGood, good)
                | success == answer = (bound, reading held)
                | otherwise = printed bound (reading held)
              (ready, bad) = printed withGood (reading outcome)
              chosen = expression answer (CoreMatch (reading outcome)
                [ CoreArm at (CoreVariantPattern "Ok" [CoreBindPattern held]) Nothing good
                , CoreArm at (CoreVariantPattern "Err" [CoreWildcardPattern]) Nothing bad ])
           in (ready, Just (expression answer (CoreBlockValue (CoreBlock
                [CoreStatement at (CoreDeclare outcome result)] (Just chosen)))))
      | otherwise = halt at "an async entry without a represented Result" current

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
        expected = signatureResult signature
        (projected, coreBlock) = case coreBlockResult lowered of
          Just value ->
            let (ready, carried) = projectRuntimeValue (contextTypes (lowerContext after)) after expected value
             in (ready, lowered{coreBlockResult = Just carried})
          Nothing -> (after, lowered)
        final
          | printValued coreBlock = refuse (locatedSpan block) "a function body returning Result[(), Str]" projected
          | not (lowerFlexibleResult state)
          , Just value <- coreBlockResult coreBlock
          , coreExpressionType value `notElem` [expected, CoreNeverType] =
              refuse (coreExpressionSpan value) "a function body whose runtime result differs from its fixed signature" projected
          | otherwise = projected
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
