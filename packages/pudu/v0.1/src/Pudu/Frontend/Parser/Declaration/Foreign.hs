{-| @Program.Parser.Declaration.Foreign — parses a library written elsewhere

    The block is the unit because the library is what its functions share: it
    is opened once, its version is one fact, and what a program reaches outside
    itself is one place to look. [[ADR-0018 Calling a Library Written
    Elsewhere]] settles the shape. -}
module Pudu.Frontend.Parser.Declaration.Foreign
  ( parseForeign
  ) where

import Pudu.Frontend.Parser.Type (parseTypeSyntax)
import Pudu.Frontend.Parser.Expression.Recovery (mergedOrLeft)
import Pudu.Frontend.Parser.Name (expectUpperIdentifier, expectValueIdentifier)
import Data.Text (Text)
import Data.List.NonEmpty (NonEmpty (..))
import Pudu.Foreign.Extent (ExtentUnit (..))
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , budgetExhausted
  , emitParseError
  , expectKeyword
  , expectSymbol
  , isSymbol
  , lookaheadKind
  , matchKeyword
  , matchKind
  , matchSymbol
  , peekKind
  , peekToken
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Foreign (..)
  , ForeignCallback (..)
  , ForeignCallbackGroup (..)
  , ForeignDelegate (..)
  , ForeignDelegateMethod (..)
  , ForeignCallbackMember (..)
  , ForeignCallbackParameter (..)
  , ForeignCallbackPassing (..)
  , ForeignFunction (..)
  , ForeignClass (..)
  , ForeignMethod (..)
  , ForeignLength (..)
  , Literal (..)
  , ForeignParameter (..)
  , TypeSyntax (..)
  , Visibility
  )
import Pudu.Frontend.Token
  ( Keyword (KwElse, KwFalse, KwFn, KwFor, KwNull, KwTrue, KwType)
  , Token (..)
  , TokenKind (..)
  )
import Pudu.Source (Span)

{-| Parse `foreign "name" version "v"? { fn … }`.

    The library is named by a string rather than by an identifier because it is
    a name the platform is asked for, not a name in this program — and a string
    is where a reader already expects something outside the source. -}
parseForeign :: Visibility -> Parser (Located Declaration)
parseForeign visibility = do
  start <- peekToken
  _ <- matchWord "foreign"
  library <- expectStringLiteral "for the library's name"
  version <- parseVersion
  _ <- expectSymbol "{" "to start the foreign declarations"
  (types, classes, callbacks, groups, delegates, functions) <- parseForeignMembers [] [] [] [] [] []
  closing <- expectSymbol "}" "to close the foreign declarations"
  pure
    ( Located (mergedOrLeft (tokenSpan start) (tokenSpan closing))
        ( ForeignDeclaration
            Foreign
              { foreignVisibility = visibility
              , foreignLibrary = library
              , foreignVersion = version
              , foreignTypes = types <> map foreignClassName classes
                  <> map (foreignDelegateName . locatedValue) delegates
              , foreignClasses = classes
              , foreignCallbacks = callbacks
              , foreignCallbackGroups = groups
              , foreignDelegates = delegates
              , foreignFunctions = functions
              }
        )
    )

{-| The version a declaration expects, where it names one.

    Recorded rather than enforced: nothing here fetches or verifies a library,
    and a check this cannot perform would be a claim rather than a check. -}
parseVersion :: Parser (Maybe (Located Text))
parseVersion = do
  keyword <- matchWord "version"
  case keyword of
    Nothing -> pure Nothing
    Just _ -> Just <$> expectStringLiteral "after version"

{-| The members of a block: the opaque things the library hands back, and the
    functions that produce and consume them.

    A handle is declared rather than inferred from the signatures that mention
    it, so a misspelling in one of them is a name nothing declares rather than a
    second handle type that silently accepts nothing. -}
parseForeignMembers
  :: [Located Text]
  -> [ForeignClass]
  -> [Located ForeignCallback]
  -> [Located ForeignCallbackGroup]
  -> [Located ForeignDelegate]
  -> [Located ForeignFunction]
  -> Parser
      ( [Located Text], [ForeignClass], [Located ForeignCallback], [Located ForeignCallbackGroup]
      , [Located ForeignDelegate], [Located ForeignFunction] )
parseForeignMembers types classes callbacks groups delegates functions = do
  before <- peekToken
  exhausted <- budgetExhausted
  let kind = tokenKind before
      collected = pure
        (reverse types, reverse classes, reverse callbacks, reverse groups, reverse delegates, reverse functions)
      continue next = do
        after <- peekToken
        if before == after then collected else next
  if isSymbol "}" kind || kind == EndOfFile || exhausted then collected else
    case kind of
      Keyword KwType -> do
        _ <- advanceToken
        name <- expectUpperIdentifier "after type"
        continue (parseForeignMembers (name : types) classes callbacks groups delegates functions)
      Identifier "class" -> do
        _ <- advanceToken
        name <- expectUpperIdentifier "after class"
        symbol <- parseSymbol
        continue (parseForeignMembers types (ForeignClass name (maybe name id symbol) : classes) callbacks groups delegates functions)
      Identifier "callback" -> do
        callback <- parseForeignCallback
        continue (parseForeignMembers types classes (callback : callbacks) groups delegates functions)
      Identifier "callbacks" -> do
        group <- parseCallbackGroup
        continue (parseForeignMembers types classes callbacks (group : groups) delegates functions)
      Identifier "delegate" -> do
        delegate <- parseDelegate
        continue (parseForeignMembers types classes callbacks groups (delegate : delegates) functions)
      _ -> do
        function <- parseForeignFunction
        continue (parseForeignMembers types classes callbacks groups delegates (maybe functions (: functions) function))

{-| `delegate Name symbol "Class" for Group { member "selector:", ... }`. The
    symbol defaults to the local name, as a class declaration's does. -}
parseDelegate :: Parser (Located ForeignDelegate)
parseDelegate = do
  start <- advanceToken
  name <- expectUpperIdentifier "after delegate"
  symbol <- parseSymbol
  _ <- expectKeyword KwFor "before the delegate's callback group"
  group <- expectUpperIdentifier "for the delegate's callback group"
  _ <- expectSymbol "{" "before the delegate's methods"
  methods <- parseMethods []
  closing <- expectSymbol "}" "after the delegate's methods"
  pure (Located (mergedOrLeft (tokenSpan start) (tokenSpan closing))
    (ForeignDelegate name (maybe name id symbol) group methods))
 where
  parseMethods reversed = do
    kind <- peekKind
    exhausted <- budgetExhausted
    if kind == EndOfFile || isSymbol "}" kind || exhausted
      then pure (reverse reversed)
      else do
        member <- expectValueIdentifier "for the callback group member"
        selector <- expectStringLiteral "for the member's Objective-C selector"
        let methods = ForeignDelegateMethod member selector : reversed
        separator <- matchSymbol ","
        case separator of
          Just _ -> parseMethods methods
          Nothing -> pure (reverse methods)

parseCallbackGroup :: Parser (Located ForeignCallbackGroup)
parseCallbackGroup = do
  start <- advanceToken
  name <- expectUpperIdentifier "after callbacks"
  _ <- expectSymbol "{" "before the callback group members"
  members <- parseMembers []
  closing <- expectSymbol "}" "after the callback group members"
  pure (Located (mergedOrLeft (tokenSpan start) (tokenSpan closing))
    (ForeignCallbackGroup name members))
 where
  parseMembers reversed = do
    kind <- peekKind
    exhausted <- budgetExhausted
    if kind == EndOfFile || isSymbol "}" kind || exhausted
      then pure (reverse reversed)
      else do
        name <- expectValueIdentifier "for the callback group member"
        _ <- expectSymbol ":" "before the member's callback type"
        callback <- expectUpperIdentifier "for the member's callback type"
        let members = ForeignCallbackMember name callback : reversed
        separator <- matchSymbol ","
        case separator of
          Just _ -> parseMembers members
          Nothing -> pure (reverse members)

parseForeignCallback :: Parser (Located ForeignCallback)
parseForeignCallback = do
  start <- advanceToken
  name <- expectUpperIdentifier "after callback"
  _ <- expectSymbol "(" "before the callback parameter list"
  parameters <- parseCallbackParameters []
  closing <- expectSymbol ")" "after the callback parameter list"
  arrow <- matchSymbol "->"
  result <- case arrow of
    Nothing -> pure (Located (tokenSpan closing) UnitType)
    Just _ -> parseTypeSyntax
  fallback <- case arrow of
    Nothing -> pure Nothing
    Just _ -> do
      keyword <- matchKeyword KwElse
      case keyword of
        Nothing -> pure Nothing
        Just _ -> parseCallbackFallback
  let end = maybe (locatedSpan result) locatedSpan fallback
  pure (Located (mergedOrLeft (tokenSpan start) end)
    (ForeignCallback name parameters result fallback))

parseCallbackParameters :: [Located ForeignCallbackParameter] -> Parser [Located ForeignCallbackParameter]
parseCallbackParameters reversed = do
  start <- peekToken
  exhausted <- budgetExhausted
  let kind = tokenKind start
  if isSymbol ")" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      following <- lookaheadKind 1
      parameter <- if kind == Identifier "context" && not (isSymbol ":" following)
        then advanceToken >> pure (Located (tokenSpan start) ForeignCallbackContext)
        else do
          name <- expectValueIdentifier "for the callback parameter's name"
          _ <- expectSymbol ":" "after the callback parameter's name"
          borrowed <- matchWord "borrowed"
          written <- parseTypeSyntax
          extent <- parseLengthRelation
          pure (Located (mergedOrLeft (tokenSpan start) (locatedSpan written))
            (ForeignCallbackArgument name (borrowed /= Nothing) written extent))
      comma <- matchSymbol ","
      case comma of
        Nothing -> pure (reverse (parameter : reversed))
        Just _ -> parseCallbackParameters (parameter : reversed)

parseCallbackFallback :: Parser (Maybe (Located Literal))
parseCallbackFallback = do
  minus <- matchSymbol "-"
  token <- peekToken
  let prefix = maybe "" (const "-") minus
      start = maybe (tokenSpan token) tokenSpan minus
      literal = case tokenKind token of
        IntegerLiteral value -> Just (IntegerValue (prefix <> value))
        FloatLiteral value -> Just (FloatValue (prefix <> value))
        DecimalLiteral value -> Just (DecimalValue (prefix <> value))
        StringLiteral value | minus == Nothing -> Just (StringValue value)
        CharLiteral value | minus == Nothing -> Just (CharValue value)
        Keyword KwTrue | minus == Nothing -> Just (BoolValue True)
        Keyword KwFalse | minus == Nothing -> Just (BoolValue False)
        Keyword KwNull | minus == Nothing -> Just NullValue
        _ -> Nothing
  case literal of
    Just value -> do
      _ <- advanceToken
      pure (Just (Located (mergedOrLeft start (tokenSpan token)) value))
    Nothing -> do
      let (code, message) = case tokenKind token of
            EndOfFile -> ("E1000", "the file ends before the callback fallback literal")
            _ -> ("E1001", "expected a callback fallback literal")
      emitParseError code (tokenSpan token) message
        (Just "give the value the library receives when the callback does not complete")
      pure Nothing

{-| One function, as this program asserts its shape.

    There is no body: the body is somebody else's, in another language, and the
    signature is the whole of what this program knows about it. -}
parseForeignFunction :: Parser (Maybe (Located ForeignFunction))
parseForeignFunction = do
  start <- peekToken
  _ <- expectKeyword KwFn "to start a foreign function"
  name <- expectValueIdentifier "after fn"
  symbol <- parseSymbol
  method <- parseMethod
  _ <- expectSymbol "(" "before the parameter list"
  parameters <- parseForeignParameters []
  _ <- expectSymbol ")" "after the parameter list"
  arrow <- matchSymbol "->"
  owned <- if arrow == Nothing then pure Nothing else matchWord "owned"
  borrowed <-
    if arrow == Nothing || owned /= Nothing then pure Nothing else matchWord "borrowed"
  counted <-
    if arrow == Nothing || owned /= Nothing || borrowed /= Nothing
      then pure Nothing
      else matchWord "counted"
  returned <- if arrow == Nothing then pure Nothing else Just <$> parseTypeSyntax
  lengthSlot <- case returned of
    Nothing -> pure Nothing
    Just _ -> do
      relation <- matchExtentWord "elements"
      traverse (const (expectValueIdentifier "after elements of")) relation
  released <-
    parseReleasedBy owned (borrowed /= Nothing || counted /= Nothing) (tokenSpan start)
  let result = maybe (Located (tokenSpan start) UnitType) id returned
  pure
    ( Just
        ( Located (mergedOrLeft (tokenSpan start) (locatedSpan result))
            ForeignFunction
              { foreignName = name
              , foreignSymbol = symbol
              , foreignMethod = method
              , foreignParameters = parameters
              , foreignResult = result
              , foreignResultLength = lengthSlot
              , foreignResultBorrowed = borrowed /= Nothing
              , foreignResultCounted = counted /= Nothing
              , foreignReleasedBy = released
              }
        )
    )

{-| The parameter list of a foreign function.

    Its own parser rather than the ordinary one because two things only make
    sense here: a parameter the library writes rather than reads, and the
    ownership of what it wrote. A foreign parameter also has no default, there
    being no caller on this side to apply one. -}
parseForeignParameters :: [Located ForeignParameter] -> Parser [Located ForeignParameter]
parseForeignParameters reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol ")" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      one <- parseForeignParameter
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          _ <- matchSymbol ","
          parseForeignParameters (one : reversed)

{-| One parameter: `out`? name `:` `owned`? type (`by` release)?

    `out` before the name because that is the first thing a reader needs to
    know about it — everything after reads the same either way, and a marker
    after the type would be found only by someone already reading closely. -}
parseForeignParameter :: Parser (Located ForeignParameter)
parseForeignParameter = do
  start <- peekToken
  following <- lookaheadKind 1
  case (tokenKind start, following) of
    (Identifier "context", Identifier _) -> do
      _ <- advanceToken
      name <- expectValueIdentifier "after context"
      pure (Located (mergedOrLeft (tokenSpan start) (locatedSpan name))
        ForeignParameter
          { foreignParameterName = name
          , foreignParameterContext = True
          , foreignParameterCallbackPassing = Nothing
          , foreignParameterType = Nothing
          , foreignParameterOut = False
          , foreignParameterOwned = False
          , foreignParameterNullable = Nothing
          , foreignParameterLength = Nothing
          , foreignParameterReleasedBy = Nothing
          })
    _ -> do
      out <- matchWord "out"
      name <- expectValueIdentifier "for the parameter's name"
      _ <- expectSymbol ":" "after the parameter's name"
      owned <- matchWord "owned"
      nullable <- case owned of
        Just _ -> pure Nothing
        Nothing -> matchWord "nullable"
      passing <- do
        trampoline <- matchWord "trampoline"
        case trampoline of
          Just _ -> pure (Just TrampolinePassing)
          Nothing -> do
            context <- matchWord "context"
            case context of
              Just _ -> pure (Just ContextPassing)
              Nothing -> fmap (const BlockPassing) <$> matchWord "block"
      written <- case passing of
        Just TrampolinePassing -> parseTrampolineType
        _ -> parseTypeSyntax
      extent <- parseLengthRelation
      released <- parseSlotRelease owned (locatedSpan written)
      pure (Located (mergedOrLeft (tokenSpan start) (locatedSpan written))
        ForeignParameter
          { foreignParameterName = name
          , foreignParameterContext = False
          , foreignParameterCallbackPassing = passing
          , foreignParameterType = Just written
          , foreignParameterOut = out /= Nothing
          , foreignParameterOwned = owned /= Nothing
          , foreignParameterNullable = tokenSpan <$> nullable
          , foreignParameterLength = extent
          , foreignParameterReleasedBy = released
          })

parseTrampolineType :: Parser (Located TypeSyntax)
parseTrampolineType = do
  Located at owner <- expectUpperIdentifier "after trampoline"
  separator <- matchSymbol "."
  case separator of
    Nothing -> pure (Located at (NamedType (ModuleName (owner :| [])) []))
    Just _ -> do
      Located end member <- expectValueIdentifier "for the callback group member"
      pure (Located (mergedOrLeft at end) (NamedType (ModuleName (owner :| [member])) []))

parseLengthRelation :: Parser (Maybe ForeignLength)
parseLengthRelation = do
  elements <- matchExtentWord "elements"
  case elements of
    Just token -> Just <$> relation token ExtentElements
    Nothing -> do
      bytes <- matchExtentWord "bytes"
      traverse (\token -> relation token ExtentBytes) bytes
 where
  relation token unit = do
    first <- expectValueIdentifier "after the foreign length unit"
    rest <- targets []
    pure (ForeignLength (Located (tokenSpan token) unit) (first :| rest))
  targets reversed = do
    next <- matchWord "and"
    case next of
      Nothing -> pure (reverse reversed)
      Just _ -> do
        target <- expectValueIdentifier "after and"
        targets (target : reversed)

matchExtentWord :: Text -> Parser (Maybe Token)
matchExtentWord word = do
  kind <- peekKind
  following <- lookaheadKind 1
  case (kind, following) of
    (Identifier current, Identifier "of") | current == word -> do
      unit <- advanceToken
      _ <- advanceToken
      pure (Just unit)
    _ -> pure Nothing

{-| What releases what an owned slot received.

    The same rule the result follows, for the same reason: ownership is written
    in the declaration precisely so that a missing release is a diagnostic here
    rather than a leak nobody sees. -}
parseSlotRelease :: Maybe Token -> Span -> Parser (Maybe (Located Text))
parseSlotRelease owned spanValue = case owned of
  Nothing -> pure Nothing
  Just _ -> do
    keyword <- matchWord "by"
    case keyword of
      Just _ -> Just <$> expectValueIdentifier "after by"
      Nothing -> do
        emitParseError "E1060" spanValue "an owned slot names no release"
          (Just "write owned T by release, naming the function that frees it")
        pure Nothing

{-| The exact native spelling, when its library does not use Pudu's naming
    convention. Keeping this separate lets a Raylib `MemAlloc` remain the
    idiomatic local `memAlloc` without guessing or rewriting either name. -}
parseMethod :: Parser (Maybe ForeignMethod)
parseMethod = do
  keyword <- matchWord "selector"
  traverse (const (ForeignMethod
    <$> expectStringLiteral "for the Objective-C selector"
    <*> (matchWord "on" >>= traverse (const (expectUpperIdentifier "after on"))))) keyword

parseSymbol :: Parser (Maybe (Located Text))
parseSymbol = do
  keyword <- matchWord "symbol"
  case keyword of
    Nothing -> pure Nothing
    Just _ -> Just <$> expectStringLiteral "after symbol"

{-| What releases an owned result.

    An owned result that names no release is refused here rather than leaking
    later: the whole reason ownership is in the declaration is that it can be
    checked where it is written. -}
parseReleasedBy :: Maybe Token -> Bool -> Span -> Parser (Maybe (Located Text))
parseReleasedBy owned borrowed spanValue = case owned of
  {-| A release is read after `borrowed` and `counted` too. It cannot mean
      anything after `borrowed`, and after `counted` its absence is the mistake
      — but refusing either in the grammar reports a missing `fn` several tokens
      later, or names the wrong mode. Read it, and let the check that knows what
      each mode means say so where it is written. -}
  Nothing
    | borrowed -> do
        keyword <- matchWord "by"
        case keyword of
          Just _ -> Just <$> expectValueIdentifier "after by"
          Nothing -> pure Nothing
    | otherwise -> pure Nothing
  Just _ -> do
    keyword <- matchWord "by"
    case keyword of
      Just _ -> Just <$> expectValueIdentifier "after by"
      Nothing -> do
        emitParseError "E1060" spanValue "an owned result names no release"
          (Just "write owned T by release, naming the function that frees it")
        pure Nothing

expectStringLiteral :: Text -> Parser (Located Text)
expectStringLiteral purpose = do
  token <- advanceToken
  case tokenKind token of
    StringLiteral value -> pure (Located (tokenSpan token) value)
    _ -> do
      emitParseError "E1061" (tokenSpan token) ("expected a string " <> purpose)
        (Just "write the name in quotation marks")
      pure (Located (tokenSpan token) "")

{-| A word that means something only here.

    `version`, `symbol`, `out`, `owned`, and `by` are ordinary names everywhere
    else in a program, and reserving five common words for one declaration form
    would cost every program that used them for anything. They are recognised in
    the positions where nothing else may appear. -}
matchWord :: Text -> Parser (Maybe Token)
matchWord word = matchKind (== Identifier word)
