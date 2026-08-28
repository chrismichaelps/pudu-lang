{-| @Type.Check.Record — constructing a record, and a variant that names its
    payload.

    A field's value is an expression and an expression may be a record
    construction, so one of the two directions has to be an argument rather than
    an import. This is that direction, the same shape the parser and the call
    checker already use for their own recursion. -}
module Pudu.Type.Check.Record
  ( CheckValue (..)
  , namedVariantShape
  , recordType
  ) where

import Control.Monad (foldM, unless, when)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.IntegerLiteral (ParsedInteger (..), parseIntegerLiteral)
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameSegments, moduleNameText)
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Declaration (..)
  , Expression (..)
  , FieldInit (..)
  , Function (..)
  , FunctionBody (..)
  , Impl (..)
  , MatchArm (..)
  , Module (..)
  , Parameter
  , Statement (..)
  , Trait (..)
  , TypeParam (..)
  , Visibility (Exported)
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , CheckerProducts (..)
  , DeclaredTypes (..)
  , bindName
  , finalizeIntegerLiterals
  , finalizeIntegerLiteralsBetween
  , finalizeIntegerLiteralsSince
  , freshVariable
  , inTypeScope
  , inTypeScopeWith
  , integerLiteralCheckpoint
  , LoopFrame (..)
  , enterLoop
  , enterUnsafe
  , leaveLoop
  , loopTarget
  , markLoopBroken
  , withoutLoops
  , leaveUnsafe
  , warn
  , recordUnsafeFunction
  , recordComptimeFunction
  , withComptime
  , lookupField
  , lookupVariant
  , lookupVariantFields
  , lookupTypeParams
  , lookupName
  , recordExpression
  , report
  , withRigidBounds
  , validateIntegerLiteralsSince
  , runChecker
  , withDeclared
  )
import Pudu.Type.Check.Pattern (bindPattern, freshFor, substituteRigid)
import Pudu.Type.Check.Iteration (iterationElement)
import Pudu.Type.Check.Safety
  ( checkComptimeCall
  , checkUnsafeCall
  , reportUnusedCapabilities
  , requireComptimePurity
  )
import Pudu.Type.Check.Call
  ( CheckExpression (..)
  , checkCallee
  , throughBorrow
  , traitQualifiedCall
  )
import Pudu.Type.Check.Coherence (checkCoherence)
import Pudu.Type.Check.Rule
  ( awaitType
  , binaryType
  , enclosingFunctionType
  , enclosingReturnType
  , instantiateWith
  , callType
  , elementType
  , literalType
  , memberType
  , nameType
  , selfName
  , namedVariantAsValue
  , qualifiedMemberType
  , tryType
  , unaryType
  )
import Pudu.Type.Check.Method
  ( declareBounds
  , declareMethods
  , declareBuiltinConstructors
  , declareTraitMembers
  , dischargeObligations
  , functionRigid
  , implAliases
  , implBounds
  , implRigid
  , traitBounds
  , traitRigid
  , traitTable
  )
import Pudu.Type.Exhaust (checkExhaustive)
import Pudu.Type.Formation
  ( collectDeclaredFrom
  , declaredParameterType
  , formOptionalType
  , formType
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value
  ( NominalId (..)
  , Scheme (..)
  , monotype
  , polytype
  , Type (..)
  , boolType
  , integerType
  )
import Pudu.Type.Interface (ImportTypes)
import Pudu.Type.Check.Import (collectImportedDeclared, declareImportedTypes)

{-| @Check.Record.CheckValue — checking a value, from where a field is checked.

    Two directions are needed rather than one: a field with a written value is
    checked *against* its declared type, so a literal of mixed implementations
    reaches the field's own type rather than being inferred on its own first. -}
data CheckValue = CheckValue
  { valueOf :: DeclaredTypes -> [Text] -> Located Expression -> Checker Type
  , valueAgainst :: DeclaredTypes -> [Text] -> Type -> Located Expression -> Checker Type
  }

{-| A record construction is checked field by field against its declaration,
    and every declared field must be supplied. -}
recordType
  :: CheckValue
  -> DeclaredTypes
  -> [Text]
  -> Span
  -> ModuleName
  -> [Located FieldInit]
  -> Checker Type
recordType checking declared rigid spanValue path fields = do
  let name = NonEmpty.last (moduleNameSegments path)
      identity = Map.findWithDefault (NominalId Nothing (moduleNameText path))
        (moduleNameText path) (declaredNames declared)
  declaredFieldTypes <- lookupField identity
  case declaredFieldTypes of
    Nothing -> do
      variantShape <- namedVariantShape name
      case variantShape of
        Just (owner, ownerParams, expected) ->
          variantRecordType checking declared rigid spanValue name owner ownerParams expected fields
        Nothing -> do
          positional <- lookupVariant name
          report "E3007" spanValue (name <> " is not a record type")
            ( Just $ case positional of
                Just (_, _, payload) | not (null payload) ->
                  name <> " carries a positional payload; write "
                    <> name <> "(...) with one argument per element"
                Just _ -> name <> " carries no payload; write " <> name <> " on its own"
                Nothing -> "construct a record whose type declares fields"
            )
          mapM_ (checkFieldInit checking declared rigid) fields
          pure ErrorType
    Just declaredFields' -> do
      {-| A generic record is instantiated at every construction, exactly as a
          generic sum already was. `Boxed{value: 7}` is a `Boxed[Int]`, and the
          field is checked against `Int` rather than against the declaration's
          rigid parameter — which nothing could ever satisfy. -}
      parameters <- maybe [] id <$> lookupTypeParams identity
      replacements <- freshFor parameters
      let expected =
            [ (fieldName, substituteRigid replacements fieldType)
            | (fieldName, fieldType) <- declaredFields'
            ]
      mapM_ (checkField checking declared rigid expected) fields
      let supplied = map (locatedValue . fieldInitName . locatedValue) fields
          missing = [fieldName | (fieldName, _) <- expected, fieldName `notElem` supplied]
      case missing of
        [] -> pure ()
        _ ->
          report "E3008" spanValue
            (name <> " construction is missing " <> Text.intercalate ", " missing)
            (Just "supply every declared field")
      pure (NominalType identity (map snd replacements))

{-| A variant's payload paired with the names it declared for it.

    A variant is present here only when its declaration gave names. The names
    sit over the same positional payload a bare `Circle(Int)` would carry, so
    nothing downstream needs to know which spelling was used. -}

{-| A variant's payload paired with the names it declared for it.

    A variant is present here only when its declaration gave names. The names
    sit over the same positional payload a bare `Circle(Int)` would carry, so
    nothing downstream needs to know which spelling was used. -}
namedVariantShape :: Text -> Checker (Maybe (NominalId, [Text], [(Text, Type)]))
namedVariantShape name = do
  fieldNames <- lookupVariantFields name
  variant <- lookupVariant name
  pure $ case (fieldNames, variant) of
    (Just names, Just (owner, ownerParams, payload))
      | length names == length payload -> Just (owner, ownerParams, zip names payload)
    _ -> Nothing

{-| Construct a variant by naming its payload elements.

    The variant's own type is instantiated at the construction, exactly as a
    record's is, so `Wrap{value: 7}` is a `Wrap[Int]` and the field is checked
    against `Int` rather than against the declaration's rigid parameter. -}

{-| Construct a variant by naming its payload elements.

    The variant's own type is instantiated at the construction, exactly as a
    record's is, so `Wrap{value: 7}` is a `Wrap[Int]` and the field is checked
    against `Int` rather than against the declaration's rigid parameter. -}
variantRecordType
  :: CheckValue
  -> DeclaredTypes
  -> [Text]
  -> Span
  -> Text
  -> NominalId
  -> [Text]
  -> [(Text, Type)]
  -> [Located FieldInit]
  -> Checker Type
variantRecordType checking declared rigid spanValue name owner ownerParams declaredShape fields = do
  replacements <- freshFor ownerParams
  let expected =
        [ (fieldName, substituteRigid replacements fieldType)
        | (fieldName, fieldType) <- declaredShape
        ]
  mapM_ (checkField checking declared rigid expected) fields
  let supplied = map (locatedValue . fieldInitName . locatedValue) fields
      missing = [fieldName | (fieldName, _) <- expected, fieldName `notElem` supplied]
  case missing of
    [] -> pure ()
    _ ->
      report "E3008" spanValue
        (name <> " construction is missing " <> Text.intercalate ", " missing)
        (Just "supply every declared field")
  pure (NominalType owner (map snd replacements))

checkField
  :: CheckValue
  -> DeclaredTypes
  -> [Text]
  -> [(Text, Type)]
  -> Located FieldInit
  -> Checker ()
checkField checking declared rigid expected located@(Located fieldSpan field) = do
  let name = locatedValue (fieldInitName field)
  case lookup name expected of
    Nothing -> do
      _ <- checkFieldInit checking declared rigid located
      report "E3005" fieldSpan ("no declared field " <> name)
        (Just "check the field name against the type declaration")
    {-| The declared field type is an expectation, so it reaches the value the
        same way a binding's annotation does. A field declared
        `Array[dynamic Node]` accepts a literal of mixed implementations; before
        this the literal was inferred on its own and its elements disagreed
        before the field's type was ever consulted. -}
    Just declaredType -> case fieldInitValue field of
      Just value -> do
        _ <- valueAgainst checking declared rigid declaredType value
        pure ()
      Nothing -> do
        actual <- checkFieldInit checking declared rigid located
        _ <- unify fieldSpan declaredType actual
        pure ()

checkFieldInit :: CheckValue -> DeclaredTypes -> [Text] -> Located FieldInit -> Checker Type
checkFieldInit checking declared rigid (Located fieldSpan field) = case fieldInitValue field of
  Just value -> valueOf checking declared rigid value
  Nothing -> nameType fieldSpan (locatedValue (fieldInitName field) NonEmpty.:| [])
