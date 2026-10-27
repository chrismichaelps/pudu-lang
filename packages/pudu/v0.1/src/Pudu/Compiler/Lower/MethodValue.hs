{-| @Pudu.Compiler.Lower.MethodValue — built-in methods taken as values, like
    `text.length` or `items.push`. The receiver runs once, when the value is
    made, and is kept as the closure's capture. Calling the value runs the
    method on it through the same lowering a written call gets. -}
module Pudu.Compiler.Lower.MethodValue (lowerMethodValue) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.State
  ( LowerContext (..), LowerState (..), bindLocal, refuse, refused, startFunction )
import Pudu.Compiler.Lower.Types (typeFactAt, typeForSpan, withFacts)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Data.Maybe (fromMaybe)
import Pudu.Source (Span (..), offsetFromInt, zeroOffset)
import Pudu.Type.Value (Type (FunctionTypeRequiring))

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| Nothing unless the receiver is a built-in value and checking typed the
    member as a function. -}
lowerMethodValue :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> Maybe Lowered
lowerMethodValue lower state at receiver member = case (typeForSpan types (locatedSpan receiver), typeForSpan types at, typeFactAt types at) of
  (Just receiverType, Just kind@(CoreFunctionType inputs result), Just (FunctionTypeRequiring _ inputFacts _ resultFact))
    | builtIn receiverType, length inputs == length inputFacts -> Just $ case lower state receiver of
        (after, Nothing) -> refused after
        (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
        (after, Just (core, _)) ->
          let key = "$method:" <> member <> ":" <> Text.pack (show receiverType) <> ":" <> Text.pack (show kind)
              made = if Map.member key (contextClosures (lowerContext after)) then after
                else register after key receiverType kind inputs result inputFacts resultFact
           in (made, Just (CoreExpression at kind (CoreClosure key [core]), kind))
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

  -- The lifted body is `$receiver.member($1, ...)`. The receiver keeps its
  -- own span and fact; the call's span answers the method's result and each
  -- argument gets a span of its own, made up, with its parameter's fact.
  register current key receiverType kind inputs result inputFacts resultFact =
    let env = CoreLocal 0 "" kind
        parameters = [CoreParameter (CoreLocal index (argumentName index) input) at | (index, input) <- zip [1 ..] inputs]
        entered = (startFunction current (CoreParameter env at : parameters) (Just result)){lowerCurrentKey = key, lowerDeclaredResult = Nothing}
        (withReceiver, held) = bindLocal entered "$receiver" receiverType
        captured = CoreExpression at receiverType (CoreCapture 0 (CoreExpression at kind (CoreReadLocal env)))
        -- Past the end of any source, so no site made from one has a position.
        beyond index = fromMaybe zeroOffset (offsetFromInt (maxBound - index))
        argumentSpans = [at{spanStart = beyond index, spanEnd = beyond index} | index <- [1 .. length inputs]]
        original = contextTypes (lowerContext current)
        overlaid = withReceiver{lowerContext = (lowerContext withReceiver)
          {contextTypes = withFacts ((at, resultFact) : zip argumentSpans inputFacts) original}}
        call = Located at (CallExpression
          (Located at (MemberExpression (Located (locatedSpan receiver) (NameExpression ("$receiver" :| []))) (Located at member)))
          [Located spanValue (NameExpression (argumentName index :| [])) | (index, spanValue) <- zip [1 ..] argumentSpans])
        (afterBody, lowered) = lower overlaid call
        context = (lowerContext afterBody){contextTypes = original}
        before = length (contextRefusals (lowerContext current))
        -- Refusals inside point at made-up spans; one at the member says it.
        settled = if length (contextRefusals context) > before
          then refuse at ("the method value '" <> member <> "'") current{lowerContext = context{contextRefusals = drop (length (contextRefusals context) - before) (contextRefusals context)}}
          else current{lowerContext = context}
     in case lowered of
          Just (body, _) | length (contextRefusals context) == before ->
            let lifted = CoreFunction key (CoreParameter env at : parameters) result
                  (CoreBlock [CoreStatement at (CoreDeclare held captured)] (Just body))
                info = CoreClosureInfo [receiverType] member ("method " <> member <> " " <> Text.pack (show receiverType)) False True (Just receiverType)
                registered = (lowerContext settled)
                  { contextFunctions = lifted : contextFunctions (lowerContext settled)
                  , contextClosures = Map.insert key info (contextClosures (lowerContext settled))
                  }
             in settled{lowerContext = registered}
          _ -> settled
  argumentName index = "$" <> Text.pack (show (index :: Int))
