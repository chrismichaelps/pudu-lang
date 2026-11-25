---
date: 2026-11-25
topic: parallel-c-units
to_role: Implementer
status: READY
tags: [handoff, native, toolchain]
---

# Handoff — parallel C units (#1003)

Role: Implementer. Owned files when work starts: `packages/pudu/v0.1/src/Pudu/Backend/Toolchain.hs`, `Backend/Emit/Frame.hs`, `Backend/Emit/State.hs`, and the runtime part modules whose file-scope state moves.

## Measurements (website, `pudu build website/src/Main.pudu --native`)

| Step | Time |
|---|---|
| Whole build | about 104 s |
| Frontend (parse, check, lower, emit) | about 22 s |
| `cc -O2` on the one generated unit (358k lines, 25 MB) | 70 to 81 s |
| same unit at `-O1` | 59 s |
| same unit at `-O0` | 12 s |
| `-O2` with stepping bodies marked cold | 66 s |
| `-O2 -fno-inline-functions` | 34 s, but the site serves about 20% fewer requests per second (home 1,380 to 1,100; module page 424 to 328), so it is not a default |

The optimizer's cost is spread over about 4,000 functions; no single function dominates. A stepping body that has a direct form is only a thin wrapper around it, so there is no duplicated code to remove.

## Design

- One generated header for every unit: types, `static inline` runtime helpers (each unit keeps its own copy so hot paths still inline), prototypes for every program function and aggregate helper, and `extern` declarations for every piece of file-scope data and state.
- Unit 0 defines all file-scope data and state exactly once: site tables, byte data, function and ownership tables, constant cells, the frame engine's globals, thread-locals, and any one-time flags (for example the flag inside `pudu_constants_arrange`, which must stay single so release is registered once).
- Program functions and aggregate helpers are partitioned across units by size; definitions lose `static` in split mode so they link across units.
- The toolchain compiles the units concurrently (one per core, capped) and links them. Programs below a size threshold keep the single unit, where a split costs more than it saves.
- Output and diagnostics must stay identical; the native key cache keys on the whole set of units.

## Risks

- Runtime parts are written as raw C lines, so each top-level item must be classified as declaration, definition, or data. Function-local `static` state in a helper copied into several units would silently split; such helpers must be defined once.
- Cross-unit calls of formerly static functions lose inlining unless they stay `static inline` in the header.

## Exact next action

Add an emitter-level item type that tags every top-level C item the frame emitter and runtime parts produce as declaration, inline helper, definition, or data, and render today's single unit from it with byte-identical output, proven by diffing the website's generated C before and after.
