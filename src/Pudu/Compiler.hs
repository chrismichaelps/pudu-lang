{-| @Program.Compiler.Module — orchestrates explicit compiler phases -}
module Pudu.Compiler
  ( FrontendResult (..)
  , runFrontend
  ) where

import Pudu.Diagnostic (Diagnostic, hasErrors, sortDiagnostics)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser (ParseResult (..), parseModule)
import Pudu.Frontend.Syntax (Module)
import Pudu.Frontend.Token (Token)
import Pudu.Source (Source)

{-| @Program.Compiler.FrontendResult — exposes valid frontend products -}
data FrontendResult = FrontendResult
  { frontendTokens :: ![Token]
  , frontendModule :: !(Maybe Module)
  , frontendDiagnostics :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

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
