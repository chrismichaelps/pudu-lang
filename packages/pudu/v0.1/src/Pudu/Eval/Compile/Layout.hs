{-| @Pudu.Eval.Compile.Layout.Module — where a compiled body keeps its locals -}
module Pudu.Eval.Compile.Layout
  ( slotLayout
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Eval.Capture (reachableNames)
import Pudu.Frontend.Expand.Substitute (patternNames)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree

{-| Admit fixed positions only for unique binders whose reads follow their
    introduction and lexical scope. Uncertain captures retain name lookup. -}
slotLayout :: [Text] -> FunctionBody -> Maybe (Map Text Int)
slotLayout parameters body
  -- A body with no locals of its own reads only its parameters, and setting
  -- up slots for a call costs more than it saves there.
  | null declared = Nothing
  | Set.size (Set.fromList everything) /= length everything = Nothing
  | not (validAccesses (Set.fromList (parameters <> placed)) (Set.fromList parameters) found) = Nothing
  | otherwise = Just (Map.fromList (zip (parameters <> placed) [0 ..]))
 where
  found = case body of
    BlockBody block -> fromBlock block
    ExpressionBody expression -> fromExpression expression
  inventory = flattenBinders found
  declared = [name | Declared name <- inventory]
  placed = declared <> [name | Matched name <- inventory]
  everything = parameters <> mapMaybe nameOf inventory
  nameOf binder = case binder of
    Declared name -> Just name
    Matched name -> Just name
    Framed name -> Just name
    Used _ -> Nothing
    Scoped _ -> Nothing

{-| A name a body binds: by `let`, or by a pattern the compiled code matches
    (a `match` arm or an `if let`), each of which takes a slot; or by a pattern
    the tree walker binds through a frame of its own (`for`, `while let`,
    `let ... else`, a destructuring `let`), which is read by name. -}
data Binder = Declared Text | Matched Text | Framed Text | Used Text | Scoped [Binder]

flattenBinders :: [Binder] -> [Binder]
flattenBinders = walk []
 where
  walk pending entries = case entries of
    [] -> case pending of
      [] -> []
      next : rest -> walk rest next
    Scoped nested : rest -> walk (rest : pending) nested
    Used _ : rest -> walk pending rest
    binder : rest -> binder : walk pending rest

validAccesses :: Set Text -> Set Text -> [Binder] -> Bool
validAccesses eligible = walk
 where
  walk _ [] = True
  walk active (entry : rest) = case entry of
    Scoped nested -> walk active nested && walk active rest
    Used name ->
      (Set.notMember name eligible || Set.member name active) && walk active rest
    Declared name -> bound name
    Matched name -> bound name
    Framed name -> bound name
   where
    bound name = walk (Set.insert name active) rest

fromBlock :: Located Block -> [Binder]
fromBlock (Located _ block) =
  [Scoped (concatMap fromStatement (blockStatements block) <> foldMap fromExpression (blockResult block))]

fromStatement :: Located Statement -> [Binder]
fromStatement (Located _ statement) = case statement of
  DeclarationStatement (Located _ (BindingDeclaration _ _ name _ value)) ->
    fromExpression value <> [Declared (locatedValue name)]
  DeclarationStatement _ -> []
  ExpressionStatement expression -> fromExpression expression
  ReturnStatement value -> foldMap fromExpression value
  BreakStatement _ value -> foldMap fromExpression value
  ContinueStatement _ -> []
  LetElseStatement pattern' subject fallback ->
    fromExpression subject <> fromBlock fallback <> framed pattern'
  LetPatternStatement _ pattern' _ subject -> fromExpression subject <> framed pattern'
  InvalidStatement -> []

fromExpression :: Located Expression -> [Binder]
fromExpression (Located _ expression) = case expression of
  UnaryExpression _ operand -> fromExpression operand
  BinaryExpression left _ right -> fromExpression left <> fromExpression right
  CallExpression callee arguments -> fromExpression callee <> concatMap fromExpression arguments
  MemberExpression target _ -> fromExpression target
  IndexExpression target index -> fromExpression target <> fromExpression index
  RangeExpression lower _ upper -> foldMap fromExpression lower <> foldMap fromExpression upper
  TryExpression target -> fromExpression target
  AwaitExpression target -> fromExpression target
  TupleExpression members -> concatMap fromExpression members
  ArrayExpression members -> concatMap fromExpression members
  SetExpression members -> concatMap fromExpression members
  UnsafeExpression _ body -> fromBlock body
  MacroCall _ arguments -> concatMap fromExpression arguments
  ScopeExpression body -> fromBlock body
  TypeApplication target _ -> fromExpression target
  RecordExpression _ fields -> concatMap fromField fields
  RecordUpdateExpression _ source fields -> fromExpression source <> concatMap fromField fields
  BlockExpression block -> fromBlock block
  IfExpression condition thenBlock elseBranch ->
    fromExpression condition <> fromBlock thenBlock <> foldMap fromExpression elseBranch
  IfLetExpression pattern' subject thenBlock elseBranch ->
    fromExpression subject <> [Scoped (matched pattern' <> fromBlock thenBlock)]
      <> foldMap fromExpression elseBranch
  MatchExpression subject arms -> fromExpression subject <> concatMap fromArm arms
  WhileExpression _ condition body -> fromExpression condition <> fromBlock body
  WhileLetExpression _ pattern' subject body ->
    fromExpression subject <> [Scoped (framed pattern' <> fromBlock body)]
  LoopExpression _ body -> fromBlock body
  ForExpression _ binder iterated body ->
    fromExpression iterated <> [Scoped (framed binder <> fromBlock body)]
  {-| The element binds one slot like a pattern with one name; the source and
      body are read for the bindings they declare. -}
  ComptimeForExpression loop ->
    fromExpression (comptimeForSource loop)
      <> [Scoped (Framed (locatedValue (comptimeForElement loop))
          : fromBlock (comptimeForBody loop))]
  LiteralExpression _ -> []
  NameExpression (first :| _) -> [Used first]
  LambdaExpression function -> map Used (Set.toAscList (reachableNames function))
  InvalidExpression -> []
 where
  fromField (Located _ field) = case fieldInitValue field of
    Just value -> fromExpression value
    Nothing -> [Used (locatedValue (fieldInitName field))]
  fromArm (Located _ arm) =
    [Scoped (matched (armPattern arm) <> foldMap fromExpression (armGuard arm)
      <> fromExpression (armBody arm))]

matched :: Located Pattern -> [Binder]
matched = map Matched . patternNames

framed :: Located Pattern -> [Binder]
framed = map Framed . patternNames
