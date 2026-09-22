// When to ask for completions, which answers still apply, and accepting one.

import {
  ASSIST,
  CALLABLE_KINDS,
  COMPLETION_DELAY_MS,
  COMPLETION_PAGE_ROWS,
  COMPLETION_TRIGGERS,
  PATH_TEXT,
  SERVER_TRIGGERS,
} from "../config/constants.js";
import { offsetAt } from "../text/positions.js";
import { inImportSelection, isName, wantsCompletion, wordAfter, wordBefore } from "../text/scan.js";
import { createCompletionList } from "./completion-list.js";
import { onlyRepeats, rankCompletions, usableItems } from "./completion-rank.js";

export function createCompletion({ editor, session }) {
  const list = createCompletionList({ source: editor.source, signal: editor.signal, onPick: accept });
  let items = [];
  let anchor = -1;
  let explicitList = false;
  // An answer whose items replace a range, a module path, is filtered and
  // accepted over that whole range rather than the name at the caret.
  let replacesRange = false;
  let timer = null;
  let round = 0;
  // Where a list was answered empty, so typing on in the same name does not
  // ask again for what the server already said has no answer.
  let emptyAnchor = -1;

  function request(explicit = false, trigger = "") {
    clearTimeout(timer);
    const text = editor.text();
    const caret = editor.caret();
    if (editor.hasSelection() || !wantsCompletion(text, caret, explicit, trigger)) {
      close();
      return;
    }
    const start = caret - wordBefore(text, caret).length;
    if (list.open && (start === anchor || (replacesRange && fits(text.slice(anchor, caret))))) {
      refilter();
      return;
    }
    if (!explicit && start === emptyAnchor) return;
    const sent = SERVER_TRIGGERS.has(trigger) ? trigger : "";
    timer = setTimeout(() => ask(start, explicit, sent), explicit ? 0 : COMPLETION_DELAY_MS);
  }

  async function ask(start, explicit, trigger) {
    const mine = ++round;
    const asked = editor.text();
    const askedCaret = editor.caret();
    const answer = await session.ask(ASSIST.completion, asked, editor.positionOf(askedCaret, asked), trigger);
    if (!answer || mine !== round) return;
    const answered = usableItems(answer.result);
    const edited = answered.find((item) => item.textEdit?.range?.start);
    const from = edited ? Math.min(start, offsetAt(asked, edited.textEdit.range.start)) : start;
    if (!stillApplies(asked, askedCaret, from, Boolean(edited))) return;
    if (answered.length === 0) {
      emptyAnchor = start;
      close();
      return;
    }
    emptyAnchor = -1;
    items = answered;
    anchor = from;
    replacesRange = Boolean(edited);
    explicitList = explicit;
    refilter();
  }

  function fits(typed, range = replacesRange) {
    return range ? PATH_TEXT.test(typed) : isName(typed);
  }

  // An answer holds while the reader has only gone on typing the same name:
  // everything before the name and after the caret is as it was asked.
  function stillApplies(asked, askedCaret, start, range) {
    const text = editor.text();
    const caret = editor.caret();
    return (
      caret >= start &&
      text.slice(0, start) === asked.slice(0, start) &&
      text.slice(caret) === asked.slice(askedCaret) &&
      fits(text.slice(start, caret), range)
    );
  }

  function refilter() {
    const caret = editor.caret();
    const typed = editor.text().slice(anchor, caret);
    if (anchor < 0 || caret < anchor || !fits(typed)) {
      close();
      return;
    }
    const ranked = rankCompletions(items, typed);
    if (ranked.length === 0 || (onlyRepeats(ranked, typed) && !explicitList)) {
      close();
      return;
    }
    const point = editor.screenPoint(anchor);
    list.show(ranked, point.x - 6, point.y + editor.lineHeight() + 2, point.y - 2);
  }

  function accept(index) {
    const item = list.itemAt(index);
    if (!item) return;
    const text = editor.text();
    const caret = editor.caret();
    const end = caret + wordAfter(text, caret).length;
    const insertion =
      typeof item.textEdit?.newText === "string"
        ? item.textEdit.newText
        : typeof item.insertText === "string"
          ? item.insertText
          : item.label;
    const start = anchor;
    close();
    editor.replaceRange(start, end, insertion);
    // A function chosen in an import's selection is named, not called.
    const calls = CALLABLE_KINDS.has(item.kind) && !inImportSelection(editor.text(), editor.caret());
    if (calls && editor.text()[editor.caret()] !== "(") {
      const after = editor.caret();
      editor.replaceRange(after, after, "()", "(");
      editor.moveCaret(after + 1);
    }
  }

  function close() {
    clearTimeout(timer);
    round += 1;
    anchor = -1;
    replacesRange = false;
    if (list.open) list.hide();
  }

  const MOVES = {
    ArrowDown: () => list.select((list.selected + 1) % list.count),
    ArrowUp: () => list.select((list.selected - 1 + list.count) % list.count),
    PageDown: () => list.select(Math.min(list.count - 1, list.selected + COMPLETION_PAGE_ROWS)),
    PageUp: () => list.select(Math.max(0, list.selected - COMPLETION_PAGE_ROWS)),
    Enter: () => accept(list.selected),
    Tab: () => accept(list.selected),
    Escape: close,
  };

  // Take a key meant for the open list; true when it was taken.
  function handleKey(event) {
    const move = MOVES[event.key];
    if (!list.open || !move) return false;
    const plain = !(event.shiftKey || event.altKey || event.ctrlKey || event.metaKey);
    if ((event.key === "Enter" || event.key === "Tab") && !plain) return false;
    event.preventDefault();
    move();
    return true;
  }

  return {
    request,
    handleKey,
    close,
    get open() {
      return list.open;
    },
    // The text changed by typing `typed`, when that is known.
    typed(typedText) {
      if (typedText === "." || (typedText?.length === 1 && isName(typedText))) request();
      else if (COMPLETION_TRIGGERS.has(typedText)) request(false, typedText);
      else if (list.open) refilter();
    },
  };
}
