{-| @Type.Exhaust.Module — checks that a match covers its scrutinee -}
module Pudu.Type.Exhaust
  ( checkExhaustive
  ) where

import Control.Monad (filterM)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameSegments, moduleNameText)
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree (MatchArm (..), Pattern (..))
import Pudu.Source (Span)
import Pudu.Type.Check.Pattern (substituteRigid, variantForPath)
import Pudu.Type.Env (Checker, DeclaredTypes (..), lookupField, lookupOwnerVariants, lookupVariantIn, patternTests, report, warn)
import Pudu.Type.Unify (zonk)
import Pudu.Type.Value (NominalId, Type (..), nominalName, renderType)

{-| Check that a match covers every value its scrutinee can take, and that no
    arm is unreachable.

    A guarded arm never contributes to coverage: its guard may be false, which
    is exactly the rule [[architecture/SEMANTICS]] states. Coverage is decided
    only where it is decidable — closed sums, booleans, and tuples — and an open domain
    such as `Int` is covered only by an irrefutable arm. -}
checkExhaustive :: DeclaredTypes -> Span -> Type -> [Located MatchArm] -> Checker ()
checkExhaustive declared spanValue subjectType arms = do
  resolved <- zonk subjectType
  tests <- patternTests
  let isTest at = Set.member at tests
  reportUnreachable declared isTest arms
  case resolved of
    ErrorType -> pure ()
    VariableType _ -> pure ()
    NominalType "Bool" [] -> checkClosed isTest spanValue "Bool" [] ["true", "false"] arms
    NominalType owner arguments -> do
      variants <- lookupOwnerVariants owner
      case variants of
        Just names -> checkClosed isTest spanValue owner arguments names arms
        Nothing -> checkOpen isTest spanValue resolved arms
    TupleTypeValue _ -> do
      covered <- coversRows isTest [resolved]
        [[armPattern arm] | Located _ arm <- arms, armGuard arm == Nothing]
      if covered then pure () else checkOpen isTest spanValue resolved arms
    _ -> checkOpen isTest spanValue resolved arms

{-| A closed domain is covered when every constructor is covered by the
    unguarded arms, or when an irrefutable arm covers what remains. -}
checkClosed
  :: (Span -> Bool) -> Span -> NominalId -> [Type] -> [Text] -> [Located MatchArm] -> Checker ()
checkClosed isTest spanValue owner arguments names arms
  | any (irrefutableArm isTest) arms = pure ()
  | otherwise = do
      missing <- filterM (fmap not . constructorCovered isTest owner arguments patterns) names
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

{-| Cover a constructor's actual instantiated payload, retaining correlations
    between payload elements and resolving every nested sum by its owner. -}
constructorCovered
  :: (Span -> Bool) -> NominalId -> [Type] -> [Located Pattern] -> Text -> Checker Bool
constructorCovered isTest owner typeArguments patterns name
  | any (namesLiteral name) patterns = pure True
  | any bindsWhole patterns = pure True
  | null payloads = pure False
  | otherwise = do
      found <- lookupVariantIn owner name
      case found of
        Nothing -> pure False
        Just (_, parameters, declaredPayload) ->
          coversRows isTest
            (map (substituteRigid (zip parameters typeArguments)) declaredPayload) payloads
 where
  payloads =
    [ arguments
    | Located _ (ConstructorPattern path arguments) <- patterns
    , NonEmpty.last (moduleNameSegments path) == name
    ]
  bindsWhole (Located _ pattern') = case pattern' of
    ConstructorPattern path arguments ->
      NonEmpty.last (moduleNameSegments path) == name
        && all (irrefutable isTest) arguments
    RecordPattern (Just path) fields _ ->
      NonEmpty.last (moduleNameSegments path) == name
        && all (irrefutableField isTest) fields
    _ -> False
  namesLiteral wanted (Located _ pattern') = case pattern' of
    LiteralPattern (Tree.BoolValue flag) -> wanted == (if flag then "true" else "false")
    _ -> False

{-| Specialize complete rows against actual column types. Payload instantiation
    follows the column's canonical owner rather than a globally loaded variant
    spelling; keeping the remaining columns preserves tuple correlations. -}
coversRows :: (Span -> Bool) -> [Type] -> [[Located Pattern]] -> Checker Bool
coversRows isTest types rows
  | null rows = pure False
  | null types = pure (any null rows)
  | any (all (irrefutable isTest)) rows = pure True
  | otherwise = case types of
      [] -> pure False
      subject : restTypes -> do
        resolved <- zonk subject
        if all (irrefutable isTest) heads
          then coversRows isTest restTypes defaults
          else case resolved of
            ReferenceTypeValue _ target -> coversRows isTest (target : restTypes) rows
            TupleTypeValue members ->
              coversRows isTest (members <> restTypes) (specialize (length members) tupleMembers)
            NominalType "Bool" [] ->
              and <$> mapM (\flag -> coversRows isTest restTypes (specialize 0 (boolean flag))) [True, False]
            NominalType owner arguments -> do
              variants <- lookupOwnerVariants owner
              case variants of
                Nothing -> coversRows isTest restTypes defaults
                Just names -> and <$> mapM (coverConstructor owner arguments restTypes) names
            _ -> coversRows isTest restTypes defaults
 where
  expanded = concatMap expand rows
  expand [] = [[]]
  expand (held : rest) = [branch : rest | branch <- branches held]
  heads = [held | held : _ <- expanded]
  defaults = [rest | held : rest <- expanded, irrefutable isTest held]
  specialize arity select =
    [ arguments <> rest
    | held@(Located heldSpan _) : rest <- expanded
    , arguments <- if irrefutable isTest held
        then [replicate arity (Located heldSpan WildcardPattern)]
        else maybe [] pure (select held)
    ]
  tupleMembers (Located _ (TuplePattern members)) = Just members
  tupleMembers _ = Nothing
  boolean flag (Located _ (LiteralPattern (Tree.BoolValue actual)))
    | flag == actual = Just []
  boolean _ _ = Nothing
  constructor name arity (Located heldSpan pattern') = case pattern' of
    ConstructorPattern path arguments
      | NonEmpty.last (moduleNameSegments path) == name -> Just arguments
    RecordPattern (Just path) fields _
      | NonEmpty.last (moduleNameSegments path) == name
      , all (irrefutableField isTest) fields ->
          Just (replicate arity (Located heldSpan WildcardPattern))
    _ -> Nothing
  coverConstructor owner arguments restTypes name = do
    found <- lookupVariantIn owner name
    case found of
      Nothing -> pure False
      Just (_, parameters, declaredPayload) -> do
        let payload = map (substituteRigid (zip parameters arguments)) declaredPayload
        coversRows isTest (payload <> restTypes)
          (specialize (length payload) (constructor name (length payload)))

{-| An open domain cannot be enumerated, so only an irrefutable arm covers it. -}
checkOpen :: (Span -> Bool) -> Span -> Type -> [Located MatchArm] -> Checker ()
checkOpen isTest spanValue resolved arms
  | any (irrefutableArm isTest) arms = pure ()
  | otherwise =
      report "E5001" spanValue
        ("match on " <> renderType resolved <> " does not cover every value")
        (Just "add a wildcard case for the values the arms do not name")

irrefutableArm :: (Span -> Bool) -> Located MatchArm -> Bool
irrefutableArm isTest (Located _ arm) =
  armGuard arm == Nothing && irrefutable isTest (armPattern arm)

{-| A pattern is irrefutable when it always matches: a wildcard, a binding, or
    an aggregate whose parts are all irrefutable. -}
irrefutable :: (Span -> Bool) -> Located Pattern -> Bool
irrefutable isTest (Located at pattern') = case pattern' of
  WildcardPattern -> True
  BindingPattern _ -> True
  TuplePattern members -> all (irrefutable isTest) members
  {-| A sequence pattern names a length and a sequence has whatever length it
      has, so it never stands for every value the way a binding does. -}
  ArrayPattern{} -> False
  {-| Named sum payloads and dynamic record narrowing test declaration identity. -}
  RecordPattern _ fields _
    | isTest at -> False
    | otherwise -> all (irrefutableField isTest) fields
  _ -> False

irrefutableField :: (Span -> Bool) -> Located Tree.FieldPattern -> Bool
irrefutableField isTest (Located _ field) = case Tree.fieldPatternValue field of
  Nothing -> True
  Just nested -> irrefutable isTest nested

{-| What an earlier unguarded arm has already taken.

    Only tests whose whole extent is one name or one literal are recorded. A
    pattern that binds part of what it matches spans more values than any key
    could stand for, so it contributes nothing here and nothing is claimed
    about it. -}
data Taken
  = TakenConstructor !NominalId !Text
  | TakenLiteral !Tree.Literal
  deriving stock (Eq)

{-| An arm that can never run, either because an earlier arm matches everything
    or because an earlier arm already took every value this one names.

    Both are the same mistake to a reader — a case that looks live and is not —
    but they are different mistakes to make, so each says which happened. -}
reportUnreachable :: DeclaredTypes -> (Span -> Bool) -> [Located MatchArm] -> Checker ()
reportUnreachable declared isTest = walk False []
 where
  walk _ _ [] = pure ()
  walk closed taken (Located armSpan arm : rest) = do
    keys <- takenBy declared isTest (armPattern arm)
    let unguarded = armGuard arm == Nothing
        subsumed = not (null keys) && all (`elem` taken) keys
        closed' = closed || (unguarded && irrefutable isTest (armPattern arm))
        taken' = if unguarded then keys <> taken else taken
    if closed
      then unreachable armSpan coveredHelp >> walk True taken rest
      else if subsumed
        then unreachable armSpan takenHelp >> walk closed taken rest
        else walk closed' taken' rest

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
takenBy :: DeclaredTypes -> (Span -> Bool) -> Located Pattern -> Checker [Taken]
takenBy declared isTest (Located _ pattern') = case pattern' of
  ConstructorPattern path arguments
    | all (irrefutable isTest) arguments -> constructorKey path
  RecordPattern (Just path) fields _
    | all (irrefutableField isTest) fields -> do
        let owner = Map.lookup (moduleNameText path) (declaredNames declared)
        record <- maybe (pure Nothing) lookupField owner
        case (owner, record) of
          (Just identity, Just _) -> pure [TakenConstructor identity ""]
          _ -> constructorKey path
  LiteralPattern literal -> pure [TakenLiteral literal]
  AlternativePattern alternatives -> do
    taken <- mapM (takenBy declared isTest) alternatives
    pure (if any null taken then [] else concat taken)
  _ -> pure []
 where
  constructorKey path = do
    let name = NonEmpty.last (moduleNameSegments path)
    found <- variantForPath declared path name
    pure (case found of
      Just (owner, _, _) -> [TakenConstructor owner name]
      Nothing -> [])
