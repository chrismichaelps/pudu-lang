{-| @Test.Derive.CacheSpec — compile-time content and actual warm consumer invalidation. -}
module Pudu.Derive.CacheSpec (deriveCacheProperties) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..), FrontendResult (..), runFrontend)
import Pudu.Compiler.Cache
  ( disabledCache, interfaceKey, openCollectingCache, openProductCacheAt, storeFrontend )
import Pudu.Compiler.ComptimeDependencies (compiletimeDependencies)
import Pudu.Compiler.Program
  ( compileProgramCached, programDiagnostics, programDependencies, programFolded
  , programIntegerKinds, rootCompileResult )
import Pudu.Diagnostic (hasErrors)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntryFolded)
import Pudu.Eval.Render (renderValue)
import Pudu.Frontend.Syntax.Located (locatedValue)
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Pudu.Frontend.Syntax.Tree (Module (..))
import Pudu.Source (Source, SourceName (..), newSource)
import System.Directory (getModificationTime, setModificationTime)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

deriveCacheProperties :: [(String, IO Property)]
deriveCacheProperties =
  [ ("derive cache keys include observable compile-time code", contentKeys)
  , ("derive cache inputs follow compile-time roots through cyclic diamonds", dependencyClosure)
  , ("warm cached constants observe transitive ordinary helper body edits", warmConstants)
  ]

contentKeys :: IO Property
contentKeys = do
  cache <- openCollectingCache Map.empty
  let key contents = do
        source <- newSource (SourceName "Lib.pudu") contents
        unit <- parsed source
        storeFrontend cache source unit
        interfaceKey cache source
      base held = "module Lib\nexport trait Label {fn label(self: &Self) -> Str}\nexport derive Label for T: Record {fn label(self: &T) -> Str = " <> held <> "}\n"
      variants =
        [ ("derive body", base "\"one\"", base "\"two\"")
        , ("private marked helper", base "wire()" <> "comptime fn wire() -> Str = \"one\"", base "wire()" <> "comptime fn wire() -> Str = \"two\"")
        , ("private constant", base "KEY" <> "const KEY: Str = \"one\"", base "KEY" <> "const KEY: Str = \"two\"")
        , ("local macro", base "wire!(\"\")" <> "macro wire(x: expr) = x + \"one\"", base "wire!(\"\")" <> "macro wire(x: expr) = x + \"two\"")
        ]
  findings <- mapM (\(label, before, after) -> do
    first <- key before
    second <- key after
    pure (counterexample label (first /= second))) variants
  original <- key (base "\"one\"")
  relocated <- key ("// relocation is not interface content\n\n" <> base "\"one\"")
  ordinaryBefore <- key "module Lib\nexport fn answer() -> Int = 41"
  ordinaryAfter <- key "module Lib\nexport fn answer() -> Int = 42"
  pure (conjoin (findings <>
    [ counterexample "derive interface identity ignores source positions" (original === relocated)
    , counterexample "ordinary runtime interfaces remain body-free" (ordinaryBefore === ordinaryAfter)
    ]))

dependencyClosure :: IO Property
dependencyClosure = do
  let branch name imports suffix = do
        source <- newSource (SourceName (name <> ".pudu"))
          ("module " <> name <> "\n" <> imports <> "\n" <> suffix)
        unit <- parsed source
        pure (locatedValue (moduleName unit), unit)
      graph rootBody otherBody = Map.fromList <$> sequence
        [ branch "Main" "import B\nimport C" rootBody
        , branch "B" "import D" otherBody
        , branch "C" "import D" "fn unused() -> Int = 0"
        , branch "D" "import B\nimport Ghost" "fn answer() -> Int = 41"
        , branch "Unused" "" "fn ignored() -> Int = 0"
        ]
      closure = map moduleNameText . Set.toAscList . compiletimeDependencies
  constant <- graph "const VALUE: Int = 0" "fn relay() -> Int = 0"
  ordinary <- graph "fn main() -> Int = 0" "comptime fn relay() -> Int = 0"
  definitions <- graph "fn main() -> Int = 0" "trait Label {}\nderive Label for T: Record {}"
  requests <- graph "trait Label {}\ntype Sample = {value: Int} derives Label" "fn relay() -> Int = 0"
  pure $ conjoin
    [ closure constant === ["B", "C", "D", "Main"]
    , closure ordinary === []
    , closure definitions === ["B", "D"]
    , closure requests === ["B", "C", "D", "Main"]
    ]

warmConstants :: IO Property
warmConstants = withSystemTempDirectory "pudu-derive-cache" $ \root -> do
  let helper = root </> "Helper.pudu"
      entry = root </> "Main.pudu"
      cacheRoot = root </> "cache"
      helperText :: Text -> Text
      helperText value = "module Helper\nexport fn answer() -> Int = " <> value <> "\n"
      cached = openProductCacheAt cacheRoot >>= (`compileProgramCached` entry)
      observe action = do
        result <- action
        output <- case rootCompileResult result >>= compileModule of
          Nothing -> pure Nothing
          Just unit -> do
            outcome <- evaluateProgramEntryFolded (programFolded result)
              (programIntegerKinds result) (programDependencies result) "main" unit
            pure (renderValue <$> outcomeValue outcome)
        pure (programDiagnostics result, output,
          Map.keys (Map.findWithDefault Map.empty "Main" (programFolded result)))
  TextIO.writeFile helper (helperText "41")
  TextIO.writeFile (root </> "Lib.pudu")
    "module Lib\nimport Helper\nexport fn relay() -> Int = Helper.answer()\n"
  TextIO.writeFile entry
    "module Main\nimport Lib\nconst VALUE: Int = Lib.relay()\nfn main() -> Int = VALUE\n"
  first <- observe cached
  warm <- observe cached
  stamp <- getModificationTime helper
  TextIO.writeFile helper (helperText "42")
  setModificationTime helper stamp
  changed <- observe cached
  fresh <- observe (compileProgramCached disabledCache entry)
  pure $ counterexample (show (first, warm, changed, fresh)) $ conjoin
    [ first === ([], Just "41", ["VALUE"])
    , warm === first
    , changed === ([], Just "42", ["VALUE"])
    , changed === fresh
    ]

parsed :: Source -> IO Module
parsed source = case runFrontend source of
  FrontendResult{frontendModule = Just value, frontendDiagnostics}
    | not (hasErrors frontendDiagnostics) -> pure value
  result -> fail ("derive cache fixture failed to parse: " <> show result)
