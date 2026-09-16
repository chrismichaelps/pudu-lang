{-| @Program.Lint.Module — typed source findings and verified safe edits. -}
module Pudu.Lint
  ( FixApplicability (..)
  , LintFinding (..)
  , LintFix (..)
  , LintResult (..)
  , LintStats (..)
  , applySafeFixes
  , lintModule
  ) where

import Data.List (sortOn)
import Data.Maybe (mapMaybe, maybeToList)
import Data.Ord (Down (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Diagnostic
  , DiagnosticCode
  , Severity (Warning)
  , diagnostic
  , diagnosticCode
  , diagnosticSpan
  , mkDiagnosticCode
  , withHelp
  )
import Pudu.Frontend.Syntax.Located (Located (..), locatedSpan, locatedValue)
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Declaration (..)
  , Expression (..)
  , FieldInit (..)
  , Function (..)
  , FunctionBody (..)
  , Impl (..)
  , Literal (..)
  , Macro (..)
  , MatchArm (..)
  , Module (..)
  , Parameter (..)
  , Statement (..)
  , Trait (..)
  )
import Pudu.Source
  ( Source
  , Span
  , sourceText
  , spanEnd
  , spanStart
  , unOffset
  )
import Pudu.Type (TypeInfo, typeAt)
import Pudu.Type.Value (boolType)

data FixApplicability = Safe
  deriving stock (Eq, Ord, Show)

data LintFix = LintFix
  { lintFixStart :: !Int
  , lintFixEnd :: !Int
  , lintFixReplacement :: !Text
  , lintFixApplicability :: !FixApplicability
  }
  deriving stock (Eq, Show)

data LintFinding = LintFinding
  { lintDiagnostic :: !Diagnostic
  , lintRuleName :: !Text
  , lintFix :: !(Maybe LintFix)
  }
  deriving stock (Eq, Show)

newtype LintStats = LintStats
  { lintVisitedExpressions :: Int
  }
  deriving stock (Eq, Show)

data LintResult = LintResult
  { lintFindings :: ![LintFinding]
  , lintStats :: !LintStats
  }
  deriving stock (Eq, Show)

{-| Analyze every expression once with an explicit work stack. -}
lintModule :: Source -> TypeInfo -> Module -> LintResult
lintModule source types parsed =
  let (found, visited) = walk (map DeclarationWork (moduleDeclarations parsed)) [] 0
   in LintResult
        { lintFindings = sortOn findingKey found
        , lintStats = LintStats visited
        }
 where
  walk pending found visited = case pending of
    [] -> (found, visited)
    work : remaining -> case work of
      DeclarationWork (Located _ declaration) ->
        walk (declarationWork declaration <> remaining) found visited
      FunctionWork function -> walk (functionWork function <> remaining) found visited
      StatementWork (Located _ statement) ->
        walk (statementWork statement <> remaining) found visited
      BlockWork (Located _ block) -> walk (blockWork block <> remaining) found visited
      ExpressionWork located@(Located _ expression) ->
        walk
          (expressionWork expression <> remaining)
          (maybe found (: found) (lintExpression source types located))
          (visited + 1)

findingKey :: LintFinding -> (Int, Int, DiagnosticCode)
findingKey finding =
  let value = lintDiagnostic finding
   in ( unOffset (spanStart (diagnosticSpan value))
      , unOffset (spanEnd (diagnosticSpan value))
      , diagnosticCode value
      )

data Work
  = DeclarationWork !(Located Declaration)
  | FunctionWork !Function
  | StatementWork !(Located Statement)
  | BlockWork !(Located Block)
  | ExpressionWork !(Located Expression)

declarationWork :: Declaration -> [Work]
declarationWork declaration = case declaration of
  BindingDeclaration _ _ _ _ value -> [ExpressionWork value]
  FunctionDeclaration function -> [FunctionWork function]
  TypeDeclaration {} -> []
  TraitDeclaration trait -> map (FunctionWork . locatedValue) (traitMembers trait)
  ImplDeclaration implementation -> map (FunctionWork . locatedValue) (implFunctions implementation)
  MacroDeclaration macroValue -> [ExpressionWork (macroBody macroValue)]
  ForeignDeclaration {} -> []
  InvalidDeclaration -> []

functionWork :: Function -> [Work]
functionWork function =
  mapMaybe (fmap ExpressionWork . parameterDefault . locatedValue) (functionParameters function)
    <> maybeToList (bodyWork <$> functionBody function)
 where
  bodyWork (Located _ body) = case body of
    BlockBody block -> BlockWork block
    ExpressionBody expression -> ExpressionWork expression

blockWork :: Block -> [Work]
blockWork block =
  map StatementWork (blockStatements block)
    <> maybeToList (ExpressionWork <$> blockResult block)

statementWork :: Statement -> [Work]
statementWork statement = case statement of
  DeclarationStatement declaration -> [DeclarationWork declaration]
  ExpressionStatement expression -> [ExpressionWork expression]
  ReturnStatement expression -> maybeToList (ExpressionWork <$> expression)
  BreakStatement _ expression -> maybeToList (ExpressionWork <$> expression)
  ContinueStatement {} -> []
  LetElseStatement _ expression fallback -> [ExpressionWork expression, BlockWork fallback]
  InvalidStatement -> []

expressionWork :: Expression -> [Work]
expressionWork expression = case expression of
  LiteralExpression {} -> []
  NameExpression {} -> []
  UnaryExpression _ operand -> [ExpressionWork operand]
  BinaryExpression left _ right -> [ExpressionWork left, ExpressionWork right]
  CallExpression callee arguments -> ExpressionWork callee : map ExpressionWork arguments
  MemberExpression receiver _ -> [ExpressionWork receiver]
  IndexExpression receiver index -> [ExpressionWork receiver, ExpressionWork index]
  TryExpression operand -> [ExpressionWork operand]
  AwaitExpression operand -> [ExpressionWork operand]
  TupleExpression members -> map ExpressionWork members
  ArrayExpression members -> map ExpressionWork members
  SetExpression members -> map ExpressionWork members
  UnsafeExpression _ body -> [BlockWork body]
  MacroCall _ arguments -> map ExpressionWork arguments
  ScopeExpression body -> [BlockWork body]
  LambdaExpression function -> [FunctionWork function]
  TypeApplication operand _ -> [ExpressionWork operand]
  RecordExpression _ fields -> fieldWork fields
  RecordUpdateExpression _ original fields -> ExpressionWork original : fieldWork fields
  BlockExpression block -> [BlockWork block]
  IfExpression condition yes no ->
    [ExpressionWork condition, BlockWork yes] <> maybeToList (ExpressionWork <$> no)
  IfLetExpression _ value yes no ->
    [ExpressionWork value, BlockWork yes] <> maybeToList (ExpressionWork <$> no)
  MatchExpression value arms -> ExpressionWork value : concatMap armWork arms
  WhileExpression _ condition body -> [ExpressionWork condition, BlockWork body]
  WhileLetExpression _ _ value body -> [ExpressionWork value, BlockWork body]
  LoopExpression _ body -> [BlockWork body]
  ForExpression _ _ values body -> [ExpressionWork values, BlockWork body]
  InvalidExpression -> []

fieldWork :: [Located FieldInit] -> [Work]
fieldWork = mapMaybe (fmap ExpressionWork . fieldInitValue . locatedValue)

armWork :: Located MatchArm -> [Work]
armWork (Located _ arm) =
  maybeToList (ExpressionWork <$> armGuard arm) <> [ExpressionWork (armBody arm)]

{-| Publish a fix only after type and exact source spelling agree. -}
lintExpression :: Source -> TypeInfo -> Located Expression -> Maybe LintFinding
lintExpression source types (Located whole expression) = do
  (operand, literal, operator) <- comparisonCandidate expression
  if typeAt types (locatedSpan operand) /= Just boolType
    then Nothing
    else do
      replacement <- verifiedReplacement source whole operand literal operator
      code <- mkDiagnosticCode "W7101"
      base <- diagnostic code Warning whole "comparison with a Boolean literal is redundant"
      pure
        LintFinding
          { lintDiagnostic = withHelp ("replace it with " <> replacement) base
          , lintRuleName = "redundant-boolean-comparison"
          , lintFix = Just LintFix
              { lintFixStart = unOffset (spanStart whole)
              , lintFixEnd = unOffset (spanEnd whole)
              , lintFixReplacement = replacement
              , lintFixApplicability = Safe
              }
          }

comparisonCandidate :: Expression -> Maybe (Located Expression, Located Expression, Text)
comparisonCandidate expression = case expression of
  BinaryExpression left operator right
    | operator == "==", isBoolean True right -> Just (left, right, operator)
    | operator == "==", isBoolean True left -> Just (right, left, operator)
    | operator == "!=", isBoolean False right -> Just (left, right, operator)
    | operator == "!=", isBoolean False left -> Just (right, left, operator)
  _ -> Nothing
 where
  isBoolean expected (Located _ candidate) = case candidate of
    LiteralExpression (BoolValue actual) -> actual == expected
    _ -> False

verifiedReplacement
  :: Source -> Span -> Located Expression -> Located Expression -> Text -> Maybe Text
verifiedReplacement source whole operand literal operator = do
  let operandSpan = locatedSpan operand
      literalSpan = locatedSpan literal
      operandBefore = spanStart operandSpan < spanStart literalSpan
      first = if operandBefore then operandSpan else literalSpan
      second = if operandBefore then literalSpan else operandSpan
  if spanStart whole /= spanStart first || spanEnd whole /= spanEnd second
    then Nothing
    else do
      between <- sourceSlice source (unOffset (spanEnd first)) (unOffset (spanStart second))
      replacement <- sourceSlice source
        (unOffset (spanStart operandSpan)) (unOffset (spanEnd operandSpan))
      literalText <- sourceSlice source
        (unOffset (spanStart literalSpan)) (unOffset (spanEnd literalSpan))
      if Text.strip between == operator
          && Text.strip literalText `elem` ["true", "false"]
          && not (Text.null replacement)
        then Just replacement
        else Nothing

sourceSlice :: Source -> Int -> Int -> Maybe Text
sourceSlice source start end
  | start < 0 || end < start || end > Text.length contents = Nothing
  | otherwise = Just (Text.take (end - start) (Text.drop start contents))
 where
  contents = sourceText source

{-| Apply one compatible batch in linear output construction. -}
applySafeFixes :: Source -> [LintFinding] -> Text
applySafeFixes source findings = stitch 0 selected []
 where
  contents = sourceText source
  selected = compatible
    (sortOn (\edit -> (lintFixStart edit, Down (lintFixEnd edit))) valid)
  valid =
    [ edit
    | finding <- findings
    , Just edit <- [lintFix finding]
    , lintFixApplicability edit == Safe
    , lintFixStart edit >= 0
    , lintFixEnd edit > lintFixStart edit
    , lintFixEnd edit <= Text.length contents
    ]
  compatible edits = choose 0 edits
  choose _ [] = []
  choose available (edit : rest)
    | lintFixStart edit < available = choose available rest
    | otherwise = edit : choose (lintFixEnd edit) rest
  stitch cursor edits chunks = case edits of
    [] -> Text.concat (reverse (Text.drop cursor contents : chunks))
    edit : rest ->
      let unchanged = Text.take (lintFixStart edit - cursor) (Text.drop cursor contents)
       in stitch (lintFixEnd edit) rest
            (lintFixReplacement edit : unchanged : chunks)
