{-| @Pudu.Eval.Compile.Layout.Module — where a compiled body keeps its locals -}
module Pudu.Eval.Compile.Layout
  ( slotLayout
  ) where

import Data.List (nub)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Frontend.Expand.Substitute (patternNames)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree

{-| The positions of a body's parameters and of every `let` it declares, or
    nothing when some name is bound twice anywhere in the body.

    Only a body that declares a local, and whose names are all distinct, is
    given slots. Then no binding in
    it shadows another, so a name in the layout means its slot wherever it is
    written, and a name bound by a pattern is never a slot's name. A function
    literal written inside the body is its own body and is not looked into. -}
slotLayout :: [Text] -> FunctionBody -> Maybe (Map Text Int)
slotLayout parameters body
  -- A body with no locals of its own reads only its parameters, and setting
  -- up slots for a call costs more than it saves there.
  | null declared = Nothing
  | nub everything /= everything = Nothing
  | otherwise = Just (Map.fromList (zip (parameters <> declared) [0 ..]))
 where
  found = case body of
    BlockBody block -> fromBlock block
    ExpressionBody expression -> fromExpression expression
  declared = [name | Declared name <- found]
  everything = parameters <> map nameOf found
  nameOf binder = case binder of
    Declared name -> name
    Matched name -> name

{-| A name a body binds: by `let`, which takes a slot, or by a pattern, which
    binds through a frame. -}
data Binder = Declared Text | Matched Text

fromBlock :: Located Block -> [Binder]
fromBlock (Located _ block) =
  concatMap fromStatement (blockStatements block) <> foldMap fromExpression (blockResult block)

fromStatement :: Located Statement -> [Binder]
fromStatement (Located _ statement) = case statement of
  DeclarationStatement (Located _ (BindingDeclaration _ _ name _ value)) ->
    Declared (locatedValue name) : fromExpression value
  DeclarationStatement _ -> []
  ExpressionStatement expression -> fromExpression expression
  ReturnStatement value -> foldMap fromExpression value
  BreakStatement _ value -> foldMap fromExpression value
  ContinueStatement _ -> []
  LetElseStatement pattern' subject fallback ->
    matched pattern' <> fromExpression subject <> fromBlock fallback
  LetPatternStatement _ pattern' _ subject -> matched pattern' <> fromExpression subject
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
    matched pattern' <> fromExpression subject <> fromBlock thenBlock <> foldMap fromExpression elseBranch
  MatchExpression subject arms -> fromExpression subject <> concatMap fromArm arms
  WhileExpression _ condition body -> fromExpression condition <> fromBlock body
  WhileLetExpression _ pattern' subject body ->
    matched pattern' <> fromExpression subject <> fromBlock body
  LoopExpression _ body -> fromBlock body
  ForExpression _ binder iterated body -> matched binder <> fromExpression iterated <> fromBlock body
  LiteralExpression _ -> []
  NameExpression _ -> []
  LambdaExpression _ -> []
  InvalidExpression -> []
 where
  fromField (Located _ field) = foldMap fromExpression (fieldInitValue field)
  fromArm (Located _ arm) =
    matched (armPattern arm) <> foldMap fromExpression (armGuard arm) <> fromExpression (armBody arm)

matched :: Located Pattern -> [Binder]
matched = map Matched . patternNames
