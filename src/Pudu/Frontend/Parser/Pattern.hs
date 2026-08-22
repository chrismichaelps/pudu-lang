{-| @Program.Parser.Pattern — parses match and binding patterns -}
module Pudu.Frontend.Parser.Pattern
  ( parsePattern
  ) where

import Data.Char (isUpper)
import qualified Data.Text as Text
import Pudu.Frontend.Parser.Name (parseModuleName)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , budgetExhausted
  , currentSpan
  , emitParseError
  , expectIdentifier
  , expectSymbol
  , isSymbol
  , matchSymbol
  , peekKind
  , peekToken
  , withRecursionBudget
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Frontend.Syntax.Tree (FieldPattern (..), Literal (..), Pattern (..))
import Pudu.Frontend.Token
  ( Keyword (KwFalse, KwNull, KwTrue)
  , Token (..)
  , TokenKind (..)
  )
import Pudu.Source (Span, mergeSpans)

{-| Parse one pattern, including `|` alternation. Every recursive descent is
    charged to the shared budget so hostile nesting reports one `E1099`. -}
parsePattern :: Parser (Located Pattern)
parsePattern = do
  bounded <- withRecursionBudget $ do
    first <- parseAlternative
    parseAlternationTail first []
  case bounded of
    Just pattern' -> pure pattern'
    Nothing -> do
      spanValue <- currentSpan
      pure (Located spanValue InvalidPattern)

parseAlternationTail :: Located Pattern -> [Located Pattern] -> Parser (Located Pattern)
parseAlternationTail first reversed = do
  pipe <- matchSymbol "|"
  case pipe of
    Nothing -> pure (collectAlternatives first (reverse reversed))
    Just _ -> do
      before <- peekToken
      next <- parseAlternative
      after <- peekToken
      if before == after
        then pure (collectAlternatives first (reverse (next : reversed)))
        else parseAlternationTail first (next : reversed)

collectAlternatives :: Located Pattern -> [Located Pattern] -> Located Pattern
collectAlternatives first rest = case rest of
  [] -> first
  _ ->
    Located (foldl mergedOrLeft (locatedSpan first) (map locatedSpan rest))
      (AlternativePattern (first : rest))

{-| Dispatch on the closed set of pattern starts. `_` never binds, a lowercase
    identifier always binds, and an uppercase path is a constructor even with
    no payload. -}
parseAlternative :: Parser (Located Pattern)
parseAlternative = do
  token <- peekToken
  case tokenKind token of
    Identifier name
      | name == "_" -> advanceToken >> pure (Located (tokenSpan token) WildcardPattern)
      | startsUpper name -> parseConstructor
      | otherwise -> advanceToken >> pure (Located (tokenSpan token) (BindingPattern (Located (tokenSpan token) name)))
    IntegerLiteral value -> literalOrRange token (IntegerValue value)
    FloatLiteral value -> literalOrRange token (FloatValue value)
    StringLiteral value -> literal token (StringValue value)
    CharLiteral value -> literalOrRange token (CharValue value)
    Keyword KwTrue -> literal token (BoolValue True)
    Keyword KwFalse -> literal token (BoolValue False)
    Keyword KwNull -> literal token NullValue
    Symbol _
      | isSymbol "-" (tokenKind token) -> parseNegativeLiteral token
      | isSymbol "(" (tokenKind token) -> parseTuple
      | isSymbol "{" (tokenKind token) -> advanceToken >> parseRecord Nothing (tokenSpan token)
    _ -> invalidPattern token

startsUpper :: Text.Text -> Bool
startsUpper value = maybe False (isUpper . fst) (Text.uncons value)

literal :: Token -> Literal -> Parser (Located Pattern)
literal token value = do
  _ <- advanceToken
  pure (Located (tokenSpan token) (LiteralPattern value))

{-| A numeric pattern literal admits a leading `-`, which is preserved in the
    literal's own text rather than becoming a unary expression node. -}
parseNegativeLiteral :: Token -> Parser (Located Pattern)
parseNegativeLiteral minus = do
  _ <- advanceToken
  token <- peekToken
  case tokenKind token of
    IntegerLiteral value -> negated minus token (IntegerValue ("-" <> value))
    FloatLiteral value -> negated minus token (FloatValue ("-" <> value))
    _ -> invalidPattern token

negated :: Token -> Token -> Literal -> Parser (Located Pattern)
negated minus token value = do
  _ <- advanceToken
  let spanValue = mergedOrLeft (tokenSpan minus) (tokenSpan token)
  rangeTail spanValue value

literalOrRange :: Token -> Literal -> Parser (Located Pattern)
literalOrRange token value = do
  _ <- advanceToken
  rangeTail (tokenSpan token) value

{-| `..` and `..=` join two literals into one range pattern; anything else
    leaves the literal alone. -}
rangeTail :: Span -> Literal -> Parser (Located Pattern)
rangeTail startSpan value = do
  exclusive <- matchSymbol ".."
  inclusive <- case exclusive of
    Just _ -> pure Nothing
    Nothing -> matchSymbol "..="
  case (exclusive, inclusive) of
    (Nothing, Nothing) -> pure (Located startSpan (LiteralPattern value))
    _ -> do
      upperToken <- peekToken
      upper <- case tokenKind upperToken of
        IntegerLiteral text -> advanceToken >> pure (Just (IntegerValue text))
        FloatLiteral text -> advanceToken >> pure (Just (FloatValue text))
        CharLiteral character -> advanceToken >> pure (Just (CharValue character))
        _ | isSymbol "-" (tokenKind upperToken) -> negativeBound
        _ -> pure Nothing
      case upper of
        Nothing -> do
          emitParseError "E1050" (tokenSpan upperToken) "expected a literal range endpoint"
            (Just "end the range with an integer, float, or character literal")
          pure (Located startSpan (LiteralPattern value))
        Just bound ->
          pure
            ( Located (mergedOrLeft startSpan (tokenSpan upperToken))
                (RangePattern value (maybe False (const True) inclusive) bound)
            )

negativeBound :: Parser (Maybe Literal)
negativeBound = do
  _ <- advanceToken
  token <- peekToken
  case tokenKind token of
    IntegerLiteral value -> advanceToken >> pure (Just (IntegerValue ("-" <> value)))
    FloatLiteral value -> advanceToken >> pure (Just (FloatValue ("-" <> value)))
    _ -> pure Nothing

{-| An uppercase path is a constructor; `(` introduces positional payloads and
    `{` introduces a record payload. -}
parseConstructor :: Parser (Located Pattern)
parseConstructor = do
  path <- parseModuleName
  kind <- peekKind
  if isSymbol "(" kind
    then do
      _ <- advanceToken
      arguments <- parseSequence ")" []
      closing <- closeDelimiter ")" "to close the constructor pattern"
      pure
        ( Located (maybe (locatedSpan path) (mergedOrLeft (locatedSpan path) . tokenSpan) closing)
            (ConstructorPattern (locatedValue path) arguments)
        )
    else if isSymbol "{" kind
      then do
        _ <- advanceToken
        parseRecord (Just (locatedValue path)) (locatedSpan path)
      else pure (Located (locatedSpan path) (ConstructorPattern (locatedValue path) []))

parseTuple :: Parser (Located Pattern)
parseTuple = do
  opening <- advanceToken
  members <- parseSequence ")" []
  closing <- closeDelimiter ")" "to close the tuple pattern"
  let spanValue = maybe (tokenSpan opening) (mergedOrLeft (tokenSpan opening) . tokenSpan) closing
  case members of
    [single] -> pure single{locatedSpan = spanValue}
    _ -> pure (Located spanValue (TuplePattern members))

{-| Parse comma-separated patterns up to a closing delimiter, admitting one
    trailing comma and requiring progress on every element. -}
parseSequence :: Text.Text -> [Located Pattern] -> Parser [Located Pattern]
parseSequence closing reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol closing kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      element <- parsePattern
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse (element : reversed))
            Just _ -> parseSequence closing (element : reversed)

{-| A record pattern may end with `..` to ignore remaining fields; a field with
    no `:` binds the field to its own name. The opening `{` is consumed by the
    caller so a constructor and a bare record share one implementation. -}
parseRecord :: Maybe ModuleName -> Span -> Parser (Located Pattern)
parseRecord path startSpan = do
  (fields, rest) <- parseFields [] False
  closing <- closeDelimiter "}" "to close the record pattern"
  pure
    ( Located (maybe startSpan (mergedOrLeft startSpan . tokenSpan) closing)
        (RecordPattern path fields rest)
    )

{-| A latched budget stops delimiter expectations so one `E1099` never cascades
    into an unclosed-delimiter diagnostic per unwinding level. -}
closeDelimiter :: Text.Text -> Text.Text -> Parser (Maybe Token)
closeDelimiter closing context = do
  exhausted <- budgetExhausted
  if exhausted then pure Nothing else Just <$> expectSymbol closing context

parseFields :: [Located FieldPattern] -> Bool -> Parser ([Located FieldPattern], Bool)
parseFields reversed rest = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol "}" kind || kind == EndOfFile || exhausted || rest
    then pure (reverse reversed, rest)
    else do
      dots <- matchSymbol ".."
      case dots of
        Just _ -> do
          _ <- matchSymbol ","
          pure (reverse reversed, True)
        Nothing -> do
          before <- peekToken
          field <- parseField
          after <- peekToken
          if before == after
            then pure (reverse reversed, rest)
            else do
              comma <- matchSymbol ","
              case comma of
                Nothing -> pure (reverse (field : reversed), rest)
                Just _ -> parseFields (field : reversed) rest

parseField :: Parser (Located FieldPattern)
parseField = do
  name <- expectIdentifier "for the record field pattern"
  colon <- matchSymbol ":"
  value <- case colon of
    Nothing -> pure Nothing
    Just _ -> Just <$> parsePattern
  pure
    ( Located (maybe (locatedSpan name) (mergedOrLeft (locatedSpan name) . locatedSpan) value)
        FieldPattern{fieldPatternName = name, fieldPatternValue = value}
    )

invalidPattern :: Token -> Parser (Located Pattern)
invalidPattern token = do
  emitParseError "E1050" (tokenSpan token) "expected a pattern"
    (Just "use _, a name, a literal, a tuple, a constructor, or a record pattern")
  case tokenKind token of
    EndOfFile -> pure ()
    kind | isRecoveryBoundary kind -> pure ()
    _ -> advanceToken >> pure ()
  pure (Located (tokenSpan token) InvalidPattern)

isRecoveryBoundary :: TokenKind -> Bool
isRecoveryBoundary kind = any (`isSymbol` kind) [",", ")", "]", "}", "=>", "|"]

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
