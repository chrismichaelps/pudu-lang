{-| @Type.Parser.Module — parses unresolved type syntax -}
module Pudu.Frontend.Parser.Type
  ( parseTypeList
  , parseTypeSyntax
  ) where

import Data.Text (Text)
import Pudu.Frontend.Parser.Name (parseModuleName)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , emitParseError
  , expectKeyword
  , expectSymbol
  , isSymbol
  , matchKeyword
  , matchSymbol
  , peekKind
  , peekToken
  , withRecursionBudget
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Frontend.Syntax.Tree (TypeSyntax (..))
import Pudu.Frontend.Token
  ( Keyword (KwDynamic, KwAsync, KwFn, KwMut)
  , Token (tokenKind, tokenSpan)
  , TokenKind (..)
  )
import Pudu.Source (Span, mergeSpans)

parseTypeSyntax :: Parser (Located TypeSyntax)
parseTypeSyntax = do
  bounded <- withRecursionBudget parseTypeSyntaxBody
  case bounded of
    Just syntax -> pure syntax
    Nothing -> invalidAtCurrent False False

parseTypeSyntaxBody :: Parser (Located TypeSyntax)
parseTypeSyntaxBody = do
  reference <- matchSymbol "&"
  case reference of
    Just token -> do
      mutable <- maybe False (const True) <$> matchKeyword KwMut
      target <- parseTypeSyntax
      pure
        Located
          { locatedSpan = mergedOrLeft (tokenSpan token) (locatedSpan target)
          , locatedValue = ReferenceType mutable target
          }
    Nothing -> parseTypeAtom

parseTypeList :: Text -> Parser [Located TypeSyntax]
parseTypeList closing = do
  kind <- peekKind
  if isSymbol closing kind
    then pure []
    else do
      first <- parseTypeSyntax
      parseRest [first]
 where
  parseRest reversed = do
    bounded <- withRecursionBudget $ do
      comma <- matchSymbol ","
      case comma of
        Nothing -> pure (reverse reversed)
        Just _ -> do
          kind <- peekKind
          if isSymbol closing kind
            then pure (reverse reversed)
            else parseTypeSyntax >>= \next -> parseRest (next : reversed)
    pure (maybe (reverse reversed) id bounded)

parseTypeAtom :: Parser (Located TypeSyntax)
parseTypeAtom = do
  kind <- peekKind
  case kind of
    Keyword KwAsync -> parseFunctionType
    Keyword KwFn -> parseFunctionType
    Keyword KwDynamic -> parseDynamicType
    _ -> do
      opening <- matchSymbol "("
      case opening of
        Just token -> parseParenthesized (tokenSpan token)
        Nothing -> parseNamed

{-| Parse `dynamic Trait`.

    The trait takes no arguments here. A dynamic type over a generic trait would
    have to say what its parameters are, and every value in a collection of them
    would have to agree — which is a bound, not a dynamic type. -}
parseDynamicType :: Parser (Located TypeSyntax)
parseDynamicType = do
  keyword <- advanceToken
  name <- parseModuleName
  pure
    Located
      { locatedSpan = mergedOrLeft (tokenSpan keyword) (locatedSpan name)
      , locatedValue = DynamicType (locatedValue name)
      }

{-| Parse `async? fn(A, B) -> T`. The async marker and the declared return type
    are preserved so a first-class function type keeps its capability and its
    recoverable-failure spelling. -}
parseFunctionType :: Parser (Located TypeSyntax)
parseFunctionType = do
  start <- peekToken
  asyncKeyword <- matchKeyword KwAsync
  _ <- expectKeyword KwFn "to start a function type"
  _ <- expectSymbol "(" "before the function type inputs"
  inputs <- parseTypeList ")"
  _ <- expectSymbol ")" "after the function type inputs"
  _ <- expectSymbol "->" "before the function type result"
  result <- parseTypeSyntax
  pure
    Located
      { locatedSpan = mergedOrLeft (tokenSpan start) (locatedSpan result)
      , locatedValue = FunctionType (maybe False (const True) asyncKeyword) inputs result
      }

parseParenthesized :: Span -> Parser (Located TypeSyntax)
parseParenthesized openingSpan = do
  immediateClose <- matchSymbol ")"
  case immediateClose of
    Just closing ->
      pure Located{locatedSpan = mergedOrLeft openingSpan (tokenSpan closing), locatedValue = UnitType}
    Nothing -> do
      first <- parseTypeSyntax
      comma <- matchSymbol ","
      case comma of
        Nothing -> do
          closing <- expectSymbol ")" "to close the grouped type"
          pure first{locatedSpan = mergedOrLeft openingSpan (tokenSpan closing)}
        Just _ -> do
          rest <- parseTypeList ")"
          closing <- expectSymbol ")" "to close the tuple type"
          pure
            Located
              { locatedSpan = mergedOrLeft openingSpan (tokenSpan closing)
              , locatedValue = TupleType (first : rest)
              }

parseNamed :: Parser (Located TypeSyntax)
parseNamed = do
  kind <- peekKind
  case kind of
    Identifier _ -> do
      name <- parseModuleName
      opening <- matchSymbol "["
      case opening of
        Nothing -> pure Located{locatedSpan = locatedSpan name, locatedValue = NamedType (locatedValue name) []}
        Just _ -> parseArguments name
    _ -> invalidAtCurrent True True

parseArguments :: Located ModuleName -> Parser (Located TypeSyntax)
parseArguments name = do
  empty <- matchSymbol "]"
  case empty of
    Just closing -> do
      emitParseError "E1020" (tokenSpan closing) "type argument list cannot be empty"
        (Just "provide at least one type argument")
      pure (Located (mergedOrLeft (locatedSpan name) (tokenSpan closing)) InvalidType)
    Nothing -> do
      arguments <- parseTypeList "]"
      closing <- expectSymbol "]" "to close the type arguments"
      pure (Located (mergedOrLeft (locatedSpan name) (tokenSpan closing))
        (NamedType (locatedValue name) arguments))

invalidAtCurrent :: Bool -> Bool -> Parser (Located TypeSyntax)
invalidAtCurrent consume diagnose = do
  token <- peekToken
  if diagnose
    then emitParseError "E1020" (tokenSpan token) "expected type syntax"
      (Just "use a named, reference, tuple, or unit type")
    else pure ()
  if consume && tokenKind token /= EndOfFile then advanceToken >> pure () else pure ()
  pure (Located (tokenSpan token) InvalidType)

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
