{-| @Pudu.Compiler.Frame.Match — `match` as a chain of tests over one subject
    slot: each arm's pattern, then its guard, then its body, falling through
    to the next arm on any failed test. -}
module Pudu.Compiler.Frame.Match (MatchLowering (..), lowerMatch) where

import Control.Monad (unless)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Compiler.Frame.State
  ( Build, BuildState (..), Flow (..), begin, bindLocal, fault, finish, freshLabel
  , getState, moveValue, saveValue, storeValue )
import Pudu.Core
import Pudu.Core.Frame
  ( FrameLabel, FrameSlot (..), FrameTerminator (..), FrameValue (..)
  , FrameValueShape (..), scalarOperator )
import Pudu.IntegerLiteral (IntegerKind (..), integerKindWidth)
import Pudu.Source (Span)

{-| What the body lowering lends this module. -}
data MatchLowering = MatchLowering
  { matchExpression :: CoreExpression -> Build Flow
  , matchScalar :: CoreExpression -> Build Flow
  , matchResult :: Span -> CoreType -> Build (Maybe FrameSlot)
  }

lowerMatch :: MatchLowering -> Span -> CoreType -> CoreExpression -> [CoreArm] -> Build Flow
lowerMatch lowering at kind subject arms
  | CoreConstruct name written <- coreExpressionShape subject = do
      layouts <- buildLayouts <$> getState
      case Map.lookup (coreExpressionType subject) layouts of
        Just (CoreSumLayout variants)
          | Just variant <- lookup name [(coreVariantName item, item) | item <- variants]
          , Just (bindings, body) <- scalarArm name (coreVariantFields variant) written arms
          , coreExpressionType body `elem` [kind, CoreNeverType] ->
              direct bindings body [] written
        _ -> boxedMatch lowering at kind subject arms
  | otherwise = boxedMatch lowering at kind subject arms
 where
  direct bindings body done remaining = case remaining of
    [] -> do
      mapM_ (\(label, local) -> case lookup label done of
        Just payload -> bindLocal at local >>= \target -> moveValue at target (Just payload)
        Nothing -> fault (Just at) "a variant binding without its constructed field") bindings
      matchExpression lowering body
    (label, operand) : rest -> do
      flow <- matchScalar lowering operand
      case flow of
        Stopped -> pure Stopped
        Completed Nothing -> fault (Just at) "a constructed scalar without a value"
        Completed (Just payload) -> direct bindings body ((label, payload) : done) rest

{-| Select a branch without boxing only when no reachable test can depend on
    the payload and no arm needs the whole constructor value. -}
scalarArm :: Text -> [(Text, CoreType)] -> [(Text, CoreExpression)] -> [CoreArm]
  -> Maybe ([(Text, CoreLocal)], CoreExpression)
scalarArm name fields written arms
  | length fields == length written
  , all (\(label, kind) -> scalar kind && lookup label operands == Just kind) fields = choose arms
  | otherwise = Nothing
 where
  operands = [(label, coreExpressionType value) | (label, value) <- written]
  scalar kind = case kind of
    CoreIntegerType integer -> integer /= ExactIntKind && maybe False (<= 64) (integerKindWidth integer)
    CoreFloatType{} -> True
    CoreBoolType -> True
    CoreCharType -> True
    CoreUnitType -> True
    _ -> False
  choose [] = Nothing
  choose (CoreArm _ pattern' guard' body : rest) = case pattern' of
    CoreVariantPattern variant members
      | variant /= name -> choose rest
      | Nothing <- guard', length members == length fields -> do
          bindings <- traverse binding (zip fields members)
          pure (concat bindings, body)
    CoreWildcardPattern | Nothing <- guard' -> Just ([], body)
    _ -> Nothing
  binding ((label, kind), pattern') = case pattern' of
    CoreWildcardPattern -> Just []
    CoreBindPattern local | coreLocalType local == kind -> Just [(label, local)]
    _ -> Nothing

boxedMatch :: MatchLowering -> Span -> CoreType -> CoreExpression -> [CoreArm] -> Build Flow
boxedMatch lowering at kind subject arms = do
  held <- matchScalar lowering subject
  case held of
    Stopped -> pure Stopped
    Completed Nothing -> fault (Just at) "a match subject without a value"
    Completed (Just source) -> do
      join <- freshLabel
      destination <- matchResult lowering at kind
      layouts <- buildLayouts <$> getState
      reached <- case Map.lookup (frameSlotType source) layouts of
        Just (CoreSumLayout variants)
          | Just (cases, fallback) <- variantCases variants arms ->
              switchArms source join destination cases fallback
        _ -> tryArms source join destination arms
      if reached then begin join >> pure (Completed destination) else pure Stopped
 where
  tryArms source join destination remaining = case remaining of
    [] -> do
      -- No arm took the subject: the evaluator renders it into the message.
      let text kindOf shape = saveValue (FrameValue at kindOf shape)
      prefix <- text CoreTextType (FrameTextLiteral "no match arm accepted ")
      shown <- text CoreTextType (FrameShow source)
      message <- case scalarOperator CoreAdd of
        Just add -> text CoreTextType (FrameBinary add prefix shown)
        Nothing -> fault (Just at) "text concatenation without an operator"
      finish (FrameFailText at "E7011" (Just "add a case that covers this value") message Nothing)
      pure False
    arm : rest -> do
      next <- freshLabel
      bodyReached <- emitArm False source join destination next arm
      begin next
      laterReached <- tryArms source join destination rest
      pure (bodyReached || laterReached)
  switchArms source join destination cases fallback = do
    next <- freshLabel
    labels <- traverse (const freshLabel) cases
    finish (FrameSwitchVariant at source (zip (map fst cases) labels) next)
    reached <- sequence
      [begin label >> emitArm True source join destination next arm | (label, (_, arm)) <- zip labels cases]
    begin next
    defaultReached <- tryArms source join destination fallback
    pure (or reached || defaultReached)
  emitArm tagSelected source join destination next (CoreArm armSpan pattern' guard' body) = do
    matchWithTag tagSelected lowering armSpan pattern' source next
    guarded <- case guard' of
      Nothing -> pure True
      Just test -> do
        verdict <- matchScalar lowering test
        case verdict of
          Stopped -> pure False
          Completed Nothing -> fault (Just armSpan) "a guard without a value"
          Completed (Just slot) -> do
            taken <- freshLabel
            finish (FrameBranch armSpan slot taken next)
            begin taken
            pure True
    if not guarded then pure False else do
      flow <- matchExpression lowering body
      case flow of
        Stopped -> pure False
        Completed payload -> do
          maybe (pure ()) (\target -> moveValue armSpan target payload) destination
          finish (FrameJump Nothing join)
          pure True

variantCases :: [CoreVariant] -> [CoreArm] -> Maybe ([(Int, CoreArm)], [CoreArm])
variantCases variants arms = do
  let (tagged, fallback) = span isTagged arms
  cases <- traverse identify tagged
  case fallback of
    [] -> distinct cases fallback
    [arm] | isCatchAll (coreArmPattern arm) -> distinct cases fallback
    _ -> Nothing
 where
  indices = Map.fromList [(coreVariantName variant, index) | (index, variant) <- zip [0 ..] variants]
  isTagged arm = case coreArmPattern arm of
    CoreVariantPattern{} -> True
    _ -> False
  isCatchAll pattern' = case pattern' of
    CoreWildcardPattern -> True
    CoreBindPattern{} -> True
    _ -> False
  identify arm = case coreArmPattern arm of
    CoreVariantPattern name _ -> fmap (\tag -> (tag, arm)) (Map.lookup name indices)
    _ -> Nothing
  distinct cases fallback
    | length cases >= 2, Set.size (Set.fromList (map fst cases)) == length cases = Just (cases, fallback)
    | otherwise = Nothing

{-| Test one pattern against a slot, jumping to `failed` when it does not
    apply and binding its names when it does. -}
matches :: MatchLowering -> Span -> CorePattern -> FrameSlot -> FrameLabel -> Build ()
matches = matchWithTag False

matchWithTag :: Bool -> MatchLowering -> Span -> CorePattern -> FrameSlot -> FrameLabel -> Build ()
matchWithTag tagSelected lowering at pattern' source failed = case pattern' of
  CoreWildcardPattern -> pure ()
  CoreBindPattern local -> do
    target <- bound local
    storeValue at target (Just source)
  CoreLiteralPattern literal -> do
    value <- operand literal
    test CoreEqual source value
  CoreRangePattern low inclusive high -> do
    lower <- operand low
    upper <- operand high
    test CoreGreaterOrEqual source lower
    test (if inclusive then CoreLessOrEqual else CoreLess) source upper
  CoreTuplePattern members -> positions FrameMember members
  CoreRecordPattern members -> positions FrameMember members
  CoreVariantPattern name members -> do
    layouts <- buildLayouts <$> getState
    case Map.lookup (frameSlotType source) layouts of
      Just (CoreSumLayout variants)
        | Just (index, variant) <- lookup name [(coreVariantName v, (i, v)) | (i, v) <- zip [0 ..] variants] -> do
            unless tagSelected $ do
              holds <- saveValue (FrameValue at CoreBoolType (FrameIsVariant index source))
              branch holds
            sequence_
              [ member (FramePayload position source) fieldKind inner
              | (position, ((_, fieldKind), inner)) <- zip [0 ..] (zip (coreVariantFields variant) members)
              , inner /= CoreWildcardPattern ]
      _ -> fault (Just at) "a variant pattern on a value without that variant"
  -- The length decides first, as `matchPattern` checks it before reading.
  CoreArrayPattern front rest back -> do
    element <- case frameSlotType source of
      CoreArrayType held -> pure held
      _ -> fault (Just at) "a sequence pattern on a value that is not an array"
    let named = length front + length back
        intType = CoreIntegerType PlatformSigned
        integer number = FrameValue at intType (FrameIntegerLiteral PlatformSigned (toInteger number))
        arithmetic operator left right = case scalarOperator operator of
          Just scalar -> saveValue (FrameValue at intType (FrameBinary scalar left right))
          Nothing -> fault (Just at) "a sequence position without an operator"
    count <- saveValue (FrameValue at intType (FrameArrayMethod ArrayLengthOf source []))
    wanted <- saveValue (integer named)
    test (if rest == Nothing then CoreEqual else CoreGreaterOrEqual) count wanted
    sequence_
      [ do
          position <- saveValue (integer index)
          member (FrameIndex source position) element inner
      | (index, inner) <- zip [0 :: Int ..] front, inner /= CoreWildcardPattern ]
    skipped <- saveValue (integer (length back))
    start <- arithmetic CoreSubtract count skipped
    sequence_
      [ do
          offset <- saveValue (integer index)
          position <- arithmetic CoreAdd start offset
          member (FrameIndex source position) element inner
      | (index, inner) <- zip [0 :: Int ..] back, inner /= CoreWildcardPattern ]
    case rest of
      Just (Just local) -> do
        from <- saveValue (integer (length front))
        target <- bound local
        middle <- saveValue (FrameValue at (frameSlotType source) (FrameArrayMethod ArraySliceOf source [from, start]))
        storeValue at target (Just middle)
      _ -> pure ()
  CoreAlternativePattern alternatives -> do
    matched <- freshLabel
    let go [] = finish (FrameJump Nothing failed)
        go (alternative : rest) = do
          next <- freshLabel
          matches lowering at alternative source next
          finish (FrameJump Nothing matched)
          begin next
          go rest
    go alternatives
    begin matched
  CoreProjectPattern inner copies -> do
    matches lowering at inner source failed
    sequence_
      [ do
          value <- operand expression
          slot <- bound local
          storeValue at slot (Just value)
      | (local, expression) <- copies ]
 where
  positions shape members = do
    kinds <- memberKinds (length members)
    sequence_ [ member (shape position source) kind inner
              | (position, (kind, inner)) <- zip [0 ..] (zip kinds members), inner /= CoreWildcardPattern ]
  memberKinds count = case frameSlotType source of
    CoreTupleType kinds | length kinds == count -> pure kinds
    kind -> do
      layouts <- buildLayouts <$> getState
      case Map.lookup kind layouts of
        Just (CoreRecordLayout fields) | length fields == count -> pure (map snd fields)
        _ -> fault (Just at) "a positional pattern on a value without those members"
  member shape kind inner = do
    slot <- saveValue (FrameValue at kind shape)
    matches lowering at inner slot failed
  operand literal = do
    flow <- matchScalar lowering literal
    case flow of
      Completed (Just slot) -> pure slot
      _ -> fault (Just at) "a pattern literal without a value"
  test operator left right = case scalarOperator operator of
    Just scalar -> do
      verdict <- saveValue (FrameValue at CoreBoolType (FrameBinary scalar left right))
      branch verdict
    Nothing -> fault (Just at) "a pattern test without an operator"
  branch verdict = do
    continue <- freshLabel
    finish (FrameBranch at verdict continue failed)
    begin continue
  -- Alternatives bind the same locals; the first one to run creates the slot.
  bound local = do
    existing <- Map.lookup (coreLocalId local) . buildLocals <$> getState
    maybe (bindLocal at local) pure existing
