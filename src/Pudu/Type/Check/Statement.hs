{-| @Type.Check.Statement — what a block and the statements in it mean.

    A statement contains expressions and declarations, and both reach statements
    again, so what this module needs of them arrives as a record rather than an
    import. -}
module Pudu.Type.Check.Statement
  ( FunctionRole (..)
  , StatementNeeds (..)
  , checkAgainst
  , checkBlock
  , checkBlockAgainst
  , checkMember
  ) where

import Control.Monad (when)
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Declaration (..)
  , Expression (..)
  , Function (..)
  , MatchArm (..)
  , Statement (..)
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , bindName
  , inTypeScope
  , LoopFrame (..)
  , loopTarget
  , markLoopBroken
  , warn
  , recordExpression
  , report
  )
import Pudu.Type.Check.Pattern (bindPattern)
import Pudu.Type.Check.Call (throughBorrow)
import Pudu.Type.Check.Signature
  ( nonMutatingMethods
  )
import Pudu.Type.Check.Rule
  ( enclosingReturnType
  , selfName
  )
import Pudu.Type.Exhaust (checkExhaustive)
import Pudu.Type.Formation
  ( formOptionalType
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value
  ( NominalId (..)
  , monotype
  , Type (..)
  , boolType
  )

{-| @Check.Statement.Needs — what a statement needs of what it contains.

    A statement holds expressions, may declare something, and a function
    declared inside one is checked as a function. All three reach statements
    again, which is why they arrive rather than being imported. -}
data StatementNeeds = StatementNeeds
  { statementExpression :: DeclaredTypes -> [Text] -> Located Expression -> Checker Type
  , statementDeclaration :: DeclaredTypes -> Located Declaration -> Checker ()
  , statementFunction ::
      FunctionRole
      -> DeclaredTypes
      -> [Text]
      -> [(Text, [NominalId])]
      -> Maybe NominalId
      -> Function
      -> Checker ()
  }

checkBlock :: StatementNeeds -> DeclaredTypes -> [Text] -> Located Block -> Checker Type
checkBlock needs declared rigid (Located _ block) = do
  mapM_ (checkStatement needs declared rigid) (blockStatements block)
  case blockResult block of
    Nothing -> pure UnitTypeValue
    Just expression -> statementExpression needs declared rigid expression

checkStatement :: StatementNeeds -> DeclaredTypes -> [Text] -> Located Statement -> Checker ()
checkStatement needs declared rigid (Located spanValue statement) = case statement of
  DeclarationStatement (Located _ (BindingDeclaration _ _ name annotation value)) -> do
    expected <- formOptionalType declared rigid annotation
    actual <- case annotation of
      Just _ -> checkAgainst needs declared rigid expected value
      Nothing -> statementExpression needs declared rigid value
    unified <- unify (locatedSpan value) expected actual
    {-| The name a binding introduces carries the type it was given, so an
        editor asked about `text` in `let text = "hello"` can answer about
        `text`. Only uses were recorded before, and a reader points at the
        place a name is introduced at least as often as at a use of it. -}
    resolved <- zonk unified
    recordExpression (locatedSpan name) resolved
    bindName (locatedValue name) (monotype unified)
  DeclarationStatement other -> statementDeclaration needs declared other
  ExpressionStatement expression -> do
    _ <- statementExpression needs declared rigid expression
    reportDiscardedResult needs declared rigid expression
  ReturnStatement value -> do
    actual <- case value of
      Nothing -> pure UnitTypeValue
      Just expression -> statementExpression needs declared rigid expression
    expected <- enclosingReturnType selfName
    case value of
      Nothing -> pure ()
      Just expression -> do
        _ <- unify (locatedSpan expression) expected actual
        pure ()
  BreakStatement label value -> checkBreak needs declared rigid spanValue label value
  ContinueStatement _ -> pure ()
  InvalidStatement -> pure ()

{-| Check a `break`, against the loop it leaves.

    A `break` carrying a value must leave a `loop`: `while` and `for` finish on
    their own condition, so a value carried out of one would be produced on
    some runs and not others, and there is no type for that. Reported here
    rather than made to work, because the honest fix is a `loop` and saying so
    is more use than inventing a default.

    Every `break` leaving the same loop must carry the same type, which is what
    unifying against the loop's result variable enforces. -}

{-| Check a `break`, against the loop it leaves.

    A `break` carrying a value must leave a `loop`: `while` and `for` finish on
    their own condition, so a value carried out of one would be produced on
    some runs and not others, and there is no type for that. Reported here
    rather than made to work, because the honest fix is a `loop` and saying so
    is more use than inventing a default.

    Every `break` leaving the same loop must carry the same type, which is what
    unifying against the loop's result variable enforces. -}
checkBreak
  :: StatementNeeds
  -> DeclaredTypes
  -> [Text]
  -> Span
  -> Maybe (Located Text)
  -> Maybe (Located Expression)
  -> Checker ()
checkBreak needs declared rigid spanValue label value = do
  target <- loopTarget (fmap locatedValue label)
  markLoopBroken (fmap locatedValue label)
  case (target, value) of
    (_, Nothing) -> pure ()
    (Nothing, Just expression) -> do
      _ <- statementExpression needs declared rigid expression
      pure ()
    (Just frame, Just expression) -> do
      carried <- statementExpression needs declared rigid expression
      if frameCarries frame
        then do
          _ <- unify (locatedSpan expression) (frameResult frame) carried
          pure ()
        else
          report "E3029" spanValue "this loop cannot carry a value out of a break"
            ( Just
                ( "while and for finish when their own condition does, so a value "
                    <> "carried out would exist on some runs and not others; use loop"
                )
            )

checkGuard :: StatementNeeds -> DeclaredTypes -> [Text] -> Located Expression -> Checker ()
checkGuard needs declared rigid guard = do
  guardType <- statementExpression needs declared rigid guard
  _ <- unify (locatedSpan guard) boolType guardType
  pure ()

{-| Check one expression and record the type it was given, so tooling can
    report it later. -}
{-| The way [[Type Check Call]] checks an expression.

    A call's arguments are expressions and an expression may be a call, so one
    direction has to be a capability rather than an import. This is that
    direction. -}

checkAgainst :: StatementNeeds -> DeclaredTypes -> [Text] -> Type -> Located Expression -> Checker Type
checkAgainst needs declared rigid expected located@(Located spanValue expression) = do
  resolved <- zonk expected
  if not (worthPushing resolved)
    then fallback
    else case expression of
      IfExpression condition thenBlock elseBranch -> do
        conditionType <- statementExpression needs declared rigid condition
        _ <- unify (locatedSpan condition) boolType conditionType
        _ <- checkBlockAgainst needs declared rigid resolved thenBlock
        mapM_ (checkAgainst needs declared rigid resolved) elseBranch
        recordExpression spanValue resolved
        pure resolved
      IfLetExpression pattern' subject thenBlock (Just elseBranch) -> do
        borrowed <- statementExpression needs declared rigid subject
        subjectType <- throughBorrow borrowed
        inTypeScope $ do
          bindPattern declared rigid pattern' subjectType
          _ <- checkBlockAgainst needs declared rigid resolved thenBlock
          pure ()
        _ <- checkAgainst needs declared rigid resolved elseBranch
        recordExpression spanValue resolved
        pure resolved
      MatchExpression scrutinee arms -> do
        subject <- statementExpression needs declared rigid scrutinee
        resolvedSubject <- zonk subject
        mapM_ (checkArmAgainst needs declared rigid resolved resolvedSubject) arms
        checkExhaustive spanValue resolvedSubject arms
        recordExpression spanValue resolved
        pure resolved
      ArrayExpression members
        | NominalType identity [element] <- resolved
        , nominalName identity == "Array" -> do
            mapM_ (checkAgainst needs declared rigid element) members
            recordExpression spanValue resolved
            pure resolved
      BlockExpression block -> do
        _ <- checkBlockAgainst needs declared rigid resolved block
        recordExpression spanValue resolved
        pure resolved
      _ -> fallback
 where
  {-| Returning what `unify` produced, rather than the inferred type, is what
      keeps a failure from being reported twice: the caller unifies again
      against the same expectation, and `ErrorType` absorbs there. -}
  fallback = do
    actual <- statementExpression needs declared rigid located
    unify spanValue expected actual

  {-| Only a dynamic expectation changes an outcome, and pushing one inward
      costs a walk. Anything else is left to inference, which already handles
      it and produces the diagnostics readers are used to. -}
  worthPushing typeValue = case typeValue of
    DynamicTypeValue _ -> True
    NominalType _ arguments -> any worthPushing arguments
    TupleTypeValue members -> any worthPushing members
    ReferenceTypeValue _ target -> worthPushing target
    _ -> False

{-| A block checked against an expectation pushes it to the trailing
    expression, which is the block's value. -}

{-| A block checked against an expectation pushes it to the trailing
    expression, which is the block's value. -}
checkBlockAgainst :: StatementNeeds -> DeclaredTypes -> [Text] -> Type -> Located Block -> Checker Type
checkBlockAgainst needs declared rigid expected (Located blockSpan block) = do
  mapM_ (checkStatement needs declared rigid) (blockStatements block)
  case blockResult block of
    Nothing -> do
      _ <- unify blockSpan expected UnitTypeValue
      pure UnitTypeValue
    Just expression -> checkAgainst needs declared rigid expected expression

checkArmAgainst
  :: StatementNeeds
  -> DeclaredTypes -> [Text] -> Type -> Type -> Located MatchArm -> Checker ()
checkArmAgainst needs declared rigid expected subject (Located _ arm) = inTypeScope $ do
  bindPattern declared rigid (armPattern arm) subject
  mapM_ (checkGuard needs declared rigid) (armGuard arm)
  _ <- checkAgainst needs declared rigid expected (armBody arm)
  pure ()

reportDiscardedResult :: StatementNeeds -> DeclaredTypes -> [Text] -> Located Expression -> Checker ()
reportDiscardedResult needs declared rigid (Located spanValue expression) = case expression of
  CallExpression callee _ -> case locatedValue callee of
    MemberExpression receiver member
      | locatedValue member `elem` nonMutatingMethods -> do
          receiverType <- statementExpression needs declared rigid receiver
          resolved <- zonk receiverType
          when (isCollection resolved) $
            warn "W3002"
              spanValue
              ( locatedValue member
                  <> " returns a new collection and this result is discarded"
              )
              ( Just
                  ( "assign it back, as in value = value."
                      <> locatedValue member
                      <> "(...), or remove the call"
                  )
              )
    _ -> pure ()
  _ -> pure ()
 where
  isCollection resolved = case resolved of
    NominalType identity _ -> nominalName identity `elem` ["Array", "Str"]
    ReferenceTypeValue _ inner -> isCollection inner
    _ -> False

{-| Check a trait member with a rigid `Self` bound, or an implementation member
    with `Self` aliased to its canonical target. -}
checkMember
  :: StatementNeeds
  -> DeclaredTypes
  -> [Text]
  -> [(Text, [NominalId])]
  -> Maybe NominalId
  -> Located Function
  -> Checker ()
checkMember needs declared enclosing enclosingBounds selfBound (Located _ value) =
  statementFunction needs MemberFunction declared enclosing enclosingBounds selfBound value

{-| @Type.Check.FunctionRole — whether a function owns the module-scope name it
    is written under.

    A member does not: its scheme is recorded under a qualified key, and the
    plain name may belong to an unrelated free function in the same module.
    Tying a member's body to whatever that name happens to hold would unify two
    signatures that were never meant to meet. -}
data FunctionRole = ModuleScopeFunction | MemberFunction
  deriving stock (Eq, Show)
