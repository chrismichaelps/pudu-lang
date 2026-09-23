{-| @Type.Interface.Graph.Module — prepares a module graph's shared interface facts once -}
module Pudu.Type.Interface.Graph
  ( ImportTypes (..)
  , InterfaceGraph
  , consumerDefaults
  , consumerIdentities
  , consumerNames
  , consumerTraits
  , contributesTo
  , emptyImportTypes
  , emptyInterfaceGraph
  , graphDeclared
  , graphInstalled
  , graphInterfaces
  , graphOrder
  , importsFor
  , prepareInterfaces
  ) where

import Control.Monad (foldM)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameText, moduleQualifier)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Function
  , Import (..)
  , Module (..)
  )
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Type.Check.Install (installShared, interfaceScope)
import Pudu.Type.Check.Prelude (declareBuiltinConstructors)
import Pudu.Type.Env
  ( DeclaredTypes (..)
  , InstalledNames
  , emptyDeclared
  , evalChecker
  , installedNames
  )
import Pudu.Type.Formation (collectDeclaredFrom, formTraitReference)
import Pudu.Type.Interface
  ( TypeInterface
  , interfaceDeclarations
  , interfaceDefaults
  , interfaceExportedIdentities
  , interfaceExportedValues
  , interfaceIdentities
  , interfaceImports
  , interfaceModule
  , interfacePrivateDeclarations
  )
import Pudu.Type.Value (NominalId, Type (..), canonicalNominal)

{-| Everything about a module graph's interfaces that does not depend on which
    module is being checked, formed once per graph.

    Each consumer used to rebuild all of it: the dependency order of every
    other interface, the names each one forms its declarations under, the
    trait table and defaults of the whole program, and the declarations those
    interfaces collect to. For a graph of M modules that is M copies of work
    proportional to the whole graph, and every copy came out the same.

    The collected declarations are formed from every interface, the consumer's
    own included. The consumer collects its own declarations again on top, and
    each of them replaces what the interface recorded under the same key, so
    including it changes nothing the consumer can observe, while leaving it out
    would make the collection depend on the consumer. A diagnostic raised while
    forming another module's declaration belongs to that module, which reports
    it when it is checked; a consumer repeating it reported one mistake once per
    module that imported it.

    The collected declarations are not forced until a module is checked, so a
    graph that fails before typing never forms them. -}
data InterfaceGraph = InterfaceGraph
  { graphInterfaces :: !(Map ModuleName TypeInterface)
  {-| Every module after the modules it imports, cycles broken in name order. -}
  , graphOrder :: ![ModuleName]
  , graphIdentities :: !(Map ModuleName [(Text, NominalId)])
  {-| The names each interface's declarations are formed under: its own
      declarations and the exported names of what it imports. -}
  , graphNames :: !(Map ModuleName (Map Text NominalId))
  {-| The modules that import each module, which are the only interfaces whose
      names change when that module is the one being checked. -}
  , graphImporters :: !(Map ModuleName (Set ModuleName))
  , graphTraits :: !(Map NominalId [Located Function])
  , graphDefaults :: !(Set (NominalId, Text))
  , graphDeclared :: ~DeclaredTypes
  {-| The names every consumer starts from: the language's constructors, then
      each interface's constructors, trait members, and foreign functions. -}
  , graphInstalled :: ~InstalledNames
  {-| The traits each interface implements. A consumer receives implementation
      methods only for traits it can see, so an interface implementing none of
      them has nothing to give it and is passed over unread. -}
  , graphImplemented :: ~(Map ModuleName (Set NominalId))
  }

{-| Two graphs are the same graph when they hold the same interfaces; every
    other field is derived from those. -}
instance Eq InterfaceGraph where
  left == right = graphInterfaces left == graphInterfaces right

instance Show InterfaceGraph where
  showsPrec precedence graph =
    showParen (precedence > 10)
      (showString "InterfaceGraph " . showsPrec 11 (graphInterfaces graph))

emptyInterfaceGraph :: InterfaceGraph
emptyInterfaceGraph = prepareInterfaces Map.empty

prepareInterfaces :: Map ModuleName TypeInterface -> InterfaceGraph
prepareInterfaces interfaces =
  InterfaceGraph
    { graphInterfaces = interfaces
    , graphOrder = order
    , graphIdentities = identities
    , graphNames = names
    , graphImporters = importers
    , graphTraits = Map.unions (map interfaceTraits (Map.elems interfaces))
    , graphDefaults = Set.unions (map interfaceDefaults (Map.elems interfaces))
    , graphDeclared = declared
    , graphInstalled = installGraph interfaces names declared
    , graphImplemented = implementedTraits interfaces names declared
    }
 where
  declared = collectGraph (mapMaybe (`Map.lookup` interfaces) order) names
  order = dependencyOrder interfaces
  identities = Map.map interfaceIdentities interfaces
  names = Map.map (interfaceNames identities) interfaces
  importers = Map.fromListWith Set.union
    [ (dependency, Set.singleton (interfaceModule value))
    | value <- Map.elems interfaces
    , Located _ imported <- interfaceImports value
    , let dependency = locatedValue (importModule imported)
    , Map.member dependency interfaces
    ]

{-| Collecting an interface forms the types its declarations name, and a record
    field naming another module's alias can only become what the alias stands
    for once that module's aliases are collected, so each interface follows the
    modules it imports. -}
collectGraph :: [TypeInterface] -> Map ModuleName (Map Text NominalId) -> DeclaredTypes
collectGraph ordered names = evalChecker (foldM collectOne emptyDeclared ordered)
 where
  collectOne accumulated value =
    collectDeclaredFrom
      accumulated
        { declaredNames =
            Map.findWithDefault Map.empty (interfaceModule value) names
              <> declaredNames accumulated
        }
      (interfaceModule value)
      (interfacePrivateDeclarations value <> interfaceDeclarations value)

{-| Install every interface's consumer-independent declarations once, in
    module-name order so a bare name two modules share resolves as it did when
    each consumer installed them itself. -}
installGraph
  :: Map ModuleName TypeInterface
  -> Map ModuleName (Map Text NominalId)
  -> DeclaredTypes
  -> InstalledNames
installGraph interfaces names declared = evalChecker $ do
  declareBuiltinConstructors
  mapM_ installOne (Map.elems interfaces)
  installedNames
 where
  installOne value =
    installShared
      (interfaceScope declared (Map.findWithDefault Map.empty (interfaceModule value) names) value)
      value

implementedTraits
  :: Map ModuleName TypeInterface
  -> Map ModuleName (Map Text NominalId)
  -> DeclaredTypes
  -> Map ModuleName (Set NominalId)
implementedTraits interfaces names declared = evalChecker (traverse implemented interfaces)
 where
  implemented value = do
    let scope = interfaceScope declared (Map.findWithDefault Map.empty (interfaceModule value) names) value
    formed <- mapM (formTraitReference scope [] . Tree.implTrait)
      [implementation | Located _ (ImplDeclaration implementation) <- interfaceDeclarations value]
    pure (Set.fromList [identity | NominalType identity _ <- formed])

{-| Whether an interface can give a consumer anything beyond what the graph
    installed for every module: a value it imported, an implementation of a
    trait it can see, or — inside a cycle — names formed without its own. -}
contributesTo :: ImportTypes -> TypeInterface -> Bool
contributesTo imported value =
  Set.member owner (importedModules imported)
    || maybe False (\consumer -> Set.member owner (Map.findWithDefault Set.empty consumer (graphImporters graph))) (importedConsumer imported)
    || not (Set.disjoint (importedTraits imported) (Map.findWithDefault Set.empty owner (graphImplemented graph)))
 where
  owner = interfaceModule value
  graph = importedGraph imported

dependencyOrder :: Map ModuleName TypeInterface -> [ModuleName]
dependencyOrder interfaces = reverse (snd (foldl visit (Set.empty, []) (Map.elems interfaces)))
 where
  visit (seen, ordered) value
    | Set.member (interfaceModule value) seen = (seen, ordered)
    | otherwise =
        let (reached, placed) =
              foldl visit (Set.insert (interfaceModule value) seen, ordered) (dependencies value)
         in (reached, interfaceModule value : placed)
  dependencies value =
    [ dependency
    | Located _ imported <- interfaceImports value
    , Just dependency <- [Map.lookup (locatedValue (importModule imported)) interfaces]
    ]

{-| What a module may see of the program around it.

    Names and values come from what it imported: a name has to be imported to be
    written, and that is the whole point of an import list.

    **Implementations do not.** An implementation is a fact about a type and a
    trait, true everywhere in a program once it exists anywhere in it — which is
    what an orphan rule is for. Scoping them to direct imports made a bounded
    generic unusable across modules: `Std.List.sum` is bounded by `Add`, whose
    implementations live in `Std.Num`, and a caller importing only `Std.List`
    was told `Int does not implement Add` about a program in which it plainly
    does.

    **The consumer's own module is removed.** Its implementations are declared
    by the local pass, and declaring them a second time through the interface
    path made every one of them collide with itself: a module that implemented
    an imported trait for its own type was told the method was ambiguous, which
    made `impl Eq for MyType` impossible to write outside the module that
    declared `Eq`. -}
importsFor :: InterfaceGraph -> Module -> ImportTypes
importsFor graph consumer =
  ImportTypes
    { importedInterfaces = Map.elems (Map.delete owner (graphInterfaces graph))
    , importedNames = Map.unions (map pieceNames pieces)
    , importedValues = Map.unions (map pieceValues pieces)
    , importedTraits = Set.unions (map pieceTraits pieces)
    , importedQualifiers = Set.unions (map pieceQualifiers pieces)
    , importedModules = Set.fromList [interfaceModule found | (_, found) <- reached]
    , importedGraph = graph
    , importedConsumer = Just owner
    }
 where
  owner = locatedValue (moduleName consumer)
  pieces = [importOne value found | (value, found) <- reached]
  reached =
    [ (value, found)
    | Located _ value <- moduleImports consumer
    , Just found <- [Map.lookup (locatedValue (importModule value)) (graphInterfaces graph)]
    ]

data ImportTypes = ImportTypes
  {-| Every interface in the graph but the consumer's, in module-name order. -}
  { importedInterfaces :: ![TypeInterface]
  , importedNames :: !(Map Text NominalId)
  , importedValues :: !(Map Text Text)
  , importedTraits :: !(Set NominalId)
  {-| The qualifiers whose module was actually found.

      A name this qualifier does not carry is a mistake worth reporting, and a
      qualifier that is missing from here is a module nothing could be known
      about — the difference between "that module has no such type" and "that
      module was not available", which look identical in a table of names. -}
  , importedQualifiers :: !(Set Text)
  {-| The modules an import of this consumer's reached. -}
  , importedModules :: !(Set ModuleName)
  , importedGraph :: !InterfaceGraph
  , importedConsumer :: !(Maybe ModuleName)
  }
  deriving stock (Eq, Show)

emptyImportTypes :: ImportTypes
emptyImportTypes =
  ImportTypes [] Map.empty Map.empty Set.empty Set.empty Set.empty emptyInterfaceGraph Nothing

data ImportPiece = ImportPiece
  { pieceNames :: !(Map Text NominalId)
  , pieceValues :: !(Map Text Text)
  , pieceTraits :: !(Set NominalId)
  , pieceQualifiers :: !(Set Text)
  }

importOne :: Import -> TypeInterface -> ImportPiece
importOne value found =
  ImportPiece
    { pieceNames = Map.fromList (concatMap namesFor exported)
    , pieceValues = Map.fromList (concatMap valuesFor (interfaceExportedValues found))
    , pieceTraits = Set.fromList [identity | (name, identity, True) <- exported, visible name]
    {-| Only a whole-module import lends its name to what it carries. A
        selective one brings its names in unqualified, so nothing is written
        `qualifier.name` and there is no qualifier to judge against. -}
    , pieceQualifiers = if Set.null selected then Set.singleton qualifier else Set.empty
    }
 where
  selected = Set.fromList (map locatedValue (importItems value))
  qualifier = maybe (moduleQualifier (interfaceModule found)) locatedValue (importAlias value)
  visible name = Set.null selected || Set.member name selected
  namesFor (name, identity, _)
    | Set.null selected = [(qualifier <> "." <> name, identity)]
    | Set.member name selected = [(name, identity)]
    | otherwise = []
  valuesFor name
    | Set.null selected = [(qualifier <> "." <> name, canonicalValue name)]
    | Set.member name selected = [(name, canonicalValue name)]
    | otherwise = []
  canonicalValue name = moduleNameText (interfaceModule found) <> "." <> name
  exported = interfaceExportedIdentities found

{-| The exported identities of every module but the consumer's. -}
consumerIdentities :: ImportTypes -> Map ModuleName [(Text, NominalId)]
consumerIdentities imported =
  maybe id Map.delete (importedConsumer imported) (graphIdentities (importedGraph imported))

{-| The trait table of every module but the consumer's, whose traits the local
    pass declares. -}
consumerTraits :: ImportTypes -> Map NominalId [Located Function]
consumerTraits imported = case consumerInterface imported of
  Nothing -> graphTraits (importedGraph imported)
  Just own -> Map.difference (graphTraits (importedGraph imported)) (interfaceTraits own)

consumerDefaults :: ImportTypes -> Set (NominalId, Text)
consumerDefaults imported = case consumerInterface imported of
  Nothing -> graphDefaults (importedGraph imported)
  Just own -> Set.difference (graphDefaults (importedGraph imported)) (interfaceDefaults own)

{-| The names an interface's declarations are formed under, as the consumer
    sees them.

    The consumer's own interface is not among the ones it imports, so a module
    that imports the consumer — only possible inside a cycle — forms its
    declarations without the consumer's names, exactly as it would were the
    consumer absent. Every other interface's names are the graph's. -}
consumerNames :: ImportTypes -> TypeInterface -> Map Text NominalId
consumerNames imported value = case importedConsumer imported of
  Just owner
    | Set.member (interfaceModule value)
        (Map.findWithDefault Set.empty owner (graphImporters graph)) ->
        interfaceNames (consumerIdentities imported) value
  _ -> case Map.lookup (interfaceModule value) (graphNames graph) of
    Just found -> found
    Nothing -> interfaceNames (consumerIdentities imported) value
 where
  graph = importedGraph imported

consumerInterface :: ImportTypes -> Maybe TypeInterface
consumerInterface imported = do
  owner <- importedConsumer imported
  Map.lookup owner (graphInterfaces (importedGraph imported))

interfaceTraits :: TypeInterface -> Map NominalId [Located Function]
interfaceTraits value = Map.fromList
  [ (canonicalNominal (interfaceModule value) (locatedValue (Tree.traitName trait)), Tree.traitMembers trait)
  | Located _ (TraitDeclaration trait) <- interfaceDeclarations value
  ]

interfaceNames :: Map ModuleName [(Text, NominalId)] -> TypeInterface -> Map Text NominalId
interfaceNames available value = interfaceLocalNames value <> interfaceReferenceNames available value

interfaceLocalNames :: TypeInterface -> Map Text NominalId
interfaceLocalNames value = Map.fromList (concatMap one declarations)
 where
  declarations = interfacePrivateDeclarations value <> interfaceDeclarations value
  owner = interfaceModule value
  one (Located _ declaration) = case declaration of
    TypeDeclaration typeValue -> identity (locatedValue (Tree.typeName typeValue))
    TraitDeclaration trait -> identity (locatedValue (Tree.traitName trait))
    ForeignDeclaration foreignValue ->
      concatMap (identity . locatedValue) (Tree.foreignTypes foreignValue)
    _ -> []
  identity name = [(name, canonicalNominal owner name)]

interfaceReferenceNames :: Map ModuleName [(Text, NominalId)] -> TypeInterface -> Map Text NominalId
interfaceReferenceNames available value = foldMap one (interfaceImports value)
 where
  one (Located _ imported) = case Map.lookup (locatedValue (importModule imported)) available of
    Nothing -> Map.empty
    Just dependency ->
      let selected = Set.fromList (map locatedValue (importItems imported))
       in Map.fromList (concatMap (binding imported selected) dependency)

  binding imported selected (name, identity)
    | Set.null selected = [(qualifier imported <> "." <> name, identity)]
    | Set.member name selected = [(name, identity)]
    | otherwise = []

  qualifier imported = maybe
    (lastSegment (moduleNameText (locatedValue (importModule imported))))
    locatedValue
    (importAlias imported)

lastSegment :: Text -> Text
lastSegment value = case reverse (Text.splitOn "." value) of
  first : _ -> first
  [] -> value
