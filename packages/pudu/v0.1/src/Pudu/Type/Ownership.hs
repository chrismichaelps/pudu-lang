{-| @Type.Ownership.Module — checks moves of values that need drop -}
module Pudu.Type.Ownership (checkOwnership) where

import Control.Monad (forM_, when)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
import Pudu.Semantic.Prelude (preludeValueNames)
import Pudu.Source (Span)
import Pudu.Type.Drop (implementsDrop, needsDrop)
import Pudu.Type.Env (Checker, finalExpressionTypes, methodReceivers)
import Pudu.Type.Ownership.Declaration (checkDropImplementation)
import Pudu.Type.Ownership.Flow
import Pudu.Frontend.Syntax.Pattern (patternBindings)
import Pudu.Type.Ownership.Pattern (checkPattern)
import Pudu.Type.Value (NominalId (..), Type (..))

{-| Check every body of a module and answer the spans of the uses that move a
    value needing drop, and of the binders that own one. Values that need no drop are not tracked: they keep
    the reading semantics every program had before ownership mattered. -}
checkOwnership :: Module -> Checker (Set Span, Set Span)
checkOwnership checked = do
  types <- finalExpressionTypes
  receivers <- methodReceivers
  let declarations = moduleDeclarations checked
      known = Facts
        { factTypes = types
        , factReceivers = receivers
        , factBuiltins = Set.fromList preludeValueNames `Set.difference` (declaredValues declarations <> constructors)
        }
  mapM_ checkDropImplementation declarations
  runWalk known (mapM_ declaration declarations)

{-| The prelude's constructors take what they are given, as every
    constructor does. -}
constructors :: Set Text
constructors = Set.fromList ["Some", "None", "Ok", "Err"]

declaredValues :: [Located Declaration] -> Set Text
declaredValues declarations = Set.fromList $ concat
  [ case value of
      FunctionDeclaration function -> [locatedValue (functionName function)]
      BindingDeclaration _ _ name _ _ -> [locatedValue name]
      _ -> []
  | Located _ value <- declarations
  ]

declaration :: Located Declaration -> Walk ()
declaration (Located _ value) = case value of
  FunctionDeclaration function -> checkBody function
  ImplDeclaration implementation -> mapM_ (checkBody . locatedValue) (implFunctions implementation)
  TraitDeclaration trait -> mapM_ (checkBody . locatedValue) (traitMembers trait)
  BindingDeclaration _ _ _ _ initializer -> do
    owning <- needs (locatedSpan initializer)
    when owning $ refuse "E4004" (locatedSpan initializer)
      "a module value cannot hold a value that needs drop"
      "create the value inside the function that owns it"
    expression Consume initializer
  _ -> pure ()

checkBody :: Function -> Walk ()
checkBody function = case functionBody function of
  Nothing -> pure ()
  Just (Located _ body) -> withFreshFlow $ withScope $ do
    mapM_ (bindBinder . parameterName . locatedValue) (functionParameters function)
    case body of
      BlockBody located -> block Consume located
      ExpressionBody located -> expression Consume located

needs :: Span -> Walk Bool
needs at = do
  found <- typeAt at
  maybe (pure False) (lift . needsDrop) found

block :: Mode -> Located Block -> Walk ()
block mode (Located _ value) = withScope $ do
  mapM_ statement (blockStatements value)
  mapM_ (expression mode) (blockResult value)

statement :: Located Statement -> Walk ()
statement (Located _ value) = case value of
  DeclarationStatement (Located _ (BindingDeclaration _ _ name _ initializer)) -> do
    expression Consume initializer
    bindBinder name
  DeclarationStatement (Located _ (FunctionDeclaration function)) -> withClosure (checkBody function)
  DeclarationStatement _ -> pure ()
  ExpressionStatement located -> do
    expression Consume located
    owning <- needs (locatedSpan located)
    when owning (ownTemporary (locatedSpan located))
  ReturnStatement operand -> mapM_ (expression Consume) operand >> stop
  BreakStatement label operand -> mapM_ (expression Consume) operand >> breakTo (fmap locatedValue label)
  ContinueStatement label -> continueTo (fmap locatedValue label)
  LetElseStatement pattern subject fallback -> do
    subjectType <- consumeSubject subject
    checkPattern subjectType pattern
    branches [block Read fallback, pure ()]
    mapM_ bindBinder (patternBindings pattern)
  LetPatternStatement _ (Located _ WildcardPattern) _ subject -> do
    expression Consume subject
    owning <- needs (locatedSpan subject)
    when owning (ownTemporary (locatedSpan subject))
  LetPatternStatement _ pattern _ subject -> do
    subjectType <- consumeSubject subject
    checkPattern subjectType pattern
    mapM_ bindBinder (patternBindings pattern)
  InvalidStatement -> pure ()

consumeSubject :: Located Expression -> Walk (Maybe Type)
consumeSubject subject = do
  expression Consume subject
  typeAt (locatedSpan subject)

expression :: Mode -> Located Expression -> Walk ()
expression mode located@(Located at value) = do
  holding located
  temporary mode located
  case value of
    NameExpression (name :| []) -> useName mode at name
    NameExpression _ -> moduleValue at
    LiteralExpression _ -> pure ()
    UnaryExpression operator operand
      | operator `elem` ["&", "&mut"] -> place operand
      | otherwise -> expression Read operand
    BinaryExpression target "=" source -> do
      expression Consume source
      assign target source
    BinaryExpression left operator right
      | operator `elem` ["&&", "||"] -> expression Read left >> branches [expression Read right, pure ()]
      | otherwise -> expression Read left >> expression Read right
    CallExpression callee arguments -> call callee arguments
    MemberExpression base _ -> member mode at base
    IndexExpression base index -> place base >> expression Read index
    RangeExpression low _ high -> mapM_ (expression Read) low >> mapM_ (expression Read) high
    TryExpression operand -> expression Consume operand
    AwaitExpression operand -> expression Read operand
    TupleExpression members -> mapM_ (expression Consume) members
    ArrayExpression members -> mapM_ (expression Consume) members
    SetExpression members -> mapM_ (expression Consume) members
    UnsafeExpression _ inner -> block mode inner
    MacroCall _ arguments -> mapM_ (expression Read) arguments
    ScopeExpression inner -> block mode inner
    LambdaExpression function -> withClosure (checkBody function)
    TypeApplication inner _ -> expression mode inner
    RecordExpression _ fields -> mapM_ fieldInit fields
    RecordUpdateExpression _ base fields -> do
      owning <- needs (locatedSpan base)
      when owning $ refuse "E4006" (locatedSpan base)
        "a record that needs drop cannot be updated into a new one"
        "build the new record from fields read through a name"
      place base
      mapM_ fieldInit fields
    BlockExpression inner -> block mode inner
    IfExpression condition consequent alternative -> do
      expression Read condition
      branches [block mode consequent, mapM_ (expression mode) alternative]
    IfLetExpression pattern subject consequent alternative -> do
      subjectType <- consumeSubject subject
      checkPattern subjectType pattern
      branches
        [ withScope (mapM_ bindBinder (patternBindings pattern) >> block mode consequent)
        , mapM_ (expression mode) alternative
        ]
    MatchExpression subject arms -> do
      subjectType <- consumeSubject subject
      branches (map (arm mode subjectType) arms)
    WhileExpression label condition body ->
      loopWith (fmap locatedValue label) Conditional (expression Read condition >> block Read body)
    WhileLetExpression label pattern subject body ->
      loopWith (fmap locatedValue label) Conditional $ do
        subjectType <- consumeSubject subject
        checkPattern subjectType pattern
        withScope (mapM_ bindBinder (patternBindings pattern) >> block Read body)
    LoopExpression label body -> loopWith (fmap locatedValue label) Unconditional (block Read body)
    ForExpression label pattern source body -> do
      expression Read source
      loopWith (fmap locatedValue label) Conditional
        (withScope (mapM_ bindBinder (patternBindings pattern) >> block Read body))
    ComptimeForExpression _ -> pure ()
    InvalidExpression -> pure ()

arm :: Mode -> Maybe Type -> Located MatchArm -> Walk ()
arm mode subjectType (Located _ value) = withScope $ do
  checkPattern subjectType (armPattern value)
  mapM_ bindBinder (patternBindings (armPattern value))
  mapM_ (expression Read) (armGuard value)
  expression mode (armBody value)

fieldInit :: Located FieldInit -> Walk ()
fieldInit (Located _ field) = case fieldInitValue field of
  Just value -> expression Consume value
  Nothing -> useName Consume (locatedSpan (fieldInitName field)) (locatedValue (fieldInitName field))

{-| A use of a local that needs drop: reading it requires it is still there,
    and a consuming use moves it. -}
useName :: Mode -> Span -> Text -> Walk ()
useName mode at name = do
  owning <- needs at
  when owning $ do
    found <- resolveBinder name
    case found of
      Nothing -> when (Set.notMember name constructors) (moduleValue at)
      Just (_, True) ->
        refuse "E4004" at (name <> " needs drop and cannot be captured by a closure")
          "pass it to the closure as an argument instead"
      Just (binder, False) -> do
        moved <- movedAt binder
        forM_ moved $ \(definite, _) ->
          refuse "E4001" at
            ((if definite then "use of moved value " else "use of a value that may have moved: ") <> name)
            "a value that needs drop has one owner; borrow it with & to use it without moving it"
        when (mode == Consume) (markMoved binder at)

moduleValue :: Span -> Walk ()
moduleValue at = do
  owning <- needs at
  when owning $ refuse "E4004" at "a module value cannot hold a value that needs drop"
    "create the value inside the function that owns it"

{-| A place read through: the root must still be there, and nothing moves. -}
place :: Located Expression -> Walk ()
place located@(Located at value) = case value of
  NameExpression (name :| []) -> useName Read at name
  MemberExpression base _ -> place base
  IndexExpression base index -> place base >> expression Read index
  UnaryExpression "*" inner -> place inner
  _ -> expression Read located

member :: Mode -> Span -> Located Expression -> Walk ()
member mode at base = do
  owning <- needs at
  when (owning && mode == Consume) $
    refuse "E4002" at "cannot move a field that needs drop out of its record"
      "borrow it with & or move the whole record"
  place base

assign :: Located Expression -> Located Expression -> Walk ()
assign target source = case locatedValue target of
  NameExpression (name :| []) -> do
    found <- resolveBinder name
    owning <- needs (locatedSpan source)
    case found of
      Just (_, True) | owning ->
        refuse "E4004" (locatedSpan target) (name <> " needs drop and cannot be assigned from a closure")
          "assign it where it is declared"
      Just (binder, _) -> reinitialize binder
      Nothing -> pure ()
  _ -> do
    owning <- needs (locatedSpan source)
    when owning $ refuse "E4006" (locatedSpan target)
      "a value that needs drop can only be assigned to a local name"
      "assign the whole record to a local instead of storing into a field or reference"
    place target

call :: Located Expression -> [Located Expression] -> Walk ()
call callee arguments = case locatedValue callee of
  MemberExpression receiver memberName -> do
    explicitDrop receiver memberName
    receivers <- factReceivers <$> facts
    local <- receiverIsLocalValue receiver
    case Map.lookup (locatedSpan receiver) receivers of
      Just True -> expression Consume receiver >> mapM_ (expression Consume) arguments
      Just False -> place receiver >> mapM_ (expression Consume) arguments
      Nothing
        | not local -> mapM_ (expression Consume) arguments
        | otherwise -> do
            builtinOperand receiver
            mapM_ builtinOperand arguments
            place receiver
            mapM_ (expression Read) arguments
  NameExpression (name :| []) -> do
    builtins <- factBuiltins <$> facts
    found <- resolveBinder name
    if found == Nothing && Set.member name builtins
      then mapM_ builtinOperand arguments >> mapM_ (expression Read) arguments
      else expression Read callee >> mapM_ (expression Consume) arguments
  _ -> expression Read callee >> mapM_ (expression Consume) arguments

{-| A receiver written as a type or module qualifier names no value. -}
receiverIsLocalValue :: Located Expression -> Walk Bool
receiverIsLocalValue (Located _ value) = case value of
  NameExpression (name :| []) -> (/= Nothing) <$> resolveBinder name
  NameExpression _ -> pure False
  _ -> pure True

builtinOperand :: Located Expression -> Walk ()
builtinOperand operand = do
  owning <- needs (locatedSpan operand)
  when owning $ refuse "E4004" (locatedSpan operand)
    "a builtin operation cannot take a value that needs drop"
    "pass a field or a borrow of the value instead"

explicitDrop :: Located Expression -> Located Text -> Walk ()
explicitDrop receiver memberName = when (locatedValue memberName == "drop") $ do
  receivers <- factReceivers <$> facts
  receiverType <- typeAt (locatedSpan receiver)
  let owner = receiverType >>= ownerOf
      qualified = locatedValue receiver == NameExpression ("Drop" :| [])
  implemented <- maybe (pure False) (lift . implementsDrop) owner
  when (qualified || (implemented && Map.member (locatedSpan receiver) receivers)) $
    refuse "E4003" (locatedSpan memberName) "drop runs at the end of ownership and cannot be called"
      "let the value go out of scope, or move it into a scope that ends where it should be dropped"
 where
  ownerOf held = case held of
    NominalType owner _ -> Just owner
    ReferenceTypeValue _ inner -> ownerOf inner
    _ -> Nothing

{-| A collection, map, set or task holding a value that needs drop would let
    the value be copied out from under its owner. -}
holding :: Located Expression -> Walk ()
holding (Located at _) = do
  found <- typeAt at
  case found of
    Just held@(NominalType owner _) | Just described <- Map.lookup (nominalName owner) holderNames -> do
      owning <- lift (needsDrop held)
      when owning $ refuse "E4004" at
        (described <> " cannot hold a value that needs drop")
        "keep the value in a local, a record field, an Option or a Result"
    _ -> pure ()

{-| The wired-in holders that copy their elements, as a diagnostic names them. -}
holderNames :: Map.Map Text Text
holderNames = Map.fromList
  [ ("Array", "an array"), ("Map", "a map"), ("Set", "a set")
  , ("Buckets", "a bucket store"), ("Task", "a task")
  ]

{-| A value that needs drop and is only read would be lost when the read is
    done, with no owner to drop it. -}
temporary :: Mode -> Located Expression -> Walk ()
temporary mode located@(Located at _) = when (mode == Read && not (isPlace located)) $ do
  owning <- needs at
  when owning $ refuse "E4005" at
    "this value needs drop and is only read, so nothing would own it"
    "bind it to a name first"

isPlace :: Located Expression -> Bool
isPlace (Located _ value) = case value of
  NameExpression _ -> True
  MemberExpression base _ -> isPlace base
  IndexExpression base _ -> isPlace base
  UnaryExpression "*" inner -> isPlace inner
  _ -> False
