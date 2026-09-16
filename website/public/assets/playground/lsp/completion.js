// When to ask for completions, which answers still apply, and accepting one.

import { ASSIST, CALLABLE_KINDS, COMPLETION_DELAY_MS, COMPLETION_PAGE_ROWS } from "../config/constants.js";
import { isName, wantsCompletion, wordAfter, wordBefore } from "../text/scan.js";
import { createCompletionList } from "./completion-list.js";
import { onlyRepeats, rankCompletions, usableItems } from "./completion-rank.js";

export function createCompletion({ editor, session }) {
  const list = createCompletionList({ source: editor.source, signal: editor.signal, onPick: accept });
  let items = [];
  let anchor = -1;
  let explicitList = false;
  let timer = null;
  let round = 0;
  // Where a list was answered empty, so typing on in the same name does not
  // ask again for what the server already said has no answer.
  let emptyAnchor = -1;

  function request(explicit = false) {
    clearTimeout(timer);
    const text = editor.text();
    const caret = editor.caret();
    if (editor.hasSelection() || !wantsCompletion(text, caret, explicit)) {
      close();
      return;
    }
    const start = caret - wordBefore(text, caret).length;
    if (list.open && start === anchor) {
      refilter();
      return;
    }
    if (!explicit && start === emptyAnchor) return;
    timer = setTimeout(() => ask(start, explicit), explicit ? 0 : COMPLETION_DELAY_MS);
  }

  async function ask(start, explicit) {
    const mine = ++round;
    const asked = editor.text();
    const askedCaret = editor.caret();
    const answer = await session.ask(ASSIST.completion, asked, editor.positionOf(askedCaret, asked));
    if (!answer || mine !== round || !stillApplies(asked, askedCaret, start)) return;
    const answered = usableItems(answer.result);
    if (answered.length === 0) {
      emptyAnchor = start;
      close();
      return;
    }
    emptyAnchor = -1;
    items = answered;
    anchor = start;
    explicitList = explicit;
    refilter();
  }

  // An answer holds while the reader has only gone on typing the same name:
  // everything before the name and after the caret is as it was asked.
  function stillApplies(asked, askedCaret, start) {
    const text = editor.text();
    const caret = editor.caret();
    return (
      caret >= start &&
      text.slice(0, start) === asked.slice(0, start) &&
      text.slice(caret) === asked.slice(askedCaret) &&
      isName(text.slice(start, caret))
    );
  }

  function refilter() {
    const caret = editor.caret();
    const typed = editor.text().slice(anchor, caret);
    if (anchor < 0 || caret < anchor || !isName(typed)) {
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
    const insertion = typeof item.insertText === "string" ? item.insertText : item.label;
    const start = anchor;
    close();
    editor.replaceRange(start, end, insertion);
    if (CALLABLE_KINDS.has(item.kind) && editor.text()[editor.caret()] !== "(") {
      const after = editor.caret();
      editor.replaceRange(after, after, "()", "(");
      editor.moveCaret(after + 1);
    }
  }

  function close() {
    clearTimeout(timer);
    round += 1;
    anchor = -1;
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
      else if (list.open) refilter();
    },
  };
}
