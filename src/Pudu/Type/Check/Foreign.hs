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
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Capability (ForeignCapability)
  , Foreign (..)
  , ForeignFunction (..)
  , Parameter (..)
  , TypeSyntax
  )
import Pudu.Source (Span)
import Pudu.Type.Env (Checker, DeclaredTypes, bindName, recordUnsafeFunction, report)
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
  inputs <- mapM (parameterCrossing declared layouts handles) (foreignParameters function)
  result <- formedCrossing declared layouts handles (foreignResult function)
  let name = locatedValue (foreignName function)
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

parameterCrossing
  :: DeclaredTypes -> RecordLayouts -> Set.Set Text -> Located Parameter -> Checker Type
parameterCrossing declared layouts handles (Located _ parameter) =
  case parameterType parameter of
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
checkOne layouts handles declared (Located _ function) = do
  case foreignSymbol function of
    Just (Located spanValue symbol) | Text.null symbol ->
      report "E3068" spanValue
        "a foreign symbol cannot be empty"
        (Just "write the exact function name exported by the library")
    _ -> pure ()
  mapM_ (checkParameter layouts handles) (foreignParameters function)
  refuseUncrossable (locatedSpan (foreignResult function)) result
  checkOwnership declared function result
 where
  result = crossingFor handles layouts (foreignResult function)

checkParameter :: RecordLayouts -> Set.Set Text -> Located Parameter -> Checker ()
checkParameter layouts handles (Located spanValue parameter) = case parameterType parameter of
  Nothing ->
    report "E3062" spanValue
      ( "foreign parameter " <> locatedValue (parameterName parameter)
          <> " names no type"
      )
      (Just "give every foreign parameter a type; nothing here can be inferred")
  Just written -> refuseUncrossable (locatedSpan written) (crossingFor handles layouts written)

refuseUncrossable :: Span -> Maybe Crossing -> Checker ()
refuseUncrossable spanValue crossing = case crossing of
  Just _ -> pure ()
  Nothing ->
    report "E3063" spanValue
      "this type cannot cross a foreign boundary"
      (Just ("what may cross: " <> crossableNames))

{-| An owned result is a handle, it names the function that frees it, and that
    function is one this library declares.

    The reason ownership belongs in the declaration is that it can be checked
    there. A release named in a comment is a leak nobody sees; a release named
    in another library is a call into the wrong allocator; and an owned number
    is nothing at all, since there is nothing to free. -}
checkOwnership :: Map.Map Text ForeignFunction -> ForeignFunction -> Maybe Crossing -> Checker ()
checkOwnership declared function result = case (result, foreignReleasedBy function) of
  (Just (HandleCrossing _), Nothing) ->
    report "E3066" (locatedSpan (foreignResult function))
      "a foreign handle result must be owned"
      (Just "write owned Handle by release; borrowed foreign lifetimes are not represented yet")
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
    [Located _ parameter] -> case parameterType parameter of
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
