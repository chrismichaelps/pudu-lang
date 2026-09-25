---
type: test
path: "@root/website/src/Test/LiveStand.pudu"
fidelity: Active
tags: [website, packages, test]
aliases: [website live stand]
---
# Website Live Stand

A stand-in GitHub for the live package suites: a table of addresses and bodies, entity tags derived
from each body so a revalidation with an unchanged tag is answered `304`, a switch that makes every
request fail, and a clock the test moves. Nothing reaches the network.

Resolved Grill Log: entity tags are computed from the body rather than stored, so changing a body in
a test changes its tag exactly as GitHub's would.

## Referenced by

[[website live pages suite]] · [[website live packages suite]] · [[website/_MOC]]
