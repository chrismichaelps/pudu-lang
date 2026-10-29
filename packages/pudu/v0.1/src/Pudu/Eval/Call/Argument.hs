{-| @Pudu.Eval.Call.Argument.Module — what a call's arguments and receiver lend -}
module Pudu.Eval.Call.Argument
  ( argumentOf
  , argumentPlace
  , bindArguments
  , chosenByElement
  , receiverOf
  ) where

import Data.Text (Text)
import Pudu.Eval.Call.Needs (CallNeeds (..))
import Pudu.Eval.Env (Evaluator, abortAt, withFrame)
import Pudu.Eval.Place (Place, placeOf, plainPlace, readPlace)
import Pudu.Eval.Value (Value)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Expression (..), Parameter (..))
import Pudu.Source (Span)

{-| An argument's value, and the place it was lent from when the argument is
    `&mut place` or names a binding that may itself be an exclusive reference
    being lent on. Which of those a call hands back to is decided by the
    parameters of the function it reaches. -}
argumentOf :: CallNeeds -> Located Expression -> Evaluator (Maybe Place, Value)
argumentOf needs argument = case locatedValue argument of
  UnaryExpression "&mut" operand -> lentFrom needs operand
  _ -> do
    value <- callEvaluate needs argument
    pure (argumentPlace argument, value)

{-| The place an argument other than `&mut place` lends on: a single name, which
    may itself hold an exclusive reference. -}
argumentPlace :: Located Expression -> Maybe Place
argumentPlace argument = case locatedValue argument of
  NameExpression names | length names == 1 -> plainPlace argument
  _ -> Nothing

{-| A receiver chosen by an element is read through its place, so the index is
    evaluated once whether or not the method turns out to change the receiver. -}
receiverOf :: CallNeeds -> Located Expression -> Evaluator (Maybe Place, Value)
receiverOf needs target
  | chosenByElement (locatedValue target) = lentFrom needs target
  | otherwise = do
      value <- callEvaluate needs target
      pure (plainPlace target, value)

{-| Whether a receiver is reached through an element, and so read through its
    place rather than evaluated as an expression. -}
chosenByElement :: Expression -> Bool
chosenByElement expression = case expression of
  IndexExpression _ _ -> True
  MemberExpression inner _ -> chosenByElement (locatedValue inner)
  UnaryExpression "*" operand -> chosenByElement (locatedValue operand)
  _ -> False

lentFrom :: CallNeeds -> Located Expression -> Evaluator (Maybe Place, Value)
lentFrom needs operand = do
  found <- placeOf (callEvaluate needs) operand
  case found of
    Just place -> do
      value <- readPlace place
      pure (Just place, value)
    Nothing -> do
      value <- callEvaluate needs operand
      pure (Nothing, value)

{-| Supplied arguments bind left to right; a parameter with no argument uses its
    default, evaluated in the environment the earlier parameters already
    extended. -}
bindArguments :: CallNeeds -> [Located Parameter] -> [Value] -> Maybe Span -> Evaluator [(Text, Value)]
bindArguments needs parameters arguments callSpan = go parameters arguments []
 where
  go [] [] collected = pure (reverse collected)
  go [] (_ : _) collected =
    abortAt callSpan "E7003" "too many arguments in call"
      (Just "pass one argument per declared parameter") >> pure (reverse collected)
  go (Located _ parameter : rest) supplied collected = case supplied of
    value : remaining ->
      go rest remaining ((locatedValue (parameterName parameter), value) : collected)
    [] -> case parameterDefault parameter of
      Just expression -> do
        value <- withFrame (reverse collected) (callEvaluate needs expression)
        go rest [] ((locatedValue (parameterName parameter), value) : collected)
      Nothing -> do
        _ <-
          abortAt callSpan "E7003"
            ("missing argument for parameter " <> locatedValue (parameterName parameter))
            (Just "supply the argument or give the parameter a default")
        pure (reverse collected)
