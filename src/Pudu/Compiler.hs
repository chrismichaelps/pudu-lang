{-| @Program.Compiler.Module — orchestrates explicit compiler phases -}
module Pudu.Compiler
  ( CompileResult (..)
  , FrontendResult (..)
  , runCompile
  , runFrontend
  ) where

import Pudu.Diagnostic (Diagnostic, hasErrors, sortDiagnostics)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser (ParseResult (..), parseModule)
import Pudu.Frontend.Syntax (Module)
import Pudu.Frontend.Token (Token)
import Pudu.Semantic (Resolution, resolveModule)
import Pudu.Type (TypeInfo, checkTypes)
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

{-| Run lexing, parsing, name resolution, and type checking in fixed order.

    Each phase runs only on what the previous one admitted, so a defect is
    explained by the earliest phase that can explain it and never a second time
    by a later one. The module is withheld when any error-severity diagnostic
    exists. -}
runCompile :: Source -> CompileResult
runCompile source =
  let FrontendResult{frontendTokens, frontendModule, frontendDiagnostics} = runFrontend source
   in case frontendModule of
        Nothing ->
          CompileResult
            { compileTokens = frontendTokens
            , compileModule = Nothing
            , compileResolution = Nothing
            , compileTypes = Nothing
            , compileDiagnostics = frontendDiagnostics
            }
        Just parsed ->
          let (resolution, resolutionDiagnostics) = resolveModule parsed
              resolved = sortDiagnostics (frontendDiagnostics <> resolutionDiagnostics)
              (types, typeDiagnostics) =
                if hasErrors resolved then (Nothing, []) else typedResult parsed
              diagnostics = sortDiagnostics (resolved <> typeDiagnostics)
           in CompileResult
                { compileTokens = frontendTokens
                , compileModule = if hasErrors diagnostics then Nothing else Just parsed
                , compileResolution = Just resolution
                , compileTypes = types
                , compileDiagnostics = diagnostics
                }

{-| Typing runs only on a module whose names all resolved: an unresolved name
    has no type, and reporting one would explain the same defect twice. -}
typedResult :: Module -> (Maybe TypeInfo, [Diagnostic])
typedResult parsed =
  let (info, diagnostics) = checkTypes parsed
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
