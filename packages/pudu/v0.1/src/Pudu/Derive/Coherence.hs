{-| @Derive.Coherence — canonical request ownership and bounded generated overlap. -}
module Pudu.Derive.Coherence (requestOwnership, generatedCoherence) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Comptime.Limits (iterationLimit)
import Pudu.Derive.Catalogue (Request (..))
import Pudu.Diagnostic
  ( Diagnostic, Related (..), Severity (Error), diagnostic, mkDiagnosticCode, withRelated )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Frontend.Syntax.Tree (Declaration (..), Impl (..), Module (..), TypeParam (..))
import Pudu.Source (Span)
import Pudu.Type.Env (DeclaredTypes)
import Pudu.Type.Formation (formBoundType)
import Pudu.Type.Implementation (ImplementationRule (..))
import Pudu.Type.Proof.Match
  ( MatchResult (..), beginEvidence, overlapRules, remainingEvidence )
import Pudu.Type.Value (NominalId (..), Type (..))

requestOwnership :: Request -> [Diagnostic]
requestOwnership request
  | owned (requestTrait request) || owned (requestTarget request) = []
  | otherwise = finding "E3014" (requestAnchor request)
      "orphan derive request: neither the trait nor target type is declared in this module"
 where
  owned (NominalType identity _) = nominalModule identity == Just (requestModule request)
  owned _ = False

data Head = Head !Span !ImplementationRule

{-| The trait and target constructors a head names, where it names one. Two
    heads can overlap only where both agree; a parameter or other open target
    agrees with every constructor. -}
data Key = Key !(Maybe NominalId) !(Maybe NominalId)

{-| The heads seen so far: those naming both constructors by them, and the
    open ones, which every later head is compared with. -}
data Seen = Seen !(Map (NominalId, NominalId) [Head]) ![Head]

generatedCoherence
  :: Map ModuleName DeclaredTypes -> Map ModuleName Module -> [(Request, Impl)]
  -> Map ModuleName [Diagnostic]
generatedCoherence scopes modules generated =
  inspect iterationLimit Map.empty (foldr remember (Seen Map.empty []) ordinary) generatedHeads
 where
  ordinary =
    [ Head (locatedSpan (implTarget value)) (formed scope value)
    | (owner, unit) <- Map.toAscList modules
    , Just scope <- [Map.lookup owner scopes]
    , Located _ (ImplDeclaration value) <- moduleDeclarations unit
    ]
  generatedHeads =
    [(request, Head (requestAnchor request) (formed scope value))
    | (request, value) <- generated
    , Just scope <- [Map.lookup (requestModule request) scopes]]
  inspect _ errors _ [] = errors
  inspect fuel errors seen ((request, held) : rest) =
    compare' fuel errors (candidates seen held)
   where
    compare' left found [] = inspect left found (remember held seen) rest
    compare' left found (Head otherAt other : more) =
      let Head _ rule = held
       in case overlapRules (beginEvidence left) rule other of
            Mismatched after -> compare' (remainingEvidence after) found more
            Matched () after ->
              let errorsHere = map (withRelated (Related otherAt "overlapping implementation declared here"))
                    (finding "E3015" (requestAnchor request)
                      "derived implementation overlaps an existing canonical implementation head")
               in compare' (remainingEvidence after)
                    (Map.insertWith (<>) (requestModule request) errorsHere found) more
            MatchLimit _ -> Map.insertWith (<>) (requestModule request)
              (finding "E3093" (requestAnchor request) "derive coherence exhausted its compile-time work budget") found

remember :: Head -> Seen -> Seen
remember held (Seen exact open) = case keyOf held of
  Key (Just trait) (Just target) -> Seen (Map.insertWith (<>) (trait, target) [held] exact) open
  _ -> Seen exact (held : open)

{-| The heads a new one could overlap: its own bucket and every open head, or,
    for an open head, every head whose constructors agree with it. -}
candidates :: Seen -> Head -> [Head]
candidates (Seen exact open) held = case keyOf held of
  Key (Just trait) (Just target) -> Map.findWithDefault [] (trait, target) exact <> filter (agrees held) open
  _ -> filter (agrees held) (concat (Map.elems exact) <> open)

agrees :: Head -> Head -> Bool
agrees left right = case (keyOf left, keyOf right) of
  (Key leftTrait leftTarget, Key rightTrait rightTarget) ->
    same leftTrait rightTrait && same leftTarget rightTarget
 where
  same (Just one) (Just other) = one == other
  same _ _ = True

keyOf :: Head -> Key
keyOf (Head _ rule) = Key (constructor (implementationTrait rule)) (constructor (implementationTarget rule))
 where
  constructor held = case held of
    NominalType identity _ -> Just identity
    AppliedType target _ -> constructor target
    _ -> Nothing

formed :: DeclaredTypes -> Impl -> ImplementationRule
formed scope value = ImplementationRule rigid
  (formBoundType scope rigid (implTarget value))
  (formBoundType scope rigid (implTrait value)) []
 where
  rigid = [(locatedValue (typeParamName parameter), typeParamArity parameter)
    | Located _ parameter <- implTypeParams value]

finding :: Text -> Span -> Text -> [Diagnostic]
finding name at message = case mkDiagnosticCode name >>= \code -> diagnostic code Error at message of
  Nothing -> []
  Just value -> [value]
