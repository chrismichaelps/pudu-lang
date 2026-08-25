{-| @Program.Compiler.Program.Module — compiles a filesystem module graph -}
module Pudu.Compiler.Program
  ( ProgramResult (..)
  , compileProgram
  , programDependencies
  , programDocs
  , rootCompileResult
  ) where

import Control.Exception (IOException, try)
import Data.Graph (SCC, flattenSCC, stronglyConnComp)
import Data.List (isSuffixOf, sort)
import Data.List.NonEmpty (toList)
import Data.Maybe (fromMaybe)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler
  ( CompileContext (..)
  , CompileResult (..)
  , FrontendResult (..)
  , compileFrontendWith
  , runFrontend
  )
import Pudu.Compiler.Library (isStandardModule, searchRoots)
import Pudu.Doc (DocIndex)
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (Error)
  , diagnostic
  , mkDiagnosticCode
  , sortDiagnostics
  , withHelp
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import Pudu.Frontend.Syntax.Tree (Import (..), Module (..))
import Pudu.Semantic.Interface (exportIndex)
import Pudu.Source (Source, SourceName (..), emptySpan, newSource)
import Pudu.Type.Interface (interfaceSkeleton)
import System.FilePath
  ( (</>)
  , dropExtension
  , joinPath
  , normalise
  , splitDirectories
  , takeDirectory
  )

data ProgramResult = ProgramResult
  { programRoot :: !(Maybe ModuleName)
  , programModules :: !(Map ModuleName CompileResult)
  , programSources :: ![Source]
  , programOrder :: ![ModuleName]
  , programDiagnostics :: ![Diagnostic]
  , programContext :: !CompileContext
  }

{-| Every documented name in the program, in dependency order.

    Ordering by `programOrder` rather than by module name means a search over a
    whole program lists a dependency's answer before the module that uses it,
    which is the order a reader follows a definition in. -}
programDocs :: ProgramResult -> DocIndex
programDocs result =
  foldMap forModule (programOrder result)
 where
  forModule name = case Map.lookup name (programModules result) of
    Nothing -> mempty
    Just compiled -> fromMaybe mempty (compileDocs compiled)

{-| The program's dependencies, in the order they must be linked.

    The root is excluded: it is the module being evaluated, not one of its
    dependencies, and linking it twice would run its constants twice. A module
    that failed to compile is excluded too — there is nothing to link — and the
    diagnostics already say why. -}
programDependencies :: ProgramResult -> [(Text.Text, Module)]
programDependencies result =
  [ (moduleNameText name, parsed)
  | name <- programOrder result
  , Just name /= programRoot result
  , Just compiled <- [Map.lookup name (programModules result)]
  , Just parsed <- [compileModule compiled]
  ]

rootCompileResult :: ProgramResult -> Maybe CompileResult
rootCompileResult result = programRoot result >>= (`Map.lookup` programModules result)

compileProgram :: FilePath -> IO ProgramResult
compileProgram rootPath = do
  rootRead <- readSource rootPath
  case rootRead of
    Left _ -> do
      source <- newSource (SourceName (Text.pack rootPath)) Text.empty
      pure (ProgramResult Nothing Map.empty [source] [] (rootReadFailure rootPath source)
        (CompileContext (exportIndex Map.empty) Map.empty True))
    Right rootSource -> do
      let rootFrontend = runFrontend rootSource
      case frontendModule rootFrontend of
        Nothing ->
          pure
            (ProgramResult Nothing Map.empty [rootSource] [] (frontendDiagnostics rootFrontend) (CompileContext (exportIndex Map.empty) Map.empty True))
        Just rootModule -> do
          let rootName = locatedValue (moduleName rootModule)
              (sourceRoot, rootMismatch) = deriveSourceRoot rootPath rootModule
          if rootMismatch
            then do
              let mismatch = rootPathMismatch rootPath (moduleName rootModule)
                  emptyContext = CompileContext (exportIndex Map.empty) Map.empty True
              compiled <- compileFrontendWith emptyContext rootFrontend
              pure
                (ProgramResult (Just rootName) (Map.singleton rootName compiled)
                  [rootSource] [rootName]
                  (sortDiagnostics (frontendDiagnostics rootFrontend <> mismatch)) emptyContext)
            else do
              discovered <- discover sourceRoot
                (Map.singleton rootName rootFrontend)
                (Map.singleton rootName rootSource)
                []
                (importsOf rootModule)
              finish rootName discovered

data Discovery = Discovery
  { discoveredFrontends :: !(Map ModuleName FrontendResult)
  , discoveredSources :: !(Map ModuleName Source)
  , discoveredDiagnostics :: ![Diagnostic]
  }

discover
  :: FilePath
  -> Map ModuleName FrontendResult
  -> Map ModuleName Source
  -> [Diagnostic]
  -> [(Located Import, ModuleName)]
  -> IO Discovery
discover sourceRoot frontends sources diagnostics pending = case pending of
  [] -> pure (Discovery frontends sources diagnostics)
  (locatedImport, requested) : rest
    | Map.member requested frontends -> discover sourceRoot frontends sources diagnostics rest
    | otherwise -> do
        roots <- searchRoots sourceRoot requested
        loaded <- readFirst [modulePath root requested | root <- roots]
        case loaded of
          Left _ ->
            discover sourceRoot frontends sources
              (diagnostics <> missingModule requested locatedImport) rest
          Right source -> do
            let frontend = runFrontend source
            case frontendModule frontend of
              Nothing ->
                discover sourceRoot
                  (Map.insert requested frontend frontends)
                  (Map.insert requested source sources)
                  diagnostics rest
              Just parsed ->
                let actual = locatedValue (moduleName parsed)
                 in if actual /= requested
                      then discover sourceRoot
                        (Map.insert requested frontend{frontendModule = Nothing} frontends)
                        (Map.insert requested source sources)
                        (diagnostics <> pathMismatch requested (moduleName parsed)) rest
                      else discover sourceRoot
                        (Map.insert requested frontend frontends)
                        (Map.insert requested source sources)
                        diagnostics (importsOf parsed <> rest)

finish :: ModuleName -> Discovery -> IO ProgramResult
finish rootName discovered = do
  let validModules = Map.mapMaybe frontendModule (discoveredFrontends discovered)
      interfaces = Map.map interfaceSkeleton validModules
      context = CompileContext (exportIndex validModules) interfaces True
      order = dependencyOrder validModules
      pending =
        [ (name, frontend)
        | name <- order
        , Just frontend <- [Map.lookup name (discoveredFrontends discovered)]
        ]
  {-| Modules compile in dependency order, one at a time, because compiling a
      module folds its constants and folding runs the evaluator. -}
  results <- mapM (\(name, frontend) -> (,) name <$> compileFrontendWith context frontend) pending
  let compiled = Map.fromList results
      uncompiled = Map.difference (discoveredFrontends discovered) compiled
      diagnostics = sortDiagnostics
        ( discoveredDiagnostics discovered
            <> concatMap frontendDiagnostics (Map.elems uncompiled)
            <> concatMap compileDiagnostics (Map.elems compiled)
        )
  pure (ProgramResult (Just rootName) compiled (Map.elems (discoveredSources discovered)) order diagnostics context)

dependencyOrder :: Map ModuleName Module -> [ModuleName]
dependencyOrder modules =
  concatMap ordered (stronglyConnComp nodes)
 where
  nodes =
    [ (name, name, [dependency | (_, dependency) <- importsOf value, Map.member dependency modules])
    | (name, value) <- Map.toList modules
    ]
  ordered :: SCC ModuleName -> [ModuleName]
  ordered = sort . flattenSCC

importsOf :: Module -> [(Located Import, ModuleName)]
importsOf value =
  [ (located, locatedValue (importModule imported))
  | located@(Located _ imported) <- moduleImports value
  ]

deriveSourceRoot :: FilePath -> Module -> (FilePath, Bool)
deriveSourceRoot rootPath value =
  let pathParts = splitDirectories (dropExtension (normalise rootPath))
      nameParts = map Text.unpack (toList (moduleNameSegments (locatedValue (moduleName value))))
      agrees = nameParts `isSuffixOf` pathParts
      kept = take (length pathParts - length nameParts) pathParts
   in (if agrees then joinPath kept else takeDirectory rootPath, not agrees)

modulePath :: FilePath -> ModuleName -> FilePath
modulePath sourceRoot name =
  normalise (sourceRoot </> joinPath (map Text.unpack (toList (moduleNameSegments name))) <> ".pudu")

{-| Read the first path that exists, keeping the last failure so a module that
    is nowhere is reported against the search rather than against one guess. -}
readFirst :: [FilePath] -> IO (Either IOException Source)
readFirst [] = readSource ""
readFirst [path] = readSource path
readFirst (path : rest) = do
  loaded <- readSource path
  case loaded of
    Right source -> pure (Right source)
    Left _ -> readFirst rest

readSource :: FilePath -> IO (Either IOException Source)
readSource path = do
  loaded <- try (TextIO.readFile path)
  case loaded of
    Left problem -> pure (Left problem)
    Right contents -> Right <$> newSource (SourceName (Text.pack path)) contents

missingModule :: ModuleName -> Located Import -> [Diagnostic]
missingModule requested locatedImport = do
  code <- maybe [] pure (mkDiagnosticCode "E2014")
  value <- maybe [] pure
    (diagnostic code Error (locatedSpan locatedImport)
      ("cannot read module " <> moduleNameText requested))
  pure (withHelp helpText value)
 where
  {-| A missing `Std` module is almost always a misspelling of a module that
      exists, not a file the author forgot to write, so the help points at the
      library rather than at their own source root. -}
  helpText
    | isStandardModule requested =
        "check the spelling against the standard library, or set PUDU_LIB if it is installed elsewhere"
    | otherwise = "create the module at its canonical source-root path, or fix the import"

pathMismatch :: ModuleName -> Located ModuleName -> [Diagnostic]
pathMismatch requested actual = do
  code <- maybe [] pure (mkDiagnosticCode "E2015")
  value <- maybe [] pure
    (diagnostic code Error (locatedSpan actual)
      ("module path expects " <> moduleNameText requested
        <> ", but the file declares " <> moduleNameText (locatedValue actual)))
  pure (withHelp "make the module header agree with its canonical path" value)

rootPathMismatch :: FilePath -> Located ModuleName -> [Diagnostic]
rootPathMismatch rootPath actual = do
  code <- maybe [] pure (mkDiagnosticCode "E2015")
  value <- maybe [] pure
    (diagnostic code Error (locatedSpan actual)
      ("module " <> moduleNameText (locatedValue actual)
        <> " does not match source path " <> Text.pack (normalise rootPath)))
  pure (withHelp "rename the file hierarchy or change the module header so their segments agree" value)

rootReadFailure :: FilePath -> Source -> [Diagnostic]
rootReadFailure rootPath source = do
  code <- maybe [] pure (mkDiagnosticCode "E2014")
  value <- maybe [] pure
    (diagnostic code Error (emptySpan source)
      ("cannot read root source " <> Text.pack (normalise rootPath)))
  pure (withHelp "check that the path names a readable Pudu source file" value)
