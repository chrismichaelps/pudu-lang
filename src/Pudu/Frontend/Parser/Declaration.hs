{-| @Program.Parser.Declaration — orchestrates one compilation unit -}
module Pudu.Frontend.Parser.Declaration
  ( parseCompilationUnit
  ) where

import Pudu.Frontend.Parser.Declaration.Binding (parseTopConst)
import Pudu.Frontend.Parser.Declaration.Block (parseBlock)
import Pudu.Frontend.Parser.Declaration.Function (parseFunction)
import Pudu.Frontend.Parser.Declaration.Import (parseImport)
import Pudu.Frontend.Parser.Declaration.Trait (parseImpl, parseTrait)
import Pudu.Frontend.Parser.Declaration.Type (parseTypeDeclaration)
import Pudu.Frontend.Parser.Name (parseModuleName)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , budgetExhausted
  , emitParseError
  , expectKeyword
  , isDeclarationStart
  , isSymbol
  , matchKeyword
  , peekKind
  , peekToken
  , synchronizeDeclaration
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Declaration (..), Import, Module (..), Visibility (..))
import Pudu.Frontend.Token
  ( Keyword (..)
  , Token (..)
  , TokenKind (..)
  )
import Pudu.Source (Span, mergeSpans)

{-| Parse `module path`, its imports, and its declarations. Composition only:
    every construct grammar lives in its own module, and none of them import
    this one. -}
parseCompilationUnit :: Parser (Maybe Module)
parseCompilationUnit = do
  header <- matchKeyword KwModule
  case header of
    Nothing -> do
      _ <- expectKeyword KwModule "at the start of the file"
      pure Nothing
    Just moduleToken -> do
      name <- parseModuleName
      (imports, declarations) <- parseBody [] []
      let endSpan = lastSpan (locatedSpan name) imports declarations
      pure
        ( Just
            Module
              { moduleSpan = mergedOrLeft (tokenSpan moduleToken) endSpan
              , moduleName = name
              , moduleImports = imports
              , moduleDeclarations = declarations
              }
        )

{-| Iterate the module body. Imports stay ordered before declarations; a later
    import is preserved with `E1034` rather than discarded. Each iteration must
    consume a token, and a latched budget stops the loop without a cascade. -}
parseBody
  :: [Located Import]
  -> [Located Declaration]
  -> Parser ([Located Import], [Located Declaration])
parseBody imports declarations = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if kind == EndOfFile || exhausted
    then pure (reverse imports, reverse declarations)
    else do
      before <- peekToken
      (imports', declarations') <- parseEntry before kind imports declarations
      after <- peekToken
      if before == after
        then advanceToken >> parseBody imports' declarations'
        else parseBody imports' declarations'

parseEntry
  :: Token
  -> TokenKind
  -> [Located Import]
  -> [Located Declaration]
  -> Parser ([Located Import], [Located Declaration])
parseEntry token kind imports declarations = case kind of
  Keyword KwImport -> do
    misplacedImport token declarations
    parsed <- parseImport
    pure (parsed : imports, declarations)
  _ -> do
    declaration <- parseTopDeclaration kind
    pure (imports, declaration : declarations)

misplacedImport :: Token -> [Located Declaration] -> Parser ()
misplacedImport token declarations
  | null declarations = pure ()
  | otherwise =
      emitParseError "E1034" (tokenSpan token) "imports must precede declarations"
        (Just "move every import above the first declaration")

{-| `export` is consumed here and handed to the declaration modules, so no
    construct grammar can invent public API. -}
parseTopDeclaration :: TokenKind -> Parser (Located Declaration)
parseTopDeclaration kind = do
  visibility <- if kind == Keyword KwExport
    then advanceToken >> pure Exported
    else pure Private
  following <- peekKind
  case following of
    Keyword KwConst -> parseTopConst visibility parseBlock
    Keyword KwLet -> rejectedModuleBinding visibility
    Keyword KwVar -> rejectedModuleBinding visibility
    Keyword KwFn -> parseFunction visibility
    Keyword KwAsync -> parseFunction visibility
    Keyword KwType -> parseTypeDeclaration visibility
    Keyword KwTrait -> parseTrait visibility
    Keyword KwImpl -> parseImpl
    Keyword reserved | isReservedDeclaration reserved -> reservedDeclaration
    _ -> unexpectedModuleToken

{-| [[Parser Binding]] owns the single rejection diagnostic for a module `let`
    or `var`; the orchestrator only synchronizes past the rejected binding so
    its initializer does not cascade into further module-scope diagnostics. -}
rejectedModuleBinding :: Visibility -> Parser (Located Declaration)
rejectedModuleBinding visibility = do
  rejected <- parseTopConst visibility parseBlock
  synchronizeDeclaration
  pure rejected

{-| `enum`, `struct`, `macro`, and `comptime` remain reserved: their meaning is
    not yet represented by [[Syntax Tree]], and record/sum shapes are declared
    with `type` in [[grammar/pudu]]. -}
isReservedDeclaration :: Keyword -> Bool
isReservedDeclaration keyword =
  keyword `elem` [KwEnum, KwStruct, KwMacro, KwComptime]

{-| Reserved declaration forms are diagnosed and synchronized, never accepted
    as valid syntax for a construct the compiler cannot yet represent. -}
reservedDeclaration :: Parser (Located Declaration)
reservedDeclaration = do
  token <- peekToken
  emitParseError "E1039" (tokenSpan token) "declaration form is reserved"
    (Just "enum, struct, macro, and comptime declarations enter in later slices; use type for records and sums")
  _ <- advanceToken
  skipReservedRegion 0
  pure (Located (tokenSpan token) InvalidDeclaration)

{-| Skip a reserved declaration, including a braced body, so its closing `}`
    is never re-reported as a stray module-scope token. Recovery stops at the
    next declaration start, never consuming it. -}
skipReservedRegion :: Int -> Parser ()
skipReservedRegion depth = do
  kind <- peekKind
  case kind of
    EndOfFile -> pure ()
    _ | isSymbol "{" kind -> advanceToken >> skipReservedRegion (depth + 1)
      | isSymbol "}" kind ->
          if depth <= 1
            then advanceToken >> pure ()
            else advanceToken >> skipReservedRegion (depth - 1)
      | depth == 0 && isDeclarationStart kind -> pure ()
      | otherwise -> advanceToken >> skipReservedRegion depth

{-| Module-scope synchronization stops at `}`, so a stray delimiter must be
    consumed here or the declaration loop cannot progress. -}
unexpectedModuleToken :: Parser (Located Declaration)
unexpectedModuleToken = do
  token <- peekToken
  emitParseError "E1038" (tokenSpan token) "expected a declaration at module scope"
    (Just "start a module-scope declaration with export, const, fn, async fn, type, trait, or impl")
  _ <- advanceToken
  kind <- peekKind
  if kind == EndOfFile || isSymbol "}" kind || isDeclarationStart kind
    then pure ()
    else synchronizeDeclaration
  pure (Located (tokenSpan token) InvalidDeclaration)

lastSpan :: Span -> [Located Import] -> [Located Declaration] -> Span
lastSpan nameSpan imports declarations =
  case (reverse imports, reverse declarations) of
    (_, declaration : _) -> locatedSpan declaration
    (importValue : _, []) -> locatedSpan importValue
    ([], []) -> nameSpan

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
