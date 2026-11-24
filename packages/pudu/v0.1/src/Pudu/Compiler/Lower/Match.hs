{-| @Pudu.Compiler.Lower.Match — `match`: the subject, then each arm's
    pattern, guard and body in a scope of its own. -}
module Pudu.Compiler.Lower.Match
  ( lowerMatch, lowerLetElse, lowerLetSequence, hasSequencePattern, lowerPattern, ifLetArms, whileLetLoop ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.List (find, mapAccumL)
import Data.List.NonEmpty (NonEmpty (..))
import Pudu.Compiler.Lower.Control (expressionIsPrintValued, joinType)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, refused)
import Pudu.Compiler.Lower.Types (ownerKeyOf, recordFields, sumVariants, typeForSpan, writtenLabel)
import Pudu.Core
import Pudu.Compiler.Lower.Dynamic (commonAggregateCarrier, isDynamic, mapRuntimeChoice, normalizeAggregateValue, preserveRuntimeResult, pathText, projectRuntimeValue, widen)
import Pudu.Frontend.Syntax
  ( ArrayRest (..), Block (..), Expression (..), FieldPattern (..), Literal (..), Located (..), MatchArm (..), Pattern (..)
  , Statement (..) )
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.IntegerLiteral (ParsedInteger (..), integerKindBounds, integerKindFits, parseIntegerLiteral)
import Pudu.Source (Span)
import Data.Text (Text)
import qualified Data.Text as Text

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

lowerMatchSubject :: LowerExpression -> LowerExpression
lowerMatchSubject lower state subject = case lower state subject of
  (after, Just (value, _)) ->
    let types = contextTypes (lowerContext after)
        (ready, held) = normalizeAggregateValue types (typeForSpan types (locatedSpan subject)) after value
     in (ready, Just (held, coreExpressionType held))
  (after, Nothing) -> refused after

{-| When `discarded`, the match is a statement: each arm's value is evaluated
    and dropped, so an arm may end in `print(...)`. -}
lowerMatch :: LowerExpression -> Bool -> LowerState -> Span -> Located Expression -> [Located MatchArm]
  -> (LowerState, Maybe (CoreExpression, CoreType))
lowerMatch lower discarded state at subject arms = case lowerMatchSubject lower state subject of
  (after, Nothing) -> refused after
  (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
  (after, Just (core, _))
    | expressionIsPrintValued core -> halt (locatedSpan subject) "matching a Result[(), Str] value" after
    | otherwise -> fmap (fmap preserve) (select after core)
 where
  preserve answer | discarded = answer
  preserve (value, _) =
    let checked = typeForSpan (contextTypes (lowerContext state)) at
        carried = maybe value (\expected -> preserveRuntimeResult expected value) checked
     in (carried, coreExpressionType carried)
  select current held
    | Just selected <- mapRuntimeChoice current at CoreNeverType held
        (\ready payload -> fmap (fmap fst) (select ready payload)) = selected
    | otherwise = compileArms current held
  compileArms initial core = go initial (coreExpressionType core) [] arms
     where
      go prior _ done [] =
        let lowered = reverse done
         in case foldr (\arm found -> found >>= joinType (coreExpressionType (coreArmBody arm))) (Just CoreNeverType) lowered of
              Just result -> (prior, Just (CoreExpression at result (CoreMatch core lowered), result))
              Nothing
                | Just expected <- typeForSpan (contextTypes (lowerContext prior)) at
                , let widened = [arm{coreArmBody = widen (contextTypes (lowerContext prior)) expected (coreArmBody arm)} | arm <- lowered]
                , all ((`elem` [expected, CoreNeverType]) . coreExpressionType . coreArmBody) widened ->
                    (prior, Just (CoreExpression at expected (CoreMatch core widened), expected))
                | let types = contextTypes (lowerContext prior)
                , Just checked <- typeForSpan types at
                , Just shared <- commonAggregateCarrier types checked
                    (filter (/= CoreNeverType) (map (coreExpressionType . coreArmBody) lowered))
                , let project entered arm =
                        let (ready, value) = projectRuntimeValue types entered shared (coreArmBody arm)
                         in (ready, arm{coreArmBody = value})
                      (final, projected) = mapAccumL project prior lowered
                , all ((`elem` [shared, CoreNeverType]) . coreExpressionType . coreArmBody) projected ->
                    (final, Just (CoreExpression at shared (CoreMatch core projected), shared))
                | otherwise -> halt at "a match whose arms have different types" prior
      go prior subjectKind done (Located armSpan (MatchArm pattern' guard' body) : rest) =
        let opened = prior{lowerScopes = [] : lowerScopes prior}
            close next = next{lowerScopes = drop 1 (lowerScopes next)}
         in case lowerPattern lower opened subjectKind Map.empty pattern' of
              (afterPattern, Nothing) -> refused (close afterPattern)
              (afterPattern, Just (corePattern, _))
                | impossiblePattern corePattern -> go (close afterPattern) subjectKind done rest
              (afterPattern, Just (corePattern, _)) -> case maybe (afterPattern, Just Nothing) (fmap (fmap Just) . guardOf afterPattern) guard' of
                (afterGuard, Nothing) -> refused (close afterGuard)
                (afterGuard, Just coreGuard) -> case lower afterGuard body of
                  (afterBody, Nothing) -> refused (close afterBody)
                  (afterBody, Just (coreBody, bodyKind))
                    | discarded ->
                        let dropped = CoreExpression (locatedSpan body) (if bodyKind == CoreNeverType then CoreNeverType else CoreUnitType)
                              (CoreBlockValue (CoreBlock [CoreStatement (locatedSpan body) (CoreEvaluate coreBody)] Nothing))
                         in go (close afterBody) subjectKind (CoreArm armSpan corePattern coreGuard dropped : done) rest
                    | expressionIsPrintValued coreBody -> halt (locatedSpan body) "a match arm returning Result[(), Str]" (close afterBody)
                    | otherwise -> go (close afterBody) subjectKind (CoreArm armSpan corePattern coreGuard coreBody : done) rest
      guardOf current test = case lower current test of
        (next, Just (coreGuard, guardKind))
          | guardKind `elem` [CoreBoolType, CoreNeverType] -> (next, Just coreGuard)
          | otherwise -> halt (locatedSpan test) ("a guard of type " <> coreTypeName guardKind) next
        (next, Nothing) -> refused next

{-| The fallback sees the outer scope; only success publishes the pattern's
    locals into the enclosing block. Frame matching initializes those locals
    before its unit arm joins the following statement. -}
lowerLetElse :: LowerExpression -> LowerState -> Span -> Located Pattern -> Located Expression -> Located Block
  -> (LowerState, Maybe CoreStatement)
lowerLetElse lower state at pattern' subject fallback = case lowerMatchSubject lower state subject of
  (after, Nothing) -> refused after
  (after, Just (core, CoreNeverType)) -> evaluated after core
  (after, Just (core, kind))
    | expressionIsPrintValued core -> halt (locatedSpan subject) "matching a Result[(), Str] value" after
    | otherwise -> case lower after (Located (locatedSpan fallback) (BlockExpression fallback)) of
        (afterFallback, Nothing) -> refused afterFallback
        (afterFallback, Just (otherwise', CoreNeverType)) ->
          case lowerPattern lower afterFallback kind Map.empty pattern' of
            (afterPattern, Nothing) -> refused afterPattern
            (afterPattern, Just (matched, _))
              | impossiblePattern matched ->
                  let statements = [CoreStatement at (CoreEvaluate core)]
                   in evaluated afterPattern (CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock statements (Just otherwise'))))
            (afterPattern, Just (matched, _)) ->
              let unit = CoreExpression at CoreUnitType (CoreBlockValue (CoreBlock [] Nothing))
                  arms = [CoreArm (locatedSpan pattern') matched Nothing unit,
                          CoreArm (locatedSpan fallback) CoreWildcardPattern Nothing otherwise']
               in evaluated afterPattern (CoreExpression at CoreUnitType (CoreMatch core arms))
        (afterFallback, Just _) -> halt (locatedSpan fallback) "a let else fallback that does not diverge" afterFallback
 where
  evaluated after core = (after, Just (CoreStatement at (CoreEvaluate core)))

{-| `let [a, ..rest] = subject`, at any depth of the pattern: the one test a
    destructuring binding can fail is a sequence's length, and it stops the
    program at the pattern, naming what the subject is. -}
lowerLetSequence :: LowerExpression -> LowerState -> Span -> Located Pattern -> Located Expression
  -> (LowerState, Maybe CoreStatement)
lowerLetSequence lower state at pattern' subject = case lower state subject of
  (after, Nothing) -> refused after
  (after, Just (core, CoreNeverType)) -> evaluated after core
  (after, Just (core, kind))
    | expressionIsPrintValued core -> halt (locatedSpan subject) "matching a Result[(), Str] value" after
    | otherwise -> case lowerPattern lower after kind Map.empty pattern' of
        (afterPattern, Nothing) -> refused afterPattern
        (afterPattern, Just (matched, _)) ->
          let here = CoreExpression (locatedSpan pattern')
              (ready, failedSubject) = bindLocal afterPattern "" kind
              text = here CoreTextType
              append left right = text (CoreBinary CoreAdd left right)
              named = text (CoreRuntimeKind (here kind (CoreReadLocal failedSubject)))
              message = append (text (CoreTextLiteral "this pattern does not match the "))
                (append named (text (CoreTextLiteral " it was given")))
              stop = here CoreNeverType (CoreFailText "E7013" (Just "check the number of elements the pattern names against the value") message Nothing)
              unit = CoreExpression at CoreUnitType (CoreBlockValue (CoreBlock [] Nothing))
              arms = [CoreArm (locatedSpan pattern') matched Nothing unit | not (impossiblePattern matched)]
                <> [CoreArm at (CoreBindPattern failedSubject) Nothing stop]
              result = if impossiblePattern matched then CoreNeverType else CoreUnitType
           in evaluated ready (CoreExpression at result (CoreMatch core arms))
 where
  evaluated after core = (after, Just (CoreStatement at (CoreEvaluate core)))

{-| Whether a pattern tests a sequence's length anywhere inside it. -}
hasSequencePattern :: Located Pattern -> Bool
hasSequencePattern (Located _ shape) = case shape of
  ArrayPattern{} -> True
  TuplePattern members -> any hasSequencePattern members
  RecordPattern _ fields _ -> or [maybe False hasSequencePattern inner | Located _ (FieldPattern _ inner) <- fields]
  _ -> False

{-| `if let` as match arms: the pattern takes the block, anything else takes
    the `else` branch or unit. -}
ifLetArms :: Span -> Located Pattern -> Located Block -> Maybe (Located Expression) -> [Located MatchArm]
ifLetArms at pattern' taken otherwise' =
  [ Located at (MatchArm pattern' Nothing (Located (locatedSpan taken) (BlockExpression taken)))
  , Located at (MatchArm (Located at WildcardPattern) Nothing (maybe (Located at (TupleExpression [])) id otherwise'))
  ]

{-| `while let` as a `loop` whose body matches the subject afresh each turn
    and breaks on the first value the pattern refuses. -}
whileLetLoop :: Span -> Maybe (Located Text) -> Located Pattern -> Located Expression -> Located Block -> Located Expression
whileLetLoop at label pattern' subject body =
  let stop = Located at (BlockExpression (Located at (Block [Located at (BreakStatement Nothing Nothing)] Nothing)))
      arms =
        [ Located at (MatchArm pattern' Nothing (Located (locatedSpan body) (BlockExpression body)))
        , Located at (MatchArm (Located at WildcardPattern) Nothing stop)
        ]
      turn = Located at (ExpressionStatement (Located at (MatchExpression subject arms)))
   in Located at (LoopExpression label (Located at (Block [turn] Nothing)))

{-| A pattern against a value of the given type. Names already bound by an
    earlier alternative of the same pattern reuse their locals. -}
lowerPattern :: LowerExpression -> LowerState -> CoreType -> Map Text CoreLocal -> Located Pattern
  -> (LowerState, Maybe (CorePattern, Map Text CoreLocal))
lowerPattern lower state kind bound (Located at shape) = case shape of
  _ | isDynamic kind
    , Just owner <- nominalPatternOwner shape
    , variants@(_ : _) <-
        [ (coreVariantName variant, payload)
        | variant <- maybe [] id (sumVariants types kind)
        , [(_, payload)] <- [coreVariantFields variant]
        , ownerKeyOf payload == Just owner ] ->
        narrowed state bound [] variants
  WildcardPattern -> done state CoreWildcardPattern bound
  BindingPattern (Located _ name) -> case Map.lookup name bound of
    Just local
      | coreLocalType local == kind -> done state (CoreBindPattern local) bound
      | otherwise -> halt at "a pattern binding with incompatible native carriers" state
    Nothing ->
      let (after, local) = bindLocal state name kind
       in done after (CoreBindPattern local) (Map.insert name local bound)
  -- Integers compare by value whatever their kind (sameValue), so the literal
  -- is built at the subject's kind; one the kind cannot hold never matches,
  -- and an empty alternative is a pattern that never does.
  _ | Just variants <- runtimeChoiceAlternatives kind ->
        narrowed state bound [] variants
  LiteralPattern literal
    | CoreIntegerType integerKind <- kind, Just number <- integerOf literal ->
        if integerKindFits integerKind number
          then done state (CoreLiteralPattern (integer integerKind number)) bound
          else done state never bound
  LiteralPattern literal -> case lower state (Located at (LiteralExpression literal)) of
    (after, Just (core, literalKind))
      | literalKind == kind -> done after (CoreLiteralPattern core) bound
      | otherwise -> done after never bound
    (after, Nothing) -> refused after
  RangePattern low inclusive high
    | CoreIntegerType integerKind <- kind, Just from <- integerOf low, Just to <- integerOf high
    , Just (smallest, largest) <- integerKindBounds integerKind ->
        let start = max from smallest
            (end, closed) = if to > largest then (largest, True) else (to, inclusive)
         in if start > largest || end < smallest || start > end || (start == end && not closed)
              then done state never bound
              else done state (CoreRangePattern (integer integerKind start) closed (integer integerKind end)) bound
  RangePattern low inclusive high
    | CoreIntegerType integerKind <- kind, Just from <- integerOf low, Just to <- integerOf high
    , Nothing <- integerKindBounds integerKind ->
        done state (CoreRangePattern (integer integerKind from) inclusive (integer integerKind to)) bound
  RangePattern low inclusive high -> case (lower state (Located at (LiteralExpression low)), lower state (Located at (LiteralExpression high))) of
    ((_, Just (lower', lowKind)), (after, Just (upper', highKind)))
      | lowKind == kind && highKind == kind -> done after (CoreRangePattern lower' inclusive upper') bound
      | otherwise -> done after never bound
    ((after, Nothing), _) -> refused after
    (_, (after, Nothing)) -> refused after
  TuplePattern members -> case kind of
    CoreTupleType kinds | length kinds == length members -> sequenceOf CoreTuplePattern state bound (zip kinds members)
    _ -> done state never bound
  ConstructorPattern written members -> case variantOf (writtenLabel written) of
    Just variant
      | not (coreVariantRecord variant), length (coreVariantFields variant) == length members ->
          sequenceOf (CoreVariantPattern (coreVariantName variant)) state bound (zip (map snd (coreVariantFields variant)) members)
    _ -> done state never bound
  RecordPattern path fields _ -> case (path, recordFields types kind) of
    (Nothing, Just declared) -> recordMembers CoreRecordPattern declared fields
    (Just written, Just declared)
      | CoreRecordType name _ <- kind, displayName name == writtenLabel written -> recordMembers CoreRecordPattern declared fields
    (Just written, Nothing)
      | Just variant <- variantOf (writtenLabel written), coreVariantRecord variant ->
          recordMembers (CoreVariantPattern (coreVariantName variant)) (coreVariantFields variant) fields
    _ -> done state never bound
  AlternativePattern alternatives -> alternativesOf state bound [] alternatives
  ArrayPattern front rest back -> case kind of
    CoreArrayType element -> case sequenceOf CoreTuplePattern state bound [(element, member) | member <- front] of
      (afterFront, Just (CoreTuplePattern fronts, withFront)) ->
        let (afterRest, restPattern, withRest) = case rest of
              Nothing -> (afterFront, Nothing, withFront)
              Just (IgnoredRest _) -> (afterFront, Just Nothing, withFront)
              Just (BoundRest (Located _ name)) -> case Map.lookup name withFront of
                Just local -> (afterFront, Just (Just local), withFront)
                Nothing ->
                  let (next, local) = bindLocal afterFront name kind
                   in (next, Just (Just local), Map.insert name local withFront)
         in case lowerSequence afterRest withRest [(element, member) | member <- back] of
              (afterBack, Just (backs, withBack)) -> done afterBack (CoreArrayPattern fronts restPattern backs) withBack
              (afterBack, Nothing) -> (afterBack, Nothing)
      (afterFront, _) -> (afterFront, Nothing)
    _ -> done state never bound
  _ -> halt at "this pattern" state
 where
  types = contextTypes (lowerContext state)
  done current pattern' names = (current, Just (pattern', names))
  never = CoreAlternativePattern []
  integer integerKind number = CoreExpression at (CoreIntegerType integerKind) (CoreIntegerLiteral integerKind number)
  integerOf literal = case literal of
    ResolvedInteger _ number -> Just number
    IntegerValue text -> parsedIntegerValue <$> parseIntegerLiteral text
    _ -> Nothing
  variantOf name = sumVariants types kind >>= find ((== name) . coreVariantName)
  narrowed current names collected [] =
    done current (case collected of { [one] -> one; _ -> CoreAlternativePattern (reverse collected) }) names
  narrowed current names collected ((tag, payload) : rest) =
    case lowerPattern lower current payload names (Located at shape) of
      (after, Just (inner, bindings))
        | impossiblePattern inner -> narrowed after{lowerScopes = lowerScopes current} names collected rest
        | otherwise -> narrowed after bindings (CoreVariantPattern tag [inner] : collected) rest
      (after, Nothing) -> refused after
  lowerSequence current names pairs = case sequenceOf CoreTuplePattern current names pairs of
    (after, Just (CoreTuplePattern members, names')) -> (after, Just (members, names'))
    (after, _) -> (after, Nothing)
  sequenceOf build current names [] = done current (build []) names
  sequenceOf build current names pairs = go current names [] pairs
   where
    go state' names' collected [] = done state' (build (reverse collected)) names'
    go state' names' collected ((memberKind, member) : rest) = case lowerPattern lower state' memberKind names' member of
      (next, Just (pattern', after)) -> go next after (pattern' : collected) rest
      (next, Nothing) -> (next, Nothing)
  -- Declared order, a wildcard for every field the pattern leaves out; `{x}`
  -- is `{x: x}`.
  recordMembers build declared fields =
    let written = [(locatedValue name, (nameSpan, inner)) | Located _ (FieldPattern name@(Located nameSpan _) inner) <- fields]
        member (name, fieldKind) = case lookup name written of
          Nothing -> (fieldKind, Located at WildcardPattern)
          Just (nameSpan, inner) -> (fieldKind, maybe (Located nameSpan (BindingPattern (Located nameSpan name))) id inner)
     in if all ((`elem` map fst declared) . fst) written
          then sequenceOf build state bound (map member declared)
          else done state never bound
  alternativesOf current names collected [] = done current (CoreAlternativePattern (reverse collected)) names
  alternativesOf current names collected (alternative : rest) = case lowerPattern lower current kind names alternative of
    (next, Just (pattern', after)) -> alternativesOf next after (pattern' : collected) rest
    (next, Nothing) -> (next, Nothing)

impossiblePattern :: CorePattern -> Bool
impossiblePattern shape = case shape of
  CoreAlternativePattern alternatives -> all impossiblePattern alternatives
  CoreTuplePattern members -> any impossiblePattern members
  CoreRecordPattern fields -> any impossiblePattern fields
  CoreVariantPattern _ fields -> any impossiblePattern fields
  CoreArrayPattern front _ back -> any impossiblePattern (front <> back)
  _ -> False

nominalPatternOwner :: Pattern -> Maybe Text
nominalPatternOwner shape = case shape of
  ConstructorPattern written _
    | (qualified, _) <- Text.breakOnEnd "." (pathText written)
    , not (Text.null qualified) -> Just (Text.dropEnd 1 qualified)
  RecordPattern (Just (ModuleName ("::sum::" :| [owner, _]))) _ _ -> Just owner
  RecordPattern (Just written) _ _ -> Just (pathText written)
  _ -> Nothing
