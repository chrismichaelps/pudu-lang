{-| @Pudu.Eval.Call.Needs.Module — what a call needs of the evaluator around it -}
module Pudu.Eval.Call.Needs
  ( CallNeeds (..)
  ) where

import Data.Text (Text)
import Pudu.Eval.Env (Evaluator)
import Pudu.Eval.Value (Value)
import Pudu.Frontend.Syntax.Located (Located)
import Pudu.Frontend.Syntax.Tree (Block, Expression, FunctionBody, TraitEvidence)
import Pudu.Source (Span)

{-| @Eval.Call.Needs — what a call needs of the evaluator around it.

    An argument is an expression and a function's body is a block. Both reach
    calls again, which is why they arrive rather than being imported. -}
data CallNeeds = CallNeeds
  { callEvaluate :: Located Expression -> Evaluator Value
  , callBlock :: Located Block -> Evaluator Value
  {-| A function body compiled to closures, for a run that compiles them. -}
  , callCompile :: [Text] -> FunctionBody -> Evaluator (Evaluator Value)
  {-| The trait evidence of a callee, by its span. Compiled code answers it
      once per call site rather than once per call. -}
  , callEvidence :: Span -> Evaluator (Maybe TraitEvidence)
  }
