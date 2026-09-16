// Running and formatting the program in place.

import { ACTION, HTTP_TOO_MANY, OUTCOME, RUN_TIMEOUT_MARGIN_MS } from "../config/constants.js";
import { MESSAGES } from "../config/messages.js";
import { FAILURE } from "../net/errors.js";
import { postJson } from "../net/request.js";

export function createRunner({ form, endpoint, runMillis, editor, editing, output }) {
  const buttons = Array.from(form.querySelectorAll("button[name=action]"));
  let busy = false;

  function setBusy(on) {
    busy = on;
    buttons.forEach((button) => { button.disabled = on; });
    output.busy(on);
  }

  // Without a way to ask in place, the form is posted and the server answers
  // with the whole page.
  function postForm(action) {
    const button = document.getElementById(action === ACTION.format ? "playground-format" : "playground-run");
    form.requestSubmit(button);
  }

  async function act(action) {
    if (busy) return;
    if (!endpoint || !window.fetch) {
      postForm(action);
      return;
    }
    const asked = editor.text();
    if (!asked.trim()) {
      output.status("is-refused", MESSAGES.emptyProgram);
      return;
    }
    setBusy(true);
    if (action === ACTION.run) {
      output.status("is-running", MESSAGES.running);
      output.reveal();
    }
    try {
      const { status, answer } = await postJson(endpoint, { source: asked, action }, { timeoutMs: runMillis + RUN_TIMEOUT_MARGIN_MS });
      if (typeof answer.outcome !== "string") output.status("is-refused", MESSAGES.badAnswer);
      else if (answer.outcome === OUTCOME.formatted) formatted(asked, answer.source);
      else if (status === HTTP_TOO_MANY && !answer.headline) output.status("is-refused", MESSAGES.tooManyRuns);
      else output.outcome(answer);
    } catch (failure) {
      output.status("is-refused", failureMessage(failure));
    } finally {
      setBusy(false);
    }
  }

  function formatted(asked, text) {
    if (editor.text() !== asked) {
      output.status("is-refused", MESSAGES.changedWhileFormatting);
      return;
    }
    if (typeof text !== "string" || text === asked) {
      output.status("is-ok", MESSAGES.alreadyFormatted);
      return;
    }
    const caret = editor.caret();
    editing.replaceRange(0, asked.length, text);
    editing.moveCaret(Math.min(caret, text.length));
    output.status("is-ok", MESSAGES.formatted);
  }

  return { act };
}

function failureMessage(failure) {
  if (failure?.kind === FAILURE.timedOut) return MESSAGES.runTimedOut;
  if (failure?.kind === FAILURE.unreadable) return failure.status === HTTP_TOO_MANY ? MESSAGES.tooManyRuns : MESSAGES.badAnswer;
  return MESSAGES.offline;
}
