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

import Control.Monad (unless, when)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Foreign.Crossing
  ( Crossing (..)
  , RecordLayouts
  , crossableNames
  , crossingFor
  , crossingType
  , foreignArgumentLimit
  , foreignRecordFieldLimit
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( Capability (ForeignCapability)
  , Foreign (..)
  , ForeignFunction (..)
  , ForeignParameter (..)
  , TypeSyntax (..)
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker, DeclaredTypes, bindName, recordRequiredArity, recordUnsafeFunction, report )
import Pudu.Type.Formation (formType)
import Pudu.Type.Value (Type (..), capabilitiesOf, monotype)

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
declareForeign declared layouts value =
  mapM_ (declareOne declared layouts (foreignHandles value)) (foreignFunctions value)

declareOne
  :: DeclaredTypes -> RecordLayouts -> Set.Set Text -> Located ForeignFunction -> Checker ()
declareOne declared layouts handles (Located _ function) = do
  inputs <- mapM (parameterCrossing declared layouts handles) (ordinaryOf function)
  native <- formedCrossing declared layouts handles (foreignResult function)
  written <- mapM (slotAnswer declared layouts handles) (slotsOf function)
  let result = answeredType native written
      name = locatedValue (foreignName function)
  {-| Every foreign function requires the capability, and requires it in its
      own type, so a binding stored in a variable or passed on still asks for
      it wherever it is finally called. -}
  bindName name
    ( monotype
        ( RestrictedType (capabilitiesOf [ForeignCapability])
            (FunctionTypeValue False inputs result)
        )
    )
  {-| Every foreign call needs the capability, without the declaration saying
      so. The signature is unverifiable by construction, and the language
      already has a word for an assertion of that kind. -}
  recordUnsafeFunction name [ForeignCapability]
  {-| A foreign parameter never has a default: there is no caller on this side
      to apply one, so every argument the declaration names must be supplied. -}
  recordRequiredArity name (length inputs, length inputs)

{-| The parameters a caller supplies, and the ones the library writes.

    A slot is a native argument and not a Pudu one, so the two lists are what
    every phase after this asks for: the caller's arguments come from the first,
    the answer's shape from the second. -}
ordinaryOf :: ForeignFunction -> [Located ForeignParameter]
ordinaryOf function =
  [ parameter
  | parameter <- foreignParameters function
  , not (foreignParameterOut (locatedValue parameter))
  ]

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

parameterCrossing
  :: DeclaredTypes -> RecordLayouts -> Set.Set Text -> Located ForeignParameter -> Checker Type
parameterCrossing declared layouts handles (Located _ parameter) =
  case foreignParameterType parameter of
    Just written -> formedCrossing declared layouts handles written
    Nothing -> pure ErrorType

formedCrossing
  :: DeclaredTypes -> RecordLayouts -> Set.Set Text -> Located TypeSyntax -> Checker Type
formedCrossing declared layouts handles written =
  case crossingFor handles layouts written of
    {-| A handle and a record are both nominal types of this program, so their
        formed type is the ordinary one and a caller builds and reads one the
        ordinary way. -}
    Just (HandleCrossing _) -> formType declared [] written
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
checkForeign layouts value = mapM_ (checkOne layouts handles declared) (foreignFunctions value)
 where
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
  -> Located ForeignFunction
  -> Checker ()
checkOne layouts handles declared (Located functionSpan function) = do
  when (length (foreignParameters function) > foreignArgumentLimit) $
    report "E3069" functionSpan
      "a foreign function may take at most 32 arguments"
      (Just "split the native surface into functions whose signatures fit the bridge")
  case foreignSymbol function of
    Just (Located spanValue symbol) | Text.null symbol ->
      report "E3068" spanValue
        "a foreign symbol cannot be empty"
        (Just "write the exact function name exported by the library")
    _ -> pure ()
  mapM_ (checkParameter layouts handles declared) (foreignParameters function)
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
  refuseUncrossable layouts (foreignResult function) result
  checkOwnership declared function result
 where
  result = crossingFor handles layouts (foreignResult function)

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
    Just written -> do
      case crossingFor handles layouts written of
        Just NothingCrossing ->
          report "E3070" (locatedSpan written)
            "a foreign parameter cannot be ()"
            (Just "() describes a function returning no value; it is not an argument value")
        crossing -> do
          refuseUncrossable layouts written crossing
          checkSlotOwnership declared spanValue parameter crossing

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
    | otherwise ->
        report "E3066" (locatedSpan (foreignResult function))
          "a foreign handle result must say whether it is owned or borrowed"
          ( Just
              ( "write owned Handle by release for one the library gives away, or "
                  <> "borrowed Handle for one it keeps"
              )
          )
  (_, _)
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

{-| A release is deliberately one exact shape: the handle it frees, then unit.

    More parameters would leave the runtime unable to identify one atomic
    ownership transfer, and a result would suggest that release failure is
    recoverable after the library may already have destroyed the resource. -}
checkReleaseShape :: Span -> Text -> ForeignFunction -> Checker ()
checkReleaseShape spanValue handle release =
  unless (parameterMatches && resultMatches && foreignReleasedBy release == Nothing) $
    report "E3067" spanValue
      (locatedValue (foreignName release) <> " does not release one " <> handle)
      (Just ("declare it as fn " <> locatedValue (foreignName release) <> "(value: "
        <> handle <> ") -> ()"))
 where
  parameterMatches = case foreignParameters release of
    [Located _ parameter]
      | not (foreignParameterOut parameter) -> case foreignParameterType parameter of
          Just written ->
            crossingFor (Set.singleton handle) Map.empty written == Just (HandleCrossing handle)
          Nothing -> False
    _ -> False
  resultMatches =
    crossingFor (Set.singleton handle) Map.empty (foreignResult release) == Just NothingCrossing

isHandle :: Maybe Crossing -> Bool
isHandle crossing = case crossing of
  Just (HandleCrossing _) -> True
  _ -> False
