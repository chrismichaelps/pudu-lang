{-| @Repl.Evaluation — executes checked entry regions against retained values. -}
module Pudu.Repl.Evaluation
  ( declarationUpdateAllowed
  , evaluateEntry
  , retainedTypes
  ) where

import Data.Maybe (maybeToList)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Compiler (CompileResult (..))
import Pudu.Eval (EvalOutcome (..))
import Pudu.Diagnostic (Severity (Error), diagnostic, mkDiagnosticCode)
import Pudu.Eval.Context (EvaluationContext, evaluateInContextAndCommit)
import Pudu.Eval.Env (abortAt)
import Pudu.Eval.Program (evaluateInteractiveBlock)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..), Declaration (..), Function (..), FunctionBody (..), Module (..) )
import Pudu.Source (Span, spanStart, spanEnd, unOffset)
import Pudu.Type (TypeInfo (..))

{-| Exact prior types are required; a fresh inference must not reinterpret a
    value produced by an earlier evaluation under a different type. -}
evaluateEntry
  :: EvaluationContext -> Maybe TypeInfo -> Bool -> Bool -> Bool -> Int -> Int
  -> [(Text, Module)] -> CompileResult -> (EvalOutcome -> IO ())
  -> IO (Maybe EvalOutcome)
evaluateEntry context previous contextCompatible executesLocals reuseDeclarations start width dependencies result publish =
  case compileModule result of
    Nothing -> pure Nothing
    Just parsed -> do
      let position = locatedSpan (moduleName parsed)
          failEntry message = abortAt (Just position) "E7001" message
            (Just "use :reset or :load before changing the retained session context")
          action
            | not contextCompatible = failEntry "declarations or dependencies changed while local values are retained"
            | not (compatible previous (retainedTypes result)) =
                failEntry "this entry changes an earlier retained expression's type"
            | otherwise = case sessionBlock parsed of
                Nothing -> failEntry "the checked interactive entry block is unavailable"
                Just (Located location block) ->
                  let regions = map locatedSpan (blockStatements block)
                        <> map locatedSpan (maybeToList (blockResult block))
                      overlaps region = unOffset (spanEnd region) > start
                        && unOffset (spanStart region) < start + width
                      crossing region = overlaps region && not (within start width region)
                      selected = Block
                        { blockStatements = filter (within start width . locatedSpan) (blockStatements block)
                        , blockResult = case blockResult block of
                            Just expression | within start width (locatedSpan expression) -> Just expression
                            _ -> Nothing
                        }
                   in if executesLocals && (any crossing regions || not (any (within start width) regions))
                        then failEntry "this submission is not an independent statement or expression"
                        else
                          let kinds = if reuseDeclarations
                                then Map.filterWithKey (\spanValue _ -> within start width spanValue)
                                  (compileIntegerKinds result)
                                else compileIntegerKinds result
                           in evaluateInteractiveBlock reuseDeclarations kinds dependencies parsed
                                (Located location selected)
      outcome <- evaluateInContextAndCommit context action publish
      pure $ case outcome of
        Right value -> Just value
        Left _ -> Just (EvalOutcome Nothing (maybeToList $ do
          code <- mkDiagnosticCode "E7001"
          diagnostic code Error position "the interactive evaluation context is closed"))

compatible :: Maybe TypeInfo -> Maybe TypeInfo -> Bool
compatible Nothing _ = True
compatible (Just (TypeInfo previous)) (Just (TypeInfo current)) =
  Map.isSubmapOfBy (==) previous current
compatible _ Nothing = False

{-| Keep only local expression spans, never the enclosing synthetic function
    whose result type and extent legitimately change on every submission. -}
retainedTypes :: CompileResult -> Maybe TypeInfo
retainedTypes result = do
  parsed <- compileModule result
  Located location block <- sessionBlock parsed
  TypeInfo entries <- compileTypes result
  let regions = map locatedSpan (blockStatements block)
        <> map locatedSpan (maybeToList (blockResult block))
      contained (from, to) = any
        (\region -> from >= unOffset (spanStart region) && to <= unOffset (spanEnd region)) regions
      origin = unOffset (spanStart location)
      relative (from, to) = (from - origin, to - origin)
  pure (TypeInfo (Map.mapKeysMonotonic relative
    (Map.filterWithKey (\key _ -> contained key) entries)))

declarationUpdateAllowed :: Int -> Int -> CompileResult -> Bool
declarationUpdateAllowed start width result = case compileModule result of
  Nothing -> False
  Just parsed ->
    let declarations = filter (within start width . locatedSpan) (moduleDeclarations parsed)
        allowed (Located _ declaration) = case declaration of
          FunctionDeclaration _ -> True
          BindingDeclaration {} -> True
          _ -> False
     in not (null declarations) && all allowed declarations

within :: Int -> Int -> Span -> Bool
within start width location =
  unOffset (spanStart location) >= start && unOffset (spanEnd location) <= start + width

sessionBlock :: Module -> Maybe (Located Block)
sessionBlock parsed = case
  [ block
  | Located _ (FunctionDeclaration function) <- moduleDeclarations parsed
  , locatedValue (functionName function) == "__session"
  , Just (Located _ (BlockBody block)) <- [functionBody function]
  ] of
    block : _ -> Just block
    [] -> Nothing
