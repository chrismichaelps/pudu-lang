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
  , bytesType
  , decimalType
  , floatType
  , integerType
  , isErrorType
  , renderType
  , Capabilities
  , noCapabilities
  , capabilitiesOf
  , capabilityList
  , capabilitiesCover
  , capabilitiesUnion
  , capabilityName
  , renderCapabilities
  , restrictedBy
  , stringType
  , unitType
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Data.Bits ((.&.), (.|.), setBit, testBit, zeroBits)
import Data.String (IsString (..))
import Data.Word (Word8)
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameText)
import Pudu.Frontend.Syntax.Tree (Capability (..))

{-| The unchecked abilities a function requires of whoever calls it.

    A set of at most four things, held as bits rather than as a list. Two types
    are compared on every unification, so the comparison is one machine word
    here instead of a walk over a list whose order would also have to be
    normalised first. -}
newtype Capabilities = Capabilities Word8
  deriving stock (Eq, Ord, Show)

noCapabilities :: Capabilities
noCapabilities = Capabilities zeroBits

capabilitiesOf :: [Capability] -> Capabilities
capabilitiesOf = Capabilities . foldr (\capability bits -> setBit bits (fromEnum capability)) zeroBits

capabilityList :: Capabilities -> [Capability]
capabilityList (Capabilities bits) =
  [capability | capability <- [minBound .. maxBound], testBit bits (fromEnum capability)]

{-| Whether the first set covers the second.

    Used where a requirement meets a grant rather than where two types meet:
    types match exactly, and only a granting region is allowed to hold more than
    was asked of it. -}
capabilitiesCover :: Capabilities -> Capabilities -> Bool
capabilitiesCover (Capabilities granted) (Capabilities required) =
  granted .&. required == required

capabilitiesUnion :: Capabilities -> Capabilities -> Capabilities
capabilitiesUnion (Capabilities left) (Capabilities right) = Capabilities (left .|. right)

capabilityName :: Capability -> Text
capabilityName capability = case capability of
  RawCapability -> "raw"
  ForeignCapability -> "foreign"
  UncheckedCapability -> "unchecked"
  NullCapability -> "null"

{-| The abilities a set names, for a diagnostic to read back. -}
renderCapabilities :: Capabilities -> Text
renderCapabilities = Text.intercalate ", " . map capabilityName . capabilityList

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
  {-| A parameter of higher kind applied to its arguments.

      The head is a `RigidType` inside the body that declared the parameter, and
      a `VariableType` once a scheme has been instantiated. It is never a named
      constructor, because one of those already carries its own arguments, and
      never a computation over types, which is what keeps solving it decidable
      and a mismatch explainable. -}
  | AppliedType !Type ![Type]
  | VariableType !TypeVar
  {-| A function that requires unchecked abilities of whoever calls it.

      A wrapper rather than a field on the function type, because the ordinary
      function is the ordinary case and should not carry a set nearly every one
      of them leaves empty. It also means a restricted function and a plain one
      are different types, which is the whole point: a value cannot lose what it
      requires by being stored in a variable or passed as an argument, because
      the requirement is in the type that travels with it. -}
  | RestrictedType !Capabilities !Type
  | UnitTypeValue
  | NeverType
  | ErrorType
  deriving stock (Eq, Show)

{-| @Type.Value.Scheme — a type with the parameters a call instantiates and the
    trait bounds each of them must satisfy -}
data Scheme = Scheme
  {-| Each parameter beside how many type arguments it takes. Zero is the
      ordinary parameter; a greater number is one standing for a constructor,
      and instantiation replaces it with a variable that is applied rather than
      one that stands alone. -}
  { schemeParams :: ![(Text, Int)]
  , schemeBounds :: ![(Text, [NominalId])]
  , schemeType :: !Type
  }
  deriving stock (Eq, Show)

{-| A scheme with no parameters and nothing to prove. -}
monotype :: Type -> Scheme
monotype typeValue = Scheme{schemeParams = [], schemeBounds = [], schemeType = typeValue}

{-| A scheme over declared parameters carrying their bounds. -}
polytype :: [(Text, Int)] -> [(Text, [NominalId])] -> Type -> Scheme
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

bytesType :: Type
bytesType = NominalType "Bytes" []

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

{-| The type a declaration's own capabilities give it.

    A declaration that said `unsafe` is wrapped even when it named nothing: the
    blanket form still requires an open region of its caller, and leaving it an
    ordinary function type is what let it lose that requirement by being stored
    in a variable. An ordinary declaration is left exactly as it was, so the
    common signature carries no set at all. -}
restrictedBy :: Maybe [Capability] -> Type -> Type
restrictedBy declared inner = case declared of
  Nothing -> inner
  Just capabilities -> RestrictedType (capabilitiesOf capabilities) inner

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
  {-| Rendered the way it is written, so a mismatch quotes something a reader
      can search for in their own source. -}
  RestrictedType capabilities inner ->
    "unsafe(" <> renderCapabilities capabilities <> ") " <> renderType inner
  ReferenceTypeValue mutable target ->
    (if mutable then "&mut " else "&") <> renderType target
  RigidType name -> name
  AppliedType head' arguments
    | null arguments -> renderType head'
    | otherwise ->
        renderType head' <> "[" <> Text.intercalate ", " (map renderType arguments) <> "]"
  VariableType (TypeVar identifier) -> variableName identifier
  UnitTypeValue -> "()"
  NeverType -> "Never"
  ErrorType -> "?"
