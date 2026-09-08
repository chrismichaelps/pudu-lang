---
type: module
path: "@root/src/Pudu/Repl/Command.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.35
depth_status: SHALLOW
coupling: 1.0
interface_stability: 0.9
tags: [module, shallow]
aliases: [Repl Command]
---

# Repl Command

## Purpose

Parse one prompt line into either a colon command from a closed vocabulary or program text.

## Interface

### Signatures

```haskell
data Command
  = Help
  | Quit
  | Load !Text
  | Reload
  | Reset
  | Browse !(Maybe Text)
  | Edit !(Maybe Text)
  | ShowType !Text
  | ShowTokens !Text
  | ShowAst !Text
  | ShowContext
  | ShowInfo !Text
  | ShowKind !Text
  | ShowInstances !Text
  | ShowSetting !Text
  | ClearSetting !Text
  | ShowState !Text
  | ShowDoc !Text
  | Search !Text
  | BeginBlock
  | EndBlock
  | Unknown !Text
data Entry = CommandEntry !Command | SourceEntry !Text | BlankEntry
parseEntry :: Text -> Entry
commandNames :: [Text]
commandHelp :: [(Text, Text)]
```

### Governance

- `:browse` accepts an optional target module name: `:browse` without arguments inspects what the current
  session exports or declares, while `:browse Std.Math` browses the exports of the named library module.
- `:edit` accepts an optional file path: `:edit <file>` edits the specified file, while `:edit` without
  arguments edits the currently loaded file or creates a temporary session scratchpad, triggering an
  automatic reload on exit.
- `:doc` and `:search` carry their argument untrimmed like the other inspection commands: the
  parser does not know what is documented or searchable, and inventing that knowledge here would
  put the vocabulary in two places.

- A leading `:` introduces a command; everything else is program text, and a blank line or standalone comment (`//`, `/* ... */`) is neither, parsing as `BlankEntry`. Documentation comments (`///`) remain `SourceEntry` so multiline declaration blocks can bind them.
- The vocabulary is closed and its order is priority: an abbreviation resolves to the first command it prefixes, and an exact spelling always wins over a prefix.
- An unrecognized command keeps the name that was typed so the session can report it back accurately.
- Parsing is pure and total: it never fails, never performs IO, and never interprets the command's argument.
- `commandHelp` is the single source of the help text, so a command cannot exist without being documented.
- The inspection commands (`:info`, `:kind`, `:instances`) and the state commands (`:set`, `:unset`, `:show`) carry their argument as untrimmed text: the parser does not know which settings or topics exist, and inventing that knowledge here would put the vocabulary in two places.

### Linkage

- **Requires:** [[grammar/haskell]].
- **Consumed by:** [[Pudu REPL]].

## Algorithm

Trim the line, detect `:{` and `:}`, treat single-line comments as blank entries, split a command from its argument at the first space, resolve the name against the priority-ordered vocabulary, and build the command value.

## Negative Logic (Prohibited Paths)

- No IO, no evaluation, no argument validation, and no command whose behaviour depends on session state.

## Edge Cases

- `:` followed by nothing is an unknown command rather than a crash; `:?` is help; an argument keeps its internal spacing.

## Depth

DEPTH 0.35 (SHALLOW by intent). It is a vocabulary and a parser for it; deepening it would move session behaviour into the wrong module.

## Grill Log

- **Q:** Should an ambiguous abbreviation be rejected? **A:** No; first match wins, by declared priority. _Rationale:_ established shortcuts must not break when a new command is added, and a rejection would break them the moment a prefix collides. _Rejected:_ ambiguity errors; alphabetical resolution, which makes shortcuts depend on spelling.
- **Q:** Why add `:edit` and optional module browsing to `:browse`? **A:** Interactive exploration requires browsing standard library modules (`:browse Std.Math`) directly from the prompt, and complex multi-function editing requires round-tripping through `$EDITOR` (`:edit`) with automatic session reload. _Rationale:_ command-level discovery and editor handoff transform the REPL into a productive environment. _Rejected:_ requiring manual file creation and separate `:load` for external edits.
- **Q:** Why parse standalone comments as `BlankEntry`? **A:** Typing a line comment (`// note`) at the interactive prompt should simply return to the prompt without triggering evaluation errors or continuation lockups. _Rationale:_ interactive commentary is expected in tutorial and scratchpad workflows; non-doc comments carry no semantic value alone. _Rejected:_ treating comments as expressions that fail to parse; allowing non-doc comments to enter continuation mode.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Pudu REPL]]


## Interactive boundary completion

Command parsing recognizes only a single physical non-doc line comment as blank. Block comments and multiline input are passed intact to the lexical trivia classifier. Prefix/suffix comment matching must not discard intervening program text.

Resolved Grill Log: lexer tokens own syntax identity; do not infer it from textual word splitting. Existing source and compiler diagnostics remain authoritative. No tests or reviews run.
