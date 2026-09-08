# Measuring, and then reading

Three tools, in the order they are worth reaching for. Asked out of order the
last one is a haystack: a dump of the whole compiler is megabytes, and only a
measurement says which page of it to read.

## 1. Where does the cost grow

```bash
node bench/scaling.mjs "$(cabal list-bin exe:pudu)"
```

Builds inputs at doubling sizes and reports the ratio between them. Near 2 is
linear; sustained above 2.4 is not. This is what found the parser's quadratic
scan of a text (character access cost what it skipped) and a block that costs
the square of the statements it holds.

It takes three samples and keeps the smallest, because a busy machine adds time
and never takes it away — one sample per point once reported a front end growing
at x3.60 that a careful measure put at x2.27. Figures below a noise floor carry
no ratio at all, and a program that failed to compile is reported rather than
timed, because a program that does not run is not a fast one.

## 1b. What one request costs

```bash
node bench/request.mjs "$(cabal list-bin exe:pudu)"
```

Starts the service in `bench/service`, issues requests over a real socket, and
reports both what one request costs and what the server gets through when
several are waiting. Both, because neither follows from the other: this is what
found the runtime using one core no matter how many workers a server started,
where latency was already right and throughput was a third of what the machine
could do.

Three routes, because the cost divides between three things and one figure for
all of them says nothing about which to improve: a fixed reply is the floor —
socket, request parse, router, reply — and the other two add an encoded
document and a rendered page on top of it.

Measure with an optimised build. The development build is several times slower,
so an absolute figure taken from it is not one to quote.

## 2. Which function spends it

```bash
bench/profile.sh check some/file.pudu
```

A cost-centre report. Names the module and function to look at next.

## 3. What the optimiser made of that function

```bash
bench/ir.sh Pudu.Eval.Match --find sameValue
bench/ir.sh Pudu.Eval.Match --stage core
```

Dumps one module's intermediate forms at the optimisation the shipped build
uses, and points at where a name appears in each.

- **core** — what survived the optimiser. Whether a function specialised,
  whether a dictionary is still passed, whether a value is boxed, where a thunk
  is built. Most wins are visible here and nowhere else.
- **stg** — the same with allocation explicit.
- **cmm** — the imperative form, before instruction selection.
- **asm** — the instructions. Read this to confirm a loop is a loop rather than
  a call through a dictionary, and to see the heap and stack checks.

A name that appears in none of them was inlined into its callers, which is
usually the answer you wanted.

The dumps go in `dist-ir`, a build directory of their own, because a dump is
written only for a module the build actually compiles: touching a source does
not cause that, since cabal decides by content hash, and deleting an object file
does not either, since cabal trusts its own record over the file system. A
directory with no record compiles everything. The first run takes minutes.

## What this cannot show

A Pudu program has no machine code. These read the *compiler*, which is where
the compiler's own costs are. What a Pudu program costs is a different question,
and `pudu explain <file>` answers it — the names it looked up, the closures it
called — because those are the costs this implementation actually has.
