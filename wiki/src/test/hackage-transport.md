---
type: module
path: "@root/test/hackage-transport.py"
fidelity: Active
aliases: [Hackage Transport Test]
tags: [module, test, delivery]
---
# Hackage Transport Test

## Purpose and algorithm

Extract the configuration command from [[Website Linux Workflow]], check that setup updates
are disabled and exactly one explicit update follows configuration, then run that command in
Bash with temporary CABAL_CONFIG paths. No index update or network request runs in this test.
Existing HTTP configuration must become HTTPS with signed metadata enabled, preserving cache
paths and jobs settings. The runner's repository inventory must contain only Hackage after
augmentation. A repeated invocation must produce identical configuration.
A missing configuration must be created correctly by Cabal. Temporary files are always removed.
Malformed scalar configuration must fail without changing the original file.

## Resolved Grill Log

- **Q:** Test a copied command? **A:** No; execute the exact workflow command so configuration
  syntax drift fails this focused test.
- **Q:** Fetch the complete index to test configuration? **A:** No; configuration behavior is
  proven by the real Cabal CLI; network availability is a separate CI observation.

## Referenced by

[[src/_MOC]] · [[Website Linux Workflow]] · [[Hackage Transport Delivery]]
