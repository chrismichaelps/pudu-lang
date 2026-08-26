---
type: decision
status: Proposed
date: 2026-08-25
tags: [decision, paradigm, effects, proposal]
aliases: [ADR-0009, Effects in the Type]
---

# ADR-0009 — One capability set, in the type

**Status: Proposed.**

## The finding

Pudu answers the question *what may this code do* in three separate places, with three separate
implementations, three vocabularies, and three diagnostic families. None of the three reaches a
function's type.

### One — `comptime`

A boolean on `Function`. `requireComptimePurity` refuses `async` and `unsafe`;
`checkComptimeCall` walks calls and refuses any callee that is not itself `comptime`, against a
hardcoded allowlist:

```haskell
comptimeBuiltins :: [Text]
comptimeBuiltins = ["Some", "None", "Ok", "Err", "panic", "charFromCode", "show", ...]
```

**This is already a transitive capability check.** It has one capability, spelled as its absence.

### Two — `unsafe`

Named capabilities — `raw`, `foreign`, `unchecked`, `null` — with lexical regions
(`enterUnsafe`/`leaveUnsafe`), per-frame use tracking, and propagation to callers:

```haskell
checkUnsafeCall spanValue callee = ...
  Just required -> mapM_ (requireCapability spanValue name) required
```

**This is also already a transitive capability check.** It has four capabilities and its own
diagnostic (`E3023`), its own state (`stateUnsafeFrames`, `stateUnsafeFunctions`), and its own
propagation rule.

### Three — effects

Nineteen builtins — `print`, `readFile`, `writeFile`, `listDirectory`, `environment`, `exit`,
`clock`, `now`, `runProgram`, and the rest — each returning `Result[T, Str]`. They are not checked
statically at all. They are blocked **at run time**, and only while folding a constant:

```haskell
callEffect spanValue builtin arguments = do
  admitted <- effectsAdmitted
  if not admitted
    then abortAt (Just spanValue) "E7009" (builtinName builtin <> " reaches outside the program")
```

## What it costs today

```pudu
fn looksPure(a: Int) -> Int {
  print("side effect")
  a + 1
}
```

```
$ pudu check   →  no diagnostics
$ pudu doc     →  looksPure :: Int -> Int
```

That signature is false. It is also the signature `pudu doc --json` publishes, the one
`pudu doc --html` indexes, and the one the language server shows on hover. A language that refuses
to let an integer wrap quietly, that will not round a decimal without being told, and that rejects
`break` outside a loop before the program runs, will publish a signature claiming a function does
not touch the filesystem when it does.

The three mechanisms also cannot compose. A `comptime` function may not be `unsafe` — not because
the combination is meaningless, but because `requireComptimePurity` has a special case for it. There
is no way to say "this reaches the environment but nothing else", because effects have no vocabulary
at all.

## The proposal

**Generalise `comptime`'s boolean to a set, and fold the other two mechanisms into it.**

This is not an effect system imported from research. It is the machinery that exists twice already,
written once, with a vocabulary instead of a flag.

```pudu
/// Declared as a set. The check is `checkComptimeCall`, against a set.
fn greet(name: Str) -> Int uses io {
  print(name)
  0
}

fn load(path: Str) -> Result[Str, Str] uses io, env { ... }

/// What `comptime` means today, spelled the way everything else is.
fn double(x: Int) -> Int uses nothing { x * 2 }

/// What `unsafe(raw)` means today.
fn peek(address: Int) -> Int uses raw { ... }
```

An undeclared effect is a compile error at the call, where the reach happens:

```pudu
fn looksPure(a: Int) -> Int {
  print("side effect")
//^^^^^ E3025: looksPure declares no effects, print needs io
//      help: add `uses io` to looksPure, or move the call to a caller that has it
  a + 1
}
```

### What each mechanism becomes

| Today | Becomes |
|---|---|
| `comptime fn f()` | `fn f() uses nothing` |
| `unsafe(raw) fn f()` | `fn f() uses raw` |
| `unsafe { ... }` region | unchanged — a region granting effects to its body |
| `print`, `readFile`, … | prelude signatures gain `uses io` |
| `arguments`, `environment` | `uses env` |
| `clock`, `now` | `uses time` |
| `runProgram` | `uses process` |
| `E7009` at run time | `E3025` at compile time |
| `effectsAdmitted` gate | the folding context requires `uses nothing` |

Constant folding stops needing a runtime gate: a `const` initialiser is checked to require no
effects, so an effectful call in one is refused before the evaluator ever runs.

### The vocabulary

`io`, `env`, `time`, `process`, `random`, and the existing `raw`, `foreign`, `unchecked`, `null`.
Closed, like `Capability` is today — an open vocabulary would need a declaration form and a
namespacing rule, and neither earns its place in a first slice.

## The hard part

**Higher-order functions.** This is the crux, and the reason effect systems are rare rather than
universal.

```pudu
List.map(items, fn(x: Int) -> Int => { print(x)  x })
```

`map` itself performs no effect. The function it is given does. Three possible answers:

1. **`map` requires `uses nothing`.** Simple, and immediately useless: half the reason to map is to
   do something.
2. **`map` declares `uses io`.** A lie in the other direction, and it infects every caller.
3. **`map` is polymorphic in its effects** — it performs whatever its argument performs.

Only the third is honest, and it needs an effect variable:

```pudu
export fn map[A, B, e](items: &Array[A], transform: fn(A) -> B uses e) -> Array[B] uses e
```

This is row polymorphism over a closed vocabulary, which is what Koka does. It is a real addition to
the type system — unification has to handle effect rows, and `Scheme` has to quantify over them.

**A staged answer:** land the monomorphic core first, with `Std` functions that take a function
argument temporarily declared `uses e` as an unchecked hole, then add the variable. That is worse
than doing it once, and it is honest about the order the work can actually be done in.

## Prior art, and what each got wrong

**Java's checked exceptions** are the cautionary tale, and the closest analogue to getting this
wrong. The idea was right — a callee's failure modes belong in its signature — and the execution
made them so painful that the ecosystem routed around them with `throws Exception` and wrapped
everything in unchecked types. The failure was *no polymorphism*: a higher-order function could not
say "I throw whatever my argument throws", so every generic interface either forbade checked
exceptions or declared the union of everything. **If Pudu ships effects without the variable, it
ships Java's mistake.**

**Koka** and **Eff** infer effects rather than requiring declarations. That removes the annotation
burden entirely, and costs signature stability: a signature changes when a body changes. Pudu
already requires annotations on exported functions for exactly that reason — an inferred exported
signature lets an unrelated edit break callers silently — so declaring is the consistent choice
here, and the annotation cost is real and accepted.

**Haskell** puts effects in the type through `IO` and monad transformers. It works and it is
honest, but it colours every function and forces a second syntax — `do` notation — for effectful
code. Pudu's effects already return `Result`, so there is no monad to thread; the type just has to
say what the body reaches for.

**Rust** deliberately did not do this, and has `unsafe` as a single un-tracked hatch. Pudu already
went further than Rust here by naming four capabilities — this proposal is finishing what that
started rather than importing something foreign.

## What it costs

- **Signature noise.** `uses io` propagates up every call chain that reaches the world. In a program
  that is mostly IO, most signatures carry it. This is the main cost and it does not go away.
- **A type-system addition.** Effect variables are not free. Unification, generalisation, and
  instantiation all have to handle them.
- **Churn in `Std`.** Every effectful signature in `Std.Io`, `Std.Env`, `Std.Time`, `Std.Process`,
  and `Std.Random` changes, and every higher-order function in `Std.List` needs the variable.
- **Two keywords**, `uses` and `nothing`.

## What it buys

- The signature stops lying, in the tool that publishes it and the editor that shows it.
- Three code paths, three diagnostic families, and three pieces of checker state collapse to one.
- `comptime` stops being a special case and becomes a bound.
- `E7009` moves from run time to compile time, which is the direction every other rule in this
  language has moved.
- A caller can see, without reading a body, whether calling it can touch the disk.

## Open questions

1. Whether `async` folds in as `uses async`. It would make it four mechanisms into one, but it
   changes an existing surface rather than unifying hidden ones — a different and larger risk.
2. Whether effect variables should be inferred *within* a module and required only at export
   boundaries. That would cut the annotation cost sharply and keep exported signatures stable, and
   it has no precedent I can point at.
3. Whether `unsafe { }` as a region survives, or becomes `uses` on the block.

## Referenced by

[[decisions/_MOC]] · [[ADR-0008]] · [[grammar/pudu]] · [[architecture/SEMANTICS]] · [[Type Check]]
