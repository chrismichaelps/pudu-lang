---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_nodes.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, nodes, objective-c]
aliases: [pudu_ios_nodes.h, iOS Host Nodes]
---

# pudu_ios_nodes.h

## Purpose and interface

The shared vocabulary of the iOS host: the instruction codes and control kinds of the view stream, and the host's node table. The header is included by [[iOS Host Adapter]] and by every capability header that handles an instruction naming a node, so each instruction's handler sits beside its capability while the codes, kinds and table stay in one place. Its codes match [[Std Mobile Stream]]; its kinds match the kind table of the host.

Entry points and state:
- `PUDU_UI_*` instruction codes, `CREATE` (1) through `WAKE` (40), with the network codes `FETCH` (38), `CANCEL` (39) and `WAKE` (40) handled by [[pudu_ios_fetch.h]]. `PUDU_UI_INSTRUCTIONS` is 61, the bound of the instruction table. DEVICE (58), NETWORK (59) and AWAKE (60) follow STORE_REMOVE (57) in the same table (#983).
- `PUDU_UI_*` control kinds, `LABEL` (1) through `ACTIVITY` (11). `PUDU_UI_KINDS` is 12, the bound of the kind table. Kind 0 is unused.
- `pudu_nodes`: the node table, an array indexed by node id. A slot holds the platform view of a live node, or `NSNull` for a removed node that CREATE may reuse.
- `pudu_kinds`: the kind of each slot, parallel to `pudu_nodes`, boxed as `NSNumber`.
- `pudu_node_id(reader)`: reads one node id from the stream and returns it only when that node exists.
- `pudu_node_scrolls(node)`: whether the node is a scroll viewport or a list, the two kinds that fill the area they are placed in.

## Behavior

- The codes name the instructions of the view stream in the order [[Std Mobile Stream]] writes them. `WAKE` (40) is the most recent code; `CANCEL` (39), `FETCH` (38), `REFRESH` (37), `NAVIGATE` (36) and `ANIMATE` (35) precede it.
- The control kinds are numbered from 1 so that a stream word of 0 never names a kind. A kind of 12 or more is refused by the kind table in [[iOS Host Adapter]].
- `pudu_node_id` reads one word. A node id at or past the end of `pudu_nodes`, or a slot holding `NSNull`, ends the process with the stream defect `named node before creating it:` followed by the id. The read happens before any handler changes a view.
- `pudu_node_scrolls` reads the kind of the node. It answers yes for a scroll viewport and for a list, and no for every other kind. It is only meaningful for a node that exists, so it is called after `pudu_node_id`.
- The table and the kind array are created together by the host at start and are emptied together when a ROOT or a sheet resets the tree.

## Negative Logic

- No dispatch here. Handlers that use the table live in [[iOS Host Adapter]] and in the capability headers.
- No creation or removal of nodes. CREATE and REMOVE change the table in the host; this header only reads it.
- No kind-specific behavior. The header names the kinds; their factories, setters and paint hooks are in the kind table.
- No refusal of a code. An unknown code is refused by the dispatcher in the host, not by this header.

## Dependencies and consumers

Depends on UIKit for the node types, on [[iOS Host Stream]] for the reader, `pudu_word` and `pudu_stream_defect`, and on the instruction spelling of [[Std Mobile Stream]]. Included by [[iOS Host Adapter]], and by the capability headers [[pudu_ios_navigation.h]] and [[pudu_ios_refresh.h]], which read node ids and kinds for their own instructions. It is staged beside the host translation unit ([[Native Toolchain Host Sources]]) and listed in the Cabal source list ([[pudu-cabal]]).

## Resolved Grill Log

- **Q:** Why move the codes and node table out of the host file? **A:** Capability headers need to read node ids and kinds for their own instructions; sharing them keeps each instruction's handler beside its capability and the host file under the size limit.
- **Q:** Why do removed slots hold `NSNull` rather than being deleted? **A:** The node id is the index a later stream names. Keeping the slot lets a reference to a removed node be refused as never created, and lets CREATE reuse the same index.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[iOS Host Stream]] · [[pudu_ios_navigation.h]] · [[pudu_ios_refresh.h]] · [[pudu_ios_fetch.h]] · [[Std Mobile Stream]] · [[Native iOS Navigation Delivery]] · [[Native iOS Refresh Delivery]]
