{-| @Test.Compiler.Program.TypeBoundarySpec — type boundaries, qualified types, and REPL context -}
module Pudu.Compiler.Program.TypeBoundarySpec
  ( testQualifiedTypeNames
  , testReplLoadContext
  , testTypeNamesAreNotValues
  , typeBoundaryProperties
  ) where

import qualified Data.Map.Strict as Map
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileContext (..))
import Pudu.Compiler.Program.Common (codes, helps, runEntry)
import Pudu.Diagnostic
  ( diagnosticCode
  , diagnosticCodeText
  , diagnosticMessage
  )
import Pudu.Repl.Session
  ( EntryResult (..)
  , Session (..)
  , emptySession
  , loadModule
  , submitEntry
  )
import Test.QuickCheck (Property, conjoin, counterexample, (===))

typeBoundaryProperties :: [(String, IO Property)]
typeBoundaryProperties =
  [ ("REPL loads retain the program interface context", testReplLoadContext)
  , ("a module cannot lend its name to a type it does not declare", testQualifiedTypeNames)
  , ("a type-only name cannot masquerade as a runtime value", testTypeNamesAreNotValues)
  ]

testTypeNamesAreNotValues :: IO Property
testTypeNamesAreNotValues = do
  missing <- codes "test-fixtures/stdlib/RejectsMissingArgument.pudu"
  values <- codes "test-fixtures/stdlib/RejectsTypeAsValue.pudu"
  members <- codes "test-fixtures/stdlib/RejectsTypeMember.pudu"
  pure $ conjoin
    [ counterexample "wired-in, prelude, and declared types are not bare or callable values"
        (values === replicate 6 "E2010")
    , counterexample "non-variant members through every type category are refused precisely"
        (members === replicate 3 "E3034")
    , counterexample
        ( "a call missing an argument is refused where it is written, while a "
            <> "default may still be omitted and a parameter is not the declaration "
            <> "it shares a name with"
        )
        (missing === ["W2001", "E3003", "E3003"])
    ]

{-| A qualified type name is judged only against a module the compiler read.

    An unfound one used to become a nominal type of its own, named after what
    was written, so `Mp.Map[Str, Int]` was a different type from `Map[Str, Int]`
    and the reader was told "expected Mp.Map[Str, Int], found Map[a, b]" — two
    names that read alike, about a type that never existed, at a line that was
    not the mistake.

    The cases that must stay silent are the point of the test. A type a module
    really declares looks exactly like one it does not when the module's
    interface was never available, and an earlier attempt that could not tell
    those apart reported correct code in the standard library. That is also why
    this lives here rather than beside the other type-checking properties: those
    compile a module on its own, with no interfaces at all, and this rule
    deliberately says nothing then. -}
testQualifiedTypeNames :: IO Property
testQualifiedTypeNames = do
  builtinThroughModule <- codes "test-fixtures/qualified/RejectsBuiltinThroughModule.pudu"
  neverDeclared <- codes "test-fixtures/qualified/RejectsUndeclaredType.pudu"
  wrongModule <- codes "test-fixtures/qualified/RejectsWrongModuleType.pudu"
  advice <- helps "test-fixtures/qualified/RejectsBuiltinThroughModule.pudu"
  declared <- runEntry "test-fixtures/qualified/UsesQualifiedTypes.pudu"
  pure $ conjoin
    [ counterexample "a built-in reached through a module is reported"
        (builtinThroughModule === ["E3035"])
    , counterexample "a name the module never declares is reported"
        (neverDeclared === ["E3035"])
    , counterexample "a type asked of the wrong module is reported"
        (wrongModule === ["E3035"])
    , counterexample "the advice names the spelling that works"
        (advice === ["Map stands on its own; write it without Mp."])
    , counterexample "types the modules do declare are left alone"
        (declared === Just "3")
    ]

testReplLoadContext :: IO Property
testReplLoadContext = do
  let path = "test-fixtures/program29/B.pudu"
  contents <- TextIO.readFile path
  (apply, loadedDiagnostics, _) <- loadModule path contents
  let loaded = apply emptySession
  entry <- submitEntry loaded
    "fn again(user: User) -> Str { user.show() }"
  pure $ conjoin
    [ map (diagnosticCodeText . diagnosticCode) loadedDiagnostics === []
    , counterexample "the loaded context retains both graph interfaces"
        (Map.size (contextTypes (sessionContext loaded)) === 2)
    , counterexample
        ("post-load diagnostics: " <> show
          [(diagnosticCodeText (diagnosticCode value), diagnosticMessage value) | value <- resultDiagnostics entry])
        (resultAccepted entry === True)
    ]
