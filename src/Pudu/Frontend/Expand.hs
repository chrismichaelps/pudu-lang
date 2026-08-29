{-| @Program.Expand.Module — expands macro calls before name resolution -}
module Pudu.Frontend.Expand
  ( expandModule
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (Error)
  , diagnostic
  , mkDiagnosticCode
  , sortDiagnostics
  , withHelp
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Declaration (..)
  , Expression (..)
  , FieldInit (..)
  , FieldPattern (..)
  , Function (..)
  , FunctionBody (..)
  , Impl (..)
  , Macro (..)
  , MacroKind (..)
  , MacroParam (..)
  , MatchArm (..)
  , Module (..)
  , Parameter (..)
  , Pattern (..)
  , Statement (..)
  , Trait (..)
  )
import Pudu.Source (Span)

{-| Expand every macro call in a module.

    [[architecture/SEMANTICS]] puts expansion before name resolution, so the
    phases that follow never see a call. A call that cannot be expanded becomes
    an explicit invalid node, which keeps later phases from explaining the same
    defect a second time. -}
expandModule :: Module -> (Module, [Diagnostic])
expandModule moduleValue =
  let macros = collectMacros (moduleDeclarations moduleValue)
      state = ExpandState{stateNext = 0, stateDiagnosticsRev = []}
      (declarations, finalState) =
        runExpand (mapM (expandDeclaration macros 0) (moduleDeclarations moduleValue)) state
   in ( moduleValue{moduleDeclarations = declarations}
      , sortDiagnostics (reverse (stateDiagnosticsRev finalState))
      )

collectMacros :: [Located Declaration] -> Map Text Macro
collectMacros declarations =
  Map.fromList
    [ (locatedValue (macroName value), value)
    | Located _ (MacroDeclaration value) <- declarations
    ]

data ExpandState = ExpandState
  { stateNext :: !Int
  , stateDiagnosticsRev :: ![Diagnostic]
  }

newtype Expand a = Expand (ExpandState -> (a, ExpandState))

runExpand :: Expand a -> ExpandState -> (a, ExpandState)
runExpand (Expand action) = action

instance Functor Expand where
  fmap transform (Expand action) =
    Expand $ \state -> let (value, next) = action state in (transform value, next)

instance Applicative Expand where
  pure value = Expand $ \state -> (value, state)
  Expand leftAction <*> Expand rightAction =
    Expand $ \state ->
      let (transform, afterLeft) = leftAction state
          (value, afterRight) = rightAction afterLeft
       in (transform value, afterRight)

instance Monad Expand where
  Expand action >>= continue =
    Expand $ \state ->
      let (value, next) = action state
          Expand continued = continue value
       in continued next

fresh :: Expand Int
fresh = Expand $ \state -> (stateNext state, state{stateNext = stateNext state + 1})

report :: Text -> Span -> Text -> Maybe Text -> Expand ()
report code spanValue message help =
  case build code spanValue message help of
    Nothing -> pure ()
    Just value ->
      Expand $ \state -> ((), state{stateDiagnosticsRev = value : stateDiagnosticsRev state})

build :: Text -> Span -> Text -> Maybe Text -> Maybe Diagnostic
build code spanValue message help = do
  validCode <- mkDiagnosticCode code
  value <- diagnostic validCode Error spanValue message
  pure (maybe value (`withHelp` value) help)

{-| A macro that expands into itself would never finish, so expansion is
    bounded and reports where it started. -}
expansionLimit :: Int
expansionLimit = 32

expandDeclaration :: Map Text Macro -> Int -> Located Declaration -> Expand (Located Declaration)
expandDeclaration macros depth (Located declarationSpan declaration) = case declaration of
  BindingDeclaration visibility kind name annotation value -> do
    expanded <- expandExpression macros depth value
    pure (Located declarationSpan (BindingDeclaration visibility kind name annotation expanded))
  FunctionDeclaration value -> do
    expanded <- expandFunction macros depth value
    pure (Located declarationSpan (FunctionDeclaration expanded))
  TraitDeclaration value -> do
    members <- mapM (expandLocatedFunction macros depth) (traitMembers value)
    pure (Located declarationSpan (TraitDeclaration value{traitMembers = members}))
  ImplDeclaration value -> do
    functions <- mapM (expandLocatedFunction macros depth) (implFunctions value)
    pure (Located declarationSpan (ImplDeclaration value{implFunctions = functions}))
  _ -> pure (Located declarationSpan declaration)

expandLocatedFunction :: Map Text Macro -> Int -> Located Function -> Expand (Located Function)
expandLocatedFunction macros depth (Located functionSpan value) =
  Located functionSpan <$> expandFunction macros depth value

expandFunction :: Map Text Macro -> Int -> Function -> Expand Function
expandFunction macros depth value = do
  parameters <- mapM (expandParameter macros depth) (functionParameters value)
  body <- mapM (expandBody macros depth) (functionBody value)
  pure value{functionParameters = parameters, functionBody = body}

expandParameter :: Map Text Macro -> Int -> Located Parameter -> Expand (Located Parameter)
expandParameter macros depth (Located parameterSpan parameter) = do
  defaultValue <- mapM (expandExpression macros depth) (parameterDefault parameter)
  pure (Located parameterSpan parameter{parameterDefault = defaultValue})

expandBody :: Map Text Macro -> Int -> Located FunctionBody -> Expand (Located FunctionBody)
expandBody macros depth (Located bodySpan body) = case body of
  BlockBody block -> Located bodySpan . BlockBody <$> expandBlock macros depth block
  ExpressionBody expression ->
    Located bodySpan . ExpressionBody <$> expandExpression macros depth expression

expandBlock :: Map Text Macro -> Int -> Located Block -> Expand (Located Block)
expandBlock macros depth (Located blockSpan block) = do
  statements <- mapM (expandStatement macros depth) (blockStatements block)
  result <- mapM (expandExpression macros depth) (blockResult block)
  pure (Located blockSpan (Block statements result))

expandStatement :: Map Text Macro -> Int -> Located Statement -> Expand (Located Statement)
expandStatement macros depth (Located statementSpan statement) = case statement of
  DeclarationStatement declaration ->
    Located statementSpan . DeclarationStatement <$> expandDeclaration macros depth declaration
  ExpressionStatement expression ->
    Located statementSpan . ExpressionStatement <$> expandExpression macros depth expression
  ReturnStatement value ->
    Located statementSpan . ReturnStatement <$> mapM (expandExpression macros depth) value
  _ -> pure (Located statementSpan statement)

expandExpression :: Map Text Macro -> Int -> Located Expression -> Expand (Located Expression)
expandExpression macros depth located@(Located expressionSpan expression) = case expression of
  MacroCall name arguments -> do
    expandedArguments <- mapM (expandExpression macros depth) arguments
    expandCall macros depth expressionSpan name expandedArguments
  UnaryExpression operator operand ->
    rebuild (UnaryExpression operator <$> expandExpression macros depth operand)
  BinaryExpression left operator right ->
    rebuild
      ( BinaryExpression
          <$> expandExpression macros depth left
          <*> pure operator
          <*> expandExpression macros depth right
      )
  CallExpression callee arguments ->
    rebuild
      ( CallExpression
          <$> expandExpression macros depth callee
          <*> mapM (expandExpression macros depth) arguments
      )
  MemberExpression target member ->
    rebuild (MemberExpression <$> expandExpression macros depth target <*> pure member)
  IndexExpression target index ->
    rebuild
      ( IndexExpression
          <$> expandExpression macros depth target
          <*> expandExpression macros depth index
      )
  TryExpression target -> rebuild (TryExpression <$> expandExpression macros depth target)
  AwaitExpression target -> rebuild (AwaitExpression <$> expandExpression macros depth target)
  TupleExpression members ->
    rebuild (TupleExpression <$> mapM (expandExpression macros depth) members)
  ArrayExpression members ->
    rebuild (ArrayExpression <$> mapM (expandExpression macros depth) members)
  RecordExpression path fields ->
    rebuild (RecordExpression path <$> mapM (expandFieldInit macros depth) fields)
  BlockExpression block -> rebuild (BlockExpression <$> expandBlock macros depth block)
  UnsafeExpression capabilities block ->
    rebuild (UnsafeExpression capabilities <$> expandBlock macros depth block)
  ScopeExpression block -> rebuild (ScopeExpression <$> expandBlock macros depth block)
  IfExpression condition thenBlock elseBranch ->
    rebuild
      ( IfExpression
          <$> expandExpression macros depth condition
          <*> expandBlock macros depth thenBlock
          <*> mapM (expandExpression macros depth) elseBranch
      )
  IfLetExpression pattern' subject thenBlock elseBranch ->
    rebuild
      ( IfLetExpression pattern'
          <$> expandExpression macros depth subject
          <*> expandBlock macros depth thenBlock
          <*> mapM (expandExpression macros depth) elseBranch
      )
  MatchExpression scrutinee arms ->
    rebuild
      ( MatchExpression
          <$> expandExpression macros depth scrutinee
          <*> mapM (expandArm macros depth) arms
      )
  WhileExpression label condition body ->
    rebuild
      ( WhileExpression label
          <$> expandExpression macros depth condition
          <*> expandBlock macros depth body
      )
  LoopExpression label body -> rebuild (LoopExpression label <$> expandBlock macros depth body)
  ForExpression label binder iterated body ->
    rebuild
      ( ForExpression label binder
          <$> expandExpression macros depth iterated
          <*> expandBlock macros depth body
      )
  _ -> pure located
 where
  rebuild build' = Located expressionSpan <$> build'

expandFieldInit :: Map Text Macro -> Int -> Located FieldInit -> Expand (Located FieldInit)
expandFieldInit macros depth (Located fieldSpan field) = do
  value <- mapM (expandExpression macros depth) (fieldInitValue field)
  pure (Located fieldSpan field{fieldInitValue = value})

expandArm :: Map Text Macro -> Int -> Located MatchArm -> Expand (Located MatchArm)
expandArm macros depth (Located armSpan arm) = do
  guard <- mapM (expandExpression macros depth) (armGuard arm)
  body <- expandExpression macros depth (armBody arm)
  pure (Located armSpan arm{armGuard = guard, armBody = body})

{-| Expand one call: check that the macro exists, that the argument count and
    kinds match what it declared, then substitute into a hygienic copy of the
    body. The result carries the call's span, so a later diagnostic points at
    what the reader wrote. -}
expandCall
  :: Map Text Macro
  -> Int
  -> Span
  -> Located Text
  -> [Located Expression]
  -> Expand (Located Expression)
expandCall macros depth callSpan name arguments
  | depth >= expansionLimit = do
      report "E1046" callSpan
        ("macro " <> locatedValue name <> " expanded past the depth limit")
        (Just "a macro that expands into itself has no fixed point; break the cycle")
      pure (Located callSpan InvalidExpression)
  | otherwise = case Map.lookup (locatedValue name) macros of
      Nothing -> do
        report "E1047" callSpan ("unknown macro " <> locatedValue name)
          (Just "declare the macro, or remove the ! if an ordinary call was meant")
        pure (Located callSpan InvalidExpression)
      Just macro -> do
        let parameters = macroParameters macro
        if length parameters /= length arguments
          then do
            report "E1048" callSpan
              ( "macro " <> locatedValue name <> " takes "
                  <> countText (length parameters)
                  <> " but the call passes " <> countText (length arguments)
              )
              (Just "pass one argument per declared parameter")
            pure (Located callSpan InvalidExpression)
          else do
            kindErrors <- mapM (checkKind name) (zip parameters arguments)
            if or kindErrors
              then pure (Located callSpan InvalidExpression)
              else do
                let bindings =
                      Map.fromList
                        [ (locatedValue (macroParamName (locatedValue parameter)), argument)
                        | (parameter, argument) <- zip parameters arguments
                        ]
                identifier <- fresh
                let substituted =
                      substituteExpression bindings identifier Map.empty callSpan (macroBody macro)
                expandExpression macros (depth + 1) substituted

countText :: Int -> Text
countText total = case total of
  1 -> "1 argument"
  _ -> Text.pack (show total) <> " arguments"

{-| An argument must be the kind of syntax its parameter declared. Reporting
    this against the call is the point of typed parameters: the message names
    the argument, not a matcher's state. -}
checkKind :: Located Text -> (Located MacroParam, Located Expression) -> Expand Bool
checkKind name (Located _ parameter, Located argumentSpan argument) =
  case (macroParamKind parameter, argument) of
    (ExpressionKind, _) -> pure False
    (IdentifierKind, NameExpression _) -> pure False
    (BlockKind, BlockExpression _) -> pure False
    {-| `E1054` rather than a code beside `E1048`, because `E1049` already
        belongs to the statement-separator rule [[grammar/pudu]] states. One
        code cannot mean two things: a reader who looked it up would be told
        about a macro argument or about a missing line break depending on which
        answer they found first. -}
    (kind, _) -> do
      report "E1054" argumentSpan
        ( "macro " <> locatedValue name <> " expects "
            <> kindName kind <> " for " <> locatedValue (macroParamName parameter)
        )
        (Just (kindHelp kind))
      pure True

kindName :: MacroKind -> Text
kindName kind = case kind of
  ExpressionKind -> "an expression"
  IdentifierKind -> "an identifier"
  BlockKind -> "a block"

kindHelp :: MacroKind -> Text
kindHelp kind = case kind of
  ExpressionKind -> "pass any expression"
  IdentifierKind -> "pass a bare name"
  BlockKind -> "pass a block in braces"

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
  RecordExpression path fields -> at (RecordExpression path (map recurseField fields))
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
