{-| @Type.Exhaust.Module — checks that a match covers its scrutinee -}
module Pudu.Type.Exhaust
  ( checkExhaustive
  ) where

import Control.Monad (filterM)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameSegments)
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree (MatchArm (..), Pattern (..))
import Pudu.Source (Span)
import Pudu.Type.Env (Checker, lookupOwnerVariants, lookupVariant, report, warn)
import Pudu.Type.Unify (zonk)
import Pudu.Type.Value (NominalId, Type (..), nominalName, renderType)

{-| Check that a match covers every value its scrutinee can take, and that no
    arm is unreachable.

    A guarded arm never contributes to coverage: its guard may be false, which
    is exactly the rule [[architecture/SEMANTICS]] states. Coverage is decided
    only where it is decidable — closed sums and booleans — and an open domain
    such as `Int` is covered only by an irrefutable arm. -}
checkExhaustive :: Span -> Type -> [Located MatchArm] -> Checker ()
checkExhaustive spanValue subjectType arms = do
  resolved <- zonk subjectType
  isVariant <- variantNamer arms
  reportUnreachable isVariant arms
  case resolved of
    ErrorType -> pure ()
    VariableType _ -> pure ()
    NominalType "Bool" [] -> checkClosed isVariant spanValue "Bool" ["true", "false"] arms
    NominalType owner _ -> do
      variants <- lookupOwnerVariants owner
      case variants of
        Just names -> checkClosed isVariant spanValue owner names arms
        Nothing -> checkOpen isVariant spanValue resolved arms
    _ -> checkOpen isVariant spanValue resolved arms

{-| Decide, for the names these arms actually mention, which are sum variants.

    A record pattern reaches a sum when a variant declared names for its
    payload, and `case Circle{radius}` is then a test rather than a binding —
    it matches one variant of several. A record type's own pattern names no
    variant and stays irrefutable, which is what it has always been. The
    question is asked once per name the arms mention rather than at every
    recursive step, because the answer cannot change within a match. -}
variantNamer :: [Located MatchArm] -> Checker (Text -> Bool)
variantNamer arms = do
  let mentioned = concatMap (recordNames . armPattern . locatedValue) arms
  found <- mapM (\name -> (,) name . (/= Nothing) <$> lookupVariant name) mentioned
  pure (\name -> Just True == lookup name found)

{-| Every name a record pattern in this tree writes before its braces. -}
recordNames :: Located Pattern -> [Text]
recordNames (Located _ pattern') = case pattern' of
  RecordPattern path fields _ ->
    maybe [] (pure . NonEmpty.last . moduleNameSegments) path
      <> concatMap fieldNames fields
  ConstructorPattern _ arguments -> concatMap recordNames arguments
  TuplePattern members -> concatMap recordNames members
  AlternativePattern alternatives -> concatMap recordNames alternatives
  _ -> []
 where
  fieldNames (Located _ field) =
    maybe [] recordNames (Tree.fieldPatternValue field)

{-| A closed domain is covered when every constructor is covered by the
    unguarded arms, or when an irrefutable arm covers what remains. -}
checkClosed
  :: (Text -> Bool) -> Span -> NominalId -> [Text] -> [Located MatchArm] -> Checker ()
checkClosed isVariant spanValue owner names arms
  | any (irrefutableArm isVariant) arms = pure ()
  | otherwise = do
      missing <- filterM (fmap not . constructorCovered isVariant patterns) names
      if null missing
        then pure ()
        else
          report "E5001" spanValue
            ("match on " <> nominalName owner <> " does not cover " <> Text.intercalate ", " missing)
            (Just "add a case for each remaining constructor, or a wildcard case")
 where
  patterns = concatMap (branches . armPattern . locatedValue) (filter unguarded arms)
  unguarded (Located _ arm) = armGuard arm == Nothing

{-| A pattern and, for an alternative, each of its branches.

    An alternative matches when any branch does, so its branches cover exactly
    what they cover separately. -}
branches :: Located Pattern -> [Located Pattern]
branches held@(Located _ pattern') = case pattern' of
  AlternativePattern alternatives -> concatMap branches alternatives
  _ -> [held]

{-| Whether these patterns, between them, cover one constructor.

    A payload that binds covers the constructor outright, which is the rule a
    single arm has always followed. A payload that tests covers it only when
    the arms naming that constructor exhaust the payload between them — the
    same question, one level down, which is what makes `Ok(None)` and
    `Ok(Some(x))` cover `Ok` while `Ok(1)` does not.

    Only a payload of one value is followed down. Two of them would need every
    combination accounted for, and `C(true, true)` with `C(false, false)`
    covers neither the pair `(true, false)` nor `C`; answering that needs more
    than this asks, so it answers no. Saying no where the truth is unknown
    costs a wildcard nobody needed. Saying yes would accept a match that fails
    at run time. -}
constructorCovered :: (Text -> Bool) -> [Located Pattern] -> Text -> Checker Bool
constructorCovered isVariant patterns name
  | any (namesLiteral name) patterns = pure True
  | any bindsWhole patterns = pure True
  | null payloads = pure False
  | not (all single payloads) = pure False
  | otherwise = coversPatterns isVariant [held | [held] <- payloads]
 where
  payloads =
    [ arguments
    | Located _ (ConstructorPattern path arguments) <- patterns
    , NonEmpty.last (moduleNameSegments path) == name
    ]
  single held = length held == 1
  bindsWhole (Located _ pattern') = case pattern' of
    ConstructorPattern path arguments ->
      NonEmpty.last (moduleNameSegments path) == name
        && all (irrefutable isVariant) arguments
    RecordPattern (Just path) fields _ ->
      NonEmpty.last (moduleNameSegments path) == name
        && all (irrefutableField isVariant) fields
    _ -> False
  namesLiteral wanted (Located _ pattern') = case pattern' of
    LiteralPattern (Tree.BoolValue flag) -> wanted == (if flag then "true" else "false")
    _ -> False

{-| Whether these patterns, between them, cover every value they could be
    matched against.

    The domain is read from the patterns rather than from a type. A payload's
    declared type is written in the sum's own parameters — `Ok` carries a `T`,
    not the `Bool` this particular `Result` settled it to — so the type at hand
    would have to be instantiated before it said anything. A constructor that
    was actually written names its sum directly, and that is the same question
    answered without the substitution.

    Booleans are the domain with no constructors to read, so they are named. -}
coversPatterns :: (Text -> Bool) -> [Located Pattern] -> Checker Bool
coversPatterns isVariant patterns
  | any (irrefutable isVariant) patterns = pure True
  | bothBooleans = pure True
  | otherwise = case written of
      [] -> pure False
      (first : _) -> do
        found <- lookupVariant first
        case found of
          Nothing -> pure False
          Just (owner, _, _) -> do
            variants <- lookupOwnerVariants owner
            case variants of
              Nothing -> pure False
              Just names -> and <$> mapM (constructorCovered isVariant patterns) names
 where
  written =
    [ NonEmpty.last (moduleNameSegments path)
    | Located _ (ConstructorPattern path _) <- patterns
    ]
      <> [ NonEmpty.last (moduleNameSegments path)
         | Located _ (RecordPattern (Just path) _ _) <- patterns
         ]
  bothBooleans = boolean True && boolean False
  boolean wanted =
    any
      ( \(Located _ pattern') -> case pattern' of
          LiteralPattern (Tree.BoolValue flag) -> flag == wanted
          _ -> False
      )
      patterns

{-| An open domain cannot be enumerated, so only an irrefutable arm covers it. -}
checkOpen :: (Text -> Bool) -> Span -> Type -> [Located MatchArm] -> Checker ()
checkOpen isVariant spanValue resolved arms
  | any (irrefutableArm isVariant) arms = pure ()
  | otherwise =
      report "E5001" spanValue
        ("match on " <> renderType resolved <> " does not cover every value")
        (Just "add a wildcard case for the values the arms do not name")

irrefutableArm :: (Text -> Bool) -> Located MatchArm -> Bool
irrefutableArm isVariant (Located _ arm) =
  armGuard arm == Nothing && irrefutable isVariant (armPattern arm)

{-| A pattern is irrefutable when it always matches: a wildcard, a binding, or
    an aggregate whose parts are all irrefutable. -}
irrefutable :: (Text -> Bool) -> Located Pattern -> Bool
irrefutable isVariant (Located _ pattern') = case pattern' of
  WildcardPattern -> True
  BindingPattern _ -> True
  TuplePattern members -> all (irrefutable isVariant) members
  {-| Naming a variant is a test. `case Circle{radius}` matches one variant of
      several, so it cannot stand for the whole type the way a record type's own
      pattern does. -}
  RecordPattern path fields _
    | any isVariant (maybe [] (pure . NonEmpty.last . moduleNameSegments) path) -> False
    | otherwise -> all (irrefutableField isVariant) fields
  _ -> False

irrefutableField :: (Text -> Bool) -> Located Tree.FieldPattern -> Bool
irrefutableField isVariant (Located _ field) = case Tree.fieldPatternValue field of
  Nothing -> True
  Just nested -> irrefutable isVariant nested

{-| What an earlier unguarded arm has already taken.

    Only tests whose whole extent is one name or one literal are recorded. A
    pattern that binds part of what it matches spans more values than any key
    could stand for, so it contributes nothing here and nothing is claimed
    about it. -}
data Taken
  = TakenConstructor !Text
  | TakenLiteral !Tree.Literal
  deriving stock (Eq)

{-| An arm that can never run, either because an earlier arm matches everything
    or because an earlier arm already took every value this one names.

    Both are the same mistake to a reader — a case that looks live and is not —
    but they are different mistakes to make, so each says which happened. -}
reportUnreachable :: (Text -> Bool) -> [Located MatchArm] -> Checker ()
reportUnreachable isVariant = walk False []
 where
  walk _ _ [] = pure ()
  walk closed taken (Located armSpan arm : rest)
    | closed = unreachable armSpan coveredHelp >> walk True taken rest
    | subsumed = unreachable armSpan takenHelp >> walk closed taken rest
    | otherwise = walk closed' taken' rest
   where
    keys = takenBy isVariant (armPattern arm)
    unguarded = armGuard arm == Nothing
    subsumed = not (null keys) && all (`elem` taken) keys
    closed' = closed || (unguarded && irrefutable isVariant (armPattern arm))
    taken' = if unguarded then keys <> taken else taken

  unreachable armSpan help =
    warn "W5001" armSpan "this case can never match" (Just help)

  coveredHelp = "an earlier case already covers every remaining value"
  takenHelp = "an earlier case already matches this pattern"

{-| The values a pattern names, when they can be named exactly.

    A constructor stands for all of its values only when its payload binds
    rather than tests: `case Ok(1)` leaves the rest of `Ok` for a later arm,
    so it takes nothing. An alternative takes what its branches take, and only
    when every branch is nameable — one open branch leaves the whole
    alternative open. -}
takenBy :: (Text -> Bool) -> Located Pattern -> [Taken]
takenBy isVariant (Located _ pattern') = case pattern' of
  ConstructorPattern path arguments
    | all (irrefutable isVariant) arguments ->
        [TakenConstructor (NonEmpty.last (moduleNameSegments path))]
  RecordPattern (Just path) fields _
    | all (irrefutableField isVariant) fields ->
        [TakenConstructor (NonEmpty.last (moduleNameSegments path))]
  LiteralPattern literal -> [TakenLiteral literal]
  AlternativePattern alternatives ->
    let taken = map (takenBy isVariant) alternatives
     in if any null taken then [] else concat taken
  _ -> []
