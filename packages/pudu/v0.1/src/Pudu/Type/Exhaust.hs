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
import Pudu.Type.Check.Pattern (substituteRigid)
import Pudu.Type.Env (Checker, lookupOwnerVariants, lookupVariant, lookupVariantIn, report, warn)
import Pudu.Type.Unify (zonk)
import Pudu.Type.Value (NominalId, Type (..), nominalName, renderType)

{-| Check that a match covers every value its scrutinee can take, and that no
    arm is unreachable.

    A guarded arm never contributes to coverage: its guard may be false, which
    is exactly the rule [[architecture/SEMANTICS]] states. Coverage is decided
    only where it is decidable — closed sums, booleans, and tuples — and an open domain
    such as `Int` is covered only by an irrefutable arm. -}
checkExhaustive :: Span -> Type -> [Located MatchArm] -> Checker ()
checkExhaustive spanValue subjectType arms = do
  resolved <- zonk subjectType
  isVariant <- variantNamer arms
  reportUnreachable isVariant arms
  case resolved of
    ErrorType -> pure ()
    VariableType _ -> pure ()
    NominalType "Bool" [] -> checkClosed isVariant spanValue "Bool" [] ["true", "false"] arms
    NominalType owner arguments -> do
      variants <- lookupOwnerVariants owner
      case variants of
        Just names -> checkClosed isVariant spanValue owner arguments names arms
        Nothing -> checkOpen isVariant spanValue resolved arms
    TupleTypeValue _ -> do
      covered <- coversRows isVariant [resolved]
        [[armPattern arm] | Located _ arm <- arms, armGuard arm == Nothing]
      if covered then pure () else checkOpen isVariant spanValue resolved arms
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
  ArrayPattern prefix _ suffix -> concatMap recordNames (prefix <> suffix)
  AlternativePattern alternatives -> concatMap recordNames alternatives
  _ -> []
 where
  fieldNames (Located _ field) =
    maybe [] recordNames (Tree.fieldPatternValue field)

{-| A closed domain is covered when every constructor is covered by the
    unguarded arms, or when an irrefutable arm covers what remains. -}
checkClosed
  :: (Text -> Bool) -> Span -> NominalId -> [Type] -> [Text] -> [Located MatchArm] -> Checker ()
checkClosed isVariant spanValue owner arguments names arms
  | any (irrefutableArm isVariant) arms = pure ()
  | otherwise = do
      missing <- filterM (fmap not . constructorCovered isVariant owner arguments patterns) names
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
  :: (Text -> Bool) -> NominalId -> [Type] -> [Located Pattern] -> Text -> Checker Bool
constructorCovered isVariant owner typeArguments patterns name
  | any (namesLiteral name) patterns = pure True
  | any bindsWhole patterns = pure True
  | null payloads = pure False
  | otherwise = do
      found <- lookupVariantIn owner name
      case found of
        Nothing -> pure False
        Just (_, parameters, declaredPayload) ->
          coversRows isVariant
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
        && all (irrefutable isVariant) arguments
    RecordPattern (Just path) fields _ ->
      NonEmpty.last (moduleNameSegments path) == name
        && all (irrefutableField isVariant) fields
    _ -> False
  namesLiteral wanted (Located _ pattern') = case pattern' of
    LiteralPattern (Tree.BoolValue flag) -> wanted == (if flag then "true" else "false")
    _ -> False

{-| Specialize complete rows against actual column types. Payload instantiation
    follows the column's canonical owner rather than a globally loaded variant
    spelling; keeping the remaining columns preserves tuple correlations. -}
coversRows :: (Text -> Bool) -> [Type] -> [[Located Pattern]] -> Checker Bool
coversRows isVariant types rows
  | null rows = pure False
  | null types = pure (any null rows)
  | any (all (irrefutable isVariant)) rows = pure True
  | otherwise = case types of
      [] -> pure False
      subject : restTypes -> do
        resolved <- zonk subject
        if all (irrefutable isVariant) heads
          then coversRows isVariant restTypes defaults
          else case resolved of
            ReferenceTypeValue _ target -> coversRows isVariant (target : restTypes) rows
            TupleTypeValue members ->
              coversRows isVariant (members <> restTypes) (specialize (length members) tupleMembers)
            NominalType "Bool" [] ->
              and <$> mapM (\flag -> coversRows isVariant restTypes (specialize 0 (boolean flag))) [True, False]
            NominalType owner arguments -> do
              variants <- lookupOwnerVariants owner
              case variants of
                Nothing -> coversRows isVariant restTypes defaults
                Just names -> and <$> mapM (coverConstructor owner arguments restTypes) names
            _ -> coversRows isVariant restTypes defaults
 where
  expanded = concatMap expand rows
  expand [] = [[]]
  expand (held : rest) = [branch : rest | branch <- branches held]
  heads = [held | held : _ <- expanded]
  defaults = [rest | held : rest <- expanded, irrefutable isVariant held]
  specialize arity select =
    [ arguments <> rest
    | held@(Located heldSpan _) : rest <- expanded
    , arguments <- if irrefutable isVariant held
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
      , all (irrefutableField isVariant) fields ->
          Just (replicate arity (Located heldSpan WildcardPattern))
    _ -> Nothing
  coverConstructor owner arguments restTypes name = do
    found <- lookupVariantIn owner name
    case found of
      Nothing -> pure False
      Just (_, parameters, declaredPayload) -> do
        let payload = map (substituteRigid (zip parameters arguments)) declaredPayload
        coversRows isVariant (payload <> restTypes)
          (specialize (length payload) (constructor name (length payload)))

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
  {-| A sequence pattern names a length and a sequence has whatever length it
      has, so it never stands for every value the way a binding does. -}
  ArrayPattern{} -> False
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
