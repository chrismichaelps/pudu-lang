module Pudu.Frontend.ParserExpressionSpec (parserExpressionProperties) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Diagnostic
  , diagnosticCode
  , diagnosticCodeText
  , diagnosticHelp
  , diagnosticSpan
  )
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Expression (parseExpression)
import Pudu.Frontend.Parser.State (Parser, expectSymbol, peekKind, runParser)
import Pudu.Repl.Outline (outlineExpression)
import Pudu.Frontend.Syntax
  ( Block (..)
  , Expression (..)
  , FieldInit (..)
  , FieldPattern (..)
  , Function (..)
  , Parameter (..)
  , Literal (..)
  , Located (..)
  , MatchArm (..)
  , Pattern (..)
  , moduleNameText
  )
import Pudu.Frontend.Token (SymbolKind (..), Token (tokenSpan), TokenKind (..))
import Pudu.Source (SourceName (SourceName), mergeSpans, newSource, spanStart, unOffset)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

parserExpressionProperties :: [(String, IO Property)]
parserExpressionProperties =
  [ ("binary precedence and associativity are explicit", testPrecedence)
  , ("closed binary vocabulary parses exhaustively", testBinaryVocabulary)
  , ("literal vocabulary maps into expression nodes", testLiterals)
  , ("function literals parse in both body forms", testLambdas)
  , ("type arguments are told from an index", testTypeArguments)
  , ("postfix calls and members bind before binary operators", testPostfix)
  , ("unary borrow and conditional blocks preserve structure", testUnaryIf)
  , ("if let binds one refutable pattern", testIfLet)
  , ("expression recovery emits exact diagnostics", testRecovery)
  , ("reserved keywords produce E1041 with guidance", testReservedKeywords)
  , ("index failure-propagation and await postfix forms parse", testPostfixForms)
  , ("match while loop and for parse as expressions", testControlExpressions)
  , ("control owners survive mixed-chain recovery", testControlRecovery)
  , ("tuples and record constructions parse", testAggregates)
  , ("hostile postfix and binary chains share the nesting budget", testHostileChains)
  , ("hostile ambiguous tails share the nesting budget", testHostileAmbiguousTails)
  , ("hostile else-if chains share the nesting budget", testHostileConditionals)
  , ("an exhausted budget reports once and stops", testExhaustedBudgetIsQuiet)
  , ("every precedence band binds as the grammar states", testPrecedenceBands)
  , ("an operator that cannot begin an expression continues the line above", testLineLeadingOperators)
  ]

{-| An operator written at the start of a line joins the expression above it,
    except where reading it that way would change a program that already had a
    meaning.

    Every operator without a prefix form continues: a line starting with one
    could not have begun a statement, so the only reading it ever had was a
    parse error. `-`, `&` and `*` do have a prefix form, so a line starting
    with one still begins a statement — `total\n-1` is a negation on its own
    line, as it always was, and the subtraction is written by ending the line
    above with the operator instead. -}
testLineLeadingOperators :: IO Property
testLineLeadingOperators = do
  let continuingOperators =
        [ "=", "||", "|", "&&", "==", "!=", "<", "<=", ">", ">="
        , "in"
        , "..", "..=", "^", "<<", ">>", "+", "&+", "&-", "+|", "-|"
        , "/", "%", "&*", "*|"
        ]
  continued <- traverse (\operator -> parse ("a\n" <> operator <> " b")) continuingOperators
  let expected = map (\operator -> "(a" <> operator <> "b)") continuingOperators
  -- A trailing operator has always continued, and still does.
  trailing <- parse "a +\nb"
  -- These three keep their prefix reading, so the expression ends at `a` and
  -- the operator is left in the stream for whatever parses next. Reading one
  -- expression here leaves those tokens over, which is the observable form of
  -- "this did not join".
  prefixed <- traverse parse ["a\n- b", "a\n& b", "a\n* b"]
  mixed <- traverse parse
    [ "a\n+ b\n- c", "a\n== b\n& c", "a\n/ b\n* c", "a == b\n+ c\n- d" ]
  delimited <- traverse parse
    [ "(a\n+ b\n- c)"
    , "f(a\n+ b\n- c)"
    , "values[a\n+ b\n- c]"
    , "[a\n+ b\n- c]"
    , "(a\n+ b\n- nested(c), d)"
    , "(a\n+ b\n- c\n& d\n* e)"
    ]
  -- Indentation is not what decides it; a continuation may sit anywhere.
  unindented <- parse "a\n+ b"
  deeplyIndented <- parse "a\n        + b"
  pure $ conjoin
    [ counterexample "operators with no prefix form join the line above"
        (map validShape continued === expected)
    , counterexample "a trailing operator still continues"
        (validShape trailing === "(a+b)")
    , counterexample "an operator that can begin an expression is left for the next statement"
        (map (shape . firstOf) prefixed === ["a", "a", "a"])
    , counterexample "and the operator itself is still waiting in the stream"
        (map remainingOf prefixed
          === [Symbol SymMinus, Symbol SymAmpersand, Symbol SymStar])
    , counterexample "a prefix spelling after a leading-operator chain is refused once"
        (map codes mixed === replicate 4 ["E1055"])
    , counterexample "the ambiguous operator remains available to the statement parser"
        (map remainingOf mixed
          === [Symbol SymMinus, Symbol SymAmpersand, Symbol SymStar, Symbol SymMinus])
    , counterexample "delimited ambiguity produces exactly one diagnostic"
        (map codes delimited === replicate 6 ["E1055"])
    , counterexample "group, call, index, array, and tuple owners still receive their delimiter"
        (map remainingOf delimited === replicate 6 EndOfFile)
    , counterexample "the diagnostic points at the ambiguous operator"
        (map diagnosticOffsets mixed === [[6], [7], [6], [11]])
    , counterexample "the diagnostic explains the two explicit spellings"
        ( map helps mixed
          === [ ["end the preceding line with - to continue, or wrap this prefix expression in parentheses to start a new statement"]
              , ["end the preceding line with & to continue, or wrap this prefix expression in parentheses to start a new statement"]
              , ["end the preceding line with * to continue, or wrap this prefix expression in parentheses to start a new statement"]
              , ["end the preceding line with - to continue, or wrap this prefix expression in parentheses to start a new statement"]
              ]
        )
    , counterexample "delimited help does not promise an impossible statement"
        ( map helps delimited
          === [ ["end the preceding line with - to continue, or rewrite the enclosing expression so this prefix expression is not adjacent to the chain"]
              , ["end the preceding line with - to continue, or rewrite the enclosing expression so this prefix expression is not adjacent to the chain"]
              , ["end the preceding line with - to continue, or rewrite the enclosing expression so this prefix expression is not adjacent to the chain"]
              , ["end the preceding line with - to continue, or rewrite the enclosing expression so this prefix expression is not adjacent to the chain"]
              , ["end the preceding line with - to continue, or rewrite the enclosing expression so this prefix expression is not adjacent to the chain"]
              , ["end the preceding line with - to continue, or rewrite the enclosing expression so this prefix expression is not adjacent to the chain"]
              ]
        )
    , counterexample "indentation does not decide it"
        (validShape unindented === validShape deeplyIndented)
    ]

testPrecedence :: IO Property
testPrecedence = do
  assignment <- parse "a = b = c"
  subtraction <- parse "a - b - c"
  mixed <- parse "a + b * c"
  membership <- parse "a in b == c"
  comparisonMembership <- parse "a < b in c"
  pure $ conjoin [validShape assignment === "(a=(b=c))",
    validShape subtraction === "((a-b)-c)", validShape mixed === "(a+(b*c))",
    validShape membership === "((ainb)==c)",
    validShape comparisonMembership === "((a<b)inc)"]

testBinaryVocabulary :: IO Property
testBinaryVocabulary = do
  let operators = ["=", "||", "&&", "==", "!=", "<", "<=", ">", ">=", "in", "..", "..=",
        "<<", ">>", "^", "|", "+", "-", "&+", "&-", "+|", "-|", "*", "/", "%", "&*", "*|"]
  results <- traverse (\operator -> parse ("a " <> operator <> " b")) operators
  pure (map validShape results === map (\operator -> "(a" <> operator <> "b)") operators)

testLiterals :: IO Property
testLiterals = do
  results <- traverse parse ["1", "1.5", "\"hi\"", "'x'", "true", "false", "null"]
  pure (map validShape results === ["1", "1.5", "hi", "x", "true", "false", "null"])

{-| The `fn` keyword introduces a literal wherever an expression may start. It
    is the same spelling the function *type* already uses, and it could not
    previously begin an expression, so nothing became ambiguous. -}
testLambdas :: IO Property
testLambdas = do
  arrow <- parse "fn(x) => x + 1"
  block <- parse "fn(x: Int) -> Int {}"
  empty <- parse "fn() => 1"
  several <- parse "fn(a, b) => a"
  asynchronous <- parse "async fn(x) => x"
  applied <- parse "items.map(fn(x) => x)"
  missingBody <- codes <$> parse "fn(x) x"
  pure $ conjoin
    [ counterexample "an arrow body parses" (validShape arrow === "fn(x)")
    , counterexample "a block body parses" (validShape block === "fn(x)")
    , counterexample "no parameters parses" (validShape empty === "fn()")
    , counterexample "several parameters parse" (validShape several === "fn(a,b)")
    , counterexample "an async literal parses" (validShape asynchronous === "fn(x)")
    , counterexample "a literal is an ordinary argument" (validShape applied === "items.map(fn(x))")
    , counterexample "a missing body names both forms" (missingBody === ["E1032"])
    ]

{-| A type-argument list and an index both open with `[`. Two things decide it:
    the closing bracket is followed by `(`, and the first token inside could
    begin a type — which for an identifier means it is capitalised, as every
    type name is and no value name is. -}
testTypeArguments :: IO Property
testTypeArguments = do
  applied <- parse "convert[UInt8](value)"
  several <- parse "convert[UInt8, Int](value)"
  byLiteral <- parse "handlers[0](value)"
  byName <- parse "handlers[index](value)"
  plainIndex <- parse "handlers[0]"
  qualified <- parse "Num.small[UInt16](value)"
  notCalled <- parse "handlers[Thing]"
  pure $ conjoin
    [ counterexample "a capitalised name before a call is a type argument"
        (validShape applied === "convert[T](value)")
    , counterexample "several type arguments parse"
        (validShape several === "convert[T,T](value)")
    , counterexample "an index by a literal stays an index"
        (validShape byLiteral === "handlers[0](value)")
    , counterexample "an index by a variable stays an index"
        (validShape byName === "handlers[index](value)")
    , counterexample "an index with no call stays an index"
        (validShape plainIndex === "handlers[0]")
    , counterexample "a qualified name carries type arguments"
        (validShape qualified === "Num.small[T](value)")
    , counterexample "a capitalised index with no call stays an index"
        (validShape notCalled === "handlers[Thing]")
    ]

testPostfix :: IO Property
testPostfix = do
  result <- parse "service.fetch(1, 2,).name + 3"
  pure (validShape result === "(service.fetch(1,2).name+3)")

testUnaryIf :: IO Property
testUnaryIf = do
  unary <- parse "&mut -value"
  conditional <- parse "if true {} else if false {} else {}"
  pure $ conjoin [validShape unary === "(&mut(-value))", validShape conditional === "if"]

testIfLet :: IO Property
testIfLet = do
  present <- parse "if let Some(value) = candidate {} else {}"
  absentElse <- parse "if let Some(value) = candidate {}"
  chained <- parse
    "if let Some(first) = left {} else if let Some(second) = right {} else {}"
  irrefutable <- traverse parse
    [ "if let value = candidate {}"
    , "if let _ = candidate {}"
    , "if let (first, second) = pair {}"
    , "if let {value} = record {}"
    , "if let _ | Some(value) = candidate {}"
    ]
  missingPattern <- parse "if let = candidate {}"
  missingEquals <- parse "if let Some(value) candidate {}"
  pure $ conjoin
    [ counterexample "the surface node retains pattern subject and else"
        (validShape present === "if let Some(value) = candidate else")
    , counterexample "else remains optional"
        (validShape absentElse === "if let Some(value) = candidate")
    , counterexample "else if let nests as a conditional chain"
        (validShape chained === "if let Some(first) = left else")
    , counterexample ":ast retains if let rather than inventing match"
        (outlineExpression (firstOf present) === "if let Some(value) = candidate else ...")
    , counterexample "syntactically irrefutable patterns are rejected"
        (map codes irrefutable === replicate 5 ["E1056"])
    , counterexample "E1056 points at the pattern"
        (map diagnosticOffsets irrefutable === [[7], [7], [7], [7], [7]])
    , counterexample "E1056 explains the unconditional form"
        ( map helps irrefutable
          === replicate 5
            ["use let for an unconditional binding, or choose a pattern that can fail"]
        )
    , counterexample "a missing pattern preserves the owned equals"
        (codes missingPattern === ["E1050"])
    , counterexample "a missing equals is owned once"
        (codes missingEquals === ["E1001"])
    ]

testRecovery :: IO Property
testRecovery = do
  missing <- parse "a +"
  invalid <- parse ")"
  malformedElse <- parse "if true {} else 1"
  delimited <- parse "(a +)"
  {-| A token the lexer marked invalid has already been diagnosed, and
      precisely: `"{}"` is an interpolation with no expression. Saying "expected expression" over the top gives the
      reader two diagnostics for one mistake, with the less useful one first.

      This harness collects parser diagnostics only, so an empty list here is
      the parser staying quiet; the lexer's own message is covered by
      [[Lexer Quoted]]'s tests. -}
  emptyHole <- parse "\"{}\""
  pure $ conjoin [codes missing === ["E1040"], codes invalid === ["E1040"],
    codes malformedElse === ["E1042"], diagnosticOffsets malformedElse === [16],
    codes delimited === ["E1040"], resultKind delimited === EndOfFile,
    counterexample "the parser adds nothing to an invalid string"
      (codes emptyHole === [])]

testReservedKeywords :: IO Property
testReservedKeywords = do
  enumKw <- parse "enum Color { Red, Green, Blue }"
  structKw <- parse "struct Point { x: Int, y: Int }"
  taskKw <- parse "task foo() -> Int { 42 }"
  spawnKw <- parse "spawn bar()"
  moduleKw <- parse "module M"
  mutKw <- parse "mut x = 5"
  pure $ conjoin
    [ counterexample "enum produces E1041" (codes enumKw === ["E1041"])
    , counterexample "enum help points to type" (helps enumKw === ["enum is reserved; use type for sum and record declarations"])
    , counterexample "struct produces E1041" (codes structKw === ["E1041"])
    , counterexample "struct help points to type" (helps structKw === ["struct is reserved; use type for record declarations"])
    , counterexample "task produces E1041" (codes taskKw === ["E1041"])
    , counterexample "task help points to async fn and scope" (helps taskKw === ["task is reserved; use async fn and scope for structured concurrency"])
    , counterexample "spawn produces E1041" (codes spawnKw === ["E1041"])
    , counterexample "spawn help points to async fn and scope" (helps spawnKw === ["spawn is reserved; use async fn and scope for structured concurrency"])
    , counterexample "module produces E1041" (codes moduleKw === ["E1041"])
    , counterexample "module help explains file-only" (helps moduleKw === ["module declarations are only valid at the top of a file"])
    , counterexample "mut produces E1041" (codes mutKw === ["E1041"])
    , counterexample "mut help points to var" (helps mutKw === ["use var for mutable bindings; mut modifies references and fields"])
    , counterexample "enum recovers without cascade" (resultKind enumKw === EndOfFile)
    , counterexample "struct recovers without cascade" (resultKind structKw === EndOfFile)
    , counterexample "task recovers without cascade" (resultKind taskKw === EndOfFile)
    , counterexample "spawn recovers without cascade" (resultKind spawnKw === EndOfFile)
    , counterexample "module recovers without cascade" (resultKind moduleKw === EndOfFile)
    , counterexample "mut recovers without cascade" (resultKind mutKw === EndOfFile)
    ]

testPostfixForms :: IO Property
testPostfixForms = do
  index <- parse "a[0]"
  propagation <- parse "read()?"
  awaiting <- parse "fetch().await"
  chained <- parse "rows[i].value?.await"
  pure $ conjoin
    [ validShape index === "a[0]"
    , validShape propagation === "read()?"
    , validShape awaiting === "fetch().await"
    , validShape chained === "rows[i].value?.await"
    ]

testControlExpressions :: IO Property
testControlExpressions = do
  matched <- parse "match value {\n  case Ok(v) if v > 0 => v\n  case _ => 0\n}"
  loopValue <- parse "loop {}"
  whileValue <- parse "while ready {}"
  forValue <- parse "for item in items {}"
  labelledLoop <- parse "@retry loop {}"
  labelledWhile <- parse "@outer while ready {}"
  labelledFor <- parse "@rows for item in items {}"
  strayLabel <- parse "@rows item"
  pure $ conjoin
    [ validShape matched === "match(value){Ok(v) if (v>0)=>v;_=>0}"
    , validShape loopValue === "loop"
    , validShape whileValue === "while(ready)"
    , validShape forValue === "for item in items"
    , counterexample "a label attaches to the loop that follows it"
        (validShape labelledLoop === "@retry loop")
    , validShape labelledWhile === "@outer while(ready)"
    , validShape labelledFor === "@rows for item in items"
    , counterexample "a label naming no loop is rejected where it was written"
        (codes strayLabel === ["E1053"])
    ]

{-| Recovery consumes the ambiguous prefix expression, not raw punctuation.
    The grammar therefore leaves each control form's actual owner token even
    though those owners are `{`, `=>`, `case`, and `}` rather than delimiters
    used by calls and aggregates. -}
testControlRecovery :: IO Property
testControlRecovery = do
  condition <- parse "if a\n+ b\n- c {} else {}"
  whileCondition <- parse "while a\n+ b\n- c {}"
  forIterable <- parse "for x in a\n+ b\n- c {}"
  matchScrutinee <- parse "match a\n+ b\n- c { case _ => 0 }"
  matchGuard <- parse
    "match value {\ncase x if a\n+ b\n- c => 1\ncase _ => 0\n}"
  matchBody <- parse
    "match value {\ncase 0 => a\n+ b\n- c\ncase _ => 0\n}"
  repeated <- parse "if a\n+ b\n- c\n& d\n* e {}"
  let recovered =
        [ condition, whileCondition, forIterable, matchScrutinee, matchGuard, matchBody, repeated ]
  pure $ conjoin
    [ counterexample "every control ambiguity is diagnosed exactly once"
        (map codes recovered === replicate 7 ["E1055"])
    , counterexample "every control owner completes its enclosing expression"
        (map remainingOf recovered === replicate 7 EndOfFile)
    , counterexample "if, while, for, and match structure survives recovery"
        ( map (shape . firstOf) recovered
          === [ "if"
              , "while((a+b))"
              , "for x in (a+b)"
              , "match((a+b)){_=>0}"
              , "match(value){x if (a+b)=>1;_=>0}"
              , "match(value){0=>(a+b);_=>0}"
              , "if"
              ]
        )
    ]

labelShape :: Maybe (Located Text) -> Text
labelShape = foldMap (\label -> "@" <> locatedValue label <> " ")

testAggregates :: IO Property
testAggregates = do
  tuple <- parse "(1, 2, 3)"
  grouped <- parse "(1 + 2)"
  record <- parse "User{id: 1, name: n}"
  shorthand <- parse "User{id, name}"
  qualified <- parse "Core.User{id: 1}"
  nested <- parse "Wrapper{inner: User{id: 2}}"
  blockNotRecord <- parse "if READY {} else {}"
  parenthesized <- parse "if (User{id: 1}).id > 0 {} else {}"
  setLiteral <- parse "#{3, 1, 2, 1,}"
  emptySet <- parse "#{}"
  recordMember <- parse "#{User{id: 1}}"
  pure $ conjoin
    [ validShape tuple === "(1,2,3)"
    , counterexample "one member without a comma groups" (validShape grouped === "(1+2)")
    , validShape record === "User{id:1,name:n}"
    , counterexample "a field without a value is shorthand"
        (validShape shorthand === "User{id,name}")
    , validShape qualified === "Core.User{id:1}"
    , validShape nested === "Wrapper{inner:User{id:2}}"
    , counterexample "a condition keeps its block"
        (validShape blockNotRecord === "if")
    , counterexample "parentheses reinstate a record construction"
        (validShape parenthesized === "if")
    , counterexample "a Set retains written members and a trailing comma"
        (validShape setLiteral === "#{3,1,2,1}")
    , counterexample "the REPL outline retains written Set order"
        (outlineExpression (firstOf setLiteral) === "#{3, 1, 2, 1}")
    , counterexample "an empty Set is a distinct aggregate"
        (validShape emptySet === "#{}")
    , counterexample "records are admitted inside a Set literal"
        (validShape recordMember === "#{User{id:1}}")
    ]

testHostileChains :: IO Property
testHostileChains = do
  members <- parse ("root" <> Text.concat (replicate 520 ".x"))
  binaries <- parse ("a" <> Text.concat (replicate 520 " + a"))
  arguments <- parse ("f(" <> Text.intercalate "," (replicate 520 "a") <> ")")
  setMembers <- parse ("#{" <> Text.intercalate "," (replicate 520 "a") <> "}")
  pure $ conjoin [codes members === ["E1099"], codes binaries === ["E1099"],
    codes arguments === ["E1099"], codes setMembers === ["E1099"],
    diagnosticOffsets arguments === [1022]]

testHostileAmbiguousTails :: IO Property
testHostileAmbiguousTails = do
  let tailLines = Text.concat (replicate 520 "\n- c")
  delimited <- parse ("(a\n+ b" <> tailLines <> ")")
  pure $ conjoin
    [ counterexample "the ambiguity is owned once before budget exhaustion"
        (codes delimited === ["E1055", "E1099"])
    , counterexample "budget exhaustion suppresses missing-delimiter cascades"
        (length (codes delimited) === 2)
    ]

testHostileConditionals :: IO Property
testHostileConditionals = do
  let input = "if true {}" <> Text.concat (replicate 519 " else if true {}")
      patternInput =
        "if let Some(value) = Some(1) {}"
          <> Text.concat (replicate 519 " else if let Some(value) = Some(1) {}")
  result <- parse input
  patternResult <- parse patternInput
  pure $ conjoin
    [ codes result === ["E1099"]
    , diagnosticOffsets result === [8179]
    , counterexample "if let chains use the same shared budget"
        (codes patternResult === ["E1099"])
    ]

{-| Once the budget is gone the parse has given up, and every message after
    that describes the wreckage rather than the mistake.

    Five thousand nested parentheses used to report one `E1099` and then four
    and a half thousand `E1001`s as recovery unwound past each unmatched
    delimiter — one hostile file amplified into thousands of diagnostics, which
    is the cascade the budget exists to prevent. -}
testExhaustedBudgetIsQuiet :: IO Property
testExhaustedBudgetIsQuiet = do
  balanced <- parse (Text.replicate 5000 "(" <> "1" <> Text.replicate 5000 ")")
  unclosed <- parse (Text.replicate 5000 "(" <> "1")
  brackets <- parse (Text.replicate 5000 "[" <> Text.replicate 5000 "]")
  pure $ conjoin
    [ counterexample "a balanced flood reports once" (codes balanced === ["E1099"])
    , counterexample "an unclosed flood reports once" (codes unclosed === ["E1099"])
    , counterexample "and so does a bracket flood" (codes brackets === ["E1099"])
    ]

{-| Check the precedence table in [[grammar/pudu]] band by band.

    The grammar states one ordering, tightest to loosest, and this walks every
    adjacent pair of bands: for a tighter operator `t` and a looser one `l`,
    `a t b l c` must parse as `(a t b) l c`. A table stated in prose and a table
    implemented in a parser are two tables until something compares them. -}
testPrecedenceBands :: IO Property
testPrecedenceBands = do
  {-| One representative per band, tightest first, in the order
      [[grammar/pudu]] lists them: multiplicative, additive, shift, range and
      bitwise xor, comparison, equality, boolean and, boolean or. -}
  let bands :: [Text]
      bands = ["*", "+", "<<", "^", "<", "==", "&&", "||"]
      adjacent = zip bands (drop 1 bands)
  tighter <- traverse (\(t, l) -> parse ("a " <> t <> " b " <> l <> " c")) adjacent
  let expected = ["((a" <> t <> "b)" <> l <> "c)" | (t, l) <- adjacent]
  associativity <- traverse (\op -> parse ("a " <> op <> " b " <> op <> " c")) bands
  let leftAssociative = ["((a" <> op <> "b)" <> op <> "c)" | op <- bands]
  assignment <- parse "a = b = c"
  unaryBinding <- parse "-a * -b"
  postfixBinding <- parse "-f(a)"
  pure $ conjoin
    [ counterexample "each band binds tighter than the next"
        (map validShape tighter === expected)
    , counterexample "every binary band is left-associative"
        (map validShape associativity === leftAssociative)
    , counterexample "assignment is right-associative"
        (validShape assignment === "(a=(b=c))")
    , counterexample "a prefix operator binds tighter than every binary one"
        (validShape unaryBinding === "((-a)*(-b))")
    , counterexample "and looser than every postfix one"
        (validShape postfixBinding === "(-f(a))")
    ]

parse :: Text -> IO (Located Expression, TokenKind, [Diagnostic])
parse input = do
  source <- newSource (SourceName "expression.pudu") input
  let LexResult{lexTokens} = lexSource source
      action = (,) <$> parseExpression emptyBlock <*> peekKind
      ((expression, remainingKind), diagnostics) = runParser source action lexTokens
  pure (expression, remainingKind, diagnostics)

emptyBlock :: Parser (Located Block)
emptyBlock = do
  opening <- expectSymbol "{" "to start the block"
  closing <- expectSymbol "}" "to close the block"
  let spanValue = maybe (tokenSpan opening) id (mergeSpans (tokenSpan opening) (tokenSpan closing))
  pure (Located spanValue (Block [] Nothing))

firstOf :: (Located Expression, TokenKind, [Diagnostic]) -> Located Expression
firstOf (expression, _, _) = expression

remainingOf :: (Located Expression, TokenKind, [Diagnostic]) -> TokenKind
remainingOf (_, remainingKind, _) = remainingKind

validShape :: (Located Expression, TokenKind, [Diagnostic]) -> Text
validShape (expression, remainingKind, diagnostics)
  | remainingKind == EndOfFile && null diagnostics = shape expression
  | otherwise = "invalid:" <> Text.pack (show (remainingKind, map diagnosticCode diagnostics))

codes :: (Located Expression, TokenKind, [Diagnostic]) -> [Text]
codes (_, _, diagnostics) = map (diagnosticCodeText . diagnosticCode) diagnostics

helps :: (Located Expression, TokenKind, [Diagnostic]) -> [Text]
helps (_, _, diagnostics) = map (maybe Text.empty id . diagnosticHelp) diagnostics

diagnosticOffsets :: (Located Expression, TokenKind, [Diagnostic]) -> [Int]
diagnosticOffsets (_, _, diagnostics) = map (unOffset . spanStart . diagnosticSpan) diagnostics

resultKind :: (Located Expression, TokenKind, [Diagnostic]) -> TokenKind
resultKind (_, kind, _) = kind

shape :: Located Expression -> Text
shape (Located _ expression) = case expression of
  LiteralExpression literalValue -> literalShape literalValue
  NameExpression names -> Text.intercalate "." (NonEmpty.toList names)
  UnaryExpression operator operand -> "(" <> operator <> shape operand <> ")"
  BinaryExpression left operator right -> "(" <> shape left <> operator <> shape right <> ")"
  CallExpression callee arguments -> shape callee <> "(" <> Text.intercalate "," (map shape arguments) <> ")"
  TypeApplication target arguments ->
    shape target <> "[" <> Text.intercalate "," (map (const "T") arguments) <> "]"
  LambdaExpression value ->
    "fn(" <> Text.intercalate "," (map (locatedValue . parameterName . locatedValue) (functionParameters value)) <> ")"
  MemberExpression target member -> shape target <> "." <> locatedValue member
  IndexExpression target index -> shape target <> "[" <> shape index <> "]"
  TryExpression target -> shape target <> "?"
  AwaitExpression target -> shape target <> ".await"
  BlockExpression _ -> "block"
  IfExpression{} -> "if"
  IfLetExpression pattern' subject _ elseBranch ->
    "if let " <> patternShape pattern' <> " = " <> shape subject
      <> maybe Text.empty (const " else") elseBranch
  MatchExpression scrutinee arms ->
    "match(" <> shape scrutinee <> "){"
      <> Text.intercalate ";" (map armShape arms) <> "}"
  WhileExpression label condition _ -> labelShape label <> "while(" <> shape condition <> ")"
  WhileLetExpression label pattern' subject _ ->
    labelShape label <> "while let " <> patternShape pattern' <> "=" <> shape subject
  LoopExpression label _ -> labelShape label <> "loop"
  ForExpression label binder iterated _ ->
    labelShape label <> "for " <> patternShape binder <> " in " <> shape iterated
  TupleExpression members -> "(" <> Text.intercalate "," (map shape members) <> ")"
  ArrayExpression members -> "[" <> Text.intercalate "," (map shape members) <> "]"
  SetExpression members -> "#{" <> Text.intercalate "," (map shape members) <> "}"
  UnsafeExpression _ _ -> "unsafe"
  ScopeExpression _ -> "scope"
  MacroCall name arguments ->
    locatedValue name <> "!(" <> Text.intercalate "," (map shape arguments) <> ")"
  RecordExpression path fields ->
    moduleNameText path <> "{" <> Text.intercalate "," (map fieldInitShape fields) <> "}"
  InvalidExpression -> "invalid"

fieldInitShape :: Located FieldInit -> Text
fieldInitShape (Located _ field) =
  locatedValue (fieldInitName field)
    <> maybe Text.empty (\value -> ":" <> shape value) (fieldInitValue field)

armShape :: Located MatchArm -> Text
armShape (Located _ arm) =
  patternShape (armPattern arm)
    <> maybe Text.empty (\guard -> " if " <> shape guard) (armGuard arm)
    <> "=>" <> shape (armBody arm)

patternShape :: Located Pattern -> Text
patternShape (Located _ value) = case value of
  WildcardPattern -> "_"
  BindingPattern name -> locatedValue name
  LiteralPattern literalValue -> literalShape literalValue
  RangePattern lower inclusive upper ->
    literalShape lower <> (if inclusive then "..=" else "..") <> literalShape upper
  TuplePattern members -> "(" <> Text.intercalate "," (map patternShape members) <> ")"
  ConstructorPattern path arguments ->
    moduleNameText path
      <> if null arguments then Text.empty
         else "(" <> Text.intercalate "," (map patternShape arguments) <> ")"
  RecordPattern path fields rest ->
    maybe Text.empty moduleNameText path
      <> "{" <> Text.intercalate "," (map fieldShape fields)
      <> (if rest then ",.." else Text.empty) <> "}"
  AlternativePattern alternatives -> Text.intercalate "|" (map patternShape alternatives)
  InvalidPattern -> "invalid"

fieldShape :: Located FieldPattern -> Text
fieldShape (Located _ field) =
  locatedValue (fieldPatternName field)
    <> maybe Text.empty (\value -> ":" <> patternShape value) (fieldPatternValue field)

literalShape :: Literal -> Text
literalShape literalValue = case literalValue of
  IntegerValue value -> value
  FloatValue value -> value
  DecimalValue value -> value
  StringValue value -> value
  CharValue value -> Text.singleton value
  BoolValue value -> if value then "true" else "false"
  NullValue -> "null"
