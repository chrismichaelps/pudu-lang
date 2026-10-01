module Pudu.Frontend.ExpandSpec (expandProperties) where

import Data.List.NonEmpty (NonEmpty ((:|)))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateEntryPoint)
import Pudu.Eval.Render (renderValue)
import Pudu.Frontend.Expand (expandModule)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser (ParseResult (..), parseModule)
import Pudu.Frontend.Syntax
  ( Block (..)
  , ComptimeFor (..)
  , Declaration (..)
  , Derive (..)
  , Expression (..)
  , Function (..)
  , FunctionBody (..)
  , Located (..)
  , Module (..)
  , Statement (..)
  )
import Pudu.Frontend.Token (Token)
import Pudu.Source (Source, SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

expandProperties :: [(String, IO Property)]
expandProperties =
  [ ("macros expand before the phases that follow", testExpansion)
  , ("arguments are parsed, so precedence cannot surprise", testPrecedence)
  , ("parameter kinds are checked against the call", testKinds)
  , ("introduced bindings cannot capture or leak", testHygiene)
  , ("a call that cannot expand reports once", testFailures)
  , ("derive surface keeps its shape while macro calls expand", testDeriveSurface)
  , ("a surviving compile-time loop reports E3090", testComptimeDiagnostic)
  , ("a loop element renames with its body", testComptimeHygiene)
  ]

testExpansion :: IO Property
testExpansion = do
  expression <- evaluateWith
    [ "macro twice(value: expr) = value + value" ]
    "twice!(20)"
  identifier <- evaluateWith
    [ "macro pick(name: ident) = name"
    , "fn chosen() -> Int { 5 }"
    ]
    "pick!(chosen)()"
  block <- evaluateWith
    [ "macro run(body: block) = body" ]
    "run!({ let inner = 3\n inner * 2 })"
  nested <- evaluateWith
    [ "macro twice(value: expr) = value + value"
    , "macro quadruple(value: expr) = twice!(twice!(value))"
    ]
    "quadruple!(5)"
  setMembers <- evaluateWith
    [ "macro twice(value: expr) = value + value" ]
    "#{twice!(2), twice!(1)}"
  setBody <- evaluateWith
    [ "macro neighbours(value: expr) = #{value, value + 1}" ]
    "neighbours!(3)"
  pure $ conjoin
    [ counterexample "an expression argument expands" (expression === "40")
    , counterexample "an identifier argument expands" (identifier === "5")
    , counterexample "a block argument expands" (block === "6")
    , counterexample "a macro may call another" (nested === "20")
    , counterexample "Set members are expanded" (setMembers === "#{2, 4}")
    , counterexample "a Set body substitutes every member" (setBody === "#{3, 4}")
    ]

testPrecedence :: IO Property
testPrecedence = do
  outer <- evaluateWith ["macro twice(value: expr) = value + value"] "2 * twice!(3)"
  inner <- evaluateWith ["macro twice(value: expr) = value + value"] "twice!(1 + 2)"
  pure $ conjoin
    [ counterexample "the expansion is grouped where it was called" (outer === "12")
    , counterexample "an argument keeps its own grouping" (inner === "6")
    ]

testKinds :: IO Property
testKinds = do
  identifierGiven <- codes
    [ "module M"
    , "macro pick(name: ident) = name"
    , "fn run() -> Int { pick!(1 + 1) }"
    ]
  blockGiven <- codes
    [ "module M"
    , "macro run(body: block) = body"
    , "fn go() -> Int { run!(7) }"
    ]
  expressionAccepts <- codes
    [ "module M"
    , "macro any(value: expr) = value"
    , "fn go() -> Int { any!(1 + 1) }"
    ]
  unknownKind <- codes
    [ "module M"
    , "macro bad(value: thing) = value"
    ]
  pure $ conjoin
    [ counterexample "an expression is not an identifier" (identifierGiven === ["E1054"])
    , counterexample "an expression is not a block" (blockGiven === ["E1054"])
    , counterexample "an expression parameter takes anything" (expressionAccepts === [])
    , counterexample "the kind vocabulary is closed" (unknownKind === ["E1045"])
    ]

testHygiene :: IO Property
testHygiene = do
  captured <- evaluateStatements
    [ "macro shadowing(value: expr) = { let hidden = value\n hidden * 10 }"
    , "let hidden = 1"
    , "shadowing!(hidden)"
    ]
  leaked <- evaluateStatements
    [ "macro shadowing(value: expr) = { let hidden = value\n hidden * 10 }"
    , "let hidden = 1"
    , "shadowing!(hidden)"
    , "hidden"
    ]
  patternBinding <- evaluateStatements
    [ "macro select(value: expr) = if let Some(hidden) = value { hidden * 10 } else { 0 }"
    , "let hidden = 1"
    , "select!(Some(hidden))"
    ]
  patternElse <- evaluateStatements
    [ "macro select(value: expr) = if let Some(hidden) = value { hidden * 10 } else { hidden }"
    , "let hidden = 3"
    , "select!(None)"
    ]
  patternAfter <- evaluateStatements
    [ "macro select(value: expr) = { if let Some(hidden) = value { hidden } else { 0 }\n hidden }"
    , "let hidden = 4"
    , "select!(None)"
    ]
  pure $ conjoin
    [ counterexample "the argument is not captured by the body's binding"
        (captured === "10")
    , counterexample "the body's binding does not leak to the caller" (leaked === "1")
    , counterexample "an if let binding is renamed with its successful uses"
        (patternBinding === "10")
    , counterexample "an if let binding does not rename a free else name"
        (patternElse === "3")
    , counterexample "an if let binding does not rename a later free name"
        (patternAfter === "4")
    ]

testFailures :: IO Property
testFailures = do
  unknown <- codes ["module M", "fn run() -> Int { missing!(1) }"]
  arity <- codes
    [ "module M"
    , "macro twice(value: expr) = value + value"
    , "fn run() -> Int { twice!(1, 2) }"
    ]
  recursive <- codes
    [ "module M"
    , "macro loopy(value: expr) = loopy!(value)"
    , "fn run() -> Int { loopy!(1) }"
    ]
  pure $ conjoin
    [ counterexample "an unknown macro is reported" (unknown === ["E1047"])
    , counterexample "arity is exact" (arity === ["E1048"])
    , counterexample "expansion is bounded" (recursive === ["E1046"])
    ]

evaluateWith :: [Text] -> Text -> IO Text
evaluateWith declarations expression = runProgram declarations [] expression

evaluateStatements :: [Text] -> IO Text
evaluateStatements entries = case reverse entries of
  final : leading -> case span isDeclaration (reverse leading) of
    (declarations, statements) -> runProgram declarations statements final
  [] -> pure "none"
 where
  isDeclaration line = Text.isPrefixOf "macro " line

runProgram :: [Text] -> [Text] -> Text -> IO Text
runProgram declarations statements expression = do
  let buffer =
        Text.unlines
          ( ["module Expand.Spec"]
              <> declarations
              <> ["fn __entry() {"]
              <> statements
              <> [expression, "}"]
          )
  source <- newSource (SourceName "expand.pudu") buffer
  result <- runCompile source
  case compileModule result of
    Nothing -> pure ("failed: " <> Text.intercalate "," (codesOf result))
    Just parsed -> do
      outcome <- evaluateEntryPoint (compileIntegerKinds result) "__entry" parsed
      case outcomeValue outcome of
        Nothing -> pure "no value"
        Just value -> pure (renderValue value)

codes :: [Text] -> IO [Text]
codes inputLines = do
  source <- newSource (SourceName "expand.pudu") (Text.unlines inputLines)
  codesOf <$> runCompile source

testDeriveSurface :: IO Property
testDeriveSurface = do
  source <- newSource (SourceName "derive.pudu") (Text.unlines
    [ "module M"
    , "macro twice(value: expr) = value + value"
    , "derive Encode for T: Record {"
    , "  fn encode(self: &T) -> Str { twice!(\"x\") }"
    , "}"
    , "fn run(items: Array[Int]) -> Int {"
    , "  var total = 0"
    , "  comptime for item: Int in twice!(items) {"
    , "    total = total + item"
    , "  }"
    , "  total"
    , "}"
    ])
  pure $ case parseModule source (lexTokensOf source) of
    ParseResult Nothing _ -> counterexample "module parses" False
    ParseResult (Just moduleValue) _ ->
      let (expanded, diagnostics) = expandModule moduleValue
          counts = countNodes expanded
       in conjoin
        [ counterexample "no expansion diagnostics" (null diagnostics)
        , counterexample "one derive kept" (deriveCount counts === 1)
        , counterexample "one compile-time loop kept" (comptimeCount counts === 1)
        , counterexample "every macro call expanded" (macroCallCount counts === 0)
        ]

testComptimeDiagnostic :: IO Property
testComptimeDiagnostic = do
  found <- codes
    [ "module M"
    , "fn run(items: Array[Int]) -> Int {"
    , "  var total = 0"
    , "  comptime for item: Int in items {"
    , "    total = total + item"
    , "  }"
    , "  total"
    , "}"
    ]
  pure $ counterexample "E3090 names the missing phase" ("E3090" `elem` found)

testComptimeHygiene :: IO Property
testComptimeHygiene = do
  source <- newSource (SourceName "derive.pudu") (Text.unlines
    [ "module M"
    , "macro build(items: expr) = comptime for item: Int in items { item }"
    , "fn run() -> Int { build!([1]) }"
    ])
  pure $ case parseModule source (lexTokensOf source) of
    ParseResult Nothing _ -> counterexample "module parses" False
    ParseResult (Just moduleValue) _ ->
      let (expanded, _) = expandModule moduleValue
       in case findLoop expanded of
        Nothing -> counterexample "one compile-time loop" False
        Just loop -> conjoin
          [ counterexample "element renamed" (element /= "item")
          , counterexample "body follows the binding" (filter (== element) (bodyRefs loop) === [element])
          , counterexample "source substituted" (isExpandedSource (comptimeForSource loop))
          ]
         where
          element = locatedValue (comptimeForElement loop)

findLoop :: Module -> Maybe ComptimeFor
findLoop moduleValue = searchDeclarations (moduleDeclarations moduleValue)
 where
  searchDeclarations [] = Nothing
  searchDeclarations (Located _ declaration : rest) = case declaration of
    FunctionDeclaration function -> case functionBody function of
      Just locatedBody -> case locatedValue locatedBody of
        BlockBody locatedBlock -> case searchBlock locatedBlock of
          Just loop -> Just loop
          Nothing -> searchDeclarations rest
        _ -> searchDeclarations rest
      Nothing -> searchDeclarations rest
    _ -> searchDeclarations rest
  searchBlock (Located _ block) = case searchStatements (blockStatements block) of
    Just loop -> Just loop
    Nothing -> case blockResult block of
      Just expression -> searchExpression expression
      Nothing -> Nothing
  searchStatements [] = Nothing
  searchStatements (Located _ statement : rest) = case statement of
    ExpressionStatement expression -> case searchExpression expression of
      Just loop -> Just loop
      Nothing -> searchStatements rest
    _ -> searchStatements rest
  searchExpression expression = case locatedValue expression of
    ComptimeForExpression loop -> Just loop
    _ -> Nothing

bodyRefs :: ComptimeFor -> [Text]
bodyRefs loop = case locatedValue (comptimeForBody loop) of
  Block statements result ->
    concatMap statementRefs statements <> foldMap expressionRefs result
 where
  statementRefs statement = case locatedValue statement of
    ExpressionStatement expression -> expressionRefs expression
    _ -> []
  expressionRefs expression = case locatedValue expression of
    NameExpression (single :| []) -> [single]
    BinaryExpression left _ right -> expressionRefs left <> expressionRefs right
    _ -> []

isExpandedSource :: Located Expression -> Bool
isExpandedSource expression = case locatedValue expression of
  MacroCall _ _ -> False
  _ -> True

lexTokensOf :: Source -> [Token]
lexTokensOf source = case lexSource source of
  LexResult{lexTokens} -> lexTokens

data NodeCounts = NodeCounts
  { deriveCount :: Int
  , comptimeCount :: Int
  , macroCallCount :: Int
  }

countNodes :: Module -> NodeCounts
countNodes moduleValue = foldMap countDeclaration (moduleDeclarations moduleValue)
 where
  zero = NodeCounts 0 0 0
  one derive comptime macro = NodeCounts derive comptime macro
  countDeclaration (Located _ declaration) = case declaration of
    DeriveDeclaration value ->
      one 1 0 0 <> foldMap (countFunction . locatedValue) (deriveFunctions value)
    FunctionDeclaration function -> countFunction function
    _ -> zero
  countFunction function = case functionBody function of
    Just (Located _ (BlockBody block)) -> countBlock block
    _ -> zero
  countBlock (Located _ block) =
    foldMap countStatement (blockStatements block)
      <> foldMap countExpression (blockResult block)
  countStatement statement = case locatedValue statement of
    ExpressionStatement expression -> countExpression expression
    DeclarationStatement nested -> countDeclaration nested
    ReturnStatement result -> foldMap countExpression result
    _ -> zero
  countExpression expression = case locatedValue expression of
    MacroCall _ arguments -> one 0 0 1 <> foldMap countExpression arguments
    ComptimeForExpression loop ->
      one 0 1 0 <> countExpression (comptimeForSource loop) <> countBlock (comptimeForBody loop)
    CallExpression callee arguments ->
      countExpression callee <> foldMap countExpression arguments
    BlockExpression block -> countBlock block
    _ -> zero

instance Semigroup NodeCounts where
  left <> right = NodeCounts
    { deriveCount = deriveCount left + deriveCount right
    , comptimeCount = comptimeCount left + comptimeCount right
    , macroCallCount = macroCallCount left + macroCallCount right
    }

instance Monoid NodeCounts where
  mempty = NodeCounts 0 0 0

codesOf :: CompileResult -> [Text]
codesOf result = map (diagnosticCodeText . diagnosticCode) (compileDiagnostics result)
