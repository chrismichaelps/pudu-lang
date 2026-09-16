{-| @Test.Type.Check.TraitSpec — trait dispatch, bounds, coherence, and qualified calls -}
module Pudu.Type.Check.TraitSpec
  ( traitProperties
  , testTraits
  , testTraitDefaultCalls
  , testBounds
  , testAmbiguousMethod
  , testCoherence
  , testQualifiedMethods
  , testGenericTraits
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Test.QuickCheck ((===), Property, conjoin, counterexample)

import Pudu.Compiler (CompileResult(..))
import Pudu.Diagnostic
  ( diagnosticCode
  , diagnosticCodeText
  , diagnosticHelp
  , diagnosticMessage
  , diagnosticSpan
  )
import Pudu.Source (spanStart, unOffset)
import Pudu.Type.Check.Common (codes, compile, region, typeOfIn)

traitProperties :: [(String, IO Property)]
traitProperties =
  [ ("trait methods dispatch on the receiver type", testTraits)
  , ("a trait default method may call another trait method on Self", testTraitDefaultCalls)
  , ("trait bounds are proved at the call site", testBounds)
  , ("two trait bounds providing the same member is ambiguous", testAmbiguousMethod)
  , ("coherence rejects duplicate and orphan implementations", testCoherence)
  , ("same-named trait methods are selected by a qualified call", testQualifiedMethods)
  , ("a generic trait's parameters are solved from its implementation", testGenericTraits)
  ]

traitProgram :: [Text]
traitProgram =
  [ "module M"
  , "type User = { name: Str }"
  , "trait Greet {"
  , "  fn name(self: &Self) -> Str"
  , "  fn greet(self: &Self) -> Str = \"hello\""
  , "}"
  , "impl Greet for User {"
  , "  fn name(self: &Self) -> Str { self.name }"
  , "}"
  ]

testTraits :: IO Property
testTraits = do
  implemented <- codes (traitProgram <> ["fn run(user: User) -> Str { user.name() }"])
  inherited <- codes (traitProgram <> ["fn run(user: User) -> Str { user.greet() }"])
  wrongResult <- codes (traitProgram <> ["fn run(user: User) -> Int { user.greet() }"])
  unknownMethod <- codes (traitProgram <> ["fn run(user: User) -> Str { user.missing() }"])
  selfFields <- codes traitProgram
  methodType <- typeOfIn (drop 1 traitProgram <> ["fn run(user: User) -> Str { user.greet() }"]) "user.greet"
  pure $ conjoin
    [ counterexample "an implemented method is callable" (implemented === [])
    , counterexample "a default is inherited" (inherited === [])
    , counterexample "a method result is still checked" (wrongResult === ["E3001"])
    , counterexample "an unknown method is reported" (unknownMethod === ["E3005"])
    , counterexample "Self reads the implementing type's fields" (selfFields === [])
    , counterexample "the receiver is already applied" (methodType === "fn() -> Str")
    ]

{-| A trait default body that calls another trait method on `self` must resolve
    through the rigid `Self` bound, finding the method in the trait's own
    member table. This covers the case where a default composes other trait
    methods that the implementation inherits. -}
defaultCallProgram :: [Text]
defaultCallProgram =
  [ "module M"
  , "type Bot = { id: Int }"
  , "trait Service {"
  , "  fn id(self: &Self) -> Int"
  , "  fn label(self: &Self) -> Str = \"bot\""
  , "  fn report(self: &Self) -> Str { self.label() }"
  , "}"
  , "impl Service for Bot {"
  , "  fn id(self: &Self) -> Int { self.id }"
  , "}"
  ]

testTraitDefaultCalls :: IO Property
testTraitDefaultCalls = do
  defaultBody <- codes (defaultCallProgram <> ["fn run(b: Bot) -> Str { b.report() }"])
  genericDispatch <- codes
    (defaultCallProgram <> ["fn run[T: Service](value: T) -> Str { value.report() }"])
  wrongResult <- codes (defaultCallProgram <> ["fn run(b: Bot) -> Int { b.report() }"])
  pure $ conjoin
    [ counterexample "a default body calls another trait method on Self"
        (defaultBody === [])
    , counterexample "generic dispatch through a default that calls a trait method"
        (genericDispatch === [])
    , counterexample "the default body's result is still checked"
        (wrongResult === ["E3001"])
    ]

boundProgram :: [Text]
boundProgram =
  [ "module M"
  , "type User = { name: Str }"
  , "trait Show {"
  , "  fn show(self: &Self) -> Str"
  , "}"
  , "impl Show for User {"
  , "  fn show(self: &Self) -> Str { self.name }"
  , "}"
  , "fn display[T: Show](value: T) -> Str { value.show() }"
  ]

testBounds :: IO Property
testBounds = do
  satisfied <- codes (boundProgram <> ["fn run() -> Str { display(User{name: \"a\"}) }"])
  unsatisfied <- codes (boundProgram <> ["fn run() -> Str { display(5) }"])
  forwarded <- codes (boundProgram <> ["fn again[T: Show](value: T) -> Str { display(value) }"])
  unbounded <- codes (boundProgram <> ["fn again[T](value: T) -> Str { display(value) }"])
  whereClause <- codes (boundProgram <>
    [ "fn again[T](value: T) -> Str where T: Show { display(value) }" ])
  missingMethod <- codes
    [ "module M"
    , "trait Show { fn show(self: &Self) -> Str }"
    , "fn display[T: Show](value: T) -> Str { value.missing() }"
    ]
  pure $ conjoin
    [ counterexample "an implementing type satisfies the bound" (satisfied === [])
    , counterexample "a type without the implementation is reported"
        (unsatisfied === ["E3012"])
    , counterexample "a bounded parameter forwards its bound" (forwarded === [])
    , counterexample "an unbounded parameter cannot" (unbounded === ["E3012"])
    , counterexample "a where clause carries the same bound" (whereClause === [])
    , counterexample "a bound supplies only its own methods"
        (missingMethod === ["E3005"])
    ]

ambiguousProgram :: [Text]
ambiguousProgram =
  [ "module M"
  , "trait A { fn name(self: &Self) -> Str }"
  , "trait B { fn name(self: &Self) -> Str }"
  , "fn run[T: A + B](value: T) -> Str { value.name() }"
  ]

testAmbiguousMethod :: IO Property
testAmbiguousMethod = do
  ambiguous <- codes ambiguousProgram
  pure $ conjoin
    [ counterexample "two trait bounds providing the same member is ambiguous"
        (ambiguous === ["E3013"])
    ]

testCoherence :: IO Property
testCoherence = do
  let duplicateProgram =
        [ "module M"
        , "type Local = { value: Int }"
        , "trait Mark { fn mark(self: &Self) -> Int = 1 }"
        , "impl Mark for Local {}"
        , "impl Mark for Local {}"
        ]
      duplicateSource = Text.unlines duplicateProgram
      orphanProgram =
        [ "module M"
        , "import Traits {Mark}"
        , "import Models {Remote}"
        , "impl Mark for Remote {}"
        ]
      orphanSource = Text.unlines orphanProgram
  duplicateResult <- compile duplicateSource
  orphanResult <- compile orphanSource
  qualifiedDistinct <- codes
    [ "module M"
    , "import A"
    , "import B"
    , "type Local = { value: Int }"
    , "impl A.Mark for Local {}"
    , "impl B.Mark for Local {}"
    ]
  qualifiedDuplicate <- codes
    [ "module M"
    , "import A"
    , "type Local = { value: Int }"
    , "impl A.Mark for Local {}"
    , "impl A.Mark for Local {}"
    ]
  alphaEquivalent <- codes
    [ "module M"
    , "type Box[T] = { value: T }"
    , "trait Mark {}"
    , "impl[T] Mark for Box[T] {}"
    , "impl[U] Mark for Box[U] {}"
    ]
  distinctArguments <- codes
    [ "module M"
    , "type Box[T] = { value: T }"
    , "trait Mark {}"
    , "impl Mark for Box[Int] {}"
    , "impl Mark for Box[Str] {}"
    ]
  structural <- codes
    [ "module M"
    , "trait Mark {}"
    , "impl Mark for &Int {}"
    , "impl Mark for &Int {}"
    ]
  repeated <- codes
    [ "module M"
    , "type Local = { value: Int }"
    , "trait Mark { fn mark(self: &Self) -> Int = 1 }"
    , "impl Mark for Local {}"
    , "impl Mark for Local {}"
    , "impl Mark for Local {}"
    ]
  foreignTraitLocalTarget <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type Local = { value: Int }"
    , "impl Mark for Local {}"
    ]
  foreignTraitLocalSum <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type Local = | First | Second"
    , "impl Mark for Local {}"
    ]
  localTraitForeignTarget <- codes
    [ "module M"
    , "import Models {Remote}"
    , "trait Mark {}"
    , "impl Mark for Remote {}"
    ]
  foreignAlias <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "import Models {Remote}"
    , "type Alias = Remote"
    , "impl Mark for Alias {}"
    ]
  localAlias <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type Local = { value: Int }"
    , "type Alias = Local"
    , "impl Mark for Alias {}"
    ]
  genericAlias <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "import Models {Remote}"
    , "type Identity[T] = T"
    , "impl Mark for Identity[Remote] {}"
    ]
  genericLocalAlias <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type Local = { value: Int }"
    , "type Identity[T] = T"
    , "impl Mark for Identity[Local] {}"
    ]
  aliasChain <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "import Models {Remote}"
    , "type First[T] = Second[T]"
    , "type Second[U] = U"
    , "impl Mark for First[Remote] {}"
    ]
  traitAlias <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type MarkAlias = Mark"
    , "impl MarkAlias for Int {}"
    ]
  foreignNonNominal <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "impl Mark for &Int {}"
    ]
  foreignBuiltin <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "impl Mark for Int {}"
    ]
  foreignParameter <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "impl[T] Mark for T {}"
    ]
  aliasShadow <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type Local = { value: Int }"
    , "type T = Local"
    , "impl[T] Mark for T {}"
    ]
  nominalShadow <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type T = { value: Int }"
    , "impl[T] Mark for T {}"
    ]
  traitShadow <- codes
    [ "module M"
    , "import Models {Remote}"
    , "trait T {}"
    , "impl[T] T for Remote {}"
    ]
  pure $ conjoin
    [ counterexample "the duplicate diagnostic preserves code message help and target span"
        (duplicateDiagnostic duplicateSource duplicateResult)
    , counterexample "the orphan diagnostic preserves code message help and target span"
        (orphanDiagnostic orphanSource orphanResult)
    , counterexample "qualified traits with the same basename stay distinct"
        (qualifiedDistinct === [])
    , counterexample "the same qualified head is rejected"
        (qualifiedDuplicate === ["E3015"])
    , counterexample "generic binder renaming does not evade the check"
        (alphaEquivalent === ["E3015"])
    , counterexample "different concrete arguments are distinct exact heads"
        (distinctArguments === [])
    , counterexample "non-nominal syntax does not bypass duplicate detection"
        (structural === ["E3015"])
    , counterexample "each implementation after the first reports once"
        (repeated === ["E3015", "E3015"])
    , counterexample "a foreign trait is owned by a local nominal target"
        (foreignTraitLocalTarget === [])
    , counterexample "a local sum declaration supplies nominal ownership"
        (foreignTraitLocalSum === [])
    , counterexample "a local trait owns a foreign target"
        (localTraitForeignTarget === [])
    , counterexample "a local alias cannot launder a foreign target"
        (foreignAlias === ["E3014"])
    , counterexample "an alias of a local nominal target remains locally owned"
        (localAlias === [])
    , counterexample "generic alias substitution preserves foreign ownership"
        (genericAlias === ["E3014"])
    , counterexample "generic alias substitution reaches a local nominal owner"
        (genericLocalAlias === [])
    , counterexample "alias chains substitute arguments before ownership"
        (aliasChain === ["E3014"])
    , counterexample "a local alias cannot launder a foreign trait"
        (traitAlias === ["E3014"])
    , counterexample "a non-nominal target contributes no local owner"
        (foreignNonNominal === ["E3014"])
    , counterexample "a built-in target contributes no local owner"
        (foreignBuiltin === ["E3014"])
    , counterexample "an implementation parameter contributes no local owner"
        (foreignParameter === ["E3014"])
    , counterexample "a parameter shadows a same-named local alias for ownership"
        (aliasShadow === ["W2001", "E3014"])
    , counterexample "a parameter shadows a same-named local nominal for ownership"
        (nominalShadow === ["W2001", "E3014"])
    , counterexample "a parameter shadows a same-named local trait for ownership"
        (traitShadow === ["W2001", "E3014"])
    ]

orphanDiagnostic :: Text -> CompileResult -> Property
orphanDiagnostic source result =
  case (compileDiagnostics result, region source "Remote") of
    ([value], Just (expectedStart, _)) -> conjoin
      [ diagnosticCodeText (diagnosticCode value) === "E3014"
      , diagnosticMessage value === "orphan implementation: neither the trait nor target type is declared in this module"
      , diagnosticHelp value === Just "move this implementation to the module that declares the trait or target nominal type; aliases do not confer ownership"
      , unOffset (spanStart (diagnosticSpan value)) === expectedStart
      ]
    (values, location) ->
      counterexample ("unexpected diagnostics or location: " <> show (length values, location)) False

duplicateDiagnostic :: Text -> CompileResult -> Property
duplicateDiagnostic source result =
  case (compileDiagnostics result, region source "Local") of
    ([value], Just (expectedStart, _)) -> conjoin
      [ diagnosticCodeText (diagnosticCode value) === "E3015"
      , diagnosticMessage value === "duplicate implementation: Mark is already implemented for Local"
      , diagnosticHelp value === Just "remove one implementation; duplicate implementation heads are prohibited"
      , unOffset (spanStart (diagnosticSpan value)) === expectedStart
      ]
    (values, location) ->
      counterexample ("unexpected diagnostics or location: " <> show (length values, location)) False

sharedNameProgram :: [Text]
sharedNameProgram =
  [ "module M"
  , "type Bot = { id: Int }"
  , "trait Speak { fn label(self: &Self) -> Str }"
  , "trait Print { fn label(self: &Self) -> Str }"
  , "impl Speak for Bot { fn label(self: &Self) -> Str { \"speak\" } }"
  , "impl Print for Bot { fn label(self: &Self) -> Str { \"print\" } }"
  ]

testQualifiedMethods :: IO Property
testQualifiedMethods = do
  declaring <- codes sharedNameProgram
  traitQualified <- codes (sharedNameProgram <>
    ["fn run(bot: Bot) -> Str { Speak.label(&bot) }"])
  otherTrait <- codes (sharedNameProgram <>
    ["fn run(bot: Bot) -> Str { Print.label(&bot) }"])
  unqualified <- codes (sharedNameProgram <> ["fn run(bot: Bot) -> Str { bot.label() }"])
  typeQualified <- codes
    [ "module M"
    , "type Bot = { id: Int }"
    , "trait Speak { fn label(self: &Self) -> Str }"
    , "impl Speak for Bot { fn label(self: &Self) -> Str { \"speak\" } }"
    , "fn run(bot: Bot) -> Str { Bot.label(&bot) }"
    ]
  singleProviderStillPlain <- codes
    [ "module M"
    , "type Bot = { id: Int }"
    , "trait Speak { fn label(self: &Self) -> Str }"
    , "impl Speak for Bot { fn label(self: &Self) -> Str { \"speak\" } }"
    , "fn run(bot: Bot) -> Str { bot.label() }"
    ]
  wrongReceiver <- codes (sharedNameProgram <>
    ["fn run() -> Str { Speak.label(1) }"])
  valueReceiver <- codes (sharedNameProgram <>
    ["fn run(bot: Bot) -> Str { Speak.label(bot) }"])
  typeQualifiedAmbiguous <- codes (sharedNameProgram <>
    ["fn run(bot: Bot) -> Str { Bot.label(&bot) }"])
  pure $ conjoin
    [ counterexample "two traits may declare the same member" (declaring === [])
    , counterexample "a trait-qualified call selects one" (traitQualified === [])
    , counterexample "the other trait is equally selectable" (otherTrait === [])
    , counterexample "an unqualified call must choose" (unqualified === ["E3013"])
    , counterexample "a type-qualified call selects the implementation"
        (typeQualified === [])
    , counterexample "one provider needs no qualification" (singleProviderStillPlain === [])
    , counterexample "a qualified call still checks its receiver"
        (wrongReceiver === ["E3001"])
    , counterexample "a qualified call does not borrow for you"
        (valueReceiver === ["E3001"])
    , counterexample "the type-qualified form cannot choose either"
        (typeQualifiedAmbiguous === ["E3013"])
    ]

{-| A trait's own type parameters used to be formed as nominal types named
    after the parameter, so `trait Holds[T]` gave `get` a result of some type
    literally called `T`, and a trait-qualified call typed itself from the
    declaration rather than from the implementation it would actually run. -}
testGenericTraits :: IO Property
testGenericTraits = do
  methodCall <- codes (genericTrait <> ["fn run(b: Box) -> Int { b.get() }"])
  qualifiedCall <- codes (genericTrait <> ["fn run(b: Box) -> Int { Holds.get(&b) }"])
  wrongResult <- codes (genericTrait <> ["fn run(b: Box) -> Str { Holds.get(&b) }"])
  twoParameters <- codes
    [ "module M"
    , "type Pair = { a: Int }"
    , "trait Maps[K, V] { fn lookup(self: &Self, key: K) -> Option[V] }"
    , "impl Maps[Int, Str] for Pair {"
    , "  fn lookup(self: &Self, key: Int) -> Option[Str] { None }"
    , "}"
    , "fn run(p: Pair) -> Option[Str] { Maps.lookup(&p, 1) }"
    ]
  nonGenericStillWorks <- codes
    [ "module M"
    , "type Bot = { id: Int }"
    , "trait Speak { fn label(self: &Self) -> Int }"
    , "impl Speak for Bot { fn label(self: &Self) -> Int { 1 } }"
    , "fn run(b: Bot) -> Int { Speak.label(&b) }"
    ]
  pure $ conjoin
    [ counterexample "method syntax resolves the concrete method" (methodCall === [])
    , counterexample "so does the trait-qualified form" (qualifiedCall === [])
    , counterexample "and it is still checked against the implementation"
        (wrongResult === ["E3001"])
    , counterexample "a trait may carry more than one parameter" (twoParameters === [])
    , counterexample "a trait with no parameters is unaffected"
        (nonGenericStillWorks === [])
    ]
 where
  genericTrait =
    [ "module M"
    , "type Box = { v: Int }"
    , "trait Holds[T] { fn get(self: &Self) -> T }"
    , "impl Holds[Int] for Box { fn get(self: &Self) -> Int { self.v } }"
    ]
