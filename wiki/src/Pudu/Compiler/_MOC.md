---
type: moc
tags: [moc]
aliases: [Program Compiler Module Map]
---

# Program Compiler Module Map

- [[Compiler Frame Lowering]] · [[Compiler Frame State]] · [[Compiler Frame Body]] — structured Core to explicit continuations for #499.
- [[Core Frame IR]] · [[Native Frame Lowering Tests]] — typed flat blocks and ordering/transfer evidence.

- [[Compile-Time Dependency Closure]] — transitive source inputs of expansion
  and folding, including ordinary pure helper bodies.

- [[Program Reflection Spec]] — loaded Meta accessor and heterogeneous-sequence checks.

- [[Compiler Product Publication]] — cache admission and analysis/execution product lifetime.

- [[Compiler Constants]] — transitive checked products selected for imported constant folds.
- [[Program Cache Spec]] — cold/warm product and constant dependency regression checks.

- [[Compiler Program]] — dependency discovery, module graph ordering, and cross-module interface
  orchestration.
- [[Compiler Lower]] — checked tree to [[Core IR]], with typed `E6001` refusals for everything the
  native subset does not carry.
- [[Compiler Lower Body]] — the block, statement, expression, and call-site traversal the reachability
  driver drives; state and signature admission have separate modules.
- [[Compiler Library]] — where a module is looked for, and how `Std` resolves from the distribution.
- [[Compiler Literals]] — integer literals resolved to their kind and value once, after checking.
- [[Compiler Literals Spec]] — resolved and preserved literal regressions.
- [[Compiler Cache]] — compiled products kept across runs under content and interface keys.
- [[Compiler Manifest]] — one-read project snapshots, ordered dependency roots, version diagnostics,
  and setup-operation evidence.
- [[Standard Library Program Spec]] — loaded-standard-library discovery and qualified-member diagnostic regressions.
- [[Program Spec]] — the aggregate program-compiler property list.
- [[Program Graph Spec]] — discovery, graph, interface, and search-root regressions.
- [[Program Test Common]] — complete-program evaluation and exact diagnostic observations for tests.
- [[Language Foundation Program Spec]] — function literal, capture, range, slice, and destructuring regressions.

Dependency direction: Library → Program. Only [[Compiler Program]] reads files.
- [[Compiler Lower Method]] — implementation members and trait defaults as direct calls (#551).
- [[Compiler Lower Generic]] — specialization of generic bodies (#552).
- [[Compiler Lower Try]] — `?` on Result and Option (#553).
- [[Compiler Lower For]] — `for` over ranges and sequences (#554).
- [[Compiler Lower Lambda]] — lambdas and function values (#555).

## Referenced by

[[src/Pudu/_MOC]] · [[Compiler Pipeline]]

## Native function delivery (#488)

- [[Compiler Lower State]]
- [[Compiler Lower Signature]]

- [[Compiler Lower Control]] — resolved scalar loop targets, transfers and divergence (#489).

- [[Compiler Lower Types]] — same-module solved types for native lowering (#491).

- [[Native Solved Types Tests]] — canonical representation and fact identity regressions.

- [[Compiler Lower Scalar]] — represented operators and ordered runtime failures (#494).

- [[Compiler Lower Constant]] — typed projection of compiler-folded constants (#543).

- [[Compiler Lower Reference]] — checked shared-reference identity lowering (#544).
