{-| @Type.Value.Module — represents formed types -}
module Pudu.Type.Value
  ( Scheme (..)
  , monotype
  , polytype
  , Type (..)
  , TypeVar (..)
  , boolType
  , charType
  , floatType
  , integerType
  , isErrorType
  , renderType
  , stringType
  , unitType
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

{-| @Type.Value.Var — one inference variable -}
newtype TypeVar = TypeVar Int
  deriving stock (Eq, Ord, Show)

{-| @Type.Value.Type — a formed type.

    Nominal types are identified by declaration name and arguments, matching
    [[architecture/SEMANTICS]]'s rule that nominal equality is by identity;
    tuples, functions, and references are structural. `ErrorType` is poison: it
    unifies with everything so one mistake does not cascade. -}
data Type
  = NominalType !Text ![Type]
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
  , schemeBounds :: ![(Text, [Text])]
  , schemeType :: !Type
  }
  deriving stock (Eq, Show)

{-| A scheme with no parameters and nothing to prove. -}
monotype :: Type -> Scheme
monotype typeValue = Scheme{schemeParams = [], schemeBounds = [], schemeType = typeValue}

{-| A scheme over declared parameters carrying their bounds. -}
polytype :: [Text] -> [(Text, [Text])] -> Type -> Scheme
polytype params bounds typeValue =
  Scheme{schemeParams = params, schemeBounds = bounds, schemeType = typeValue}

integerType :: Type
integerType = NominalType "Int" []

floatType :: Type
floatType = NominalType "Float64" []

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
  NominalType name arguments
    | null arguments -> name
    | otherwise -> name <> "[" <> Text.intercalate ", " (map renderType arguments) <> "]"
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
