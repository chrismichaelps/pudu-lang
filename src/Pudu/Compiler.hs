{-| @Program.Compiler.Module — orchestrates explicit compiler phases -}
module Pudu.Compiler
  ( CompileContext (..)
  , CompileResult (..)
  , FrontendResult (..)
  , compileFrontendWith
  , emptyCompileContext
  , runCompile
  , runCompileWith
  , runFrontend
  ) where

import Pudu.Diagnostic (Diagnostic, hasErrors, sortDiagnostics)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser (ParseResult (..), parseModule)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Pudu.Frontend.Syntax (Module, ModuleName)
import Pudu.Frontend.Token (Token)
import Pudu.Eval (EvalOutcome (..), evaluateModule)
import Pudu.Frontend.Expand (expandModule)
import Pudu.Semantic (ExportIndex, Resolution, emptyExportIndex, resolveModule, resolveModuleWith)
import Pudu.Doc (DocIndex, buildIndex)
import Pudu.Type (ModuleTypes (..), TypeInfo, checkTypesDetailed)
import Pudu.Type.Interface (TypeInterface, importsFor)
import Data.Text (Text)
import Pudu.Source (Source, Span)

{-| @Program.Compiler.FrontendResult — exposes valid frontend products -}
data FrontendResult = FrontendResult
  { frontendTokens :: ![Token]
  , frontendModule :: !(Maybe Module)
  , frontendDiagnostics :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

{-| @Program.Compiler.CompileResult — exposes frontend products plus the
    resolution that later phases consume -}
data CompileResult = CompileResult
  { compileTokens :: ![Token]
  , compileModule :: !(Maybe Module)
  , compileResolution :: !(Maybe Resolution)
  , compileTypes :: !(Maybe TypeInfo)
  {-| What inference settled on for each integer literal this module wrote.

      A literal written without a suffix is not a platform `Int` merely because
      it was written plainly, and only the checker knows what it became. The
      evaluator reads this to build the literal as the type it is. -}
  , compileIntegerKinds :: !(Map Span Text)
  , compileDocs :: !(Maybe DocIndex)
  , compileDiagnostics :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

data CompileContext = CompileContext
  { contextExports :: !ExportIndex
  , contextTypes :: !(Map ModuleName TypeInterface)
  , contextStrictImports :: !Bool
  }
  deriving stock (Eq, Show)

emptyCompileContext :: CompileContext
emptyCompileContext = CompileContext emptyExportIndex Map.empty False

{-| Run lexing, parsing, name resolution, and type checking in fixed order.

    Each phase runs only on what the previous one admitted, so a defect is
    explained by the earliest phase that can explain it and never a second time
    by a later one. The module is withheld when any error-severity diagnostic
    exists. -}
{-| Compiling runs the evaluator to fold constants, and the evaluator lives in
    `IO` so that a program can reach the world. Folding itself never does: it is
    run with effects denied, so a constant that tried to read a file is refused
    rather than performed while the compiler runs. The `IO` here is a type, not
    a permission. -}
runCompile :: Source -> IO CompileResult
runCompile = runCompileWith emptyCompileContext

runCompileWith :: CompileContext -> Source -> IO CompileResult
runCompileWith context source = compileFrontendWith context (runFrontend source)

compileFrontendWith :: CompileContext -> FrontendResult -> IO CompileResult
compileFrontendWith context FrontendResult{frontendTokens, frontendModule, frontendDiagnostics} =
  case frontendModule of
        Nothing ->
          pure CompileResult
            { compileTokens = frontendTokens
            , compileModule = Nothing
            , compileResolution = Nothing
            , compileTypes = Nothing
            , compileIntegerKinds = Map.empty
            , compileDocs = Nothing
            , compileDiagnostics = frontendDiagnostics
            }
        Just original ->
          let (parsed, expansionDiagnostics) = expandModule original
              (resolution, resolutionDiagnostics) =
                if contextStrictImports context
                  then resolveModuleWith (contextExports context) parsed
                  else resolveModule parsed
              resolved =
                sortDiagnostics
                  (frontendDiagnostics <> expansionDiagnostics <> resolutionDiagnostics)
              (typing, typeDiagnostics) =
                if hasErrors resolved then (Nothing, []) else typedResult context parsed
              types = moduleTypeInfo <$> typing
              typed = sortDiagnostics (resolved <> typeDiagnostics)
           in do
                constantDiagnostics <-
                  if hasErrors typed
                    then pure []
                    else foldConstants (maybe Map.empty moduleIntegerKinds typing) parsed
                let diagnostics = sortDiagnostics (typed <> constantDiagnostics)
                pure
                  CompileResult
                    { compileTokens = frontendTokens
                    , compileModule = if hasErrors diagnostics then Nothing else Just parsed
                    , compileResolution = Just resolution
                    , compileTypes = types
                    , compileIntegerKinds =
                        maybe Map.empty moduleIntegerKinds typing
                    , compileDocs =
                        (\checked -> buildIndex frontendTokens checked parsed) <$> typing
                    , compileDiagnostics = diagnostics
                    }

{-| Evaluate the module's constants at compile time.

    [[architecture/SEMANTICS]] makes a module-scope `const` a compile-time
    value, so its initializer runs here rather than when the program does. A
    failure — division by zero, an exhausted evaluation budget, a constant that
    reads one declared later — is therefore a compile diagnostic, and the same
    bounded evaluator that runs the program produces it.

    Folding runs only on a module that typed, so an initializer whose meaning
    was never established is not evaluated for a second opinion. -}
foldConstants :: Map Span Text -> Module -> IO [Diagnostic]
foldConstants integerKinds parsed =
  outcomeDiagnostics <$> evaluateModule integerKinds parsed

{-| Typing runs only on a module whose names all resolved: an unresolved name
    has no type, and reporting one would explain the same defect twice. -}
typedResult :: CompileContext -> Module -> (Maybe ModuleTypes, [Diagnostic])
typedResult context parsed =
  let imported = importsFor (contextTypes context) parsed
      (checked, diagnostics) = checkTypesDetailed imported parsed
   in (Just checked, diagnostics)

runFrontend :: Source -> FrontendResult
runFrontend source =
  let LexResult{lexTokens, lexDiagnostics} = lexSource source
      ParseResult{parseModuleValue, parseDiagnostics} = parseModule source lexTokens
      diagnostics = sortDiagnostics (lexDiagnostics <> parseDiagnostics)
      validModule = if hasErrors diagnostics then Nothing else parseModuleValue
   in FrontendResult
        { frontendTokens = lexTokens
        , frontendModule = validModule
        , frontendDiagnostics = diagnostics
        }
