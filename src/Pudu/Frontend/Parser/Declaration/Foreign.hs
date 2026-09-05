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
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , budgetExhausted
  , emitParseError
  , expectKeyword
  , expectSymbol
  , isSymbol
  , matchKind
  , matchSymbol
  , peekKind
  , peekToken
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Foreign (..)
  , ForeignFunction (..)
  , ForeignParameter (..)
  , TypeSyntax (..)
  , Visibility
  )
import Pudu.Frontend.Token
  ( Keyword (KwFn, KwType)
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
  (types, functions) <- parseForeignMembers [] []
  closing <- expectSymbol "}" "to close the foreign declarations"
  pure
    ( Located (mergedOrLeft (tokenSpan start) (tokenSpan closing))
        ( ForeignDeclaration
            Foreign
              { foreignVisibility = visibility
              , foreignLibrary = library
              , foreignVersion = version
              , foreignTypes = types
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
  -> [Located ForeignFunction]
  -> Parser ([Located Text], [Located ForeignFunction])
parseForeignMembers types reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol "}" kind || kind == EndOfFile || exhausted
    then pure (reverse types, reverse reversed)
    else do
      before <- peekToken
      if kind == Keyword KwType
        then do
          _ <- advanceToken
          name <- expectUpperIdentifier "after type"
          after <- peekToken
          if before == after
            then pure (reverse types, reverse reversed)
            else parseForeignMembers (name : types) reversed
        else do
          one <- parseForeignFunction
          after <- peekToken
          if before == after
            then pure (reverse types, reverse reversed)
            else parseForeignMembers types (maybe reversed (: reversed) one)

{-| One function, as this program asserts its shape.

    There is no body: the body is somebody else's, in another language, and the
    signature is the whole of what this program knows about it. -}
parseForeignFunction :: Parser (Maybe (Located ForeignFunction))
parseForeignFunction = do
  start <- peekToken
  _ <- expectKeyword KwFn "to start a foreign function"
  name <- expectValueIdentifier "after fn"
  symbol <- parseSymbol
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
  released <-
    parseReleasedBy owned (borrowed /= Nothing || counted /= Nothing) (tokenSpan start)
  let result = maybe (Located (tokenSpan start) UnitType) id returned
  pure
    ( Just
        ( Located (mergedOrLeft (tokenSpan start) (locatedSpan result))
            ForeignFunction
              { foreignName = name
              , foreignSymbol = symbol
              , foreignParameters = parameters
              , foreignResult = result
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
  out <- matchWord "out"
  name <- expectValueIdentifier "for the parameter's name"
  _ <- expectSymbol ":" "after the parameter's name"
  owned <- matchWord "owned"
  written <- parseTypeSyntax
  released <- parseSlotRelease owned (locatedSpan written)
  pure
    ( Located (mergedOrLeft (tokenSpan start) (locatedSpan written))
        ForeignParameter
          { foreignParameterName = name
          , foreignParameterType = Just written
          , foreignParameterOut = out /= Nothing
          , foreignParameterOwned = owned /= Nothing
          , foreignParameterReleasedBy = released
          }
    )

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
