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
import Pudu.Frontend.Syntax.Name (moduleNameSegments, moduleQualifier)
import Pudu.Frontend.Syntax.Tree
  ( Expression
  , FieldPattern (..)
  , Import (..)
  , MatchArm (..)
  , Module (..)
  , Pattern (..)
  )
import Pudu.Lsp.Shapes (SumShape (..), VariantShape (..), renderTypeSyntax)
import Pudu.Type (Type (..), TypeInfo, renderType, typeAt)
import Pudu.Type.Value (NominalId (..), nominalKey)

data PatternCandidate = PatternCandidate
  { candidateLabel :: !Text
  , candidateDetail :: !Text
  }
  deriving stock (Eq, Show)

patternCandidates
  :: Maybe TypeInfo
  -> Map Text SumShape
  -> Module
  -> Located Expression
  -> [Located MatchArm]
  -> Located MatchArm
  -> [PatternCandidate]
patternCandidates types sums parsed subject arms arm =
  variants <> [PatternCandidate "_" "any value" | not wildcardCovered]
 where
  variants = case types >>= (`typeAt` locatedSpan subject) of
    Just subjectType -> case throughReferenceType subjectType of
      NominalType identity arguments -> variantsOf identity arguments
      _ -> []
    Nothing -> []
  variantsOf identity arguments = case nominalModule identity of
    Nothing -> case nominalName identity of
      "Option" -> builtinOffered "Option" [("Some", take 1 arguments), ("None", [])] Just
      "Result" -> builtinOffered "Result" [("Ok", take 1 arguments), ("Err", take 1 (drop 1 arguments))] Just
      _ -> []
    Just owner -> case Map.lookup (nominalKey identity) sums of
      Just shape -> offered identity arguments shape (spelledFrom identity owner)
      Nothing -> []
  offered identity arguments shape spell =
    [ PatternCandidate spelled (variantDetail (nominalName identity) substitutions variant variantShape)
    | (variant, variantShape) <- sumVariants shape
    , not (covered variant variantShape)
    , Just spelled <- [spell variant]
    ]
   where
    substitutions = Map.fromList (zip (sumTypeParams shape) arguments)
  builtinOffered owner shapes spell =
    [ PatternCandidate spelled (owner <> "." <> variant <> payloadDetail (map renderType payload))
    | (variant, payload) <- shapes
    , not (covered variant (if null payload then UnitVariant else TupleVariant []))
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
