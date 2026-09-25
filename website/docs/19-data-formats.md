# Data formats

Programs exchange data as text: JSON between services, CSV from spreadsheets, TOML in configuration files. The standard library reads each into ordinary Pudu values and writes them back, and a malformed document is always a `Result` you handle rather than a crash.

## JSON

A JSON document is a `Json` value, a sum type with one variant for each kind of JSON value:

| Variant | JSON |
| --- | --- |
| `Null` | `null` |
| `Boolean(Bool)` | `true`, `false` |
| `Number(Int)` | a whole number |
| `Fractional(Str)` | a number with a fraction, kept as its exact text |
| `Text(Str)` | a string |
| `List(Array[Json])` | an array |
| `Object(Array[(Str, Json)])` | an object, with its keys in the order they were written |

### Reading

`Json.decode` reads text. The accessors each answer an `Option`, because the value might not be the kind asked for:

```pudu
module ReadJson

import Std.Json as Json
import Std.Option as Option

type User = { name: Str, age: Int, admin: Bool }

fn userFrom(value: &Json.Json) -> Option[User] {
  let name = Json.asText(&Json.field(value, "name") ?) ?
  let age = Json.asInt(&Json.field(value, "age") ?) ?
  let admin = Option.unwrapOr(Option.andThen(Json.field(value, "admin"), fn(held: Json.Json) -> Option[Bool] { Json.asBool(&held) }), false)
  Some(User{name: name, age: age, admin: admin})
}

fn main() -> Int {
  let text = "\{\"name\": \"Ada\", \"age\": 36, \"languages\": [\"English\", \"French\"]\}"
  let value = match Json.decode(text) {
    case Ok(held) => held
    case Err(problem) => { return 1 }
  }
  let languages = Option.unwrapOr(Option.andThen(Json.field(&value, "languages"), fn(held: Json.Json) -> Option[Array[Json.Json]] { Json.asList(&held) }), [])
  match userFrom(&value) {
    case Some(user) => if user.name == "Ada" && user.age == 36 && !user.admin && languages.length() == 2 { 0 } else { 1 }
    case None => 1
  }
}
```

`userFrom` uses `?` on each `Option`: if any field is missing or has the wrong kind, the whole function answers `None`. When a document does not decode, `Json.explain(&problem)` describes where and why in words a person can act on.

### Writing

A value is built with `Json.object` and `Json.list`, then written compactly with `Json.encode` or across lines with `Json.encodePretty`:

```pudu
module WriteJson

import Std.Json as Json

type Task = { title: Str, done: Bool, estimate: Int }

fn taskJson(item: Task) -> Json.Json {
  Json.object(&[
      ("title", Json.Text(item.title)),
      ("done", Json.Boolean(item.done)),
      ("estimate", Json.Number(item.estimate))
    ])
}

fn main() -> Int {
  let tasks = [Task{title: "write", done: true, estimate: 3}, Task{title: "review", done: false, estimate: 1}]
  let document = Json.object(&[("tasks", Json.list(&tasks.map(taskJson)))])
  let compact = Json.encode(&document)
  let readBack = Json.decode(compact)
  if compact.startsWith("\{\"tasks\":[\{\"title\":\"write\"") && readBack == Ok(document) { 0 } else { 1 }
}
```

Text is escaped on the way out, and reading what was written gives back an equal value.

## CSV

`Csv.parseTable` reads CSV whose first row names the columns. A row can then be read by column name:

```pudu
module Spreadsheet

import Std.Csv as Csv
import Std.Map as Map
import Std.Option as Option
import Std.Text as Text

fn main() -> Int {
  let text = "name,team,points\nada,red,12\ngrace,blue,30\n\"lin, jr\",red,8\n"
  let table = match Csv.parseTable(text) {
    case Ok(held) => held
    case Err(_) => { return 1 }
  }
  var redPoints = 0
  for row in Csv.records(&table) {
    if Map.getOr(&row, "team", "") == "red" {
      redPoints = redPoints + Option.unwrapOr(Text.wholeOf(Map.getOr(&row, "points", "0")), 0)
    }
  }
  let names = Option.unwrapOr(Csv.column(&table, "name"), [])
  let written = Csv.render(&[["name", "note"], ["ada", "said \"hello\""]])
  if redPoints == 20 && names[2] == "lin, jr" && written.contains("\"said \"\"hello\"\"\"") { 0 } else { 1 }
}
```

Quoted fields, commas inside quotes, and doubled quotes are handled in both directions. For a file too large to hold, `Csv.foldRows(path, start, step)` reads it one row at a time.

## TOML

Configuration is usually TOML. `Std.Toml.Read.read` parses a document, and `Toml.path` walks dotted keys:

```pudu
module Configuration

import Std.Option as Option
import Std.Toml as Toml
import Std.Toml.Read as TomlRead

type Settings = { host: Str, port: Int, debug: Bool }

fn settingsFrom(document: &Toml.Toml) -> Settings {
  let host = Option.unwrapOr(Option.andThen(Toml.path(document, "server.host"), fn(held: Toml.Toml) -> Option[Str] { Toml.asText(&held) }), "127.0.0.1")
  let port = Option.unwrapOr(Option.andThen(Toml.path(document, "server.port"), fn(held: Toml.Toml) -> Option[Int] { Toml.asWhole(&held) }), 8080)
  let debug = Option.unwrapOr(Option.andThen(Toml.path(document, "debug"), fn(held: Toml.Toml) -> Option[Bool] { Toml.asBoolean(&held) }), false)
  Settings{host: host, port: port, debug: debug}
}

fn main() -> Int {
  let text = "debug = true\n\n[server]\nhost = \"0.0.0.0\"\nport = 9000\n"
  match TomlRead.read(text) {
    case Ok(document) => {
      let settings = settingsFrom(&document)
      if settings.host == "0.0.0.0" && settings.port == 9000 && settings.debug { 0 } else { 1 }
    }
    case Err(_) => 1
  }
}
```

Every setting in `settingsFrom` has a default, so a configuration file only needs to name what it changes.

## More formats

| Module | Reads and writes |
| --- | --- |
| [Std.Yaml](/module/Std.Yaml) | YAML documents |
| [Std.Xml](/module/Std.Xml) | XML documents and their attributes |
| [Std.Bytes](/module/Std.Bytes) | hex and base64 |
| [Std.Archive.Zip](/module/Std.Archive.Zip) and [Std.Archive.Tar](/module/Std.Archive.Tar) | archives |
| [Std.Compress.Gzip](/module/Std.Compress.Gzip) | gzip compression |
