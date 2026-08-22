{-| @Type.Exhaust.Module — checks that a match covers its scrutinee -}
module Pudu.Type.Exhaust
  ( checkExhaustive
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameSegments)
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree (MatchArm (..), Pattern (..))
import Pudu.Source (Span)
import Pudu.Type.Env (Checker, lookupOwnerVariants, report, warn)
import Pudu.Type.Unify (zonk)
import Pudu.Type.Value (Type (..), renderType)

{-| Check that a match covers every value its scrutinee can take, and that no
    arm is unreachable.

    A guarded arm never contributes to coverage: its guard may be false, which
    is exactly the rule [[architecture/SEMANTICS]] states. Coverage is decided
    only where it is decidable — closed sums and booleans — and an open domain
    such as `Int` is covered only by an irrefutable arm. -}
checkExhaustive :: Span -> Type -> [Located MatchArm] -> Checker ()
checkExhaustive spanValue subjectType arms = do
  resolved <- zonk subjectType
  reportUnreachable arms
  case resolved of
    ErrorType -> pure ()
    VariableType _ -> pure ()
    NominalType "Bool" [] -> checkClosed spanValue "Bool" ["true", "false"] arms
    NominalType owner _ -> do
      variants <- lookupOwnerVariants owner
      case variants of
        Just names -> checkClosed spanValue owner names arms
        Nothing -> checkOpen spanValue resolved arms
    _ -> checkOpen spanValue resolved arms

{-| A closed domain is covered when every constructor appears in an unguarded
    arm whose sub-patterns bind rather than test, or when an irrefutable arm
    covers what remains. -}
checkClosed :: Span -> Text -> [Text] -> [Located MatchArm] -> Checker ()
checkClosed spanValue owner names arms
  | any irrefutableArm arms = pure ()
  | null missing = pure ()
  | otherwise =
      report "E5001" spanValue
        ("match on " <> owner <> " does not cover " <> Text.intercalate ", " missing)
        (Just "add a case for each remaining constructor, or a wildcard case")
 where
  covered = concatMap coveredNames arms
  missing = [name | name <- names, name `notElem` covered]

{-| An open domain cannot be enumerated, so only an irrefutable arm covers it. -}
checkOpen :: Span -> Type -> [Located MatchArm] -> Checker ()
checkOpen spanValue resolved arms
  | any irrefutableArm arms = pure ()
  | otherwise =
      report "E5001" spanValue
        ("match on " <> renderType resolved <> " does not cover every value")
        (Just "add a wildcard case for the values the arms do not name")

{-| An arm covers a name when it is unguarded and its payload patterns only
    bind. `case Ok(1)` tests its payload, so it does not cover `Ok`. -}
coveredNames :: Located MatchArm -> [Text]
coveredNames (Located _ arm)
  | armGuard arm /= Nothing = []
  | otherwise = namesOf (armPattern arm)

namesOf :: Located Pattern -> [Text]
namesOf (Located _ pattern') = case pattern' of
  ConstructorPattern path arguments
    | all irrefutable arguments -> [NonEmpty.last (moduleNameSegments path)]
    | otherwise -> []
  RecordPattern path _ _ -> maybe [] (pure . NonEmpty.last . moduleNameSegments) path
  LiteralPattern (Tree.BoolValue flag) -> [if flag then "true" else "false"]
  AlternativePattern alternatives -> concatMap namesOf alternatives
  _ -> []

irrefutableArm :: Located MatchArm -> Bool
irrefutableArm (Located _ arm) =
  armGuard arm == Nothing && irrefutable (armPattern arm)

{-| A pattern is irrefutable when it always matches: a wildcard, a binding, or
    an aggregate whose parts are all irrefutable. -}
irrefutable :: Located Pattern -> Bool
irrefutable (Located _ pattern') = case pattern' of
  WildcardPattern -> True
  BindingPattern _ -> True
  TuplePattern members -> all irrefutable members
  RecordPattern _ fields _ -> all irrefutableField fields
  _ -> False

irrefutableField :: Located Tree.FieldPattern -> Bool
irrefutableField (Located _ field) = case Tree.fieldPatternValue field of
  Nothing -> True
  Just nested -> irrefutable nested

{-| An arm after one that already matches everything can never run. -}
reportUnreachable :: [Located MatchArm] -> Checker ()
reportUnreachable arms = case break irrefutableArm arms of
  (_, _ : rest@(_ : _)) -> mapM_ unreachable rest
  _ -> pure ()
 where
  unreachable (Located armSpan _) =
    warn "W5001" armSpan "this case can never match"
      (Just "an earlier case already covers every remaining value")
