{-| @Type.Value.Module — represents formed types -}
module Pudu.Type.Value
  ( NominalId (..)
  , Scheme (..)
  , canonicalNominal
  , nominalKey
  , monotype
  , polytype
  , Type (..)
  , TypeVar (..)
  , boolType
  , charType
  , decimalType
  , floatType
  , integerType
  , isErrorType
  , renderType
  , stringType
  , unitType
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Data.String (IsString (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameText)

{-| @Type.Value.Var — one inference variable -}
newtype TypeVar = TypeVar Int
  deriving stock (Eq, Ord, Show)

data NominalId = NominalId
  { nominalModule :: !(Maybe ModuleName)
  , nominalName :: !Text
  }
  deriving stock (Eq, Ord, Show)

instance IsString NominalId where
  fromString = NominalId Nothing . Text.pack

canonicalNominal :: ModuleName -> Text -> NominalId
canonicalNominal owner = NominalId (Just owner)

nominalKey :: NominalId -> Text
nominalKey value = case nominalModule value of
  Nothing -> nominalName value
  Just owner -> moduleNameText owner <> "." <> nominalName value

{-| @Type.Value.Type — a formed type.

    Nominal types are identified by declaration name and arguments, matching
    [[architecture/SEMANTICS]]'s rule that nominal equality is by identity;
    tuples, functions, and references are structural. `ErrorType` is poison: it
    unifies with everything so one mistake does not cascade. -}
data Type
  = NominalType !NominalId ![Type]
  {-| Some value implementing a trait, whose own type is not named here.

      This is the one place the language admits a value whose concrete type is
      not known statically. It exists because a heterogeneous collection — a
      list of listeners, a registry of handlers, a factory's result — cannot be
      written any other way: a sum type closes the set, and a bound names one
      type per call site. -}
  | DynamicTypeValue !NominalId
  | TupleTypeValue ![Type]
  | FunctionTypeValue !Bool ![Type] !Type
  | ReferenceTypeValue !Bool !Type
  | RigidType !Text
  | VariableType !TypeVar
  | UnitTypeValue
  | NeverType
  | ErrorType
  deriving stock (Eq, Show)

{-| @Type.Value.Scheme — a type with the parameters a call instantiates and the
    trait bounds each of them must satisfy -}
data Scheme = Scheme
  { schemeParams :: ![Text]
  , schemeBounds :: ![(Text, [NominalId])]
  , schemeType :: !Type
  }
  deriving stock (Eq, Show)

{-| A scheme with no parameters and nothing to prove. -}
monotype :: Type -> Scheme
monotype typeValue = Scheme{schemeParams = [], schemeBounds = [], schemeType = typeValue}

{-| A scheme over declared parameters carrying their bounds. -}
polytype :: [Text] -> [(Text, [NominalId])] -> Type -> Scheme
polytype params bounds typeValue =
  Scheme{schemeParams = params, schemeBounds = bounds, schemeType = typeValue}

integerType :: Type
integerType = NominalType "Int" []

floatType :: Type
floatType = NominalType "Float64" []

decimalType :: Type
decimalType = NominalType "Decimal" []

boolType :: Type
boolType = NominalType "Bool" []

stringType :: Type
stringType = NominalType "Str" []

charType :: Type
charType = NominalType "Char" []

unitType :: Type
unitType = UnitTypeValue

isErrorType :: Type -> Bool
isErrorType typeValue = case typeValue of
  ErrorType -> True
  _ -> False

{-| An unsolved inference variable reads as a letter rather than a number: a
    signature shown as `fn(a) -> a` says "some type" the way a reader expects,
    and the number carried no meaning outside the checker. -}
variableName :: Int -> Text
variableName identifier
  | identifier < 26 = Text.singleton (toEnum (fromEnum 'a' + identifier))
  | otherwise =
      Text.singleton (toEnum (fromEnum 'a' + identifier `mod` 26))
        <> Text.pack (show (identifier `div` 26))

{-| Render a type the way a diagnostic quotes it. -}
renderType :: Type -> Text
renderType typeValue = case typeValue of
  DynamicTypeValue identity -> "dynamic " <> nominalName identity
  NominalType identity arguments
    | null arguments -> nominalName identity
    | otherwise -> nominalName identity <> "[" <> Text.intercalate ", " (map renderType arguments) <> "]"
  TupleTypeValue members -> "(" <> Text.intercalate ", " (map renderType members) <> ")"
  FunctionTypeValue asynchronous inputs result ->
    (if asynchronous then "async fn(" else "fn(")
      <> Text.intercalate ", " (map renderType inputs)
      <> ") -> " <> renderType result
  ReferenceTypeValue mutable target ->
    (if mutable then "&mut " else "&") <> renderType target
  RigidType name -> name
  VariableType (TypeVar identifier) -> variableName identifier
  UnitTypeValue -> "()"
  NeverType -> "Never"
  ErrorType -> "?"
