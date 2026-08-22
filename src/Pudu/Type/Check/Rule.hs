{-| @Type.Check.Rule.Module — types the closed operator and access rules -}
module Pudu.Type.Check.Rule
  ( callType
  , countText
  , binaryType
  , elementType
  , instantiate
  , literalType
  , memberType
  , nameType
  , unaryType
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , addObligation
  , freshVariable
  , lookupField
  , lookupName
  , report
  , rigidBoundsOf
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value
  ( Scheme (..)
  , Type (..)
  , boolType
  , charType
  , floatType
  , integerType
  , renderType
  , stringType
  )

literalType :: Tree.Literal -> Type
literalType literal = case literal of
  Tree.IntegerValue _ -> integerType
  Tree.FloatValue _ -> floatType
  Tree.StringValue _ -> stringType
  Tree.CharValue _ -> charType
  Tree.BoolValue _ -> boolType
  Tree.NullValue -> ErrorType

{-| A name's type comes from its declaration. A declared generic is
    instantiated with fresh variables at every use, which is what makes one
    generic function usable at several types. -}
nameType :: Span -> NonEmpty.NonEmpty Text -> Checker Type
nameType spanValue names = do
  found <- lookupName (NonEmpty.head names)
  case found of
    Nothing -> pure ErrorType
    Just scheme -> instantiate spanValue scheme

{-| Instantiate a scheme with fresh variables and register the trait
    obligations its bounds impose, so a call proves what the declaration
    demanded once the argument types are known. -}
instantiate :: Span -> Scheme -> Checker Type
instantiate spanValue scheme
  | null (schemeParams scheme) = pure (schemeType scheme)
  | otherwise = do
      replacements <- mapM (\name -> (,) name <$> freshVariable) (schemeParams scheme)
      mapM_ (obligationsFor spanValue replacements) (schemeBounds scheme)
      pure (substitute replacements (schemeType scheme))

obligationsFor :: Span -> [(Text, Type)] -> (Text, [Text]) -> Checker ()
obligationsFor spanValue replacements (name, bounds) =
  case lookup name replacements of
    Nothing -> pure ()
    Just assigned -> mapM_ (addObligation spanValue assigned) bounds

substitute :: [(Text, Type)] -> Type -> Type
substitute replacements typeValue = case typeValue of
  RigidType name -> maybe typeValue id (lookup name replacements)
  NominalType name arguments -> NominalType name (map (substitute replacements) arguments)
  TupleTypeValue members -> TupleTypeValue (map (substitute replacements) members)
  FunctionTypeValue asynchronous inputs result ->
    FunctionTypeValue asynchronous
      (map (substitute replacements) inputs)
      (substitute replacements result)
  ReferenceTypeValue mutable target -> ReferenceTypeValue mutable (substitute replacements target)
  other -> other

unaryType :: Span -> Text -> Type -> Checker Type
unaryType spanValue operator operand = case operator of
  "!" -> unify spanValue boolType operand
  "-" -> pure operand
  "&" -> pure (ReferenceTypeValue False operand)
  "&mut" -> pure (ReferenceTypeValue True operand)
  _ -> pure operand

{-| Operator typing follows [[grammar/pudu]]'s bands: arithmetic keeps its
    operand type, comparison and equality produce `Bool`, boolean operators
    require `Bool`, a range produces a range over its endpoints, and assignment
    produces unit. -}
binaryType :: Span -> Text -> Type -> Type -> Checker Type
binaryType spanValue operator left right
  | operator == "=" = do
      _ <- unify spanValue left right
      pure UnitTypeValue
  | operator `elem` ["&&", "||"] = do
      _ <- unify spanValue boolType left
      _ <- unify spanValue boolType right
      pure boolType
  | operator `elem` ["==", "!="] = do
      _ <- unify spanValue left right
      pure boolType
  | operator `elem` ["<", "<=", ">", ">="] = do
      _ <- unify spanValue left right
      pure boolType
  | operator `elem` ["..", "..="] = do
      unified <- unify spanValue left right
      pure (NominalType "Range" [unified])
  | otherwise = unify spanValue left right

callType :: Span -> Type -> [Type] -> Checker Type
callType spanValue calleeType argumentTypes = case calleeType of
  ErrorType -> pure ErrorType
  FunctionTypeValue _ inputs result
    | length inputs == length argumentTypes -> do
        _ <- sequence (zipWith (unify spanValue) inputs argumentTypes)
        pure result
    | length argumentTypes < length inputs -> do
        _ <- sequence (zipWith (unify spanValue) inputs argumentTypes)
        pure result
    | otherwise -> do
        report "E3003" spanValue
          ( "expected " <> countText (length inputs)
              <> ", found " <> countText (length argumentTypes)
          )
          (Just "pass one argument per parameter, or give the parameter a default")
        pure result
  VariableType _ -> do
    result <- freshVariable
    _ <- unify spanValue calleeType (FunctionTypeValue False argumentTypes result)
    pure result
  _ -> do
    rendered <- zonk calleeType
    report "E3004" spanValue ("this is not callable: " <> renderCallee rendered)
      (Just "call a function, a variant constructor, or a value of function type")
    pure ErrorType

renderCallee :: Type -> Text
renderCallee = renderType

countText :: Int -> Text
countText total = case total of
  1 -> "1 argument"
  _ -> tshow total <> " arguments"

tshow :: Int -> Text
tshow = Text.pack . show

memberType :: Span -> Type -> Text -> Checker Type
memberType spanValue targetType member = do
  resolved <- zonk targetType
  case resolved of
    ErrorType -> pure ErrorType
    VariableType _ -> freshVariable
    NominalType name _ -> do
      fields <- lookupField name
      case fields >>= lookup member of
        Just found -> pure found
        Nothing -> methodType spanValue name member
    RigidType name -> do
      bounds <- rigidBoundsOf name
      rigidMethod spanValue name bounds member
    ReferenceTypeValue _ inner -> memberType spanValue inner member
    _ -> do
      report "E3005" spanValue ("a " <> renderType resolved <> " has no fields")
        (Just "read a field from a record value")
      pure ErrorType

{-| A method reached through a bound: the receiver is a parameter, and the trait
    its declaration named supplies the member. -}
rigidMethod :: Span -> Text -> [Text] -> Text -> Checker Type
rigidMethod spanValue name bounds member = case bounds of
  [] -> do
    report "E3005" spanValue (name <> " has no method " <> member)
      (Just "add a trait bound that declares the method")
    pure ErrorType
  traitText : rest -> do
    found <- lookupName (traitText <> "." <> member)
    case found of
      Nothing -> rigidMethod spanValue name rest member
      Just scheme -> do
        instantiated <- instantiate spanValue scheme
        case instantiated of
          FunctionTypeValue asynchronous (_ : inputs) result ->
            pure (FunctionTypeValue asynchronous inputs result)
          other -> pure other

{-| A member that is not a field may be a method of the receiver's type. A
    method call binds the receiver as its first parameter, so the member itself
    has the method's type with that parameter already supplied. -}
methodType :: Span -> Text -> Text -> Checker Type
methodType spanValue owner member = do
  found <- lookupName (owner <> "." <> member)
  case found of
    Nothing -> do
      report "E3005" spanValue (owner <> " has no field or method " <> member)
        (Just "check the name against the type declaration and its implementations")
      pure ErrorType
    Just scheme -> do
      instantiated <- instantiate spanValue scheme
      case instantiated of
        FunctionTypeValue asynchronous (_ : rest) result ->
          pure (FunctionTypeValue asynchronous rest result)
        other -> pure other

elementType :: Span -> Type -> Checker Type
elementType spanValue targetType = do
  resolved <- zonk targetType
  case resolved of
    ErrorType -> pure ErrorType
    VariableType _ -> freshVariable
    NominalType "Str" [] -> pure charType
    NominalType "Array" [element] -> pure element
    TupleTypeValue members -> case members of
      first : _ -> pure first
      [] -> pure ErrorType
    _ -> do
      report "E3006" spanValue ("a " <> renderType resolved <> " cannot be indexed")
        (Just "index a string, an array, or a tuple")
      pure ErrorType
