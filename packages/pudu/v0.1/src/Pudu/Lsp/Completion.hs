{-| @Program.Lsp.Completion — member and identifier completions -}
module Pudu.Lsp.Completion (completionAt, completionRepaired) where

import Control.Applicative ((<|>))
import Data.Char (isAlphaNum)
import qualified Data.List.NonEmpty as NonEmpty
import Data.List (sortOn)
import Data.Maybe (isJust, listToMaybe)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc (DocEntry (..), DocIndex (..), DocKind (..))
import Pudu.Eval.Operator (builtinMethodNamesFor)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameSegments, moduleNameText, moduleQualifier)
import Pudu.Frontend.Syntax.Tree
  ( Expression
  , Import (..)
  , MatchArm
  , Module (..)
  , TypeSyntax (..)
  )
import Pudu.Lsp.Context (CompletionContext (..), ImportSite (..), TypeParameter, contextAt, contextParameters)
import Pudu.Lsp.ImportCompletion (importCompletions, importQualifiers, moduleMembers)
import Pudu.Lsp.Documents (Analysis (..), Documents, documentOf)
import Pudu.Lsp.Feature (completionItem, completionItems, offsetAt)
import Pudu.Lsp.Json (Json (..), lookupField)
import Pudu.Lsp.PatternCompletion (PatternCandidate (..), patternCandidates)
import Pudu.Lsp.Protocol (positionOf)
import Pudu.Lsp.Receiver (MemberSite (..), memberSiteAt, receiverType)
import Pudu.Lsp.Repair (Repair (..), closedPrefix, closedPrefixWith, elsewhereBlanked, lineBounds, mostComplete, withoutRange)
import Pudu.Lsp.Shapes (RecordShape (..), renderTypeSyntax)
import Pudu.Semantic.Prelude (wiredInTypeNames)
import Pudu.Semantic.Resolve (Resolution (..))
import Pudu.Semantic.ScopeIndex (visibleAt)
import Pudu.Semantic.Symbol (Namespace (..), Symbol (..), SymbolOrigin (..))
import Pudu.Source (spanStart, unOffset)
import Pudu.Type (Type (..), narrowestAt, renderType, typeAt)
import Pudu.Type.Value (NominalId (..), Scheme (..), nominalKey)

{-| Completions from the analysis already held, repairing nothing. A request
    that names no position is answered with every documented name. An import
    being written is offered the modules this program already reached. -}
completionAt :: Documents -> Json -> Json
completionAt documents parameters = case located documents parameters of
  Just (value, offset) -> completionFrom [] value value offset offset
  Nothing -> maybe (JsonArray []) (completionItems . analysisProgramIndex) (documentOf documents parameters)

{-| Completions at `offset` of `written`, the text the editor holds, answered
    from `known`, whose names and types are consulted and which agrees with
    `written` up to `agrees`. `catalog` is every module an import could name.

    The two analyses differ only when a repaired copy of the text was compiled.
    The construct is read from `written`, because that is where the cursor is.
    After a dot the answer is members or nothing: a keyword is never what
    follows `value.`. -}
completionFrom :: [Text] -> Analysis -> Analysis -> Int -> Int -> Json
completionFrom catalog written known agrees offset = JsonArray $ case context of
  PatternContext subject arms arm -> case analysisModule written of
    Just parsed -> patternCompletions known parsed subject arms arm offset
    Nothing -> []
  ImportContext site -> importCompletions catalog written known offset site
  SuppressedContext -> []
  _ -> case memberSiteAt (analysisTokens written) offset of
    Just site -> case moduleMembers written known site of
      members@(_ : _) -> members
      [] -> memberCompletions known site
    Nothing -> case (context, analysisModule written) of
      (TypeContext parameters, Just parsed) -> typeCompletions known parsed (map fst parameters)
      _ -> scopeCompletions written known agrees (wordStart written offset)
 where
  context = syntaxContext written offset

{-| What construct `offset` stands in, read from the document as written. -}
syntaxContext :: Analysis -> Int -> CompletionContext
syntaxContext written = contextAt (analysisTokens written) (analysisModule written)

{-| What may be written as the pattern of an arm: the variants of the subject's
    sum, spelled the way this module reaches them, and `_`.

    A variant another arm already covers — without a guard, and with a payload
    every value matches — is left out, because a second arm for it could never
    be reached. One covered only under a guard or for some payloads is still
    offered. -}
patternCompletions :: Analysis -> Module -> Located Expression -> [Located MatchArm] -> Located MatchArm -> Int -> [Json]
patternCompletions known parsed subject arms arm offset =
  [ simpleItem label (if label == "_" then 14 else 20) detail
  | PatternCandidate label detail <-
      patternCandidates (analysisTypes known) (analysisSums known) parsed subject arms arm offset
  ]

{-| What may be written where a type is: the type parameters in scope, innermost
    first, the types this module declares and imports, the modules whose types
    it may name through a qualifier, and the language's own types. -}
typeCompletions :: Analysis -> Module -> [Text] -> [Json]
typeCompletions known parsed parameters =
  distinctItems
    ( [simpleItem name 25 "type parameter" | name <- parameters]
        <> [ simpleItem (symbolName symbol) 22 (originDetail (symbolOrigin symbol))
           | symbol <- maybe [] resolutionSymbols (analysisResolution known)
           , symbolNamespace symbol == TypeSpace
           , symbolOrigin symbol `elem` [ModuleOrigin, ImportOrigin]
           ]
        <> [ simpleItem qualifier 9 ("module " <> moduleNameText (locatedValue (importModule imported)))
           | Located _ imported <- moduleImports parsed
           , null (importItems imported)
           , let qualifier = maybe (moduleQualifier (locatedValue (importModule imported))) locatedValue (importAlias imported)
           ]
        <> [simpleItem name 22 "type" | name <- wiredInTypeNames, name `notElem` ["Copy", "Never", "Buckets"]]
    )
 where
  originDetail origin = if origin == ImportOrigin then "imported type" else "type"

distinctItems :: [Json] -> [Json]
distinctItems = go Set.empty
 where
  go _ [] = []
  go seen (item : rest) = case labelOf item of
    Just label
      | Set.member label seen -> go seen rest
      | otherwise -> item : go (Set.insert label seen) rest
    Nothing -> go seen rest

{-| Completions answered from a repaired copy of the program when the program as
    written cannot say what the answer is.

    `total.` and `total.le` leave a program that does not parse, so the type of
    `total` is unknown exactly when it is asked for; the program without the
    member access ends in `total` itself. A name half written on a line of its
    own usually parses, but an unfinished line such as `let size = ` does not,
    and the program without that line still says what is in scope above it.
    `analyse` compiles text as the document; it is asked only when the analysis
    already held cannot answer. -}
completionRepaired :: (Text -> IO Analysis) -> IO [Text] -> Documents -> Json -> IO Json
completionRepaired analyse modules documents parameters = case located documents parameters of
  Nothing -> pure (completionAt documents parameters)
  Just (value, offset) -> case syntaxContext value offset of
    ImportContext site@(ImportSelection path) -> do
      -- The document does not parse while a selection is written, so its
      -- program never reached the module; a two-line program that imports
      -- it does.
      probe <- analyse ("module ImportProbe\nimport " <> path <> "\n")
      pure (JsonArray (importCompletions [] value probe offset site))
    ImportContext site -> do
      catalog <- modules
      pure (JsonArray (importCompletions catalog value value offset site))
    context -> repaired value offset context
 where
  complete written (known, agrees) offset = completionFrom [] written known agrees offset
  repaired value offset context =
    let content = analysisText value
        tokens = analysisTokens value
        (lineStart, lineEnd) = lineBounds content offset
        start = wordStart value offset
        attempt answers candidates = complete value <$> mostComplete analyse answers value offset candidates <*> pure offset
        -- The same text with any other broken declaration blanked, offsets
        -- kept; `finish` makes what is unfinished at the cursor whole.
        elsewhere finish = case elsewhereBlanked value offset of
          Just blanked -> [Repair blanked offset, finish blanked]
          Nothing -> []
     in case (memberSiteAt tokens offset, context) of
          (Just site@(MemberSite dotOffset _), _)
            | typesReceiver value -> pure (complete value (value, offset) offset)
            | otherwise ->
                attempt typesReceiver
                  ( [ withoutRange content dotOffset offset
                    , Repair (Text.take dotOffset content <> Text.drop lineEnd content) dotOffset
                    , closedPrefix tokens content dotOffset
                    ]
                      <> elsewhere (\blanked -> closedPrefix tokens blanked dotOffset)
                  )
           where
            typesReceiver known = isJust (analysisTypes known >>= (`receiverType` site))
          (Nothing, PatternContext subject _ (Located armSpan _))
            | typesSubject value -> pure (complete value (value, offset) offset)
            | otherwise ->
                -- The arm is unfinished. Replacing it with one whose pattern
                -- and body every match accepts, and closing what is open,
                -- leaves the match and its subject where they were.
                let armStart = unOffset (spanStart armSpan)
                    wholeArm = closedPrefixWith "case _ => panic(\"\")" tokens
                 in attempt typesSubject
                      ([wholeArm content armStart, closedPrefix tokens content lineStart] <> elsewhere (`wholeArm` armStart))
           where
            typesSubject known = isJust (analysisTypes known >>= (`typeAt` locatedSpan subject))
          (Nothing, _)
            | isJust (analysisTypes value) -> pure (complete value (value, offset) offset)
            | otherwise ->
                attempt (isJust . analysisTypes)
                  ( [ withoutRange content start offset
                    , withoutRange content lineStart lineEnd
                    , closedPrefix tokens content start
                    , closedPrefix tokens content lineStart
                    ]
                      <> elsewhere (\blanked -> closedPrefix tokens blanked start)
                  )

{-| The offset where the name being written at `offset` starts. -}
wordStart :: Analysis -> Int -> Int
wordStart value offset =
  offset - Text.length (Text.takeWhileEnd nameScalar (Text.take offset (analysisText value)))

nameScalar :: Char -> Bool
nameScalar scalar = isAlphaNum scalar || scalar == '_'

{-| Everything a name written at `before` could be, nearest first: the
    bindings in scope, the file's own declarations, the modules and names it
    imports, the prelude a program always has, and the language's words.

    Bindings are the ones resolution's frames hold at `before`: a `let` in a
    block that has ended, or a name another match arm bound, is not among them,
    and an inner binding comes before an outer one of the same name, so the
    first of each name is the one a use there would resolve to.

    They are read from the text as written whenever it resolved, which it does
    while the name being typed is still unknown; a repaired copy is consulted
    for them only when the written text did not parse. Types come from `known`
    for bindings before `agrees`, where the two texts are the same. -}
scopeCompletions :: Analysis -> Analysis -> Int -> Int -> [Json]
scopeCompletions written known agrees before =
  distinctItems
    ( locals
        <> declarations
        <> imported
        <> map preludeItem preludeItems
        <> map keywordItem keywords
        <> [simpleItem name 22 "type" | name <- wiredInTypeNames, name `notElem` ["Copy", "Never", "Buckets"]]
    )
 where
  qualifiers = importQualifiers written known
  (scoped, position) = case analysisResolution written of
    Just resolution -> (Just resolution, before)
    Nothing -> (analysisResolution known, min agrees before)
  symbols = maybe [] resolutionSymbols scoped
  byId = Map.fromList [(symbolId symbol, symbol) | symbol <- symbols]
  visible = maybe [] (\resolution -> visibleAt (resolutionScopes resolution) position) scoped
  startOf symbol = maybe maxBound (unOffset . spanStart) (symbolSpan symbol)
  locals =
    [ simpleItem (symbolName symbol) 6 (typeNear (startOf symbol))
    | identity <- visible
    , Just symbol <- [Map.lookup identity byId]
    , symbolOrigin symbol `elem` [ParameterOrigin, LocalOrigin, PatternOrigin]
    , symbolNamespace symbol == ValueSpace
    ]
  typeNear start = maybe "" renderType (typesFor start >>= narrowestAt start)
  typesFor start
    | isJust (analysisTypes written) = analysisTypes written
    | start < agrees = analysisTypes known
    | otherwise = Nothing
  fileEntries = [entry | entry <- indexEntries (analysisFileIndex known), not (isMember (docKind entry))]
  declared = Set.fromList (map docName fileEntries)
  declarations =
    map completionItem fileEntries
      <> [ simpleItem (symbolName symbol) (if symbolNamespace symbol == TypeSpace then 22 else 3) ""
         | symbol <- symbols
         , symbolOrigin symbol `elem` [ModuleOrigin, VariantOrigin]
         , not (Set.member (symbolName symbol) declared)
         ]
  imported =
    [simpleItem alias 9 ("module " <> moduleNameText owner) | (alias, owner) <- qualifiers]
      <> [ maybe (simpleItem (symbolName symbol) 3 "") completionItem (selectedEntry (symbolName symbol))
         | symbol <- symbols
         , symbolOrigin symbol == ImportOrigin
         , symbolName symbol `notElem` map fst qualifiers
         ]
  -- A selected name is described by the module the import selected it from,
  -- whatever other module also declares that name.
  selectedEntry name = listToMaybe
    [ entry
    | Located _ entry' <- maybe [] moduleImports (analysisModule written <|> analysisModule known)
    , name `elem` map locatedValue (importItems entry')
    , let owner = moduleNameText (locatedValue (importModule entry'))
    , entry <- indexEntries (analysisProgramIndex known)
    , docModule entry == owner
    , docName entry == name
    , not (isMember (docKind entry))
    ]

labelOf :: Json -> Maybe Text
labelOf item = case lookupField "label" item of
  Just (JsonText label) -> Just label
  _ -> Nothing

isMember :: DocKind -> Bool
isMember kind = case kind of
  DocMethod _ -> True
  DocTraitMethod _ -> True
  _ -> False

simpleItem :: Text -> Int -> Text -> Json
simpleItem label kind detail =
  JsonObject
    ( [("label", JsonText label), ("kind", JsonNumber (fromIntegral kind))]
        <> [("detail", JsonText detail) | not (Text.null detail)]
    )

keywordItem :: Text -> Json
keywordItem word = simpleItem word 14 "keyword"

preludeItem :: (Text, Int, Text) -> Json
preludeItem (label, kind, detail) = simpleItem label kind detail

{-| The prelude names a program reaches for, with what they are. The prelude
    holds far more — the runtime's primitives, which the library wraps — and
    offering those unasked would bury these. -}
preludeItems :: [(Text, Int, Text)]
preludeItems =
  [ ("print", 3, "fn(Str) -> Result[(), E]")
  , ("printError", 3, "fn(Str) -> Result[(), E]")
  , ("printPart", 3, "fn(Str) -> Result[(), E]")
  , ("readLine", 3, "fn() -> Result[Option[Str], E]")
  , ("show", 3, "fn(T) -> Str")
  , ("display", 3, "fn(T) -> Str")
  , ("panic", 3, "fn(Str) -> Never")
  , ("mapOf", 3, "fn(Array[(K, V)]) -> Map[K, V]")
  , ("setOf", 3, "fn(Array[T]) -> Set[T]")
  , ("bytesOf", 3, "fn(Array[Int]) -> Bytes")
  , ("Some", 20, "Option[T]")
  , ("None", 20, "Option[T]")
  , ("Ok", 20, "Result[T, E]")
  , ("Err", 20, "Result[T, E]")
  ]

keywords :: [Text]
keywords =
  [ "fn", "let", "var", "const", "mut", "if", "else", "match", "case", "for"
  , "in", "while", "loop", "break", "continue", "return", "type", "enum"
  , "struct", "trait", "impl", "where", "export", "import", "unsafe", "foreign", "dynamic"
  , "true", "false"
  ]

{-| What may follow a value of the type the checker gave the receiver: the
    fields of its record type, then the methods it can be called with. -}
memberCompletions :: Analysis -> MemberSite -> [Json]
memberCompletions value site@(MemberSite _ (_, receiverEnd')) = case analysisTypes value >>= (`receiverType` site) of
  Nothing -> []
  Just typeValue ->
    fieldCompletions value typeValue
      <> distinctItems (methodCompletions value (contextParameters (syntaxContext value receiverEnd')) typeValue)

{-| The methods a receiver can be called with, from the methods the program's
    modules declared, by the owner the checker would look them up under: a
    nominal type's own and inherited default methods, a `dynamic` trait's
    members, and for a type parameter the members of the traits its bounds
    name. A wired-in type also has the methods its runtime provides. Sorted by
    name; a method two traits provide is offered once. -}
methodCompletions :: Analysis -> [TypeParameter] -> Type -> [Json]
methodCompletions value parameters receiver =
  [methodItem name (maybe "method" (renderType . schemeType) scheme) | (name, scheme) <- sortOn fst (methodsOf receiver)]
 where
  methodsOf typeValue = case throughReferenceType typeValue of
    NominalType owner _ ->
      declaredOn (nominalKey owner)
        <> [ (name, Nothing)
           | nominalModule owner == Nothing
           , name <- builtinMethodNamesFor (nominalName owner)
           , name `notElem` map fst (declaredOn (nominalKey owner))
           ]
    DynamicTypeValue trait -> declaredOn (nominalKey trait)
    AppliedType head' _ -> methodsOf head'
    RigidType name -> concat [declaredOn key | bound <- boundsOf name, key <- traitKeys bound]
    _ -> []
  declaredOn key = [(name, Just scheme) | (name, scheme) <- Map.findWithDefault [] key (analysisMethods value)]
  boundsOf name = concat [bounds | (parameter, bounds) <- parameters, parameter == name]
  traitKeys (Located _ bound) = case bound of
    NamedType path _ -> filter (`Map.member` analysisMethods value) (ownersOf path)
    _ -> []
  -- The canonical keys a written trait name may stand for in this module: a
  -- qualifier names the module it was imported as; a bare name is this
  -- module's own, or one a selective import brought in.
  ownersOf path = case NonEmpty.toList (moduleNameSegments path) of
    [name] -> [own <> "." <> name | Just own <- [rootName]] <> [imported <> "." <> name | imported <- selecting name]
    segments -> [qualified (init segments) <> "." <> last segments]
  rootName = moduleNameText . locatedValue . moduleName <$> analysisModule value
  imports = maybe [] (map locatedValue . moduleImports) (analysisModule value)
  selecting name =
    [moduleNameText (locatedValue (importModule entry)) | entry <- imports, name `elem` map locatedValue (importItems entry)]
  qualified segments =
    let written = Text.intercalate "." segments
     in case [moduleNameText (locatedValue (importModule entry)) | entry <- imports, Just alias <- [importAlias entry], locatedValue alias == written] of
          target : _ -> target
          [] -> case [moduleNameText (locatedValue (importModule entry)) | entry <- imports, null (importItems entry), importAlias entry == Nothing, moduleQualifier (locatedValue (importModule entry)) == written] of
            target : _ -> target
            [] -> written

{-| The fields of the receiver's record type, found by the type's canonical
    identity — its declaring module and name — so a record another module
    declares is found and two modules' records of the same name never exchange
    fields. The type's parameters are replaced by the receiver's arguments:
    a `Box[Int]`'s `value: T` is offered as `Int`. A `mut` field says so. -}
fieldCompletions :: Analysis -> Type -> [Json]
fieldCompletions value typeValue = case throughReferenceType typeValue of
  NominalType identity arguments
    | Just shape <- Map.lookup (nominalKey identity) (analysisRecords value) ->
        let substitutions = Map.fromList (zip (recordTypeParams shape) arguments)
         in [ simpleItem name 5 ((if mutable then "mut " else "") <> renderTypeSyntax substitutions written)
            | (name, mutable, written) <- recordFields shape
            ]
  _ -> []

throughReferenceType :: Type -> Type
throughReferenceType typeValue = case typeValue of
  ReferenceTypeValue _ target -> throughReferenceType target
  other -> other

methodItem :: Text -> Text -> Json
methodItem name detail = simpleItem name 2 detail

located :: Documents -> Json -> Maybe (Analysis, Int)
located documents parameters = do
  value <- documentOf documents parameters
  position <- lookupField "position" parameters >>= positionOf
  pure (value, offsetAt (analysisText value) position)
