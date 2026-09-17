// Asking for a program's problems once the reader pauses, and keeping the ones
// already shown in step with what they type meanwhile.

import { ASSIST, DIAGNOSTICS_DELAY_MS } from "../config/constants.js";
import { nextProblemOffset, problemsAt, shiftProblems, validProblems } from "../model/problems.js";

export function createDiagnostics({ session, editor }) {
  let problems = [];
  let timer = null;

  function publish(list, fresh) {
    problems = list;
    editor.showProblems(problems, fresh);
  }

  async function refresh() {
    const text = editor.text();
    const answer = await session.ask(ASSIST.diagnostics, text, { line: 0, character: 0 });
    if (answer && answer.text === editor.text()) publish(validProblems(answer.diagnostics), true);
  }

  function schedule(delay = DIAGNOSTICS_DELAY_MS) {
    clearTimeout(timer);
    timer = setTimeout(refresh, delay);
  }

  session.onResume(() => schedule(0));

  return {
    schedule,
    changed(before, after) {
      if (problems.length > 0) publish(shiftProblems(problems, before, after), false);
      schedule();
    },
    reset() {
      publish([], true);
      schedule(0);
    },
    at: (offset) => problemsAt(problems, editor.text(), offset),
    nextAfter: (caret) => nextProblemOffset(problems, editor.text(), caret),
  };
}
