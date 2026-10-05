{-| @Program.Lsp.ImplMembers — the members an implementation has yet to write.

    Inside `impl Trait for Type { … }` the useful completion is the trait
    itself: each member not yet written, offered as a whole method with the
    signature the trait declares, the trait's own parameters replaced by the
    arguments the implementation gave. The same list answers the quick fix
    that writes every required member at once. -}
module Pudu.Lsp.ImplMembers
  ( canonicalKeys
  , implMemberCompletions
  , implementMembersActions
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameSegments, moduleNameText, moduleQualifier)
import Pudu.Frontend.Syntax.Tree
  ( Constraint (..), Declaration (..), Function (..), Impl (..), Import (..), Module (..)
  , Parameter (..), TypeParam (..), TypeSyntax (..) )
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Feature (offsetAt, rangeOfOffsets)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (Range (..), rangeJson)
import Pudu.Lsp.Shapes (TraitShape (..), renderTypeSyntax)
import Pudu.Source (Span, spanEnd, spanStart, unOffset)

{-| The canonical keys a written type path may name from this module: its own
    declaration, a selectively imported one, or one reached through a module
    qualifier. -}
canonicalKeys :: Module -> ModuleName -> [Text]
canonicalKeys parsed path = case NonEmpty.toList (moduleNameSegments path) of
  [name] ->
    (own <> "." <> name)
      : [moduleNameText (locatedValue (importModule entry)) <> "." <> name | entry <- imports, name `elem` map locatedValue (importItems entry)]
  segments ->
    let qualifier = Text.intercalate "." (init segments)
     in [ moduleNameText (locatedValue (importModule entry)) <> "." <> last segments
        | entry <- imports
        , null (importItems entry)
        , maybe (moduleQualifier (locatedValue (importModule entry))) locatedValue (importAlias entry) == qualifier
        ]
 where
  own = moduleNameText (locatedValue (moduleName parsed))
  imports = map locatedValue (moduleImports parsed)

{-| An implementation and the members its trait declares that it has not
    written, each beside whether it has a default. -}
data Unwritten = Unwritten
  { unwrittenImpl :: !(Located Impl)
  , unwrittenTrait :: !Text
  , unwrittenMembers :: ![(Text, Text, Bool)]
  }

{-| A cursor in a member's header marks the member being typed, which is not
    yet written; `Nothing` asks about the implementation as a whole. -}
unwritten :: Analysis -> Module -> Maybe Int -> Located Impl -> Maybe Unwritten
unwritten known parsed cursor located@(Located _ impl) = case locatedValue (implTrait impl) of
  NamedType path arguments -> do
    shape <- listToMaybe [found | key <- canonicalKeys parsed path, Just found <- [Map.lookup key (analysisTraits known)]]
    let written =
          [ locatedValue (functionName member)
          | Located at member <- implFunctions impl, maybe True (\offset -> not (inHeader offset at member)) cursor ]
        replacements = Map.fromList (zip (traitShapeParams shape) arguments)
    pure $ Unwritten located (moduleNameText path)
      [ (name, stub replacements member, defaulted)
      | (member, defaulted) <- traitShapeMembers shape
      , let name = locatedValue (functionName member)
      , name `notElem` written
      ]
  _ -> Nothing

{-| Whether the offset falls in a member's header, before its body: where its
    name and signature are still being written. -}
inHeader :: Int -> Span -> Function -> Bool
inHeader offset at member =
  unOffset (spanStart at) <= offset
    && offset <= maybe (unOffset (spanEnd at)) (unOffset . spanStart . locatedSpan) (functionBody member)

inBody :: Int -> Function -> Bool
inBody offset member = case functionBody member of
  Just (Located body _) -> unOffset (spanStart body) < offset && offset < unOffset (spanEnd body)
  Nothing -> False

{-| Completions inside an implementation's body, outside every member it has
    written: the trait's unwritten members, required ones first. `Nothing`
    when the offset is not in such a place. -}
implMemberCompletions :: Analysis -> Analysis -> Int -> Maybe [Json]
implMemberCompletions written known offset = do
  parsed <- analysisModule written
  located <- listToMaybe
    [ held
    | Located at (ImplDeclaration impl) <- moduleDeclarations parsed
    , let held = Located at impl
    , unOffset (spanEnd (locatedSpan (implTarget impl))) < offset, offset < unOffset (spanEnd at)
    , not (any (inBody offset . locatedValue) (implFunctions impl))
    ]
  found <- unwritten known parsed (Just offset) located
  let afterFn = "fn" `Text.isSuffixOf` Text.stripEnd (Text.dropWhileEnd isWordChar (Text.take offset (analysisText written)))
      item (name, text, defaulted) = JsonObject
        [ ("label", JsonText name)
        , ("kind", JsonNumber 2)
        , ("detail", JsonText ((if defaulted then "override " else "implement ") <> unwrittenTrait found <> "." <> name))
        , ("filterText", JsonText name)
        , ("sortText", JsonText ((if defaulted then "1" else "0") <> name))
        , ("insertTextFormat", JsonNumber 2)
        , ("insertText", JsonText (snippet (if afterFn then Text.drop 3 text else text)))
        ]
  case unwrittenMembers found of
    [] -> Nothing
    members -> Just (map item members)
 where
  isWordChar character = character == '_' || character `elem` ['a' .. 'z'] || character `elem` ['A' .. 'Z'] || character `elem` ['0' .. '9']
  snippet text = text <> " {\n\t${0:panic(\"not yet implemented\")}\n}"

{-| One quick fix per implementation overlapping the range that has required
    members unwritten: write each with a body that panics until it is
    filled in. -}
implementMembersActions :: Text -> Analysis -> Range -> [Json]
implementMembersActions uri value range = case analysisModule value of
  Nothing -> []
  Just parsed ->
    [ action found required
    | Located at (ImplDeclaration impl) <- moduleDeclarations parsed
    , unOffset (spanStart at) <= end, start <= unOffset (spanEnd at)
    , Just found <- [unwritten value parsed Nothing (Located at impl)]
    , let required = [text | (_, text, False) <- unwrittenMembers found]
    , not (null required)
    ]
 where
  content = analysisText value
  start = offsetAt content (rangeStart range)
  end = offsetAt content (rangeEnd range)
  action found required =
    let closing = unOffset (spanEnd (locatedSpan (unwrittenImpl found))) - 1
        inserted = Text.concat ["\n  " <> text <> " {\n    panic(\"not yet implemented\")\n  }\n" | text <- required]
     in JsonObject
          [ ("title", JsonText ("Implement missing members of " <> unwrittenTrait found))
          , ("kind", JsonText "quickfix")
          , ( "edit", JsonObject [("changes", JsonObject [(uri, JsonArray
                [JsonObject [("range", rangeJson (rangeOfOffsets content closing closing)), ("newText", JsonText inserted)]])])])
          ]

{-| The member's declaration line as an implementation writes it. -}
stub :: Map.Map Text (Located TypeSyntax) -> Function -> Text
stub replacements member =
  (if functionAsync member then "async " else "") <> "fn " <> locatedValue (functionName member)
    <> typeParameters (functionTypeParams member)
    <> "(" <> Text.intercalate ", " (map (parameter . locatedValue) (functionParameters member)) <> ")"
    <> maybe "" ((" -> " <>) . written) (functionReturn member)
    <> constraints (functionConstraints member)
 where
  written = renderTypeSyntax Map.empty . substitute
  parameter held = locatedValue (parameterName held) <> maybe "" ((": " <>) . written) (parameterType held)
  typeParameters [] = ""
  typeParameters held = "[" <> Text.intercalate ", " (map (one . locatedValue) held) <> "]"
  one held = locatedValue (typeParamName held) <> bounds (typeParamBounds held)
  constraints [] = ""
  constraints held = " where " <> Text.intercalate ", "
    [locatedValue (constraintSubject value) <> bounds (constraintBounds value) | Located _ value <- held]
  bounds [] = ""
  bounds held = ": " <> Text.intercalate " + " (map written held)
  substitute (Located at syntax) = case syntax of
    NamedType (ModuleName (name NonEmpty.:| [])) []
      | Just replacement <- Map.lookup name replacements -> replacement
    NamedType path arguments -> Located at (NamedType path (map substitute arguments))
    ReferenceType mutable target -> Located at (ReferenceType mutable (substitute target))
    TupleType members -> Located at (TupleType (map substitute members))
    FunctionType async inputs result -> Located at (FunctionType async (map substitute inputs) (substitute result))
    UnsafeType capabilities target -> Located at (UnsafeType capabilities (substitute target))
    _ -> Located at syntax
