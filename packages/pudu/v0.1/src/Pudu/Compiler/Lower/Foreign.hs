{-| @Compiler.Lower.Foreign — a call to a foreign function the module declares
    or imports: its arguments in order, then the call through the declared
    library and symbol. -}
module Pudu.Compiler.Lower.Foreign
  ( lowerForeignCall, lowerQualifiedForeignCall, callbackSignatureOf
  , lowerCallbackValue, lowerCallbackRegistration, lowerCallbackUnregister, lowerCallbackUnregisterValue
  ) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import GHC.Float (castDoubleToWord64)
import qualified Pudu.Foreign.Callback as Callback
import Pudu.Foreign.Crossing (Crossing (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Compiler.Lower.Array (collect, stops, stopped)
import Pudu.Compiler.Lower.State (ForeignTarget (..), LowerContext (..), LowerState (..), halt, lookupCallback, lookupForeign, lookupQualifiedForeign, refused)
import Pudu.Compiler.Lower.Types (LowerTypes, recordFields, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.IntegerLiteral (IntegerKind (SignedKind, UnsignedKind))
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| Nothing unless the name reaches a foreign declaration. The crossing types
    come from the checked arguments and the call's own result. -}
lowerForeignCall :: (LowerState -> Located Expression -> Lowered) -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered
lowerForeignCall lower state at name arguments =
  crossing lower state at arguments <$> lookupForeign state name

{-| Nothing unless the qualifier names a module declaring the name foreign. -}
lowerQualifiedForeignCall :: (LowerState -> Located Expression -> Lowered) -> LowerState -> Span -> Text -> Text -> [Located Expression] -> Maybe Lowered
lowerQualifiedForeignCall lower state at qualifier name arguments =
  crossing lower state at arguments <$> lookupQualifiedForeign state qualifier name

{-| The arguments in order, then the call through the declared target. -}
crossing :: (LowerState -> Located Expression -> Lowered) -> LowerState -> Span -> [Located Expression] -> ForeignTarget -> Lowered
crossing lower state at arguments target = case collect lower state arguments of
    (after, Nothing) -> refused after
    (after, Just cores)
      | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
      | otherwise -> case typeForSpan (contextTypes (lowerContext after)) at of
          Just result
            | foreignParametersFit target types parameters
            , admittedResult target types result ->
                let declared = CoreForeign (targetLibrary target) (targetVersion target) (targetSymbol target) parameters result
                      (targetClaim target) (targetReleases target) (targetSlotPositions target) (targetSlotClaims target)
                      (targetCallbackSlots target)
                 in (after, Just (CoreExpression at result (CoreForeignCall declared cores), result))
          _ -> halt at "a foreign call crossing output slots" after
      where
        parameters = map coreExpressionType cores
        types = contextTypes (lowerContext after)

foreignParametersFit :: ForeignTarget -> LowerTypes -> [CoreType] -> Bool
foreignParametersFit target types parameters =
  length inputPositions == length parameters && and (zipWith fits inputPositions parameters)
 where
  callbacks = targetCallbackSlots target
  blocked = Set.fromList (targetSlotPositions target <> map coreCallbackContextIndex callbacks)
  nativeCount = length parameters + Set.size blocked
  inputPositions = [index | index <- [0 .. nativeCount - 1], Set.notMember index blocked]
  owners = Map.fromList
    [(coreCallbackFunctionIndex slot, coreCallbackOwner (coreCallbackSignature slot)) | slot <- callbacks]
  fits index kind = case (Map.lookup index owners, kind) of
    (Just owner, CoreCallbackType actual _) -> owner == actual
    (Just _, _) -> False
    (Nothing, _) -> parameterCrossing types kind

callbackSignatureOf :: Text -> Text -> Callback.CallbackSignature -> CoreCallbackSignature
callbackSignatureOf owner name signature =
  CoreCallbackSignature (owner <> "." <> name) (map parameter (Callback.callbackParameters signature)) result fallback
 where
  parameter Callback.CallbackContext = Nothing
  parameter (Callback.CallbackValue kind) = Just (coreCrossing kind)
  coreCrossing kind = case kind of
    SignedCrossing width -> signed width
    UnsignedCrossing width -> unsigned width
    FloatingCrossing 32 -> CoreFloatType Float32Width
    FloatingCrossing _ -> CoreFloatType Float64Width
    BooleanCrossing -> CoreBoolType
    TextCrossing -> CoreTextType
    BytesCrossing -> CoreBytesType
    HandleCrossing label -> CoreHandleType (owner <> "." <> label) label
    RecordCrossing label _ -> CoreRecordType (owner <> "." <> label) []
    NothingCrossing -> CoreUnitType
  (result, fallback) = case Callback.callbackResult signature of
    Callback.CallbackVoid -> (CoreUnitType, CallbackFallbackUnit)
    Callback.CallbackSigned width held -> (signed width, CallbackFallbackInteger held)
    Callback.CallbackUnsigned width held -> (unsigned width, CallbackFallbackInteger held)
    Callback.CallbackFloat width held -> (CoreFloatType width, CallbackFallbackFloat (castDoubleToWord64 held))
    Callback.CallbackBool held -> (CoreBoolType, CallbackFallbackBool held)
  signed = CoreIntegerType . SignedKind
  unsigned = CoreIntegerType . UnsignedKind

lowerCallbackRegistration
  :: (LowerState -> Located Expression -> Lowered)
  -> LowerState -> Span -> [Text] -> [Located Expression] -> Maybe Lowered
lowerCallbackRegistration lower state at path arguments = do
  signature <- lookupCallback state path
  pure $ case arguments of
    [handler] -> lowerCallbackOperand lower state at (CoreCallbackRegister signature) handler
    _ -> halt at "a callback registration without its handler" state

lowerCallbackUnregister
  :: (LowerState -> Located Expression -> Lowered)
  -> LowerState -> Span -> Located Expression -> [Located Expression] -> Maybe Lowered
lowerCallbackUnregister lower state at receiver arguments = case (formed receiver, arguments) of
  (Just CoreCallbackType{}, []) -> Just (lowerCallbackOperand lower state at CoreCallbackUnregister receiver)
  (Just (CoreFunctionType [_] CoreCallbackType{}), [token])
    | Just CoreCallbackType{} <- formed token -> Just (lowerCallbackOperand lower state at CoreCallbackUnregister token)
  _ -> Nothing
 where
  formed = typeForSpan (contextTypes (lowerContext state)) . locatedSpan

lowerCallbackOperand
  :: (LowerState -> Located Expression -> Lowered)
  -> LowerState -> Span -> CoreCallbackOperation -> Located Expression -> Lowered
lowerCallbackOperand lower state at operation operand = case lower state operand of
  (after, Just (held, _))
    | stops held -> (after, Just (held, CoreNeverType))
    | Just result <- typeForSpan (contextTypes (lowerContext after)) at ->
        (after, Just (CoreExpression at result (CoreCallback operation held), result))
    | otherwise -> halt at "a callback operation without a represented result" after
  (after, Nothing) -> refused after

lowerCallbackValue :: LowerState -> Span -> [Text] -> Maybe Lowered
lowerCallbackValue state at path = do
  signature <- lookupCallback state path
  kind@(CoreFunctionType [input] result@CoreCallbackType{}) <- typeForSpan (contextTypes context) at
  let key = "$callback:" <> coreCallbackOwner signature
      parameter = CoreLocal 0 "handler" input
      operand = CoreExpression at input (CoreReadLocal parameter)
      body = CoreExpression at result (CoreCallback (CoreCallbackRegister signature) operand)
      function = CoreFunction key [CoreParameter parameter at] result (CoreBlock [] (Just body))
      name = displayName (coreCallbackOwner signature)
      info = CoreClosureInfo [] name key False False Nothing
      next | Map.member key (contextClosures context) = context
           | otherwise = context
              { contextFunctions = function : contextFunctions context
              , contextClosures = Map.insert key info (contextClosures context) }
  pure (state{lowerContext = next}, Just (CoreExpression at kind (CoreClosure key []), kind))
 where
  context = lowerContext state

-- A retained method captures the already evaluated token, just as a
-- retained ordinary member captures its receiver.
lowerCallbackUnregisterValue
  :: (LowerState -> Located Expression -> Lowered)
  -> LowerState -> Span -> Located Expression -> Maybe Lowered
lowerCallbackUnregisterValue lower state at receiver = case formed (locatedSpan receiver) of
  Just token@(CoreCallbackType owner _) -> do
    kind@(CoreFunctionType [] result) <- formed at
    pure $ case lower state receiver of
      (after, Just (held, _)) | stops held -> (after, Just (held, CoreNeverType))
      (after, Just (held, _)) ->
        closure after owner kind token result (Just held)
      (after, Nothing) -> refused after
  Just (CoreFunctionType [_] CoreCallbackType{}) -> do
    kind@(CoreFunctionType [token@(CoreCallbackType owner _)] result) <- formed at
    pure (closure state owner kind token result Nothing)
  _ -> Nothing
 where
  formed = typeForSpan (contextTypes (lowerContext state))
  closure after owner kind token result capture =
    let key = "$unregister:" <> owner <> maybe ":unbound" (const ":bound") capture
        packed = case capture of Nothing -> token; Just _ -> kind
        parameter = CoreLocal 0 "receiver" packed
        input = CoreExpression at packed (CoreReadLocal parameter)
        operand = case capture of
          Nothing -> input
          Just _ -> CoreExpression at token (CoreCapture 0 input)
        body = CoreExpression at result (CoreCallback CoreCallbackUnregister operand)
        function = CoreFunction key [CoreParameter parameter at] result (CoreBlock [] (Just body))
        operands = maybe [] pure capture
        info = CoreClosureInfo (map coreExpressionType operands) "unregister" key False
          (not (null operands)) (Just token)
        old = lowerContext after
        next | Map.member key (contextClosures old) = old
             | otherwise = old
                { contextFunctions = function : contextFunctions old
                , contextClosures = Map.insert key info (contextClosures old) }
     in (after{lowerContext = next}, Just (CoreExpression at kind (CoreClosure key operands), kind))

admittedResult :: ForeignTarget -> LowerTypes -> CoreType -> Bool
admittedResult target types result
  | null (targetSlotPositions target) = resultCrossing types result || handleResult target result
  | CoreTupleType (native : slots) <- result =
      (resultCrossing types native || ownedNative target native)
        && length slots == length (targetSlotPositions target)
        && and (zipWith (admitSlot types) slots (targetSlotClaims target))
  | otherwise = False

ownedNative :: ForeignTarget -> CoreType -> Bool
ownedNative target kind = case (kind, targetClaim target) of
  (CoreHandleType _ _, Just (CoreOwned _ _ _)) -> True
  _ -> False

admitSlot :: LowerTypes -> CoreType -> Maybe CoreClaim -> Bool
admitSlot types kind claim = case kind of
  CoreSumType "Option" [CoreHandleType _ _] -> claim /= Nothing
  _ -> slotCrossing types kind

slotCrossing :: LowerTypes -> CoreType -> Bool
slotCrossing types kind
  | kind == CoreSumType "Option" [CoreTextType] = True
  | scalarCrossing kind = True
  | Just fields <- recordFields types kind =
      not (null fields) && length fields <= 32 && all (slotCrossing types . snd) fields
  | otherwise = False

{-| A parameter crosses as a number, Bool, text, a lent run of bytes or a
    record of those (bytes excepted). -}
parameterCrossing :: LowerTypes -> CoreType -> Bool
parameterCrossing types kind = kind == CoreBytesType || handle kind || fieldCrossing types kind

{-| A handle result crosses when its declaration says what it transfers. -}
handleResult :: ForeignTarget -> CoreType -> Bool
handleResult target kind = handle kind && targetClaim target /= Nothing

handle :: CoreType -> Bool
handle kind = case kind of
  CoreHandleType _ _ -> True
  _ -> False

{-| A result crosses as a number, Bool, text, unit or such a record. -}
resultCrossing :: LowerTypes -> CoreType -> Bool
resultCrossing types kind = kind == CoreUnitType || fieldCrossing types kind

{-| What a record field may be: a number, Bool, text, or a record of those,
    the record holding between one and thirty-two fields. -}
fieldCrossing :: LowerTypes -> CoreType -> Bool
fieldCrossing types kind
  | scalarCrossing kind || kind == CoreTextType = True
  | otherwise = case recordFields types kind of
      Just fields -> not (null fields) && length fields <= 32 && all (fieldCrossing types . snd) fields
      Nothing -> False

{-| The numeric and Bool crossings: fixed-width integers, both float widths
    and Bool. -}
scalarCrossing :: CoreType -> Bool
scalarCrossing kind = case kind of
  CoreIntegerType (SignedKind width) -> width `elem` [8, 16, 32, 64]
  CoreIntegerType (UnsignedKind width) -> width `elem` [8, 16, 32, 64]
  CoreFloatType _ -> True
  CoreBoolType -> True
  _ -> False
