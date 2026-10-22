{-| @Pudu.Compiler.Lower.Match — `match`: the subject, then each arm's
    pattern, guard and body in a scope of its own. -}
module Pudu.Compiler.Lower.Match (lowerMatch, lowerLetElse, ifLetArms, whileLetLoop) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.List (find)
import qualified Data.List.NonEmpty as NonEmpty
import Pudu.Compiler.Lower.Control (expressionIsPrintValued, joinType)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, refused)
import Pudu.Compiler.Lower.Types (recordFields, sumVariants)
import Pudu.Core
import Pudu.Frontend.Syntax
  ( Block (..), Expression (..), FieldPattern (..), Literal (..), Located (..), MatchArm (..), Pattern (..)
  , Statement (..) )
import Pudu.IntegerLiteral (ParsedInteger (..), integerKindBounds, integerKindFits, parseIntegerLiteral)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Source (Span)
import Data.Text (Text)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

{-| When `discarded`, the match is a statement: each arm's value is evaluated
    and dropped, so an arm may end in `print(...)`. -}
lowerMatch :: LowerExpression -> Bool -> LowerState -> Span -> Located Expression -> [Located MatchArm]
  -> (LowerState, Maybe (CoreExpression, CoreType))
lowerMatch lower discarded state at subject arms = case lower state subject of
  (after, Nothing) -> refused after
  (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
  (after, Just (core, kind))
    | expressionIsPrintValued core -> halt (locatedSpan subject) "matching a Result[(), Str] value" after
    | otherwise -> go after kind [] arms
     where
      go current _ done [] =
        let lowered = reverse done
         in case foldr (\arm found -> found >>= joinType (coreExpressionType (coreArmBody arm))) (Just CoreNeverType) lowered of
              Just result -> (current, Just (CoreExpression at result (CoreMatch core lowered), result))
              Nothing -> halt at "a match whose arms have different types" current
      go current subjectKind done (Located armSpan (MatchArm pattern' guard' body) : rest) =
        let opened = current{lowerScopes = [] : lowerScopes current}
            close next = next{lowerScopes = drop 1 (lowerScopes next)}
         in case lowerPattern lower opened subjectKind Map.empty pattern' of
              (afterPattern, Nothing) -> refused (close afterPattern)
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
lowerLetElse lower state at pattern' subject fallback = case lower state subject of
  (after, Nothing) -> refused after
  (after, Just (core, CoreNeverType)) -> evaluated after core
  (after, Just (core, kind))
    | expressionIsPrintValued core -> halt (locatedSpan subject) "matching a Result[(), Str] value" after
    | otherwise -> case lower after (Located (locatedSpan fallback) (BlockExpression fallback)) of
        (afterFallback, Nothing) -> refused afterFallback
        (afterFallback, Just (otherwise', CoreNeverType)) ->
          case lowerPattern lower afterFallback kind Map.empty pattern' of
            (afterPattern, Nothing) -> refused afterPattern
            (afterPattern, Just (matched, _)) ->
              let unit = CoreExpression at CoreUnitType (CoreBlockValue (CoreBlock [] Nothing))
                  arms = [CoreArm (locatedSpan pattern') matched Nothing unit,
                          CoreArm (locatedSpan fallback) CoreWildcardPattern Nothing otherwise']
               in evaluated afterPattern (CoreExpression at CoreUnitType (CoreMatch core arms))
        (afterFallback, Just _) -> halt (locatedSpan fallback) "a let else fallback that does not diverge" afterFallback
 where
  evaluated after core = (after, Just (CoreStatement at (CoreEvaluate core)))

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
  WildcardPattern -> done state CoreWildcardPattern bound
  BindingPattern (Located _ name) -> case Map.lookup name bound of
    Just local -> done state (CoreBindPattern local) bound
    Nothing ->
      let (after, local) = bindLocal state name kind
       in done after (CoreBindPattern local) (Map.insert name local bound)
  -- Integers compare by value whatever their kind (sameValue), so the literal
  -- is built at the subject's kind; one the kind cannot hold never matches,
  -- and an empty alternative is a pattern that never does.
  LiteralPattern literal
    | CoreIntegerType integerKind <- kind, Just number <- integerOf literal ->
        if integerKindFits integerKind number
          then done state (CoreLiteralPattern (integer integerKind number)) bound
          else done state never bound
  LiteralPattern literal -> case lower state (Located at (LiteralExpression literal)) of
    (after, Just (core, literalKind))
      | literalKind == kind -> done after (CoreLiteralPattern core) bound
      -- A float of another width is never equal (Value's Eq compares widths).
      | CoreFloatType _ <- literalKind, CoreFloatType _ <- kind -> done after never bound
    (after, _) -> halt at "a literal pattern of another type" after
  RangePattern low inclusive high
    | CoreIntegerType integerKind <- kind, Just from <- integerOf low, Just to <- integerOf high
    , Just (smallest, largest) <- integerKindBounds integerKind ->
        let start = max from smallest
            (end, closed) = if to > largest then (largest, True) else (to, inclusive)
         in if start > largest || end < smallest || start > end || (start == end && not closed)
              then done state never bound
              else done state (CoreRangePattern (integer integerKind start) closed (integer integerKind end)) bound
  RangePattern low inclusive high -> case (lower state (Located at (LiteralExpression low)), lower state (Located at (LiteralExpression high))) of
    ((_, Just (lower', lowKind)), (after, Just (upper', highKind)))
      | lowKind == kind && highKind == kind -> done after (CoreRangePattern lower' inclusive upper') bound
    _ -> halt at "a range pattern of another type" state
  TuplePattern members -> case kind of
    CoreTupleType kinds | length kinds == length members -> sequenceOf CoreTuplePattern state bound (zip kinds members)
    _ -> halt at "a tuple pattern on this value" state
  ConstructorPattern (ModuleName segments) members -> case variantOf (NonEmpty.last segments) of
    Just variant
      | not (coreVariantRecord variant), length (coreVariantFields variant) == length members ->
          sequenceOf (CoreVariantPattern (coreVariantName variant)) state bound (zip (map snd (coreVariantFields variant)) members)
    _ -> halt at "this constructor pattern" state
  RecordPattern path fields _ -> case (path, recordFields types kind) of
    (Nothing, Just declared) -> recordMembers CoreRecordPattern declared fields
    (Just (ModuleName segments), Just declared)
      | CoreRecordType name <- kind, displayName name == NonEmpty.last segments -> recordMembers CoreRecordPattern declared fields
    (Just (ModuleName segments), Nothing)
      | Just variant <- variantOf (NonEmpty.last segments), coreVariantRecord variant ->
          recordMembers (CoreVariantPattern (coreVariantName variant)) (coreVariantFields variant) fields
    _ -> halt at "this record pattern" state
  AlternativePattern alternatives -> alternativesOf state bound [] alternatives
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
          else halt at "a record pattern naming an undeclared field" state
  alternativesOf current names collected [] = done current (CoreAlternativePattern (reverse collected)) names
  alternativesOf current names collected (alternative : rest) = case lowerPattern lower current kind names alternative of
    (next, Just (pattern', after)) -> alternativesOf next after (pattern' : collected) rest
    (next, Nothing) -> (next, Nothing)
