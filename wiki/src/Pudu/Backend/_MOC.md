---
type: moc
tags: [moc]
aliases: [Backend Module Map]
---

# Backend Module Map

- [[Native Binary Kernels]] · [[Backend Kernel Programs]] — C11 encoding and decoding for `Std.Binary` (#935).

- [[Backend Emit Entry]] · [[Backend Native Target]] · [[Backend Toolchain Library]] · [[Backend Toolchain Process]] · [[Backend Native Target Tests]] · [[iOS Simulator Run]] · [[iOS Foreign Apps Test]] · [[Swift Entry Points Test]] · [[Swift Counter Fixture]] — embedded mobile builds (#878) and Swift entry points (#881).

- [[Backend Emit Export]] · [[Backend Export Tests]] — exported functions a host calls through C (#899).
- [[Native App Tests]] — simulator application identifier and property-list checks (#916).
- [[Backend Export Crossing]] — C shapes, header declarations and conversions for text, records and `Result` exports (#906).
- [[Native Toolchain Host Sources]] · [[Native Host Desktop]] · [[Native Host Audio]] — packaged native platform translation units (#856).

- [[Native Hash Mixing]] · [[Backend Store Programs]] — `hashOf`, store indexes and the indexed-store corpus (#840).
- [[Native Host Runtime]] · [[Native Host Concurrent]] · [[Native Host State]] · [[Native Host Process]] · [[Native Host Input]] · [[Native Host Files]] · [[Native Host Handles]] · [[Native Host Scopes]] · [[Native Host Math]] · [[Native Host Lanes]] · [[Native Host Raster]] · [[Native Host Signals]] · [[Native Host Foreign]] · [[Native Host Sockets]] · [[Native Host TLS]] · [[Native Mobile TLS Trust]] · [[Native Host Compression]] · [[Native Host Child Programs]] · [[Native Host Time]] · [[Native Host Time Reading]] — host families (#846).
- [[Backend Host Programs]] · [[Backend Service Programs]] · [[Backend Abstraction Programs]] — host, service, task, dynamic and abstraction corpus (#846).
- [[Backend Word Map Programs]] — sparse-word algebra, persistence and ownership (#810).
- [[Backend Module Programs]] — imported identities and folded collection/range conformance (#808).

- [[Backend Frame Program]] · [[Backend Frame Runtime]] · [[Native Frame Runtime Tests]] — deterministic assembly, heap ownership and iterative calls.
- [[Backend Typed Integer Calls]] — typed C entries for suitable direct callees.
- [[Backend Frame Direct]] — frame functions with bounded depth, run as plain C calls (#904).

- [[Backend Frame Values]] · [[Backend Frame Bodies]] · [[Backend Emit Foreign]] · [[Backend Emit Foreign Callback]] · [[Backend Emit Foreign Loan]] · [[Backend Emit Foreign ABI]] · [[Backend Emit Foreign Handle]] · [[Backend Emit Foreign Delegate]] — pure operations and suspending bodies over typed frame cells.
- [[Native Frame Body Tests]] — strict C11 corpus compilation and call-suspension checks.

- [[Backend Emit]] — deterministic C11 emission from [[Core IR]], including
  the diagnostic site tables that give native refusals the interpreter's text.

- [[Backend Runtime]] — the versioned C runtime translation unit embedded in
  every generated program: checked arithmetic, printing, failure rendering,
  exit-status clamping.

- [[Backend Toolchain Cache]] — compiled native executables reused by content; a miss stores through a rename, at most 256 entries.

- [[Backend Toolchain]] — discovery, invocation, bounded capture, timeout, and
  atomic publication of the native [[Compilation Artifact]]; the only place a
  process is started.
- [[Backend Ledger]] · [[Backend Ledger Spec]] — pure platform toolchain facts: Xcode floor and tested release, store rules, capabilities and triples (#926).
- [[Backend Toolchain Probe]] — asks `xcrun` and `simctl` what is installed; pure parsers (#926).

- [[Compiler Lower]] — checked tree to [[Core IR]], with typed `E6001`
  refusals for everything the native subset does not carry.

- [[Backend Emit Tests]] · [[Backend Native Tests]] — the two specs that hold
  lowering, emission, and native execution to their documented promises.
- [[Backend Method Programs]] — native method dispatch and order (#551).
- [[Backend Generic Programs]] — native generics (#552).
- [[Backend Try Programs]] — native `?` (#553).
- [[Backend For Programs]] — native `for` (#554).
- [[Backend Closure Programs]] — native closures (#555).
- [[Backend Emit Array]] · [[Backend Emit Cell]] · [[Backend Runtime Array]] · [[Backend Array Programs]] — native arrays (#556).
- [[Backend Array Pattern Programs]] — sortBy, sequence patterns and range slices (#558).

## Referenced by

[[src/Pudu/_MOC]] · [[src/_MOC]] · [[Backend]]

## Native function delivery (#488)

- [[Backend Emit State]]
- [[Backend Emit Support]]
- [[Compiler Lower Body]]
- [[Compiler Lower State]]
- [[Compiler Lower Signature]]
- [[Backend Function Programs]]
- [[Backend Toolchain Tests]]

- [[Compiler Lower Control]] — resolved scalar loop targets, transfers and divergence (#489).

- [[Backend Control Programs]] — differential loop-control, divergence and transfer cases (#489).

- [[Backend Runtime Integer]] · [[Backend Integer Programs]] — defined C11 bit patterns, wrapping, saturation and checked shifts.
- [[Backend Float Programs]] — native Float32/Float64 source conformance.
- [[Native Text Runtime]] · [[Backend Text Programs]] · [[Backend Text Leak Tests]] — owned native text.
- [[Native Text Methods]] · [[Backend Text Method Programs]] — native Str methods.
- [[Native Text Case]] · [[Backend Text Case Tests]] — native trim and case mapping.
- [[Native Text Pieces]] · [[Native Text Number]] · [[Backend Text Collection Programs]] — Str methods answering arrays and options (#559).
- [[Native Integer Conversion]] · [[Backend Convert Programs]] — convertInteger between every integer kind (#560).
- [[Native Persistent Trees]] · [[Backend Emit Keyed]] · [[Backend Keyed Programs]] — maps and sets (#561).
- [[Backend Shape Programs]] — record shapes across modules, field calls and assignment values (#563).
- [[Native Range Runtime]] · [[Backend Emit Range]] · [[Backend Range Programs]] — range values (#564).
- [[Native Bytes Runtime]] · [[Backend Emit Bytes]] · [[Backend Bytes Programs]] — byte sequences (#565).
- [[Native Char Runtime]] · [[Backend Char Programs]] — native Char values and charAt.
- [[Native Aggregate Emission]] · [[Native Aggregate Runtime]] · [[Compiler Lower Tuple]] · [[Backend Tuple Programs]] — native tuples.
- [[Compiler Lower Record]] · [[Backend Record Programs]] — native records.

- [[Backend Integer Value]] · [[Backend Integer Arithmetic]] · [[Backend Integer Bits]] · [[Backend Deferred Integer Programs]] — exact integer carriers and deferred-value conformance.

- [[Backend Word128 Kernel]] · [[Native Word128 Tests]] — portable 128-bit arithmetic prerequisite.

- [[Backend Wide Integer Values]] · [[Native Wide Value Tests]] — exact signs and selectable dependencies (#502).

- [[Backend Wide Operations]] · [[Native Wide Operation Tests]] — planned typed primitive implementation (#503).

- [[Backend Wide Integer Display]] · [[Native Wide Runtime Tests]] — actual wide runtime integration (#504).

- [[Native Broken Pipe Tests]] — actual emitted startup under default SIGPIPE (#505).

- [[Native Wide Frame Tests]] — exact wide frame execution (#506).

- [[Native Floating Natural Kernel]] · [[Native Floating Natural Tests]] — exact formatting prerequisite (#508).

- [[Native Binary64 Formatter]] · [[Native Binary64 Formatter Tests]] — exact decimal text (#509).

- [[Native Floating Values]] · [[Native Floating Value Tests]] — exact bit transport and arithmetic (#510).

- [[Native Floating Runtime]] · [[Native Runtime Dependencies]] · [[Native Floating Runtime Tests]] — actual catalogue integration (#511).

- [[Compiler Lower Match]] · [[Native Refutable Binding Delivery]] — enclosing-scope refutable bindings (#541).

- [[Compiler Lower Constant]] · [[Native Folded Constants]] — represented folded-data emission (#543).

- [[Native Shared References]] · [[Backend Shared Reference Programs]] — native shared references (#544).

- [[Native Output Runtime]] — buffered standard-stream outcomes.

- [[Native Process Context]] — process signal and inherited-descriptor projection.

- [[Backend Output Programs]] · [[Native Output Tests]] — Result values, isolated descriptor failures and entry/fatal reporting (#566).

- [[Backend Expression Body Programs]] — expression-body conformance and cleanup (#567).

- [[Backend Named Callable Programs]] — named call depth, ownership and diagnostics (#568).

- [[Backend Output Callable Programs]] — builtin values, effects and cleanup (#569).

- [[Backend Rendering Callable Programs]] — intrinsic signatures, identity and cleanup.
- [[Backend Collection Callable Programs]] — collection builtin values and caller-site refusals.
- [[Backend Stopping Builtin Programs]] — panic and untyped convertInteger parity.
- [[Backend Place Assignment Programs]] — element and mixed path assignment.
- [[Backend Mutable Loan Programs]] — places lent to calls and written back.
- [[Backend BigInt Programs]] — BigInt arithmetic, bits, conversions and failures.
- [[Backend BigInt Values]] — the BigInt carrier.
- [[Backend BigInt Operations]] — BigInt operators, status, display and conversions.
- [[Backend Decimal Programs]] — Decimal arithmetic, parsing, callable values and failures.
- [[Backend Decimal Values]] — the Decimal carrier.
- [[Backend Decimal Operations]] — Decimal parsing, binary64, division and primitives.
- [[Backend Method Value Programs]] — built-in method values of every receiver kind.
- [[Backend Default Parameter Programs]] — defaults in every combination, directly and through values.

- [[Backend Frame Text Views]] — checked byte-method carrier emission.
- [[Backend Toolchain App]] — simulator application bundle, Info.plist and ad-hoc signing (#916).
- [[Backend Toolchain Android]] — NDK library builds and application packages, staged and published by rename.
- [[Backend Toolchain Assets]] — application assets: listing, name and link checks, staging (#973).
- [[Native Android Activity]] — the single launcher activity, lifecycle and size reporting, self-test gate.

- [[Backend Frame Slots]] · [[Backend Frame Slot References]] — physical slot reuse for generated C11.
