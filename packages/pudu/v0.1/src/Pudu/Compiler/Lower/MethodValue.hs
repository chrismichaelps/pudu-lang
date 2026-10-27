{-| @Pudu.Compiler.Lower.MethodValue — methods taken as values, like
    `text.length`, `items.push` or a trait's `bot.label`. The receiver runs once, when the value is
    made, and is kept as the closure's capture. Calling the value runs the
    method on it through the same lowering a written call gets. -}
module Pudu.Compiler.Lower.MethodValue (lowerMethodValue) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.State
  ( LowerContext (..), LowerState (..), bindLocal, lookupLocal, refuse, refused, startFunction )
import Pudu.Compiler.Lower.Types (ownerKeyOf, recordFields, typeFactAt, typeForSpan, withFacts)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Data.Maybe (fromMaybe, isJust, isNothing)
import Pudu.Source (Span (..), offsetFromInt, zeroOffset)
import Pudu.Type.Value (Type (FunctionTypeRequiring))

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| Nothing unless checking typed the member as a function and it is a
    method: of a built-in value, or of a declared type that has no field of
    that name (a field holding a function is read, not bound). `Bot.label`,
    with a type for a receiver, is the method itself, taking `self` first. -}
lowerMethodValue :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> Maybe Lowered
lowerMethodValue lower state at receiver member = case (typeForSpan types (locatedSpan receiver), typeForSpan types at, typeFactAt types at) of
  (Just receiverType, Just kind@(CoreFunctionType inputs _), Just fact@(FunctionTypeRequiring _ inputFacts _ _))
    | builtIn receiverType || declared receiverType, length inputs == length inputFacts -> Just $ case lower state receiver of
        (after, Nothing) -> refused after
        (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
        (after, Just (core, _)) ->
          let key = "$method:" <> member <> ":" <> Text.pack (show receiverType) <> ":" <> Text.pack (show kind)
           in (ensure after key (Just receiverType) kind fact, Just (CoreExpression at kind (CoreClosure key [core]), kind))
  (Nothing, Just kind@(CoreFunctionType inputs@(self : _) _), Just fact@(FunctionTypeRequiring _ inputFacts _ _))
    | Located _ (NameExpression (owner :| [])) <- receiver, Nothing <- lookupLocal state owner
    , declared self, ownerKeyOf self == Just owner || fmap displayName (ownerKeyOf self) == Just owner
    , length inputs == length inputFacts ->
        let key = "$method:" <> owner <> "." <> member <> ":" <> Text.pack (show kind)
         in Just (ensure state key Nothing kind fact, Just (CoreExpression at kind (CoreClosure key []), kind))
  _ -> Nothing
 where
  types = contextTypes (lowerContext state)
  builtIn kind = case kind of
    CoreTextType -> True
    CoreArrayType _ -> True
    CoreMapType _ _ -> True
    CoreSetType _ -> True
    CoreRangeType -> True
    CoreCharType -> True
    CoreBytesType -> True
    _ -> False
  declared kind = case kind of
    CoreRecordType _ _ -> isNothing (recordFields types kind >>= lookup member)
    CoreSumType _ _ -> True
    _ -> False
  ensure current key bound kind fact
    | Map.member key (contextClosures (lowerContext current)) = current
    | otherwise = register current key bound kind fact

  -- The lifted body is the written call: `$receiver.member($1, ...)` for a
  -- bound value, `Owner.member($1, ...)` for one named through its type.
  -- The receiver keeps its own span and fact; the call's span answers the
  -- method's result and each argument gets a made-up span with its
  -- parameter's fact.
  register current key bound kind@(CoreFunctionType inputs result) (FunctionTypeRequiring _ inputFacts _ resultFact) =
    let env = CoreLocal 0 "" kind
        offset = maybe 0 (const 1) bound
        parameters = [CoreParameter (CoreLocal (index - 1 + offset) (argumentName index) input) at | (index, input) <- zip [1 ..] inputs]
        hidden = [CoreParameter env at | Just _ <- [bound]]
        entered = (startFunction current (hidden <> parameters) (Just result)){lowerCurrentKey = key, lowerDeclaredResult = Nothing}
        (withReceiver, prologue) = case bound of
          Just held' ->
            let (next, held) = bindLocal entered "$receiver" held'
                captured = CoreExpression at held' (CoreCapture 0 (CoreExpression at kind (CoreReadLocal env)))
             in (next, [CoreStatement at (CoreDeclare held captured)])
          Nothing -> (entered, [])
        -- Past the end of any source, so no site made from one has a position.
        beyond index = fromMaybe zeroOffset (offsetFromInt (maxBound - index))
        argumentSpans = [at{spanStart = beyond index, spanEnd = beyond index} | index <- [1 .. length inputs]]
        original = contextTypes (lowerContext current)
        overlaid = withReceiver{lowerContext = (lowerContext withReceiver)
          {contextTypes = withFacts ((at, resultFact) : zip argumentSpans inputFacts) original}}
        target = case bound of
          Just _ -> Located (locatedSpan receiver) (NameExpression ("$receiver" :| []))
          Nothing -> receiver
        call = Located at (CallExpression
          (Located at (MemberExpression target (Located at member)))
          [Located spanValue (NameExpression (argumentName index :| [])) | (index, spanValue) <- zip [1 ..] argumentSpans])
        (afterBody, lowered) = lower overlaid call
        context = (lowerContext afterBody){contextTypes = original}
        before = length (contextRefusals (lowerContext current))
        -- Refusals inside point at made-up spans; one at the member says it.
        settled = if length (contextRefusals context) > before
          then refuse at ("the method value '" <> member <> "'") current{lowerContext = context{contextRefusals = drop (length (contextRefusals context) - before) (contextRefusals context)}}
          else current{lowerContext = context}
        receiverType = maybe (case inputs of { self : _ -> self; [] -> CoreUnitType }) id bound
     in case lowered of
          Just (body, _) | length (contextRefusals context) == before ->
            let lifted = CoreFunction key (hidden <> parameters) result (CoreBlock prologue (Just body))
                info = CoreClosureInfo [receiverType | Just _ <- [bound]] member key False (isJust bound) (Just receiverType)
                registered = (lowerContext settled)
                  { contextFunctions = lifted : contextFunctions (lowerContext settled)
                  , contextClosures = Map.insert key info (contextClosures (lowerContext settled))
                  }
             in settled{lowerContext = registered}
          _ -> settled
  register current _ _ _ _ = current
  argumentName index = "$" <> Text.pack (show (index :: Int))
