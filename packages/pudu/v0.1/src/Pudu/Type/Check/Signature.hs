{-| @Type.Check.Signature — what a declaration must state about itself.

    These are the rules a declaration has to satisfy that are not about the type
    it turns out to have: an exported name must say its type rather than leave a
    reader to infer it from a body they cannot see, a trait member must say its
    own, and `Self` stays rigid while the trait that names it is checked.

    Nothing here calls back into checking, which is what lets it be a module
    rather than an argument: it decides what a declaration owes before any body
    is looked at. -}
module Pudu.Type.Check.Signature
  ( adoptDeclaredSignature
  , nonMutatingMethods
  , requireFunctionAnnotations
  , requireInterfaceAnnotations
  , selfBoundAsBound
  , selfRigid
  , traitAliases
  ) where

import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree
  ( Function (..)
  , Visibility (Exported)
  )
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , report
  )
import Pudu.Type.Unify (unify)
import Pudu.Type.Value
  ( NominalId (..)
  , Scheme (..)
  , Type (..)
  )

{-| `Self` inside a trait is the implementing type, which is unknown while the
    trait itself is checked, so it stays a rigid parameter there. -}
traitAliases :: DeclaredTypes -> DeclaredTypes
traitAliases = id

{-| Check a function body against its declared result. Exported signatures are
    annotated interfaces; a trait member receives its canonical trait as the
    rigid `Self` bound used by default-body method calls. -}

{-| Unify a body's signature with the one the module already holds for the
    name, position by position.

    Only a signature of the same arity is tied: a mismatch there is a defect
    the declaration pass already reported, and unifying through it would
    produce a second, more confusing message. -}
adoptDeclaredSignature :: Function -> [Type] -> Type -> Scheme -> Checker ()
adoptDeclaredSignature value inputs result scheme = case schemeType scheme of
  FunctionTypeValue _ declaredInputs declaredResult
    | length declaredInputs == length inputs -> do
        mapM_ tie (zip declaredInputs inputs)
        tie (declaredResult, result)
  _ -> pure ()
 where
  headSpan = locatedSpan (functionName value)
  tie (left, right) = () <$ unify headSpan left right

{-| The constant an index expression names, when it names one.

    A tuple's members have different types, so indexing one is only meaningful
    at a known position. Everything else — an array, a string, a computed index
    — does not care, and reports `Nothing`. -}

requireFunctionAnnotations :: Function -> Checker ()
requireFunctionAnnotations value
  | functionVisibility value /= Exported && not (functionAsync value) = pure ()
  | otherwise = do
      mapM_ requireParameter (functionParameters value)
      case functionReturn value of
        Just _ -> pure ()
        Nothing ->
          report "E3010" (locatedSpan (functionName value))
            (functionKind <> " function " <> locatedValue (functionName value) <> " needs a return type")
            (Just returnHelp)
 where
  functionKind
    | functionVisibility value == Exported = "exported"
    | otherwise = "async"
  returnHelp
    | functionVisibility value == Exported =
        "annotate the return type; an exported signature is read without its body"
    | otherwise =
        "annotate the return type so callers can form Task[S, E] without inspecting the body"
  requireParameter (Located parameterSpan parameter) = case Tree.parameterType parameter of
    Just _ -> pure ()
    Nothing ->
      report "E3010" parameterSpan
        (functionKind <> " parameter " <> locatedValue (Tree.parameterName parameter) <> " needs a type")
        (Just parameterHelp)
  parameterHelp
    | functionVisibility value == Exported = "annotate every parameter of an exported function"
    | otherwise = "annotate every parameter of an async function so calls do not determine its contract"

requireInterfaceAnnotations :: Text -> Function -> Checker ()
requireInterfaceAnnotations kind value = do
  mapM_ requireParameter (functionParameters value)
  case functionReturn value of
    Just _ -> pure ()
    Nothing ->
      report "E3010" (locatedSpan (functionName value))
        (kind <> " " <> locatedValue (functionName value) <> " needs a return type")
        (Just "annotate the complete signature because importers read it without its body")
 where
  requireParameter (Located parameterSpan parameter) = case Tree.parameterType parameter of
    Just _ -> pure ()
    Nothing ->
      report "E3010" parameterSpan
        (kind <> " parameter " <> locatedValue (Tree.parameterName parameter) <> " needs a type")
        (Just "annotate every interface-carried parameter")

{-| The bound a trait member adds: `Self` satisfies the trait it belongs to,
    which lets a default body call other trait methods on `self`. -}
selfBoundAsBound :: NominalId -> [(Text, [NominalId])]
selfBoundAsBound traitName = [("Self", [traitName])]

{-| `Self` is rigid inside a trait member so that `formType` produces
    `RigidType "Self"` rather than `NominalType "Self"`, routing method
    calls through `rigidMethod` and the trait bound installed by
    `selfBoundAsBound`. -}

{-| `Self` is rigid inside a trait member so that `formType` produces
    `RigidType "Self"` rather than `NominalType "Self"`, routing method
    calls through `rigidMethod` and the trait bound installed by
    `selfBoundAsBound`. -}
selfRigid :: NominalId -> [(Text, Int)]
selfRigid _ = [("Self", 0)]

{-| The built-in methods that answer with a new collection rather than changing
    the one they were given. `length`, `get`, `indexOf`, and `contains` are
    absent because discarding an answer to a question is merely pointless, not
    wrong: a reader who wrote it was asking, and the compiler has nothing to
    tell them that the line does not already say. -}
nonMutatingMethods :: [Text]
nonMutatingMethods =
  ["push", "pop", "insert", "remove", "slice", "reverse", "map", "filter"]

{-| The bound a trait member adds: `Self` satisfies the trait it belongs to,
    which lets a default body call other trait methods on `self`. -}
