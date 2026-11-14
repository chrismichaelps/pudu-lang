---
type: architecture
aliases: [Native Default Parameters]
---
# Native Default Parameters

A function that declares default parameter values lowers to one native
function with a hidden trailing parameter: how many arguments the call
supplied. Its body starts with a prologue that, for each defaulted parameter
in order, assigns the default when the count does not reach it. Defaults are
lowered in the callee, after the parameters before them are in scope, so a
default reads module constants, earlier parameters and earlier defaults the
way [[grammar/pudu]] says, and its own calls count from the callee's frame.

Every call passes the full parameter list. A direct call lowers its supplied
arguments left to right, then `CoreAbsent` placeholders for the omitted ones
and the count as an Int literal. A placeholder is the zero of its type; the
frame retains and later releases it like any argument, and every release
path accepts a zero cell. The prologue's assignment replaces it.

Values go through the same function. A defaulted function's checked type
says how many parameters a call must supply, and that is what makes it a
different type from the all-required one. [[Compiler Lower Types]] forms it
as `CoreFunctionType (parameters <> [Int]) result`, so a closure of the
function and the frame it calls have the same arity. A call through a value
whose checked type requires fewer parameters than it has pads and counts
exactly as a direct call does.

## Resolved Grill Log

- **Q:** One copy per supplied count instead of a count parameter? **A:** A
  value call would then have to choose among copies at run time, so closures
  would carry several function indices. A count needs no new closure shape,
  and the prologue's branches cost one comparison per default.
- **Q:** Could the caller evaluate defaults? **A:** No; a value call does not
  know which function it reaches, and a default's calls must count from the
  callee's frame (E7002 names the default's call at the limit).
- **Q:** Is appending an Int to the Core function type observable? **A:** No;
  checking keeps defaulted and all-required function types apart, so no
  value of one reaches a call of the other, and runtime rendering and
  equality never look at parameter types.
- **Q:** A default that never returns? **A:** Its Never value ends the
  prologue as it ends any block; the body is unreachable, as in the
  interpreter.

## Evidence and remaining scope

Every subset of supplied arguments, defaults over earlier parameters,
earlier defaults, constants and generic parameters, effects and failures in
defaults, defaults through values, records, captures and generic callers,
owned defaults with zero live allocations, and E7002 at a default at the
depth limit, against both evaluators under Clang, GCC 15 and ASan/UBSan.
Trait members with defaults are covered only where the method path already
lowers; the rest of the ledger stays open.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Compiler Lower Signature]] · [[Compiler Lower Default]] · [[Backend Default Parameter Programs]]
