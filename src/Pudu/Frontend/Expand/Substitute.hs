{-| @Program.Expand.Substitute — hygienic substitution for macro expansion -}
module Pudu.Frontend.Expand.Substitute
  ( hygienicName
  , patternNames
  , substituteExpression
  , retag
  , renamePattern
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..), locatedValue)
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Declaration (..)
  , Expression (..)
  , FieldInit (..)
  , FieldPattern (..)
  , MatchArm (..)
  , Pattern (..)
  , Statement (..)
  )
import Pudu.Source (Span)

hygienicName :: Text -> Int -> Text
hygienicName name identifier = name <> "%" <> Text.pack (show identifier)

patternNames :: Located Pattern -> [Text]
patternNames (Located _ pattern') = case pattern' of
  BindingPattern name -> [locatedValue name]
  TuplePattern members -> concatMap patternNames members
  ConstructorPattern _ members -> concatMap patternNames members
  RecordPattern _ fields _ -> concatMap fieldNames fields
  AlternativePattern alternatives -> concatMap patternNames alternatives
  _ -> []
 where
  fieldNames (Located _ field) =
    maybe [locatedValue (fieldPatternName field)] patternNames (fieldPatternValue field)

{-| Substitute arguments for parameters, apply the hygienic renames, and retag
    every node with the call's span so a diagnostic inside an expansion points
    at the call the reader wrote. -}
substituteExpression
  :: Map Text (Located Expression)
  -> Int
  -> Map Text Text
  -> Span
  -> Located Expression
  -> Located Expression
substituteExpression bindings identifier renames callSpan (Located _ expression) = case expression of
  NameExpression names -> case names of
    single :| [] -> case Map.lookup single bindings of
      Just argument -> retag callSpan argument
      Nothing -> at (NameExpression (rename single :| []))
    first :| rest -> at (NameExpression (rename first :| rest))
  UnaryExpression operator operand -> at (UnaryExpression operator (recurse operand))
  BinaryExpression left operator right ->
    at (BinaryExpression (recurse left) operator (recurse right))
  CallExpression callee arguments ->
    at (CallExpression (recurse callee) (map recurse arguments))
  MemberExpression target member -> at (MemberExpression (recurse target) member)
  IndexExpression target index -> at (IndexExpression (recurse target) (recurse index))
  TryExpression target -> at (TryExpression (recurse target))
  AwaitExpression target -> at (AwaitExpression (recurse target))
  TupleExpression members -> at (TupleExpression (map recurse members))
  ArrayExpression members -> at (ArrayExpression (map recurse members))
  SetExpression members -> at (SetExpression (map recurse members))
  RecordExpression path fields -> at (RecordExpression path (map recurseField fields))
  RecordUpdateExpression path source fields ->
    at (RecordUpdateExpression path (recurse source) (map recurseField fields))
  BlockExpression block -> at (BlockExpression (recurseBlock block))
  UnsafeExpression capabilities block ->
    at (UnsafeExpression capabilities (recurseBlock block))
  ScopeExpression block -> at (ScopeExpression (recurseBlock block))
  IfExpression condition thenBlock elseBranch ->
    at (IfExpression (recurse condition) (recurseBlock thenBlock) (fmap recurse elseBranch))
  IfLetExpression pattern' subject thenBlock elseBranch ->
    let locals = Map.fromList
          [(name, hygienicName name identifier) | name <- patternNames pattern']
        successRenames = Map.union locals renames
     in at (IfLetExpression (renamePattern callSpan successRenames pattern')
          (recurse subject) (recurseBlockWith successRenames thenBlock) (fmap recurse elseBranch))
  MatchExpression scrutinee arms ->
    at (MatchExpression (recurse scrutinee) (map recurseArm arms))
  WhileExpression label condition body ->
    at (WhileExpression label (recurse condition) (recurseBlock body))
  {-| A `while let`'s pattern binds into its body alone, exactly as an `if let`'s
      binds into its success arm. The subject is read again each turn and never
      sees them. -}
  WhileLetExpression label pattern' subject body ->
    let locals = Map.fromList
          [(name, hygienicName name identifier) | name <- patternNames pattern']
        bodyRenames = Map.union locals renames
     in at (WhileLetExpression label (renamePattern callSpan bodyRenames pattern')
          (recurse subject) (recurseBlockWith bodyRenames body))
  LoopExpression label body -> at (LoopExpression label (recurseBlock body))
  ForExpression label binder iterated body ->
    at (ForExpression label binder (recurse iterated) (recurseBlock body))
  MacroCall name arguments -> at (MacroCall name (map recurse arguments))
  other -> at other
 where
  at = Located callSpan
  recurse = substituteExpression bindings identifier renames callSpan
  rename name = Map.findWithDefault name name renames
  recurseField (Located _ field) =
    Located callSpan field{fieldInitValue = fmap recurse (fieldInitValue field)}
  recurseArm (Located _ arm) =
    Located callSpan arm{armGuard = fmap recurse (armGuard arm), armBody = recurse (armBody arm)}
  recurseBlock = recurseBlockWith renames
  recurseBlockWith active (Located _ block) =
    let (statements, resultRenames) = recurseStatements active (blockStatements block)
     in Located callSpan
          ( Block statements
              (fmap (substituteExpression bindings identifier resultRenames callSpan)
                (blockResult block))
          )
  recurseStatements active statements = case statements of
    [] -> ([], active)
    statement : rest ->
      let (statement', next) = recurseStatementWith active statement
          (rest', final) = recurseStatements next rest
       in (statement' : rest', final)
  recurseStatementWith active (Located _ statement) =
    let recurseActive = substituteExpression bindings identifier active callSpan
        unchanged value = (Located callSpan value, active)
     in case statement of
          DeclarationStatement
            (Located _ (BindingDeclaration visibility kind name annotation value)) ->
              let original = locatedValue name
                  freshName = hygienicName original identifier
                  declaration = DeclarationStatement
                    ( Located callSpan
                        ( BindingDeclaration visibility kind
                            (Located callSpan freshName)
                            annotation
                            (recurseActive value)
                        )
                    )
               in (Located callSpan declaration, Map.insert original freshName active)
          ExpressionStatement expression' ->
            unchanged (ExpressionStatement (recurseActive expression'))
          ReturnStatement value -> unchanged (ReturnStatement (fmap recurseActive value))
          {-| A `let … else` binds for the rest of the block, so its pattern's
              names extend the active map for the statements after it — the same
              rule an ordinary binding follows. The subject is substituted before
              they exist, and the fallback is walked without them, because
              neither can see what the pattern binds. -}
          LetElseStatement pattern' subject fallback ->
            let locals = Map.fromList
                  [(name, hygienicName name identifier) | name <- patternNames pattern']
                after = Map.union locals active
                statement' = LetElseStatement
                  (renamePattern callSpan after pattern')
                  (recurseActive subject)
                  (recurseBlockWith active fallback)
             in (Located callSpan statement', after)
          other -> unchanged other

{-| Give an argument the call's span so its diagnostics stay where it was
    written, not where the macro body placed it. -}
retag :: Span -> Located Expression -> Located Expression
retag _ argument = argument

renamePattern :: Span -> Map Text Text -> Located Pattern -> Located Pattern
renamePattern callSpan renames (Located _ pattern') = Located callSpan $ case pattern' of
  BindingPattern name -> BindingPattern (renameLocated name)
  TuplePattern members -> TuplePattern (map recurse members)
  ConstructorPattern path members -> ConstructorPattern path (map recurse members)
  RecordPattern path fields rest -> RecordPattern path (map renameField fields) rest
  AlternativePattern alternatives -> AlternativePattern (map recurse alternatives)
  other -> other
 where
  recurse = renamePattern callSpan renames
  renameLocated (Located _ name) = Located callSpan (Map.findWithDefault name name renames)
  renameField (Located _ field) = Located callSpan field
    { fieldPatternValue = case fieldPatternValue field of
        Just nested -> Just (recurse nested)
        Nothing -> Just (Located callSpan (BindingPattern (renameLocated (fieldPatternName field))))
    }
