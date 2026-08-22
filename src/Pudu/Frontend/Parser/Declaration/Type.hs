{-| @Type.Parser.Declaration — parses record, sum, and alias declarations -}
module Pudu.Frontend.Parser.Declaration.Type
  ( parseTypeDeclaration
  ) where

import Pudu.Frontend.Parser.Declaration.Generic (parseTypeParams)
import Pudu.Frontend.Parser.Name (expectUpperIdentifier, expectValueIdentifier)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , budgetExhausted
  , currentSpan
  , expectKeyword
  , expectSymbol
  , isDeclarationStart
  , isSymbol
  , lookaheadKind
  , matchKeyword
  , matchSymbol
  , peekKind
  , peekToken
  )
import Pudu.Frontend.Parser.Type (parseTypeList, parseTypeSyntax)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , FieldDeclaration (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , Variant (..)
  , VariantPayload (..)
  , Visibility
  )
import Pudu.Frontend.Token (Keyword (KwMut, KwType), Token (..), TokenKind (..))
import Pudu.Source (Span, mergeSpans)

{-| Parse `type Name[params] = definition`. Visibility is supplied by the
    orchestrator that consumed `export`. -}
parseTypeDeclaration :: Visibility -> Parser (Located Declaration)
parseTypeDeclaration visibility = do
  keyword <- expectKeyword KwType "to start a type declaration"
  name <- expectUpperIdentifier "after type"
  typeParams <- parseTypeParams
  _ <- expectSymbol "=" "before the type definition"
  definition <- parseDefinition
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan definition))
        ( TypeDeclaration
            TypeDeclarationValue
              { typeVisibility = visibility
              , typeName = name
              , typeTypeParams = typeParams
              , typeDefinition = definition
              }
        )
    )

{-| A `{` opens a record, a leading `|` opens a sum, and an uppercase name is a
    sum exactly when a `|` follows its first variant at bracket depth zero.
    Everything else is an alias for one type reference. -}
parseDefinition :: Parser (Located TypeDefinition)
parseDefinition = do
  kind <- peekKind
  if isSymbol "{" kind
    then parseRecordDefinition
    else if isSymbol "|" kind
      then advanceToken >> parseSum
      else do
        isSum <- looksLikeSum
        if isSum then parseSum else parseAlias

parseAlias :: Parser (Located TypeDefinition)
parseAlias = do
  aliased <- parseTypeSyntax
  pure (Located (locatedSpan aliased) (AliasDefinition aliased))

{-| Scan ahead at bracket depth zero for the `|` that separates variants. The
    scan is bounded and stops at the next declaration start, so a malformed
    definition cannot make it walk the whole file. -}
looksLikeSum :: Parser Bool
looksLikeSum = scan 0 0
 where
  scan :: Int -> Int -> Parser Bool
  scan offset depth
    | offset > 512 = pure False
    | otherwise = do
        kind <- lookaheadKind offset
        case kind of
          EndOfFile -> pure False
          _ | isSymbol "|" kind && depth == 0 -> pure True
            | isSymbol "(" kind || isSymbol "[" kind || isSymbol "{" kind ->
                scan (offset + 1) (depth + 1)
            | isSymbol ")" kind || isSymbol "]" kind || isSymbol "}" kind ->
                if depth <= 0 then pure False else scan (offset + 1) (depth - 1)
            | depth == 0 && offset > 0 && isDeclarationStart kind -> pure False
            | otherwise -> scan (offset + 1) depth

parseSum :: Parser (Located TypeDefinition)
parseSum = do
  first <- parseVariant
  variants <- parseVariantTail first []
  let allVariants = first : variants
      spanValue = foldl mergedOrLeft (locatedSpan first) (map locatedSpan variants)
  pure (Located spanValue (SumDefinition allVariants))

parseVariantTail :: Located Variant -> [Located Variant] -> Parser [Located Variant]
parseVariantTail first reversed = do
  pipe <- matchSymbol "|"
  exhausted <- budgetExhausted
  case pipe of
    Nothing -> pure (reverse reversed)
    Just _ | exhausted -> pure (reverse reversed)
    Just _ -> do
      before <- peekToken
      next <- parseVariant
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else parseVariantTail first (next : reversed)

parseVariant :: Parser (Located Variant)
parseVariant = do
  name <- expectUpperIdentifier "for the variant"
  kind <- peekKind
  if isSymbol "(" kind
    then do
      _ <- advanceToken
      payload <- parseTypeList ")"
      closing <- expectSymbol ")" "to close the variant payload"
      pure
        ( Located (mergedOrLeft (locatedSpan name) (tokenSpan closing))
            Variant{variantName = name, variantPayload = TuplePayload payload}
        )
    else if isSymbol "{" kind
      then do
        (fields, endSpan) <- parseFieldBlock
        pure
          ( Located (mergedOrLeft (locatedSpan name) endSpan)
              Variant{variantName = name, variantPayload = RecordPayload fields}
          )
      else
        pure
          ( Located (locatedSpan name)
              Variant{variantName = name, variantPayload = UnitPayload}
          )

parseRecordDefinition :: Parser (Located TypeDefinition)
parseRecordDefinition = do
  start <- currentSpan
  (fields, endSpan) <- parseFieldBlock
  pure (Located (mergedOrLeft start endSpan) (RecordDefinition fields))

{-| Parse `{ mut? name: type, ... }` with one optional trailing comma. -}
parseFieldBlock :: Parser ([Located FieldDeclaration], Span)
parseFieldBlock = do
  opening <- expectSymbol "{" "to start the record fields"
  fields <- parseFields []
  closing <- expectSymbol "}" "to close the record fields"
  pure (fields, mergedOrLeft (tokenSpan opening) (tokenSpan closing))

parseFields :: [Located FieldDeclaration] -> Parser [Located FieldDeclaration]
parseFields reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol "}" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      field <- parseField
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse (field : reversed))
            Just _ -> parseFields (field : reversed)

{-| Record fields are immutable unless marked `mut`, matching the ownership
    rules in [[architecture/SEMANTICS]]. -}
parseField :: Parser (Located FieldDeclaration)
parseField = do
  mutable <- matchKeyword KwMut
  start <- peekToken
  name <- expectValueIdentifier "for the record field"
  _ <- expectSymbol ":" "before the field type"
  fieldSyntax <- parseTypeSyntax
  let startSpan = maybe (tokenSpan start) tokenSpan mutable
  pure
    ( Located (mergedOrLeft startSpan (locatedSpan fieldSyntax))
        FieldDeclaration
          { fieldMutable = maybe False (const True) mutable
          , fieldName = name
          , fieldType = fieldSyntax
          }
    )

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
