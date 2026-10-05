{-| @Program.Parser.Declaration.Derive — parses attributes, derives clauses, and derive declarations

    `derive` and `derives` stay ordinary identifiers everywhere else: both are
    only special where the grammar puts them, at a declaration start and after
    a type definition. Reserving them would rename every program that already
    uses either word, and a language that costs its own users a rename to gain
    a feature has chosen the feature over them. -}
module Pudu.Frontend.Parser.Declaration.Derive
  ( matchDeriveWord
  , parseAttributes
  , parseDeriveDeclaration
  , parseDerivesClause
  , peekDerivesClause
  ) where

import Data.Char (isUpper)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Parser.Declaration.Trait (parseMembers)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , budgetExhausted
  , emitParseError
  , expectIdentifier
  , expectKeyword
  , expectSymbol
  , isDeclarationStart
  , isSymbol
  , lookaheadKind
  , matchSymbol
  , peekKind
  , peekStartsLine
  , peekStartsLine
  , peekToken
  )
import Pudu.Frontend.Parser.Type (parseTypeSyntax)
import Pudu.Frontend.Syntax.Located (Located (..), locatedSpan, locatedValue)
import Pudu.Frontend.Syntax.Tree
  ( Attribute (..)
  , Capability
  , Declaration (..)
  , Derive (..)
  , DeriveRequest (..)
  , DeriveShape (..)
  , Literal (..)
  , TypeSyntax (..)
  , Visibility
  )
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Frontend.Token (Keyword (KwFalse, KwFor, KwImpl, KwNull, KwTrue), SymbolKind (..), Token (..), TokenKind (..))
import Pudu.Source (Span, mergeSpans)

{-| Match a contextual word: the exact identifier and nothing else. Keywords
    never match, so a reserved word in the same position falls through to the
    diagnostic its own construct owns. -}
matchDeriveWord :: Text -> Parser Bool
matchDeriveWord word = do
  kind <- peekKind
  case kind of
    Identifier name | name == word -> advanceToken >> pure True
    _ -> pure False

{-| Whether a `derives` clause with at least one entry follows. The word alone
    is not enough: `| derives` ends a sum when nothing trait-shaped follows,
    and the variant parser then reports the lowercase name itself. -}
peekDerivesClause :: Parser Bool
peekDerivesClause = do
  kind <- peekKind
  case kind of
    Identifier name | name == "derives" -> isTraitStart <$> lookaheadKind 1
    _ -> pure False

isTraitStart :: TokenKind -> Bool
isTraitStart kind = case kind of
  Identifier name -> maybe False (isUpper . fst) (Text.uncons name)
  _ -> False

{-| Parse leading `@name` and `@name(literal, ...)` attributes. Arguments are
    inert literals only; anything else is `E1067`, because only a literal
    stays data without evaluation. -}
parseAttributes :: Parser [Located Attribute]
parseAttributes = do
  kind <- peekKind
  case kind of
    Symbol symbol | symbol == SymAt -> do
      attribute <- parseAttribute
      rest <- parseAttributes
      pure (attribute : rest)
    _ -> pure []

parseAttribute :: Parser (Located Attribute)
parseAttribute = do
  sigil <- advanceToken
  name <- expectIdentifier "after @ to name the attribute"
  (arguments, ending) <- parseAttributeArguments
  let endSpan = maybe (locatedSpan name) id ending
  pure (Located (mergedOrLeft (tokenSpan sigil) endSpan) (Attribute name arguments))

parseAttributeArguments :: Parser ([Located Literal], Maybe Span)
parseAttributeArguments = do
  open <- matchSymbol "("
  case open of
    Nothing -> pure ([], Nothing)
    Just token -> do
      (arguments, ending) <- parseAttributeArgumentList [] (tokenSpan token) False
      pure (arguments, Just ending)

parseAttributeArgumentList :: [Located Literal] -> Span -> Bool -> Parser ([Located Literal], Span)
parseAttributeArgumentList reversed ending recovering = do
  kind <- peekKind
  exhausted <- budgetExhausted
  before <- peekToken
  if exhausted
    then pure (reverse reversed, ending)
    else if argumentBoundary kind
      then do
        if recovering then pure () else do
          _ <- expectSymbol ")" "to close the attribute arguments"
          pure ()
        pure (reverse reversed, ending)
    else case kind of
      Symbol SymRightParen -> do
        closing <- advanceToken
        pure (reverse reversed, tokenSpan closing)
      _ -> case argumentOf kind of
        Just build -> do
          _ <- advanceToken
          following <- peekKind
          if isSymbol "," following || isSymbol ")" following || argumentBoundary following
            then continue (Located (tokenSpan before) build : reversed) (tokenSpan before) False
            else invalidArgument before reversed
        Nothing -> invalidArgument before reversed
 where
  continue collected ending' recovering' = do
    comma <- matchSymbol ","
    case comma of
      Just token -> parseAttributeArgumentList collected (tokenSpan token) recovering'
      Nothing -> parseAttributeArgumentList collected ending' recovering'
  invalidArgument before collected = do
    emitParseError "E1067" (tokenSpan before) "expected a literal attribute argument"
      (Just "arguments are integers, decimals, strings, chars, true, false, or null")
    ending' <- skipAttributeArgument [] (tokenSpan before)
    comma <- matchSymbol ","
    case comma of
      Just token -> parseAttributeArgumentList collected (tokenSpan token) True
      Nothing -> do
        closing <- matchSymbol ")"
        pure (reverse collected, maybe ending' tokenSpan closing)
  argumentOf argumentKind = case argumentKind of
    IntegerLiteral value -> Just (IntegerValue value)
    FloatLiteral value -> Just (FloatValue value)
    DecimalLiteral value -> Just (DecimalValue value)
    StringLiteral value -> Just (StringValue value)
    CharLiteral value -> Just (CharValue value)
    Keyword KwTrue -> Just (BoolValue True)
    Keyword KwFalse -> Just (BoolValue False)
    Keyword KwNull -> Just NullValue
    _ -> Nothing

argumentBoundary :: TokenKind -> Bool
argumentBoundary kind = kind == EndOfFile || isDeclarationStart kind
  || isSymbol "}" kind || isSymbol "]" kind

{-| Consume one malformed argument, retaining nested commas and stopping before
    the following declaration or enclosing delimiter. Each token is visited once. -}
skipAttributeArgument :: [SymbolKind] -> Span -> Parser Span
skipAttributeArgument closers ending = do
  kind <- peekKind
  token <- peekToken
  newLine <- peekStartsLine
  exhausted <- budgetExhausted
  if exhausted || kind == EndOfFile || isDeclarationStart kind
      || (null closers && ((newLine && tokenSpan token /= ending) || argumentBoundary kind
          || isSymbol "," kind || isSymbol ")" kind))
    then pure ending
    else do
      consumed <- advanceToken
      let next = case kind of
            Symbol SymLeftParen -> SymRightParen : closers
            Symbol SymLeftBracket -> SymRightBracket : closers
            Symbol SymLeftBrace -> SymRightBrace : closers
            Symbol closer | closer `elem` [SymRightParen, SymRightBracket, SymRightBrace] ->
              case closers of
                expected : rest | closer == expected -> rest
                _ -> closers
            _ -> closers
      skipAttributeArgument next (tokenSpan consumed)

{-| Parse `derives Trait, ...` after a type definition. Returns the entries
    with the clause span, or nothing when no clause follows. A missing entry
    is `E1065`; naming a trait twice is `E1066`. -}
parseDerivesClause :: Parser (Maybe (Span, [Located TypeSyntax]))
parseDerivesClause = do
  keyword <- peekToken
  matched <- matchDeriveWord "derives"
  if not matched
    then pure Nothing
    else do
      entries <- parseDerivesList keyword Set.empty []
      let endSpan = case reverse entries of
            [] -> tokenSpan keyword
            final : _ -> locatedSpan final
      pure (Just (mergedOrLeft (tokenSpan keyword) endSpan, entries))

parseDerivesList :: Token -> Set DeriveKey -> [Located TypeSyntax] -> Parser [Located TypeSyntax]
parseDerivesList keyword seen reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  before <- peekToken
  -- A clause left empty at the end of its line is reported at `derives`;
  -- the next line's declaration is not the mistake.
  detached <- peekStartsLine
  let missingEntry = missingEntryAt (if detached || kind == EndOfFile then keyword else before)
  if exhausted
    then pure (reverse reversed)
    else if kind == EndOfFile
      then do
        case reversed of
          [] -> missingEntry
          _ -> pure ()
        pure (reverse reversed)
      else if not (isTraitStart kind)
        then
          if null reversed
            then missingEntry >> pure []
            else pure (reverse reversed)
        else do
          entry <- parseTypeSyntax
          let collected = entry : reversed
          let key = deriveKey (locatedValue entry)
          if Set.member key seen
            then emitParseError "E1066" (locatedSpan entry) "a type may name a derive once"
              (Just "remove the repeated entry")
            else pure ()
          after <- peekToken
          if before == after
            then pure (reverse collected)
            else do
              comma <- matchSymbol ","
              case comma of
                Nothing -> pure (reverse collected)
                Just _ -> parseDerivesList keyword (Set.insert key seen) collected

missingEntryAt :: Token -> Parser ()
missingEntryAt anchor =
  emitParseError "E1065" (tokenSpan anchor) "expected a trait name in the derives clause"
    (Just "name one trait per entry, separated by commas")

data DeriveKey
  = NamedKey !ModuleName ![DeriveKey]
  | DynamicKey !ModuleName
  | ReferenceKey !Bool !DeriveKey
  | TupleKey ![DeriveKey]
  | FunctionKey !Bool ![DeriveKey] !DeriveKey
  | UnsafeKey ![Capability] !DeriveKey
  | UnitKey
  | InvalidKey
  deriving stock (Eq, Ord)

deriveKey :: TypeSyntax -> DeriveKey
deriveKey syntax = case syntax of
  NamedType path arguments -> NamedKey path (map recurse arguments)
  DynamicType path -> DynamicKey path
  ReferenceType mutable target -> ReferenceKey mutable (recurse target)
  TupleType members -> TupleKey (map recurse members)
  FunctionType asynchronous inputs result ->
    FunctionKey asynchronous (map recurse inputs) (recurse result)
  UnsafeType capabilities target -> UnsafeKey (map locatedValue capabilities) (recurse target)
  UnitType -> UnitKey
  InvalidType -> InvalidKey
 where
  recurse = deriveKey . locatedValue

{-| Parse `derive Trait for Param: Shape { ... }` or `derive impl Trait for
    Target`. `impl` is only special directly after `derive`; everywhere else
    the keyword keeps the meaning it already had. -}
parseDeriveDeclaration :: Visibility -> Parser (Located Declaration)
parseDeriveDeclaration visibility = do
  start <- advanceToken
  kind <- peekKind
  case kind of
    Keyword KwImpl -> parseDeriveRequest (tokenSpan start)
    _ -> parseDeriveDefinition (tokenSpan start) visibility

parseDeriveRequest :: Span -> Parser (Located Declaration)
parseDeriveRequest start = do
  _ <- expectKeyword KwImpl "after derive to request an impl"
  trait <- parseTypeSyntax
  _ <- expectKeyword KwFor "between the trait and its target"
  target <- parseTypeSyntax
  pure
    ( Located (mergedOrLeft start (locatedSpan target))
        (DeriveImplDeclaration (DeriveRequest trait target))
    )

parseDeriveDefinition :: Span -> Visibility -> Parser (Located Declaration)
parseDeriveDefinition start visibility = do
  trait <- parseTypeSyntax
  _ <- expectKeyword KwFor "between the trait and the derived type"
  parameter <- expectIdentifier "for the derived type parameter"
  _ <- expectSymbol ":" "before the derive shape"
  shape <- parseDeriveShape
  _ <- expectSymbol "{" "to open the derive body"
  functions <- parseMembers True []
  closing <- expectSymbol "}" "to close the derive body"
  pure
    ( Located (mergedOrLeft start (tokenSpan closing))
        ( DeriveDeclaration
            Derive
              { deriveVisibility = visibility
              , deriveTrait = trait
              , deriveParameter = parameter
              , deriveShape = shape
              , deriveFunctions = functions
              }
        )
    )

parseDeriveShape :: Parser (Located DeriveShape)
parseDeriveShape = do
  token <- peekToken
  case tokenKind token of
    Identifier name | name == "Record" -> advanceToken >> pure (Located (tokenSpan token) RecordShape)
    Identifier name | name == "Sum" -> advanceToken >> pure (Located (tokenSpan token) SumShape)
    _ -> do
      emitParseError "E1068" (tokenSpan token) "expected Record or Sum after :"
        (Just "a derive accepts one kind of type")
      _ <- advanceToken
      pure (Located (tokenSpan token) RecordShape)

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
