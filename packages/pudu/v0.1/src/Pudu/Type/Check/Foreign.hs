{-| @Type.Check.Foreign — checks a declaration of a library written elsewhere

    A foreign declaration is the only description of the function that exists:
    there is no body to read and no definition to jump to. So it is checked more
    carefully than ordinary code rather than less — every mistake it can hold is
    caught where it is written, because where it is called the mistake is a
    corrupted stack rather than a diagnostic. -}
module Pudu.Type.Check.Foreign
  ( declareForeign
  , checkForeign
  , foreignHandles
  ) where

import Control.Applicative ((<|>))
import Control.Monad (unless, when)
import Data.List.NonEmpty (NonEmpty ((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Foreign.Callback
  ( CallbackFault (..), CallbackGroupMember (..), CallbackGroups, CallbackPair (callbackPlacement), CallbackSignature
  , callbackHiddenPositions, callbackNativePosition, callbackPairs, checkCallbackDeclarations, checkCallbackGroups )
import Pudu.Foreign.Crossing
  ( Crossing (..)
  , ObjectiveCMethod (..)
  , objectiveCInitializer
  , objectiveCRetainedFamily
  , parameterCrossingFor
  , RecordLayouts
  , crossableNames
  , crossingFor
  , crossingType
  , foreignBounds
  , foreignArgumentLimit
  , foreignRecordFieldLimit
  , isArrayCrossingSyntax
  , isOptionCrossingSyntax
  , loanFor
  , optionalHandleFor
  , resolveReturnedRun
  , returnedRunElementFor
  , runLoanFor
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( Capability (ForeignCapability)
  , Foreign (..)
  , ForeignCallback (..)
  , ForeignCallbackGroup (..)
  , ForeignCallbackParameter (..)
  , ForeignFunction (..)
  , ForeignClass (..)
  , ForeignMethod (..)
  , ForeignParameter (..)
  , TypeSyntax (..)
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker, DeclaredTypes, bindName, recordDeclaredMethod, recordUnsafeFunction, report )
import Pudu.Type.Formation (formType)
import Pudu.Type.Value (Required (..), Type (..), capabilitiesOf, monotype, nominalKey, stringType)

{-| The opaque things a block declares, which its own signatures may name. -}
foreignHandles :: Foreign -> Set.Set Text
foreignHandles value = Set.fromList (map locatedValue (foreignTypes value))

{-| Give every foreign function a type before anything calls it.

    The declaration is an assertion by whoever wrote it that this signature
    matches the library, and nothing can check that assertion. What can be done
    is to make the assertion visible: the name is bound like any other, so a
    call is checked, hover shows the signature, and going to the definition
    arrives at the declaration — which is the definition, as far as this program
    is concerned. -}
declareForeign :: DeclaredTypes -> RecordLayouts -> Foreign -> Checker ()
declareForeign declared layouts value = do
  let handles = foreignHandles value
      callbacks = either (const Map.empty) id (checkCallbackDeclarations handles layouts (foreignCallbacks value))
      groups = either (const Map.empty) id (checkCallbackGroups handles callbacks (foreignCallbackGroups value))
      syntax = Map.fromList
        [(locatedValue (foreignCallbackName callback), callback) | Located _ callback <- foreignCallbacks value]
  mapM_ (declareCallback declared layouts handles callbacks . locatedValue) (foreignCallbacks value)
  mapM_ (declareCallbackGroup declared layouts handles syntax groups . locatedValue) (foreignCallbackGroups value)
  mapM_ (declareOne declared layouts handles callbacks groups) (foreignFunctions value)

declareCallback
  :: DeclaredTypes -> RecordLayouts -> Set.Set Text
  -> Map.Map Text (Located CallbackSignature) -> ForeignCallback -> Checker ()
declareCallback declared layouts handles callbacks callback = do
  let name = locatedValue (foreignCallbackName callback)
  scheme <- if Map.member name callbacks
    then do
      handler <- callbackHandlerType declared layouts handles callback
      token <- declareCallbackToken declared (foreignCallbackName callback)
      pure (FunctionTypeValue False [handler] token)
    else pure ErrorType
  bindName name (monotype scheme)

callbackHandlerType :: DeclaredTypes -> RecordLayouts -> Set.Set Text -> ForeignCallback -> Checker Type
callbackHandlerType declared layouts handles callback = do
  let crossing = formedCrossing declared layouts handles
  inputs <- traverse crossing
    [ written | Located _ (ForeignCallbackArgument _ _ written _) <- foreignCallbackParameters callback ]
  answer <- crossing (foreignCallbackResult callback)
  pure (FunctionTypeValue False inputs answer)

declareCallbackToken :: DeclaredTypes -> Located Text -> Checker Type
declareCallbackToken declared (Located at name) = do
  token <- formType declared [] (Located at (NamedType (ModuleName (name :| [])) []))
  case token of
    NominalType owner [] -> do
      let member = Located at "unregister"
          result = NominalType "Result" [UnitTypeValue, stringType]
          method = monotype (FunctionTypeValue False [token] result)
      bindName (nominalKey owner <> ".unregister") method
      recordDeclaredMethod owner member method
    _ -> pure ()
  pure token

declareCallbackGroup
  :: DeclaredTypes -> RecordLayouts -> Set.Set Text -> Map.Map Text ForeignCallback
  -> CallbackGroups -> ForeignCallbackGroup -> Checker ()
declareCallbackGroup declared layouts handles syntax groups group = do
  let named = foreignCallbackGroupName group
      name = locatedValue named
      handler member = maybe (pure ErrorType) (callbackHandlerType declared layouts handles)
        (Map.lookup (callbackMemberTypeName member) syntax)
  scheme <- case Map.lookup name groups of
    Nothing -> pure ErrorType
    Just (Located _ members) -> do
      types <- traverse handler (NonEmpty.toList members)
      token <- declareCallbackToken declared named
      pure (FunctionTypeRequiring False [TupleTypeValue types]
        (CallbackMembers (map callbackMemberField (NonEmpty.toList members))) token)
  bindName name (monotype scheme)

declareOne
  :: DeclaredTypes -> RecordLayouts -> Set.Set Text
  -> Map.Map Text (Located CallbackSignature) -> CallbackGroups -> Located ForeignFunction -> Checker ()
declareOne declared layouts handles callbacks groups located@(Located _ function) = do
  let pairs = either (const []) id (callbackPairs callbacks groups located)
      callbackArguments = Set.fromList (map (callbackNativePosition . callbackPlacement) pairs)
      hidden = Set.fromList (concatMap (callbackHiddenPositions . callbackPlacement) pairs)
      ordinary = [(index, parameter) | (index, Located _ parameter) <- zip [0 ..] (foreignParameters function)
                                      , not (foreignParameterOut parameter || foreignParameterContext parameter)
                                      , Set.notMember index hidden]
      input nativeIndex written
        | Set.member nativeIndex callbackArguments = formType declared [] written
        | Just _ <- loanFor handles layouts written = formType declared [] written
        | Just _ <- runLoanFor handles layouts written = formType declared [] written
        | otherwise = formedCrossing declared layouts handles written
  inputs <- sequence
    [ maybe (pure ErrorType) (input nativeIndex) (foreignParameterType parameter)
    | (nativeIndex, parameter) <- ordinary
    ]
  native <- case foreignResultLength function of
    Just _ | Just _ <- returnedRunElementFor handles layouts (foreignResult function) ->
      formType declared [] (foreignResult function)
    _ -> formedCrossing declared layouts handles (foreignResult function)
  written <- mapM (slotAnswer declared layouts handles) (slotsOf function)
  let result = answeredType native written
      name = locatedValue (foreignName function)
      nullable = [index | (index, (_, parameter)) <- zip [0 ..] ordinary
                        , foreignParameterNullable parameter /= Nothing]
      required = case nullable of
        [] -> Required (length inputs)
        positions -> NullableLoans (length inputs) positions
  {-| Every foreign function requires the capability, and requires it in its
      own type, so a binding stored in a variable or passed on still asks for
      it wherever it is finally called. -}
  bindName name
    ( monotype
        ( RestrictedType (capabilitiesOf [ForeignCapability])
            (FunctionTypeRequiring False inputs required result)
        )
    )
  {-| Every foreign call needs the capability, without the declaration saying
      so. The signature is unverifiable by construction, and the language
      already has a word for an assertion of that kind. -}
  recordUnsafeFunction name [ForeignCapability]
  {-| A foreign parameter never has a default: there is no caller on this side
      to apply one, so every argument the declaration names must be supplied. -}

slotsOf :: ForeignFunction -> [Located ForeignParameter]
slotsOf function =
  [ parameter
  | parameter <- foreignParameters function
  , foreignParameterOut (locatedValue parameter)
  ]

{-| What a call answers with.

    Without slots, the result the declaration wrote. With them, one tuple whose
    first member is that result and whose rest are the slots in source order.
    The native result stays present even when it is unit, so that adding a
    status later does not move every slot and nothing reading these signatures
    needs a special case for whether the result carries information. -}
answeredType :: Type -> [Type] -> Type
answeredType native written = case written of
  [] -> native
  _ -> TupleTypeValue (native : written)

{-| The type one slot contributes to the answer.

    A pointer-shaped slot answers `Option`, because null is an absence a pointer
    really carries and most of these functions leave the cell untouched when
    they fail. A scalar or record slot answers its own type: a written zero and
    an unwritten cell leave the same bytes, so optionality there would be
    invented rather than observed. -}
slotAnswer
  :: DeclaredTypes -> RecordLayouts -> Set.Set Text -> Located ForeignParameter -> Checker Type
slotAnswer declared layouts handles (Located _ parameter) =
  case foreignParameterType parameter of
    Nothing -> pure ErrorType
    Just written -> do
      formed <- formedCrossing declared layouts handles written
      pure
        ( case crossingFor handles layouts written of
            Just TextCrossing -> NominalType "Option" [formed]
            Just (HandleCrossing _) -> NominalType "Option" [formed]
            _ -> formed
        )

formedCrossing
  :: DeclaredTypes -> RecordLayouts -> Set.Set Text -> Located TypeSyntax -> Checker Type
formedCrossing declared layouts handles written =
  case parameterCrossingFor handles layouts written of
    {-| A handle and a record are both nominal types of this program, so their
        formed type is the ordinary one and a caller builds and reads one the
        ordinary way. An optional handle is the ordinary `Option` of one. -}
    Just (HandleCrossing _) -> formType declared [] written
    Just (OptionalHandleCrossing _) -> formType declared [] written
    Just (RecordCrossing _ _) -> formType declared [] written
    Just crossing -> pure (crossingType crossing)
    Nothing -> pure ErrorType

{-| What the declaration itself can be wrong about.

    Four things, each catchable here: a type that cannot cross, an owned result
    that is not a handle, an owned result that names no release, and a release
    that is not declared in this library. The fifth — a signature that does not
    match what the library actually exports — is the one nothing can catch,
    which is why the other four are worth catching. -}
checkForeign :: RecordLayouts -> Foreign -> Checker ()
checkForeign layouts value = do
  checkLoaderName "library name" (foreignLibrary value)
  mapM_ (checkLoaderName "version") (foreignVersion value)
  mapM_ (checkClassName . foreignClassSymbol) (foreignClasses value)
  case checkCallbackDeclarations handles layouts (foreignCallbacks value) of
    Left failure -> reportCallbackFault failure
    Right callbacks -> case checkCallbackGroups handles callbacks (foreignCallbackGroups value) of
      Left failure -> reportCallbackFault failure
      Right groups -> mapM_ (checkFunction callbacks groups) (foreignFunctions value)
 where
  checkClassName written@(Located at name) = do
    checkLoaderName "Objective-C class name" written
    when (Text.null name) $
      report "E3068" at "an Objective-C class name cannot be empty" Nothing
  checkFunction callbacks groups function = case callbackPairs callbacks groups function of
    Left failure -> reportCallbackFault failure >> pure False
    Right pairs -> do
      let callbackArguments = Set.fromList (map (callbackNativePosition . callbackPlacement) pairs)
      checkObjectiveC layouts (foreignClasses value) declared function
      checkOne layouts handles declared callbackArguments function
      pure True
  reportCallbackFault (CallbackFault at message) = report "E3063" at message Nothing
  handles = foreignHandles value
  declared =
    Map.fromList
      [ (locatedValue (foreignName function), function)
      | Located _ function <- foreignFunctions value
      ]

checkOne
  :: RecordLayouts
  -> Set.Set Text
  -> Map.Map Text ForeignFunction
  -> Set.Set Int
  -> Located ForeignFunction
  -> Checker ()
checkOne layouts handles declared callbackArguments (Located functionSpan function) = do
  when (length (foreignParameters function) > foreignArgumentLimit) $
    report "E3069" functionSpan
      "a foreign function may take at most 32 arguments"
      (Just "split the native surface into functions whose signatures fit the bridge")
  case foreignSymbol function of
    Just (Located spanValue symbol) | Text.null symbol ->
      report "E3068" spanValue
        "a foreign symbol cannot be empty"
        (Just "write the exact function name exported by the library")
    Just symbol -> checkLoaderName "symbol" symbol
    _ -> pure ()
  mapM_ (checkParameter layouts handles declared)
    [ parameter
    | (index, parameter) <- zip [0 ..] (foreignParameters function)
    , not (foreignParameterContext (locatedValue parameter) || Set.member index callbackArguments)
    ]
  case foreignBounds handles layouts (foreignParameters function) of
    Left (at, message) -> report "E3098" at message
      (Just "name one or more distinct input runs from this declaration")
    Right _ -> pure ()
  mapM_ checkNullable (zip [0 ..] (foreignParameters function))
  case resolveReturnedRun handles layouts declared function of
    Left (at, message) -> report "E3098" at message
      (Just "use an owned array result with a fixed-width length slot and a same-block release")
    Right (Just _) -> pure ()
    Right Nothing -> checkOrdinaryResult layouts declared function result
 where
  checkNullable (index, Located _ parameter)
    | Just at <- foreignParameterNullable parameter
    , foreignParameterOut parameter || foreignParameterContext parameter
      || Set.member index callbackArguments || not (validLoan parameter) =
        report "E3063" at "nullable applies only to a foreign reference input"
          (Just "declare a nullable shared or mutable loan")
    | otherwise = pure ()
  validLoan parameter = case foreignParameterType parameter of
    Just written -> loanFor handles layouts written /= Nothing || runLoanFor handles layouts written /= Nothing
    Nothing -> False
  result = crossingFor handles layouts (foreignResult function)
    <|> optionalHandleFor handles (foreignResult function)

checkObjectiveC :: RecordLayouts -> [ForeignClass] -> Map.Map Text ForeignFunction -> Located ForeignFunction -> Checker ()
checkObjectiveC layouts classes declared (Located at function) =
  mapM_ checkMethod (foreignMethod function)
 where
  parameters = map locatedValue (foreignParameters function)
  names = Set.fromList (map (locatedValue . foreignClassName) classes)
  checkMethod method = do
    let written@(Located selectorSpan selector) = foreignMethodSelector method
    checkLoaderName "Objective-C selector" written
    when (Text.null selector) $
      report "E3068" selectorSpan "an Objective-C selector cannot be empty" Nothing
    when (foreignSymbol function /= Nothing) $
      report "E3063" at "an Objective-C method declaration names one selector" Nothing
    arguments <- case foreignMethodClass method of
      Just (Located classSpan name) -> do
        unless (Set.member name names) $
          report "E3063" classSpan "declare the Objective-C class in this foreign block" Nothing
        pure parameters
      Nothing -> case parameters of
        receiver : rest | instanceReceiver receiver -> pure rest
        _ -> do
          report "E3063" at "an Objective-C instance method needs a class handle as its first parameter" Nothing
          pure []
    when (Text.count ":" selector /= length arguments
        || (not (null arguments) && not (Text.isSuffixOf ":" selector))) $
      report "E3063" selectorSpan "the Objective-C selector does not match the declared argument count"
        (Just "give one selector segment ending in a colon per argument after the receiver")
    when (length arguments + 2 > foreignArgumentLimit) $
      report "E3069" at "an Objective-C method has too many native arguments"
        (Just "the receiver and selector use two positions in the native signature")
    let transfer = foreignReleasedBy function /= Nothing && not (foreignResultBorrowed function)
        initializing = objectiveCInitializer (ObjectiveCMethod selector Nothing)
    case methodResult of
      Just HandleCrossing{}
        | objectiveCRetainedFamily selector && not transfer ->
            report "E3066" selectorSpan "this Objective-C method family returns a retained object"
              (Just "declare the result as owned or counted and name its objc_release function")
        | not (objectiveCRetainedFamily selector) && transfer ->
            report "E3066" selectorSpan "this Objective-C method family returns a borrowed object"
              (Just "declare a borrowed result or adapt the retained result through a C function")
      _ -> pure ()
    when (initializing && isHandle methodResult && foreignMethodClass method /= Nothing) $
      report "E3063" selectorSpan "an Objective-C initializer must take an instance receiver" Nothing
    mapM_ (checkRelease selector) (foreignReleasedBy function)
  methodResult = crossingFor names layouts (foreignResult function)
    <|> optionalHandleFor names (foreignResult function)
  instanceReceiver parameter =
    not (foreignParameterOut parameter) && case foreignParameterType parameter >>= crossingFor names layouts of
      Just HandleCrossing{} -> True
      _ -> False
  checkRelease selector (Located releaseSpan name) =
    case Map.lookup name declared of
      Just release
        | foreignMethod release == Nothing
        , fmap locatedValue (foreignSymbol release) == Just "objc_release" -> pure ()
      _ -> report "E3067" releaseSpan ("the Objective-C method " <> selector <> " must release owned results through objc_release")
        (Just "declare a same-block C function with symbol \"objc_release\"")

checkLoaderName :: Text -> Located Text -> Checker ()
checkLoaderName label (Located at name) =
  when (Text.any (== '\0') name) $
    report "E3068" at ("a foreign " <> label <> " cannot contain a nought")
      (Just "write the complete name as it is passed to the platform loader")

checkOrdinaryResult :: RecordLayouts -> Map.Map Text ForeignFunction -> ForeignFunction -> Maybe Crossing -> Checker ()
checkOrdinaryResult layouts declared function result = do
  {-| A run of bytes a library allocated is a resource: it has a length that
      arrives beside it and a release that frees it, and a declaration cannot
      yet say either. Refused where it is written rather than answered with
      storage nobody owns. -}
  when (result == Just BytesCrossing) $
    report "E3073" (locatedSpan (foreignResult function))
      "a foreign result cannot be Bytes"
      ( Just
          ( "a run of bytes a library allocated needs a length and a release; "
              <> "declare what it hands back another way"
          )
      )
  case foreignResult function of
    Located at (ReferenceType _ _) -> refuseLoanOutput at
    written | isArrayCrossingSyntax written ->
      refuseValueArray (locatedSpan written)
    written | isOptionCrossingSyntax written, result == Nothing ->
      refuseOptionalHandle (locatedSpan written)
    written -> refuseUncrossable layouts written result
  checkOwnership declared function result

checkParameter
  :: RecordLayouts
  -> Set.Set Text
  -> Map.Map Text ForeignFunction
  -> Located ForeignParameter
  -> Checker ()
checkParameter layouts handles declared (Located spanValue parameter) =
  case foreignParameterType parameter of
    Nothing ->
      report "E3062" spanValue
        ( "foreign parameter " <> locatedValue (foreignParameterName parameter)
            <> " names no type"
        )
        (Just "give every foreign parameter a type; nothing here can be inferred")
    Just written@(Located at (ReferenceType _ pointee)) -> do
      if foreignParameterOut parameter
        then refuseLoanOutput at
        else when (loanFor handles layouts written == Nothing && runLoanFor handles layouts written == Nothing) $
          report "E3095" (locatedSpan pointee)
            "this type cannot be lent across a foreign boundary"
            (Just "lend a fixed-width scalar, a scalar-only record, or an array of those elements")
      checkSlotOwnership declared spanValue parameter Nothing
    Just written | isArrayCrossingSyntax written -> refuseValueArray (locatedSpan written)
    Just written | isOptionCrossingSyntax written ->
      case optionalHandleFor handles written of
        Just handle | not (foreignParameterOut parameter) ->
          checkSlotOwnership declared spanValue parameter (Just handle)
        _ -> refuseOptionalHandle (locatedSpan written)
    Just written -> do
      case parameterCrossingFor handles layouts written of
        Just NothingCrossing ->
          report "E3070" (locatedSpan written)
            "a foreign parameter cannot be ()"
            (Just "() describes a function returning no value; it is not an argument value")
        crossing -> do
          refuseUncrossable layouts written crossing
          {-| A run of bytes crosses one way: lent to the library, read-only,
              for the length of the call. A slot is the other direction — the
              library writes into what the slot names — and the two cannot be
              the same thing.

              Admitting it would hand a library the address of storage the
              language holds as unchanging, and let it write there. Nothing
              downstream would notice: the value would go on being read as the
              one it was, and the length would still be the length it had.

              A run the library writes into is a real shape and a different
              contract: storage the caller owns and a length the library is
              told. It is refused here until a declaration can say both. -}
          when (foreignParameterOut parameter && crossing == Just BytesCrossing) $
            report "E3074" (maybe spanValue locatedSpan (foreignParameterType parameter))
              "a foreign slot cannot be Bytes"
              ( Just
                  ( "a run of bytes crosses lent and read-only; a run the library writes "
                      <> "into needs storage the caller owns and a length it is told"
                  )
              )
          checkSlotOwnership declared spanValue parameter crossing

refuseLoanOutput :: Span -> Checker ()
refuseLoanOutput at =
  report "E3094" at "a foreign result or output slot cannot be a loan"
    (Just "use a reference only in a parameter supplied by the caller")

refuseValueArray :: Span -> Checker ()
refuseValueArray at =
  report "E3096" at "an array cannot cross a foreign boundary by value"
    (Just "lend an array using a reference parameter")

refuseOptionalHandle :: Span -> Checker ()
refuseOptionalHandle at =
  report "E3097" at "only a declared handle may cross as an optional input or result"
    (Just "write Option[Handle] for a nullable pointer, or Handle alone for an output slot")

{-| What ownership a slot must carry, and what an ordinary parameter may not.

    A handle a library writes into a slot is a resource the program now holds,
    so the same rule the result follows applies: it is owned, and it names the
    release. An ordinary parameter owns nothing — the caller already had the
    value and passing it transfers nothing — so `owned` on one is a claim the
    boundary would not honour. -}
checkSlotOwnership
  :: Map.Map Text ForeignFunction
  -> Span
  -> ForeignParameter
  -> Maybe Crossing
  -> Checker ()
checkSlotOwnership declared spanValue parameter crossing
  | not (foreignParameterOut parameter) =
      when (foreignParameterOwned parameter) $
        report "E3072" spanValue
          "only an output slot may be owned"
          ( Just
              ( "a parameter the caller supplies was already theirs; write out "
                  <> locatedValue (foreignParameterName parameter)
                  <> " if the library writes it"
              )
          )
  | isHandle crossing && not (foreignParameterOwned parameter) =
      report "E3066" spanValue
        "a foreign handle slot must be owned"
        (Just "write owned Handle by release; borrowed foreign lifetimes are not represented yet")
  | foreignParameterOwned parameter && not (isHandle crossing) =
      report "E3065" spanValue
        "only something this library hands back can be owned"
        ( Just
            ( "declare the slot as a type the block itself declares; a number "
                <> "or a piece of text is copied here and there is nothing to release"
            )
        )
  | otherwise = case foreignParameterReleasedBy parameter of
      Nothing -> pure ()
      Just (Located releaseSpan name) -> case Map.lookup name declared of
        Nothing ->
          report "E3064" releaseSpan
            ("this library declares no " <> name <> " to release with")
            (Just "declare the release in the same foreign block as what it frees")
        Just release -> case crossing of
          Just (HandleCrossing handle) -> checkReleaseShape releaseSpan handle release
          _ -> pure ()

refuseUncrossable :: RecordLayouts -> Located TypeSyntax -> Maybe Crossing -> Checker ()
refuseUncrossable layouts written crossing = case crossing of
  Just _ -> pure ()
  Nothing -> case oversizedRecord layouts written of
    Just count ->
      report "E3071" (locatedSpan written)
        ("this foreign record has " <> Text.pack (show count) <> " fields; the bridge accepts at most 32")
        (Just "split the native surface into records whose layouts fit the bridge")
    Nothing ->
      report "E3063" (locatedSpan written)
        "this type cannot cross a foreign boundary"
        (Just ("what may cross: " <> crossableNames))

oversizedRecord :: RecordLayouts -> Located TypeSyntax -> Maybe Int
oversizedRecord layouts (Located _ syntax) = case syntax of
  NamedType (ModuleName (name :| [])) [] -> do
    fields <- Map.lookup name layouts
    let count = length fields
    if count > foreignRecordFieldLimit then Just count else Nothing
  _ -> Nothing

{-| An owned result is a handle, it names the function that frees it, and that
    function is one this library declares.

    The reason ownership belongs in the declaration is that it can be checked
    there. A release named in a comment is a leak nobody sees; a release named
    in another library is a call into the wrong allocator; and an owned number
    is nothing at all, since there is nothing to free. -}
checkOwnership :: Map.Map Text ForeignFunction -> ForeignFunction -> Maybe Crossing -> Checker ()
checkOwnership declared function result = case (result, foreignReleasedBy function) of
  (Just (HandleCrossing _), Nothing)
    | foreignResultBorrowed function -> pure ()
    | foreignResultCounted function ->
        report "E3075" (locatedSpan (foreignResult function))
          "a counted foreign result names no release"
          (Just "write counted Handle by release, naming the function that drops one reference")
    | otherwise ->
        report "E3066" (locatedSpan (foreignResult function))
          "a foreign handle result must say what it transfers"
          ( Just
              ( "write owned Handle by release for one the library gives away, "
                  <> "borrowed Handle for one it keeps, or counted Handle by release "
                  <> "for one more reference to something it counts"
              )
          )
  (_, _)
    | foreignResultCounted function && not (isHandle result) ->
        report "E3065" (locatedSpan (foreignResult function))
          "only something this library hands back can be counted"
          ( Just
              ( "declare the result as a type the block itself declares; a number "
                  <> "or a piece of text is copied here and there is nothing to count"
              )
          )
    | foreignResultBorrowed function && not (isHandle result) ->
        report "E3065" (locatedSpan (foreignResult function))
          "only something this library hands back can be borrowed"
          ( Just
              ( "declare the result as a type the block itself declares; a number "
                  <> "or a piece of text is copied here and there is nothing to borrow"
              )
          )
    | foreignResultBorrowed function ->
        report "E3074" (locatedSpan (foreignResult function))
          "a borrowed foreign result cannot name a release"
          (Just "the library keeps what it returned; drop the by clause, or write owned instead")
  (_, Nothing) -> pure ()
  (_, Just (Located spanValue name)) -> do
    when (not (isHandle result)) $
      report "E3065" spanValue
        "only something this library hands back can be owned"
        ( Just
            ( "declare the result as a type the block itself declares; a number "
                <> "or a piece of text is copied here and there is nothing to release"
            )
        )
    case Map.lookup name declared of
      Nothing ->
        report "E3064" spanValue
          ("this library declares no " <> name <> " to release with")
          (Just "declare the release in the same foreign block as what it frees")
      Just release -> case result of
        Just (HandleCrossing handle) -> checkReleaseShape spanValue handle release
        _ -> pure ()

{-| A release takes exactly the handle it frees, and answers nothing a caller
    can act on.

    One parameter, because more would leave the runtime unable to identify one
    atomic ownership transfer.

    The result is where this used to say unit and nothing else, and that made
    the rule unusable against the libraries it exists for. Releasing is the one
    operation C libraries conventionally report a status from — `sqlite3_close`
    and `sqlite3_finalize` answer `int`, `gzclose` and `fclose` answer `int` —
    so a boundary admitting only `void` cannot bind them directly, and every
    such library needs a C shim written for it whose only work is to discard a
    number.

    So a scalar result is admitted and discarded. The reasoning that produced
    the original rule is kept whole, because it was about the *caller*: nothing
    is handed back, so release failure still cannot be treated as recoverable
    after the library may already have destroyed the resource.

    A handle result stays refused. That is not a status but the library handing
    something else back, and nobody would claim it. -}
checkReleaseShape :: Span -> Text -> ForeignFunction -> Checker ()
checkReleaseShape spanValue handle release =
  unless (parameterMatches && resultMatches && foreignReleasedBy release == Nothing && foreignMethod release == Nothing) $
    report "E3067" spanValue
      (locatedValue (foreignName release) <> " does not release one " <> handle)
      (Just ("declare it as fn " <> locatedValue (foreignName release) <> "(value: "
        <> handle <> ") -> (), or -> a number the library reports its status with"))
 where
  parameterMatches = case foreignParameters release of
    [Located _ parameter]
      | not (foreignParameterOut parameter) -> case foreignParameterType parameter of
          Just written ->
            crossingFor (Set.singleton handle) Map.empty written == Just (HandleCrossing handle)
          Nothing -> False
    _ -> False
  resultMatches = case crossingFor (Set.singleton handle) Map.empty (foreignResult release) of
    Just NothingCrossing -> True
    Just (SignedCrossing _) -> True
    Just (UnsignedCrossing _) -> True
    _ -> False

isHandle :: Maybe Crossing -> Bool
isHandle crossing = case crossing of
  Just (HandleCrossing _) -> True
  _ -> False
