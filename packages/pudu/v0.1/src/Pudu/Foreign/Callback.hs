{-| Checked foreign callback signatures and native argument positions shared
    by declaration checking and the two foreign dispatch paths. -}
module Pudu.Foreign.Callback
  ( CallbackFault (..)
  , CallbackParameter (..)
  , CallbackResult (..)
  , CallbackSignature (..)
  , CallbackPair (..)
  , CallbackPlacement (..)
  , CallbackGroupMember (..)
  , CallbackGroups
  , checkCallbackGroups
  , callbackInputPosition
  , callbackHiddenPositions
  , callbackNativePosition
  , checkCallbackDeclarations
  , callbackPairs
  ) where

import Control.Monad (foldM, guard, unless, when)
import Data.Maybe (isJust)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.FloatLiteral
  ( FloatWidth (..), ParsedFloat (..), parseFloatLiteral, splitFloatSuffix )
import Pudu.Foreign.Crossing
  ( Crossing (..), RecordLayouts, crossingFor, fitsCrossing, foreignArgumentLimit )
import Pudu.Foreign.Extent (ExtentUnit (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( ForeignCallback (..), ForeignCallbackGroup (..), ForeignCallbackMember (..)
  , ForeignCallbackParameter (..), ForeignFunction (..)
  , ForeignCallbackPassing (..), ForeignLength (..), ForeignParameter (..), Literal (..), TypeSyntax (..) )
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
  , callbackByteLengths :: ![(Int, Int)]
  }
  deriving stock (Eq, Show)

{-| Native positions include output slots and are independent of Pudu arity. -}
data CallbackPlacement
  = PairedCallback !Int !Int
  | StaticTrampoline !Int
  | RegistrationContext !Int
  {-| One native pointer to a block literal whose invoke is the trampoline. -}
  | BlockCallback !Int
  deriving stock (Eq, Ord, Show)

data CallbackPair = CallbackPair
  { callbackPlacement :: !CallbackPlacement
  , callbackTypeName :: !Text
  , callbackProjection :: !(Maybe (Int, Text))
  , callbackSlotSignature :: !CallbackSignature
  }
  deriving stock (Eq, Show)

callbackNativePosition :: CallbackPlacement -> Int
callbackNativePosition placement = case placement of
  PairedCallback function _ -> function
  StaticTrampoline function -> function
  RegistrationContext context -> context
  BlockCallback position -> position

callbackInputPosition :: CallbackPlacement -> Maybe Int
callbackInputPosition placement = case placement of
  StaticTrampoline _ -> Nothing
  _ -> Just (callbackNativePosition placement)

callbackHiddenPositions :: CallbackPlacement -> [Int]
callbackHiddenPositions placement = case placement of
  PairedCallback _ context -> [context]
  StaticTrampoline function -> [function]
  RegistrationContext _ -> []
  BlockCallback _ -> []

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

data CallbackGroupMember = CallbackGroupMember
  { callbackMemberField :: !Text
  , callbackMemberTypeName :: !Text
  , callbackMemberSignature :: !(Located CallbackSignature)
  }
  deriving stock (Eq, Show)

type CallbackGroups = Map.Map Text (Located (NonEmpty CallbackGroupMember))

checkCallbackGroups
  :: Set.Set Text
  -> Map.Map Text (Located CallbackSignature)
  -> [Located ForeignCallbackGroup]
  -> Either CallbackFault CallbackGroups
checkCallbackGroups handles signatures = foldM insert Map.empty
 where
  insert groups (Located at group) = do
    let Located nameSpan name = foreignCallbackGroupName group
    when (Map.member name groups || Map.member name signatures || Set.member name handles) $
      refuse nameSpan ("foreign callback " <> name <> " is already declared in this block")
    case foreignCallbackGroupMembers group of
      [] -> refuse at "a foreign callback group needs at least one member"
      first : rest -> do
        initial <- resolveMember at first
        (_, reversed) <- foldM (addMember at) (Set.singleton (callbackMemberField initial), []) rest
        pure (Map.insert name (Located at (initial :| reverse reversed)) groups)
  addMember at (seen, reversed) member = do
    let Located fieldSpan field = foreignCallbackMemberName member
    when (Set.member field seen) $
      refuse fieldSpan ("callback member " <> field <> " is already declared in this group")
    checked <- resolveMember at member
    pure (Set.insert field seen, checked : reversed)
  resolveMember groupSpan member = do
    let Located used name = foreignCallbackMemberType member
    case Map.lookup name signatures of
      Just signature | spanStart (locatedSpan signature) < spanStart groupSpan ->
        pure (CallbackGroupMember (locatedValue (foreignCallbackMemberName member)) name signature)
      _ -> refuse used ("declare callback " <> name <> " in this block before using it in a group")

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
  byteLengths <- checkByteLengths (zip written parameters)
  let result = foreignCallbackResult callback
  answer <- checkResult (crossingFor handles layouts result) result (foreignCallbackFallback callback)
  pure (CallbackSignature parameters answer byteLengths)
 where
  checkParameter (Located at' parameter) = case parameter of
    ForeignCallbackContext -> pure CallbackContext
    ForeignCallbackArgument _ borrowed written _ ->
      let invalidParameter = refuse (locatedSpan written) "this type cannot cross as a callback parameter"
       in case (borrowed, crossingFor handles layouts written) of
            (True, Just crossing@HandleCrossing{}) -> pure (CallbackValue crossing)
            (True, _) -> refuse at' "borrowed callback parameters must name an opaque type from this block"
            (False, Just crossing) -> case crossing of
              HandleCrossing{} -> refuse at' "an opaque callback parameter must be written borrowed"
              NothingCrossing -> invalidParameter
              _ -> pure (CallbackValue crossing)
            (False, Nothing) -> invalidParameter

checkByteLengths
  :: [(Located ForeignCallbackParameter, CallbackParameter)] -> Either CallbackFault [(Int, Int)]
checkByteLengths parameters = do
  relations <- concat <$> traverse relation positions
  traverse (uniqueLength relations) runs
 where
  positions = zip [0 ..] parameters
  runs = [(index, at) | (index, (Located at _, CallbackValue BytesCrossing)) <- positions]
  inputs = Map.fromListWith (<>)
    [(locatedValue name, [(index, kind)]) | (index, (Located _ (ForeignCallbackArgument name _ _ _), kind)) <- positions]
  relation (index, (Located _ (ForeignCallbackArgument _ _ _ (Just (ForeignLength unit targets))), kind))
    | locatedValue unit == ExtentBytes, integer kind =
        traverse (target index) (NonEmpty.toList targets)
    | otherwise = refuse (locatedSpan unit) "a callback byte length must be a fixed-width integer written bytes of"
  relation _ = pure []
  integer (CallbackValue SignedCrossing{}) = True
  integer (CallbackValue UnsignedCrossing{}) = True
  integer _ = False
  target lengthIndex (Located at name) = case Map.lookup name inputs of
    Just [(index, CallbackValue BytesCrossing)] -> pure (index, lengthIndex)
    _ -> refuse at "a callback byte length must name a unique Bytes parameter"
  uniqueLength relations (index, at) = case [lengthIndex | (run, lengthIndex) <- relations, run == index] of
    [lengthIndex] -> pure (index, lengthIndex)
    _ -> refuse at "a callback Bytes parameter needs exactly one byte length"

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
  -> CallbackGroups
  -> Located ForeignFunction
  -> Either CallbackFault [CallbackPair]
callbackPairs signatures groups (Located _ function) = do
  when (isToken (foreignResult function)) $
    refuse (locatedSpan (foreignResult function)) "a callback token cannot cross as a foreign result"
  mapM_ checkContext contexts
  concat <$> traverse pair parameters
 where
  parameters = zip [0 ..] (foreignParameters function)
  contexts = [(index, foreignParameterName value) | (index, Located _ value) <- parameters, foreignParameterContext value]
  contextPositions = Map.fromListWith (flip (++))
    [(locatedValue reference, [(index, locatedSpan reference)]) | (index, reference) <- contexts]
  parameterCounts = Map.fromListWith (+)
    [(locatedValue (foreignParameterName value), 1 :: Int) | (_, Located _ value) <- parameters, not (foreignParameterContext value)]
  callbackNames = Set.fromList
    [ locatedValue (foreignParameterName value)
    | (_, Located _ value) <- parameters
    , foreignParameterCallbackPassing value == Nothing
    , Just written <- [foreignParameterType value]
    , Just _ <- [resolvedType written]
    ]
  resolvedType (Located _ syntax) = case syntax of
    NamedType (ModuleName (name :| [])) [] -> (name,) <$> Map.lookup name signatures
    _ -> Nothing
  checkContext (_, Located referenceSpan name) =
    unless (Set.member name callbackNames) $
      refuse referenceSpan ("context " <> name <> " must refer to a callback parameter of this function")
  isToken written@(Located _ syntax) =
    case syntax of
      NamedType (ModuleName (owner :| [])) [] -> Map.member owner groups || isJust (resolvedType written)
      _ -> False
  resolve passing written@(Located _ syntax) = case (passing, syntax) of
    (Just ContextPassing, NamedType (ModuleName (owner :| [])) [])
      | Just (Located at (representative :| _)) <- Map.lookup owner groups ->
          Just (owner, at, Nothing, locatedValue (callbackMemberSignature representative))
    (Just TrampolinePassing, NamedType (ModuleName (owner :| [member])) []) -> do
      Located at members <- Map.lookup owner groups
      (ordinal, selected) <- lookup member
        [(callbackMemberField entry, (ordinal, entry)) | (ordinal, entry) <- zip [0 ..] (NonEmpty.toList members)]
      pure (owner, at, Just (ordinal, member), locatedValue (callbackMemberSignature selected))
    _ -> do
      (owner, Located at signature) <- resolvedType written
      pure (owner, at, Nothing, signature)
  pair (index, Located at value) =
    case foreignParameterType value >>= \written -> (written,) <$> resolve passing written of
      Just (written, slot) -> (: []) <$> checked index value written slot
      Nothing
        | passing /= Nothing ->
            refuse at "trampoline and context must name a callback or a valid group projection declared in this block"
        | Just written <- foreignParameterType value, isToken written ->
            refuse at "a callback group token must cross as an explicit context"
        | otherwise -> pure []
   where passing = foreignParameterCallbackPassing value
  checked index value written (name, declaredAt, projection, signature) = do
    let Located nameSpan parameter = foreignParameterName value
    when (spanStart declaredAt >= spanStart (locatedSpan written)) $
      refuse (locatedSpan written) ("declare callback " <> name <> " before using it in a foreign signature")
    when (foreignParameterOut value || foreignParameterOwned value
        || foreignParameterNullable value /= Nothing || foreignParameterLength value /= Nothing) $
      refuse nameSpan "a callback token crosses as an ordinary foreign input"
    when (Map.lookup parameter parameterCounts /= Just 1) $
      refuse nameSpan ("callback parameter " <> parameter <> " is ambiguous in this function")
    placement <- case foreignParameterCallbackPassing value of
      Just TrampolinePassing -> pure (StaticTrampoline index)
      Just ContextPassing -> pure (RegistrationContext index)
      Just BlockPassing -> case callbackParameters signature of
        CallbackContext : _ -> pure (BlockCallback index)
        _ -> refuse (locatedSpan written)
          ("callback " <> name <> " must take its context first to cross as a block")
      Nothing -> case Map.findWithDefault [] parameter contextPositions of
        [(contextIndex, _)] -> pure (PairedCallback index contextIndex)
        _ : (_, duplicate) : _ -> refuse duplicate ("callback parameter " <> parameter <> " has more than one context reference")
        [] -> refuse nameSpan ("callback parameter " <> parameter <> " needs a context reference")
    pure (CallbackPair placement name projection signature)

refuse :: Span -> Text -> Either CallbackFault a
refuse at message = Left (CallbackFault at message)
