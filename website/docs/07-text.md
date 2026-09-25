# Text

Text in Pudu is the `Str` type: a sequence of Unicode characters stored as UTF-8. A single character is a `Char`. This chapter covers writing text, placing values inside it, and the everyday operations on it.

## Writing text

Text is written between double quotes. A backslash writes a character that would otherwise end or change the text:

| Escape | Character |
| --- | --- |
| `\n` | a line break |
| `\t` | a tab |
| `\"` | a double quote |
| `\\` | a backslash |
| `\{` and `\}` | braces, when they are not an interpolation |

A `Char` is written between single quotes: `'a'`, `'\n'`.

## Placing values inside text

An expression between braces inside text is evaluated and written in its place. Any value can be placed, and the expression can be more than a name:

```pudu
module Interpolation

fn main() -> Int {
  let name = "Ada"
  let year = 1843
  let sentence = "{name} published her notes in {year}, {2024 - year} years ago."
  let braces = "a set is written \{1, 2, 3\}"
  if sentence == "Ada published her notes in 1843, 181 years ago." && braces.startsWith("a set") { 0 } else { 1 }
}
```

Text can also be joined with `+`, which is handy when the pieces are already values: `first + " " + last`.

## Turning any value into text

Every value has a `toText()` method that answers it as text, the same text interpolation writes. Numbers, booleans, collections, records, and variants all have one, so building a message never needs to know which kind of value is in hand:

```pudu
module ToText

type Point = { x: Int, y: Int }

fn main() -> Int {
  let count = 3
  let ratio = 0.5
  let label = count.toText() + " of " + [1, 2, 3].length().toText() + " at " + ratio.toText()
  let spot = Point{x: 1, y: 2}.toText()
  if label == "3 of 3 at 0.5" && spot == "Point\{x: 1, y: 2\}" && true.toText() == "true" { 0 } else { 1 }
}
```

Text inside a collection or a record keeps its quotes, so `["a"].toText()` is `["a"]`. A type that wants to be written its own way implements a `toText` method, and that implementation is used instead. Bytes are the one exception: `bytes.toText()` answers an `Option`, because not every run of bytes is valid text.

## Asking questions about text

```pudu
module Questions

fn main() -> Int {
  let title = "The Analytical Engine"
  let checks = [
    title.length() == 21,
    !title.isEmpty(),
    title.contains("Engine"),
    title.startsWith("The"),
    title.endsWith("Engine"),
    title.indexOf("Analytical") == 4,
    title.indexOf("Difference") == -1
  ]
  if checks.filter(fn(held: Bool) => !held).isEmpty() { 0 } else { 1 }
}
```

`length()` counts characters, not bytes, so `"héllo".length()` is `5`. `indexOf` answers `-1` when the text does not occur.

## Changing text

Text never changes in place. Every operation answers new text and leaves the original as it was:

```pudu
module Changes

fn main() -> Int {
  let raw = "  Hello, World  "
  let tidy = raw.trim()
  let shouted = tidy.toUpper()
  let quiet = tidy.toLower()
  let swapped = tidy.replace("World", "Pudu")
  let first = tidy.take(5)
  let rest = tidy.drop(7)
  let middle = tidy.slice(2, 5)
  let echo = "ha".repeat(3)
  let ok = tidy == "Hello, World" && shouted == "HELLO, WORLD" && quiet == "hello, world"
  if ok && swapped == "Hello, Pudu" && first == "Hello" && rest == "World" && middle == "llo" && echo == "hahaha" { 0 } else { 1 }
}
```

## Splitting and joining

`split` breaks text on a separator, and `join` on an array puts pieces back together. `lines` splits on line breaks:

```pudu
module Splitting

import Std.Text as Text

fn main() -> Int {
  let csvRow = "ada,grace,alan"
  let names = csvRow.split(",")
  let joined = names.join(" and ")
  let poem = "roses are red\nviolets are blue"
  let words = Text.words("the quick  brown fox")
  let ok = names.length() == 3 && joined == "ada and grace and alan"
  if ok && poem.lines().length() == 2 && words == ["the", "quick", "brown", "fox"] { 0 } else { 1 }
}
```

## Characters

`chars()` answers every character of a text, and `for` walks text one character at a time. Characters compare in Unicode order, and `code()` gives a character's number:

```pudu
module Characters

fn isVowel(letter: Char) -> Bool {
  letter == 'a' || letter == 'e' || letter == 'i' || letter == 'o' || letter == 'u'
}

fn main() -> Int {
  var vowels = 0
  var digits = 0
  for letter in "pudu 2026" {
    if isVowel(letter) { vowels = vowels + 1 }
    if letter >= '0' && letter <= '9' { digits = digits + 1 }
  }
  let letters = "abc".chars()
  if vowels == 2 && digits == 4 && letters.length() == 3 && 'A'.code() == 65 { 0 } else { 1 }
}
```

## Reading numbers from text

Text that should be a number is read with `Std.Text`. The answer is an `Option`, because the text may not be a number at all:

```pudu
module Numbers

import Std.Option as Option
import Std.Text as Text

fn portFrom(written: Str) -> Int {
  Option.unwrapOr(Text.wholeOf(written.trim()), 8080)
}

fn main() -> Int {
  if portFrom(" 3000 ") == 3000 && portFrom("http") == 8080 { 0 } else { 1 }
}
```

Going the other way, any value placed inside text is written as text: `"{3000}"` is `"3000"`.

## Std.Text

The built-in methods cover the everyday work. [Std.Text](/module/Std.Text) adds the rest, as functions that take the text as their first argument:

| Function | Answers |
| --- | --- |
| `Text.wholeOf(text)` | the whole number the text spells, or `None` |
| `Text.words(text)` | the words, split on spaces |
| `Text.capitalize(text)` | the text with its first character in upper case |
| `Text.padLeft(text, width, fill)` | the text padded on the left to a width |
| `Text.countOccurrences(text, needle)` | how many times a needle occurs |
| `Text.isBlank(text)` | whether the text holds only whitespace |

```pudu
module Formatting

import Std.Text as Text

fn row(name: Str, score: Int) -> Str {
  Text.padRight(Text.capitalize(name), 8, ".") + Text.padLeft("{score}", 4, " ")
}

fn main() -> Int {
  let table = [row("ada", 95), row("grace", 100)]
  if table[0] == "Ada.....  95" && table[1] == "Grace... 100" { 0 } else { 1 }
}
```
