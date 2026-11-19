---
type: handoff
status: ACTIVE
issue: 965
aliases: [Declared Attributes Delivery]
---

# Declared Attributes Delivery

Attributes are declared with `attribute name(...)`, so a derive's reads are checked: a misspelled or misused attribute is an error at the use, not an input the derive silently ignores.

## Roles

- Language Architect: designing. Owns the grammar, tree and checker contract in [[grammar/pudu]] and [[architecture/DERIVES]].
- Backend Engineer: implementing the parser, tree and checker.
- Review: Language Architect (semantic and public change) and Forensic Guardian (wiki parity). The implementation author is not the sole reviewer.

## Design

- Declarations are program-wide, collected in formation; conflicts are `E3106`.
- Uses are checked in [[Type Check Attribute]]: `E3104` for undeclared names, `E3105` for count or kind mismatches, `E1069` for unsupported parameter kinds.
- Standard library declares json, skip, default, binary, column, label, min, max and readonly.

## Evidence

Fixtures: [[src/test-fixtures/attributes/UnknownAttribute]] · [[src/test-fixtures/attributes/WrongAttributeArgument]] · [[src/test-fixtures/attributes/conflict/Main]] · [[src/test-fixtures/attributes/conflict/Tags]] · [[src/test-fixtures/attributes/UndeclaredRead]] · [[src/test-fixtures/attributes/UnsupportedKind]] · [[src/test-fixtures/attributes/DeclaredAttribute]]. Spec: [[Program Attribute Spec]].

## Exact next action

Run the full gates, then open the PR to dev.
