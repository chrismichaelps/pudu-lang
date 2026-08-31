{-| @Type.Check.Collection — collection checks that wait for context -}
module Pudu.Type.Check.Collection
  ( requireConcreteSetLiteral
  ) where

import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Expression (..)
  , FieldInit (..)
  , MatchArm (..)
  )
import Pudu.Source (Span)
import Pudu.Type.Env (Checker, lookupRecordedExpression, report)
import Pudu.Type.Unify (zonk)
import Pudu.Type.Value (Type (..), nominalName)

{-| Refuse every unresolved empty Set below an expression boundary, after the
    boundary has supplied every available constraint. The checker records the
    type variable at each literal span during inference; looking it up here
    preserves contextual forms such as `take(#{})` while catching nested forms
    such as `[#{\}]` that would otherwise leak a metavariable. -}
requireConcreteSetLiteral :: Span -> Tree.Expression -> Type -> Checker ()
requireConcreteSetLiteral spanValue expression inferred =
  mapM_ requireConcrete (emptySets (Located spanValue expression))
 where
  requireConcrete (Located literalSpan _) = do
    recorded <- lookupRecordedExpression literalSpan
    resolved <- zonk (maybe inferred id recorded)
    case resolved of
      NominalType identity [VariableType _]
        | nominalName identity == "Set" ->
            report "E3037" literalSpan
              "an empty Set needs an element type"
              (Just "annotate it, for example: let values: Set[Int] = #{}")
      _ -> pure ()

emptySets :: Located Expression -> [Located Expression]
emptySets located@(Located _ expression) = case expression of
  SetExpression [] -> [located]
  SetExpression members -> descend members
  UnaryExpression _ operand -> descend [operand]
  BinaryExpression left _ right -> descend [left, right]
  CallExpression callee arguments -> descend (callee : arguments)
  MemberExpression target _ -> descend [target]
  IndexExpression target index -> descend [target, index]
  TryExpression target -> descend [target]
  AwaitExpression target -> descend [target]
  TupleExpression members -> descend members
  ArrayExpression members -> descend members
  MacroCall _ arguments -> descend arguments
  UnsafeExpression _ block -> blockEmptySets block
  ScopeExpression block -> blockEmptySets block
  TypeApplication target _ -> descend [target]
  RecordExpression _ fields ->
    descend [value | Located _ field <- fields, Just value <- [fieldInitValue field]]
  BlockExpression block -> blockEmptySets block
  IfExpression condition thenBlock elseBranch ->
    descend (condition : maybe [] pure elseBranch) <> blockEmptySets thenBlock
  IfLetExpression _ subject thenBlock elseBranch ->
    descend (subject : maybe [] pure elseBranch) <> blockEmptySets thenBlock
  MatchExpression subject arms ->
    descend (subject : concatMap armExpressions arms)
  WhileExpression _ condition body -> descend [condition] <> blockEmptySets body
  WhileLetExpression _ _ subject body -> descend [subject] <> blockEmptySets body
  LoopExpression _ body -> blockEmptySets body
  ForExpression _ _ source body -> descend [source] <> blockEmptySets body
  LiteralExpression _ -> []
  NameExpression _ -> []
  LambdaExpression _ -> []
  InvalidExpression -> []
 where
  descend = concatMap emptySets

blockEmptySets :: Located Block -> [Located Expression]
blockEmptySets (Located _ block) = maybe [] emptySets (blockResult block)

armExpressions :: Located MatchArm -> [Located Expression]
armExpressions (Located _ arm) = maybe [] pure (armGuard arm) <> [armBody arm]
