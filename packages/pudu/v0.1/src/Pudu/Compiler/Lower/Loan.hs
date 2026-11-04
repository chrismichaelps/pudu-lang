{-| @Pudu.Compiler.Lower.Loan — `&mut` parameters by copy-in/copy-out. A
    loaned parameter is a local holding its place's value. Every way out of
    the function answers the tuple of its result and each loaned parameter's
    final value, read after the result has run, as `runClosureKeeping` reads
    the frame after the body. The call site holds each argument in order,
    resolving a lent place once where its argument stands, then stores each
    final through that place in parameter order, as `storePlace` does. -}
module Pudu.Compiler.Lower.Loan (Operand (..), loanedReturn, loanedValue, lowerLoanedBody, lowerLoanedCall, lowerLoanedOperands) where

import Data.List (elemIndex, sortOn)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Compiler.Lower.Control (blockType, expressionIsPrintValued)
import Pudu.Compiler.Lower.Default (suppliedArguments)
import Pudu.Compiler.Lower.Place (HeldPlace (..), holdPlace, readHeld, storeHeld)
import Pudu.Compiler.Lower.State (CoreSignature (..), LowerContext (..), LowerState (..), bindLocal, halt, refused)
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
    let body = coreFunctionBody function
        at = locatedSpan located
        (final, result) = case coreBlockResult body of
          Just value -> Just <$> loanedValue after (coreExpressionSpan value) value
          Nothing
            | blockType (coreBlockStatements body) Nothing == CoreNeverType -> (after, Nothing)
            | otherwise -> Just <$> loanedValue after at (unitValue at)
     in ( final{lowerLoaned = []}
        , Just function{coreFunctionResult = loanedType signature, coreFunctionBody = body{coreBlockResult = result}} )
  (after, Nothing) -> (after{lowerLoaned = []}, Nothing)
 where
  lent = state{lowerLoaned = loanedLocals signature}

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

{-| How an operand of a loaned call is written: an argument, or the
    receiver of a method call, which lends whatever place it names. -}
data Operand = Argument | Receiver
  deriving stock (Eq)

{-| A call to a function with `&mut` parameters. An argument at a loaned
    position that is `&mut place`, or a local lent on, is read through its
    place and stored back after the call; any other is an ordinary value. -}
lowerLoanedCall :: LowerExpression -> LowerState -> Span -> Text -> CoreSignature -> Bool -> [Located Expression] -> Lowered
lowerLoanedCall lower state at target signature defaulted arguments =
  lowerLoanedOperands lower state at target signature defaulted [(index, Argument, argument) | (index, argument) <- zip [0 ..] arguments]

{-| The operands in the order they run, each with its parameter position.
    The call passes them by position and stores the finals in parameter
    order, so a method's receiver, which runs last, is written back first. -}
lowerLoanedOperands :: LowerExpression -> LowerState -> Span -> Text -> CoreSignature -> Bool -> [(Int, Operand, Located Expression)] -> Lowered
lowerLoanedOperands lower state at target signature defaulted = go state [] []
 where
  types = contextTypes . lowerContext
  loaned = signatureLoaned signature
  parameterTypes = map (coreLocalType . coreParameterLocal) (signatureParameters signature)

  go current statements held [] = finish current statements (reverse held)
  go current statements held ((index, operand, argument) : rest) = case argumentOf current index operand argument of
    (after, Nothing) -> refused after
    (after, Just (declarations, value, kept))
      | expressionIsPrintValued value -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
      | Just found <- kept, Just expected <- lookup index (zip [0 ..] parameterTypes)
      , heldType found /= expected -> halt (locatedSpan argument) "lending a place of a different type" after
      | otherwise ->
          let (bound, local) = bindLocal after "" (coreExpressionType value)
              declared = declarations <> [CoreStatement (locatedSpan argument) (CoreDeclare local value)]
           in go bound (statements <> declared) ((local, kept, index) : held) rest

  argumentOf current index operand argument
    | index `elem` loaned, Receiver <- operand = lentFrom argument
    | index `elem` loaned = case locatedValue argument of
        UnaryExpression "&mut" inner -> lentFrom inner
        NameExpression (_ :| []) -> lentFrom argument
        _ -> plain argument
    | otherwise = plain argument
   where
    plain written = case lower current written of
      (after, Just (core, _)) -> (after, Just ([], core, Nothing))
      (after, Nothing) -> (after, Nothing)
    lentFrom written = case holdPlace lower current (locatedSpan written) written of
      Nothing -> plain written
      Just (after, Nothing) -> (after, Nothing)
      Just (after, Just (declarations, found)) -> (after, Just (declarations, readHeld (types after) found, Just found))

  finish current statements held
    | blockType statements Nothing == CoreNeverType =
        (current, Just (CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock statements Nothing)), CoreNeverType))
    | otherwise =
        let given = [reading at local | (local, _, _) <- sortOn (\(_, _, index) -> index) held]
            passed = if defaulted then suppliedArguments at parameterTypes given else given
            kind = loanedType signature
            (bound, answer) = bindLocal (queued current) "" kind
            answered = reading at answer
            called = CoreStatement at (CoreDeclare answer (CoreExpression at kind (CoreCall target passed)))
            stores =
              [ storeHeld (types bound) (heldSpan found) found
                  (CoreExpression (heldSpan found) (heldType found) (CoreTupleIndex (position + 1) answered))
              | (_, Just found, index) <- sortOn (\(_, _, index) -> index) held, Just position <- [elemIndex index loaned] ]
            result = CoreExpression at (signatureResult signature) (CoreTupleIndex 0 answered)
            whole = CoreBlock (statements <> [called] <> stores) (Just result)
         in (bound, Just (CoreExpression at (signatureResult signature) (CoreBlockValue whole), signatureResult signature))

  -- Only a call that is made reaches its callee.
  queued current = current{lowerContext = (lowerContext current){contextQueue = target : contextQueue (lowerContext current)}}

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
