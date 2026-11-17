{-| Checked foreign callback signatures and native argument positions shared
    by declaration checking and the two foreign dispatch paths. -}
module Pudu.Foreign.Callback
  ( CallbackFault (..)
  , CallbackParameter (..)
  , CallbackResult (..)
  , CallbackSignature (..)
  , CallbackPair (..)
  , checkCallbackDeclarations
  , callbackPairs
  ) where

import Control.Monad (foldM, guard, unless, when)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.FloatLiteral
  ( FloatWidth (..), ParsedFloat (..), parseFloatLiteral, splitFloatSuffix )
import Pudu.Foreign.Crossing
  ( Crossing (..), RecordLayouts, crossingFor, fitsCrossing, foreignArgumentLimit )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( ForeignCallback (..), ForeignCallbackParameter (..), ForeignFunction (..)
  , ForeignParameter (..), Literal (..), TypeSyntax (..) )
import Pudu.IntegerLiteral
  ( IntegerSuffix (..), ParsedInteger (..), parseIntegerLiteral )
import Pudu.Source (Span, spanStart)

data CallbackFault = CallbackFault !Span !Text
  deriving stock (Eq, Show)

{-| One native trampoline parameter. A handle crossing here is borrowed for
    the invocation. -}
data CallbackParameter = CallbackContext | CallbackValue !Crossing
  deriving stock (Eq, Show)

{-| A non-void result always carries its checked failure value. The float
    payload preserves its declared rounding and signed zero. -}
data CallbackResult
  = CallbackVoid
  | CallbackSigned !Int !Integer
  | CallbackUnsigned !Int !Integer
  | CallbackFloat !FloatWidth !Double
  | CallbackBool !Bool
  deriving stock (Eq, Show)

data CallbackSignature = CallbackSignature
  { callbackParameters :: ![CallbackParameter]
  , callbackResult :: !CallbackResult
  }
  deriving stock (Eq, Show)

{-| Zero-based slots in the native foreign function signature. The context
    slot consumes no additional Pudu argument. -}
data CallbackPair = CallbackPair
  { callbackArgumentIndex :: !Int
  , callbackContextIndex :: !Int
  , callbackTypeName :: !Text
  }
  deriving stock (Eq, Show)

checkCallbackDeclarations
  :: Set.Set Text
  -> RecordLayouts
  -> [Located ForeignCallback]
  -> Either CallbackFault (Map.Map Text (Located CallbackSignature))
checkCallbackDeclarations handles layouts = foldM insert Map.empty
 where
  insert signatures (Located at callback) = do
    let Located nameSpan name = foreignCallbackName callback
    when (Map.member name signatures || Set.member name handles) $
      refuse nameSpan ("foreign callback " <> name <> " is already declared in this block")
    signature <- checkSignature handles layouts at callback
    pure (Map.insert name (Located at signature) signatures)

checkSignature
  :: Set.Set Text -> RecordLayouts -> Span -> ForeignCallback
  -> Either CallbackFault CallbackSignature
checkSignature handles layouts at callback = do
  let written = foreignCallbackParameters callback
  when (length written > foreignArgumentLimit) $
    refuse at "a foreign callback may take at most 32 native arguments"
  case [locatedSpan parameter | parameter <- written, ForeignCallbackContext <- [locatedValue parameter]] of
    [_] -> pure ()
    _ : extra : _ -> refuse extra "a foreign callback has more than one context parameter"
    [] -> refuse at "a foreign callback must declare a context parameter"
  parameters <- traverse checkParameter written
  let result = foreignCallbackResult callback
  answer <- checkResult (crossingFor handles layouts result) result (foreignCallbackFallback callback)
  pure (CallbackSignature parameters answer)
 where
  checkParameter (Located at' parameter) = case parameter of
    ForeignCallbackContext -> pure CallbackContext
    ForeignCallbackArgument _ borrowed written ->
      let invalidParameter = refuse (locatedSpan written) "this type cannot cross as a callback parameter"
       in case (borrowed, crossingFor handles layouts written) of
            (True, Just crossing@HandleCrossing{}) -> pure (CallbackValue crossing)
            (True, _) -> refuse at' "borrowed callback parameters must name an opaque type from this block"
            (False, Just crossing) -> case crossing of
              HandleCrossing{} -> refuse at' "an opaque callback parameter must be written borrowed"
              BytesCrossing -> invalidParameter
              NothingCrossing -> invalidParameter
              _ -> pure (CallbackValue crossing)
            (False, Nothing) -> invalidParameter

checkResult
  :: Maybe Crossing -> Located TypeSyntax -> Maybe (Located Literal)
  -> Either CallbackFault CallbackResult
checkResult crossing written fallback = case crossing of
  Just NothingCrossing -> case fallback of
    Nothing -> pure CallbackVoid
    Just (Located at _) -> refuse at "a callback returning () cannot declare a fallback value"
  Just result@SignedCrossing{} -> withFallback result
  Just result@UnsignedCrossing{} -> withFallback result
  Just result@FloatingCrossing{} -> withFallback result
  Just BooleanCrossing -> withFallback BooleanCrossing
  _ -> refuse (locatedSpan written) "a callback result must be (), a fixed-width integer, a float or Bool"
 where
  withFallback result = case fallback of
    Nothing -> refuse (locatedSpan written) "a callback returning a value must declare an else fallback"
    Just (Located at value) ->
      maybe (refuse at "the callback fallback does not fit its declared result type") pure
        (decodeFallback result value)

decodeFallback :: Crossing -> Literal -> Maybe CallbackResult
decodeFallback crossing literal = case (crossing, literal) of
  (SignedCrossing width, IntegerValue text) ->
    CallbackSigned width <$> decodeInteger crossing (SignedSuffix width) text
  (UnsignedCrossing width, IntegerValue text) ->
    CallbackUnsigned width <$> decodeInteger crossing (UnsignedSuffix width) text
  (FloatingCrossing 32, FloatValue text) -> CallbackFloat Float32Width <$> fallbackFloat Float32Width text
  (FloatingCrossing 64, FloatValue text) -> CallbackFloat Float64Width <$> fallbackFloat Float64Width text
  (BooleanCrossing, BoolValue value) -> pure (CallbackBool value)
  _ -> Nothing

decodeInteger :: Crossing -> IntegerSuffix -> Text -> Maybe Integer
decodeInteger crossing expected text = do
  ParsedInteger value suffix <- parseIntegerLiteral text
  value <$ guard (maybe True (== expected) suffix && fitsCrossing crossing value)

fallbackFloat :: FloatWidth -> Text -> Maybe Double
fallbackFloat width text = do
  let (body, suffix) = splitFloatSuffix text
  guard (maybe True (== width) suffix)
  let spelling = case width of
        Float32Width -> body <> "f32"
        Float64Width -> body <> "f64"
  value <- parseFloatLiteral spelling
  parsedFloatValue value <$ guard (parsedFloatFits value)

callbackPairs
  :: Map.Map Text (Located CallbackSignature)
  -> Located ForeignFunction
  -> Either CallbackFault [CallbackPair]
callbackPairs signatures (Located _ function) = do
  case resolvedType (foreignResult function) of
    Just _ -> refuse (locatedSpan (foreignResult function)) "a callback token cannot cross as a foreign result"
    Nothing -> pure ()
  mapM_ checkContext contexts
  traverse pair callbacks
 where
  parameters = zip [0 ..] (foreignParameters function)
  contexts = [(index, foreignParameterName value) | (index, Located _ value) <- parameters, foreignParameterContext value]
  callbacks =
    [ (index, value, written, name, signature)
    | (index, Located _ value) <- parameters
    , Just written <- [foreignParameterType value]
    , Just (name, signature) <- [resolvedType written]
    ]
  contextPositions = Map.fromListWith (flip (++))
    [(locatedValue reference, [(index, locatedSpan reference)]) | (index, reference) <- contexts]
  parameterCounts = Map.fromListWith (+)
    [(locatedValue (foreignParameterName value), 1 :: Int) | (_, Located _ value) <- parameters, not (foreignParameterContext value)]
  callbackNames = Set.fromList [locatedValue (foreignParameterName value) | (_, value, _, _, _) <- callbacks]
  resolvedType (Located _ syntax) = case syntax of
    NamedType (ModuleName (name :| [])) [] -> (name,) <$> Map.lookup name signatures
    _ -> Nothing
  checkContext (_, Located referenceSpan name) =
    unless (Set.member name callbackNames) $
      refuse referenceSpan ("context " <> name <> " must refer to a callback parameter of this function")
  pair (index, value, written, name, signature) = do
    let Located nameSpan parameter = foreignParameterName value
    when (spanStart (locatedSpan signature) >= spanStart (locatedSpan written)) $
      refuse (locatedSpan written) ("declare callback " <> name <> " before using it in a foreign signature")
    when (foreignParameterOut value || foreignParameterOwned value) $
      refuse nameSpan "a callback token crosses as an ordinary foreign input"
    when (Map.lookup parameter parameterCounts /= Just 1) $
      refuse nameSpan ("callback parameter " <> parameter <> " is ambiguous in this function")
    case Map.findWithDefault [] parameter contextPositions of
      [(contextIndex, _)] -> pure (CallbackPair index contextIndex name)
      _ : (_, duplicate) : _ -> refuse duplicate ("callback parameter " <> parameter <> " has more than one context reference")
      [] -> refuse nameSpan ("callback parameter " <> parameter <> " needs a context reference")

refuse :: Span -> Text -> Either CallbackFault a
refuse at message = Left (CallbackFault at message)
