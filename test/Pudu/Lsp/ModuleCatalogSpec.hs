{-| @Test.Lsp.ModuleCatalog — completion admits exactly the compiler's roots -}
module Pudu.Lsp.ModuleCatalogSpec (catalogProperties) where

import Control.Exception (bracket)
import Control.Monad (forM_)
import Data.List (sort)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Set as Set
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler.Library (isStandardModule)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Lsp.ModuleCatalog (moduleCatalog)
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath (takeDirectory, (</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

catalogProperties :: [(String, IO Property)]
catalogProperties = [("import completion follows compiler roots with installed packages", testCatalogRoots)]

testCatalogRoots :: IO Property
testCatalogRoots = withSystemTempDirectory "pudu-catalog-roots" $ \root ->
  bracket (lookupEnv "PUDU_LIB") restore $ \_ -> do
    let project = root </> "project"
        source = project </> "src"
        package = project </> "deps" </> "@test" </> "catalog" </> "src"
        library = root </> "library"
        namespaces = ["Std", "Ark", "Arks", "Tools"]
        write path contents = do
          createDirectoryIfMissing True (takeDirectory path)
          TextIO.writeFile path contents
        declaration first suffix = "module " <> first <> "." <> suffix <> "\n"
        shipped first = isStandardModule (ModuleName (first :| []))
    createDirectoryIfMissing True source
    write (project </> "pudu.toml") "[package]\nname = \"catalog\"\nsource = \"src\"\n"
    write (project </> "pudu.lock")
      "version = 1\n[[package]]\nname = \"@test/catalog\"\nversion = \"1.0.0\"\nsource = \"fixture\"\nchecksum = \"fixture\"\nroot = \"catalog\"\ndependencies = []\n"
    forM_ namespaces $ \first -> do
      let directory = Text.unpack first
      write (source </> directory </> "ProjectCatalog654.pudu") (declaration first "ProjectCatalog654")
      write (package </> directory </> "PackageCatalog654.pudu") (declaration first "PackageCatalog654")
      write (library </> directory </> "LibraryCatalog654.pudu") (declaration first "LibraryCatalog654")
    setEnv "PUDU_LIB" library
    names <- moduleCatalog source
    pure $ conjoin
      ( counterexample "catalog remains sorted and unique" (names === sort (Set.toList (Set.fromList names)))
          : concatMap
            (\first ->
              [ counterexample (Text.unpack first <> " project declarations remain visible")
                  ((first <> ".ProjectCatalog654" `elem` names) === True)
              , counterexample (Text.unpack first <> " library admission follows compiler policy")
                  ((first <> ".LibraryCatalog654" `elem` names) === shipped first)
              , counterexample (Text.unpack first <> " package admission follows compiler policy")
                  ((first <> ".PackageCatalog654" `elem` names) === not (shipped first))
              ]
            )
            namespaces
      )
 where
  restore previous = maybe (unsetEnv "PUDU_LIB") (setEnv "PUDU_LIB") previous
