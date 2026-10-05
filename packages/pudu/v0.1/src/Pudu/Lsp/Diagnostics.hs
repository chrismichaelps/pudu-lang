{-| @Program.Lsp.Diagnostics — one compile's findings placed in one open document -}
module Pudu.Lsp.Diagnostics
  ( Elsewhere
  , diagnosticEntries
  , elsewhereFor
  , noElsewhere
  , ownDiagnostics
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program (ProgramResult (..))
import Pudu.Diagnostic
  ( Diagnostic
  , Related (..)
  , Severity (..)
  , diagnosticCode
  , diagnosticCodeText
  , diagnosticHelp
  , diagnosticMessage
  , diagnosticRelated
  , diagnosticSeverity
  , diagnosticSpan
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameText)
import Pudu.Frontend.Syntax.Tree (Import (..), Module (..))
import Pudu.Lsp.Feature (rangeOfOffsets)
import Pudu.Lsp.Json (Json (..))
import Pudu.Lsp.Protocol (fileUri, rangeJson)
import Pudu.Source
  ( Source
  , SourceName (..)
  , Span
  , sourceName
  , sourceText
  , spanEnd
  , spanOrigin
  , spanSource
  , spanStart
  , unOffset
  )
import System.Directory (makeAbsolute)

{-| The other files this document's findings name: each one's URI and text by
    file name, and for each module file the document reaches, the import that
    reaches it and the module's name. -}
data Elsewhere = Elsewhere
  { elsewhereFiles :: !(Map SourceName (Text, Text))
  , elsewhereImports :: !(Map SourceName ((Int, Int), Text))
  }

noElsewhere :: Elsewhere
noElsewhere = Elsewhere Map.empty Map.empty

elsewhereFor :: Source -> Maybe Module -> ProgramResult -> IO Elsewhere
elsewhereFor own written program = do
  files <- mapM located (Map.toList kept)
  pure (Elsewhere (Map.fromList files) reaching)
 where
  ownName = sourceName own
  diagnostics = programDiagnostics program
  named =
    Set.fromList
      ( concat
          [ spanSource (diagnosticSpan value)
              : map (spanSource . relatedSpan) (diagnosticRelated value)
              <> maybe [] (\(definition, _, _) -> [spanSource definition]) (spanOrigin (diagnosticSpan value))
          | value <- diagnostics
          ]
      )
  kept =
    Map.fromList
      [ (sourceName source, source)
      | source <- programSources program
      , sourceName source /= ownName
      , Set.member (sourceName source) named
      ]
  located (name, source) = do
    absolute <- makeAbsolute (Text.unpack (unSourceName name))
    pure (name, (fileUri absolute, sourceText source))
  fileOf = Map.map sourceName (programNamedSources program)
  importsOf name =
    maybe [] (map (locatedValue . importModule . locatedValue) . moduleImports)
      (Map.lookup name (programModules program) >>= compileSyntax)
  reaching =
    Map.fromListWith (\_ earlier -> earlier)
      [ (file, (spanOffsets at, moduleNameText target))
      | Located _ entry <- maybe [] moduleImports written
      , let Located at root = importModule entry
      , target <- Set.toList (reachable (Set.singleton root) [root])
      , Just file <- [Map.lookup target fileOf]
      ]
  reachable :: Set.Set ModuleName -> [ModuleName] -> Set.Set ModuleName
  reachable seen pending = case pending of
    [] -> seen
    next : rest ->
      let fresh = [name | name <- importsOf next, not (Set.member name seen)]
       in reachable (foldr Set.insert seen fresh) (fresh <> rest)

{-| The findings located in this document: the only ones whose offsets mean
    anything against its text. -}
ownDiagnostics :: Source -> [Diagnostic] -> [Diagnostic]
ownDiagnostics own = filter ((== sourceName own) . spanSource . diagnosticSpan)

{-| What to publish for the document at `uri` with text `content`. -}
diagnosticEntries :: Text -> Text -> Source -> Elsewhere -> [Diagnostic] -> [Json]
diagnosticEntries uri content own elsewhere = mapMaybe (entryFor uri content own elsewhere)

entryFor :: Text -> Text -> Source -> Elsewhere -> Diagnostic -> Maybe Json
entryFor uri content own elsewhere value
  | inOwn spanValue = Just (entry (spanOffsets spanValue) "" [])
  | Just (_, request, _) <- spanOrigin spanValue, inOwn request =
      Just (entry (spanOffsets request) "" [reportedHere])
  | diagnosticSeverity value /= Error = Nothing
  | Just (at, owner) <- Map.lookup (spanSource spanValue) (elsewhereImports elsewhere) =
      Just (entry at (owner <> ": ") [reportedHere])
  | otherwise = Just (entry (0, 0) (unSourceName (spanSource spanValue) <> ": ") [reportedHere])
 where
  spanValue = diagnosticSpan value
  ownName = sourceName own
  inOwn = (== ownName) . spanSource
  reportedHere = Related spanValue "reported here"
  entry (start, end) prefix extra =
    let notes = diagnosticRelated value <> extra
        placed = mapMaybe (relatedJson uri content ownName elsewhere) notes
        unplaced = [note | note <- notes, Nothing <- [relatedJson uri content ownName elsewhere note]]
     in JsonObject
          ( [ ("range", rangeJson (rangeOfOffsets content start end))
            , ("severity", JsonNumber (fromIntegral (severityCode (diagnosticSeverity value))))
            , ("code", JsonText (diagnosticCodeText (diagnosticCode value)))
            , ("source", JsonText "pudu")
            , ("message", JsonText (messageText prefix unplaced))
            ]
              <> [("relatedInformation", JsonArray placed) | not (null placed)]
          )
  messageText prefix unplaced =
    Text.intercalate "\n" $
      (prefix <> diagnosticMessage value)
        : ["note: " <> relatedMessage note | note <- unplaced]
        <> maybe [] (\guidance -> ["help: " <> guidance]) (diagnosticHelp value)

relatedJson :: Text -> Text -> SourceName -> Elsewhere -> Related -> Maybe Json
relatedJson ownUri content ownName elsewhere note = do
  (uri, text) <-
    if spanSource at == ownName
      then Just (ownUri, content)
      else Map.lookup (spanSource at) (elsewhereFiles elsewhere)
  let (start, end) = spanOffsets at
  pure $
    JsonObject
      [ ("location", JsonObject [("uri", JsonText uri), ("range", rangeJson (rangeOfOffsets text start end))])
      , ("message", JsonText (relatedMessage note))
      ]
 where
  at = relatedSpan note

spanOffsets :: Span -> (Int, Int)
spanOffsets at = (unOffset (spanStart at), unOffset (spanEnd at))

severityCode :: Severity -> Int
severityCode severity = case severity of
  Error -> 1
  Warning -> 2
  Note -> 3
