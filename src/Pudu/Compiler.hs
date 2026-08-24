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
import Pudu.Semantic (ExportIndex, Resolution, emptyExportIndex, resolveModule, resolveModuleWith)
import Pudu.Type (TypeInfo, checkTypesWith)
import Pudu.Type.Interface (TypeInterface, importsFor)
import Pudu.Source (Source)

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
runCompile :: Source -> CompileResult
runCompile = runCompileWith emptyCompileContext

runCompileWith :: CompileContext -> Source -> CompileResult
runCompileWith context source = compileFrontendWith context (runFrontend source)

compileFrontendWith :: CompileContext -> FrontendResult -> CompileResult
compileFrontendWith context FrontendResult{frontendTokens, frontendModule, frontendDiagnostics} =
  case frontendModule of
        Nothing ->
          CompileResult
            { compileTokens = frontendTokens
            , compileModule = Nothing
            , compileResolution = Nothing
            , compileTypes = Nothing
            , compileDiagnostics = frontendDiagnostics
            }
        Just parsed ->
          let (resolution, resolutionDiagnostics) =
                if contextStrictImports context
                  then resolveModuleWith (contextExports context) parsed
                  else resolveModule parsed
              resolved = sortDiagnostics (frontendDiagnostics <> resolutionDiagnostics)
              (types, typeDiagnostics) =
                if hasErrors resolved then (Nothing, []) else typedResult context parsed
              typed = sortDiagnostics (resolved <> typeDiagnostics)
              constantDiagnostics =
                if hasErrors typed then [] else foldConstants parsed
              diagnostics = sortDiagnostics (typed <> constantDiagnostics)
           in CompileResult
                { compileTokens = frontendTokens
                , compileModule = if hasErrors diagnostics then Nothing else Just parsed
                , compileResolution = Just resolution
                , compileTypes = types
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
foldConstants :: Module -> [Diagnostic]
foldConstants parsed = outcomeDiagnostics (evaluateModule parsed)

{-| Typing runs only on a module whose names all resolved: an unresolved name
    has no type, and reporting one would explain the same defect twice. -}
typedResult :: CompileContext -> Module -> (Maybe TypeInfo, [Diagnostic])
typedResult context parsed =
  let imported = importsFor (contextTypes context) parsed
      (info, diagnostics) = checkTypesWith imported parsed
   in (Just info, diagnostics)

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
