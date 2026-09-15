# Modules and packages

A program grows past one file by splitting into modules. This chapter covers how a module names itself, what it shows to other modules, the ways to import, and how a project and its dependencies are described.

## A module is a file

Every file declares exactly one module, and the module's name is the file's path with dots for directories. Inside a project whose source lives in `src`:

| File | Module |
| --- | --- |
| `src/Main.pudu` | `module Main` |
| `src/Shapes/Area.pudu` | `module Shapes.Area` |
| `src/Shapes/Perimeter.pudu` | `module Shapes.Perimeter` |

A file holds declarations only — functions, types, traits, implementations, and constants. Nothing runs when a module is loaded, so importing a module can never have a side effect.

## What a module shows

Declarations are private unless they are marked `export`. An exported function writes out every parameter type and its return type, and an exported constant writes out its type, because other modules are checked against those signatures alone:

```pudu
module Shapes.Area

/// The ratio of a circle's circumference to its diameter, to five places.
export const PI: Float64 = 3.14159

/// The area of a circle.
export fn circle(radius: Float64) -> Float64 {
  PI * square(radius)
}

/// The area of a rectangle.
export fn rectangle(width: Float64, height: Float64) -> Float64 {
  width * height
}

fn square(value: Float64) -> Float64 = value * value

fn main() -> Int {
  if rectangle(2.0, 3.0) == 6.0 && circle(1.0) == PI { 0 } else { 1 }
}
```

`square` has no `export`, so it is an implementation detail other modules cannot call.

## Importing

A second file imports the first by its full name:

```pudu
module Main

import Std.Io as Io
import Shapes.Area as Area

export fn main() -> Int {
  let total = Area.rectangle(2.0, 3.0) + Area.circle(1.0)
  match Io.writeLine("total area: {total}") {
    case Ok(_) => 0
    case Err(_) => 1
  }
}
```

Imports are always absolute — there is no importing relative to the current file — and there are three forms:

| Form | Binds | Used as |
| --- | --- | --- |
| `import Shapes.Area` | the module under its full name | `Shapes.Area.circle(1.0)` |
| `import Shapes.Area as Area` | the module under a short name | `Area.circle(1.0)` |
| `import Shapes.Area {circle, PI}` | the named declarations | `circle(1.0)`, `PI` |

The alias form is the one most code uses: it is short, and every use still says where the name came from. Selecting names reads well for a few that are used constantly:

```pudu
module Selected

import Std.Option {unwrapOr}
import Std.Text {wholeOf}

fn main() -> Int {
  let port = unwrapOr(wholeOf("8080"), 80)
  if port == 8080 { 0 } else { 1 }
}
```

There are no wildcard imports, so the answer to "where does this name come from?" is always in the import list at the top of the file.

## Constants

A `const` is a value computed while the program is compiled. It can use arithmetic, text, collections, and other constants, and a module can export one:

```pudu
module Limits

const KILOBYTE: Int = 1024

const UPLOAD_LIMIT: Int = 8 * KILOBYTE * KILOBYTE

const SUPPORTED: Array[Str] = ["png", "jpeg", "webp"]

const LABELS: Map[Str, Str] = mapOf([("png", "PNG image"), ("webp", "WebP image")])

fn accepts(extension: Str, size: Int) -> Bool {
  SUPPORTED.contains(extension) && size <= UPLOAD_LIMIT
}

fn main() -> Int {
  let labelled = LABELS.get("png") == Some("PNG image")
  if accepts("png", 4096) && !accepts("gif", 10) && labelled { 0 } else { 1 }
}
```

A constant table like `LABELS` is often the clearest way to write a lookup: the data is in one place, and the code that reads it stays short.

## The manifest

A project is described by `pudu.toml` at its root:

```toml
[package]
name = "shapes"
version = "0.1.0"
language = ">=0.1.0 <0.2.0"
source = "src"

[dependencies]
src = "src"
geometry = "../geometry"
```

| Key | Means |
| --- | --- |
| `name` | the package's name, in lower case |
| `version` | the package's own version |
| `language` | the Pudu versions it works with |
| `source` | the directory its modules live under |
| `[dependencies]` | other directories whose modules this package imports, each under a name |

A dependency is a local directory for now. Its modules are imported by their own names, exactly like the package's own.

## Organising a project

`pudu init` lays a project out in three layers, and larger programs tend to keep them:

- **`Domain`** modules hold the rules of the problem as pure functions and types, with no input or output.
- **`App`** modules use the domain to do one job a user asks for.
- **`Main`** reads the outside world — arguments, files, the network — calls the application, and reports.

Dependencies point inward: `Main` imports `App`, `App` imports `Domain`, and `Domain` imports only the standard library. The domain is then the easiest code to test, because it needs nothing but values.
