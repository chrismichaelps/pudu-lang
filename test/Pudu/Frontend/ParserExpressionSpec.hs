{-| @Test.Frontend.ParserExpressionSpec — coordinator for expression parser properties -}
module Pudu.Frontend.ParserExpressionSpec
  ( parserExpressionProperties
  , module Pudu.Frontend.ParserExpression.PrecedenceSpec
  , module Pudu.Frontend.ParserExpression.PrimarySpec
  , module Pudu.Frontend.ParserExpression.ControlSpec
  , module Pudu.Frontend.ParserExpression.RecoverySpec
  ) where

import Test.QuickCheck (Property)

import Pudu.Frontend.ParserExpression.ControlSpec
  ( controlProperties
  , testControlExpressions
  , testControlRecovery
  , testIfLet
  , testUnaryIf
  )
import Pudu.Frontend.ParserExpression.PrecedenceSpec
  ( precedenceProperties
  , testBinaryVocabulary
  , testLineLeadingOperators
  , testPrecedence
  , testPrecedenceBands
  )
import Pudu.Frontend.ParserExpression.PrimarySpec
  ( primaryProperties
  , testAggregates
  , testLambdas
  , testLiterals
  , testPostfix
  , testPostfixForms
  , testTypeArguments
  )
import Pudu.Frontend.ParserExpression.RecoverySpec
  ( recoveryProperties
  , testExhaustedBudgetIsQuiet
  , testHostileAmbiguousTails
  , testHostileChains
  , testHostileConditionals
  , testRecovery
  , testReservedKeywords
  )

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
