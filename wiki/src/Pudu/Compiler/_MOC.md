---
type: moc
tags: [moc]
aliases: [Program Compiler Module Map]
---

# Program Compiler Module Map

- [[Compile-Time Dependency Closure]] — transitive source inputs of expansion
  and folding, including ordinary pure helper bodies.

- [[Program Reflection Spec]] — loaded Meta accessor and heterogeneous-sequence checks.

- [[Compiler Product Publication]] — cache admission and analysis/execution product lifetime.

- [[Compiler Constants]] — transitive checked products selected for imported constant folds.
- [[Program Cache Spec]] — cold/warm product and constant dependency regression checks.

- [[Compiler Program]] — dependency discovery, module graph ordering, and cross-module interface
  orchestration.
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

## Referenced by

[[src/Pudu/_MOC]] · [[Compiler Pipeline]]
