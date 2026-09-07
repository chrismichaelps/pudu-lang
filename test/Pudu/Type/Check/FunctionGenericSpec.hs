{-| @Test.Type.Check.FunctionGenericSpec — functions, closures, calls, generics, and higher-kinded types -}
module Pudu.Type.Check.FunctionGenericSpec
  ( functionGenericProperties
  , testCalls
  , testDynamicTypes
  , testGenericAliases
  , testGenericTypes
  , testGenerics
  , testGlobalImpls
  , testLambdaTypes
  ) where

import Pudu.Type.Check.Common
  ( codes
  , codesOfExpression
  , typeOf
  )
import Test.QuickCheck (Property, conjoin, counterexample, (===))

functionGenericProperties :: [(String, IO Property)]
functionGenericProperties =
  [ ("a generic alias stands for what it names", testGenericAliases)
  , ("a trait bound is satisfied by any implementation in the program", testGlobalImpls)
  , ("function literals are typed and inferred", testLambdaTypes)
  , ("calls check argument types and count", testCalls)
  , ("generic functions instantiate per use", testGenerics)
  , ("a type declaration's parameters are instantiated at every use", testGenericTypes)
  , ("a dynamic type accepts any implementation and nothing else", testDynamicTypes)
  ]

testGenericAliases :: IO Property
testGenericAliases = do
  plain <- codes
    [ "module M", "type Count = Int"
    , "fn take(n: Count) -> Int { n }", "fn run() -> Int { take(3) }"
    ]
  generic <- codes
    [ "module M", "type Boxed[T] = Option[T]"
    , "fn make() -> Boxed[Int] { Some(2) }"
    , "fn run() -> Bool { match make() { case Some(_) => true \n case None => false } }"
    ]
  functionAlias <- codes
    [ "module M", "type Step[T] = Result[T, Str]", "type Rule[T] = fn(Int) -> Step[T]"
    , "fn digits() -> Rule[Int] { fn(n: Int) -> Step[Int] => Ok(n) }"
    ]
  wrongArity <- codes
    [ "module M", "type Boxed[T] = Option[T]", "fn make() -> Boxed { Some(2) }" ]
  pure $ conjoin
    [ counterexample "a plain alias stands for its type" (plain === [])
    , counterexample "a generic alias substitutes its argument" (generic === [])
    , counterexample "an alias may name a function type" (functionAlias === [])
    , counterexample "an alias written with the wrong count stays nominal"
        (wrongArity === ["E3001"])
    ]

testGlobalImpls :: IO Property
testGlobalImpls = do
  converting <- typeOf "convertInteger[UInt8](300)"
  tooMany <- codesOfExpression "convertInteger[UInt8, Int, Str](300)"
  notAName <- codesOfExpression "5[UInt8](300)"
  indexing <- typeOf "[1, 2][1]"
  shifting <- codesOfExpression "1u8 << 3"
  sameType <- codesOfExpression "1u8 << 3u8"
  prefixProduct <- codes
    [ "module M"
    , "fn run(a: &Int, b: &Int) -> Int { (*a) * (*b) }"
    ]
  prefixBare <- codes
    [ "module M"
    , "fn run(a: &Int, b: &Int) -> Int { *a * *b }"
    ]
  pure $ conjoin
    [ counterexample "a shift count is a plain Int" (shifting === [])
    , counterexample "a count of another integer type is refused, as every other conversion is"
        (sameType === ["E3001"])
    , counterexample "a parenthesised product of dereferences checks"
        (prefixProduct === [])
    , counterexample "an unparenthesised one checks the same way"
        (prefixBare === [])
    , counterexample "a type argument pins what inference cannot settle"
        (converting === "Option[UInt8]")
    , counterexample "too many type arguments is E3028" (tooMany === ["E3028"])
    , counterexample "an expression cannot carry type arguments" (notAName === ["E3028"])
    , counterexample "indexing is still indexing" (indexing === "Int")
    ]

testLambdaTypes :: IO Property
testLambdaTypes = do
  annotated <- typeOf "fn(n: Int) -> Int => n * 2"
  inferredUse <- typeOf "[1, 2].map(fn(n) => n * 2)"
  higherOrder <- codes
    [ "module M"
    , "fn apply(f: fn(Int) -> Int, n: Int) -> Int { f(n) }"
    , "fn run() -> Int { apply(fn(x) => x * 3, 7) }"
    ]
  returned <- codes
    [ "module M"
    , "fn adder(step: Int) -> fn(Int) -> Int { fn(n: Int) -> Int => n + step }"
    ]
  wrongBody <- codesOfExpression "fn(n: Int) -> Int => \"text\""
  wrongArgument <- codes
    [ "module M"
    , "fn apply(f: fn(Int) -> Int) -> Int { f(1) }"
    , "fn run() -> Int { apply(fn(x: Str) -> Int => 1) }"
    ]
  pure $ conjoin
    [ counterexample "an annotated literal has its written type"
        (annotated === "fn(Int) -> Int")
    , counterexample "an unannotated literal is inferred from its use"
        (inferredUse === "Array[Int]")
    , counterexample "a literal satisfies a function parameter" (higherOrder === [])
    , counterexample "a literal may be returned" (returned === [])
    , counterexample "a body is checked against the declared result"
        (wrongBody === ["E3001"])
    , counterexample "a literal's own parameter type is checked at the call"
        (wrongArgument === ["E3001"])
    ]

testCalls :: IO Property
testCalls = do
  correct <- codes ["module M", "fn twice(n: Int) -> Int { n * 2 }", "fn run() -> Int { twice(3) }"]
  wrongType <- codes ["module M", "fn twice(n: Int) -> Int { n * 2 }", "fn run() -> Int { twice(\"x\") }"]
  tooMany <- codes ["module M", "fn twice(n: Int) -> Int { n * 2 }", "fn run() -> Int { twice(1, 2) }"]
  defaulted <- codes
    [ "module M"
    , "fn scale(n: Int, factor: Int = 2) -> Int { n * factor }"
    , "fn run() -> Int { scale(3) }"
    ]
  notCallable <- codes ["module M", "const VALUE: Int = 1", "fn run() -> Int { VALUE(1) }"]
  tooFew <- codes
    [ "module M"
    , "fn add(left: Int, right: Int) -> Int { left + right }"
    , "fn run() -> Int { add(1) }"
    ]
  {-| A call through a value reaches the same rule, because the count the
      declaration set travels in the type rather than in a table the name
      would have to be looked up in. -}
  tooFewByValue <- codes
    [ "module M"
    , "fn add(left: Int, right: Int) -> Int { left + right }"
    , "fn run() -> Int { let indirect = add"
    , "  indirect(1) }"
    ]
  defaultedByValue <- codes
    [ "module M"
    , "fn scale(n: Int, factor: Int = 2) -> Int { n * factor }"
    , "fn run() -> Int { let indirect = scale"
    , "  indirect(3) }"
    ]
  pure $ conjoin
    [ correct === []
    , wrongType === ["E3001"]
    , tooMany === ["E3003"]
    , counterexample "a default covers a missing argument" (defaulted === [])
    , counterexample "a non-function is not callable" (notCallable === ["E3004"])
    , counterexample "too few arguments is refused at the check, not at the run"
        (tooFew === ["E3003"])
    , counterexample "and refused through a function value too"
        (tooFewByValue === ["E3003"])
    , counterexample "a default still applies through a function value"
        (defaultedByValue === [])
    ]

testGenerics :: IO Property
testGenerics = do
  reused <- codes
    [ "module M"
    , "fn identity[T](value: T) -> T { value }"
    , "fn run() -> Int { identity(1) }"
    , "fn text() -> Str { identity(\"a\") }"
    ]
  mismatched <- codes
    [ "module M"
    , "fn identity[T](value: T) -> T { value }"
    , "fn run() -> Str { identity(1) }"
    ]
  applied <- codes
    [ "module M"
    , "fn swap[F](value: F[Int]) -> F[Str] { value }"
    ]
  higherKinded <- codes
    [ "module M"
    , "fn keep[F[_], A](value: F[A]) -> F[A] { value }"
    , "fn run() -> Option[Int] { keep(Some(1)) }"
    ]
  higherKindedSolves <- codes
    [ "module M"
    , "fn keep[F[_], A](value: F[A]) -> F[A] { value }"
    , "fn run() -> Array[Str] { keep([\"a\"]) }"
    ]
  higherKindedMismatch <- codes
    [ "module M"
    , "fn keep[F[_], A](value: F[A]) -> F[A] { value }"
    , "fn run() -> Array[Int] { keep([\"a\"]) }"
    ]
  wrongArity <- codes
    [ "module M"
    , "fn two[F[_]](value: F[Int, Str]) -> Int { 0 }"
    ]
  tooFew <- codes
    [ "module M"
    , "fn two[F[_, _]](value: F[Int]) -> Int { 0 }"
    ]
  unboundedIsOpaque <- codes
    [ "module M"
    , "fn read[F[_], A](value: F[A]) -> Array[A] { value.keys() }"
    ]
  traitOverConstructor <- codes
    [ "module M"
    , "type Box[T] = { held: T }"
    , "trait Mappable[F[_]] { fn mapped[A, B](self: &F[A], f: fn(A) -> B) -> F[B] }"
    , "impl Mappable[Box] for Box {"
    , "  fn mapped[A, B](self: &Box[A], f: fn(A) -> B) -> Box[B] { Box{held: f(self.held)} }"
    , "}"
    , "fn run() -> Box[Str] { Box{held: 1}.mapped(fn(n: Int) -> Str => show(n)) }"
    ]
  appliedOnce <- codes
    [ "module M"
    , "fn one[F](value: F[Int]) -> Int { 0 }"
    ]
  boundStillPlain <- codes
    [ "module M"
    , "trait Sized { fn size(self: &Self) -> Int }"
    , "fn total[T: Sized](value: &T) -> Int { value.size() }"
    ]
  nestedArgument <- codes
    [ "module M"
    , "fn nested[T](value: Option[T]) -> Option[T] { value }"
    ]
  pure $ conjoin
    [ counterexample "one generic serves several types" (reused === [])
    , counterexample "instantiation still checks the result" (mismatched === ["E3001"])
    , counterexample "a parameter given type arguments is refused"
        (applied === ["E3038", "E3038"])
    , counterexample "one application reports once and does not cascade"
        (appliedOnce === ["E3038"])
    , counterexample "a bounded parameter is still an ordinary parameter"
        (boundStillPlain === [])
    , counterexample "a parameter inside a real generic type is untouched"
        (nestedArgument === [])
    , counterexample "a parameter of higher kind solves against a constructor"
        (higherKinded === [])
    , counterexample "and against a different one at another call"
        (higherKindedSolves === [])
    , counterexample "the argument it carries is still checked"
        (higherKindedMismatch === ["E3001"])
    , counterexample "an application of the wrong arity is refused"
        (wrongArity === ["E3038"])
    , counterexample "too few arguments is refused the same way"
        (tooFew === ["E3038"])
    , counterexample "an unbounded constructor parameter carries no members"
        (unboundedIsOpaque === ["E3005"])
    , counterexample "a trait may abstract over the constructor"
        (traitOverConstructor === [])
    ]

testGenericTypes :: IO Property
testGenericTypes = do
  construction <- codes (boxed <> ["fn run() -> Boxed[Int] { Boxed{value: 7} }"])
  fieldRead <- codes (boxed <> ["fn run(b: &Boxed[Int]) -> Int { b.value }"])
  throughFunction <- codes
    (boxed <> ["fn unwrap[T](b: &Boxed[T]) -> T { b.value }", "fn run() -> Int { unwrap(&Boxed{value: 7}) }"])
  wrongField <- codes (boxed <> ["fn run(b: &Boxed[Int]) -> Str { b.value }"])
  inPattern <- codes
    ( boxed
        <> [ "fn run(b: Boxed[Int]) -> Int { match b { case Boxed{value} => value } }" ]
    )
  genericImpl <- codes
    [ "module M"
    , "trait Holds[T] { fn get(self: &Self) -> T }"
    , "type Boxed[T] = { value: T }"
    , "impl[T] Holds[T] for Boxed[T] { fn get(self: &Self) -> T { self.value } }"
    , "fn run() -> Int { Holds.get(&Boxed{value: 7}) }"
    ]
  boundedImpl <- codes
    [ "module M"
    , "trait Joins { fn join(self: &Self, other: &Self) -> Self }"
    , "trait Doubles { fn twice(self: &Self) -> Self }"
    , "type Wrap[N] = { held: N }"
    , "impl[N: Joins] Doubles for Wrap[N] {"
    , "  fn twice(self: &Self) -> Self { Wrap{held: self.held.join(&self.held)} }"
    , "}"
    ]
  unboundedImpl <- codes
    [ "module M"
    , "trait Joins { fn join(self: &Self, other: &Self) -> Self }"
    , "trait Doubles { fn twice(self: &Self) -> Self }"
    , "type Wrap[N] = { held: N }"
    , "impl[N] Doubles for Wrap[N] {"
    , "  fn twice(self: &Self) -> Self { Wrap{held: self.held.join(&self.held)} }"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "construction carries its arguments" (construction === [])
    , counterexample "a field read substitutes them" (fieldRead === [])
    , counterexample "and so does a call through a generic function"
        (throughFunction === [])
    , counterexample "a field is still checked against its instantiated type"
        (wrongField === ["E3001"])
    , counterexample "a record pattern instantiates too" (inPattern === [])
    , counterexample "an implementation may carry its own parameters"
        (genericImpl === [])
    , counterexample "and the bounds on them are in force inside its methods"
        (boundedImpl === [])
    , counterexample "a parameter with no bound still promises nothing"
        (unboundedImpl === ["E3005"])
    ]
 where
  boxed = ["module M", "type Boxed[T] = { value: T }"]

testDynamicTypes :: IO Property
testDynamicTypes = do
  heterogeneous <- codes (shapes <> ["fn all() -> Array[dynamic Shape] { [Circle{r: 1}, Square{s: 2}] }"])
  branches <- codes
    (shapes <> ["fn pick(f: Bool) -> dynamic Shape { if f { Circle{r: 1} } else { Square{s: 2} } }"])
  callable <- codes (shapes <> ["fn area(s: dynamic Shape) -> Int { s.area() }"])
  notImplementing <- codes
    (shapes <> ["type Other = { n: Int }", "fn bad() -> dynamic Shape { Other{n: 1} }"])
  notATrait <- codes (shapes <> ["fn bad() -> dynamic Circle { Circle{r: 1} }"])
  traitWithoutDynamic <- codes (shapes <> ["fn bad(s: Shape) -> Int { 1 }"])
  pure $ conjoin
    [ counterexample "a collection holds several implementations" (heterogeneous === [])
    , counterexample "branches of different types widen where one is asked for"
        (branches === [])
    , counterexample "a trait member is callable through it" (callable === [])
    , counterexample "a type that does not implement the trait is refused"
        (notImplementing === ["E3032"])
    , counterexample "dynamic names a trait, not a type" (notATrait === ["E3031"])
    , counterexample "a bare trait in type position still points at dynamic"
        (traitWithoutDynamic === ["E3030"])
    ]
 where
  shapes =
    [ "module M"
    , "trait Shape { fn area(self: &Self) -> Int }"
    , "type Circle = { r: Int }"
    , "type Square = { s: Int }"
    , "impl Shape for Circle { fn area(self: &Self) -> Int { self.r } }"
    , "impl Shape for Square { fn area(self: &Self) -> Int { self.s } }"
    ]
