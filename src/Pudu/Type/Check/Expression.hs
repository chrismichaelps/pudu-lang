{-| @Type.Check.Expression — what an expression's type is.

    An expression contains blocks and blocks contain expressions, so one of the
    two directions has to be an argument rather than an import. This is that
    direction, the shape the parser, the call checker, and record construction
    already use for their own recursion. -}
module Pudu.Type.Check.Expression
  ( CheckSurroundings (..)
  , checkExpression
  ) where

import Control.Monad (foldM, unless)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.IntegerLiteral (ParsedInteger (..), parseIntegerLiteral)
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Expression (..)
  , Function (..)
  , FunctionBody (..)
  , MatchArm (..)
  , Parameter
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , bindName
  , finalizeIntegerLiteralsBetween
  , finalizeIntegerLiteralsSince
  , freshVariable
  , inTypeScope
  , inTypeScopeWith
  , integerLiteralCheckpoint
  , enterLoop
  , enterUnsafe
  , leaveLoop
  , withoutLoops
  , lookupName
  , recordExpression
  , report
  , validateIntegerLiteralsSince
  )
import Pudu.Type.Check.Pattern (bindPattern)
import Pudu.Type.Check.Iteration (iterationElement)
import Pudu.Type.Check.Safety
  ( checkComptimeCall
  , checkUnsafeCall
  , reportUnusedCapabilities
  )
import Pudu.Type.Check.Call
  ( CheckExpression (..)
  , checkCallee
  , throughBorrow
  , traitQualifiedCall
  )
import Pudu.Type.Check.Record
  ( CheckValue (..)
  , recordType
  )
import Pudu.Type.Check.Rule
  ( awaitType
  , binaryType
  , enclosingFunctionType
  , enclosingReturnType
  , instantiateWith
  , callType
  , elementType
  , literalType
  , memberType
  , nameType
  , selfName
  , namedVariantAsValue
  , qualifiedMemberType
  , tryType
  , unaryType
  )
import Pudu.Type.Exhaust (checkExhaustive)
import Pudu.Type.Formation
  ( formOptionalType
  , formType
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value
  ( monotype
  , Type (..)
  , boolType
  , integerType
  )

{-| @Check.Expression.CheckSurroundings — what an expression needs of the
    constructs around it.

    A block's type is the statements in it, a value checked against an expected
    type may push that type inward, and a function literal binds parameters —
    all three are decided where declarations and statements are, and all three
    are reached from inside an expression. -}
data CheckSurroundings = CheckSurroundings
  { aroundBlock :: DeclaredTypes -> [Text] -> Located Block -> Checker Type
  , aroundAgainst :: DeclaredTypes -> [Text] -> Type -> Located Expression -> Checker Type
  , aroundParameter :: DeclaredTypes -> [Text] -> Located Parameter -> Checker Type
  }

expressionChecker :: CheckSurroundings -> CheckExpression
expressionChecker around = CheckExpression (checkExpression around)

checkExpression
  :: CheckSurroundings -> DeclaredTypes -> [Text] -> Located Expression -> Checker Type
checkExpression around declared rigid (Located spanValue expression) = do
  typeValue <- inferExpression around declared rigid spanValue expression
  resolved <- zonk typeValue
  recordExpression spanValue resolved
  pure typeValue

inferExpression
  :: CheckSurroundings -> DeclaredTypes -> [Text] -> Span -> Expression -> Checker Type
inferExpression around declared rigid spanValue expression = case expression of
  LiteralExpression literal -> literalType spanValue literal
  NameExpression names -> nameType spanValue names
  UnaryExpression operator operand -> do
    actual <- checkExpression around declared rigid operand
    unaryType spanValue operator actual
  BinaryExpression left operator right -> do
    leftType <- checkExpression around declared rigid left
    rightType <- checkExpression around declared rigid right
    binaryType spanValue operator leftType rightType
  CallExpression callee arguments -> do
    checkUnsafeCall spanValue callee
    checkComptimeCall spanValue callee
    dispatched <- traitQualifiedCall (expressionChecker around) declared rigid callee arguments
    case dispatched of
      Just (calleeType, argumentTypes) -> callType spanValue calleeType argumentTypes
      Nothing -> do
        calleeType <- checkCallee (expressionChecker around) declared rigid callee
        argumentTypes <- mapM (checkExpression around declared rigid) arguments
        callType spanValue calleeType argumentTypes
  MemberExpression target member -> do
    {-| A variant that named its payload is refused here rather than inside
        qualified member typing, which a call reaches twice — once for the
        callee and once for the expression — and would report twice. -}
    refused <- namedVariantAsValue spanValue (locatedValue member)
    qualified <- case refused of
      Just value -> pure (Just value)
      Nothing -> qualifiedMemberType spanValue (locatedValue target) (locatedValue member)
    case qualified of
      Just value -> pure value
      Nothing -> do
        targetType <- checkExpression around declared rigid target
        memberType spanValue targetType (locatedValue member)
  IndexExpression target index -> do
    targetType <- checkExpression around declared rigid target
    indexType <- checkExpression around declared rigid index
    _ <- unify (locatedSpan index) integerType indexType
    elementType spanValue (literalIndex index) targetType
  TryExpression target -> do
    checkpoint <- integerLiteralCheckpoint
    targetType <- checkExpression around declared rigid target
    finalizeIntegerLiteralsSince checkpoint
    resolvedTarget <- zonk targetType
    declaredResult <- enclosingReturnType selfName
    tryType spanValue resolvedTarget declaredResult
  AwaitExpression target -> do
    checkpoint <- integerLiteralCheckpoint
    targetType <- checkExpression around declared rigid target
    finalizeIntegerLiteralsSince checkpoint
    resolvedTarget <- zonk targetType
    (asynchronous, declaredResult) <- enclosingFunctionType selfName
    awaitType spanValue asynchronous resolvedTarget declaredResult
  {-| An empty tuple is the unit *value*, not a tuple of nothing. The evaluator
      already produces `UnitValue` for it, and typing it as an empty tuple made
      `()` fail against the `()` type it was annotated with. -}
  TupleExpression [] -> pure UnitTypeValue
  TupleExpression members -> TupleTypeValue <$> mapM (checkExpression around declared rigid) members
  ArrayExpression members -> do
    elementTypes <- mapM (checkExpression around declared rigid) members
    inferredElementType <- case elementTypes of
      [] -> freshVariable
      first : rest -> foldM (unify spanValue) first rest
    pure (NominalType "Array" [inferredElementType])
  MacroCall _ _ -> pure ErrorType
  LambdaExpression value -> lambdaType around declared rigid value
  ScopeExpression body -> do
    (asynchronous, _) <- enclosingFunctionType selfName
    unless asynchronous $
      report "E3026" spanValue "a structured scope needs an async function"
        (Just "declare the enclosing function async; a scope joins the tasks it starts")
    aroundBlock around declared rigid body
  UnsafeExpression capabilities body -> do
    enterUnsafe (map locatedValue capabilities)
    bodyType <- aroundBlock around declared rigid body
    reportUnusedCapabilities spanValue
    pure bodyType
  RecordExpression path fields -> recordType (checkValue around) declared rigid spanValue path fields
  BlockExpression block -> aroundBlock around declared rigid block
  IfExpression condition thenBlock elseBranch -> do
    conditionCheckpoint <- integerLiteralCheckpoint
    conditionType <- checkExpression around declared rigid condition
    _ <- unify (locatedSpan condition) boolType conditionType
    validateIntegerLiteralsSince conditionCheckpoint
    branchCheckpoint <- integerLiteralCheckpoint
    thenType <- aroundBlock around declared rigid thenBlock
    case elseBranch of
      Nothing -> do
        finalizeIntegerLiteralsSince branchCheckpoint
        pure UnitTypeValue
      Just branch -> do
        elseType <- checkExpression around declared rigid branch
        unified <- unify spanValue thenType elseType
        validateIntegerLiteralsSince branchCheckpoint
        resolvedThen <- zonk thenType
        resolvedElse <- zonk elseType
        case (resolvedThen, resolvedElse) of
          (ErrorType, _) -> pure ErrorType
          (_, ErrorType) -> pure ErrorType
          _ -> zonk unified
  IfLetExpression pattern' subject thenBlock elseBranch -> do
    subjectCheckpoint <- integerLiteralCheckpoint
    borrowed <- checkExpression around declared rigid subject
    subjectType <- throughBorrow borrowed
    subjectEnd <- integerLiteralCheckpoint
    branchCheckpoint <- integerLiteralCheckpoint
    thenType <- inTypeScopeWith $ do
      bindPattern declared rigid pattern' subjectType
      aroundBlock around declared rigid thenBlock
    result <- case elseBranch of
      Nothing -> pure UnitTypeValue
      Just branch -> do
        elseType <- checkExpression around declared rigid branch
        unified <- unify spanValue thenType elseType
        resolvedThen <- zonk thenType
        resolvedElse <- zonk elseType
        case (resolvedThen, resolvedElse) of
          (ErrorType, _) -> pure ErrorType
          (_, ErrorType) -> pure ErrorType
          _ -> zonk unified
    finalizeIntegerLiteralsBetween subjectCheckpoint subjectEnd
    validateIntegerLiteralsSince branchCheckpoint
    pure result
  MatchExpression scrutinee arms -> do
    subjectCheckpoint <- integerLiteralCheckpoint
    borrowed <- checkExpression around declared rigid scrutinee
    {-| A match reads its subject; it does not consume it. Looking through a
        borrow is what lets a function take `&Option[T]` and still match on it,
        and every language with both references and patterns does the same. A
        pattern that binds by value from a borrowed subject is an ownership
        question, and ownership checking is where it belongs — not here, where
        the only available answer would be to refuse the match entirely. -}
    subjectType <- throughBorrow borrowed
    subjectEnd <- integerLiteralCheckpoint
    result <- checkArms around declared rigid spanValue subjectType arms
    finalizeIntegerLiteralsBetween subjectCheckpoint subjectEnd
    resolvedSubject <- zonk subjectType
    checkExhaustive spanValue resolvedSubject arms
    zonk result
  WhileExpression label condition body -> do
    conditionCheckpoint <- integerLiteralCheckpoint
    conditionType <- checkExpression around declared rigid condition
    _ <- unify (locatedSpan condition) boolType conditionType
    validateIntegerLiteralsSince conditionCheckpoint
    _ <- aroundLoop label UnitTypeValue False (aroundBlock around declared rigid body)
    pure UnitTypeValue
  {-| A `loop` has the type its `break` statements carry.

      One that never breaks does not finish, so its type is `Never` and it may
      stand where any type is wanted. That is not a special case bolted on: a
      loop with no exit genuinely produces no value, and `Never` is the type of
      an expression that produces none. -}
  LoopExpression label body -> do
    result <- freshVariable
    broken <- aroundLoop label result True (aroundBlock around declared rigid body)
    if broken then zonk result else pure NeverType
  ForExpression label binder iterated body -> do
    {-| The iterated expression's integer literals are settled before its
        element type is read.

        A literal defers its type until inference has seen enough to choose
        one, which is right nearly everywhere and wrong here: the binder's type
        comes from this expression and nothing else, so leaving it a variable
        meant the loop body could ask it for any method at all. `for x in
        [1, 2, 3] { x.length() }` passed because `x` had no type yet, not
        because whole numbers have a length. -}
    iteratedCheckpoint <- integerLiteralCheckpoint
    iteratedType <- checkExpression around declared rigid iterated
    finalizeIntegerLiteralsSince iteratedCheckpoint
    resolved <- zonk iteratedType
    element <- iterationElement spanValue resolved
    _ <- inTypeScope $ do
      bindPattern declared rigid binder element
      aroundLoop label UnitTypeValue False (aroundBlock around declared rigid body)
    pure UnitTypeValue
  {-| A type application pins what inference could not settle.

      Only a name can carry one: a scheme belongs to a declaration, and an
      arbitrary expression has already been instantiated by the time it is an
      expression. That is a real restriction and it is reported rather than
      worked around. -}
  TypeApplication target arguments -> do
    formed <- mapM (formType declared rigid) arguments
    {-| A qualified name carries type arguments as readily as a bare one:
        `Num.small[UInt16](...)` is the same call as `small[UInt16](...)` from
        inside the module, and a caller should not have to import a name
        unqualified to pin its type. A qualifier is written as a member access,
        so the chain is flattened back into the dotted name it stands for. -}
    case dottedName (locatedValue target) of
      Just name -> do
        found <- lookupName name
        case found of
          Just scheme -> do
            applied <- instantiateWith spanValue scheme formed
            recordExpression (locatedSpan target) applied
            pure applied
          Nothing -> do
            report "E2010" spanValue ("unresolved value name " <> name)
              (Just "declare the name, import it, or check the spelling")
            pure ErrorType
      Nothing -> do
        report "E3028" spanValue "only a name may carry type arguments"
          ( Just
              ( "write the type arguments on the function's own name; an "
                  <> "expression has already been given its types"
              )
          )
        _ <- checkExpression around declared rigid target
        pure ErrorType
  InvalidExpression -> pure ErrorType

checkArms
  :: CheckSurroundings
  -> DeclaredTypes
  -> [Text]
  -> Span
  -> Type
  -> [Located MatchArm]
  -> Checker Type
checkArms around declared rigid spanValue subjectType arms = case arms of
  [] -> pure ErrorType
  _ -> do
    checkpoint <- integerLiteralCheckpoint
    types <- mapM checkArm arms
    unified <- case types of
      [] -> pure ErrorType
      first : rest -> foldUnify first rest
    validateIntegerLiteralsSince checkpoint
    resolved <- mapM zonk types
    if ErrorType `elem` resolved then pure ErrorType else zonk unified
 where
  checkArm (Located _ arm) = do
    result <- freshVariable
    inTypeScope $ do
      bindPattern declared rigid (armPattern arm) subjectType
      case armGuard arm of
        Nothing -> pure ()
        Just guard -> do
          guardType <- checkExpression around declared rigid guard
          _ <- unify (locatedSpan guard) boolType guardType
          pure ()
      bodyType <- checkExpression around declared rigid (armBody arm)
      _ <- unify (locatedSpan (armBody arm)) result bodyType
      pure ()
    pure result
  foldUnify current rest = case rest of
    [] -> pure current
    next : remaining -> do
      unified <- unify spanValue current next
      foldUnify unified remaining

{-| A chain of names written as a path or as member accesses, joined back into
    the dotted name it stands for. Anything else is not a name. -}
dottedName :: Expression -> Maybe Text
dottedName expression = case expression of
  NameExpression names -> Just (Text.intercalate "." (NonEmpty.toList names))
  MemberExpression target member ->
    (\prefix -> prefix <> "." <> locatedValue member) <$> dottedName (locatedValue target)
  _ -> Nothing

{-| Type a function literal.

    The literal is checked exactly like a declaration's body — its parameters
    bound, its result unified with what the body produced — and answers with the
    function type a caller sees. Sharing the path is what keeps a literal and a
    declaration from drifting into two dialects of the same thing.

    A literal is not generalised. Its type is fixed at the point it is written,
    so a literal used at two types is an error the reader can see, rather than a
    silent second instantiation of something they wrote once. Generalisation
    belongs to a declaration, which has a name to attach it to. -}

literalIndex :: Located Expression -> Maybe Integer
literalIndex (Located _ expression) = case expression of
  LiteralExpression (Tree.IntegerValue text) ->
    parsedIntegerValue <$> parseIntegerLiteral text
  _ -> Nothing

{-| A chain of names written as a path or as member accesses, joined back into
    the dotted name it stands for. Anything else is not a name. -}

{-| Type a function literal.

    The literal is checked exactly like a declaration's body — its parameters
    bound, its result unified with what the body produced — and answers with the
    function type a caller sees. Sharing the path is what keeps a literal and a
    declaration from drifting into two dialects of the same thing.

    A literal is not generalised. Its type is fixed at the point it is written,
    so a literal used at two types is an error the reader can see, rather than a
    silent second instantiation of something they wrote once. Generalisation
    belongs to a declaration, which has a name to attach it to. -}
lambdaType :: CheckSurroundings -> DeclaredTypes -> [Text] -> Function -> Checker Type
lambdaType around declared rigid value = withoutLoops $ inTypeScopeWith $ do
  inputs <- mapM (aroundParameter around declared rigid) (functionParameters value)
  result <- formOptionalType declared rigid (functionReturn value)
  let signature = FunctionTypeValue (functionAsync value) inputs result
  bindName selfName (monotype signature)
  case functionBody value of
    Nothing -> pure ()
    Just (Located bodySpan body) -> do
      actual <- case body of
        BlockBody block -> aroundBlock around declared rigid block
        ExpressionBody expression -> checkExpression around declared rigid expression
      _ <- unify bodySpan result actual
      pure ()
  zonk signature

{-| Warn when a statement throws away a value that is the whole point of the
    call that produced it.

    A built-in collection method never mutates its receiver; it returns a new
    collection. So `items.push(value)` written as a statement does nothing at
    all, and does it silently — the statement type-checks, the program runs, and
    the array is unchanged. This is not a style preference: there is no reading
    of that line under which it is correct.

    The check is deliberately narrow. It fires only for the closed set of
    built-in methods the compiler already knows the semantics of, on a receiver
    the checker has confirmed is a collection. A general "unused result" warning
    would need to know which functions are pure, which Pudu does not track, and
    guessing would either miss this case or bury it in noise. -}

{-| Check a loop body with that loop on the stack, reporting whether any
    `break` left it. -}
aroundLoop :: Maybe (Located Text) -> Type -> Bool -> Checker a -> Checker Bool
aroundLoop label result carries action = do
  enterLoop (fmap locatedValue label) result carries
  _ <- action
  leaveLoop

{-| Check an expression against a type the context already knows.

    Inference alone cannot place a value into a `dynamic`: the branches of an `if`,
    the arms of a `match`, and the elements of an array literal are unified with
    *each other* before any declared type is consulted, so two types that widen
    to the same dynamic type disagree before the widening is ever considered.

    Pushing the expectation inward fixes that at its source. Each branch is
    checked against what the context wants rather than against its sibling, and
    a widening happens per branch. Everything else falls through to ordinary
    inference followed by the same unification as before, so this changes what
    is accepted only where an expectation genuinely exists. -}

{-| The two directions a field's value may be checked in, handed to record
    construction so it can reach back into checking without importing it. -}
checkValue :: CheckSurroundings -> CheckValue
checkValue around =
  CheckValue{valueOf = checkExpression around, valueAgainst = aroundAgainst around}
