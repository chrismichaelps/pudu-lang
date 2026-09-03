{-| @Type.Check.Foreign — checks a declaration of a library written elsewhere

    A foreign declaration is the only description of the function that exists:
    there is no body to read and no definition to jump to. So it is checked more
    carefully than ordinary code rather than less — every mistake it can hold is
    caught where it is written, because where it is called the mistake is a
    corrupted stack rather than a diagnostic. -}
module Pudu.Type.Check.Foreign
  ( declareForeign
  , checkForeign
  ) where

import Control.Monad (unless)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Foreign.Crossing (Crossing, crossableNames, crossingFor, crossingType)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Capability (ForeignCapability)
  , Foreign (..)
  , ForeignFunction (..)
  , Parameter (..)
  )
import Pudu.Source (Span)
import Pudu.Type.Env (Checker, bindName, recordUnsafeFunction, report)
import Pudu.Type.Value (Type (..), monotype)

{-| Give every foreign function a type before anything calls it.

    The declaration is an assertion by whoever wrote it that this signature
    matches the library, and nothing can check that assertion. What can be done
    is to make the assertion visible: the name is bound like any other, so a
    call is checked, hover shows the signature, and going to the definition
    arrives at the declaration — which is the definition, as far as this program
    is concerned. -}
declareForeign :: Foreign -> Checker ()
declareForeign value = mapM_ declareOne (foreignFunctions value)

declareOne :: Located ForeignFunction -> Checker ()
declareOne (Located _ function) = do
  let inputs = map parameterCrossing (foreignParameters function)
      result = maybe ErrorType crossingType (crossingFor (foreignResult function))
      name = locatedValue (foreignName function)
  bindName name (monotype (FunctionTypeValue False inputs result))
  {-| Every foreign call needs the capability, without the declaration saying
      so. The signature is unverifiable by construction, and the language
      already has a word for an assertion of that kind. -}
  recordUnsafeFunction name [ForeignCapability]

parameterCrossing :: Located Parameter -> Type
parameterCrossing (Located _ parameter) =
  case parameterType parameter >>= crossingFor of
    Just crossing -> crossingType crossing
    Nothing -> ErrorType

{-| What the declaration itself can be wrong about.

    Three things, each catchable here: a type that cannot cross, an owned result
    that names no release, and a release that is not declared in this library.
    The fourth — a signature that does not match what the library actually
    exports — is the one nothing can catch, which is why the other three are
    worth catching. -}
checkForeign :: Foreign -> Checker ()
checkForeign value = mapM_ (checkOne released) (foreignFunctions value)
 where
  released = Set.fromList (map (locatedValue . foreignName . locatedValue) (foreignFunctions value))

checkOne :: Set.Set Text -> Located ForeignFunction -> Checker ()
checkOne declared (Located _ function) = do
  mapM_ checkParameter (foreignParameters function)
  checkResult (foreignResult function) (crossingFor (foreignResult function))
  checkRelease declared function

checkParameter :: Located Parameter -> Checker ()
checkParameter (Located spanValue parameter) = case parameterType parameter of
  Nothing ->
    report "E3062" spanValue
      ( "foreign parameter " <> locatedValue (parameterName parameter)
          <> " names no type"
      )
      (Just "give every foreign parameter a type; nothing here can be inferred")
  Just written -> refuseUncrossable (locatedSpan written) (crossingFor written)

checkResult :: Located a -> Maybe Crossing -> Checker ()
checkResult written = refuseUncrossable (locatedSpan written)

refuseUncrossable :: Span -> Maybe Crossing -> Checker ()
refuseUncrossable spanValue crossing = case crossing of
  Just _ -> pure ()
  Nothing ->
    report "E3063" spanValue
      "this type cannot cross a foreign boundary"
      (Just ("what may cross: " <> crossableNames))

{-| An owned result names the function that frees it, and that function is one
    this library declares.

    The reason ownership belongs in the declaration is that it can be checked
    there. A release named in a comment is a leak nobody sees; a release named
    in another library is a call into the wrong allocator. -}
checkRelease :: Set.Set Text -> ForeignFunction -> Checker ()
checkRelease declared function = case foreignReleasedBy function of
  Nothing -> pure ()
  Just (Located spanValue name) ->
    unless (Set.member name declared) $
      report "E3064" spanValue
        ("this library declares no " <> name <> " to release with")
        (Just "declare the release in the same foreign block as what it frees")
