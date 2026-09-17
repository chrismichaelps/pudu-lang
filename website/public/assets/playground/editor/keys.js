// The editor's keyboard: assistance first, then the playground's commands,
// then the editing that keeps a program's shape.
//
// Tab indents, so Escape followed by Tab is how the keyboard leaves the editor.

import { ACTION } from "../config/constants.js";

export function bindKeys({ source, assist, editing, act }) {
  let tabLeaves = false;

  function command(event, mod) {
    const key = event.key.toLowerCase();
    if (event.key === "Enter" && mod) return () => act(ACTION.run);
    if ((key === "f" && event.shiftKey && event.altKey) || (key === "s" && mod && !event.altKey)) {
      return () => act(ACTION.format);
    }
    if (key === "/" && mod) return editing.toggleComment;
    return null;
  }

  source.addEventListener("keydown", (event) => {
    if (event.isComposing || assist.key(event)) return;
    const mod = event.ctrlKey || event.metaKey;
    if (event.key === "Escape") {
      tabLeaves = true;
      return;
    }
    const run = command(event, mod);
    if (run) {
      event.preventDefault();
      run();
      return;
    }
    if (event.key === "Tab" && !event.altKey && !mod) {
      if (tabLeaves) {
        tabLeaves = false;
        return;
      }
      event.preventDefault();
      if (event.shiftKey) editing.outdent();
      else editing.indent();
      return;
    }
    tabLeaves = false;
    if (mod || event.altKey) return;
    if (event.key === "Enter" && !event.shiftKey) editing.newline(event);
    else if (event.key === "Backspace") editing.removePair(event);
    else if (event.key.length === 1) editing.typeCharacter(event);
  });
}
