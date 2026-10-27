---
type: module
path: "@root/test/Pudu/Backend/DefaultParameterPrograms.hs"
fidelity: Active
aliases: [Backend Default Parameter Programs]
---
# Backend Default Parameter Programs

Export defaultParameterSuccessPrograms (explicit stdout/stderr),
defaultParameterRefusalPrograms (runtime failures) and
defaultParameterModulePrograms. Successes cover every subset of supplied
arguments, a default with output, defaults through a function value,
defaults over earlier parameters, constants and a generic parameter, owned
array/text/record defaults in a 300-iteration loop, a default that calls
another defaulted function, and defaulted values in captures, arrays,
equality and rendering. Refusals cover E7002 at a default's call at the
depth limit, a default dividing by zero after a printing argument, and a
default with output before a panic in the body. The module case calls
another module's defaulted function selectively, qualified and through a
value.

## Resolved Grill Log

Expectations come from the tree interpreter and are rechecked against the
compiled evaluator every run. Defaults that name their own module's
constants are left out of the module case until #639 is fixed, since the
interpreter reads them in the caller's module.

## Dependencies and consumers

[[Backend Output Callable Programs]] · [[Backend Module Programs]] · [[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Pudu Test Cabal Manifest]]

## Referenced by

[[Native Default Parameters]] · [[src/Pudu/Backend/_MOC]]
