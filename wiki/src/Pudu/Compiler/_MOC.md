---
type: moc
tags: [moc]
aliases: [Program Compiler Module Map]
---

# Program Compiler Module Map

- [[Compiler Program]] — dependency discovery, module graph ordering, and cross-module interface
  orchestration.
- [[Compiler Library]] — where a module is looked for, and how `Std` resolves from the distribution.

Dependency direction: Library → Program. Only [[Compiler Program]] reads files.

## Referenced by

[[src/Pudu/_MOC]] · [[Compiler Pipeline]]
