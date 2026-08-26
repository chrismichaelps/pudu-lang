{-| @Doc.Signature.Module — the searchable shape of an inferred type -}
module Pudu.Doc.Signature
  ( SigType (..)
  , Signature (..)
  , alphaNormalise
  , renderSigType
  , renderSignature
  , schemeSignature
  , signatureArity
  , sigTypeFromType
  , typeVariables
  ) where

import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Type.Value
  ( NominalId
  , Scheme (..)
  , Type (..)
  , TypeVar (..)
  , nominalKey
  , nominalName
  )

{-| @Doc.Signature.Type — one inferred type in the shape search compares.

    This mirrors the checker's `Type` rather than the written syntax, because
    the point of the index is to report what the compiler concluded: an
    unannotated function still has a signature, and an annotated one is
    reported as it was understood rather than as it was spelled.

    It is a separate type from `Type` for one reason: search needs `Ord` and a
    normal form, and neither belongs on the checker's own representation. -}
data SigType
  = SigCon !Text ![SigType]
  | SigVar !Text
  | SigRef !Bool !SigType
  | SigTuple ![SigType]
  | SigFun ![SigType] !SigType
  | SigUnit
  | SigNever
  | SigUnknown
  deriving stock (Eq, Ord, Show)

{-| @Doc.Signature.Value — a declaration's arguments, result, and bounds.

    A non-callable declaration has no arguments and its type as the result, so
    a constant and a nullary function are searched by the same shape. -}
data Signature = Signature
  { signatureConstraints :: ![(Text, [Text])]
  , signatureArguments :: ![SigType]
  , signatureResult :: !SigType
  }
  deriving stock (Eq, Ord, Show)

{-| The searchable signature of a scheme the checker produced. -}
schemeSignature :: Scheme -> Signature
schemeSignature scheme = case schemeType scheme of
  FunctionTypeValue _ inputs result ->
    Signature
      { signatureConstraints = bounds
      , signatureArguments = map sigTypeFromType inputs
      , signatureResult = sigTypeFromType result
      }
  other ->
    Signature
      { signatureConstraints = bounds
      , signatureArguments = []
      , signatureResult = sigTypeFromType other
      }
 where
  bounds =
    [ (name, map nominalName obligations)
    | (name, obligations) <- schemeBounds scheme
    , not (null obligations)
    ]

{-| Project the checker's type into the search shape.

    An unresolved inference variable stays a variable rather than becoming a
    wildcard: it means "the compiler did not pin this down", which is exactly
    what a type variable means to a search.

    `ErrorType` becomes `SigUnknown` so a module that failed to check still
    contributes the declarations that did check, instead of poisoning the whole
    index. Documentation for broken code is when documentation is most
    wanted. -}
sigTypeFromType :: Type -> SigType
sigTypeFromType typeValue = case typeValue of
  {-| A dynamic type searches as the trait it names, so `-> dyn Shape` is
      found by a reader who asked for `Shape`. -}
  DynamicTypeValue identity -> SigCon ("dynamic " <> nominalLabel identity) []
  NominalType identity arguments -> SigCon (nominalLabel identity) (map sigTypeFromType arguments)
  TupleTypeValue members -> SigTuple (map sigTypeFromType members)
  FunctionTypeValue _ inputs result -> SigFun (map sigTypeFromType inputs) (sigTypeFromType result)
  ReferenceTypeValue mutable target -> SigRef mutable (sigTypeFromType target)
  RigidType name -> SigVar name
  VariableType (TypeVar identity) -> SigVar ("_" <> Text.pack (show identity))
  UnitTypeValue -> SigUnit
  NeverType -> SigNever
  ErrorType -> SigUnknown

{-| A nominal type prints unqualified when it is unambiguous and qualified when
    it names its owner, matching how the checker itself identifies it. -}
nominalLabel :: NominalId -> Text
nominalLabel = nominalKey

{-| Rename type variables to their order of first appearance.

    Two signatures differing only in variable names are the same signature to a
    search: asking for `Array[a] -> a` is asking the same question as
    `Array[T] -> T`, and an index that told them apart would answer neither. -}
alphaNormalise :: Signature -> Signature
alphaNormalise signature =
  signature
    { signatureConstraints = map renameConstraint (signatureConstraints signature)
    , signatureArguments = map rename (signatureArguments signature)
    , signatureResult = rename (signatureResult signature)
    }
 where
  mapping = Map.fromList (zip (orderedVariables signature) canonicalNames)

  renameConstraint (name, obligations) = (Map.findWithDefault name name mapping, obligations)

  rename sigType = case sigType of
    SigVar name -> SigVar (Map.findWithDefault name name mapping)
    SigCon name arguments -> SigCon name (map rename arguments)
    SigRef mutable target -> SigRef mutable (rename target)
    SigTuple members -> SigTuple (map rename members)
    SigFun inputs result -> SigFun (map rename inputs) (rename result)
    other -> other

canonicalNames :: [Text]
canonicalNames = map (\index -> "%" <> Text.pack (show index)) [(0 :: Int) ..]

{-| Give the checker's unresolved inference variables readable names.

    A variable the reader wrote keeps its name. One the compiler invented is
    shown as `a`, `b`, `c`… in order of appearance, because `_47` names an
    internal counter and tells a reader nothing except that the compiler was
    counting. The renaming is display-only: search compares the structure, so
    two signatures cannot become equal by being printed alike. -}
readableVariables :: Signature -> Signature
readableVariables signature =
  signature
    { signatureArguments = map rename (signatureArguments signature)
    , signatureResult = rename (signatureResult signature)
    }
 where
  inferred = filter (Text.isPrefixOf "_") (orderedVariables signature)
  mapping = Map.fromList (zip inferred letterNames)

  rename sigType = case sigType of
    SigVar name -> SigVar (Map.findWithDefault name name mapping)
    SigCon name arguments -> SigCon name (map rename arguments)
    SigRef mutable target -> SigRef mutable (rename target)
    SigTuple members -> SigTuple (map rename members)
    SigFun inputs result -> SigFun (map rename inputs) (rename result)
    other -> other

{-| Variables in order of first appearance across arguments then result. -}
orderedVariables :: Signature -> [Text]
orderedVariables signature =
  distinct (concatMap collect (signatureArguments signature) <> collect (signatureResult signature))
 where
  collect sigType = case sigType of
    SigVar name -> [name]
    SigCon _ arguments -> concatMap collect arguments
    SigRef _ target -> collect target
    SigTuple members -> concatMap collect members
    SigFun inputs result -> concatMap collect inputs <> collect result
    _ -> []

  distinct = reverse . fst . foldl step ([], Set.empty)
   where
    step (seen, known) name
      | Set.member name known = (seen, known)
      | otherwise = (name : seen, Set.insert name known)

{-| `a` through `z`, then `a1`, `b1`, and so on: a signature with more than
    twenty-six unknowns is already unreadable, but it must still print. -}
letterNames :: [Text]
letterNames =
  [Text.singleton letter | letter <- ['a' .. 'z']]
    <> [ Text.singleton letter <> Text.pack (show index)
       | index <- [(1 :: Int) ..]
       , letter <- ['a' .. 'z']
       ]

{-| Every variable a signature mentions, which decides whether a query is
    polymorphic and therefore whether it can match a concrete signature. -}
typeVariables :: Signature -> Set Text
typeVariables signature = foldMap gather (signatureResult signature : signatureArguments signature)
 where
  gather sigType = case sigType of
    SigVar name -> Set.singleton name
    SigCon _ arguments -> foldMap gather arguments
    SigRef _ target -> gather target
    SigTuple members -> foldMap gather members
    SigFun inputs result -> foldMap gather inputs <> gather result
    _ -> Set.empty

{-| How many arguments a signature takes, which is the cheapest thing a search
    can reject on. -}
signatureArity :: Signature -> Int
signatureArity = length . signatureArguments

renderSigType :: SigType -> Text
renderSigType sigType = case sigType of
  SigCon name [] -> name
  SigCon name arguments -> name <> "[" <> Text.intercalate ", " (map renderSigType arguments) <> "]"
  SigVar name -> name
  SigRef mutable target -> (if mutable then "&mut " else "&") <> renderNested target
  SigTuple members -> "(" <> Text.intercalate ", " (map renderSigType members) <> ")"
  SigFun inputs result ->
    "fn(" <> Text.intercalate ", " (map renderSigType inputs) <> ") -> " <> renderSigType result
  SigUnit -> "()"
  SigNever -> "!"
  SigUnknown -> "?"

{-| A reference to a function type needs its parentheses back, because `&fn(A)
    -> B` would otherwise read as a function returning `B` from `&fn(A)`. -}
renderNested :: SigType -> Text
renderNested sigType = case sigType of
  SigFun{} -> "(" <> renderSigType sigType <> ")"
  other -> renderSigType other

{-| Render a signature the way a search result shows it: arguments and result
    separated by arrows, with bounds trailing in a `where` clause.

    Pudu writes bounds inside the type-parameter list, but a result line has no
    parameter list to write them in, and a reader scanning results wants the
    arrow shape first and the obligations second. -}
renderSignature :: Signature -> Text
renderSignature original =
  Text.intercalate " -> " (map renderSigType arguments <> [renderSigType (signatureResult signature)])
    <> constraintSuffix
 where
  signature = readableVariables original

  arguments = signatureArguments signature

  constraintSuffix = case rendered of
    [] -> Text.empty
    bounds -> " where " <> Text.intercalate ", " bounds

  rendered =
    [ name <> ": " <> Text.intercalate " + " obligations
    | (name, obligations) <- signatureConstraints signature
    , not (null obligations)
    ]
