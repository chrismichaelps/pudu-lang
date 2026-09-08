{-| @Test.Repl.Session.CommandSpec — command parsing, classification, and tab completion in REPL -}
module Pudu.Repl.Session.CommandSpec
  ( commandProperties
  , testClassification
  , testCommandParsing
  , testCompletion
  , testDocLookup
  , testMemberCompletion
  , testTriviaOnly
  ) where

import qualified Data.Text as Text
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

import Pudu.Doc (DocEntry (..), DocIndex (..), DocKind (..), entriesFor)
import Pudu.Eval.Operator (builtinMethodNamesFor)
import Pudu.Repl.Command (Command (..), Entry (..), parseEntry)
import Pudu.Repl.Complete
  ( CompletionSource (..)
  , completionsFor
  , memberContext
  , wantsFilename
  )
import Pudu.Repl.Input (isComplete, isTriviaOnly)
import Pudu.Repl.Session
  ( EntryKind (..)
  , EntryResult (..)
  , emptySession
  , inspectSession
  , sessionDeclaredNames
  , typeOfEntry
  )
import Pudu.Repl.Session.Common (headName, submit, valueOf)

commandProperties :: [(String, IO Property)]
commandProperties =
  [ ("commands parse with unambiguous abbreviations", testCommandParsing)
  , ("submissions are classified by their leading token", testClassification)
  , ("completion offers commands paths and session names", testCompletion)
  , ("completion offers what the value before the dot carries", testMemberCompletion)
  , ("trivia and comments are identified for multiline prompt blocks", testTriviaOnly)
  , ("entriesFor matches unqualified and qualified module names", testDocLookup)
  ]

testCommandParsing :: IO Property
testCommandParsing =
  pure $ conjoin
    [ parseEntry ":quit" === CommandEntry Quit
    , parseEntry ":q" === CommandEntry Quit
    , parseEntry ":?" === CommandEntry Help
    , parseEntry ":help" === CommandEntry Help
    , parseEntry ":load demo.pudu" === CommandEntry (Load "demo.pudu")
    , parseEntry ":l demo.pudu" === CommandEntry (Load "demo.pudu")
    , parseEntry ":browse" === CommandEntry (Browse Nothing)
    , parseEntry ":browse Std.Math" === CommandEntry (Browse (Just "Std.Math"))
    , parseEntry ":b Std.Math" === CommandEntry (Browse (Just "Std.Math"))
    , parseEntry ":edit main.pudu" === CommandEntry (Edit (Just "main.pudu"))
    , parseEntry ":e" === CommandEntry (Edit Nothing)
    , parseEntry ":t 1 + 2" === CommandEntry (ShowType "1 + 2")
    , parseEntry ":{" === CommandEntry BeginBlock
    , parseEntry ":}" === CommandEntry EndBlock
    , counterexample "a prefix resolves to the first matching command"
        (parseEntry ":r" === CommandEntry Reload)
    , counterexample "a longer prefix reaches the later command"
        (parseEntry ":res" === CommandEntry Reset)
    , counterexample "an unknown command keeps its name"
        (parseEntry ":nope" === CommandEntry (Unknown "nope"))
    , parseEntry "1 + 2" === SourceEntry "1 + 2"
    , parseEntry "   " === BlankEntry
    , counterexample "line comments parse as BlankEntry"
        (parseEntry "// a comment" === BlankEntry)
    , counterexample "closed block comments parse as BlankEntry"
        (parseEntry "/* a comment */" === BlankEntry)
    , counterexample "doc comments remain SourceEntry to attach to declarations"
        (parseEntry "/// a doc comment" === SourceEntry "/// a doc comment")
    ]

testClassification :: IO Property
testClassification = do
  expression <- submit emptySession "1 + 2"
  binding <- submit emptySession "let value = 1"
  declaration <- submit emptySession "fn run() -> Int { 1 }"
  importEntry <- submit emptySession "import Core.Text {trim}"
  literal <- submit emptySession "fn(x: Int) -> Int => x"
  blockLiteral <- submit emptySession "fn(x: Int) -> Int { x }"
  asyncLiteral <- submit emptySession "async fn(x: Int) -> Int => x"
  asyncDeclaration <- submit emptySession "async fn run() -> Int { 1 }"
  assignment <- submit emptySession "counter = 1"
  completeExpr <- isComplete "1 + 2"
  incompleteAdd <- isComplete "1 +"
  incompleteShift <- isComplete "1 <<"
  incompleteXor <- isComplete "1 ^"
  completeComment <- isComplete "// a line comment"
  completeBlock <- isComplete "/* a block comment */"
  incompleteBlock <- isComplete "/* an unclosed block comment"
  incompleteDoc <- isComplete "/// a doc comment"
  pure $ conjoin
    [ resultKind expression === ExpressionEntry
    , resultKind binding === StatementEntry
    , resultKind declaration === DeclarationEntry
    , resultKind importEntry === ImportEntry
    , counterexample "top-level assignments are classified as StatementEntry"
        (resultKind assignment === StatementEntry)
    , counterexample "an expression reports its value" (valueOf expression === "3")
    , counterexample "a binding reports no value" (valueOf binding === "none")
    , counterexample "a function written as a value is an expression"
        (resultKind literal === ExpressionEntry)
    , counterexample "so is one whose body is a block"
        (resultKind blockLiteral === ExpressionEntry)
    , counterexample "and an async one"
        (resultKind asyncLiteral === ExpressionEntry)
    , counterexample "while a named async function still declares"
        (resultKind asyncDeclaration === DeclarationEntry)
    , counterexample "a function written as a value type checks"
        (null (resultDiagnostics literal) === True)
    , counterexample "completed expression completes" (property completeExpr)
    , counterexample "trailing plus continues" (property (not incompleteAdd))
    , counterexample "trailing shift continues" (property (not incompleteShift))
    , counterexample "trailing xor continues" (property (not incompleteXor))
    , counterexample "line comment is immediately complete" (property completeComment)
    , counterexample "closed block comment is immediately complete" (property completeBlock)
    , counterexample "unclosed block comment continues" (property (not incompleteBlock))
    , counterexample "doc comment awaits declaration" (property (not incompleteDoc))
    ]

testCompletion :: IO Property
testCompletion = do
  declared <- submit emptySession "fn measure(n: Int) -> Int { n }"
  (resolution, _) <- inspectSession (resultSession declared)
  let source = CompletionSource{sourceSessionNames = maybe [] sessionDeclaredNames resolution}
      empty = CompletionSource{sourceSessionNames = []}
  pure $ conjoin
    [ counterexample "commands complete at the start of a line"
        (completionsFor empty Text.empty ":q" === [":quit"])
    , counterexample "a colon later in the line is not a command"
        (completionsFor empty "value " ":q" === [])
    , counterexample "keywords complete"
        (completionsFor empty Text.empty "impo" === ["import"])
    , counterexample "wired-in types complete"
        (completionsFor empty Text.empty "Int1" === ["Int128", "Int16"])
    , counterexample "prelude names complete"
        (completionsFor empty Text.empty "Iterat" === ["Iterator"])
    , counterexample "session declarations complete"
        (completionsFor source Text.empty "meas" === ["measure"])
    , counterexample "an unknown prefix offers nothing"
        (completionsFor source Text.empty "zzz" === [])
    , counterexample "a filename is wanted after :load"
        (property (wantsFilename ":load "))
    , counterexample "a filename is wanted after :edit"
        (property (wantsFilename ":edit "))
    , counterexample "a filename is not wanted before the space"
        (property (not (wantsFilename ":load")))
    , counterexample "a filename is not wanted for other commands"
        (property (not (wantsFilename ":type ")))
    , counterexample "show topics complete after :show"
        (completionsFor empty ":show " "b" === ["bindings"])
    , counterexample "setting flags complete after :set"
        (completionsFor empty ":set " "+t" === ["+t", "+trunc"])
    , counterexample "modules complete after :browse"
        (completionsFor empty ":browse " "Std.M" === ["Std.Math", "Std.Math.Float", "Std.Mime"])
    , counterexample "standard library modules complete"
        (completionsFor empty ":browse " "Std.J" === ["Std.Json"])
    ]

testMemberCompletion :: IO Property
testMemberCompletion = do
  arrayType <- typeOfEntry emptySession "[1, 2]"
  textType <- typeOfEntry emptySession "\"hello\""
  mapType <- typeOfEntry emptySession "mapOf([(1, 2)])"
  declared <- submit emptySession "let greeting = \"hi\""
  declaredType <- typeOfEntry (resultSession declared) "greeting"
  brokenType <- typeOfEntry emptySession "nowhere"
  pure $ conjoin
    [ counterexample "the text before the dot is the receiver"
        (memberContext "[1, 2]" "." === Just ("[1, 2]", ""))
    , counterexample "a partial member name comes back with it"
        (memberContext "\"hello\"" ".to" === Just ("\"hello\"", "to"))
    , counterexample "a dotted path is not a member access"
        (memberContext "" "Std.Text.trimEnd" === Nothing)
    , counterexample "an array receiver is typed as one"
        (fmap headName arrayType === Just "Array")
    , counterexample "a text receiver is typed as one"
        (fmap headName textType === Just "Str")
    , counterexample "a map receiver is typed as one"
        (fmap headName mapType === Just "Map")
    , counterexample "a declared name is a receiver"
        (fmap headName declaredType === Just "Str")
    , counterexample "a receiver that does not type offers nothing"
        (brokenType === Nothing)
    , counterexample "an array carries the methods dispatch knows"
        (all (`elem` builtinMethodNamesFor "Array") ["map", "filter", "push", "length"] === True)
    , counterexample "text carries its own"
        (all (`elem` builtinMethodNamesFor "Str") ["toUpper", "trim", "split", "length"] === True)
    , counterexample "and the two sets are not the same"
        (("toUpper" `elem` builtinMethodNamesFor "Array") === False)
    , counterexample "a type with no built-in methods offers none"
        (builtinMethodNamesFor "Int" === [])
    ]

testTriviaOnly :: IO Property
testTriviaOnly = do
  lineCommentTrivia <- isTriviaOnly "// just a comment"
  blockCommentTrivia <- isTriviaOnly "/* multi\nline\ncomment */"
  whitespaceTrivia <- isTriviaOnly "   \n\t  "
  codeNotTrivia <- isTriviaOnly "let x = 1"
  exprNotTrivia <- isTriviaOnly "1 + 2"
  unclosedCommentNotTrivia <- isTriviaOnly "/* unclosed comment"
  pure $ conjoin
    [ counterexample "line comments are trivia only"
        (property lineCommentTrivia)
    , counterexample "block comments are trivia only"
        (property blockCommentTrivia)
    , counterexample "whitespace is trivia only"
        (property whitespaceTrivia)
    , counterexample "statements are not trivia only"
        (property (not codeNotTrivia))
    , counterexample "expressions are not trivia only"
        (property (not exprNotTrivia))
    , counterexample "unclosed comments are not trivia only"
        (property (not unclosedCommentNotTrivia))
    ]

testDocLookup :: IO Property
testDocLookup = do
  let entry = DocEntry
        { docName = "abs"
        , docModule = "Std.Math"
        , docKind = DocFunction
        , docSignature = Nothing
        , docComment = ["Absolute value."]
        , docSpan = (0, 0)
        }
      index = DocIndex [entry]
  pure $ conjoin
    [ counterexample "unqualified lookup matches"
        (map docName (entriesFor "abs" index) === ["abs"])
    , counterexample "qualified lookup matches"
        (map docName (entriesFor "Std.Math.abs" index) === ["abs"])
    , counterexample "non-matching lookup returns empty"
        (entriesFor "Std.Text.abs" index === [])
    ]
