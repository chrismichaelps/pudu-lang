{-| @Pudu.Compiler.Frame.Match — `match` as a chain of tests over one subject
    slot: each arm's pattern, then its guard, then its body, falling through
    to the next arm on any failed test. -}
module Pudu.Compiler.Frame.Match (MatchLowering (..), lowerMatch) where

import qualified Data.Map.Strict as Map
import Pudu.Compiler.Frame.State
  ( Build, BuildState (..), Flow (..), begin, bindLocal, fault, finish, freshLabel
  , getState, moveValue, saveValue, storeValue )
import Pudu.Core
import Pudu.Core.Frame
  ( FrameLabel, FrameSlot (..), FrameTerminator (..), FrameValue (..)
  , FrameValueShape (..), scalarOperator )
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

{-| What the body lowering lends this module. -}
data MatchLowering = MatchLowering
  { matchExpression :: CoreExpression -> Build Flow
  , matchScalar :: CoreExpression -> Build Flow
  , matchResult :: Span -> CoreType -> Build (Maybe FrameSlot)
  }

lowerMatch :: MatchLowering -> Span -> CoreType -> CoreExpression -> [CoreArm] -> Build Flow
lowerMatch lowering at kind subject arms = do
  held <- matchScalar lowering subject
  case held of
    Stopped -> pure Stopped
    Completed Nothing -> fault (Just at) "a match subject without a value"
    Completed (Just source) -> do
      join <- freshLabel
      destination <- matchResult lowering at kind
      reached <- tryArms source join destination arms
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
    CoreArm armSpan pattern' guard' body : rest -> do
      next <- freshLabel
      matches lowering armSpan pattern' source next
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
      bodyReached <- if not guarded then pure False else do
        flow <- matchExpression lowering body
        case flow of
          Stopped -> pure False
          Completed payload -> do
            maybe (pure ()) (\target -> moveValue armSpan target payload) destination
            finish (FrameJump Nothing join)
            pure True
      begin next
      laterReached <- tryArms source join destination rest
      pure (bodyReached || laterReached)

{-| Test one pattern against a slot, jumping to `failed` when it does not
    apply and binding its names when it does. -}
matches :: MatchLowering -> Span -> CorePattern -> FrameSlot -> FrameLabel -> Build ()
matches lowering at pattern' source failed = case pattern' of
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
