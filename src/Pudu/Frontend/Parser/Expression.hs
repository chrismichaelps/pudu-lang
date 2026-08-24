{-| @Program.Parser.Expression — applies explicit expression precedence -}
module Pudu.Frontend.Parser.Expression
  ( BlockParser
  , parseExpression
  , parseExpressionAt
  , parseScrutinee
  ) where

import Data.Char (isUpper)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Parser.Name (parseModuleName)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , currentSpan
  , emitParseError
  , expectIdentifier
  , expectSymbol
  , isSymbol
  , lookaheadKind
  , matchKeyword
  , matchSymbol
  , budgetExhausted
  , expectKeyword
  , peekKind
  , peekStartsLine
  , recordsAdmitted
  , withRecordAdmission
  , lookaheadKind
  , peekToken
  , withRecursionBudget
  )
import Pudu.Frontend.Parser.Name (expectValueIdentifier)
import Pudu.Frontend.Parser.Pattern (parsePattern)
import Pudu.Frontend.Parser.Type (parseTypeSyntax)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block
  , Capability (..)
  , Expression (..)
  , FieldInit (..)
  , Function (..)
  , FunctionBody (..)
  , Literal (..)
  , MatchArm (..)
  , Parameter (..)
  , TypeSyntax
  , Visibility (Private)
  , lambdaName
  )
import Pudu.Frontend.Token
  ( Keyword (KwAsync, KwAwait, KwCase, KwElse, KwEnum, KwFalse, KwFn, KwFor, KwIf, KwIn, KwLoop
    , KwMatch, KwModule, KwMut, KwNull, KwSpawn, KwStruct, KwScope, KwTask, KwTrue, KwUnsafe, KwWhile, KwWith)
  , SymbolKind (..)
  , Token (..)
  , TokenKind (..)
  , symbolText
  )
import Pudu.Source (Span, mergeSpans)

type BlockParser = Parser (Located Block)

parseExpression :: BlockParser -> Parser (Located Expression)
parseExpression blockParser = parseExpressionAt blockParser 0

{-| Parse the expression that precedes a block: an `if` or `while` condition, a
    `match` scrutinee, or a `for` iterable. A record construction is not
    admitted here, because `if READY { ... }` would otherwise be ambiguous with
    the block that follows. Parentheses reinstate it. -}
parseScrutinee :: BlockParser -> Parser (Located Expression)
parseScrutinee blockParser = withoutRecords (parseExpressionAt blockParser 0)

{-| Records are admitted again inside any bracketed context, so an argument, an
    index, or a parenthesized expression may construct one. -}
withRecords :: Parser a -> Parser a
withRecords = withRecordAdmission True

withoutRecords :: Parser a -> Parser a
withoutRecords = withRecordAdmission False

parseExpressionAt :: BlockParser -> Int -> Parser (Located Expression)
parseExpressionAt blockParser minimumPrecedence = do
  bounded <- withRecursionBudget $ do
    prefix <- parsePrefix blockParser
    postfixed <- parsePostfix blockParser prefix
    parseBinaryTail blockParser minimumPrecedence postfixed
  maybe invalidAtCurrent pure bounded

parsePrefix :: BlockParser -> Parser (Located Expression)
parsePrefix blockParser = do
  token <- peekToken
  following <- lookaheadKind 1
  let nextIsFunction = following == Keyword KwFn
  case tokenKind token of
    IntegerLiteral value -> literal token (IntegerValue value)
    FloatLiteral value -> literal token (FloatValue value)
    StringLiteral value -> literal token (StringValue value)
    CharLiteral value -> literal token (CharValue value)
    Keyword KwTrue -> literal token (BoolValue True)
    Keyword KwFalse -> literal token (BoolValue False)
    Keyword KwNull -> literal token NullValue
    Keyword KwIf -> parseIf blockParser
    Keyword KwMatch -> parseMatch blockParser
    Keyword KwWhile -> parseWhile blockParser
    Keyword KwUnsafe -> parseUnsafeBlock blockParser
    Keyword KwFn -> parseLambda blockParser
    Keyword KwAsync
      | nextIsFunction -> parseLambda blockParser
      | otherwise -> parseScope blockParser
    Keyword KwLoop -> parseLoop blockParser
    Keyword KwFor -> parseFor blockParser
    Identifier name -> parseNameOrRecord blockParser token name
    Symbol symbol
      | symbol == SymLeftParen -> withRecords (parseGrouped blockParser)
      | symbol == SymLeftBrace -> blockExpression blockParser
      | symbol == SymLeftBracket -> parseArrayLiteral blockParser
      | symbol `elem` unaryOperators -> parseUnary blockParser token symbol
    Keyword keyword | Just guidance <- reservedKeywordGuidance keyword ->
      reservedPrefix token guidance
    _ -> invalidPrefix token

{-| Parse a function literal: `fn(x) => x + 1` or `fn(x: Int) -> Int { ... }`.

    The `fn` keyword is reused rather than a new sigil introduced, because the
    function *type* is already written `fn(A) -> T` and a literal that spells
    itself the same way needs nothing explained. It cannot be ambiguous: `fn`
    could not previously begin an expression at all.

    Both bodies are admitted for the same reason a declaration admits both. `=>`
    reads as "answers with", matching its meaning in a match arm, and the block
    form is there when the answer takes more than one step.

    A literal's parameters take no defaults. A default is part of a named
    function's documented interface, and a literal has no name to document; a
    caller looking at a value of type `fn(Int) -> Int` has nowhere to learn that
    one of its arguments was optional. -}
parseLambda :: BlockParser -> Parser (Located Expression)
parseLambda blockParser = do
  start <- peekToken
  asyncKeyword <- matchKeyword KwAsync
  _ <- expectKeyword KwFn "to start a function literal"
  _ <- expectSymbol "(" "before the parameter list"
  parameters <- parseLambdaParameters []
  _ <- expectSymbol ")" "after the parameter list"
  returnType <- parseLambdaReturn
  body <- parseLambdaBody blockParser
  let endSpan = maybe (tokenSpan start) locatedSpan body
  pure
    ( Located (mergedOrLeft (tokenSpan start) endSpan)
        ( LambdaExpression
            Function
              { functionVisibility = Private
              , functionAsync = maybe False (const True) asyncKeyword
              , functionUnsafe = Nothing
              , functionComptime = False
              , functionName = Located (tokenSpan start) lambdaName
              , functionTypeParams = []
              , functionParameters = parameters
              , functionReturn = returnType
              , functionConstraints = []
              , functionBody = body
              }
        )
    )

{-| A literal's parameters: a name and an optional type, separated by commas. -}
parseLambdaParameters :: [Located Parameter] -> Parser [Located Parameter]
parseLambdaParameters reversed = do
  closing <- isSymbol ")" <$> peekKind
  if closing
    then pure (reverse reversed)
    else do
      name <- expectValueIdentifier "in the parameter list"
      annotation <- parseLambdaAnnotation
      let parameter =
            Located (locatedSpan name)
              Parameter
                { parameterName = name
                , parameterType = annotation
                , parameterDefault = Nothing
                }
          extended = parameter : reversed
      separator <- matchSymbol ","
      case separator of
        Just _ -> parseLambdaParameters extended
        Nothing -> pure (reverse extended)

parseLambdaAnnotation :: Parser (Maybe (Located TypeSyntax))
parseLambdaAnnotation = do
  colon <- matchSymbol ":"
  case colon of
    Nothing -> pure Nothing
    Just _ -> Just <$> parseTypeSyntax

parseLambdaReturn :: Parser (Maybe (Located TypeSyntax))
parseLambdaReturn = do
  arrow <- matchSymbol "->"
  case arrow of
    Nothing -> pure Nothing
    Just _ -> Just <$> parseTypeSyntax

{-| `=>` answers with one expression; `{` opens a block. Anything else is an
    incomplete literal, and saying which two forms exist is more useful than
    naming the token that was found. -}
parseLambdaBody :: BlockParser -> Parser (Maybe (Located FunctionBody))
parseLambdaBody blockParser = do
  arrow <- matchSymbol "=>"
  case arrow of
    Just _ -> do
      value <- parseExpression blockParser
      pure (Just (Located (locatedSpan value) (ExpressionBody value)))
    Nothing -> do
      opening <- isSymbol "{" <$> peekKind
      if opening
        then do
          block <- blockParser
          pure (Just (Located (locatedSpan block) (BlockBody block)))
        else do
          token <- peekToken
          emitParseError "E1032" (tokenSpan token)
            "expected a function literal's body"
            (Just "follow the parameter list with => and one expression, or a block")
          pure Nothing

{-| Parse `async with scope { ... }`, the structured task scope.

    Every child a scope starts is joined before the scope's value is produced,
    so no task outlives the region that started it. The keywords are spelled out
    because the construct is a promise about lifetime, not a modifier. -}
parseScope :: BlockParser -> Parser (Located Expression)
parseScope blockParser = do
  keyword <- advanceToken
  _ <- expectKeyword KwWith "after async to open a structured scope"
  _ <- expectKeyword KwScope "after with to open a structured scope"
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (ScopeExpression body)
    )

{-| Parse `unsafe { ... }` or `unsafe(raw, null) { ... }`.

    A capability list names exactly which unchecked abilities the block grants;
    an empty list grants all of them. Naming them is what makes an unsafe region
    auditable: the reader sees which invariant is in play without reading the
    body. -}
parseUnsafeBlock :: BlockParser -> Parser (Located Expression)
parseUnsafeBlock blockParser = do
  keyword <- advanceToken
  capabilities <- parseCapabilityAnnotation
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (UnsafeExpression capabilities body)
    )

parseCapabilityAnnotation :: Parser [Located Capability]
parseCapabilityAnnotation = do
  opening <- matchSymbol "("
  case opening of
    Nothing -> pure []
    Just _ -> do
      capabilities <- capabilityList []
      _ <- expectSymbol ")" "to close the capability list"
      pure capabilities

capabilityList :: [Located Capability] -> Parser [Located Capability]
capabilityList reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol ")" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      capability <- oneCapability
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          let collected = maybe reversed (: reversed) capability
          case comma of
            Nothing -> pure (reverse collected)
            Just _ -> capabilityList collected

oneCapability :: Parser (Maybe (Located Capability))
oneCapability = do
  token <- advanceToken
  case capabilityFor (tokenKind token) of
    Just capability -> pure (Just (Located (tokenSpan token) capability))
    Nothing -> do
      emitParseError "E1044" (tokenSpan token) "unknown unsafe capability"
        (Just "name one of raw, foreign, unchecked, or null")
      pure Nothing

capabilityFor :: TokenKind -> Maybe Capability
capabilityFor kind = case kind of
  Identifier "raw" -> Just RawCapability
  Identifier "foreign" -> Just ForeignCapability
  Identifier "unchecked" -> Just UncheckedCapability
  Keyword KwNull -> Just NullCapability
  _ -> Nothing

{-| An uppercase name directly followed by `{` builds a record, when records are
    admitted here; every other name is a plain reference. -}
parseNameOrRecord :: BlockParser -> Token -> Text -> Parser (Located Expression)
parseNameOrRecord blockParser token name
  | not (startsUpper name) = do
      macroCall <- macroFollows
      if macroCall then parseMacroCall blockParser token name else plainName
  | otherwise = do
      admitted <- recordsAdmitted
      opensRecord <- recordFollows
      if admitted && opensRecord
        then parseRecordExpression blockParser
        else plainName
 where
  plainName = advanceToken >> pure (Located (tokenSpan token) (NameExpression (name :| [])))

{-| A record construction may be introduced by a qualified path, so the scan
    walks `Name.Name` segments before deciding whether a `{` follows. The walk
    is bounded by the path length the name grammar admits. -}
recordFollows :: Parser Bool
recordFollows = walk 1 (0 :: Int)
 where
  walk offset segments
    | segments > 64 = pure False
    | otherwise = do
        following <- lookaheadKind offset
        if isSymbol "." following
          then do
            segment <- lookaheadKind (offset + 1)
            case segment of
              Identifier _ -> walk (offset + 2) (segments + 1)
              _ -> pure False
          else pure (isSymbol "{" following)

{-| A macro call is written `name!(...)`, so expansion is visible at the call
    rather than depending on knowing which names are macros. -}
macroFollows :: Parser Bool
macroFollows = do
  bang <- lookaheadKind 1
  opening <- lookaheadKind 2
  pure (isSymbol "!" bang && isSymbol "(" opening)

parseMacroCall :: BlockParser -> Token -> Text -> Parser (Located Expression)
parseMacroCall blockParser token name = do
  _ <- advanceToken
  _ <- advanceToken
  _ <- expectSymbol "(" "before the macro arguments"
  arguments <- parseMacroArguments blockParser []
  closing <- expectSymbol ")" "to close the macro arguments"
  pure
    ( Located (mergedOrLeft (tokenSpan token) (tokenSpan closing))
        (MacroCall (Located (tokenSpan token) name) arguments)
    )

parseMacroArguments :: BlockParser -> [Located Expression] -> Parser [Located Expression]
parseMacroArguments blockParser reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol ")" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      argument <- withRecords (parseArgumentSyntax blockParser)
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse (argument : reversed))
            Just _ -> parseMacroArguments blockParser (argument : reversed)

{-| A macro argument may be a block, which an ordinary expression position would
    read as a record or a nested scope; parsing it here keeps `block` parameters
    writable as `{ ... }`. -}
parseArgumentSyntax :: BlockParser -> Parser (Located Expression)
parseArgumentSyntax blockParser = do
  kind <- peekKind
  if isSymbol "{" kind
    then blockExpression blockParser
    else parseExpression blockParser

startsUpper :: Text -> Bool
startsUpper value = maybe False (isUpper . fst) (Text.uncons value)

parseRecordExpression :: BlockParser -> Parser (Located Expression)
parseRecordExpression blockParser = do
  path <- parseModuleName
  _ <- expectSymbol "{" "to start the record fields"
  fields <- withRecords (parseFieldInits blockParser [])
  closing <- expectSymbol "}" "to close the record fields"
  pure
    ( Located (mergedOrLeft (locatedSpan path) (tokenSpan closing))
        (RecordExpression (locatedValue path) fields)
    )

parseFieldInits :: BlockParser -> [Located FieldInit] -> Parser [Located FieldInit]
parseFieldInits blockParser reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol "}" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      field <- parseFieldInit blockParser
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse (field : reversed))
            Just _ -> parseFieldInits blockParser (field : reversed)

{-| A field written without `:` takes the binding with its own name, mirroring
    the record pattern's shorthand. -}
parseFieldInit :: BlockParser -> Parser (Located FieldInit)
parseFieldInit blockParser = do
  name <- expectIdentifier "for the record field"
  colon <- matchSymbol ":"
  value <- case colon of
    Nothing -> pure Nothing
    Just _ -> Just <$> parseExpression blockParser
  pure
    ( Located (maybe (locatedSpan name) (mergedOrLeft (locatedSpan name) . locatedSpan) value)
        FieldInit{fieldInitName = name, fieldInitValue = value}
    )

literal :: Token -> Literal -> Parser (Located Expression)
literal token value = do
  _ <- advanceToken
  pure (Located (tokenSpan token) (LiteralExpression value))

blockExpression :: BlockParser -> Parser (Located Expression)
blockExpression blockParser = do
  block <- blockParser
  pure (Located (locatedSpan block) (BlockExpression block))

{-| Parentheses group one expression; a comma makes the same syntax a tuple,
    matching the type grammar's `(T)` and `(T, U)` rule. -}
parseGrouped :: BlockParser -> Parser (Located Expression)
parseGrouped blockParser = do
  opening <- expectSymbol "(" "to start the grouped expression"
  empty <- matchSymbol ")"
  case empty of
    Just closing ->
      pure
        ( Located (mergedOrLeft (tokenSpan opening) (tokenSpan closing))
            (TupleExpression [])
        )
    Nothing -> do
      first <- parseExpression blockParser
      comma <- matchSymbol ","
      case comma of
        Nothing -> do
          closing <- expectSymbol ")" "to close the grouped expression"
          pure first{locatedSpan = mergedOrLeft (tokenSpan opening) (tokenSpan closing)}
        Just _ -> do
          rest <- parseTupleTail blockParser []
          closing <- expectSymbol ")" "to close the tuple expression"
          pure
            ( Located (mergedOrLeft (tokenSpan opening) (tokenSpan closing))
                (TupleExpression (first : rest))
            )

parseTupleTail :: BlockParser -> [Located Expression] -> Parser [Located Expression]
parseTupleTail blockParser reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol ")" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      next <- parseExpression blockParser
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse (next : reversed))
            Just _ -> parseTupleTail blockParser (next : reversed)

{-| An array literal `[a, b, c]` admits expressions separated by commas with an
    optional trailing comma. `[]` is the empty array. Records are admitted inside
    the bracketed context so `Some{value: 1}` works as an element. -}
parseArrayLiteral :: BlockParser -> Parser (Located Expression)
parseArrayLiteral blockParser = do
  opening <- expectSymbol "[" "to start the array literal"
  empty <- matchSymbol "]"
  case empty of
    Just closing ->
      pure
        ( Located (mergedOrLeft (tokenSpan opening) (tokenSpan closing))
            (ArrayExpression [])
        )
    Nothing -> do
      first <- withRecords (parseExpression blockParser)
      rest <- parseArrayTail blockParser []
      closing <- expectSymbol "]" "to close the array literal"
      pure
        ( Located (mergedOrLeft (tokenSpan opening) (tokenSpan closing))
            (ArrayExpression (first : rest))
        )

parseArrayTail :: BlockParser -> [Located Expression] -> Parser [Located Expression]
parseArrayTail blockParser reversed = do
  comma <- matchSymbol ","
  case comma of
    Nothing -> pure (reverse reversed)
    Just _ -> do
      kind <- peekKind
      if isSymbol "]" kind
        then pure (reverse reversed)
        else do
          bounded <- withRecursionBudget $ do
            before <- peekToken
            next <- withRecords (parseExpression blockParser)
            after <- peekToken
            if before == after
              then pure (reverse reversed, True)
              else do
                rest <- parseArrayTail blockParser (next : reversed)
                pure (rest, False)
          pure (maybe (reverse reversed) fst bounded)

parseUnary :: BlockParser -> Token -> SymbolKind -> Parser (Located Expression)
parseUnary blockParser operatorToken operator = do
  _ <- advanceToken
  rendered <- if operator == SymAmpersand
    then maybe "&" (const "&mut") <$> matchKeyword KwMut
    else pure (symbolText operator)
  operand <- parseExpressionAt blockParser 8
  pure (Located (mergedOrLeft (tokenSpan operatorToken) (locatedSpan operand))
    (UnaryExpression rendered operand))

parseIf :: BlockParser -> Parser (Located Expression)
parseIf blockParser = do
  keyword <- advanceToken
  condition <- parseScrutinee blockParser
  case locatedValue condition of
    InvalidExpression ->
      pure (Located (mergedOrLeft (tokenSpan keyword) (locatedSpan condition)) InvalidExpression)
    _ -> do
      thenBlock <- blockParser
      elseExpression <- parseElse blockParser
      let final = maybe (locatedSpan thenBlock) locatedSpan elseExpression
      pure (Located (mergedOrLeft (tokenSpan keyword) final)
        (IfExpression condition thenBlock elseExpression))

parseElse :: BlockParser -> Parser (Maybe (Located Expression))
parseElse blockParser = do
  elseKeyword <- matchKeyword KwElse
  case elseKeyword of
    Nothing -> pure Nothing
    Just _ -> do
      kind <- peekKind
      case kind of
        Keyword KwIf -> Just <$> parseExpressionAt blockParser 0
        _ | isSymbol "{" kind -> Just <$> blockExpression blockParser
        _ -> do
          spanValue <- currentSpan
          emitParseError "E1042" spanValue "expected if or block after else"
            (Just "add if or a block after else")
          pure (Just (Located spanValue InvalidExpression))

{-| Postfix continuation is line-sensitive per [[grammar/pudu]]: a line-initial
    `(` or `[` starts a new statement, while a line-initial `.`, `?`, or
    `.await` continues a fluent chain. -}
{-| `match` scrutinizes one expression and requires at least one `case` arm.
    Arms are separated by line breaks like every other construct. -}
parseMatch :: BlockParser -> Parser (Located Expression)
parseMatch blockParser = do
  keyword <- advanceToken
  scrutinee <- parseScrutinee blockParser
  _ <- expectSymbol "{" "to start the match arms"
  arms <- parseArms blockParser []
  closing <- expectSymbol "}" "to close the match arms"
  case arms of
    [] ->
      emitParseError "E1051" (tokenSpan closing) "match requires at least one case arm"
        (Just "add a case arm, or replace the match with an if expression")
    _ -> pure ()
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (tokenSpan closing))
        (MatchExpression scrutinee arms)
    )

parseArms :: BlockParser -> [Located MatchArm] -> Parser [Located MatchArm]
parseArms blockParser reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol "}" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      arm <- parseArm blockParser
      after <- peekToken
      if before == after
        then advanceToken >> pure (reverse reversed)
        else parseArms blockParser (arm : reversed)

parseArm :: BlockParser -> Parser (Located MatchArm)
parseArm blockParser = do
  keyword <- expectKeyword KwCase "to start a match arm"
  pattern' <- parsePattern
  guard <- parseGuard blockParser
  _ <- expectSymbol "=>" "before the arm body"
  body <- parseArmBody blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        MatchArm{armPattern = pattern', armGuard = guard, armBody = body}
    )

parseGuard :: BlockParser -> Parser (Maybe (Located Expression))
parseGuard blockParser = do
  guardKeyword <- matchKeyword KwIf
  case guardKeyword of
    Nothing -> pure Nothing
    Just _ -> Just <$> parseExpression blockParser

parseArmBody :: BlockParser -> Parser (Located Expression)
parseArmBody blockParser = do
  kind <- peekKind
  if isSymbol "{" kind
    then blockExpression blockParser
    else parseExpression blockParser

{-| `while`, `loop`, and `for` are expressions whose bodies are blocks; their
    value is `()` in this slice, which typing — not parsing — enforces. -}
parseWhile :: BlockParser -> Parser (Located Expression)
parseWhile blockParser = do
  keyword <- advanceToken
  condition <- parseScrutinee blockParser
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (WhileExpression condition body)
    )

parseLoop :: BlockParser -> Parser (Located Expression)
parseLoop blockParser = do
  keyword <- advanceToken
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (LoopExpression body)
    )

parseFor :: BlockParser -> Parser (Located Expression)
parseFor blockParser = do
  keyword <- advanceToken
  binder <- parsePattern
  _ <- expectKeyword KwIn "between the pattern and the iterated expression"
  iterated <- parseScrutinee blockParser
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (ForExpression binder iterated body)
    )

parsePostfix :: BlockParser -> Located Expression -> Parser (Located Expression)
parsePostfix blockParser expression = do
  kind <- peekKind
  newLine <- peekStartsLine
  await <- isAwaitPostfix kind
  let lineBreaks = newLine && (isSymbol "(" kind || isSymbol "[" kind)
  if (isPostfixStart kind || await) && not lineBreaks
    then do
      bounded <- withRecursionBudget (parsePostfixStep blockParser expression kind await)
      pure (maybe expression id bounded)
    else pure expression

isAwaitPostfix :: TokenKind -> Parser Bool
isAwaitPostfix kind
  | isSymbol "." kind = (== Keyword KwAwait) <$> lookaheadKind 1
  | otherwise = pure False

{-| Postfix forms bind tighter than every unary and binary operator: call,
    member, index, `?` failure propagation, and `.await`. -}
parsePostfixStep :: BlockParser -> Located Expression -> TokenKind -> Bool -> Parser (Located Expression)
parsePostfixStep blockParser expression kind await
  | await = do
      _ <- advanceToken
      keyword <- advanceToken
      let awaited = Located (mergedOrLeft (locatedSpan expression) (tokenSpan keyword))
            (AwaitExpression expression)
      parsePostfix blockParser awaited
  | isSymbol "?" kind = do
      question <- advanceToken
      let tried = Located (mergedOrLeft (locatedSpan expression) (tokenSpan question))
            (TryExpression expression)
      parsePostfix blockParser tried
  | isSymbol "[" kind = do
      _ <- advanceToken
      index <- withRecords (parseExpression blockParser)
      closing <- expectSymbol "]" "to close the index expression"
      let indexed = Located (mergedOrLeft (locatedSpan expression) (tokenSpan closing))
            (IndexExpression expression index)
      parsePostfix blockParser indexed
  | isSymbol "(" kind = do
      _ <- advanceToken
      (arguments, closing) <- parseArguments blockParser
      case closing of
        Just closingToken -> do
          let call = Located (mergedOrLeft (locatedSpan expression) (tokenSpan closingToken))
                (CallExpression expression arguments)
          parsePostfix blockParser call
        Nothing -> pure (Located (callRecoverySpan expression arguments) InvalidExpression)
  | otherwise = do
      _ <- advanceToken
      member <- expectIdentifier "after ."
      let selection = Located (mergedOrLeft (locatedSpan expression) (locatedSpan member))
            (MemberExpression expression member)
      parsePostfix blockParser selection

isPostfixStart :: TokenKind -> Bool
isPostfixStart kind =
  isSymbol "(" kind || isSymbol "." kind || isSymbol "[" kind || isSymbol "?" kind

parseArguments :: BlockParser -> Parser ([Located Expression], Maybe Token)
parseArguments blockParser = do
  kind <- peekKind
  if isSymbol ")" kind then advanceToken >>= \closing -> pure ([], Just closing)
    else withRecords (parseExpression blockParser) >>= \first -> parseArgumentTail blockParser [first]

parseArgumentTail :: BlockParser -> [Located Expression] -> Parser ([Located Expression], Maybe Token)
parseArgumentTail blockParser reversed = do
  comma <- matchSymbol ","
  case comma of
    Nothing -> do
      closing <- expectSymbol ")" "to close the function arguments"
      pure (reverse reversed, Just closing)
    Just _ -> do
      kind <- peekKind
      if isSymbol ")" kind
        then advanceToken >>= \closing -> pure (reverse reversed, Just closing)
        else do
          bounded <- withRecursionBudget $ do
            before <- peekToken
            next <- withRecords (parseExpression blockParser)
            after <- peekToken
            if before == after
              then pure (reverse reversed, Nothing)
              else parseArgumentTail blockParser (next : reversed)
          pure (maybe (reverse reversed, Nothing) id bounded)

callRecoverySpan :: Located Expression -> [Located Expression] -> Span
callRecoverySpan expression = foldl' mergedOrLeft (locatedSpan expression) . map locatedSpan

parseBinaryTail :: BlockParser -> Int -> Located Expression -> Parser (Located Expression)
parseBinaryTail blockParser minimumPrecedence left = do
  kind <- peekKind
  newLine <- peekStartsLine
  case binaryInfo kind of
    Just (operator, precedence, rightAssociative)
      | precedence >= minimumPrecedence
      , not newLine -> do
      bounded <- withRecursionBudget $ do
        _ <- advanceToken
        let rightMinimum = if rightAssociative then precedence else precedence + 1
        right <- parseExpressionAt blockParser rightMinimum
        let combined = Located (mergedOrLeft (locatedSpan left) (locatedSpan right))
              (BinaryExpression left operator right)
        parseBinaryTail blockParser minimumPrecedence combined
      pure (maybe left id bounded)
    _ -> pure left

binaryInfo :: TokenKind -> Maybe (Text, Int, Bool)
binaryInfo kind = case kind of
  Symbol symbol -> operatorInfo symbol
  _ -> Nothing

operatorInfo :: SymbolKind -> Maybe (Text, Int, Bool)
operatorInfo symbol = case symbol of
  SymAssign -> binary 0 True
  SymLogicalOr -> binary 1 False
  SymPipe -> binary 1 False
  SymLogicalAnd -> binary 2 False
  SymEqual -> binary 3 False
  SymNotEqual -> binary 3 False
  SymLess -> binary 4 False
  SymLessEqual -> binary 4 False
  SymGreater -> binary 4 False
  SymGreaterEqual -> binary 4 False
  SymRangeExclusive -> binary 5 False
  SymRangeInclusive -> binary 5 False
  SymCaret -> binary 5 False
  SymLeftShift -> binary 6 False
  SymRightShift -> binary 6 False
  SymAmpersand -> binary 6 False
  SymPlus -> binary 7 False
  SymMinus -> binary 7 False
  SymWrapAdd -> binary 7 False
  SymWrapSubtract -> binary 7 False
  SymSaturatingAdd -> binary 7 False
  SymSaturatingSubtract -> binary 7 False
  SymStar -> binary 8 False
  SymSlash -> binary 8 False
  SymPercent -> binary 8 False
  SymWrapMultiply -> binary 8 False
  SymSaturatingMultiply -> binary 8 False
  _ -> Nothing
 where
  binary precedence rightAssociative = Just (symbolText symbol, precedence, rightAssociative)

invalidPrefix :: Token -> Parser (Located Expression)
invalidPrefix token = do
  emitParseError "E1040" (tokenSpan token) "expected expression"
    (Just "start with a literal, name, (, {, if, or unary operator")
  case tokenKind token of
    EndOfFile -> pure ()
    kind | isRecoveryBoundary kind -> pure ()
    _ -> advanceToken >> pure ()
  pure (Located (tokenSpan token) InvalidExpression)

{-| Reserved keywords that appear in expression position — typically because the
    REPL submits them as entries — produce a targeted diagnostic instead of the
    generic E1040. Each message points the reader toward the canonical form, so
    `enum`/`struct` point to `type`, `task`/`spawn` point to `async`/`scope`,
    `module` explains it is file-only, and `mut` points to `var`. -}
reservedKeywordGuidance :: Keyword -> Maybe Text
reservedKeywordGuidance keyword = case keyword of
  KwEnum -> Just "enum is reserved; use type for sum and record declarations"
  KwStruct -> Just "struct is reserved; use type for record declarations"
  KwTask -> Just "task is reserved; use async fn and scope for structured concurrency"
  KwSpawn -> Just "spawn is reserved; use async fn and scope for structured concurrency"
  KwModule -> Just "module declarations are only valid at the top of a file"
  KwMut -> Just "use var for mutable bindings; mut modifies references and fields"
  _ -> Nothing

reservedPrefix :: Token -> Text -> Parser (Located Expression)
reservedPrefix token guidance = do
  emitParseError "E1041" (tokenSpan token) "reserved keyword in expression position"
    (Just guidance)
  _ <- advanceToken
  skipToLineBoundary
  pure (Located (tokenSpan token) InvalidExpression)

{-| Consume the remaining tokens on the reserved keyword's line so a construct
    like `task my_task() -> Int { 42 }` reports one E1041 rather than a cascade
    of downstream parse errors. Recovery stops only at EOF or a line-initial
    token, never consuming the next line's first token. Closing delimiters and
    commas are skipped because they belong to the same line as the reserved
    keyword; stopping at them would leave trailing tokens that produce cascading
    errors. -}
skipToLineBoundary :: Parser ()
skipToLineBoundary = do
  kind <- peekKind
  case kind of
    EndOfFile -> pure ()
    _ -> do
      startsNewLine <- peekStartsLine
      if startsNewLine
        then pure ()
        else advanceToken >> skipToLineBoundary

invalidAtCurrent :: Parser (Located Expression)
invalidAtCurrent = currentSpan >>= \spanValue -> pure (Located spanValue InvalidExpression)

{-| Prefix position decides these: `&` and `*` are also binary operators, and
    the parser only consults this list where an operand is expected. -}
unaryOperators :: [SymbolKind]
unaryOperators = [SymBang, SymMinus, SymAmpersand, SymTilde, SymStar]

isRecoveryBoundary :: TokenKind -> Bool
isRecoveryBoundary kind = any (`isSymbol` kind) [",", ")", "]", "}"]

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
