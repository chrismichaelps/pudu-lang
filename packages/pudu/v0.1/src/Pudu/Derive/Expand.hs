{-| @Derive.Expand — prints the implementations a module's derive requests produced. -}
module Pudu.Derive.Expand (expansionText) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program (ProgramResult (..))
import Pudu.Format (FormatResult (..), formatSource)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Pudu.Frontend.Syntax.Print (printImpl)
import Pudu.Frontend.Syntax.Tree (Declaration (..), Impl (..), Module (..), TypeSyntax (..))
import Pudu.Source (SourceName (..), emptySpan, newSource, sameSpanSource, spanOrigin)

{-| Every implementation generated for a request the root module wrote, in
    program order, each under a line naming what produced it. The checked
    syntax is printed rather than the executable product, so the text is what
    a person would have written by hand: no resolved literals or selections. -}
expansionText :: ProgramResult -> IO Text
expansionText program = case programRoot program >>= (`Map.lookup` programNamedSources program) of
  Nothing -> pure Text.empty
  Just root -> do
    let anchor = emptySpan root
        generated =
          [ "// derive " <> written (implTrait impl) <> " for " <> written (implTarget impl)
              <> ", generated in " <> moduleNameText owner <> "\n" <> printImpl impl
          | owner <- programOrder program
          , Just compiled <- [Map.lookup owner (programModules program)]
          , Just unit <- [compileSyntax compiled]
          , Located at (ImplDeclaration impl) <- moduleDeclarations unit
          , Just (_, request, _) <- [spanOrigin at]
          , sameSpanSource request anchor
          ]
    source <- newSource (SourceName "expansion") (Text.intercalate "\n" generated)
    pure (formatText' (formatSource source))
 where
  written (Located _ syntax) = case syntax of
    NamedType path _ -> moduleNameText path
    _ -> "a type"
