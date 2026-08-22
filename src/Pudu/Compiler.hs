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
  , compileDiagnostics :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

{-| Run lexing, parsing, and name resolution in fixed order. Resolution runs
    only on a module the parser admitted, so a syntax error never produces a
    second explanation from a later phase. The module is withheld when any
    error-severity diagnostic exists. -}
runCompile :: Source -> CompileResult
runCompile source =
  let FrontendResult{frontendTokens, frontendModule, frontendDiagnostics} = runFrontend source
   in case frontendModule of
        Nothing ->
          CompileResult
            { compileTokens = frontendTokens
            , compileModule = Nothing
            , compileResolution = Nothing
            , compileDiagnostics = frontendDiagnostics
            }
        Just parsed ->
          let (resolution, resolutionDiagnostics) = resolveModule parsed
              diagnostics = sortDiagnostics (frontendDiagnostics <> resolutionDiagnostics)
           in CompileResult
                { compileTokens = frontendTokens
                , compileModule = if hasErrors diagnostics then Nothing else Just parsed
                , compileResolution = Just resolution
                , compileDiagnostics = diagnostics
                }

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
