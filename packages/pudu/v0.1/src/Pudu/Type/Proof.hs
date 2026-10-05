{-| @Type.Proof — proves concrete conditional capabilities without body checking. -}
module Pudu.Type.Proof
  ( TraitProof (..), implementsTrait, proveBound, inferBound, deriveRequirements ) where

import Pudu.Comptime.Limits (callDepthLimit, iterationLimit)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Type.Env
  ( Checker, lookupImplementations, resolveVariable, rigidBoundsOf )
import Pudu.Type.Implementation (matchImplementation)
import Pudu.Type.Proof.Match
  ( Evidence, MatchResult (..), beginEvidence, abstractGoal, matchBound, matchRule
  , remainingEvidence, resolveEvidence, resumeEvidence, stepEvidence
  , assumeBound, evidenceRequirements )
import Pudu.Type.Marker (isMarkerTrait, satisfiesMarker)
import Pudu.Type.Value (NominalId, Type (..), TypeVar)

{-| A proof may exhaust shared work; call inference additionally refuses ambiguity. -}
data TraitProof = Proven | Unproved | ProofLimit | ProofAmbiguous
  deriving stock (Eq, Show)

data Demand = Identity !NominalId | Application !Type
  deriving stock (Eq, Show)

data ProofPolicy = ExistingEvidence | Deriving !(Set.Set Text)

implementsTrait :: Type -> NominalId -> Checker Bool
implementsTrait target trait = (== Proven) <$> prove target (Identity trait)

proveBound :: Type -> Type -> Checker TraitProof
proveBound target trait = prove target (Application trait)

{-| Propose only uniquely determined call-bound arguments. Neither successful
    nor failed search writes checker substitutions; the caller commits proposals. -}
inferBound :: Type -> Type -> Checker (TraitProof, [(TypeVar, Type)])
inferBound target bound = do
  (subject, after) <- normalize 0 iterationLimit target
  (required, fuel) <- normalize 0 after bound
  case (subject, required) of
    (Just value, Just demand) ->
      let holes = Map.toList (Map.unionWith max (variablesOf demand) (variablesOf value))
       in if null holes
            then do
              (answer, _) <- decide ExistingEvidence 0 Map.empty (beginEvidence fuel) value (Application demand)
                (\evidence -> pure (Proven, evidence))
              pure (answer, [])
            else infer value demand fuel holes
    _ -> pure (ProofLimit, [])
 where
  infer value demand fuel holes = case abstractGoal (beginEvidence fuel) holes value demand of
    MatchLimit _ -> pure (ProofLimit, [])
    Mismatched _ -> pure (Unproved, [])
    Matched (subject, wanted, mapping) initial -> do
      let required = variablesOf demand
          selected evidence local = resolveEvidence evidence local
          proposal evidence = [(variable, selected evidence local) | (variable, local) <- mapping
            , selected evidence local /= local]
          complete evidence = all (\(variable, local) ->
            (not (Map.member variable required) && selected evidence local == local)
              || Map.null (variablesOf (selected evidence local))) mapping
          finish evidence = pure (if complete evidence then Proven else Unproved, evidence)
          search evidence = decide ExistingEvidence 0 Map.empty evidence subject (Application wanted)
      (answer, found) <- search initial finish
      if answer /= Proven then pure (answer, []) else do
        let chosen = proposal found
            different evidence = pure
              (if complete evidence && proposal evidence /= chosen then Proven else Unproved, evidence)
        (alternative, _) <- search (resumeEvidence initial found) different
        pure $ case alternative of
          Unproved -> (Proven, chosen)
          ProofLimit -> (ProofLimit, [])
          _ -> (ProofAmbiguous, [])

variablesOf :: Type -> Map TypeVar Int
variablesOf value = case value of
  VariableType variable -> Map.singleton variable 0
  NominalType _ arguments -> members arguments
  ReferenceTypeValue _ held -> variablesOf held
  TupleTypeValue held -> members held
  FunctionTypeValue _ inputs result -> members (result : inputs)
  RestrictedType _ held -> variablesOf held
  AppliedType (VariableType variable) arguments ->
    Map.insert variable (length arguments) (members arguments)
  AppliedType head' arguments -> members (head' : arguments)
  _ -> Map.empty
 where
  members = Map.unionsWith max . map variablesOf

prove :: Type -> Demand -> Checker TraitProof
prove target demand = do
  (resolved, after) <- normalize 0 iterationLimit target
  case resolved of
    Nothing -> pure ProofLimit
    Just value -> case demand of
      Identity _ -> begin value demand after
      Application written -> do
        (trait, remaining) <- normalize 0 after written
        maybe (pure ProofLimit) (\bound -> begin value (Application bound) remaining) trait
 where
  begin value bound fuel = fst <$> decide ExistingEvidence 0 Map.empty (beginEvidence fuel) value bound
    (\evidence -> pure (Proven, evidence))

{-| Lift only authorized bare target parameters into conditional premises;
    ordinary capability queries retain the existing evidence-only policy. -}
deriveRequirements :: [Text] -> Type -> Type -> Checker (TraitProof, [(Text, [Type])])
deriveRequirements parameters target bound = do
  (subject, after) <- normalize 0 iterationLimit target
  (required, fuel) <- normalize 0 after bound
  case (subject, required) of
    (Just value, Just wanted) -> do
      (answer, evidence) <- decide (Deriving (Set.fromList parameters)) 0 Map.empty
        (beginEvidence fuel) value (Application wanted) (\held -> pure (Proven, held))
      pure (answer, if answer == Proven then evidenceRequirements evidence else [])
    _ -> pure (ProofLimit, [])

type Trail = Map (Int, NominalId, NominalId) [(Type, Demand)]
type Continuation = Evidence -> Checker (TraitProof, Evidence)

{-| Each successful premise invokes the rest of the proof before choosing its
    candidate. Later failure therefore revisits earlier evidence alternatives. -}
decide :: ProofPolicy -> Int -> Trail -> Evidence -> Type -> Demand -> Continuation -> Checker (TraitProof, Evidence)
decide policy depth visiting initial written wanted continue
  | depth >= callDepthLimit = pure (ProofLimit, initial)
  | otherwise = case stepEvidence initial of
      MatchLimit after -> pure (ProofLimit, after)
      Mismatched after -> pure (Unproved, after)
      Matched () evidence ->
        let target = resolveEvidence evidence written
            demand = resolveDemand evidence wanted
         in case demandedOwner demand of
              Just trait -> case target of
                RigidType name -> rigid evidence demand trait name
                AppliedType (RigidType name) _ -> rigid evidence demand trait name
                NominalType owner _ -> do
                  let key = (typeSize target, owner, trait)
                      same (previous, required) =
                        resolveEvidence evidence previous == target
                          && resolveDemand evidence required == demand
                  if any same (Map.findWithDefault [] key visiting)
                    then pure (Unproved, evidence)
                    else do
                      rules <- lookupImplementations owner trait
                      let active = Map.insertWith (<>) key [(target, demand)] visiting
                      candidates active target demand trait evidence rules
                ErrorType -> pure (Unproved, evidence)
                VariableType _ -> pure (Unproved, evidence)
                _ -> structural trait target evidence
              _ -> pure (Unproved, evidence)
 where
  rigid evidence demand trait name = do
    bounds <- rigidBoundsOf name
    scoped evidence bounds
   where
    scoped available [] = case (policy, resolveEvidence available written, resolveDemand available wanted) of
      (Deriving parameters, RigidType subject, Application required@(NominalType _ _))
        | Set.member subject parameters, Map.null (variablesOf required) ->
          case assumeBound available subject required of
            Matched () after -> continue after
            MatchLimit after -> pure (ProofLimit, after)
            Mismatched after -> pure (Unproved, after)
      _ -> pure (Unproved, available)
    scoped initialBounds (bound : rest) = case stepEvidence initialBounds of
      MatchLimit after -> pure (ProofLimit, after)
      Mismatched after -> pure (Unproved, after)
      Matched () available ->
        let selected = case (demand, bound) of
              (Identity _, NominalType owner _) | owner == trait -> stepEvidence available
              (Application required, _) -> matchBound depth available bound required
              _ -> Mismatched available
         in case selected of
              MatchLimit after -> pure (ProofLimit, after)
              Mismatched after -> scoped (resumeEvidence available after) rest
              Matched () after -> do
                (answer, final) <- continue after
                if answer == Unproved then scoped (resumeEvidence available final) rest
                  else pure (answer, final)
  candidates _ _ _ _ available _ | remainingEvidence available <= 0 = pure (ProofLimit, available)
  candidates active target demand trait available rules = case rules of
    [] -> structural trait target available
    rule : rest -> case stepEvidence available of
      MatchLimit after -> pure (ProofLimit, after)
      Mismatched after -> pure (Unproved, after)
      Matched () charged ->
        let selected = case matchImplementation target (demandedApplication demand) rule of
              Just requirements -> Matched requirements charged
              Nothing -> matchRule depth charged target (demandedApplication demand) rule
         in case selected of
              MatchLimit after -> pure (ProofLimit, after)
              Mismatched after -> candidates active target demand trait (resumeEvidence available after) rest
              Matched requirements after -> do
                (answer, final) <- conditions policy (depth + 1) active after requirements continue
                if answer == Unproved
                  then candidates active target demand trait (resumeEvidence available final) rest
                  else pure (answer, final)
  structural trait target evidence
    | isMarkerTrait trait = do
        admitted <- satisfiesMarker trait target
        if admitted then continue evidence else pure (Unproved, evidence)
    | otherwise = pure (Unproved, evidence)

conditions :: ProofPolicy -> Int -> Trail -> Evidence -> [(Type, Type)] -> Continuation -> Checker (TraitProof, Evidence)
conditions policy depth visiting evidence requirements continue = case requirements of
  [] -> continue evidence
  _ -> case select [] requirements of
    Nothing -> pure (Unproved, evidence)
    Just ((subject, bound), rest) -> decide policy depth visiting evidence subject (Application bound)
      (\after -> conditions policy depth visiting after rest continue)
 where
  select _ [] = Nothing
  select skipped (requirement@(subject, _) : rest) = case resolveEvidence evidence subject of
    VariableType _ -> select (requirement : skipped) rest
    _ -> Just (requirement, reverse skipped <> rest)

resolveDemand :: Evidence -> Demand -> Demand
resolveDemand evidence demand = case demand of
  Identity _ -> demand
  Application written -> Application (resolveEvidence evidence written)

typeSize :: Type -> Int
typeSize value = 1 + case value of
  NominalType _ arguments -> sum (map typeSize arguments)
  ReferenceTypeValue _ held -> typeSize held
  TupleTypeValue members -> sum (map typeSize members)
  FunctionTypeValue _ inputs result -> sum (map typeSize inputs) + typeSize result
  RestrictedType _ held -> typeSize held
  AppliedType head' arguments -> typeSize head' + sum (map typeSize arguments)
  _ -> 0

demandedOwner :: Demand -> Maybe NominalId
demandedOwner demand = case demand of
  Identity owner -> Just owner
  Application (NominalType owner _) -> Just owner
  _ -> Nothing

demandedApplication :: Demand -> Maybe Type
demandedApplication demand = case demand of
  Identity _ -> Nothing
  Application written -> Just written

normalize :: Int -> Int -> Type -> Checker (Maybe Type, Int)
normalize depth remaining written
  | depth >= callDepthLimit || remaining <= 0 = pure (Nothing, remaining)
  | otherwise = case written of
      VariableType variable -> do
        found <- resolveVariable variable
        maybe (pure (Just written, fuel)) (normalize (depth + 1) fuel) found
      NominalType owner arguments -> list arguments (NominalType owner)
      TupleTypeValue members -> list members TupleTypeValue
      ReferenceTypeValue mutable held -> one held (ReferenceTypeValue mutable)
      RestrictedType capabilities held -> one held (RestrictedType capabilities)
      FunctionTypeRequiring async inputs required result -> do
        (held, after) <- normalizeMany (depth + 1) fuel inputs
        case held of
          Nothing -> pure (Nothing, after)
          Just values -> do
            (answer, lastFuel) <- normalize (depth + 1) after result
            pure (FunctionTypeRequiring async values required <$> answer, lastFuel)
      AppliedType head' arguments -> do
        (head'', after) <- normalize (depth + 1) fuel head'
        case head'' of
          Nothing -> pure (Nothing, after)
          Just held -> do
            (values, lastFuel) <- normalizeMany (depth + 1) after arguments
            pure (AppliedType held <$> values, lastFuel)
      _ -> pure (Just written, fuel)
 where
  fuel = remaining - 1
  one held construct = do
    (value, after) <- normalize (depth + 1) fuel held
    pure (construct <$> value, after)
  list members construct = do
    (values, after) <- normalizeMany (depth + 1) fuel members
    pure (construct <$> values, after)

normalizeMany :: Int -> Int -> [Type] -> Checker (Maybe [Type], Int)
normalizeMany depth remaining values = case values of
  [] -> pure (Just [], remaining)
  first : rest -> do
    (value, after) <- normalize depth remaining first
    case value of
      Nothing -> pure (Nothing, after)
      Just held -> do
        (others, final) <- normalizeMany depth after rest
        pure ((held :) <$> others, final)
