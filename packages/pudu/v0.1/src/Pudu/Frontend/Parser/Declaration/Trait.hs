{-| @Program.Parser.Declaration.Trait — parses trait contracts and impls -}
module Pudu.Frontend.Parser.Declaration.Trait
  ( parseImpl
  , parseTrait
  ) where

import Pudu.Frontend.Parser.Declaration.Function (parseFunctionValue)
import Pudu.Frontend.Parser.Declaration.Generic (parseTypeParams, parseWhereClause)
import Pudu.Frontend.Parser.Name (expectUpperIdentifier)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , budgetExhausted
  , emitParseError
  , expectKeyword
  , expectSymbol
  , isSymbol
  , peekKind
  , peekToken
  )
import Pudu.Frontend.Parser.Type (parseTypeSyntax)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Function
  , Impl (..)
  , Trait (..)
  , Visibility (Private)
  )
import Pudu.Frontend.Token
  ( Keyword (KwAsync, KwFn, KwFor, KwImpl, KwTrait)
  , Token (..)
  , TokenKind (..)
  )
import Pudu.Source (Span, mergeSpans)

{-| Parse `trait Name[params] where? { members }`. A member is a function whose
    body is optional: a bodiless member declares required behavior, and a
    member with a body supplies a default implementation. -}
parseTrait :: Visibility -> Parser (Located Declaration)
parseTrait visibility = do
  keyword <- expectKeyword KwTrait "to start a trait"
  name <- expectUpperIdentifier "after trait"
  typeParams <- parseTypeParams
  constraints <- parseWhereClause
  _ <- expectSymbol "{" "to start the trait body"
  members <- parseMembers False []
  closing <- expectSymbol "}" "to close the trait body"
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (tokenSpan closing))
        ( TraitDeclaration
            Trait
              { traitVisibility = visibility
              , traitName = name
              , traitTypeParams = typeParams
              , traitConstraints = constraints
              , traitMembers = members
              }
        )
    )

{-| Parse `impl[params] Trait for Target where? { functions }`. Coherence — that
    the trait or the target is declared in this module — is a semantic rule and
    is not checked here. -}
parseImpl :: Parser (Located Declaration)
parseImpl = do
  keyword <- expectKeyword KwImpl "to start an implementation"
  typeParams <- parseTypeParams
  traitSyntax <- parseTypeSyntax
  _ <- expectKeyword KwFor "between the trait and the implementing type"
  target <- parseTypeSyntax
  constraints <- parseWhereClause
  _ <- expectSymbol "{" "to start the implementation body"
  functions <- parseMembers True []
  closing <- expectSymbol "}" "to close the implementation body"
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (tokenSpan closing))
        ( ImplDeclaration
            Impl
              { implTypeParams = typeParams
              , implTrait = traitSyntax
              , implTarget = target
              , implConstraints = constraints
              , implFunctions = functions
              }
        )
    )

{-| Members are functions only; traits declare behavior and never store state,
    so any other member start is diagnosed and skipped one token at a time. -}
parseMembers :: Bool -> [Located Function] -> Parser [Located Function]
parseMembers bodyRequired reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol "}" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      collected <- parseMember bodyRequired reversed
      after <- peekToken
      if before == after
        then advanceToken >> parseMembers bodyRequired collected
        else parseMembers bodyRequired collected

parseMember :: Bool -> [Located Function] -> Parser [Located Function]
parseMember bodyRequired reversed = do
  token <- peekToken
  case tokenKind token of
    Keyword keyword | isFunctionStart keyword -> do
      member <- parseFunctionValue Private bodyRequired
      pure (member : reversed)
    _ -> do
      emitParseError "E1052" (tokenSpan token) "expected a function member"
        (Just "traits and implementations contain only fn members")
      skipToMember
      pure reversed

{-| One rejected member is reported once. Recovery skips to the next `fn` or to
    the closing brace so a non-function member cannot emit a diagnostic per
    token it contains. -}
skipToMember :: Parser ()
skipToMember = do
  token <- peekToken
  case tokenKind token of
    EndOfFile -> pure ()
    Keyword keyword | isFunctionStart keyword -> pure ()
    kind | isSymbol "}" kind -> pure ()
    _ -> advanceToken >> skipToMember

isFunctionStart :: Keyword -> Bool
isFunctionStart keyword = keyword `elem` [KwFn, KwAsync]

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
