// The toolbar's quiet status: how many problems the program has, or why editor
// help is not answering. A note about the service outranks the count.

import { MESSAGES } from "../config/messages.js";

export function createStatus(node) {
  let note = "";
  let problems = { text: "", kind: "" };

  function render() {
    if (!node) return;
    node.textContent = note || problems.text;
    node.className = ["tool-status", note ? "" : problems.kind].filter(Boolean).join(" ");
    node.title = !note && problems.text ? MESSAGES.nextProblemHint : "";
  }

  return {
    setNote(text) {
      note = text;
      render();
    },
    setProblems(text, kind) {
      problems = { text, kind };
      render();
    },
  };
}
