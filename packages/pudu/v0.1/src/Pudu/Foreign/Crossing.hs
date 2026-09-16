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
  , RecordLayouts
  , recordLayouts
  , fitsCrossing
  , foreignArgumentLimit
  , foreignRecordFieldLimit
  ) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import qualified Data.Map.Strict as Map
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , FieldDeclaration (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeSyntax (..)
  )
import Data.String (fromString)
import Pudu.Type.Value (Type (..))
import Data.List.NonEmpty (NonEmpty (..))

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
  {-| A run of bytes the library reads, and only reads.

      Pudu's own storage, handed over as an address for the length of the call
      and no longer. The length travels as an ordinary argument because in C it
      is one: a run of bytes carries no terminator, so the library is told how
      far to read the way its other callers tell it. -}
  | BytesCrossing
  {-| An address the library hands back, under the name its own block gave it.

      Opaque: nothing here reads through it, and the name is carried so a
      texture cannot be passed where a window is wanted. A library's handles are
      not interchangeable, and one address type for all of them turns a mistake
      the checker could catch into one the library reports by failing. -}
  | HandleCrossing !Text
  {-| A record crossing by value, under its name and with its fields in the
      order the declaration wrote them.

      Where a field sits inside the record is the platform's answer rather than
      this one's, so only the names and widths are carried here; the boundary
      asks for the offsets when it lays the bytes out. -}
  | RecordCrossing !Text ![(Text, Crossing)]
  | NothingCrossing
  deriving stock (Eq, Show)

{-| The records a module declares, by name, with their fields in order.

    Built from the same declarations the checker and the evaluator each already
    walk, so both see one layout and neither has to be told about the other. -}
type RecordLayouts = Map.Map Text [(Text, Located TypeSyntax)]

{-| The fixed native call-frame capacity, exposed to declaration checking. -}
foreignArgumentLimit :: Int
foreignArgumentLimit = 32

{-| The fixed flat-record description capacity, exposed to declaration checking. -}
foreignRecordFieldLimit :: Int
foreignRecordFieldLimit = 32

recordLayouts :: [Located Declaration] -> RecordLayouts
recordLayouts declarations =
  Map.fromList
    [ (locatedValue (typeName value), fields)
    | Located _ (TypeDeclaration value) <- declarations
    , RecordDefinition declared <- [locatedValue (typeDefinition value)]
    , let fields =
            [ (locatedValue (fieldName field), fieldType field)
            | Located _ field <- declared
            ]
    ]

{-| The crossing a declared type describes, where it describes one.

    Anything absent from this is refused at the declaration, which is the point
    of stating it: a type that cannot cross is a diagnostic where it is written
    rather than a fault where it is called. -}
crossingFor :: Set Text -> RecordLayouts -> Located TypeSyntax -> Maybe Crossing
crossingFor handles layouts = crossingAt Set.empty
 where
  crossingAt enclosing (Located _ syntax) = case syntax of
    UnitType -> Just NothingCrossing
    NamedType (ModuleName (name :| [])) [] -> named enclosing name
    _ -> Nothing

  {-| A record's fields are themselves crossable, and may themselves be records.

      A camera holds two points, a font holds a texture, and a record that
      admitted only numbers would admit almost nothing a library actually
      passes. What crosses is the leaves: a record is described to the platform
      by the scalars it flattens to, in order, which is the same description the
      platform derives for the nesting itself.

      A record reached from inside itself has no flattening, because there is no
      end to its leaves. The set of records already open refuses it where it is
      written rather than looping. -}
  named enclosing name
    | Set.member name handles = Just (HandleCrossing name)
    | Set.member name enclosing = Nothing
    | Just fields <- Map.lookup name layouts =
        if null fields || length fields > foreignRecordFieldLimit
          then Nothing
          else RecordCrossing name <$> traverse (field (Set.insert name enclosing)) fields
    | otherwise = scalar name
   where
    field inner (label, written) = do
      crossing <- crossingAt inner written
      case crossing of
        NothingCrossing -> Nothing
        HandleCrossing _ -> Nothing
        {-| A record crosses as the leaves it flattens to, and a run of bytes is
            not a leaf: it is an address and a length that no field names. -}
        BytesCrossing -> Nothing
        _ -> Just (label, crossing)

  scalar name = case name of
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
    "Bytes" -> Just BytesCrossing
    _ -> Nothing

{-| What the declaration wrote, for a diagnostic to name back. -}
crossingName :: Crossing -> Text
crossingName crossing = case crossing of
  SignedCrossing width -> "Int" <> Text.pack (show width)
  UnsignedCrossing width -> "UInt" <> Text.pack (show width)
  FloatingCrossing width -> "Float" <> Text.pack (show width)
  BooleanCrossing -> "Bool"
  TextCrossing -> "Str"
  BytesCrossing -> "Bytes"
  HandleCrossing name -> name
  RecordCrossing name _ -> name
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
  "Int8 Int16 Int32 Int64, UInt8 UInt16 UInt32 UInt64, Float32 Float64, Bool, Str, Bytes, (), "
    <> "and a type the block itself declares"
