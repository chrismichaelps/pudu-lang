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
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Expression (..)
  , Parameter
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , finalizeIntegerLiteralsBetween
  , finalizeIntegerLiteralsSince
  , freshVariable
  , inTypeScope
  , inTypeScopeWith
  , integerLiteralCheckpoint
  , enterUnsafe
  , lookupName
  , recordExpression
  , report
  , validateIntegerLiteralsSince
  )
import Pudu.Type.Check.Pattern (bindPattern)
import Pudu.Type.Check.Iteration (iterationElement)
import Pudu.Type.Check.Safety
  ( checkComptimeCall
  , checkSuppliedArguments
  , dottedName
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
  , recordUpdateType
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
import Pudu.Type.Check.Propagation (reportRedundantPropagation)
import Pudu.Type.Check.Expression.Control
  ( aroundLoop
  , checkArms
  , checkCapturedAssignment
  , lambdaType
  , literalIndex
  )
import Pudu.Type.Exhaust (checkExhaustive)
import Pudu.Type.Formation (formType)
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value
  ( Type (..)
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
  { aroundBlock :: DeclaredTypes -> [(Text, Int)] -> Located Block -> Checker Type
  , aroundAgainst :: DeclaredTypes -> [(Text, Int)] -> Type -> Located Expression -> Checker Type
  , aroundParameter :: DeclaredTypes -> [(Text, Int)] -> Located Parameter -> Checker Type
  }

expressionChecker :: CheckSurroundings -> CheckExpression
expressionChecker around = CheckExpression (checkExpression around)

checkExpression
  :: CheckSurroundings -> DeclaredTypes -> [(Text, Int)] -> Located Expression -> Checker Type
checkExpression around declared rigid (Located spanValue expression) = do
  typeValue <- inferExpression around declared rigid spanValue expression
  resolved <- zonk typeValue
  recordExpression spanValue resolved
  pure typeValue

inferExpression
  :: CheckSurroundings -> DeclaredTypes -> [(Text, Int)] -> Span -> Expression -> Checker Type
inferExpression around declared rigid spanValue expression = case expression of
  LiteralExpression literal -> literalType spanValue literal
  NameExpression names -> nameType spanValue names
  UnaryExpression operator operand -> do
    actual <- checkExpression around declared rigid operand
    unaryType spanValue operator actual
  BinaryExpression left operator right -> do
    leftType <- checkExpression around declared rigid left
    rightType <- checkExpression around declared rigid right
    checkCapturedAssignment operator left
    binaryType spanValue operator leftType rightType
  CallExpression callee arguments -> do
    checkComptimeCall spanValue callee
    dispatched <- traitQualifiedCall (expressionChecker around) declared rigid callee arguments
    case dispatched of
      Just (calleeType, argumentTypes) -> callType spanValue calleeType argumentTypes
      Nothing -> do
        calleeType <- checkCallee (expressionChecker around) declared rigid callee
        checkSuppliedArguments spanValue callee calleeType (length arguments)
        argumentTypes <- mapM (checkExpression around declared rigid) arguments
        callType spanValue calleeType argumentTypes
  MemberExpression target member -> do
    {-| A variant that named its payload is refused here rather than inside
        qualified member typing, which a call reaches twice — once for the
        callee and once for the expression — and would report twice. -}
    refused <- namedVariantAsValue spanValue (locatedValue member)
    qualified <- case refused of
      Just value -> pure (Just value)
      Nothing -> qualifiedMemberType declared spanValue (locatedValue target) (locatedValue member)
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
  SetExpression members -> do
    elementTypes <- mapM (checkExpression around declared rigid) members
    inferredElementType <- case elementTypes of
      [] -> freshVariable
      first : rest -> foldM (unify spanValue) first rest
    pure (NominalType "Set" [inferredElementType])
  MacroCall _ _ -> pure ErrorType
  LambdaExpression value ->
    lambdaType
      (aroundParameter around declared rigid)
      (aroundBlock around declared rigid)
      (checkExpression around declared rigid)
      declared
      rigid
      value
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
  RecordUpdateExpression path source fields ->
    recordUpdateType (checkValue around) declared rigid spanValue path source fields
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
    result <- checkArms (checkExpression around declared rigid) declared rigid spanValue subjectType arms
    finalizeIntegerLiteralsBetween subjectCheckpoint subjectEnd
    resolvedSubject <- zonk subjectType
    checkExhaustive spanValue resolvedSubject arms
    declaredResult <- enclosingReturnType selfName >>= zonk
    reportRedundantPropagation spanValue arms declaredResult
    zonk result
  {-| A `while let` is `()` for the same reason every `while` is: it finishes
      when its pattern stops matching, so a value carried out would exist on
      some runs and not others. Bindings live in the body alone. -}
  WhileLetExpression label pattern' subject body -> do
    subjectCheckpoint <- integerLiteralCheckpoint
    borrowed <- checkExpression around declared rigid subject
    subjectType <- throughBorrow borrowed
    subjectEnd <- integerLiteralCheckpoint
    _ <- inTypeScopeWith $ do
      bindPattern declared rigid pattern' subjectType
      aroundLoop label UnitTypeValue False (aroundBlock around declared rigid body)
    finalizeIntegerLiteralsBetween subjectCheckpoint subjectEnd
    pure UnitTypeValue
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

{-| The two directions a field's value may be checked in, handed to record
    construction so it can reach back into checking without importing it. -}
checkValue :: CheckSurroundings -> CheckValue
checkValue around =
  CheckValue{valueOf = checkExpression around, valueAgainst = aroundAgainst around}

