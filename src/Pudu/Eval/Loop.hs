{-| @Eval.Loop — the looping forms, and the protocol a value is iterated by.

    A loop's body is a block and a block holds loops, so what this module needs
    of the evaluator arrives as a record rather than an import. -}
module Pudu.Eval.Loop
  ( LoopNeeds (..)
  , callClosureValue
  , evaluateFor
  , evaluateLoop
  , evaluateWhile
  , firstBound
  , receiverOwner
  , receiverOwners
  , sequenceMethods
  ) where

import Data.Foldable (toList)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Env
  ( effectsAdmitted
  , variantOwner
  , Evaluator (..)
  , abortAt
  , catchUnwind
  , expectBool
  , lookupName
  , unwind
  , Unwind (..)
  , withFrame
  )
import Pudu.Eval.Match (matchPattern)
import Pudu.Eval.Operator (nominalNameOf)
import Pudu.Eval.Value
  ( Closure (..)
  , Value (..)
  , valueKind
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Expression (..)
  , Pattern
  )
import Pudu.Source (Span)

{-| @Eval.Loop.Needs — what a loop needs of the evaluator around it.

    A condition is an expression, a body is a block, and a sequence's `advance`
    is a closure the program supplied. All three reach loops again. -}
data LoopNeeds = LoopNeeds
  { loopEvaluate :: Located Expression -> Evaluator Value
  , loopBlock :: Located Block -> Evaluator Value
  , loopClosure :: Closure -> [Value] -> Maybe Span -> Evaluator Value
  }

evaluateWhile :: LoopNeeds -> Span -> Maybe Text -> Located Expression -> Located Block -> Evaluator Value
evaluateWhile needs spanValue label condition body = loop (0 :: Int)
 where
  loop iterations = do
    stop <- exceededStepLimit iterations
    if stop
      then
        abortAt (Just spanValue) "E7002" "loop exceeded the evaluation step limit"
          (Just "a constant is folded while the compiler runs; restructure the loop")
      else do
        test <- loopEvaluate needs condition
        truth <- expectBool spanValue test
        if not truth
          then pure UnitValue
          else do
            outcome <- catchUnwind (loopBlock needs body)
            case transferFor label outcome of
              Stop _ -> pure UnitValue
              Again -> loop (iterations + 1)
              Escape transfer -> unwind transfer
              Finished -> loop (iterations + 1)

evaluateLoop :: LoopNeeds -> Span -> Maybe Text -> Located Block -> Evaluator Value
evaluateLoop needs spanValue label body = loop (0 :: Int)
 where
  loop iterations = do
    stop <- exceededStepLimit iterations
    if stop
      then
        abortAt (Just spanValue) "E7002" "loop exceeded the evaluation step limit"
          (Just "a constant is folded while the compiler runs; add a break")
      else do
        outcome <- catchUnwind (loopBlock needs body)
        case transferFor label outcome of
          Stop carried -> pure carried
          Again -> loop (iterations + 1)
          Escape transfer -> unwind transfer
          Finished -> loop (iterations + 1)

{-| Iterate a value.

    The shapes the evaluator can enumerate directly — arrays, tuples, strings,
    a variant's payload — are walked as a list. Anything else is asked whether
    it is a sequence: a type carrying `begin` and `advance` produces its items
    one at a time, which is how a user type becomes iterable without the
    evaluator knowing anything about it.

    The protocol passes state rather than mutating it. `begin` answers the
    state to start from and `advance` answers the next item and the state after
    it, so an iterator is an ordinary value in a language whose values are
    ordinary. -}

{-| Iterate a value.

    The shapes the evaluator can enumerate directly — arrays, tuples, strings,
    a variant's payload — are walked as a list. Anything else is asked whether
    it is a sequence: a type carrying `begin` and `advance` produces its items
    one at a time, which is how a user type becomes iterable without the
    evaluator knowing anything about it.

    The protocol passes state rather than mutating it. `begin` answers the
    state to start from and `advance` answers the next item and the state after
    it, so an iterator is an ordinary value in a language whose values are
    ordinary. -}
evaluateFor :: LoopNeeds -> Span -> Maybe Text -> Located Pattern -> Value -> Located Block -> Evaluator Value
evaluateFor needs spanValue label binder iterated body = case elements of
  Just values -> step values
  Nothing -> do
    sequenced <- sequenceMethods iterated
    case sequenced of
      Just (begin, advance) -> do
        start <- callClosureValue needs spanValue begin [iterated]
        walk advance start (0 :: Int)
      {-| Only once nothing implements the protocol does a sum fall back to the
          payload its matched variant carries. The checker decides the binder's
          type in exactly this order, and taking the payload first made the two
          disagree: a program with its own `Sequence` type checked against the
          implementation and then ran against the payload. -}
      Nothing -> case variantElements of
        Just values -> step values
        Nothing ->
          abortAt (Just spanValue) "E7001"
            ("cannot iterate a " <> valueKind iterated)
            ( Just
                ( "implement Std.Iter.Sequence for it, which is begin and advance, "
                    <> "or convert it to an array first"
                )
            )
 where
  {-| Walk a sequence one item at a time, threading the state each `advance`
      answers with. The step limit is the loop's, because a sequence that never
      ends is a loop that never ends. -}
  walk advance state iterations = do
    stop <- exceededStepLimit iterations
    if stop
      then
        abortAt (Just spanValue) "E7002" "loop exceeded the evaluation step limit"
          (Just "a constant is folded while the compiler runs; end the sequence or break")
      else do
        stepped <- callClosureValue needs spanValue advance [iterated, state]
        case stepped of
          VariantValue "None" _ -> pure UnitValue
          VariantValue "Some" [TupleValue [nextState, item]] ->
            case matchPattern binder item of
              Nothing -> walk advance nextState (iterations + 1)
              Just bindings -> do
                outcome <- withFrame bindings (catchUnwind (loopBlock needs body))
                case transferFor label outcome of
                  Stop _ -> pure UnitValue
                  Again -> walk advance nextState (iterations + 1)
                  Escape transfer -> unwind transfer
                  Finished -> walk advance nextState (iterations + 1)
          other ->
            abortAt (Just spanValue) "E7001"
              ("advance must answer Option[(State, Item)], not a " <> valueKind other)
              Nothing

  elements = case iterated of
    TupleValue members -> Just members
    ArrayValue members -> Just (toList members)
    StrValue text -> Just (map CharValue (Text.unpack text))
    _ -> Nothing

  variantElements = case iterated of
    VariantValue _ payload -> Just payload
    _ -> Nothing
  step values = case values of
    [] -> pure UnitValue
    value : rest -> case matchPattern binder value of
      Nothing -> step rest
      Just bindings -> do
        outcome <- withFrame bindings (catchUnwind (loopBlock needs body))
        case transferFor label outcome of
          Stop _ -> pure UnitValue
          Again -> step rest
          Escape transfer -> unwind transfer
          Finished -> step rest

{-| The `begin` and `advance` a value's own type provides, when it provides
    both. A type with only one of them is not a sequence, and saying so here
    keeps the failure at the `for` rather than inside it. -}

{-| Read a loop body's outcome as this loop's own business or someone else's.

    A break or a continue belongs to this loop when it named this loop's label,
    or when it named nothing at all and so meant the innermost — which, from
    inside the body, is this one. Anything else is addressed to a loop further
    out and travels on untouched, which is what makes `break @outer` from a
    nested loop leave the outer one rather than the nearest. -}
transferFor :: Maybe Text -> Either Unwind a -> LoopTransfer
transferFor label outcome = case outcome of
  Right _ -> Finished
  Left transfer -> case transfer of
    BreakUnwind target carried
      | addressed target -> Stop carried
    ContinueUnwind target
      | addressed target -> Again
    other -> Escape other
 where
  addressed target = case target of
    Nothing -> True
    Just name -> label == Just name

{-| Whether a loop that has run this long should be stopped.

    The compiler must terminate; a program need not. A `const` initialiser runs
    while the compiler runs, so a loop that never ends there is a build that
    never ends, and bounding it is what keeps one from happening. A program the
    reader asked to run is bounded by the machine, exactly as it would be in any
    other language — stopping it at a fixed count is not a safety property, it
    is a language that cannot read a file, because a file of any size needs more
    steps than any constant this module could pick.

    The two are told apart by whether effects are admitted, which is already how
    the language distinguishes compile-time evaluation from running. -}

{-| Whether a loop that has run this long should be stopped.

    The compiler must terminate; a program need not. A `const` initialiser runs
    while the compiler runs, so a loop that never ends there is a build that
    never ends, and bounding it is what keeps one from happening. A program the
    reader asked to run is bounded by the machine, exactly as it would be in any
    other language — stopping it at a fixed count is not a safety property, it
    is a language that cannot read a file, because a file of any size needs more
    steps than any constant this module could pick.

    The two are told apart by whether effects are admitted, which is already how
    the language distinguishes compile-time evaluation from running. -}
exceededStepLimit :: Int -> Evaluator Bool
exceededStepLimit iterations
  | iterations <= iterationLimit = pure False
  | otherwise = not <$> effectsAdmitted

iterationLimit :: Int
iterationLimit = 100000

{-| Assignment writes to an existing binding; `&&` and `||` short-circuit; every
    other operator evaluates both operands left to right. -}

{-| The `begin` and `advance` a value's own type provides, when it provides
    both. A type with only one of them is not a sequence, and saying so here
    keeps the failure at the `for` rather than inside it. -}
sequenceMethods :: Value -> Evaluator (Maybe (Value, Value))
sequenceMethods value = receiverOwners value >>= firstBound methodsUnder
 where
  methodsUnder owner = do
    begin <- lookupName (owner <> ".begin")
    advance <- lookupName (owner <> ".advance")
    pure ((,) <$> begin <*> advance)

{-| Apply a method value the evaluator found by name. -}

{-| Apply a method value the evaluator found by name. -}
callClosureValue :: LoopNeeds -> Span -> Value -> [Value] -> Evaluator Value
callClosureValue needs spanValue callee arguments = case callee of
  FunctionValue closure -> loopClosure needs closure arguments (Just spanValue)
  other ->
    abortAt (Just spanValue) "E7001"
      ("a sequence method must be a function, not a " <> valueKind other) Nothing

{-| @Eval.LoopTransfer — what a loop body's outcome means to the loop. -}
data LoopTransfer
  = Stop !Value
  | Again
  | Escape !Unwind
  | Finished

{-| Read a loop body's outcome as this loop's own business or someone else's.

    A break or a continue belongs to this loop when it named this loop's label,
    or when it named nothing at all and so meant the innermost — which, from
    inside the body, is this one. Anything else is addressed to a loop further
    out and travels on untouched, which is what makes `break @outer` from a
    nested loop leave the outer one rather than the nearest. -}

{-| The names a receiver may have its methods written under.

    A value names the variant it is, and an implementation is written for the
    type that declares the variant, so a `Circle` finds `impl Shaped for Round`
    only by asking what `Circle` belongs to. The variant's own name comes first
    because a record type is its own owner and must not be looked past. -}
receiverOwners :: Value -> Evaluator [Text]
receiverOwners value = case receiverOwner value of
  Nothing -> pure []
  Just owner -> do
    declaring <- variantOwner owner
    pure (owner : maybe [] pure declaring)

{-| The first of these names that binds something. -}

{-| The first of these names that binds something. -}
firstBound :: (Text -> Evaluator (Maybe a)) -> [Text] -> Evaluator (Maybe a)
firstBound look names = case names of
  [] -> pure Nothing
  name : rest -> do
    found <- look name
    case found of
      Just value -> pure (Just value)
      Nothing -> firstBound look rest

{-| The nominal name a runtime value carries, which is how a trait-qualified
    call finds the implementation for the receiver it was given. -}

{-| The nominal name a runtime value carries, which is how a trait-qualified
    call finds the implementation for the receiver it was given. -}
receiverOwner :: Value -> Maybe Text
receiverOwner value = case value of
  RecordValue owner _ -> Just owner
  VariantValue owner _ -> Just owner
  _ -> nominalNameOf value

{-| Call a value as a function, whether it is a closure or an array method
    value. This is used by `map`, `filter`, and `reduce` to invoke the
    callback. -}
