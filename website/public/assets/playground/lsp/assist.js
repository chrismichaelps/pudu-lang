// The editor's language assistance, assembled: problems, completion, hover,
// and signature help, all answered by the language server.
//
// Nothing here decides what a name means or whether a program is wrong. What
// this owns is timing and presentation: when to ask, which answers are still
// about the text on screen, and how to show them without getting in the way.

import { BLUR_GRACE_MS, CARET_KEYS, MODIFIER_KEYS } from "../config/constants.js";
import { createCompletion } from "./completion.js";
import { createDiagnostics } from "./diagnostics.js";
import { createHover } from "./hover.js";
import { createSession } from "./session.js";
import { createSignatureHelp } from "./signature.js";

export function startAssist(editor, { endpoint, enabled }) {
  const session = createSession({ endpoint, enabled, onNote: editor.setAssistNote, signal: editor.signal });
  const diagnostics = createDiagnostics({ session, editor });
  const signature = createSignatureHelp({ editor, session });
  const completion = createCompletion({ editor, session });
  const hover = createHover({ editor, session, problemsAt: diagnostics.at, blocked: () => completion.open });
  const { source } = editor;

  function hideAll() {
    completion.close();
    hover.hide();
    signature.hide();
  }

  function nextProblem() {
    const offset = diagnostics.nextAfter(editor.caret());
    if (offset < 0) return false;
    editor.moveCaret(offset);
    hover.showProblemsAt(offset);
    return true;
  }

  function hideOnBlur() {
    setTimeout(() => {
      if (document.activeElement !== source) hideAll();
    }, BLUR_GRACE_MS);
  }

  source.addEventListener("mousemove", hover.pointerMoved);
  source.addEventListener("mouseleave", hover.pointerLeft);
  source.addEventListener("scroll", hideAll, { passive: true });
  source.addEventListener("blur", hideOnBlur);
  source.addEventListener("mousedown", () => {
    completion.close();
    hover.hide();
  });

  if (session.available) diagnostics.schedule(0);

  return {
    available: session.available,
    nextProblem,
    hideAll,
    // The text changed from `before` to `after`, by typing `typed` when known.
    changed(before, after, typed) {
      diagnostics.changed(before, after);
      hover.hide();
      completion.typed(typed);
      signature.typed(typed);
    },
    // A program replaced whole: an example opened, or the editor reset.
    replaced() {
      hideAll();
      diagnostics.reset();
    },
    // A key the editor has not handled; true when assistance took it.
    key(event) {
      if (completion.handleKey(event)) return true;
      const mod = event.ctrlKey || event.metaKey;
      if (event.key === " " && mod && !event.altKey) {
        event.preventDefault();
        completion.request(true);
        return true;
      }
      if (event.key === "F8") {
        event.preventDefault();
        nextProblem();
        return true;
      }
      if (event.key === "Escape" && (signature.visible || hover.visible)) {
        signature.hide();
        hover.hide();
        return true;
      }
      if (!MODIFIER_KEYS.has(event.key)) hover.hide();
      if (CARET_KEYS.has(event.key)) completion.close();
      return false;
    },
  };
}
