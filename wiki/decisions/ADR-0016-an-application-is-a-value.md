---
type: decision
status: ACCEPTED
date: 2026-09-02
tags: [decision, stdlib, application, framework, wiring, lifecycle]
aliases: [ADR-0016-an-application-is-a-value]
---

# ADR-0016: An Application Is a Value

## Context

`Std.Http.Server` and `Std.Db` are what a service is built from. They are not what a service is
built as. Between them sits everything a program currently writes by hand and writes differently
each time: where configuration comes from and which source wins, what starts in what order and what
stops in reverse, how a request becomes a typed value and what the refusal says when it cannot, what
a schema migration is and how a half-applied one is prevented, what "healthy" means to something
outside the process, and what a running program reports about itself.

The reference framework for that gap is Spring Boot, and its mechanism is reflection: scanning finds
components, proxies implement repositories, annotations bind requests and mark transactions. That
mechanism is why it is powerful and is also the whole of its cost. A dependency that is not
registered is not a compile error; it is an exception at startup, from a container the programmer
did not write, naming a type rather than a place. Ordering between components is inferred and then
corrected with annotations that say what could have simply been written down. Startup does work
proportional to the size of the program before it does any work for a caller. And the application is
never a thing that can be looked at — there is no value that is the program, only a container that
has been populated.

The decisive evidence is what that framework had to do to get fast. Its ahead-of-time mode computes
at build time what the scan would have computed at start, and to do that it must assume a closed
world: the set of components is fixed before the program runs, and the features that let
configuration decide *which components exist* stop working. So the fast path is reached by giving up
the dynamism the reflection existed to provide — and the programmer pays for that dynamism twice, in
startup cost while they have it and in lost features when they trade it away.

That is the observation this decision rests on. A closed world is not a sacrifice made to go fast;
it is the ordinary case, and it is what almost every service already is. Pudu has no reflection and
will not grow any for this. Starting closed means arriving at the fast path without a build step and
without losing anything on the way, because nothing was ever built on the assumption of an open one.

The one thing that must survive is configuration deciding behaviour — and it does, because the
distinction that breaks a closed world is not configuration itself. Configuration selecting a
*value* is always safe. Configuration selecting *which objects exist* is what cannot be settled
ahead of time. This layer keeps the first and never offers the second.

## Decision

An application is an ordinary value of type `Std.App.App`, built by ordinary functions, and every
capability below is expressed as data rather than as an annotation, a proxy, or a scan.

**The smallest useful program is one call.** Explicitness is a property of what a program *can*
reach, not a tax on what it must write. `App.serve` takes a name and a router and runs a service —
configuration found, health answered, stopping graceful — and it is built from the same public
pieces a program would otherwise assemble, so outgrowing it is a step down rather than a rewrite.
The reason the established framework wins arguments it should lose is that its first program is
short; a design that is right and long loses to one that is wrong and short. This one is short.

**Wiring is a graph the programmer wrote.** A dependency is a parameter. A component that needs a
database session takes one. There is no registry to consult, nothing to register into, and no
container that can be missing an entry — a missing dependency is a type error at the place it is
missing. This is not a reduced form of dependency injection; it is the thing dependency injection
approximates, with the approximation removed.

**Lifecycle is a list, and stopping walks it backwards.** A `Stage` names what to start and how to
stop it. Start runs the list in order; stop runs it in reverse, so a pool opened after a migration
closes before the connection the migration used. Nothing infers an order, so nothing needs a
directive to correct an inferred one, and the order is legible without running the program.

**Configuration is layered and typed at the point of reading.** Sources are consulted in a fixed
order — declared defaults, then a file, then the environment, then arguments — with the later
winning, and a read states the type it expects and answers a `Result`. A profile selects which file
section applies. Nothing is bound by name to a field of an object that reflection filled in.

**A request becomes a typed value through a stated decoder, and a refusal names the field.** Binding
is a function from the parts of a request to a value, and it reports every field that failed rather
than the first, because a caller correcting a form wants the whole list.

**Health and metrics are values a program mounts where it chooses.** They are not endpoints that
appear because a dependency was on the path. A check is a function answering whether something is
usable; the aggregate is the checks. This means the same check runs in a test without a server.

**A rule worth enforcing is enforced by the types rather than written in prose.** The clearest case
is the two questions an orchestrator asks. *Should this process be restarted?* must not consult
anything outside the process — a database being unreachable is not a reason to kill a healthy
program, and a check that consults one turns a dependency's outage into a restart storm. *Should
this process receive traffic?* may consult whatever it needs. Established practice states that rule
as documentation and then relies on the programmer to obey it. Here the two are different types, and
the one that must not reach the world is given no way to.

**What is reachable from outside is what was routed, and nothing else.** There is no separate
exposure setting listing which built-in endpoints are published, because such a setting accepts a
wildcard, and a wildcard is how a program ends up serving its own environment and memory to the
network. An endpoint is reachable because a route was written for it.

**The application can be inspected without being run.** Because it is a value, a test builds one and
reads its routes, its stages, and its configuration, and never binds a port. This is the property
that the container model cannot offer, and it is the one that most changes how a service is tested.

## Consequences

**What this buys.** Startup does no discovery and its cost does not grow with the size of the
program. Every wiring failure is reported where it is written, at the time the program is checked,
naming the place rather than a type. The order of everything that starts and stops is written on one
page. A test never needs a running container, so the slow, cached, half-real application context
that dominates testing under the reflective model does not exist here.

**What this costs, stated plainly.** Wiring that a scan would have done is written out. For a large
application that is a real quantity of text — one line per component rather than none. This is
accepted: that text is the program's actual dependency graph, and a graph that is written is one
that can be read, reordered, and type-checked. The alternative is not less complexity but the same
complexity, discovered later and in a worse place.

**What is deliberately not offered.** No annotation processor, no code generation step, no proxying
of an interface into an implementation, and no automatic configuration keyed on what happens to be
importable. A capability arrives because a program asked for it by name.

## Alternatives Rejected

**A registry keyed by type, populated at start.** This is the container model without the scanning,
and it keeps the part that hurts: the failure moves from where the dependency is needed to where the
registry is built, and it stops being a type error. Rejected because the type error is the entire
advantage.

**Deriving wiring from the type of a constructor.** Attractive, and it fails at the first component
that needs two values of the same type — two pools, two clients, two keys. A framework that works
until the second one is worse than one that never claimed to.

**Automatic configuration selected by which modules are imported.** This makes the behaviour of a
program depend on its import list rather than on its text, which is the property that makes the
reflective model hard to reason about. Rejected on the same ground as the rest.

## Validation

Each module in this layer ships with a fixture that exercises it without a network where that is
possible, and over a real connection where it is not. The application value itself is checked by
building one, reading it, starting it, stopping it, and asserting the stop order is the reverse of
the start order — a check that is only expressible because the application is a value.

## Referenced by

[[Std App]] · [[Std App Config]] · [[Std App Health]] · [[Std App Metrics]] · [[architecture/STDLIB]]
