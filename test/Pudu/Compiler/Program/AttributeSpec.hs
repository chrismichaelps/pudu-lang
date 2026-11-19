{-| @Test.Compiler.Program.AttributeSpec — attributes name declarations.

    An attribute nothing declares would change nothing and say nothing, so each
    refusal here is a typo or a misuse that used to pass in silence. -}
module Pudu.Compiler.Program.AttributeSpec
  ( testDeclaredAttributes
  ) where

import Pudu.Compiler.Program.Common (codes)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

{-| A declared attribute is accepted with arguments of its kinds; an unknown
    name, a wrong argument kind, a second meaning for one name, an undeclared
    read in a derive, and a parameter kind that is no literal are refused. -}
testDeclaredAttributes :: IO Property
testDeclaredAttributes = do
  accepted <- codes "test-fixtures/attributes/DeclaredAttribute.pudu"
  unknown <- codes "test-fixtures/attributes/UnknownAttribute.pudu"
  wrongKind <- codes "test-fixtures/attributes/WrongAttributeArgument.pudu"
  conflicting <- codes "test-fixtures/attributes/conflict/Main.pudu"
  undeclaredRead <- codes "test-fixtures/attributes/UndeclaredRead.pudu"
  unsupported <- codes "test-fixtures/attributes/UnsupportedKind.pudu"
  pure $ conjoin
    [ counterexample "declared attributes with arguments of their kinds are accepted" (accepted === [])
    , counterexample "an attribute nothing declares is refused" (unknown === ["E3104"])
    , counterexample "an argument of the wrong literal kind is refused" (wrongKind === ["E3105"])
    , counterexample "a second meaning for one attribute is refused" (conflicting === ["E3106"])
    , counterexample "a derive reading an undeclared attribute is refused" (undeclaredRead === ["E3104"])
    , counterexample "a parameter kind that is no literal is refused" (unsupported === ["E1069"])
    ]
