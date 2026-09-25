{-| @Eval.Capture — the names a function literal can reach out to.

    A literal captures the scope it was written in, and the scope it was written
    in holds everything the surrounding code happens to have named. Capturing all
    of it keeps all of it alive: a literal stored in a table held the megabyte
    array that happened to be in scope beside it, for as long as the table lived,
    and nothing in the program said so.

    What a literal can actually reach is what it mentions. This module answers
    that from the syntax, over-approximating on purpose: a name collected here
    that the literal cannot use costs one map entry, and a name missed would be a
    binding that vanished, so every spelling that reaches a binding at run time
    is collected and nothing is subtracted.

    The keys are the ones the evaluator itself looks a name up by. A path is
    looked up whole and by each of its prefixes — `Std.Char.toUpper` may be one
    binding or a module reached by two steps — so every prefix is a key. A
    record field written without a value takes the binding of its own name, so
    that name is a key too. -}
module Pudu.Eval.Capture
  ( reachableNames
  ) where

import Data.List (inits)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text

import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameSegments)
import Pudu.Frontend.Syntax.Tree

{-| Every name a function literal's body could look up. -}
reachableNames :: Function -> Set Text
reachableNames function =
  foldMap fromParameter (functionParameters function)
    <> foldMap fromBody (functionBody function)
 where
  fromParameter (Located _ parameter) =
    foldMap fromExpression (parameterDefault parameter)

  fromBody (Located _ body) = case body of
    BlockBody block -> fromBlock block
    ExpressionBody expression -> fromExpression expression

fromBlock :: Located Block -> Set Text
fromBlock (Located _ block) =
  foldMap fromStatement (blockStatements block)
    <> foldMap fromExpression (blockResult block)

fromStatement :: Located Statement -> Set Text
fromStatement (Located _ statement) = case statement of
  DeclarationStatement declaration -> fromDeclaration declaration
  ExpressionStatement expression -> fromExpression expression
  ReturnStatement value -> foldMap fromExpression value
  BreakStatement _ value -> foldMap fromExpression value
  ContinueStatement _ -> Set.empty
  LetElseStatement _ subject fallback -> fromExpression subject <> fromBlock fallback
  LetPatternStatement _ _ _ subject -> fromExpression subject
  InvalidStatement -> Set.empty

{-| A declaration inside a literal's body. Only a binding carries an expression
    a name can be reached from; the rest declare shapes rather than values. -}
fromDeclaration :: Located Declaration -> Set Text
fromDeclaration (Located _ declaration) = case declaration of
  BindingDeclaration _ _ _ _ value -> fromExpression value
  FunctionDeclaration value -> reachableNames value
  MacroDeclaration value -> fromExpression (macroBody value)
  TraitDeclaration value -> foldMap (reachableNames . locatedValue) (traitMembers value)
  ImplDeclaration value -> foldMap (reachableNames . locatedValue) (implFunctions value)
  TypeDeclaration _ -> Set.empty
  ForeignDeclaration _ -> Set.empty
  InvalidDeclaration -> Set.empty

fromExpression :: Located Expression -> Set Text
fromExpression (Located _ expression) = case expression of
  LiteralExpression _ -> Set.empty
  {-| Every prefix, because the evaluator tries the longest binding first and
      falls back through the shorter ones. -}
  NameExpression names -> pathKeys (NonEmpty.toList names)
  UnaryExpression _ operand -> fromExpression operand
  BinaryExpression left _ right -> fromExpression left <> fromExpression right
  CallExpression callee arguments -> fromExpression callee <> foldMap fromExpression arguments
  {-| A chain of members may be one dotted binding rather than a read, which is
      how a module's function is passed as a value, so the chain's own prefixes
      are keys beside whatever the target reaches. -}
  MemberExpression target member ->
    fromExpression target <> maybe Set.empty pathKeys (flatten expression)
      <> Set.singleton (locatedValue member)
  IndexExpression target index -> fromExpression target <> fromExpression index
  RangeExpression lower _ upper -> foldMap fromExpression lower <> foldMap fromExpression upper
  TryExpression target -> fromExpression target
  AwaitExpression target -> fromExpression target
  TupleExpression members -> foldMap fromExpression members
  ArrayExpression members -> foldMap fromExpression members
  SetExpression members -> foldMap fromExpression members
  UnsafeExpression _ body -> fromBlock body
  MacroCall name arguments ->
    Set.insert (locatedValue name) (foldMap fromExpression arguments)
  ScopeExpression body -> fromBlock body
  LambdaExpression value -> reachableNames value
  TypeApplication target _ -> fromExpression target
  RecordExpression path fields -> pathKeys (segmentsOf path) <> foldMap fromFieldInit fields
  RecordUpdateExpression path source fields ->
    pathKeys (segmentsOf path) <> fromExpression source <> foldMap fromFieldInit fields
  BlockExpression block -> fromBlock block
  IfExpression condition thenBlock elseBranch ->
    fromExpression condition <> fromBlock thenBlock <> foldMap fromExpression elseBranch
  IfLetExpression _ subject thenBlock elseBranch ->
    fromExpression subject <> fromBlock thenBlock <> foldMap fromExpression elseBranch
  MatchExpression subject arms -> fromExpression subject <> foldMap fromArm arms
  WhileExpression _ condition body -> fromExpression condition <> fromBlock body
  WhileLetExpression _ _ subject body -> fromExpression subject <> fromBlock body
  LoopExpression _ body -> fromBlock body
  ForExpression _ _ iterated body -> fromExpression iterated <> fromBlock body
  InvalidExpression -> Set.empty

{-| A field written without a value takes the binding of its own name. -}
fromFieldInit :: Located FieldInit -> Set Text
fromFieldInit (Located _ field) = case fieldInitValue field of
  Just value -> fromExpression value
  Nothing -> Set.singleton (locatedValue (fieldInitName field))

fromArm :: Located MatchArm -> Set Text
fromArm (Located _ arm) =
  foldMap fromExpression (armGuard arm) <> fromExpression (armBody arm)

{-| The dotted prefixes of a path, and its segments. -}
pathKeys :: [Text] -> Set Text
pathKeys segments =
  Set.fromList (segments <> [Text.intercalate "." taken | taken <- drop 1 (inits segments)])

segmentsOf :: ModuleName -> [Text]
segmentsOf path = NonEmpty.toList (moduleNameSegments path)

{-| The segments of a chain of names and member accesses, mirroring the walk the
    evaluator does before it decides a chain is a binding rather than a read. -}
flatten :: Expression -> Maybe [Text]
flatten expression = case expression of
  NameExpression names -> Just (NonEmpty.toList names)
  MemberExpression (Located _ target) member ->
    (<> [locatedValue member]) <$> flatten target
  _ -> Nothing
