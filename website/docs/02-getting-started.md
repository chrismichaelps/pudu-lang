# Getting started

This chapter takes you from an installed compiler to a project with its own modules and tests. By the end you will have run a program, changed it, split it into modules, and checked it with a test suite.

## Check the installation

Pudu is one command. Once it is on your path, ask it for its version:

```sh
pudu version
```

If the command is not found, build and install it as the [introduction](/docs/introduction#install) describes, and make sure `$HOME/.local/bin` is on your `PATH`.

## A single file

The smallest Pudu program is one file. Save this as `Hello.pudu`:

```pudu
module Hello

import Std.Io as Io

fn main() -> Int {
  let _written = Io.writeLine("Hello from Pudu!")
  0
}
```

Run it:

```sh
pudu run Hello.pudu
```

Three things are worth noticing already:

- The file's first line names its module, and the name must match the file name: `module Hello` lives in `Hello.pudu`.
- Nothing is available until it is imported. `Io.writeLine` works because of `import Std.Io as Io`.
- `main` returns a whole number, and that number becomes the program's exit status. `0` means success.

Writing a line can fail — the output may be closed — so `Io.writeLine` returns a `Result`. Binding it to a name that starts with `_` says, visibly, that the program received the result and chose not to act on it. The [errors](/docs/errors) chapter shows how to act on it instead.

## Checking without running

`pudu check` compiles a file and reports every problem without running anything. It is the fastest way to find out whether a change is correct:

```sh
pudu check Hello.pudu
```

A mistake is reported with a code, the place it happened, and a suggestion. Change `Io.writeLine` to `Io.writeLne` and check again: the compiler answers with `E3033`, points at the name, and says what the module does export.

## Start a project

A project keeps its source, its tests, and a manifest together. `pudu init` creates one:

```sh
pudu init hello
cd hello
```

It writes these files:

| Path | Holds |
| --- | --- |
| `pudu.toml` | the manifest: the package name, its version, the language versions it supports, and where its source lives |
| `src/Main.pudu` | the program's entry point |
| `src/App/Greeting.pudu` | an application module, which `Main` imports |
| `src/Domain/Greeting.pudu` | a domain module, with the logic the application uses |
| `test/App/GreetingTest.pudu` | a test suite for both |
| `README.md`, `.gitignore` | the usual project companions |

Run the program and its tests:

```sh
pudu run src/Main.pudu
pudu test
```

The first prints `Hello, world.` and the second reports `2 assertions held`.

## How the modules fit together

A module's name is its path under `src`. `src/Domain/Greeting.pudu` is `module Domain.Greeting`, and another module reaches it with `import Domain.Greeting as Greeting`.

The generated domain module holds one exported function:

```pudu
module Greeting

/// A greeting for somebody, or for the world when nobody was named.
export fn forName(name: Str) -> Str {
  if name.isEmpty() { "Hello, world." } else { "Hello, " + name + "." }
}

fn main() -> Int {
  if forName("") == "Hello, world." && forName("Ada") == "Hello, Ada." { 0 } else { 1 }
}
```

`export` makes `forName` visible to other modules; everything else stays private. A comment that starts with `///` documents the declaration below it, and editors show it when you hover over a use.

## Make a change

Open `src/Domain/Greeting.pudu` and add a second function beside `forName`:

```pudu
module Farewell

export fn farewell(name: Str) -> Str {
  if name.isEmpty() { "Goodbye." } else { "Goodbye, {name}." }
}

fn main() -> Int {
  if farewell("Grace") == "Goodbye, Grace." { 0 } else { 1 }
}
```

`"Goodbye, {name}."` is text with a value placed inside it; the [text](/docs/text) chapter covers it in full. Then add a check for the new function to `test/App/GreetingTest.pudu`, inside the list the suite already has:

```pudu
module FarewellTest

import Std.Test as Test

fn farewell(name: Str) -> Str {
  if name.isEmpty() { "Goodbye." } else { "Goodbye, {name}." }
}

export fn main() -> Int {
  let checks = Test.suite("farewell", &[
      Test.equals("names somebody", &farewell("Grace"), &"Goodbye, Grace."),
      Test.equals("says goodbye to nobody in particular", &farewell(""), &"Goodbye.")
    ])
  Test.report(&Test.run(&checks))
}
```

Run `pudu test` again. A failing check prints what it expected and what it found.

## Reading the command line

A program reads its arguments through `Std.Env`. `Env.at(0)` is the first argument after the program's name, and it is an `Option` because it may not have been given:

```pudu
module Greet

import Std.Env as Env
import Std.Io as Io
import Std.Option as Option

export fn main() -> Int {
  let name = Option.unwrapOr(Env.at(0), "world")
  match Io.writeLine("Hello, {name}!") {
    case Ok(_) => 0
    case Err(_) => 1
  }
}
```

## The everyday loop

| While you are | Run |
| --- | --- |
| writing | `pudu check src/Main.pudu` |
| trying it | `pudu run src/Main.pudu`, or `pudu run --watch src/Main.pudu` to rerun on every save |
| verifying | `pudu test` |
| tidying | `pudu fmt src test` |

Every command is described in [tooling](/docs/tooling). The next chapter, [basics](/docs/basics), looks closely at what a file is made of.
