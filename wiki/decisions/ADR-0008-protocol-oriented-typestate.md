---
type: decision
status: Withdrawn
date: 2026-08-25
tags: [decision, paradigm, proposal]
aliases: [ADR-0008, Protocol Oriented Typestate, Typestate]
---

# ADR-0008 — Protocols, not classes: making a value's state part of its type

**Status: Withdrawn.** Kept as a record of a proposal that was made and rejected.

Typestate is not new — Strom and Yemini described it in 1986, and Rust shipped it before 1.0 and
**removed it in 2012** because the annotation burden never repaid what it caught. This document did
not mention that, which is the first thing an honest proposal should have said.

Worse, it was reasoned from a generic question — *what do classes fail at* — rather than from where
this language is actually straining. That is the wrong direction. A paradigm for Pudu should come
from reading Pudu, and there was a finding sitting in the source the whole time: the compiler
already implements "what may this code do" three separate times, and none of the three reaches a
function's type. See [[ADR-0009]].

## The question

Pudu has no classes and should not get them. But "no classes" is not a paradigm — it is the absence
of one. Traits and records already cover what classes do for *data with behaviour*, and that ground
is well trodden: it is what Rust and Haskell do. Copying it is not a position.

The question worth answering is different. **What do classes actually fail at, and what would
succeed there?**

## What classes fail at

Almost every serious bug in object-oriented code is a *protocol violation*, not a data error:

- reading a file after closing it
- using a connection that was returned to the pool
- calling `send` before `connect`
- consuming a response body twice
- placing an order that was already placed

A class cannot express any of these. It has one type for every state a value will ever be in, so the
protocol lives in comments and is enforced — when it is enforced at all — by a runtime flag and a
thrown exception:

```java
public String read() {
    if (closed) throw new IllegalStateException("file is closed");
    ...
}
```

That check is an admission. The author knew the rule, could not say it in the type, and settled for
discovering the violation at run time, in production, on someone else's machine.

This is the same shape of problem Pudu has already refused three times. Checked arithmetic rather
than a quiet wrap. An exact `Decimal` rather than invisible rounding. `break` outside a loop as a
compile error rather than a runtime one. Each time the answer was: *make the compiler say it*.

## The proposal

**A protocol is the primary way to model a thing that changes.** A value's state is part of its
type, transitions consume the value they move, and a method exists only in the states where it makes
sense.

### Syntax

Every form the proposal admits, in the order a reader meets them.

#### Declaring a protocol

```pudu
/// A file, and the protocol it obeys.
protocol File {
  /// Each state names its own data. A closed file has no handle to keep, so
  /// it does not have the field.
  state Open { handle: Int, path: Str }
  state Closed { path: Str }

  /// A function with no `self` is a way in. It names the state it produces.
  fn open(path: Str) -> Result[Open, Str] { ... }

  /// A transition consumes `self` and says where the value goes.
  fn read(self: Open) -> (Open, Str) { ... }
  fn close(self: Open) -> Closed { ... }

  /// A borrow reads without moving. `&Open` is readable only in Open.
  fn handle(self: &Open) -> Int { self.handle }

  /// `&Self` is every state, so this needs a field every state declares.
  fn path(self: &Self) -> Str { self.path }
}
```

Bodies live in the protocol block. States and the transitions between them are one thing, and
splitting them across a `protocol` and an `impl` would let a reader find half a state machine.

#### The types a protocol introduces

| Written | Means |
|---|---|
| `File.Open` | a file in exactly that state |
| `File.Closed` | a file in exactly that state |
| `File` | *some* file — the sum of its states |

`File` is an ordinary sum, so it stores and matches like one. That is what makes a collection of
mixed-state values expressible without new machinery.

#### Calling

```pudu
let file = File.open("notes.txt")?      // File.Open
let (file, first) = file.read()         // still Open, rebound
let file = file.close()                 // now File.Closed
```

Rebinding the same name is the idiom. The old value is gone, so reusing its name is not shadowing —
there is nothing left to shadow.

#### Matching on state

```pudu
fn describe(file: File) -> Str {
  match file {
    case File.Open(open) => "open at " + open.path
    case File.Closed(closed) => "closed: " + closed.path
  }
}
```

Exhaustiveness works exactly as it does for any sum: every state must be covered or the match is
`E5001`.

#### Fallible transitions

A transition that may fail has to say what happened to the value. `Result[To, E]` cannot: on the
error path the caller is holding nothing, and the value it was moving has vanished.

```pudu
/// Either it moved, or it did not and you still have it.
type Transition[From, To, E] = Result[To, (From, E)]

fn place(self: Draft) -> Transition[Draft, Placed, Str] { ... }
```

```pudu
match order.place() {
  case Ok(placed) => ship(placed)
  case Err(pair) => retryLater(pair[0], pair[1])   // the draft is still here
}
```

`Std.Protocol` would carry the alias. Nothing about it is special — it is the honest type, written
down.

#### Per-state methods with one name

A name may be declared once **per state**, so an operation that means the same thing in two states
keeps its name:

```pudu
protocol Buffer[T] {
  state Empty { }
  state Filled { items: Array[T] }

  fn push(self: Empty, item: T) -> Filled { Filled{items: [item]} }
  fn push(self: Filled, item: T) -> Filled { Filled{items: self.items.push(item)} }

  fn count(self: &Empty) -> Int { 0 }
  fn count(self: &Filled) -> Int { self.items.length() }
}
```

Resolution is by the receiver's state, which is known statically. There is no dispatch at run time
and no ambiguity to resolve.

#### Generic protocols

A protocol takes type parameters like any other declaration, and a transition may change them:

```pudu
protocol Parser[T] {
  state Ready { source: Str, position: Int }
  state Done { value: T }

  fn finish(self: Ready, value: T) -> Done { Done{value: value} }
}
```

#### Composition

By **holding**, not by inheriting states:

```pudu
protocol Socket {
  state Connected { file: File.Open, peer: Str }
  state Closed { peer: Str }

  fn close(self: Connected) -> Closed {
    let _ = self.file.close()
    Closed{peer: self.peer}
  }
}
```

A protocol that embedded another's states would have to answer what exhaustiveness means across the
join, and what a transition in the inner one does to the outer. Holding a value asks none of those
questions and expresses the same programs.

#### Traits over states

A state is a type, so it implements traits the ordinary way:

```pudu
impl Show for File.Closed {
  fn show(self: &Self) -> Str { "File.Closed(" + self.path + ")" }
}
```

A trait may be implemented for the sum too, when the behaviour is defined in every state.

#### Terminal states

A state with no outgoing transition is terminal. It is **inferred**, not declared: adding a
transition out of a state should not require also deleting a marker, and a marker that can disagree
with the transitions is a second source of truth.

Dropping a value in a non-terminal state is `W3003` — a warning rather than an error, because a
program that abandons an open file on an error path is doing something questionable but not
meaningless, and making it an error would demand a `close` on paths that are about to exit anyway.

#### What is refused, and what it says

```pudu
let file = File.open("a.txt")?
let closed = file.close()

closed.read()
//     ^^^^ E3040: read is not available in File.Closed
//          it exists in File.Open
//          help: this value moved to Closed at line 2

file.read()
// ^^^^^^^^ E3041: file was consumed by close at line 2
//          help: use the value that call returned
```

```pudu
protocol Broken {
  state Only { }
  fn go(self: Only) -> Missing { ... }
  //                   ^^^^^^^ E3042: Broken declares no state Missing
}
```

#### Grammar

```ebnf
protocol_decl    = "protocol", upper_ident, type_params?, "{", protocol_member*, "}" ;
protocol_member  = state_decl | function_decl ;
state_decl       = "state", upper_ident, (record_type | ) ;
```

A transition is an ordinary `function_decl`; what makes it one is the *type* of `self`:

| `self` written | Meaning |
|---|---|
| `self: Open` | consumes, and is available only in `Open` |
| `self: &Open` | borrows, and is available only in `Open` |
| `self: Self` | consumes, from any state |
| `self: &Self` | borrows, from any state |
| *absent* | a way in; produces a state without consuming one |

State types are written `Protocol.State` wherever a type is admitted, and a bare `Protocol` is the
sum of its states. No new type syntax is introduced.

### The two rules

1. **A method belongs to a state, not to a type.** `read` is not "a method on File that fails when
   closed". It does not exist on a closed file, the way `length` does not exist on an integer.
2. **A transition consumes what it moves.** The old value is not stale, not invalid, not
   flag-guarded — it is *gone*, and naming it is the same error as naming an undeclared variable.

Everything else follows. There is no `isOpen`, no `assertOpen`, no `IllegalStateException`, and no
comment explaining the order to call things in, because the order is the only order that compiles.

## Why this is the right paradigm *for Pudu*

It is not bolted on. It is the generalisation of a decision the language already made.

`Std.Iter.Sequence` passes its state rather than mutating a cursor:

```pudu
fn advance(self: &Self, state: S) -> Option[(S, T)]
```

The reasoning recorded there was that a sequence should be an ordinary value, so two walks of one
see the same items. A protocol is the same idea carried one step: **the state is passed *and the
type moves with it*.** `Sequence` is a protocol with one state. `File` is a protocol with two.

The other pieces are already built. Generic types and parameterised implementations landed in #100.
Traits carry their own type parameters. The grammar already says destruction is deterministic at the
end of ownership, and that mutation requires explicit authority. This proposal spends that
groundwork rather than requiring new.

## What it replaces

| Classes reach for | A protocol says |
|---|---|
| a mutable field plus a guard | a state, and a method that exists only there |
| an `IllegalStateException` | a compile error naming the transition that moved the value |
| a builder that must be `build()` once | a transition to a state with no further transitions |
| a comment: *call `connect` first* | `send` exists only in `Connected` |
| an interface with optional methods | a state that does not declare them |
| inheritance | composition — a protocol may embed another's states |

## Worked example: the thing every tutorial gets wrong

```pudu
protocol Order {
  state Draft { lines: Array[Line] }
  state Placed { lines: Array[Line], reference: Str }
  state Shipped { reference: Str, carrier: Str }

  fn addLine(self: Draft, line: Line) -> Draft
  fn place(self: Draft) -> Result[Placed, Str]
  fn ship(self: Placed, carrier: Str) -> Shipped
  fn reference(self: &Placed) -> Str
}
```

Double-placing an order is not a check somebody remembered to write. `place` takes a `Draft`, a
placed order is not a `Draft`, and the second call does not compile. Adding a line to a shipped
order does not compile. Reading a reference from a draft does not compile, because a draft has not
got one — the *data* differs per state, not just the permitted operations.

## What it costs

This is the part a proposal has to be honest about.

**Aliasing gets harder.** A transition consumes, so a value cannot be held in two places across one.
Pudu's `&` and `&mut` already draw this line, but protocols make it load-bearing rather than
advisory, and the borrow rules would need to say exactly what a borrow across a transition means.
The likely answer — a borrow may not outlive a transition — is a real restriction on how programs
are written.

**Collections of protocol values need thought.** An `Array[File.Open]` is fine. An array holding
files in *mixed* states is not one type, and the honest answer is that it is a sum, written as one.
That is more ceremony than a class gives, and it is more ceremony because the situation is genuinely
more complicated than a class admits.

**It is a large implementation.** State-indexed types, per-state method resolution, and a move
checker that reports the transition that consumed a value. The move checker is the biggest piece and
the one the language does not have today.

**It is unfamiliar.** Every reader arrives knowing classes. The syntax above is small, but the shift
— *methods belong to states* — takes a page to explain, and a language that needs a page before
anyone can read its examples pays for that forever.

## Rejected alternatives

**Classes with runtime guards.** The mainstream answer. Rejected for the reason this document opens
with: it moves a knowable fact to run time, which is the one thing this language has consistently
refused to do.

**Traits alone, as Rust and Haskell have.** Sound, familiar, and already most of the way here — but
it answers *behaviour over data* and says nothing about behaviour over *time*. `File` and
`ClosedFile` as separate types with conversion functions is typestate written by hand, without the
compiler checking that no path skips a step.

**Session types.** The same idea reaching further, describing protocols *between* parties rather
than within one value. Genuinely more powerful and much harder to explain; the single-value case is
where the everyday bugs are, and it is a coherent stopping point rather than a compromise.

**Effects tracked in the type.** A different axis and a good one — but it answers "what may this
function do", not "what state is this value in". The two compose; this proposal does not preclude
it and would benefit from it later.

## What would need deciding before this is accepted

1. Whether a borrow may cross a transition, and what it means if it does.
2. Whether states may be generic, and whether a transition may change a type parameter.
3. Whether the existing `trait` and a `protocol` are one construct with two syntaxes or two
   constructs. They answer different questions — a trait is behaviour shared across types, a
   protocol is behaviour across one type's lifetime — and the proposal keeps them separate, but that
   is a judgement rather than a necessity.
4. Whether a transition may be `async`, and what a state means across an await.

## A smaller first slice, if this is accepted

Protocols with no generics, no embedding, and no borrow-across-transition — just states, per-state
methods, and consuming transitions, with `E3040` for a method absent in the current state and
`E3041` for a use after a move. That is enough to write `File`, `Order`, and a connection pool, and
enough to find out whether the paradigm is pleasant to write before the harder questions are
answered.

## Referenced by

[[decisions/_MOC]] · [[grammar/pudu]] · [[architecture/SEMANTICS]] · [[ADR-0003]] · [[Std Iter]]
