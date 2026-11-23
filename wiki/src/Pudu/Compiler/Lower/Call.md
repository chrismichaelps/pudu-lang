---
type: module
path: "@root/src/Pudu/Compiler/Lower/Call.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Call]
---
# Compiler Lower Call

Direct calls and the rendering builtins, moved out of [[Compiler Lower Body]]
to keep that traversal under its size limit (#556).

`lowerFunctionCall` admits the callee through [[Compiler Lower Generic]],
lowers the arguments in order and queues the target. `lowerPrint` keeps
print's Result effect-only. `lowerRendered` lowers `display` and `show` of any
represented value.

## Resolved Grill Log

- A move, not a change: the code and its refusals are what Body had.

## Calls to the source entry

A named call to main registers and calls its ordinary callable copy. Its real parameters and result are independent of the argument-free reporting entry. Direct calls use the admitted signature to decide whether to pass the hidden count.

## Referenced by

[[Compiler Lower Body]]

## Output Results (#566)

Resolved Grill Log: lowerPrint takes the builtin name, lowers its one Str argument once and binds a CoreOutputError outcome. Empty error text constructs Ok(()); nonempty text constructs Err(text), using the exact solved Result[(), Str] fact. All four output builtin names share this path. See [[Native Output Results]].

## First-class output builtins (#569)

Resolved Grill Log: Export outputResult to build the existing Result from one Core Str operand and the exact provided Result type. Direct lowerPrint and intrinsic value bodies share this factory.

## Defaults (#638)

A direct call to a function with defaults passes suppliedArguments.
Resolved Grill Log: the arguments still run first, left to right; the
result type is unchanged.

## Mutable loans (#651)

A callee with loaned parameters is queued and lowered by [[Compiler Lower Loan]]'s
`lowerLoanedCall`, which holds the arguments, makes the call and writes the
finals back. Resolved Grill Log: the ordinary path is unchanged.

## Dynamic parameters and open callees (#846)

A direct call hands `admitCalleeGiven` the arguments' own solved types, so a
callee whose fact checking left as an unsettled application can be specialized
from its operands. Each operand then widens to its parameter's type, which is
how a value of an implementing type reaches a `dynamic` parameter, defaults
included. Resolved Grill Log: argument order and effects stay left to right;
widening happens after every operand ran and only where the parameter expects
the dynamic type.

## Rendering differing runtime result carriers (#956)

Resolved Grill Log: display, show and standard output consume the held
runtime result. Output uses raw text for Str and the value renderer for
other shapes, as the interpreter does, then writes through the existing
output Result path.

## Output from retained runtime alternatives (#956)

Resolved Grill Log: dispatch the runtime alternatives before output
chooses how to render the held value. A Str is written verbatim and
other values use their ordinary shown form.

## Copies for runtime argument carriers (#956)

Resolved Grill Log: after ordinary checked widening, a nonloaned direct
call with a runtime alternative uses a copy with the exact parameter
carrier. Memoize the copy by original specialization and argument layout.
The copy's native result is settled independently.

Resolved Grill Log: direct calls share native signature registration
with callbacks that name a function. Only the direct call inserts
omitted arguments into its call instruction.

## Runtime layouts in stored methods and builtins (#956)

Resolved Grill Log: Direct output and output callable bodies use one conversion to stream text. The held runtime alternative determines whether text is written raw or rendered.
