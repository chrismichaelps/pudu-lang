{-| @Test.Derive.RequirementsSpec — conditional premises through shared trait proof. -}
module Pudu.Derive.RequirementsSpec (requirementProperties) where

import qualified Data.Map.Strict as Map
import Pudu.Comptime.Limits (callDepthLimit, iterationLimit)
import Pudu.Type.Env (DeclaredTypes (..), emptyDeclared, evalChecker, withDeclared, withRigidBounds)
import Pudu.Type.Implementation (ImplementationRule (..))
import Pudu.Type.Proof (TraitProof (..), deriveRequirements, proveBound)
import Pudu.Type.Value (Type (..), boolType, integerType)
import Test.QuickCheck (Property, chooseInt, conjoin, forAll, (===))

requirementProperties :: [(String, IO Property)]
requirementProperties =
  [ ("derive requirements lift nested full trait applications", pure nestedRequirements)
  , ("derive requirements roll back premises and retain ordinary proof", pure alternatives)
  , ("derive requirements refuse unauthorized composite and bounded failures", pure refusals)
  ]

boxed :: Type -> Type
boxed value = NominalType "Box" [value]

ready :: Type
ready = NominalType "Ready" [integerType]

leaf :: Type
leaf = RigidType "A"

rule :: [(Type, Type)] -> ImplementationRule
rule = ImplementationRule [("A", 0)] (boxed leaf) ready

nestedRequirements :: Property
nestedRequirements = forAll (chooseInt (0, 80)) $ \depth ->
  let target = foldr (const boxed) leaf [1 .. depth]
      declarations = emptyDeclared{declaredImpls = Map.singleton ("Box", "Ready") [rule [(leaf, ready)]]}
      inferred = evalChecker $ withDeclared declarations >> deriveRequirements ["A"] target ready
      scoped = evalChecker $ withDeclared declarations >>
        withRigidBounds [("A", [ready])] (deriveRequirements ["A"] target ready)
   in conjoin
      [ inferred === (Proven, [("A", [ready])])
      , scoped === (Proven, [])
      ]

alternatives :: Property
alternatives =
  let other = NominalType "Other" [boolType]
      failed = rule [(leaf, ready), (boolType, NominalType "Absent" [])]
      selected = rule [(leaf, other), (leaf, other)]
      declarations = emptyDeclared{declaredImpls = Map.singleton ("Box", "Ready") [failed, selected]}
      (before, inferred, after) = evalChecker $ do
        withDeclared declarations
        initial <- proveBound (boxed leaf) ready
        requirements <- deriveRequirements ["A"] (boxed leaf) ready
        restored <- proveBound (boxed leaf) ready
        pure (initial, requirements, restored)
   in conjoin
      [ before === Unproved
      , inferred === (Proven, [("A", [other])])
      , after === Unproved
      ]

refusals :: Property
refusals =
  let infer rules parameters target bound = evalChecker $ do
        withDeclared emptyDeclared{declaredImpls = Map.singleton ("Box", "Ready") rules}
        deriveRequirements parameters target bound
      circular = rule [(boxed leaf, ready)]
      deep = foldr (const boxed) leaf [1 .. callDepthLimit]
      mismatch = ImplementationRule [] (boxed boolType) ready []
   in conjoin
      [ infer [] [] leaf ready === (Unproved, [])
      , infer [] ["A"] boolType ready === (Unproved, [])
      , infer [] ["A"] ErrorType ready === (Unproved, [])
      , infer [] ["A"] (AppliedType leaf [integerType]) ready === (Unproved, [])
      , infer [circular] ["A"] (boxed leaf) ready === (Unproved, [])
      , infer [rule []] ["A"] deep ready === (ProofLimit, [])
      , infer (replicate iterationLimit mismatch) ["A"] (boxed leaf) ready === (ProofLimit, [])
      ]
