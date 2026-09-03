{-| @Program.Foreign.Crossing — what may pass between this language and another

    The set is stated rather than inferred. A general marshaller for arbitrary
    types is how an interface stops being able to say what it does, and every
    value it fails on fails when it is called rather than where it is written.
    [[ADR-0018 Calling a Library Written Elsewhere]] settles the list. -}
module Pudu.Foreign.Crossing
  ( Crossing (..)
  , crossingFor
  , crossingName
  , crossingType
  , crossableNames
  , fitsCrossing
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameSegments)
import Pudu.Frontend.Syntax.Tree (TypeSyntax (..))
import Data.String (fromString)
import Pudu.Type.Value (Type (..))
import qualified Data.List.NonEmpty as NonEmpty

{-| One value's representation on the other side.

    A width is part of the declaration rather than part of the program's type,
    which is the whole trick: `Int32` says how many bits leave, and what stays
    here is the language's own integer. A binding that spread machine widths
    through the code that calls it is how a foreign library's shape ends up
    dictating the shape of everything that touches it. -}
data Crossing
  = SignedCrossing !Int
  | UnsignedCrossing !Int
  | FloatingCrossing !Int
  | BooleanCrossing
  | TextCrossing
  | NothingCrossing
  deriving stock (Eq, Show)

{-| The crossing a declared type describes, where it describes one.

    Anything absent from this is refused at the declaration, which is the point
    of stating it: a type that cannot cross is a diagnostic where it is written
    rather than a fault where it is called. -}
crossingFor :: Located TypeSyntax -> Maybe Crossing
crossingFor (Located _ syntax) = case syntax of
  UnitType -> Just NothingCrossing
  NamedType path [] -> named (NonEmpty.last (moduleNameSegments path))
  _ -> Nothing
 where
  named name = case name of
    "Int8" -> Just (SignedCrossing 8)
    "Int16" -> Just (SignedCrossing 16)
    "Int32" -> Just (SignedCrossing 32)
    "Int64" -> Just (SignedCrossing 64)
    "UInt8" -> Just (UnsignedCrossing 8)
    "UInt16" -> Just (UnsignedCrossing 16)
    "UInt32" -> Just (UnsignedCrossing 32)
    "UInt64" -> Just (UnsignedCrossing 64)
    "Float32" -> Just (FloatingCrossing 32)
    "Float64" -> Just (FloatingCrossing 64)
    "Bool" -> Just BooleanCrossing
    "Str" -> Just TextCrossing
    _ -> Nothing

{-| What the declaration wrote, for a diagnostic to name back. -}
crossingName :: Crossing -> Text
crossingName crossing = case crossing of
  SignedCrossing width -> "Int" <> Text.pack (show width)
  UnsignedCrossing width -> "UInt" <> Text.pack (show width)
  FloatingCrossing width -> "Float" <> Text.pack (show width)
  BooleanCrossing -> "Bool"
  TextCrossing -> "Str"
  NothingCrossing -> "()"

{-| The type a crossed value has on this side.

    The same type the declaration wrote. This language already carries widths —
    `Int32` is one of its own types, not a spelling invented for the boundary —
    so a foreign signature is an ordinary signature, and a caller passing the
    wrong width is told so by the ordinary checker rather than by a second one
    that only exists here. -}
crossingType :: Crossing -> Type
crossingType crossing = case crossing of
  NothingCrossing -> UnitTypeValue
  _ -> NominalType (fromString (Text.unpack (crossingName crossing))) []

{-| Whether an integer is one the declared width can carry.

    Checked at the boundary rather than wrapped there. Silent wraparound is the
    original sin of calling C from anywhere: a value that does not fit becomes a
    different value, and the program continues with it. -}
fitsCrossing :: Crossing -> Integer -> Bool
fitsCrossing crossing value = case crossing of
  SignedCrossing width -> value >= negate (2 ^ (width - 1)) && value < 2 ^ (width - 1)
  UnsignedCrossing width -> value >= 0 && value < 2 ^ width
  _ -> True

{-| The names a declaration may write, for a diagnostic to offer. -}
crossableNames :: Text
crossableNames =
  "Int8 Int16 Int32 Int64, UInt8 UInt16 UInt32 UInt64, Float32 Float64, Bool, Str, ()"
