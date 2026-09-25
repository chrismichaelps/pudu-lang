# Traits and methods

A trait names behavior that types can provide. An implementation provides it for one type, and generic code can ask for any type that does.

## Declaring and implementing a trait

```pudu
module Animals

trait Speak {
  fn sound(self: &Self) -> Str
}

type Dog = { name: Str }

type Cat = { name: Str }

impl Speak for Dog {
  fn sound(self: &Self) -> Str { "{self.name} says woof" }
}

impl Speak for Cat {
  fn sound(self: &Self) -> Str { "{self.name} says meow" }
}

fn main() -> Int {
  let rex = Dog{name: "Rex"}
  if rex.sound() == "Rex says woof" { 0 } else { 1 }
}
```

Inside an implementation, `Self` is the type being implemented. An implementation must live in the module that declares the trait or the module that declares the type, so two libraries can never provide conflicting implementations of the same pair.

## Where methods come from

A value has methods from exactly two places:

- the built-in methods of `Array`, `Str`, `Map`, `Set`, and `Char`, such as `text.trim()` and `items.length()`, plus `toText()`, which every value has;
- the `impl` blocks a program writes.

An `impl` that declares `toText` replaces the built-in one for that type.

Everything else is a module function called with the value as an argument. `Option` is an ordinary sum type that nothing implements methods for, so its helpers read `Option.unwrapOr(value, fallback)`, not `value.unwrapOr(fallback)`.

## Qualified calls

A method can also be called through the type or the trait, with the receiver as the first argument. This is how a program chooses between two traits that both declare a method of the same name for one type:

```pudu
module Qualified

trait Speak {
  fn label(self: &Self) -> Str
}

type Bot = { id: Int }

impl Speak for Bot {
  fn label(self: &Self) -> Str { "bot {self.id}" }
}

fn main() -> Int {
  let bot = Bot{id: 7}
  if Speak.label(&bot) == bot.label() { 0 } else { 1 }
}
```

## Generic bounds

A type parameter can require traits, so a generic function can use what those traits promise:

```pudu
module Bounds

trait Describe {
  fn describe(self: &Self) -> Str
}

type Planet = { name: Str }

impl Describe for Planet {
  fn describe(self: &Self) -> Str { "the planet {self.name}" }
}

fn announce[T: Describe](thing: &T) -> Str {
  "Here is {thing.describe()}"
}

fn main() -> Int {
  if announce(&Planet{name: "Mars"}) == "Here is the planet Mars" { 0 } else { 1 }
}
```

## Mixing types behind a trait

`dynamic Trait` is the type of some value that implements the trait, without naming which type it is. It is what a collection of different implementations needs:

```pudu
module Chorus

trait Speak {
  fn sound(self: &Self) -> Str
}

type Dog = { name: Str }

type Cat = { name: Str }

impl Speak for Dog {
  fn sound(self: &Self) -> Str { "woof" }
}

impl Speak for Cat {
  fn sound(self: &Self) -> Str { "meow" }
}

fn main() -> Int {
  let pets: Array[dynamic Speak] = [Dog{name: "Rex"}, Cat{name: "Tom"}]
  var sounds: Array[Str] = []
  for pet in pets {
    sounds = sounds.push(pet.sound())
  }
  if sounds == ["woof", "meow"] { 0 } else { 1 }
}
```

A concrete value becomes a `dynamic` one wherever that is what the context expects. Going the other way — from a `dynamic` value back to a concrete type — is never automatic.
