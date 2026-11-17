{-| @Compiler.Lower.Foreign — a call to a foreign function the module declares
    or imports: its arguments in order, then the call through the declared
    library and symbol. -}
module Pudu.Compiler.Lower.Foreign
  ( lowerForeignCall, lowerQualifiedForeignCall, callbackSignatureOf
  , lowerCallbackValue, lowerCallbackRegistration, lowerCallbackUnregister, lowerCallbackUnregisterValue
  ) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.List (elemIndex)
import Data.Text (Text)
import GHC.Float (castDoubleToWord64)
import qualified Pudu.Foreign.Callback as Callback
import Pudu.Foreign.Crossing (Crossing (..), isAbsentLoanArgument)
import Pudu.Foreign.Extent (ForeignBound (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Compiler.Lower.Array (collect, stops, stopped)
import Pudu.Compiler.Lower.Loan (Callee (ForeignCrossing), Operand (Argument), lowerLoanedOperands, valueSignature)
import Pudu.Compiler.Lower.State (ForeignTarget (..), LowerContext (..), LowerState (..), halt, lookupCallback, lookupCallbackGroup, lookupForeign, lookupQualifiedForeign, refused)
import Pudu.Compiler.Lower.Types (LowerTypes, recordFields, referenceTarget, typeForSpan)
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
crossing lower state at arguments target
  | Just resolvedBounds <- bounds, not (null mutable) = case traverse argumentType (zip [0 ..] arguments) of
      Just parameters
        | Just result <- typeForSpan typesAtCall at
        , foreignParametersFit target typesAtCall parameters
        , admittedResult target typesAtCall result ->
            lowerLoanedOperands lowerOperand state at (ForeignCrossing (declaration parameters result resolvedBounds))
              (valueSignature at parameters result mutable) False
              [(index, Argument, argument) | (index, argument) <- zip [0 ..] arguments]
      _ -> halt at "a foreign call with unrepresented loan operands" state
  | Just resolvedBounds <- bounds = case collect lowerOperand state arguments of
    (after, Nothing) -> refused after
    (after, Just cores)
      | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
      | otherwise -> case typeForSpan (contextTypes (lowerContext after)) at of
          Just result
            | foreignParametersFit target types parameters
            , admittedResult target types result ->
                (after, Just (CoreExpression at result (CoreForeignCall (declaration parameters result resolvedBounds) cores), result))
          _ -> halt at "a foreign call crossing output slots" after
      where
        parameters = map coreExpressionType cores
        types = contextTypes (lowerContext after)
  | otherwise = halt at "a foreign length whose input positions do not match" state
 where
  positions = foreignInputPositions target (length arguments)
  byNative = Map.fromList (zip positions [0 ..])
  bounds = traverse translate (targetBounds target)
  translate bound =
    ForeignBound <$> Map.lookup (boundLength bound) byNative <*> pure (boundUnit bound)
      <*> traverse (`Map.lookup` byNative) (boundTargets bound)
  modes =
    [ (index, exclusive)
    | (index, native) <- zip [0 ..] positions
    , Just exclusive <- [lookup native (targetLoans target)] ]
  absent = [index | (index, (native, argument)) <- zip [0 ..] (zip positions arguments)
                  , native `elem` targetNullableLoans target, isAbsentLoanArgument argument]
  absentSpans = [locatedSpan argument | (index, argument) <- zip [0 ..] arguments, index `elem` absent]
  mutable = [index | (index, True) <- modes, index `notElem` absent]
  lowerOperand current argument
    | argumentAt `elem` absentSpans
    , Just kind <- referenceTarget (contextTypes (lowerContext current)) argumentAt =
        (current, Just (CoreExpression argumentAt kind CoreAbsent, kind))
    | otherwise = lower current argument
   where
    argumentAt = locatedSpan argument
  typesAtCall = contextTypes (lowerContext state)
  argumentType (index, Located argumentAt _)
    | index `elem` mutable || index `elem` absent = referenceTarget typesAtCall argumentAt
    | otherwise = typeForSpan typesAtCall argumentAt
  declaration parameters result resolvedBounds = CoreForeign
    (targetLibrary target) (targetVersion target) (targetSymbol target) (targetObjectiveC target) parameters result
    (targetClaim target) (targetReleases target) (targetSlotPositions target) (targetSlotClaims target)
    (targetCallbackSlots target) (targetCanReenter target || targetObjectiveC target /= Nothing) modes absent resolvedBounds (targetReturnedRun target)

foreignParametersFit :: ForeignTarget -> LowerTypes -> [CoreType] -> Bool
foreignParametersFit target types parameters =
  length inputPositions == length parameters && and (zipWith fits inputPositions parameters)
 where
  callbacks = targetCallbackSlots target
  inputPositions = foreignInputPositions target (length parameters)
  owners = Map.fromList
    [ (position, coreCallbackOwner (coreCallbackSignature slot))
    | slot <- callbacks, Just position <- [Callback.callbackInputPosition (coreCallbackPlacement slot)] ]
  fits index kind = case (Map.lookup index owners, kind) of
    (Just owner, CoreCallbackType actual _) -> owner == actual
    (Just _, _) -> False
    (Nothing, CoreArrayType element)
      | Just _ <- lookup index (targetLoans target) -> scalarRecord element
    (Nothing, _) -> parameterCrossing types kind
  scalarRecord kind
    | scalarCrossing kind = True
    | Just fields <- recordFields types kind =
        not (null fields) && length fields <= 32 && all (scalarRecord . snd) fields
    | otherwise = False

foreignInputPositions :: ForeignTarget -> Int -> [Int]
foreignInputPositions target inputCount =
  [index | index <- [0 .. inputCount + Set.size blocked - 1], Set.notMember index blocked]
 where
  blocked = Set.fromList (targetSlotPositions target <> concatMap (Callback.callbackHiddenPositions . coreCallbackPlacement) (targetCallbackSlots target))

callbackSignatureOf :: Text -> Text -> Callback.CallbackSignature -> CoreCallbackSignature
callbackSignatureOf owner name signature =
  CoreCallbackSignature (owner <> "." <> name) (map parameter (Callback.callbackParameters signature)) result fallback
    (Callback.callbackByteLengths signature) Nothing
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
    OptionalHandleCrossing label -> CoreSumType "Option" [CoreHandleType (owner <> "." <> label) label]
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
lowerCallbackRegistration lower state at path arguments =
  case lookupCallbackGroup state path of
    Just (signature, members) -> Just $ case arguments of
      [handler] -> lowerGroup signature members handler
      _ -> halt at "a callback group registration without its handler record" state
    Nothing -> do
      signature <- lookupCallback state path
      pure $ case arguments of
        [handler] -> lowerCallbackOperand lower state at (CoreCallbackRegister signature) handler
        _ -> halt at "a callback registration without its handler" state
 where
  lowerGroup signature members handler = case lower state handler of
    (after, Just (held, kind))
      | stops held -> (after, Just (held, CoreNeverType))
      | let types = contextTypes (lowerContext after)
      , Just fields <- recordFields types kind
      , Just indices <- traverse (\member -> elemIndex member (map fst fields)) members
      , Just result <- typeForSpan types at ->
          (after, Just (CoreExpression at result (CoreCallback (CoreCallbackRegisterGroup signature indices) held), result))
      | otherwise -> halt at "a callback group without a represented handler record" after
    (after, Nothing) -> refused after

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
      (resultCrossing types native || handleResult target native || returnedRunResult target native)
        && length slots == length (targetSlotPositions target)
        && and (zipWith (admitSlot types) slots (targetSlotClaims target))
  | otherwise = False

returnedRunResult :: ForeignTarget -> CoreType -> Bool
returnedRunResult target kind =
  targetReturnedRun target /= Nothing && targetClaim target /= Nothing && case kind of
    CoreArrayType _ -> True
    CoreSumType "Option" [CoreArrayType _] -> True
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
  CoreSumType "Option" [CoreHandleType _ _] -> True
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
