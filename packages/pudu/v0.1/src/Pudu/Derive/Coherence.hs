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

generatedCoherence
  :: Map ModuleName DeclaredTypes -> Map ModuleName Module -> [(Request, Impl)]
  -> Map ModuleName [Diagnostic]
generatedCoherence scopes modules generated = inspect iterationLimit Map.empty pairs
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
  pairs = collect ordinary generatedHeads
  collect _ [] = []
  collect previous ((request, held) : rest) =
    [(request, held, other) | other <- previous] <> collect (held : previous) rest
  inspect _ errors [] = errors
  inspect fuel errors ((request, Head _ held, Head otherAt other) : rest) =
    case overlapRules (beginEvidence fuel) held other of
      Mismatched after -> inspect (remainingEvidence after) errors rest
      Matched () after ->
        let errorsHere = map (withRelated (Related otherAt "overlapping implementation declared here"))
              (finding "E3015" (requestAnchor request)
                "derived implementation overlaps an existing canonical implementation head")
         in inspect (remainingEvidence after)
              (Map.insertWith (<>) (requestModule request) errorsHere errors) rest
      MatchLimit _ -> Map.insertWith (<>) (requestModule request)
        (finding "E3093" (requestAnchor request) "derive coherence exhausted its compile-time work budget") errors

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
