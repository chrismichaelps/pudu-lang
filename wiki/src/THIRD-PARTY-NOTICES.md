---
type: artifact
path: "@root/packages/pudu/v0.1/THIRD_PARTY_NOTICES"
fidelity: Active
aliases: [Native Floating Notices]
---
# Native Floating Notices

Preserve attribution from GHC.Internal.Float and the complete installed GHC base
license for the adapted binary64 formatter. Cite the locked GHC 9.14.1 source.
The project's own LICENSE is unchanged. Declare this artifact alongside LICENSE
in Cabal license-files so source archives retain it. [[Package Binary]] copies
it when present, rejecting unowned/nonregular notice inputs; older packages
without it retain their existing layout.

The formatter embeds the same notice in adapted C without runtime file lookup.
[[Native Binary64 Formatter Tests]] rejects drift from this artifact. Real
source/binary archives retain exact bytes, with extracted compiler/native and
SQLite checks passing. This does not admit floating source or complete numeric
coverage. Resolved Grill Log: retain upstream terms independently of project
licensing and preserve their artifact/emitted-source equality.

## Referenced by

[[Native Binary64 Formatter]] · [[Native Binary64 Formatter Tests]] · [[Native Floating Point]] · [[Package Binary]] · [[Package Binary Tests]] · [[Native Floating Notice Delivery]]
