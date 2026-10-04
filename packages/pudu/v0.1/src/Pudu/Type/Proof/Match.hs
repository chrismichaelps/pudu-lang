{-| @Type.Proof.Match — isolated evidence inference for conditional implementations. -}
module Pudu.Type.Proof.Match
  ( Evidence, MatchResult (..), beginEvidence, abstractGoal, matchRule, matchBound, remainingEvidence
  , resolveEvidence, resumeEvidence, stepEvidence ) where

import Control.Monad (foldM, unless)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Pudu.Comptime.Limits (callDepthLimit)
import Pudu.Type.Implementation (ImplementationRule (..))
import Pudu.Type.Substitute (substituteRigid)
import Pudu.Type.Value (Type (..), TypeVar (..))

{-| Private substitutions cannot escape a search or alter the caller checker. -}
data Evidence = Evidence
  { evidenceNext :: !Int
  , evidenceFuel :: !Int
  , evidenceVariables :: !(Map TypeVar Int)
  , evidenceBindings :: !(Map TypeVar Type)
  }

data MatchResult a = Matched a !Evidence | Mismatched !Evidence | MatchLimit !Evidence

newtype Matching a = Matching (Evidence -> MatchResult a)

instance Functor Matching where
  fmap transform action = action >>= pure . transform

instance Applicative Matching where
  pure value = Matching (Matched value)
  left <*> right = do
    transform <- left
    value <- right
    pure (transform value)

instance Monad Matching where
  Matching action >>= continue = Matching $ \evidence -> case action evidence of
    Matched value after -> let Matching next = continue value in next after
    Mismatched after -> Mismatched after
    MatchLimit after -> MatchLimit after

beginEvidence :: Int -> Evidence
beginEvidence fuel = Evidence 1 fuel Map.empty Map.empty

remainingEvidence :: Evidence -> Int
remainingEvidence = evidenceFuel

resumeEvidence :: Evidence -> Evidence -> Evidence
resumeEvidence previous attempted = previous
  { evidenceNext = evidenceNext attempted, evidenceFuel = evidenceFuel attempted }

stepEvidence :: Evidence -> MatchResult ()
stepEvidence evidence
  | evidenceFuel evidence <= 0 = MatchLimit evidence
  | otherwise = Matched () evidence{evidenceFuel = evidenceFuel evidence - 1}

step :: Matching ()
step = Matching stepEvidence

current :: Matching Evidence
current = Matching $ \evidence -> Matched evidence evidence

mismatch :: Matching a
mismatch = Matching Mismatched

limit :: Matching a
limit = Matching MatchLimit

fresh :: Int -> Matching Type
fresh arity = do
  step
  Matching $ \evidence ->
    let variable = TypeVar (negate (evidenceNext evidence))
     in Matched (VariableType variable) evidence
          { evidenceNext = evidenceNext evidence + 1
          , evidenceVariables = Map.insert variable arity (evidenceVariables evidence) }

matchRule
  :: Int -> Evidence -> Type -> Maybe Type -> ImplementationRule
  -> MatchResult [(Type, Type)]
matchRule depth evidence target trait rule =
  let Matching action = do
        replacements <- mapM (\(name, arity) -> (name,) <$> fresh arity)
          (implementationParameters rule)
        let replace = substituteRigid replacements
            written = replace (implementationTarget rule)
        case (written, target) of
          (NominalType owner [], NominalType found _) | owner == found -> step
          _ -> unifyAt depth written target
        mapM_ (unifyAt depth (replace (implementationTrait rule))) trait
        pure [(replace subject, replace bound) | (subject, bound) <- implementationRequirements rule]
   in action evidence

matchBound :: Int -> Evidence -> Type -> Type -> MatchResult ()
matchBound depth evidence given wanted =
  let Matching action = unifyAt depth given wanted in action evidence

abstractGoal :: Evidence -> [(TypeVar, Int)] -> Type -> Type -> MatchResult (Type, Type, [(TypeVar, Type)])
abstractGoal evidence variables target wanted =
  let Matching action = do
        replacements <- mapM (\(variable, arity) -> (variable,) <$> fresh arity) variables
        let replace = replaceVariables (Map.fromList replacements)
        pure (replace target, replace wanted, replacements)
   in action evidence

replaceVariables :: Map TypeVar Type -> Type -> Type
replaceVariables replacements value = case value of
  VariableType variable -> Map.findWithDefault value variable replacements
  NominalType owner arguments -> NominalType owner (map replace arguments)
  ReferenceTypeValue mutable held -> ReferenceTypeValue mutable (replace held)
  TupleTypeValue members -> TupleTypeValue (map replace members)
  FunctionTypeRequiring async inputs required result ->
    FunctionTypeRequiring async (map replace inputs) required (replace result)
  RestrictedType capabilities held -> RestrictedType capabilities (replace held)
  AppliedType head' arguments -> AppliedType (replace head') (map replace arguments)
  _ -> value
 where
  replace = replaceVariables replacements

resolveEvidence :: Evidence -> Type -> Type
resolveEvidence evidence original
  | Map.null (evidenceBindings evidence) = original
  | otherwise = case original of
      VariableType variable -> maybe original recurse (Map.lookup variable (evidenceBindings evidence))
      NominalType owner arguments -> NominalType owner (map recurse arguments)
      ReferenceTypeValue mutable held -> ReferenceTypeValue mutable (recurse held)
      TupleTypeValue members -> TupleTypeValue (map recurse members)
      FunctionTypeRequiring async inputs required result ->
        FunctionTypeRequiring async (map recurse inputs) required (recurse result)
      RestrictedType capabilities held -> RestrictedType capabilities (recurse held)
      AppliedType head' arguments -> case recurse head' of
        NominalType owner prefix -> NominalType owner (prefix <> map recurse arguments)
        selected -> AppliedType selected (map recurse arguments)
      _ -> original
 where
  recurse = resolveEvidence evidence

unifyAt :: Int -> Type -> Type -> Matching ()
unifyAt depth written found = do
  if depth >= callDepthLimit then limit else step
  evidence <- current
  let left = resolveEvidence evidence written
      right = resolveEvidence evidence found
      local variable = Map.member variable (evidenceVariables evidence)
      members a b
        | length a /= length b = mismatch
        | otherwise = mapM_ (uncurry (unifyAt (depth + 1))) (zip a b)
  case (left, right) of
    (ErrorType, _) -> mismatch
    (_, ErrorType) -> mismatch
    (VariableType variable, _) | local variable -> bind depth variable right
    (_, VariableType variable) | local variable -> bind depth variable left
    (NominalType owner arguments, NominalType actual values) | owner == actual -> members arguments values
    (ReferenceTypeValue mutable held, ReferenceTypeValue writable value) | mutable == writable ->
      unifyAt (depth + 1) held value
    (TupleTypeValue held, TupleTypeValue values) -> members held values
    (FunctionTypeRequiring async inputs required result,
     FunctionTypeRequiring asynchronous values supplied answer)
      | async == asynchronous && required == supplied ->
          members inputs values >> unifyAt (depth + 1) result answer
    (RestrictedType capabilities held, RestrictedType granted value) | capabilities == granted ->
      unifyAt (depth + 1) held value
    (AppliedType (VariableType variable) arguments, NominalType owner values)
      | Just arity <- Map.lookup variable (evidenceVariables evidence)
      , arity == length arguments && length arguments == length values ->
          bind depth variable (NominalType owner []) >> members arguments values
    (NominalType owner values, AppliedType (VariableType variable) arguments)
      | Just arity <- Map.lookup variable (evidenceVariables evidence)
      , arity == length arguments && length arguments == length values ->
          bind depth variable (NominalType owner []) >> members arguments values
    (AppliedType head' arguments, AppliedType actual values) ->
      unifyAt (depth + 1) head' actual >> members arguments values
    _ -> unless (left == right) mismatch

bind :: Int -> TypeVar -> Type -> Matching ()
bind _ variable (VariableType same) | variable == same = pure ()
bind depth variable value = do
  cyclic <- occurs depth variable value
  if cyclic then mismatch else Matching $ \evidence ->
    Matched () evidence{evidenceBindings = Map.insert variable value (evidenceBindings evidence)}

occurs :: Int -> TypeVar -> Type -> Matching Bool
occurs depth variable original = do
  if depth >= callDepthLimit then limit else step
  evidence <- current
  let value = resolveEvidence evidence original
      anyHeld = foldM (\seen held -> if seen then pure True else occurs (depth + 1) variable held) False
  case value of
    VariableType actual -> pure (variable == actual)
    NominalType _ arguments -> anyHeld arguments
    ReferenceTypeValue _ held -> occurs (depth + 1) variable held
    TupleTypeValue members -> anyHeld members
    FunctionTypeValue _ inputs result -> anyHeld (result : inputs)
    RestrictedType _ held -> occurs (depth + 1) variable held
    AppliedType head' arguments -> anyHeld (head' : arguments)
    _ -> pure False
