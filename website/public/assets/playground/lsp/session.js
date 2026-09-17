// Questions to the language server, through the playground's assist endpoint.
//
// Each question carries the whole program, so an answer is about exactly the
// text it was asked for. A newer question of the same kind withdraws an older
// one. A server that keeps failing is left alone for a while rather than asked
// on every keystroke, and the reader is told so once.

import {
  ASSIST_PAUSE_MS,
  ASSIST_TIMEOUT_MS,
  DEFAULT_RETRY_SECONDS,
  FAILURES_BEFORE_PAUSE,
  HTTP_SERVER_ERROR,
  HTTP_TOO_MANY,
  OUTCOME,
} from "../config/constants.js";
import { MESSAGES } from "../config/messages.js";
import { postJson, retryAfterSeconds } from "../net/request.js";

// Questions stop, and pending ones are withdrawn, when `signal` ends the editor.
export function createSession({ endpoint, enabled, onNote, signal }) {
  const available = Boolean(enabled && endpoint && window.fetch && window.AbortController);
  const pending = new Map();
  const resumeListeners = new Set();
  let failures = 0;
  let pausedUntil = 0;
  let resumeTimer = null;

  signal.addEventListener("abort", () => {
    clearTimeout(resumeTimer);
    pending.forEach((cancel) => cancel.abort());
    pending.clear();
  }, { once: true });

  async function ask(method, text, position) {
    if (!available || signal.aborted || Date.now() < pausedUntil) return null;
    pending.get(method)?.abort();
    const cancel = new AbortController();
    pending.set(method, cancel);
    try {
      const { status, headers, answer } = await postJson(
        endpoint,
        { source: text, method, line: position.line, character: position.character },
        { timeoutMs: ASSIST_TIMEOUT_MS, cancel: cancel.signal },
      );
      if (status === HTTP_TOO_MANY) {
        pause(retryAfterSeconds(headers, DEFAULT_RETRY_SECONDS) * 1000, MESSAGES.assistPaused);
        return null;
      }
      if (answer.outcome !== OUTCOME.answered) {
        if (status >= HTTP_SERVER_ERROR) failed();
        return null;
      }
      recovered();
      return { text, result: answer.result, diagnostics: answer.diagnostics };
    } catch (failure) {
      if (!failure.cancelled) failed();
      return null;
    } finally {
      if (pending.get(method) === cancel) pending.delete(method);
    }
  }

  function failed() {
    failures += 1;
    if (failures >= FAILURES_BEFORE_PAUSE) pause(ASSIST_PAUSE_MS, MESSAGES.assistUnavailable);
  }

  function recovered() {
    if (pausedUntil || failures >= FAILURES_BEFORE_PAUSE) onNote("");
    failures = 0;
  }

  function pause(millis, note) {
    failures = 0;
    pausedUntil = Date.now() + millis;
    onNote(note);
    clearTimeout(resumeTimer);
    resumeTimer = setTimeout(() => {
      pausedUntil = 0;
      onNote("");
      resumeListeners.forEach((listener) => listener());
    }, millis);
  }

  return {
    available,
    ask,
    onResume: (listener) => resumeListeners.add(listener),
  };
}
