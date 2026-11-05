{-| @Program.Type.Check.Propagation — the match that only carries its failure on

    An arm that reconstructs its own scrutinee's failure unchanged is not a
    decision, it is punctuation, and `?` is the word for it. Recognising that
    shape is a narrow question, and it is asked in one place so the rule and the
    message that teaches it cannot drift apart. [[ADR-0011]] states the rule. -}
module Pudu.Type.Check.Propagation
  ( reportRedundantPropagation
  , markResultSpine
  , markBodyResult
  ) where

import Data.List.NonEmpty (NonEmpty ((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Expression (..)
  , FunctionBody (..)
  , MatchArm (..)
  , Pattern (..)
  , Statement (..)
  )
import Pudu.Source (Span)
import Pudu.Type.Env (Checker, isResultSpan, markResultSpans, warn)
import Pudu.Type.Value (Type (..))

{-| Warn when every failure arm of a match rebuilds what it received and the
    enclosing function carries the same shape.

    Both halves are required. An arm that transforms the payload decides
    something, and a match that changes carrier is the one conversion `?` cannot
    perform — `Option` in and `Result` out is exactly what `okOr` is for. -}
reportRedundantPropagation :: Span -> [Located MatchArm] -> Type -> Checker ()
reportRedundantPropagation spanValue arms declaredResult = do
  positioned <- isResultSpan spanValue
  case failureConstructor declaredResult of
    Nothing -> pure ()
    Just carrier -> case filter (mentions carrier) arms of
      [] -> pure ()
      first : rest
        | all (isPassThrough positioned carrier) (first : rest) ->
            warn "W3003" (locatedSpan first)
              "this match only propagates its failure"
              ( Just
                  ( "this arm rebuilds what it received; write ? after the "
                      <> "subject and drop the match"
                  )
              )
        | otherwise -> pure ()

{-| The constructor a carrier's failure arm names, or nothing when the declared
    result is not a carrier at all. -}
failureConstructor :: Type -> Maybe Text
failureConstructor declaredResult = case declaredResult of
  NominalType "Result" [_, _] -> Just "Err"
  NominalType "Option" [_] -> Just "None"
  _ -> Nothing

{-| Whether an arm names the carrier's failure constructor, which is how the
    caller knows it has seen a failure arm rather than a success one. -}
mentions :: Text -> Located MatchArm -> Bool
mentions carrier (Located _ arm) = case armPattern arm of
  Located _ (ConstructorPattern path _) -> lastSegment path == carrier
  _ -> False

{-| Whether an arm binds a failure payload and hands back exactly that payload,
    rewrapped in exactly the constructor it came out of.

    A guarded arm is never a pass-through: the guard is the decision. `None`
    carries nothing, so its pass-through binds nothing and answers the bare
    constructor. An arm that only produces the failure as a value hands it to
    the function's caller only when the match stands in result position;
    elsewhere the value is kept and the function goes on, which `?` would not
    do, so only an arm that writes `return` counts there. -}
isPassThrough :: Bool -> Text -> Located MatchArm -> Bool
isPassThrough positioned carrier (Located _ arm) = case armGuard arm of
  Just _ -> False
  Nothing -> case unwrapBody positioned (armBody arm) of
    Nothing -> False
    Just body -> case armPattern arm of
      Located _ (ConstructorPattern _ [Located _ (BindingPattern name)]) ->
        returnsRewrapped carrier (locatedValue name) body
      Located _ (ConstructorPattern _ []) -> namesOnly carrier body
      _ -> False

{-| Whether a body is `Carrier(name)` and nothing else. -}
returnsRewrapped :: Text -> Text -> Located Expression -> Bool
returnsRewrapped carrier name body = case locatedValue body of
  CallExpression callee [argument] ->
    namesOnly carrier callee && namesOnly name argument
  _ -> False

{-| Whether an expression is exactly one name, spelled unqualified. -}
namesOnly :: Text -> Located Expression -> Bool
namesOnly wanted (Located _ expression) = case expression of
  NameExpression (single :| []) -> single == wanted
  _ -> False

{-| The expression an arm's body hands to the function's caller.

    A writer spells the same arm three ways — `=> Err(e)`, `=> { Err(e) }`, and
    `=> { return Err(e) }` — and 24 of the 49 sites this rule was written for
    used the third. In result position all three mean one thing; elsewhere only
    the `return` form leaves the function. A block holding anything besides
    that one expression is doing more than propagating and is left alone. -}
unwrapBody :: Bool -> Located Expression -> Maybe (Located Expression)
unwrapBody positioned located@(Located _ expression) = case expression of
  BlockExpression (Located _ block) -> case (blockStatements block, blockResult block) of
    ([], Just result) -> unwrapBody positioned result
    ([Located _ (ReturnStatement (Just carried))], Nothing) -> unwrapBody True carried
    _ -> Nothing
  _
    | positioned -> Just located
    | otherwise -> Nothing

{-| Mark an expression standing in result position and, through blocks and
    branches, every tail that hands its value on to it. -}
markResultSpine :: Located Expression -> Checker ()
markResultSpine = markResultSpans . resultSpine

resultSpine :: Located Expression -> [Span]
resultSpine (Located spanValue expression) = spanValue : case expression of
  BlockExpression block -> blockSpine block
  IfExpression _ thenBlock elseBranch -> blockSpine thenBlock <> maybe [] resultSpine elseBranch
  IfLetExpression _ _ thenBlock elseBranch -> blockSpine thenBlock <> maybe [] resultSpine elseBranch
  MatchExpression _ arms -> concatMap (resultSpine . armBody . locatedValue) arms
  _ -> []
  where
    blockSpine (Located _ block) = maybe [] resultSpine (blockResult block)

lastSegment :: ModuleName -> Text
lastSegment = NonEmpty.last . moduleNameSegments

{-| Mark a function or closure body's result: an expression body, or a block
    body's tail. -}
markBodyResult :: FunctionBody -> Checker ()
markBodyResult body = case body of
  ExpressionBody expression -> markResultSpine expression
  BlockBody (Located _ block) -> mapM_ markResultSpine (blockResult block)
