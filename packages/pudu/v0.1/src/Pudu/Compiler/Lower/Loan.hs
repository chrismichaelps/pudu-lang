{-| @Pudu.Compiler.Lower.Loan — `&mut` parameters by copy-in/copy-out. A
    loaned parameter is a local holding its place's value. Every way out of
    the function answers the tuple of its result and each loaned parameter's
    final value, read after the result has run, as `runClosureKeeping` reads
    the frame after the body. The call site holds each argument in order,
    resolving a lent place once where its argument stands, then stores each
    final through that place in parameter order, as `storePlace` does. -}
module Pudu.Compiler.Lower.Loan
  ( Callee (..), Operand (..), closeLoaned, loanedReturn, loanedValue, lowerLoanedBody, lowerLoanedCall, lowerLoanedOperands
  , loanedType, valueSignature, withLoanedParameters
  ) where

import Data.List (elemIndex, mapAccumL, sortOn)
import qualified Data.Map.Strict as Map
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Compiler.Lower.Arguments (argumentFailure, argumentFailureWith, methodArgumentBlame)
import Pudu.Compiler.Lower.Control (blockType, expressionIsPrintValued)
import Pudu.Compiler.Lower.Default (callArityFailure, suppliedArguments, withLoanedCallableArity)
import Pudu.Compiler.Lower.Dynamic (hasRuntimeChoice, mapRuntimeChoice, preserveRuntimeResult, projectRuntimeValue, widen)
import Pudu.Compiler.Lower.Generic (runtimeCallSignature)
import Pudu.Compiler.Lower.Place (HeldPlace (..), holdPlace, observeHeldLayout, readHeld, readHeldAtKeys, storeHeld)
import Pudu.Compiler.Lower.State (CoreSignature (..), Instance (..), LowerContext (..), LowerState (..), MutableSite (MutableParameterSite), bindLocal, halt, refused)
import Pudu.Compiler.Lower.Types (nativeValueType)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Function, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type LowerBody = Located Function -> CoreSignature -> LowerState -> (LowerState, Maybe CoreFunction)
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| The body with its trailing result answering the finals too; the
    function's Core result is that tuple's type. -}
lowerLoanedBody :: LowerBody -> LowerBody
lowerLoanedBody lowerBody located signature state = case lowerBody located signature lent of
  (after, Just function) ->
    let (final, body) = closeLoaned after (locatedSpan located) (coreFunctionBody function)
     in (final{lowerLoaned = []}, Just function{coreFunctionResult = loanedType signature, coreFunctionBody = body})
  (after, Nothing) -> (after{lowerLoaned = []}, Nothing)
 where
  lent = withLoanedParameters (signatureLoaned signature) (signatureParameters signature) state

withLoanedParameters :: [Int] -> [CoreParameter] -> LowerState -> LowerState
withLoanedParameters positions parameters state =
  state
    { lowerLoaned = [coreParameterLocal parameter | (index, parameter) <- indexed, index `elem` positions]
    , lowerMutableSites = if lowerFlexibleResult state
        then foldl' register (lowerMutableSites state) indexed
        else lowerMutableSites state }
 where
  indexed = zip [0 ..] parameters
  register known (index, parameter)
    | index `elem` positions =
        let local = coreParameterLocal parameter
         in Map.insert (coreLocalId local) (MutableParameterSite (lowerCurrentKey state) index) known
    | otherwise = known

{-| A body lowered with loans in the state, its trailing result made to
    answer the finals too. -}
closeLoaned :: LowerState -> Span -> CoreBlock -> (LowerState, CoreBlock)
closeLoaned state at body = case coreBlockResult body of
  Just value -> (\answered -> body{coreBlockResult = Just answered}) <$> loanedValue state (coreExpressionSpan value) value
  Nothing
    | blockType (coreBlockStatements body) Nothing == CoreNeverType -> (state, body)
    | otherwise -> (\answered -> body{coreBlockResult = Just answered}) <$> loanedValue state at (unitValue at)

{-| A `return` of the function being lowered. -}
loanedReturn :: LowerState -> Span -> Maybe CoreExpression -> (LowerState, CoreStatementShape)
loanedReturn state at value = case (lowerLoaned state, value) of
  ([], _) -> (state, CoreReturn value)
  (_, Nothing) -> CoreReturn . Just <$> loanedValue state at (unitValue at)
  (_, Just returned) -> CoreReturn . Just <$> loanedValue state at returned

{-| A value leaving the function, held, beside each loaned parameter's final
    value. A value that never arrives leaves nothing to answer. -}
loanedValue :: LowerState -> Span -> CoreExpression -> (LowerState, CoreExpression)
loanedValue state at value
  | null (lowerLoaned state) || coreExpressionType value == CoreNeverType = (state, value)
  | otherwise =
      let (held, local) = bindLocal state "" (coreExpressionType value)
          kind = CoreTupleType (coreExpressionType value : map coreLocalType (lowerLoaned state))
          tuple = CoreExpression at kind (CoreTuple (map (reading at) (local : lowerLoaned state)))
       in (held, CoreExpression at kind (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare local value)] (Just tuple))))

{-| What a loaned call reaches: a function by name or a runtime function value. -}
data Callee
  = Direct !Text
  | DirectMember !Text !CoreExpression !(Maybe HeldPlace)
  | Through !(Located Expression) !([CoreType] -> LowerState -> CoreExpression -> Lowered)
  | Retained !CoreExpression !([CoreType] -> LowerState -> CoreExpression -> Lowered)
  | ForeignCrossing !CoreForeign

{-| The signature a call through a value of a function type reads: its
    formed inputs, its declared result, and its `&mut` positions. -}
valueSignature :: Span -> [CoreType] -> CoreType -> [Int] -> CoreSignature
valueSignature at inputs result loaned =
  CoreSignature [CoreParameter (CoreLocal index "" input) at | (index, input) <- zip [0 ..] inputs] result loaned

{-| How an operand of a loaned call is written: an argument, or the
    receiver of a method call, which lends whatever place it names. -}
data Operand = Argument | Receiver
  deriving stock (Eq)

{-| A call to a function with `&mut` parameters. An argument at a loaned
    position that is `&mut place`, or a local lent on, is read through its
    place and stored back after the call; any other is an ordinary value. -}
lowerLoanedCall :: LowerExpression -> LowerState -> Span -> Text -> CoreSignature -> Bool -> [Located Expression] -> Lowered
lowerLoanedCall lower state at target signature defaulted arguments =
  lowerLoanedOperands lower state at (Direct target) signature defaulted [(index, Argument, argument) | (index, argument) <- zip [0 ..] arguments]

{-| The operands in the order they run, each with its parameter position.
    The call passes them by position and stores the finals in parameter
    order, including a receiver at parameter zero. -}
lowerLoanedOperands :: LowerExpression -> LowerState -> Span -> Callee -> CoreSignature -> Bool -> [(Int, Operand, Located Expression)] -> Lowered
lowerLoanedOperands lower state at callee signature defaulted operands = case callee of
  Through written specialize -> case lower state written of
    (after, Nothing) -> refused after
    (after, Just (target, _)) -> throughValue (locatedSpan written) specialize after target
  Retained target specialize -> throughValue (coreExpressionSpan target) specialize state target
  Direct target -> go (direct target) state [] [] operands
  DirectMember target receiver place ->
    let (ready, local) = bindLocal state "" (coreExpressionType receiver)
        declaration = CoreStatement (coreExpressionSpan receiver) (CoreDeclare local receiver)
     in go (direct target) ready [declaration] [(local, place, 0)] operands
  ForeignCrossing target -> go (\current held -> made current defaulted held (values held) signature (CoreForeignCall target)) state [] [] operands
 where
  types = contextTypes . lowerContext
  loaned = signatureLoaned signature
  parameterTypes = map (coreLocalType . coreParameterLocal) . signatureParameters
  through = case callee of
    Direct{} -> False
    DirectMember{} -> False
    ForeignCrossing{} -> False
    _ -> True

  throughValue targetAt specialize current target
    | kind == CoreNeverType = (current, Just (target, kind))
    | otherwise =
        let (bound, local) = bindLocal current "" kind
            declaration = CoreStatement targetAt (CoreDeclare local target)
            call ready held = indirect specialize ready held (reading targetAt local)
         in go call bound [declaration] [] operands
   where
    kind = coreExpressionType target

  go prepareCall current statements held [] = finish prepareCall current statements (reverse held)
  go prepareCall current statements held ((index, operand, argument) : rest) = case argumentOf current index operand argument of
    (after, Nothing) -> refused after
    (after, Just (declarations, value, kept))
      | expressionIsPrintValued value -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
      | otherwise ->
          let passed = case (kept, lookup index (zip [0 ..] (parameterTypes signature))) of
                (Nothing, Just expected) | not through -> widen (types after) expected value
                _ -> value
              span' = locatedSpan argument
              (bound, local) = bindLocal after "" (coreExpressionType passed)
              declared = declarations <> [CoreStatement span' (CoreDeclare local passed)]
              prelude = statements <> declared
           in if blockType declared Nothing == CoreNeverType
                then stopped bound prelude
                else go prepareCall bound prelude ((local, kept, index) : held) rest

  -- A lent receiver fails at the key that chose it, as reading that element
  -- as a value does; a lent argument fails at its root, as a store does.
  argumentOf current index operand argument
    | index `elem` loaned, Receiver <- operand = lentFrom readHeldAtKeys argument
    | through || index `elem` loaned = case locatedValue argument of
        UnaryExpression "&mut" inner -> lentFrom readHeld inner
        NameExpression (_ :| []) -> lentFrom readHeld argument
        _ -> plain argument
    | otherwise = plain argument
   where
    plain written = case lower current written of
      (after, Just (core, _)) -> (after, Just ([], core, Nothing))
      (after, Nothing) -> (after, Nothing)
    lentFrom reading' written = case holdPlace lower current (locatedSpan written) written of
      Nothing -> plain written
      Just (after, Nothing) -> (after, Nothing)
      Just (after, Just (declarations, found)) ->
        fmap (fmap (\(value, _) -> (declarations, value, Just found))) (reading' after found)

  finish prepareCall current statements held
    | blockType statements Nothing == CoreNeverType = stopped current statements
    | otherwise = case prepareCall current (sortOn (\(_, _, index) -> index) held) of
        (ready, Just (call, kind)) ->
          (ready, Just (CoreExpression at kind (CoreBlockValue (CoreBlock statements (Just call))), kind))
        (ready, Nothing) -> refused ready

  stopped current statements =
    (current, Just (CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock statements Nothing)), CoreNeverType))

  direct _ current held
    | Just failure <- callArityFailure (methodArgumentBlame current) at signature (length held) =
        (current, Just (failure, CoreNeverType))
  direct target current held =
    let context = lowerContext current
        entry = case Map.lookup target (contextInstances context) of
          Just found -> Just (instanceModule found, instanceFunction found)
          Nothing -> lookup target (contextTable context)
        selected = do
          declared <- entry
          runtimeCallSignature declared current target signature [coreLocalType local | (local, _, _) <- held]
        (ready, name, exact) = maybe (current, target, signature) id selected
     in made (queued name ready) defaulted held (values held) exact (CoreCall name)

  indirect specialize current held target
    | Just selected <- mapRuntimeChoice current at CoreNeverType target
        (\ready value -> fmap (fmap fst) (indirect specialize ready held value)) = fmap (fmap preserve) selected
    | CoreFunctionType inputs _ <- coreExpressionType target
    , any hasRuntimeChoice layouts
    , any (not . fits) (zip inputs held) =
        case specialize layouts current target of
          (ready, Just (value, _)) -> invoke ready held value
          (ready, Nothing) -> refused ready
    | otherwise = invoke current held target
   where
    layouts = [coreLocalType local | (local, _, _) <- held]
    fits (expected, (local, _, _)) =
      let (_, value) = projectRuntimeValue (types current) current expected (reading at local)
       in coreExpressionType value == expected

  invoke current held target
    | Just selected <- mapRuntimeChoice current at CoreNeverType target
        (\ready value -> fmap (fmap fst) (invoke ready held value)) = fmap (fmap preserve) selected
    | CoreFunctionType inputs packed <- coreExpressionType target =
        withLoanedCallableArity (methodArgumentBlame current) at current defaulted loaned
          target inputs (signatureResult signature) (values held) (selectedCall held inputs packed)
    | uncallable (coreExpressionType target) =
        let kind = CoreExpression at CoreTextType (CoreRuntimeKind target)
            prefix = CoreExpression at CoreTextType (CoreTextLiteral "cannot call a ")
            message = CoreExpression at CoreTextType (CoreBinary CoreAdd prefix kind)
            failure = argumentFailureWith (methodArgumentBlame current) at "E7001" Nothing message
         in (current, Just (failure, CoreNeverType))
    | otherwise = halt at "a loaned callable without its final layouts" current

  uncallable kind = case kind of
    CoreSumType{} -> False
    CoreCallbackType{} -> False
    _ -> nativeValueType kind

  selectedCall held inputs packed current takesCount selectedLoans target given
    | null selectedLoans =
        made current takesCount held given (valueSignature at inputs packed []) (CoreCallValue target)
    | CoreTupleType (result : _) <- packed
    , let exact = valueSignature at inputs result selectedLoans
    , loanedType exact == packed =
        made current takesCount held given exact (CoreCallValue target)
    | otherwise =
        let failure = argumentFailure (methodArgumentBlame current) at "E7001"
              "cannot call a function value with these arguments"
         in (current, Just (failure, CoreNeverType))

  preserve (value, _) =
    let carried = preserveRuntimeResult (signatureResult signature) value
     in (carried, coreExpressionType carried)
  values held = [reading at local | (local, _, _) <- held]

  made current takesCount held operands' exact call =
    let wanted = parameterTypes exact
        readOperand prior ((_, _, index), value) = case lookup index (zip [0 ..] wanted) of
          Just expected -> projectRuntimeValue (types prior) prior expected value
          Nothing -> (prior, value)
        (ready, given) = mapAccumL readOperand current (zip held operands')
        passed = if takesCount then suppliedArguments at wanted given else given
        payload = loanedType exact
        (bound, answer) = bindLocal ready "" payload
        answered = reading at answer
        called = CoreStatement at (CoreDeclare answer (CoreExpression at payload (call passed)))
        finals = [(found, position, coreLocalType local)
          | (_, Just found, index) <- held, Just position <- [elemIndex index (signatureLoaned exact)]
          , local <- take 1 (drop position (loanedLocals exact))]
        publish prior (found, position, stored) =
          let source = CoreExpression (heldSpan found) stored (CoreTupleIndex (position + 1) answered)
              (after, projected) = projectRuntimeValue (types prior) prior (heldType found) source
           in if coreExpressionType projected == heldType found
                then (after, Just (storeHeld (types after) (heldSpan found) found projected))
                else (observeHeldLayout after found (coreExpressionType projected), Nothing)
        (final, stores) = mapAccumL publish bound finals
        result
          | null (signatureLoaned exact) = answered
          | otherwise = CoreExpression at (signatureResult exact) (CoreTupleIndex 0 answered)
        settle = case callee of
          ForeignCrossing _ -> [CoreStatement at (CoreEvaluate (CoreExpression at CoreUnitType CoreForeignSettle))]
          _ -> []
     in if map coreExpressionType passed /= wanted
          then halt at "a loaned call with incompatible argument layouts" ready
          else case sequence stores of
            Nothing -> halt at "a loaned call with incompatible writeback layouts" final
            Just writes ->
              let whole = CoreBlock ([called] <> writes <> settle) (Just result)
               in (final, Just (CoreExpression at (signatureResult exact) (CoreBlockValue whole), signatureResult exact))

  -- Only a call that is made reaches its callee.
  queued target current = current{lowerContext = (lowerContext current){contextQueue = target : contextQueue (lowerContext current)}}

{-| The Core result of a loaned function: its own, then each final. -}
loanedType :: CoreSignature -> CoreType
loanedType signature = case loanedLocals signature of
  [] -> signatureResult signature
  locals -> CoreTupleType (signatureResult signature : map coreLocalType locals)

loanedLocals :: CoreSignature -> [CoreLocal]
loanedLocals signature =
  [ coreParameterLocal parameter
  | (index, parameter) <- zip [0 ..] (signatureParameters signature), index `elem` signatureLoaned signature ]

reading :: Span -> CoreLocal -> CoreExpression
reading at local = CoreExpression at (coreLocalType local) (CoreReadLocal local)

unitValue :: Span -> CoreExpression
unitValue at = CoreExpression at CoreUnitType (CoreBlockValue (CoreBlock [] Nothing))
