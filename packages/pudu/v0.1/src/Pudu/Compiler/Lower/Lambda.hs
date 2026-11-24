{-| @Pudu.Compiler.Lower.Lambda — lambdas, functions used as values, and calls
    through a function value. A lambda becomes a lifted function whose first
    parameter is its own closure. -}
module Pudu.Compiler.Lower.Lambda
  ( lowerLambda, lowerLambdaWithInputs, lowerTask, lowerFunctionValue, lowerFunctionValueWithInputs
  , lowerValueCall, specializeCallable, specializeOpenTraversal
  ) where

import Data.List (mapAccumL)
import Data.Maybe (fromMaybe)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Arguments (methodArgumentBlame)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued, printValued)
import Pudu.Compiler.Lower.Default (couldReturnLoanFinals, suppliedArguments, withCallableArity)
import Pudu.Compiler.Lower.Dynamic (joinRuntimeArms, mapRuntimeChoice, preserveRuntimeResult, projectRuntimeValue, runtimeCarriers, runtimeResultType, settledMutableLayout)
import Pudu.Compiler.Lower.Generic (admitCallee, runtimeCallSignature)
import Pudu.Compiler.Lower.Intrinsic (specializeIntrinsicValue)
import Pudu.Compiler.Lower.Loan (Callee (..), Operand (..), closeLoaned, loanedType, lowerLoanedOperands, valueSignature, withLoanedParameters)
import Pudu.Compiler.Lower.MethodValue (openTraversal, registerMethodValue, specializeTraversalMethod)
import Pudu.Compiler.Lower.Signature (taskResultKey, taskSignatureResult)
import Pudu.Compiler.Lower.Scalar (namedFailure)
import Pudu.Compiler.Lower.Sum (registerConstructor)
import Pudu.Compiler.Lower.State
  ( CallableSource (..), CallableTemplate (..), CoreSignature (..), LowerContext (..), LowerState (..), MutableSite (MutableParameterSite)
  , bindLocal, halt, lookupLocal, refused, startFunction )
import Pudu.Compiler.Lower.Types (loanedInputs, nativeValueType, selectedMember, sumVariants, typeFactAt, typeForSpan, withShapesFrom)
import Pudu.Core
import Pudu.Eval.Capture (reachableNames)
import Pudu.Frontend.Syntax (Block, Expression, Function (..), FunctionBody (..), Located (..), Parameter (..))
import Pudu.Source (Span (..), spanSource, unOffset, unSourceName)
import Pudu.Type.Value (Type (FunctionTypeRequiring), requiredCount)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type LowerBlock = LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| The closure copies what the lambda mentions from the enclosing locals,
    when the lambda is evaluated, as the evaluator's capture does. Its body is
    lowered as a function of its own, keyed by the body it was written in, so
    each copy of a generic body gets its own lambda. -}
lowerLambda :: LowerExpression -> LowerBlock -> LowerState -> Span -> Function -> Lowered
lowerLambda lower block = lowerLambdaWithInputs lower block []

lowerLambdaWithInputs :: LowerExpression -> LowerBlock -> [CoreType] -> LowerState -> Span -> Function -> Lowered
lowerLambdaWithInputs lower block supplied state at function = case typeForSpan (contextTypes (lowerContext state)) at of
  Just kind -> liftFunction lower block state at kind "<fn>" True supplied function
  Nothing -> halt at "a lambda without a native function type" state

{-| The task an async body is until it is awaited: a function of nothing
    over the names the body mentions, lifted beside the body it was written
    in and shown under the task's name. -}
lowerTask :: LowerExpression -> LowerBlock -> LowerState -> Text -> CoreType -> Function -> Lowered
lowerTask lower block state name kind function = case functionBody function of
  Just (Located at _) ->
    case liftFunction lower block state at kind ("<task " <> name <> ">") False [] function{functionAsync = False, functionParameters = []} of
      (after, Just (task, made)) ->
        let key = taskResultKey (lowerCurrentKey state) at
            (offered, held) = adopted after at key task
         in (offered, Just (held, made))
      refusal -> refusal
  Nothing -> halt (locatedSpan (functionName function)) "a function without a body" state

{-| A function lifted at a known type. A written lambda may lend `&mut`
    parameters; a task has none. -}
liftFunction :: LowerExpression -> LowerBlock -> LowerState -> Span -> CoreType -> Text -> Bool -> [CoreType] -> Function -> Lowered
liftFunction lower block state at solved display lends supplied function = case solved of
      CoreFunctionType checkedInputs checkedResult
        | length checkedInputs == length (functionParameters function) ->
            let loaned = if lends then maybe [] loanedInputs (typeFactAt (contextTypes (lowerContext state)) at) else []
                flexible = lends || lowerFlexibleResult state
                requested
                  | flexible, length supplied == length checkedInputs = supplied
                  | otherwise = checkedInputs
                key = taskResultKey (lowerCurrentKey state) at
                  <> (if requested == checkedInputs then "" else "$runtime" <> Text.pack (show requested))
                  <> (if lends && flexible && not (null captured) then "$captures" <> Text.pack (show (map coreLocalType captured)) else "")
                inputs = zipWith carry [0 ..] requested
                carry index input
                  | index `elem` loaned =
                      settledMutableLayout (lowerContext state) (MutableParameterSite key index) input
                  | otherwise = input
                checkedOwn = case checkedResult of
                  CoreTupleType (own : _) | not (null loaned) -> own
                  _ -> checkedResult
                ownResult
                  | functionAsync function = taskSignatureResult (lowerContext state) key function checkedResult
                  | flexible = runtimeResultType checkedOwn
                      (Map.findWithDefault Set.empty key (contextRuntimeResults (lowerContext state)))
                  | otherwise = checkedOwn
                result
                  | null loaned = ownResult
                  | otherwise = CoreTupleType (ownResult : [input | (index, input) <- zip [0 ..] inputs, index `elem` loaned])
                kind = CoreFunctionType inputs result
                captured =
                  [ local | name <- Set.toAscList (reachableNames function), Just local <- [lookupLocal state name] ]
                env = CoreLocal 0 "" kind
                parameters =
                  [ CoreParameter (CoreLocal index (locatedValue (parameterName parameter)) input) (locatedSpan (parameterName parameter))
                  | (index, Located _ parameter, input) <- zip3 [1 ..] (functionParameters function) inputs ]
                -- A lambda with `&mut` parameters answers their finals beside
                -- its declared result on every way out.
                activeContext = (lowerContext state)
                  {contextActiveCallables = Set.insert key (contextActiveCallables (lowerContext state))}
                entered = (startFunction state{lowerContext = activeContext} (CoreParameter env at : parameters) (Just ownResult))
                  {lowerCurrentKey = key, lowerDeclaredResult = Nothing, lowerFlexibleResult = flexible}
                (withCaptures, prologue) = foldl' capture (entered, []) (zip [0 ..] captured)
                capture (current, done) (index, local) =
                  let (next, inner) = bindLocal current (coreLocalName local) (coreLocalType local)
                      read' = CoreExpression at kind (CoreReadLocal env)
                   in (next, done <> [CoreStatement at (CoreDeclare inner (CoreExpression at (coreLocalType local) (CoreCapture index read')))])
                (afterLowering, loweredBody) = lowered (withLoanedParameters loaned parameters withCaptures)
                (afterProjection, projected) = case loweredBody of
                  Just coreBlock@CoreBlock{coreBlockResult = Just answer}
                    | flexible ->
                        let (ready, carried) = projectRuntimeValue (contextTypes (lowerContext afterLowering)) afterLowering ownResult answer
                         in (ready, Just (coreBlock{coreBlockResult = Just carried}))
                  _ -> (afterLowering, loweredBody)
                (afterBody, body) = case projected of
                  Just coreBlock | not (null loaned) -> Just <$> closeLoaned afterProjection at coreBlock
                  _ -> (afterProjection, projected)
                lowered current = case functionBody function of
                  -- An async lambda's body is the task it answers.
                  Just _ | functionAsync function -> case lowerTask lower block current "<fn>" result function of
                    (next, Just (core, _)) -> (next, Just (CoreBlock [] (Just core)))
                    (next, Nothing) -> (next, Nothing)
                  Just (Located _ (BlockBody written)) ->
                    let (next, coreBlock, _) = block current written
                     in (next, Just coreBlock)
                  Just (Located _ (ExpressionBody written)) -> case lower current written of
                    (next, Just (core, _)) -> (next, Just (CoreBlock [] (Just core)))
                    (next, Nothing) -> (next, Nothing)
                  Nothing -> (current, Nothing)
                restored updatedContext = state{lowerContext = updatedContext
                  {contextActiveCallables = Set.delete key (contextActiveCallables updatedContext)}}
                context = lowerContext state
                captureReads = [CoreExpression at (coreLocalType local) (CoreReadLocal local) | local <- captured]
                value = CoreExpression at kind (CoreClosure key captureReads)
             in if Set.member key (contextActiveCallables context) || Map.member key (contextClosures context)
                  then (state, Just (value, kind))
                  else case body of
                  Nothing -> refused (restored (lowerContext afterBody))
                  Just coreBlock
                    | printValued coreBlock -> halt at "a lambda returning Result[(), Str]" (restored (lowerContext afterBody))
                    | not flexible, Just answer <- coreBlockResult coreBlock
                    , coreExpressionType answer `notElem` [result, CoreNeverType] ->
                        halt at "a task or lambda whose runtime result differs from its fixed signature" (restored (lowerContext afterBody))
                    | otherwise ->
                        let lifted = CoreFunction key (CoreParameter env at : parameters) result
                              (coreBlock{coreBlockStatements = prologue <> coreBlockStatements coreBlock})
                            info = CoreClosureInfo (map coreLocalType captured) display (siteOf at) False True Nothing
                            observed = lowerObservedReturns afterBody <> foldMap (runtimeCarriers . coreExpressionType) (projected >>= coreBlockResult)
                            bodyContext = lowerContext afterBody
                            settled
                              | flexible, not (observed `Set.isSubsetOf` runtimeCarriers ownResult) =
                                  bodyContext{contextObservedResults = Map.insertWith Set.union key observed (contextObservedResults bodyContext)}
                              | otherwise = bodyContext
                            template = CallableTemplate kind (LiftedCallable (contextTypes context) (contextModule context)
                              (lowerCurrentKey state) at function solved requested captured)
                            finished = registered key lifted info settled
                              { contextObservedCallables = if lends && flexible
                                  then Map.insert key template (contextObservedCallables settled)
                                  else contextObservedCallables settled }
                         in (restored finished, Just (value, kind))
      other -> halt at ("a lambda of type " <> coreTypeName other) state

{-| A task just made, offered to the innermost open scope beside the function
    that joins it: the joiner runs the task and says whether it failed,
    leaving the failure where the scope's function finds it. -}
adopted :: LowerState -> Span -> Text -> CoreExpression -> (LowerState, CoreExpression)
adopted state at key task = case coreExpressionType task of
  kind@(CoreFunctionType [] answered) ->
    let (bound, held) = bindLocal state "" kind
        joinKey = key <> "$join"
        env = CoreLocal 0 "" (CoreFunctionType [] CoreBoolType)
        inner = CoreExpression at kind (CoreCapture 0 (CoreExpression at (CoreFunctionType [] CoreBoolType) (CoreReadLocal env)))
        ran = CoreExpression at answered (CoreCallValue inner [])
        entered = startFunction state [CoreParameter env at] (Just CoreBoolType)
        (joined, answer) = joinResult entered at ran
        body = CoreBlock [] (Just answer)
        lifted = CoreFunction joinKey [CoreParameter env at] CoreBoolType body
        info = CoreClosureInfo [kind] "<fn>" (siteOf at) False True Nothing
        joiner = CoreExpression at (CoreFunctionType [] CoreBoolType) (CoreClosure joinKey [readLocal at held])
        offered = CoreBlock
          [ CoreStatement at (CoreDeclare held task), hostEffect at "scope_adopt" [readLocal at held, joiner] ]
          (Just (readLocal at held))
     in (bound{lowerContext = registered joinKey lifted info (lowerContext joined)}, CoreExpression at kind (CoreBlockValue offered))
  _ -> (state, task)

joinResult :: LowerState -> Span -> CoreExpression -> (LowerState, CoreExpression)
joinResult state at result
  | Just (ready, Just (selected, _)) <- mapRuntimeChoice state at CoreBoolType result
      (\current held -> let (next, answer) = joinResult current at held in (next, Just answer)) = (ready, selected)
  | CoreSumType "Result" native <- coreExpressionType result
  , [_, declared] <- fst (sumCarrierParts native)
  , Just variants <- sumVariants (contextTypes (lowerContext state)) (coreExpressionType result)
  , [failure] <- [kind | variant <- variants, coreVariantName variant == "Err", (_, kind) <- coreVariantFields variant]
  , nativeValueType failure =
      let (bound, problem) = bindLocal state "" failure
          context = lowerContext bound
          remembered
            | failure == declared = bound
            | otherwise = bound{lowerContext = context{contextObservedTaskFailures =
                Map.insertWith Set.union declared (Set.singleton failure) (contextObservedTaskFailures context)}}
          kept = CoreExpression at (CoreTupleType [failure]) (CoreTuple [readLocal at problem])
          failed = CoreExpression at CoreBoolType (CoreBlockValue (CoreBlock [hostEffect at "scope_stash" [kept]] (Just (boolean at True))))
       in (remembered, CoreExpression at CoreBoolType (CoreMatch result
            [ CoreArm at (CoreVariantPattern "Ok" [CoreWildcardPattern]) Nothing (boolean at False)
            , CoreArm at (CoreVariantPattern "Err" [CoreBindPattern problem]) Nothing failed ]))
  | otherwise = (state, CoreExpression at CoreBoolType (CoreBlockValue (CoreBlock
      [CoreStatement at (CoreEvaluate result)] (Just (boolean at False)))))

hostEffect :: Span -> Text -> [CoreExpression] -> CoreStatement
hostEffect at name operands = CoreStatement at (CoreEvaluate (CoreExpression at CoreBoolType (CoreKernel (KernelHost name) [] operands)))

readLocal :: Span -> CoreLocal -> CoreExpression
readLocal at local = CoreExpression at (coreLocalType local) (CoreReadLocal local)

boolean :: Span -> Bool -> CoreExpression
boolean at value = CoreExpression at CoreBoolType (CoreBoolLiteral value)

{-| Named values keep the target's own parameter ABI and call depth. -}
lowerFunctionValue :: LowerState -> Span -> Text -> (Text, Located Function) -> Lowered
lowerFunctionValue = lowerFunctionValueWithInputs []

lowerFunctionValueWithInputs :: [CoreType] -> LowerState -> Span -> Text -> (Text, Located Function) -> Lowered
lowerFunctionValueWithInputs supplied state at key entry = case typeForSpan (contextTypes (lowerContext state)) at of
  Just (CoreFunctionType inputs _) -> case admitCallee state key at entry of
    (admitted, Nothing) -> refused admitted
    (admitted, Just (original, checked)) ->
      let (ready, target, signature) = maybe (admitted, original, checked) id
            (runtimeCallSignature entry admitted original checked supplied)
          parameters = map (coreLocalType . coreParameterLocal) (signatureParameters signature)
          actual = CoreFunctionType (take (length inputs) parameters) (loanedType signature)
       in namedClosure ready at target actual entry signature
  _ -> halt at "a function value without a native function type" state

namedClosure :: LowerState -> Span -> Text -> CoreType -> (Text, Located Function) -> CoreSignature -> Lowered
namedClosure state at target kind entry signature =
  let context = lowerContext state
      function = locatedValue (snd entry)
      name = locatedValue (functionName function)
      identity = "fn " <> fst (Text.breakOn "$runtime" target)
      info = CoreClosureInfo [] name identity False False Nothing
      template = CallableTemplate kind (NamedCallable entry signature (Map.lookup target (contextInstances context)))
      observed = Map.insert target template (contextObservedCallables context)
      next = context
        { contextClosures = Map.insert target info (contextClosures context)
        , contextObservedCallables = observed
        , contextQueue = target : contextQueue context }
   in (state{lowerContext = next}, Just (CoreExpression at kind (CoreClosure target []), kind))

{-| Select a body copy while preserving the environment stored in the value. -}
specializeCallable :: LowerExpression -> LowerBlock -> [CoreType] -> LowerState -> CoreExpression -> Lowered
specializeCallable = specializeAmong (const True)

specializeOpenTraversal :: LowerExpression -> LowerBlock -> [CoreType] -> LowerState -> CoreExpression -> Maybe Lowered
specializeOpenTraversal lower block supplied state target
  | any open (matchingCallables state (coreExpressionType target)) =
      Just (specializeAmong open lower block supplied state target)
  | otherwise = Nothing
 where
  open template = case callableTemplateSource template of
    MethodCallable _ _ _ _ member (Just _) _ fact -> openTraversal (snd (selectedMember member)) fact
    _ -> False

matchingCallables :: LowerState -> CoreType -> Map.Map Text CallableTemplate
matchingCallables state kind = Map.filter ((== kind) . callableTemplateType)
  (Map.union (contextObservedCallables context) (contextKnownCallables context))
 where
  context = lowerContext state

specializeAmong :: (CallableTemplate -> Bool) -> LowerExpression -> LowerBlock -> [CoreType]
  -> LowerState -> CoreExpression -> Lowered
specializeAmong admitted lower block supplied state target
  | Just selected <- mapRuntimeChoice state at kind target specializeHeld = selected
  | CoreFunctionType expected _ <- kind
  , any (uncurry (/=)) (zip expected supplied)
  , all nativeValueType supplied =
      let demanded = state{lowerContext = context{contextNeedsCallableReplay = True}}
          (bound, held) = bindLocal demanded "" kind
          reading = readLocal at held
          (after, arms) = foldl' (copy reading) (bound, []) candidates
       in case reverse arms of
            [] -> halt at "a stored callable without a body for these argument layouts" after
            cases ->
              let invalid = CoreExpression at CoreNeverType (CoreFailText "E7001" Nothing
                    (CoreExpression at CoreTextType (CoreTextLiteral "cannot call a function value with these arguments")) Nothing)
                  selected = joinRuntimeArms at kind reading (cases <> [CoreArm at CoreWildcardPattern Nothing invalid])
                  result = coreExpressionType selected
               in (after, Just (CoreExpression at result (CoreBlockValue
                    (CoreBlock [CoreStatement at (CoreDeclare held target)] (Just selected))), result))
  | otherwise = (state, Just (target, kind))
 where
  at = coreExpressionSpan target
  kind = coreExpressionType target
  context = lowerContext state
  candidates = Map.toAscList (Map.filter admitted (matchingCallables state kind))
  specializeHeld current value = fmap (fmap fst) (specializeAmong admitted lower block supplied current value)
  copy held (current, arms) (key, template) =
    case specializeTarget lower block supplied current at key template held of
      (after, Just result) ->
        let matches = CoreExpression at CoreBoolType (CoreClosureIs key held)
         in (after, CoreArm at CoreWildcardPattern (Just matches) result : arms)
      (after, Nothing) -> (after, arms)

specializeTarget :: LowerExpression -> LowerBlock -> [CoreType] -> LowerState -> Span -> Text
  -> CallableTemplate -> CoreExpression -> (LowerState, Maybe CoreExpression)
specializeTarget lower block supplied state at key template held = case callableTemplateSource template of
  NamedCallable entry signature prior ->
    let context = lowerContext state
        registeredOriginal = state{lowerContext = context
          { contextSignatures = Map.insertWith (\_ known -> known) key (Just signature) (contextSignatures context)
          , contextInstances = maybe (contextInstances context)
              (\found -> Map.insertWith (\_ known -> known) key found (contextInstances context)) prior }}
     in case runtimeCallSignature entry registeredOriginal key signature supplied of
          Just (ready, copy, exact) ->
            let (withOriginal, _) = namedClosure ready at key (callableTemplateType template) entry signature
                inputs = map (coreLocalType . coreParameterLocal) (signatureParameters exact)
                count = case callableTemplateType template of
                  CoreFunctionType old _ -> length old
                  _ -> length inputs
                kind = CoreFunctionType (take count inputs) (loanedType exact)
             in fmap (fmap fst) (namedClosure withOriginal at copy kind entry exact)
          Nothing -> (state, Nothing)
  LiftedCallable types owner parent written function solved originalInputs captures ->
    let context = lowerContext state
        lexical = state
          { lowerScopes = [[(coreLocalName local, local) | local <- captures]]
          , lowerCurrentKey = parent
          , lowerContext = context{contextTypes = withShapesFrom (contextTypes context) types, contextModule = owner} }
        (withOriginal, _) = liftFunction lower block lexical written solved "<fn>" True originalInputs function
        (after, selected) = liftFunction lower block withOriginal written solved "<fn>" True supplied function
        restored = state{lowerContext = (lowerContext after){contextTypes = contextTypes context, contextModule = contextModule context}}
     in case selected of
          Just (value@CoreExpression{coreExpressionShape = CoreClosure copy _}, _) ->
            let values = [CoreExpression at (coreLocalType local) (CoreCapture index held) | (index, local) <- zip [0 ..] captures]
             in (restored, Just (value{coreExpressionSpan = at, coreExpressionShape = CoreClosure copy values}))
          _ -> (restored, Nothing)
  MethodCallable types owner written receiver member bound checked fact
    | CoreFunctionType inputs result <- checked
    , length inputs >= length supplied ->
        let context = lowerContext state
            carried = supplied <> drop (length supplied) inputs
            lexical = state{lowerContext = context
              {contextTypes = withShapesFrom (contextTypes context) types, contextModule = owner}}
            (original, present) = registerMethodValue lower lexical written receiver member key bound checked fact
            name = fst (Text.breakOn "$runtime" key) <> "$runtime" <> Text.pack (show carried)
            (selectedResult, selectedFact) = fromMaybe (result, fact)
              (bound >>= \kind -> specializeTraversalMethod written kind member fact carried)
            (after, exact) = case present of
              Nothing -> (original, Nothing)
              Just _ -> registerMethodValue lower original written receiver member name bound
                (CoreFunctionType carried selectedResult) selectedFact
            restored = state{lowerContext = (lowerContext after)
              {contextTypes = contextTypes context, contextModule = contextModule context}}
            captures = [CoreExpression at kind (CoreCapture 0 held) | Just kind <- [bound]]
         in (restored, (\kind -> CoreExpression at kind (CoreClosure name captures)) <$> exact)
  IntrinsicCallable written name checked ->
    maybe (state, Nothing) (fmap (fmap fst)) (specializeIntrinsicValue state written name checked supplied)
  ConstructorCallable owner label declared
    | CoreFunctionType inputs _ <- callableTemplateType template
    , length inputs == length supplied ->
        fmap (fmap fst) (registerConstructor state at owner label declared supplied)
  _ -> (state, Nothing)

{-| A call through a value holds its target before supplied operands. -}
lowerValueCall :: LowerExpression -> LowerBlock -> LowerState -> Span -> Located Expression -> [Located Expression] -> Lowered
lowerValueCall lower block state at callee arguments
  | loaned@(_ : _) <- maybe [] loanedInputs (typeFactAt (contextTypes (lowerContext state)) (locatedSpan callee))
  , Just (CoreFunctionType inputs (CoreTupleType (result : _))) <- typeForSpan (contextTypes (lowerContext state)) (locatedSpan callee) =
      lowerLoanedOperands lower state at (Through callee (specializeCallable lower block)) (valueSignature at inputs result loaned) defaulted
        indexed
  | otherwise = case lower state callee of
      (after, Nothing) -> refused after
      (after, Just (target, CoreNeverType)) -> (after, Just (target, CoreNeverType))
      (after, Just (target, kind))
        | any couldReturnLoanFinals (runtimeCarriers kind)
        , Just result <- typeForSpan (contextTypes (lowerContext after)) at ->
            lowerLoanedOperands lower after at (Retained target (specializeCallable lower block))
              (valueSignature at [] result []) defaulted indexed
        | otherwise -> case collect after [] arguments of
            (final, Nothing) -> refused final
            (final, Just cores) -> invoke True final target kind cores
 where
  indexed = [(index, Argument, argument) | (index, argument) <- zip [0 ..] arguments]
  -- A value of a function with defaults was formed with the count of supplied
  -- arguments as its last parameter; checking says how many a call must give.
  defaulted = case typeFactAt (contextTypes (lowerContext state)) (locatedSpan callee) of
    Just (FunctionTypeRequiring _ inputs required _) -> requiredCount required < length inputs
    _ -> False
  invoke adaptable final target kind cores
    | any stops cores = (final, Just (stopped (target : cores), CoreNeverType))
    | Just selected <- mapRuntimeChoice final at CoreNeverType target (callHeld adaptable cores) =
        fmap (fmap preserveSelected) selected
    | CoreFunctionType inputs result <- kind =
        withCallableArity (methodArgumentBlame final) at final defaulted target inputs result cores
          (apply adaptable inputs result)
    | uncallable kind =
        namedFailure final at (\names -> "cannot call a " <> mconcat (take 1 names)) (target : cores)
    | otherwise = halt at ("a call through a " <> coreTypeName kind <> " value") final
  callHeld adaptable cores current held = fmap (fmap fst) (invoke adaptable current held (coreExpressionType held) cores)
  preserveSelected (value, _) =
    let checked = typeForSpan (contextTypes (lowerContext state)) at
        carried = maybe value (\expected -> preserveRuntimeResult expected value) checked
     in (carried, coreExpressionType carried)
  apply adaptable inputs result final takesCount target cores =
    let carry current (expected, argument) = projectRuntimeValue (contextTypes (lowerContext current)) current expected argument
        (ready, projected) = mapAccumL carry final (zip inputs cores)
        operands = if takesCount then suppliedArguments at inputs projected else projected
     in if map coreExpressionType operands == inputs
          then called ready target result operands
          else if adaptable && all (nativeValueType . coreExpressionType) cores
            then adapt ready target projected
            else halt at "a call through a function value with incompatible argument layouts" ready
  adapt current target cores =
    let (bound, retained) = mapAccumL hold current (target : cores)
        declarations = [CoreStatement at (CoreDeclare local value) | (local, value) <- zip retained (target : cores)]
     in case map (readLocal at) retained of
          reading : given -> case specializeCallable lower block (map coreExpressionType given) bound reading of
            (ready, Just (selected, kind)) -> case invoke False ready selected kind given of
              (after, Just (called', result)) ->
                (after, Just (CoreExpression at result (CoreBlockValue (CoreBlock declarations (Just called'))), result))
              (after, Nothing) -> refused after
            (ready, Nothing) -> refused ready
          _ -> refused bound
  hold current value = bindLocal current "" (coreExpressionType value)
  uncallable kind = case kind of
    CoreFunctionType{} -> False
    CoreSumType{} -> False
    CoreCallbackType{} -> False
    _ -> nativeValueType kind
  called final target result cores = (final, Just (CoreExpression at result (CoreCallValue target cores), result))
  stops core = coreExpressionType core == CoreNeverType
  stopped cores = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
    [CoreStatement (coreExpressionSpan core) (CoreEvaluate core) | core <- cores] Nothing))
  collect current done [] = (current, Just (reverse done))
  collect current done (argument : rest) = case lower current argument of
    (next, Just (core, _))
      | stops core -> (next, Just (reverse (core : done)))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" next
      | otherwise -> collect next (core : done) rest
    (next, Nothing) -> (next, Nothing)

-- One key, one function: the body a lambda was written in is lowered once
-- per copy, but a key already seen keeps its first lowering.
registered :: Text -> CoreFunction -> CoreClosureInfo -> LowerContext -> LowerContext
registered key lifted info context
  | Map.member key (contextClosures context) = context
  | otherwise = context
      { contextFunctions = lifted : contextFunctions context
      , contextClosures = Map.insert key info (contextClosures context)
      }

siteOf :: Span -> Text
siteOf at = unSourceName (spanSource at) <> ":" <> Text.pack (show (unOffset (spanStart at))) <> "-" <> Text.pack (show (unOffset (spanEnd at)))
