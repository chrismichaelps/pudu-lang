{-| @Lsp.Context.Module — what construct a cursor stands in, read from the syntax tree -}
module Pudu.Lsp.Context
  ( CompletionContext (..)
  , ImportSite (..)
  , TypeParameter
  , contextAt
  , contextParameters
  , importSiteAt
  ) where

import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Constraint (..)
  , Declaration (..)
  , Expression (..)
  , FieldDeclaration (..)
  , FieldInit (..)
  , Function (..)
  , FunctionBody (..)
  , Impl (..)
  , MatchArm (..)
  , Module (..)
  , Pattern (InvalidPattern)
  , Parameter (..)
  , Statement (..)
  , Trait (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeParam (..)
  , TypeSyntax (..)
  , Variant (..)
  , VariantPayload (..)
  )
import Pudu.Frontend.Token
  ( Keyword (..)
  , SymbolKind (..)
  , TemplatePart (..)
  , Token (..)
  , TokenKind (..)
  , Trivia (..)
  , TriviaKind (..)
  )
import Pudu.Source (Span, spanEnd, spanStart, unOffset)

{-| What may be written where the cursor stands.

    A completion list is only as right as its idea of the position: after
    `case`, a pattern of the subject's type is wanted, not every name in scope;
    after `->`, a type, not a value. The position is read from the tree the
    parser built, so it agrees with how the program is actually read. -}
data CompletionContext
  {-| Inside a match arm's pattern: the subject, every arm of the match, and
      the arm the cursor is in. -}
  = PatternContext !(Located Expression) ![Located MatchArm] !(Located MatchArm)
  {-| Where a type is written, with the type parameters in scope there,
      innermost declaration first. -}
  | TypeContext ![TypeParameter]
  | ImportContext !ImportSite
  {-| Where a value is written, with the type parameters in scope and the
      innermost expression holding the cursor. -}
  | ValueContext ![TypeParameter] !(Maybe (Located Expression))
  | SuppressedContext
  deriving stock (Eq, Show)

{-| A type parameter in scope, with the bounds its declaration and any `where`
    clause of the same declaration gave it. -}
type TypeParameter = (Text, [Located TypeSyntax])

{-| The type parameters in scope where a context was found; none at an
    import, in prose, or where there is no tree. -}
contextParameters :: CompletionContext -> [TypeParameter]
contextParameters context = case context of
  TypeContext parameters -> parameters
  ValueContext parameters _ -> parameters
  _ -> []

{-| Where in an import the cursor stands. -}
data ImportSite
  {-| Writing the module path, which starts at this offset. -}
  = ImportPath !Int
  {-| Inside the selection braces of an import of this module. -}
  | ImportSelection !Text
  {-| After `as`, where a new name is chosen and nothing is offered. -}
  | ImportAlias
  deriving stock (Eq, Show)

{-| The construct at `offset`. Comments, quoted text, and imports are read
    from the tokens, which the lexer gives for any text, so they are known
    while the rest of the document does not parse; everything else needs the
    tree, and without one the position is an ordinary value position. -}
contextAt :: [Token] -> Maybe Module -> Int -> CompletionContext
contextAt tokens parsed offset
  | suppressedAt offset tokens = SuppressedContext
  | Just site <- importSiteAt tokens offset = ImportContext site
  | otherwise = case parsed of
      Nothing -> ValueContext [] Nothing
      Just tree ->
        maybe (ValueContext [] Nothing) id
          (listToMaybe [found | Just found <- map (declarationContext offset []) (moduleDeclarations tree)])

{-| The import being written at `offset`, read backwards from the cursor over
    the tokens before it.

    `import Std.Co` and `import Std.` are paths being written; `import Std.Io`
    followed by a space is a finished path and the cursor has left it.
    `import Std.Io { read, wr` is a selection from `Std.Io`. -}
importSiteAt :: [Token] -> Int -> Maybe ImportSite
importSiteAt tokens offset = case before of
  [] -> Nothing
  latest : _ -> case path before of
    (start, Keyword KwImport : _)
      | finishedName latest -> Nothing
      | otherwise -> Just (ImportPath start)
    (_, Keyword KwAs : rest) | importsBack rest -> Just ImportAlias
    _ -> selection before
 where
  before =
    reverse
      [ token
      | token <- tokens
      , tokenKind token /= EndOfFile
      , unOffset (spanStart (tokenSpan token)) < offset
      ]
  -- A name that ends before the cursor has been left: a space follows it.
  finishedName token = case tokenKind token of
    Identifier _ -> unOffset (spanEnd (tokenSpan token)) < offset
    _ -> False
  path rest = go offset rest
   where
    go start remaining = case remaining of
      token : more | pathToken token -> go (unOffset (spanStart (tokenSpan token))) more
      _ -> (start, map tokenKind remaining)
  pathToken = pathKind . tokenKind
  pathKind kind = case kind of
    Identifier _ -> True
    Symbol SymDot -> True
    _ -> False
  importsBack kinds = take 1 (dropWhile pathKind kinds) == [Keyword KwImport]
  selection remaining = case dropWhile selected remaining of
    brace : more
      | tokenKind brace == Symbol SymLeftBrace
      , (_, Keyword KwImport : _) <- path more ->
          Just (ImportSelection (Text.concat [spelling token | token <- reverse (takeWhile pathToken more)]))
    _ -> Nothing
  selected token = case tokenKind token of
    Identifier _ -> True
    Symbol SymComma -> True
    _ -> False
  spelling token = case tokenKind token of
    Identifier name -> name
    _ -> "."

suppressedAt :: Int -> [Token] -> Bool
suppressedAt offset = any suppressed
 where
  suppressed token =
    any comment (tokenLeadingTrivia token)
      || (covers offset (tokenSpan token) && quoted token)
  comment trivia =
    covers offset (triviaSpan trivia)
      && triviaKind trivia `elem` [LineComment, BlockComment, DocComment]
  quoted token = case tokenKind token of
    StringLiteral _ -> True
    CharLiteral _ -> True
    TemplateLiteral parts ->
      case [nested | TemplateHole spanValue nested <- parts, covers offset spanValue] of
        nested : _ -> suppressedAt offset nested
        [] -> True
    _ -> False

covers :: Int -> Span -> Bool
covers offset spanValue =
  unOffset (spanStart spanValue) <= offset && offset <= unOffset (spanEnd spanValue)

within :: Int -> Located a -> Bool
within offset = covers offset . locatedSpan

firstOf :: [Maybe CompletionContext] -> Maybe CompletionContext
firstOf candidates = listToMaybe [found | Just found <- candidates]

declarationContext :: Int -> [TypeParameter] -> Located Declaration -> Maybe CompletionContext
declarationContext offset parameters located@(Located _ declaration)
  | not (within offset located) = Nothing
  | otherwise = case declaration of
      BindingDeclaration _ _ _ annotation value ->
        firstOf [annotation >>= typeContext offset parameters, expressionContext offset parameters value]
      FunctionDeclaration function -> functionContext offset parameters function
      TypeDeclaration value -> typeDeclarationContext offset parameters value
      TraitDeclaration trait ->
        let inScope = declared (traitTypeParams trait) (traitConstraints trait) <> parameters
         in firstOf
              ( map (typeParamContext offset inScope) (traitTypeParams trait)
                  <> map (constraintContext offset inScope) (traitConstraints trait)
                  <> [functionContext offset inScope member | Located _ member <- traitMembers trait]
              )
      ImplDeclaration impl ->
        let inScope = declared (implTypeParams impl) (implConstraints impl) <> parameters
         in firstOf
              ( map (typeParamContext offset inScope) (implTypeParams impl)
                  <> [typeContext offset inScope (implTrait impl), typeContext offset inScope (implTarget impl)]
                  <> map (constraintContext offset inScope) (implConstraints impl)
                  <> [functionContext offset inScope function | Located _ function <- implFunctions impl]
              )
      _ -> Nothing

typeDeclarationContext :: Int -> [TypeParameter] -> TypeDeclarationValue -> Maybe CompletionContext
typeDeclarationContext offset parameters value =
  let inScope = declared (typeTypeParams value) [] <> parameters
   in firstOf
        ( map (typeParamContext offset inScope) (typeTypeParams value)
            <> [definitionContext inScope (typeDefinition value)]
        )
 where
  definitionContext inScope (Located _ definition) = case definition of
    RecordDefinition fields -> firstOf (map (fieldContext inScope) fields)
    SumDefinition variants -> firstOf (map (variantContext inScope) variants)
    AliasDefinition aliased -> typeContext offset inScope aliased
    InvalidDefinition -> Nothing
  fieldContext inScope (Located _ field) = typeContext offset inScope (fieldType field)
  variantContext inScope (Located _ variant) = case variantPayload variant of
    TuplePayload members -> firstOf (map (typeContext offset inScope) members)
    RecordPayload fields -> firstOf (map (fieldContext inScope) fields)
    _ -> Nothing

{-| A declaration's type parameters, innermost first, each with its written
    bounds and those its `where` clause adds. -}
declared :: [Located TypeParam] -> [Located Constraint] -> [TypeParameter]
declared params constraints =
  [ (name, typeParamBounds param <> concat [constraintBounds c | Located _ c <- constraints, locatedValue (constraintSubject c) == name])
  | Located _ param <- params
  , let name = locatedValue (typeParamName param)
  ]

typeParamContext :: Int -> [TypeParameter] -> Located TypeParam -> Maybe CompletionContext
typeParamContext offset parameters (Located _ param) =
  firstOf (map (typeContext offset parameters) (typeParamBounds param))

constraintContext :: Int -> [TypeParameter] -> Located Constraint -> Maybe CompletionContext
constraintContext offset parameters (Located _ constraint) =
  firstOf (map (typeContext offset parameters) (constraintBounds constraint))

functionContext :: Int -> [TypeParameter] -> Function -> Maybe CompletionContext
functionContext offset parameters function =
  let inScope = declared (functionTypeParams function) (functionConstraints function) <> parameters
   in firstOf
        ( map (typeParamContext offset inScope) (functionTypeParams function)
            <> map (parameterContext inScope) (functionParameters function)
            <> [functionReturn function >>= typeContext offset inScope]
            <> map (constraintContext offset inScope) (functionConstraints function)
            <> [functionBody function >>= bodyContext inScope]
        )
 where
  parameterContext inScope (Located _ parameter) =
    firstOf
      [ parameterType parameter >>= typeContext offset inScope
      , parameterDefault parameter >>= expressionContext offset inScope
      ]
  bodyContext inScope (Located _ body) = case body of
    BlockBody block -> blockContext offset inScope block
    ExpressionBody expression -> expressionContext offset inScope expression

{-| A written type contains the cursor: every name inside it is a type. -}
typeContext :: Int -> [TypeParameter] -> Located TypeSyntax -> Maybe CompletionContext
typeContext offset parameters located
  | within offset located = Just (TypeContext parameters)
  | otherwise = Nothing

blockContext :: Int -> [TypeParameter] -> Located Block -> Maybe CompletionContext
blockContext offset parameters located@(Located _ block)
  | not (within offset located) = Nothing
  | otherwise =
      firstOf
        ( map (statementContext offset parameters) (blockStatements block)
            <> [ blockResult block >>= expressionContext offset parameters
               , Just (ValueContext parameters Nothing)
               ]
        )

statementContext :: Int -> [TypeParameter] -> Located Statement -> Maybe CompletionContext
statementContext offset parameters located@(Located _ statement)
  | not (within offset located) = Nothing
  | otherwise = case statement of
      DeclarationStatement declaration -> declarationContext offset parameters declaration
      ExpressionStatement expression -> expressionContext offset parameters expression
      ReturnStatement value -> value >>= expressionContext offset parameters
      BreakStatement _ value -> value >>= expressionContext offset parameters
      LetElseStatement _ value otherwise' ->
        firstOf [expressionContext offset parameters value, blockContext offset parameters otherwise']
      LetPatternStatement _ _ annotation value ->
        firstOf [annotation >>= typeContext offset parameters, expressionContext offset parameters value]
      _ -> Nothing

expressionContext :: Int -> [TypeParameter] -> Located Expression -> Maybe CompletionContext
expressionContext offset parameters located@(Located _ expression)
  | not (within offset located) = Nothing
  | otherwise = firstOf [specific, Just (ValueContext parameters (Just located))]
 where
  specific = case expression of
      MatchExpression subject arms ->
        firstOf
          ( expressionContext offset parameters subject
              : map (armContext subject arms) arms
          )
      UnaryExpression _ operand -> inner operand
      BinaryExpression left _ right -> firstOf [inner left, inner right]
      CallExpression callee arguments -> firstOf (inner callee : map inner arguments)
      MemberExpression receiver _ -> inner receiver
      IndexExpression receiver index -> firstOf [inner receiver, inner index]
      RangeExpression from _ to -> firstOf [from >>= inner, to >>= inner]
      TryExpression value -> inner value
      AwaitExpression value -> inner value
      TupleExpression items -> firstOf (map inner items)
      ArrayExpression items -> firstOf (map inner items)
      SetExpression items -> firstOf (map inner items)
      UnsafeExpression _ block -> blockContext offset parameters block
      MacroCall _ arguments -> firstOf (map inner arguments)
      ScopeExpression block -> blockContext offset parameters block
      LambdaExpression function -> functionContext offset parameters function
      TypeApplication callee arguments ->
        firstOf (inner callee : map (typeContext offset parameters) arguments)
      RecordExpression _ fields -> firstOf (map fieldInit fields)
      RecordUpdateExpression _ base fields -> firstOf (inner base : map fieldInit fields)
      BlockExpression block -> blockContext offset parameters block
      IfExpression condition consequent alternative ->
        firstOf [inner condition, blockContext offset parameters consequent, alternative >>= inner]
      IfLetExpression _ value consequent alternative ->
        firstOf [inner value, blockContext offset parameters consequent, alternative >>= inner]
      WhileExpression _ condition body -> firstOf [inner condition, blockContext offset parameters body]
      WhileLetExpression _ _ value body -> firstOf [inner value, blockContext offset parameters body]
      LoopExpression _ body -> blockContext offset parameters body
      ForExpression _ _ iterable body -> firstOf [inner iterable, blockContext offset parameters body]
      _ -> Nothing
  inner = expressionContext offset parameters
  fieldInit (Located _ field) = fieldInitValue field >>= inner
  armContext subject arms arm@(Located armSpan value)
    | within offset (armPattern value) = Just (PatternContext subject arms arm)
    -- An arm the parser recovered with no pattern yet, `case ` at the end of
    -- what is written: the cursor after its keyword is where the pattern goes.
    | InvalidPattern <- locatedValue (armPattern value)
    , offset > unOffset (spanStart armSpan) + 4
    , within offset arm =
        Just (PatternContext subject arms arm)
    | otherwise = firstOf [armGuard value >>= inner, inner (armBody value)]
