{-| @Program.Lsp.PatternCompletion — typed candidates for one match arm -}
module Pudu.Lsp.PatternCompletion
  ( PatternCandidate (..)
  , patternCandidates
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameSegments, moduleNameText, moduleQualifier)
import Pudu.Frontend.Syntax.Tree
  ( Expression
  , FieldPattern (..)
  , Import (..)
  , MatchArm (..)
  , Module (..)
  , Pattern (..)
  , TypeSyntax (..)
  )
import Pudu.Lsp.Shapes (SumShape (..), VariantShape (..), renderTypeSyntax)
import Pudu.Source (spanEnd, spanStart, unOffset)
import Pudu.Type (Type (..), TypeInfo, renderType, typeAt)
import Pudu.Type.Value (NominalId (..), nominalKey)

data PatternCandidate = PatternCandidate
  { candidateLabel :: !Text
  , candidateDetail :: !Text
  }
  deriving stock (Eq, Show)

{-| What may be written at `offset` in an arm's pattern.

    At the top of the pattern that is a variant of the subject's type; inside a
    constructor's payload, a variant of that payload's type, found by following
    each enclosing constructor's declared payload from the subject down. Only
    at the top do earlier arms cover anything, since an arm covers whole
    values, not payloads. Anywhere else inside a pattern — a tuple, a record
    field, a payload whose type is not a known sum — only `_` is certain. -}
patternCandidates
  :: Maybe TypeInfo
  -> Map Text SumShape
  -> Module
  -> Located Expression
  -> [Located MatchArm]
  -> Located MatchArm
  -> Int
  -> [PatternCandidate]
patternCandidates types sums parsed subject arms arm offset = case positionIn offset (armPattern (locatedValue arm)) of
  TopLevel -> candidatesFor True subjectType <> [PatternCandidate "_" "any value" | not wildcardCovered]
  Payload path -> candidatesFor False (subjectType >>= along path) <> [PatternCandidate "_" "any value"]
  NestedElsewhere -> [PatternCandidate "_" "any value"]
 where
  subjectType = throughReferenceType <$> (types >>= (`typeAt` locatedSpan subject))
  candidatesFor top target = case target of
    Just (NominalType identity arguments) -> variantsOf top identity arguments
    _ -> []
  -- The type of the payload each step names, from the type holding it.
  along path current = case path of
    [] -> Just current
    (variant, index) : rest -> case current of
      NominalType identity arguments
        | Just shape <- Map.lookup (nominalKey identity) sums
        , Just (TupleVariant members) <- lookup variant (sumVariants shape)
        , written : _ <- drop index members
        , Just next <- syntaxType (sumModule shape) (Map.fromList (zip (sumTypeParams shape) arguments)) written ->
            along rest (throughReferenceType next)
        | nominalModule identity == Nothing, nominalName identity `elem` ["Option", "Result"] ->
            case (nominalName identity, variant, index, arguments) of
              ("Option", "Some", 0, [inner]) -> along rest inner
              ("Result", "Ok", 0, inner : _) -> along rest inner
              ("Result", "Err", 0, [_, failure]) -> along rest failure
              _ -> Nothing
      _ -> Nothing
  -- A payload's written type as the declaring module means it.
  syntaxType owner substitutions (Located _ written) = case written of
    NamedType path writtenArguments
      | name NonEmpty.:| [] <- moduleNameSegments path -> do
          arguments <- traverse (syntaxType owner substitutions) writtenArguments
          case Map.lookup name substitutions of
            Just bound | null writtenArguments -> Just bound
            _
              | Map.member (moduleNameText owner <> "." <> name) sums ->
                  Just (NominalType (NominalId (Just owner) name) arguments)
              | name `elem` ["Option", "Result"] -> Just (NominalType (NominalId Nothing name) arguments)
              | otherwise -> Nothing
    ReferenceType _ target -> syntaxType owner substitutions target
    _ -> Nothing
  variantsOf top identity arguments = case nominalModule identity of
    Nothing -> case nominalName identity of
      "Option" -> builtinOffered top "Option" [("Some", take 1 arguments), ("None", [])] Just
      "Result" -> builtinOffered top "Result" [("Ok", take 1 arguments), ("Err", take 1 (drop 1 arguments))] Just
      _ -> []
    Just owner -> case Map.lookup (nominalKey identity) sums of
      Just shape -> offered top identity arguments shape (spelledFrom identity owner)
      Nothing -> []
  offered top identity arguments shape spell =
    [ PatternCandidate spelled (variantDetail (nominalName identity) substitutions variant variantShape)
    | (variant, variantShape) <- sumVariants shape
    , not (top && covered variant variantShape)
    , Just spelled <- [spell variant]
    ]
   where
    substitutions = Map.fromList (zip (sumTypeParams shape) arguments)
  builtinOffered top owner shapes spell =
    [ PatternCandidate spelled (owner <> "." <> variant <> payloadDetail (map renderType payload))
    | (variant, payload) <- shapes
    , not (top && covered variant (if null payload then UnitVariant else TupleVariant []))
    , Just spelled <- [spell variant]
    ]
  spelledFrom identity owner variant
    | owner == locatedValue (moduleName parsed) =
        Just (if ambiguous variant then nominalName identity <> "." <> variant else variant)
    | otherwise = listToMaybe
        [ spelled
        | Located _ imported <- moduleImports parsed
        , locatedValue (importModule imported) == owner
        , Just spelled <- [importSpelling identity imported variant]
        ]
  importSpelling identity imported variant
    | null (importItems imported) =
        Just (maybe (moduleQualifier (locatedValue (importModule imported))) locatedValue (importAlias imported) <> "." <> variant)
    | variant `elem` map locatedValue (importItems imported) = Just variant
    | nominalName identity `elem` map locatedValue (importItems imported) =
        Just (nominalName identity <> "." <> variant)
    | otherwise = Nothing
  ambiguous variant =
    length [() | shape <- Map.elems sums, variant `elem` map fst (sumVariants shape)] > 1
  covered variant shape = or
    [ coversVariant variant shape (locatedValue (armPattern other))
    | Located _ other <- takeWhile ((/= locatedSpan arm) . locatedSpan) arms
    , armGuard other == Nothing
    ]
  wildcardCovered = any coversEverything
    [ locatedValue (armPattern other)
    | Located _ other <- takeWhile ((/= locatedSpan arm) . locatedSpan) arms
    , armGuard other == Nothing
    ]
  coversEverything pattern = case pattern of
    WildcardPattern -> True
    BindingPattern _ -> True
    AlternativePattern alternatives -> any (coversEverything . locatedValue) alternatives
    _ -> False

{-| Where in a pattern a cursor stands. -}
data Position
  = TopLevel
  {-| Inside payloads: each enclosing constructor, outermost first, with the
      position of the payload element the cursor is in. -}
  | Payload ![(Text, Int)]
  | NestedElsewhere

positionIn :: Int -> Located Pattern -> Position
positionIn offset (Located spanValue pattern) = case pattern of
  ConstructorPattern name payload
    | offset > unOffset (spanStart spanValue) + Text.length (moduleNameText name) ->
        let variant = NonEmpty.last (moduleNameSegments name)
            index = length [() | member <- payload, unOffset (spanEnd (locatedSpan member)) < offset]
            inner = [found | member <- payload, covering member, let found = positionIn offset member]
         in case inner of
              Payload deeper : _ -> Payload ((variant, index) : deeper)
              NestedElsewhere : _ -> NestedElsewhere
              _ -> Payload [(variant, index)]
  AlternativePattern alternatives -> case [positionIn offset member | member <- alternatives, covering member] of
    found : _ -> found
    [] -> TopLevel
  TuplePattern _ -> NestedElsewhere
  ArrayPattern {} -> NestedElsewhere
  RecordPattern {} | offset > unOffset (spanStart spanValue) -> NestedElsewhere
  _ -> TopLevel
 where
  covering (Located inner _) = unOffset (spanStart inner) <= offset && offset <= unOffset (spanEnd inner)

coversVariant :: Text -> VariantShape -> Pattern -> Bool
coversVariant variant shape pattern = case pattern of
  WildcardPattern -> True
  BindingPattern _ -> True
  ConstructorPattern name payload ->
    NonEmpty.last (moduleNameSegments name) == variant && all irrefutable payload
  RecordPattern (Just name) fields rest ->
    NonEmpty.last (moduleNameSegments name) == variant
      && recordComplete shape fields rest
      && all irrefutableField fields
  AlternativePattern alternatives -> any (coversVariant variant shape . locatedValue) alternatives
  _ -> False
 where
  recordComplete variantShape fields rest = case variantShape of
    RecordVariant expected -> rest || length fields == length expected
    _ -> False
  irrefutableField (Located _ field) = maybe True irrefutable (fieldPatternValue field)

irrefutable :: Located Pattern -> Bool
irrefutable (Located _ pattern) = case pattern of
  WildcardPattern -> True
  BindingPattern _ -> True
  TuplePattern members -> all irrefutable members
  _ -> False

variantDetail :: Text -> Map Text Type -> Text -> VariantShape -> Text
variantDetail owner substitutions variant shape = owner <> "." <> variant <> case shape of
  UnitVariant -> ""
  TupleVariant members -> payloadDetail (map (renderTypeSyntax substitutions) members)
  RecordVariant fields ->
    "{" <> Text.intercalate ", " [name <> ": " <> renderTypeSyntax substitutions fieldType | (name, fieldType) <- fields] <> "}"

payloadDetail :: [Text] -> Text
payloadDetail members
  | null members = ""
  | otherwise = "(" <> Text.intercalate ", " members <> ")"

throughReferenceType :: Type -> Type
throughReferenceType typeValue = case typeValue of
  ReferenceTypeValue _ target -> throughReferenceType target
  other -> other
