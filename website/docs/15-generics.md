# Generics

Generic code is written once and used with many types. `Array[T]`, `Option[T]`, and `Result[T, E]` are generic, and your own functions and types can be too. This chapter builds on [functions](/docs/functions) and [traits](/docs/traits).

## Type parameters

A type parameter is a name for a type the caller chooses. It is written in square brackets after the function's or the type's name, and the compiler works out what it stands for at every use:

```pudu
module Stacks

type Stack[T] = { items: Array[T] }

fn empty[T]() -> Stack[T] = Stack{items: []}

fn push[T](stack: Stack[T], item: T) -> Stack[T] = Stack{items: stack.items.push(item)}

fn peek[T](stack: &Stack[T]) -> Option[T] {
  if stack.items.isEmpty() { None } else { Some(stack.items[stack.items.length() - 1]) }
}

fn main() -> Int {
  let numbers: Stack[Int] = push(push(empty(), 1), 2)
  let words = push(empty(), "top")
  if peek(&numbers) == Some(2) && peek(&words) == Some("top") { 0 } else { 1 }
}
```

`Stack[Int]` and `Stack[Str]` are different types. A function that takes a `Stack[Int]` does not accept a `Stack[Str]`, and nothing is checked at run time to make that true.

## Several parameters

A declaration can take as many type parameters as it needs:

```pudu
module Pairs

type Entry[K, V] = { key: K, value: V }

fn entry[K, V](key: K, value: V) -> Entry[K, V] = Entry{key: key, value: value}

fn swap[K, V](held: Entry[K, V]) -> Entry[V, K] = Entry{key: held.value, value: held.key}

fn main() -> Int {
  let age = entry("ada", 36)
  let flipped = swap(age)
  if flipped.key == 36 && flipped.value == "ada" { 0 } else { 1 }
}
```

## Bounds

A plain type parameter promises nothing about its type, so the function can only move values of it around. A bound asks for a trait, and then the function may use what the trait provides:

```pudu
module Ranking

import Std.List as List

trait Scored {
  fn score(self: &Self) -> Int
}

type Player = { name: Str, points: Int }

type Team = { name: Str, wins: Int }

impl Scored for Player {
  fn score(self: &Self) -> Int { self.points }
}

impl Scored for Team {
  fn score(self: &Self) -> Int { self.wins * 3 }
}

fn best[T: Scored](entrants: &Array[T]) -> Option[T] {
  List.maximumOn(entrants, fn(entrant: T) => entrant.score())
}

fn main() -> Int {
  let players = [Player{name: "ada", points: 12}, Player{name: "grace", points: 30}]
  let teams = [Team{name: "red", wins: 4}, Team{name: "blue", wins: 7}]
  let topPlayer = best(&players)
  let topTeam = best(&teams)
  let named = match topPlayer { case Some(player) => player.name case None => "" }
  if named == "grace" && topTeam == Some(Team{name: "blue", wins: 7}) { 0 } else { 1 }
}
```

The bound is checked where `best` is called: calling it with an array of a type that does not implement `Scored` is a compile error at that call, naming the missing implementation.

## Traits generic code asks for

A few traits appear in almost every generic signature. Three are part of the language and need no import; the comparison traits live in [Std.Order](/module/Std.Order) and are imported like anything else:

| Trait | A type that has it can | Comes from |
| --- | --- | --- |
| `Copy` | be copied rather than moved; numbers, `Bool`, and `Char` are | the language |
| `Send` | be handed to another worker | the language |
| `Sync` | be shared between workers | the language |
| `Eq` | be compared for equality | `import Std.Order {Eq}` |
| `Ord` | be ordered and sorted | `import Std.Order {Ord}` |
| `Hash` | be a key in a hash map | `import Std.Order {Hash}` |

`List.sorted` is declared with `where T: Ord`, so it sorts numbers and text but refuses a record that has no ordering.

## where clauses

When bounds get long, they can move after the signature:

```pudu
module Wheres

import Std.List as List
import Std.Order {Ord}

fn middle[T](items: &Array[T]) -> Option[T] where T: Ord {
  let ordered = List.sorted(items)
  if ordered.isEmpty() { None } else { Some(ordered[ordered.length() / 2]) }
}

fn main() -> Int {
  if middle(&[9, 1, 5]) == Some(5) && middle(&["b", "c", "a"]) == Some("b") { 0 } else { 1 }
}
```

## Parameters that stand for a container

A type parameter usually stands for a type, like `Int` or `Str`. A parameter written `F[_]` stands for a type that still takes one argument — `Array`, `Option`, or a generic type of the program's own — so one trait can describe every container that can be transformed without changing its shape:

```pudu
module Containers

trait Container[F[_]] {
  fn transformed[A, B](self: &F[A], change: fn(A) -> B) -> F[B]
}

type Pair[T] = { left: T, right: T }

impl Container[Pair] for Pair {
  fn transformed[A, B](self: &Pair[A], change: fn(A) -> B) -> Pair[B] {
    Pair{left: change(self.left), right: change(self.right)}
  }
}

impl Container[Array] for Array {
  fn transformed[A, B](self: &Array[A], change: fn(A) -> B) -> Array[B] {
    self.map(change)
  }
}

fn lengths[F[_]](texts: &F[Str]) -> F[Int] where F: Container {
  texts.transformed(fn(text: Str) => text.length())
}

fn main() -> Int {
  let sized = lengths(&Pair{left: "pudu", right: "deer"})
  let many = lengths(&["forest", "fern"])
  if sized.left == 4 && sized.right == 4 && many == [6, 4] { 0 } else { 1 }
}
```

`F[_]` declares that `F` takes exactly one argument; `F[_, _]` would take two. An implementation names the bare constructor, `impl Container[Pair] for Pair`, and `lengths` then works for anything that implements `Container`, keeping the caller's container: a `Pair` in, a `Pair` out. [Std.Mappable](/module/Std.Mappable) is the standard library's trait of this kind.

## Type aliases

An alias gives a type a shorter or more meaningful name. It stands for exactly the type it names, and it can take parameters of its own:

```pudu
module Aliases

type Scores = Map[Str, Int]

type Labelled[T] = Array[(Str, T)]

fn total(scores: &Scores) -> Int {
  var sum = 0
  for (_, points) in *scores {
    sum = sum + points
  }
  sum
}

fn labels[T](items: &Labelled[T]) -> Array[Str] {
  items.map(fn(pair: (Str, T)) => pair[0])
}

fn main() -> Int {
  let scores: Scores = mapOf([("ada", 3), ("grace", 4)])
  let tagged: Labelled[Bool] = [("done", true), ("open", false)]
  if total(&scores) == 7 && labels(&tagged) == ["done", "open"] { 0 } else { 1 }
}
```

## Generic code is checked once

A generic function's body is checked against its bounds, not against each type it is later used with. A body that calls `score()` on a `T` without the `Scored` bound is refused where the function is written, before anything calls it. Instantiating a generic function never produces an error inside its body.
