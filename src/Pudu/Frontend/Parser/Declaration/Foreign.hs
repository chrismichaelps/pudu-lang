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
import Pudu.Frontend.Parser.Name (expectValueIdentifier)
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
  ( Keyword (KwFn)
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
  functions <- parseForeignFunctions []
  closing <- expectSymbol "}" "to close the foreign declarations"
  pure
    ( Located (mergedOrLeft (tokenSpan start) (tokenSpan closing))
        ( ForeignDeclaration
            Foreign
              { foreignVisibility = visibility
              , foreignLibrary = library
              , foreignVersion = version
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

parseForeignFunctions :: [Located ForeignFunction] -> Parser [Located ForeignFunction]
parseForeignFunctions reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol "}" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      one <- parseForeignFunction
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else parseForeignFunctions (maybe reversed (: reversed) one)

{-| One function, as this program asserts its shape.

    There is no body: the body is somebody else's, in another language, and the
    signature is the whole of what this program knows about it. -}
parseForeignFunction :: Parser (Maybe (Located ForeignFunction))
parseForeignFunction = do
  start <- peekToken
  _ <- expectKeyword KwFn "to start a foreign function"
  name <- expectValueIdentifier "after fn"
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
              , foreignParameters = parameters
              , foreignResult = result
              , foreignReleasedBy = released
              }
        )
    )

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

    `version`, `owned`, and `by` are ordinary names everywhere else in a
    program, and reserving three common words for one declaration form would
    cost every program that used them for anything. They are recognised in the
    positions where nothing else may appear. -}
matchWord :: Text -> Parser (Maybe Token)
matchWord word = matchKind (== Identifier word)
