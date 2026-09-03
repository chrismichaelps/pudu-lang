{-| @Program.Parser.Declaration.Foreign — parses a library written elsewhere

    The block is the unit because the library is what its functions share: it
    is opened once, its version is one fact, and what a program reaches outside
    itself is one place to look. [[ADR-0018 Calling a Library Written
    Elsewhere]] settles the shape. -}
module Pudu.Frontend.Parser.Declaration.Foreign
  ( parseForeign
  ) where

import Pudu.Frontend.Parser.Declaration.Function (parseParameters)
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
  parameters <- parseParameters []
  _ <- expectSymbol ")" "after the parameter list"
  arrow <- matchSymbol "->"
  owned <- if arrow == Nothing then pure Nothing else matchWord "owned"
  returned <- if arrow == Nothing then pure Nothing else Just <$> parseTypeSyntax
  released <- parseReleasedBy owned (tokenSpan start)
  let result = maybe (Located (tokenSpan start) UnitType) id returned
  pure
    ( Just
        ( Located (mergedOrLeft (tokenSpan start) (locatedSpan result))
            ForeignFunction
              { foreignName = name
              , foreignSymbol = symbol
              , foreignParameters = parameters
              , foreignResult = result
              , foreignReleasedBy = released
              }
        )
    )

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
parseReleasedBy :: Maybe Token -> Span -> Parser (Maybe (Located Text))
parseReleasedBy owned spanValue = case owned of
  Nothing -> pure Nothing
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

    `version`, `symbol`, `owned`, and `by` are ordinary names everywhere else in a
    program, and reserving four common words for one declaration form would
    cost every program that used them for anything. They are recognised in the
    positions where nothing else may appear. -}
matchWord :: Text -> Parser (Maybe Token)
matchWord word = matchKind (== Identifier word)
