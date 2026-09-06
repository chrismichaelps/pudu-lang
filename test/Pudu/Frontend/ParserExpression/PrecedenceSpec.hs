{-| @Test.Frontend.ParserExpression.PrecedenceSpec — binary precedence, associativity, and line-leading continuation -}
module Pudu.Frontend.ParserExpression.PrecedenceSpec
  ( precedenceProperties
  , testBinaryVocabulary
  , testLineLeadingOperators
  , testPrecedence
  , testPrecedenceBands
  ) where

import Data.Text (Text)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

import Pudu.Frontend.ParserExpression.Common
  ( codes
  , diagnosticOffsets
  , firstOf
  , helps
  , parse
  , remainingOf
  , shape
  , validShape
  )
import Pudu.Frontend.Token (SymbolKind (..), TokenKind (..))

precedenceProperties :: [(String, IO Property)]
precedenceProperties =
  [ ("binary precedence and associativity are explicit", testPrecedence)
  , ("closed binary vocabulary parses exhaustively", testBinaryVocabulary)
  , ("every precedence band binds as the grammar states", testPrecedenceBands)
  , ("an operator that cannot begin an expression continues the line above", testLineLeadingOperators)
  ]

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
  trailing <- parse "a +\nb"
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
  pure $ conjoin
    [ validShape assignment === "(a=(b=c))"
    , validShape subtraction === "((a-b)-c)"
    , validShape mixed === "(a+(b*c))"
    , validShape membership === "((ainb)==c)"
    , validShape comparisonMembership === "((a<b)inc)"
    ]

testBinaryVocabulary :: IO Property
testBinaryVocabulary = do
  let operators = ["=", "||", "&&", "==", "!=", "<", "<=", ">", ">=", "in", "..", "..=",
        "<<", ">>", "^", "|", "+", "-", "&+", "&-", "+|", "-|", "*", "/", "%", "&*", "*|"]
  results <- traverse (\operator -> parse ("a " <> operator <> " b")) operators
  pure (map validShape results === map (\operator -> "(a" <> operator <> "b)") operators)

testPrecedenceBands :: IO Property
testPrecedenceBands = do
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
