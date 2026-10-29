{-| @Eval.Call.Evidence — runs the implementation the checker's trait evidence names

    A value carries its owner and nothing else: not the trait a call was
    resolved through, and not the element types of a generic owner. Checking
    knows both, and records them as evidence; this module turns that evidence
    into the method that runs. Every answer is a canonical-key lookup, and a
    miss is `Nothing`, so the caller's own dispatch still stands. -}
module Pudu.Eval.Call.Evidence
  ( evidentCallee
  , evidentMethod
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Call.Path (flattenPath, selectTypes)
import Pudu.Eval.Env (Evaluator, lookupLocal, lookupMethod)
import Pudu.Eval.Loop (firstBound, receiverOwners)
import Pudu.Eval.Value (Closure (..), Value (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Expression (..), TraitEvidence (..))

{-| The method a receiver call runs: the evidenced trait's implementation for
    the witness the caller selected, else for the receiver's own owner. -}
evidentMethod :: TraitEvidence -> Value -> Text -> Evaluator (Maybe Closure)
evidentMethod evidence receiver member = do
  found <- witnessed evidence member
  method <- case found of
    Just closure -> pure (Just closure)
    Nothing -> owned evidence receiver member
  pure (fmap (\closure -> closure{closureSelf = Just receiver}) method)

{-| The method a static or trait-qualified callee runs: `T.member` through the
    witness bound to `T`, or `Trait.member(receiver)` and
    `Module.Trait.member(receiver)` through the receiver's witness or owner.
    A qualifier is the evidence's own parameter or a path ending in its
    trait's name; anything else (`POINT.distance(other)` on a constant) is a
    receiver call, which `evidentMethod` answers. -}
evidentCallee :: TraitEvidence -> Located Expression -> [Value] -> Evaluator (Maybe Value)
evidentCallee evidence (Located _ expression) values = case expression of
  MemberExpression (Located _ target) (Located _ member)
    | Just path@(first : _) <- flattenPath target -> do
        local <- lookupLocal first
        case local of
          Just (TypeWitnessValue _ _)
            | evidenceParameter evidence == Just first -> statically member
          Nothing | namesTrait path -> statically member
          _ -> pure Nothing
  _ -> pure Nothing
 where
  namesTrait path = finalOf path == finalOf (Text.splitOn "." (evidenceTrait evidence))
  finalOf = take 1 . reverse
  statically member = do
    found <- witnessed evidence member
    case (found, values) of
      (Just closure, _) -> pure (Just (FunctionValue closure))
      (Nothing, receiver : _) -> fmap FunctionValue <$> owned evidence receiver member
      (Nothing, []) -> pure Nothing

{-| The implementation for the witness bound to the evidence's parameter, with
    the witness's arguments bound to the implementation's leading parameters.
    Run-time values carry no element types, so these come only from here. -}
witnessed :: TraitEvidence -> Text -> Evaluator (Maybe Closure)
witnessed evidence member = case evidenceParameter evidence of
  Nothing -> pure Nothing
  Just parameter -> do
    local <- lookupLocal parameter
    case local of
      Just (TypeWitnessValue owner arguments) -> do
        found <- lookupMethod (canonicalKey evidence owner member)
        pure $ case found of
          Just (FunctionValue closure) -> Just (selectTypes arguments closure)
          _ -> Nothing
      _ -> pure Nothing

owned :: TraitEvidence -> Value -> Text -> Evaluator (Maybe Closure)
owned evidence receiver member = do
  owners <- receiverOwners receiver
  found <- firstBound (\owner -> lookupMethod (canonicalKey evidence owner member)) owners
  pure $ case found of
    Just (FunctionValue closure) -> Just closure
    _ -> Nothing

canonicalKey :: TraitEvidence -> Text -> Text -> Text
canonicalKey evidence owner member = evidenceTrait evidence <> "." <> owner <> "." <> member
