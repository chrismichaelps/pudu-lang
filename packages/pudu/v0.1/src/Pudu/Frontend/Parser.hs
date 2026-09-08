{-| @Program.Parser.Module — recovers structured surface programs -}
module Pudu.Frontend.Parser
  ( ParseResult (..)
  , parseModule
  ) where

import Pudu.Diagnostic (Diagnostic)
import Pudu.Frontend.Parser.Declaration (parseCompilationUnit)
import Pudu.Frontend.Parser.State (runParser)
import Pudu.Frontend.Syntax.Tree (Module)
import Pudu.Frontend.Token (Token)
import Pudu.Source (Source)

{-| @Program.Parser.Result — separates recovery tree from diagnostics -}
data ParseResult = ParseResult
  { parseModuleValue :: !(Maybe Module)
  , parseDiagnostics :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

{-| The recovered module and its diagnostics stay separate here; whether the
    module is compilable is decided by [[Compiler Pipeline]], not the parser. -}
parseModule :: Source -> [Token] -> ParseResult
parseModule source tokens =
  let (moduleValue, diagnostics) = runParser source parseCompilationUnit tokens
   in ParseResult{parseModuleValue = moduleValue, parseDiagnostics = diagnostics}
