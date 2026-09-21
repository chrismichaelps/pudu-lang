{-| @Program.Lsp.Receiver — the expression a member access is on -}
module Pudu.Lsp.Receiver
  ( MemberSite (..)
  , memberSiteAt
  , receiverType
  ) where

import Control.Applicative ((<|>))
import Pudu.Frontend.Token (Keyword (..), SymbolKind (..), Token (..), TokenKind (..))
import Pudu.Source (spanEnd, spanStart, unOffset)
import Pudu.Type (Type, TypeInfo, typeAtOffsets, widestWithin)

{-| A member being written: where its dot is, and the offsets the receiver
    before the dot occupies, from its first scalar to just after its last. -}
data MemberSite = MemberSite
  { siteDot :: !Int
  , siteReceiver :: !(Int, Int)
  }
  deriving stock (Eq, Show)

{-| The member access the cursor at `offset` is completing, read from the
    lexer's tokens, which exist whether or not the text parses.

    The cursor is right after a dot, or inside or at the end of the name
    written after one. The receiver is the whole postfix expression before the
    dot: `produce(1).` is on the call, not on `1`; `items[0].` on the element;
    `a.b.c.` on `a.b.c`; `(x + y).` on the group; `"text".` on the literal.
    Whitespace and comments before the dot are trivia and change nothing. A
    range operator is not a dot, and a dot with no receiver before it is not a
    member access. -}
memberSiteAt :: [Token] -> Int -> Maybe MemberSite
memberSiteAt tokens offset = case before of
  latest : rest
    | isName latest, endOf latest >= offset, dot : receiver <- rest, isDot dot -> site dot receiver
  dot : receiver | isDot dot -> site dot receiver
  _ -> Nothing
 where
  before =
    reverse
      [ token
      | token <- tokens
      , tokenKind token /= EndOfFile
      , startOf token < offset
      ]
  site dot receiver = do
    start <- receiverStart receiver
    last' <- case receiver of
      token : _ -> Just token
      [] -> Nothing
    pure (MemberSite (startOf dot) (start, endOf last'))

{-| Where the postfix expression ending at the head of these tokens (which
    run backwards from the dot) starts. -}
receiverStart :: [Token] -> Maybe Int
receiverStart tokens = case tokens of
  token : rest
    | atom token -> Just (continue (startOf token) rest)
    | Just opener <- closerOf (tokenKind token) -> do
        (openToken, more) <- matching opener (tokenKind token) (0 :: Int) rest
        pure (afterGroup (startOf openToken) more)
    | tokenKind token == Symbol SymQuestion -> receiverStart rest
  _ -> Nothing
 where
  -- After a complete operand, a dot before it extends the chain leftwards.
  continue start rest = case rest of
    dot : more | isDot dot, Just earlier <- receiverStart more -> earlier
    _ -> start
  -- A group is a call's or an index's arguments when a callee stands right
  -- before it; otherwise it is the whole operand.
  afterGroup start rest = case rest of
    callee : _
      | atom callee || closes callee || tokenKind callee == Symbol SymQuestion
      , Just earlier <- receiverStart rest -> earlier
    _ -> continue start rest
  closes token = case closerOf (tokenKind token) of
    Just _ -> True
    Nothing -> False
  matching opener closer depth rest = case rest of
    [] -> Nothing
    token : more
      | tokenKind token == closer -> matching opener closer (depth + 1) more
      | tokenKind token == opener, depth == 0 -> Just (token, more)
      | tokenKind token == opener -> matching opener closer (depth - 1) more
      | otherwise -> matching opener closer depth more

closerOf :: TokenKind -> Maybe TokenKind
closerOf kind = case kind of
  Symbol SymRightParen -> Just (Symbol SymLeftParen)
  Symbol SymRightBracket -> Just (Symbol SymLeftBracket)
  Symbol SymRightBrace -> Just (Symbol SymLeftBrace)
  _ -> Nothing

{-| A token that is a whole operand on its own. -}
atom :: Token -> Bool
atom token = case tokenKind token of
  Identifier _ -> True
  IntegerLiteral _ -> True
  FloatLiteral _ -> True
  DecimalLiteral _ -> True
  StringLiteral _ -> True
  TemplateLiteral _ -> True
  CharLiteral _ -> True
  Keyword KwTrue -> True
  Keyword KwFalse -> True
  _ -> False

isName :: Token -> Bool
isName token = case tokenKind token of
  Identifier _ -> True
  _ -> False

isDot :: Token -> Bool
isDot token = tokenKind token == Symbol SymDot

startOf :: Token -> Int
startOf = unOffset . spanStart . tokenSpan

endOf :: Token -> Int
endOf = unOffset . spanEnd . tokenSpan

{-| The type the checker gave the receiver: the expression recorded at exactly
    its offsets, or failing that the widest expression inside them — the call
    rather than its last argument, the group's contents rather than a part. -}
receiverType :: TypeInfo -> MemberSite -> Maybe Type
receiverType types (MemberSite _ (start, end)) =
  typeAtOffsets start end types <|> widestWithin start end types
