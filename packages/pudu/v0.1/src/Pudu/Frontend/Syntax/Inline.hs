{-| @Program.Syntax.Inline — splices statement blocks that bind nothing.

    A block standing as a statement has its value discarded, so when it binds
    no name its statements, and its result as one more statement, mean the same
    written directly into the enclosing block. Generated code is built of such
    blocks, one per unrolled step, and both running and reading it are simpler
    without them. -}
module Pudu.Frontend.Syntax.Inline
  ( inlineStatements
  ) where

import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Block (..), Expression (..), Statement (..))

inlineStatements :: [Located Statement] -> [Located Statement]
inlineStatements = concatMap inline

inline :: Located Statement -> [Located Statement]
inline held@(Located at value) = case value of
  ExpressionStatement (Located _ (BlockExpression (Located _ inner)))
    | not (any binds (blockStatements inner)) ->
        inlineStatements (blockStatements inner <> maybe [] (pure . Located at . ExpressionStatement) (blockResult inner))
  _ -> [held]
 where
  binds (Located _ entry) = case entry of
    DeclarationStatement _ -> True
    LetElseStatement {} -> True
    LetPatternStatement {} -> True
    _ -> False
