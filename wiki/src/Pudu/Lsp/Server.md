---
type: module
path: "@root/src/Pudu/Lsp/Server.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Server, Language Server]
---

# Lsp Server

## Purpose

Answer an editor's questions about an open program, over the language server protocol.

## Interface

```haskell
data Analysis = Analysis
  { analysisText        :: !Text
  , analysisSource      :: !Source
  , analysisDiagnostics :: ![Diagnostic]
  , analysisIndex       :: !DocIndex
  }
data Documents
analyse            :: Text -> Text -> IO Analysis
answer             :: Documents -> Message -> (Documents, [Text])
rememberAnalysis   :: Text -> Analysis -> Documents -> Documents
runServer          :: IO ()
serverCapabilities :: Json
```

### Governance

- **The server is the compiler.** `analyse` runs the ordinary compile, so an editor sees exactly
  what `pudu check` prints — the same codes, spans, and help — and hover shows the same signature
  `pudu doc` reports. A second analyser written for the editor would drift from the first within a
  release, and an editor that disagrees with the command line is worse than one that says nothing.
- **`answer` is pure.** All IO happens in `refresh`, which recompiles when a message carried new
  text, and in the loop that reads and writes the handles. Every feature is therefore testable
  without a client, a socket, or a running editor.
- The editor's copy of a file is authoritative while it is open, because it holds edits the disk has
  not seen. Compiling what is on disk would report diagnostics against text the reader is not
  looking at.
- An `Analysis` is held rather than recomputed per request: a hover, a definition, and a completion
  within one keystroke would otherwise compile the program three times.
- **Only implemented capabilities are announced.** A capability claimed and not honoured is worse
  than one withheld — the editor stops offering its own fallback and the reader gets nothing at all.
  Rename, references, and semantic tokens are absent for that reason.
- Synchronisation is full-document. An incremental edit is not accepted, because the server would be
  applying a range it has no guarantee it can interpret.
- A notification is never answered. Replying to one is the single protocol error a client cannot
  recover from: it waits forever for a response to a request it never made.
- An unknown *request* is refused with method-not-found rather than ignored, because a client does
  wait for an answer to every request it sends.
- Formatting replaces the whole document in one edit. The formatter guarantees it only moves
  whitespace, so a full replacement cannot change the program, and a client applies one edit
  atomically.
- A file's own directory is its source root, so a sibling module is importable from an editor the
  same way it is from the command line.
- Every new language surface joins the real stdio-session fixture. The fixture opens a clean
  compatibility document and requires an empty diagnostic list, so an editor cannot silently keep
  an older parser or checker contract while command-line-only tests advance.

- **Hover answers about what the cursor is on, and about the declaration containing it only when nothing else answers.** The documentation index holds declarations, so asking it alone could only ever name the function a cursor was inside — hovering `text` in `text.length()` reported the enclosing `main`, which is true of every position in that body and therefore tells a reader nothing.
- **After a dot, completion offers what the value carries.** The receiver is the expression ending at the dot, which the checker already recorded a type for, and the method names come from the tables dispatch reads. A request carrying no position asks about the document rather than a place in it, and is answered as it always was.
- **A type the reader wrote carries what they gave it.** The built-in sets answer for `Str` and `Array` and say nothing about anything a program declared, so the methods an `impl` block wrote are offered alongside them — the index already names the type each was implemented for.
- **A foreign function use retains provenance on hover.** The compiler-inferred signature remains first, but the declaration index is preferred for that name so the editor also says the signature is asserted against the named library rather than proved from a body. Opaque foreign handle declarations appear in outline and completion as types.

### Linkage

- **Requires:** [[Lsp Protocol]], [[Lsp Feature]], [[Lsp Json]], [[Compiler Program]], [[Doc]],
  [[Format]], [[Diagnostic Model]].
- **Consumed by:** [[Pudu CLI]] through `pudu lsp`, and the VS Code client under `editors/vscode`.

## Algorithm

Read a message; if it carried text, compile and store the analysis; answer purely from what is
stored; write the replies. The loop ends when the stream closes, when `exit` arrives, or when a
framing fault leaves the reader with no way to find the next message.

Everything a message costs is guarded. A failure while compiling or answering is caught, reported,
and answered with an error to the request that caused it; the loop then carries on and the document
store keeps whatever it last held, since what the failed analysis would have stored is unknown. The
replies are forced inside that guard, because `answer` is pure and builds them lazily, so a failure
inside one would otherwise surface where it is written to the handle rather than where it can be
caught.

## Negative Logic (Prohibited Paths)

- No analysis of its own: nothing here decides what a program means.
- No reply to a notification, and no silent drop of a request — including when the work for it fails, since a client that receives nothing waits for as long as the session lasts.
- No end to the session for a message the server could not understand.
- No success status on a session that ended because the stream broke.
- No capability announced that is not implemented.
- No disk read for an open document.

## Grill Log

- **Q:** Why not compute diagnostics incrementally? **A:** Because a whole-program compile is
  already fast enough, and incrementality is where language servers go wrong. _Rationale:_ a stale
  cache shows an error that is fixed or hides one that is not, and both destroy trust in the editor
  faster than a slower response does. _Rejected:_ a dependency-tracked rebuild graph, which is most
  of the bulk of every mature server and buys nothing at this size.
- **Q:** Should a failure while answering end the session? **A:** No. _Rationale:_ the failure is
  the server's own, and taking the editor's whole session with it turns one unanswerable question
  into a dead language server that has to be restarted by hand. Answering that one request with an
  error leaves everything else working. _Rejected:_ letting it propagate, which is what made a
  single unhandled case cost the session.
- **Q:** Then why does a framing fault end it? **A:** Because it is the one failure that leaves the
  reader unable to continue. _Rationale:_ every other failure is contained to a frame whose bounds
  are known, so the next read starts in the right place; a framing fault has no such boundary and
  the protocol offers no marker to recover one. It leaves with a failing status, because an editor
  told a session succeeded reports a clean shutdown for something that broke. _Rejected:_ guessing
  at where the next frame starts.
- **Q:** Why is `answer` pure when the protocol is inherently effectful? **A:** So the features can
  be tested. _Rationale:_ every handler is a function from what was compiled to what the editor
  shows, and the whole suite runs without a client. _Rejected:_ threading IO through the handlers,
  which would have made each one testable only end to end.
- **Q:** Why test recent syntax through a spawned server when `analyse` already uses the compiler?
  **A:** To prove the installed command reaches that compiler. _Rationale:_ protocol framing,
  process selection, and stale binaries sit outside the pure handler and are exactly where an
  editor installation can drift. _Rejected:_ another editor-specific analyser or a version-only
  smoke test.

## Referenced by

[[src/Pudu/_MOC]] · [[Tooling]] · [[Pudu CLI]] · [[Doc]]
