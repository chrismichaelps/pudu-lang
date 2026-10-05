{-| @Type.Check.Reflection — preserves heterogeneous field and owner identities -}
module Pudu.Type.Check.Reflection
  ( FieldCallback (..), reflectedParameters, checkSequenceElement, fieldCallee, checkBuildCall ) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Constraint (..), Expression (..), Function (..), Parameter (..), TypeSyntax (..) )
import Pudu.Semantic.Prelude (wiredInTypeNames)
import Pudu.Source (Span)
import Pudu.Type.Check.Bound (checkBounds)
import Pudu.Type.Check.Method (dischargeObligations)
import Pudu.Type.Env
  ( Checker, DeclaredTypes (..), report, withAdditionalRigidBounds, withLocalObligations )
import Pudu.Type.Formation (formBoundFor)
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value (NominalId, Type (..), canonicalNominal)

reflectedParameters :: DeclaredTypes -> [(Text, Int)] -> Located TypeSyntax -> [(Text, Int)]
reflectedParameters declared rigid (Located _ syntax) = case syntax of
  NamedType owner [_, Located _ (NamedType (ModuleName (name :| [])) [])]
    | Map.lookup (moduleNameText owner) (declaredNames declared) == Just (meta "Field")
    , name `notElem` map fst rigid
    , name `notElem` wiredInTypeNames
    , Map.notMember name (declaredNames declared) -> [(name, 0)]
  _ -> []

checkSequenceElement :: Span -> DeclaredTypes -> [(Text, Int)] -> Type -> Type -> Checker Type
checkSequenceElement at declared enclosing element source = do
  resolved <- zonk source
  case resolved of
    NominalType owner [target] | owner == meta "Fields" -> case element of
      NominalType field [held, RigidType name]
        | field == meta "Field", name `notElem` map fst enclosing
        , name `notElem` wiredInTypeNames, Map.notMember name (declaredNames declared) ->
        checked (unify at target held)
      ErrorType -> pure ErrorType
      _ -> refuse "a field sequence needs Field[T, F] with an abstract field type F"
    NominalType owner [target] | owner == meta "Variants" -> case element of
      NominalType variant [held] | variant == meta "Variant" ->
        checked (unify at target held)
      ErrorType -> pure ErrorType
      _ -> refuse "a variant sequence needs Variant[T] for the same owner"
    _ -> checked (unify at (NominalType "Array" [element]) resolved)
 where
  checked action = do
    matched <- action
    pure (if matched == ErrorType then ErrorType else element)
  refuse message = do
    report "E3001" at message (Just "iterate metadata with its owner and a fresh field type parameter")
    pure ErrorType

meta :: Text -> NominalId
meta = canonicalNominal (ModuleName ("Std" :| ["Meta"]))

{-| A callee whose one parameter is a field-indexed callback taking
    `Field[T, F]` for an F the call instantiates fresh. -}
data FieldCallback
  {-| `Meta.build` and a variant's `build`: the owner and the built value. -}
  = Building !Type !Type
  {-| `Meta.collect` and a variant's `collect`: the owner and the element. -}
  | Collecting !Type !Type

fieldCallee :: Type -> Maybe FieldCallback
fieldCallee callee = case callee of
  FunctionTypeValue _ [FunctionTypeValue _ [NominalType field [owner, VariableType held]] (VariableType answer)] result
    | field == meta "Field", held == answer -> Just (Building owner result)
  FunctionTypeValue _ [FunctionTypeValue _ [NominalType field [owner, VariableType held]]
      (NominalType "Option" [VariableType element])] (NominalType "Array" [VariableType collected])
    | field == meta "Field", element == collected, held /= element ->
        Just (Collecting owner (VariableType element))
  _ -> Nothing

{-| Check a field callback once, generically, as a compile-time loop body is
    checked: its field type and `where` subjects are rigid, its bounds install,
    and its obligations discharge before they disappear. For a build,
    answering F builds a `T` and answering `Result[F, E]` builds a
    `Result[T, E]` that stops at the first `Err`; a collect answers
    `Option[E]` per field. F may not escape into E either way. -}
checkBuildCall
  :: (DeclaredTypes -> [(Text, Int)] -> Located Expression -> Checker Type)
  -> DeclaredTypes -> [(Text, Int)] -> Span -> FieldCallback -> Located Expression
  -> Checker Type
checkBuildCall check declared rigid at shape callback = case locatedValue callback of
  LambdaExpression value
    | [Located _ parameter] <- functionParameters value
    , Just annotation <- parameterType parameter
    , Just _ <- functionReturn value -> do
        let subjects = [constraint | Located _ constraint <- functionConstraints value]
            variables = Map.toList (Map.fromList
              (reflectedParameters declared rigid annotation <>
              [(name, 0) | constraint <- subjects
              , let name = locatedValue (constraintSubject constraint), name `notElem` map fst rigid]))
            rigidHere = rigid <> variables
            bounds =
              [ (subject, map (formBoundFor declared rigidHere subject) (constraintBounds constraint))
              | constraint <- subjects, let subject = locatedValue (constraintSubject constraint) ]
        admitted <- checkBounds declared rigidHere
          [(locatedValue (constraintSubject constraint), constraintBounds constraint) | constraint <- subjects]
        if not admitted then pure ErrorType else do
          found <- withAdditionalRigidBounds bounds $ withLocalObligations $ do
            typed <- check declared rigidHere callback
            dischargeObligations
            pure typed
          resolved <- zonk found
          case resolved of
            FunctionTypeValue _ [NominalType field [held, RigidType name]] answer
              | field == meta "Field", name `elem` map fst variables -> case shape of
                  Building owner result -> do
                    _ <- unify at owner held
                    case answer of
                      RigidType answered | answered == name -> pure result
                      NominalType "Result" [RigidType answered, failure]
                        | answered == name, not (mentions name failure) ->
                            pure (NominalType "Result" [result, failure])
                      ErrorType -> pure ErrorType
                      _ -> refuse "a build callback answers its field type F or Result[F, E]"
                  Collecting owner element -> do
                    _ <- unify at owner held
                    case answer of
                      NominalType "Option" [answered] | not (mentions name answered) -> do
                        _ <- unify at element answered
                        pure (NominalType "Array" [answered])
                      ErrorType -> pure ErrorType
                      _ -> refuse "a collect callback answers Option[E] for an E that is not its field type"
            ErrorType -> pure ErrorType
            _ -> refuse "a build callback takes one Field[T, F] with an abstract field type F"
  _ -> refuse "a build callback is a function literal taking one Field[T, F] and declaring its answer"
 where
  refuse message = do
    report "E3001" at message (Just "write fn(field: Meta.Field[T, F]) -> F where F: Bound { ... }")
    pure ErrorType

mentions :: Text -> Type -> Bool
mentions name held = case held of
  RigidType other -> other == name
  NominalType _ arguments -> any (mentions name) arguments
  TupleTypeValue members -> any (mentions name) members
  FunctionTypeValue _ inputs output -> any (mentions name) inputs || mentions name output
  ReferenceTypeValue _ target -> mentions name target
  AppliedType target arguments -> mentions name target || any (mentions name) arguments
  RestrictedType _ target -> mentions name target
  _ -> False
