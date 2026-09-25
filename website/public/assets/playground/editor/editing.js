// Changes to the program that keep the browser's undo history.
//
// Every change goes through `insertText`, which the browser records as typing;
// assigning the text area's value would erase the history. Where the command is
// gone, the change is made directly and announced as input.

import { BRACKET_PAIRS, CLOSERS, INDENT } from "../config/constants.js";
import { focusWithoutScrolling } from "../dom/nodes.js";
import { lineEndFrom, lineStartOf } from "../text/positions.js";
import { inCommentOrString } from "../text/scan.js";

const OPENS_BLOCK = /[{([]\s*$/;
const CLOSES_NEXT = /^\s*[})\]]/;
const PAIR_ALLOWED_BEFORE = /[\s)\]},;]/;
const LEADING_SPACE = /^[ \t]*/;
const WORD_END = /[A-Za-z0-9_]$/;
const COMMENTED = /^\s*\/\//;

export function createEditing({ source, geometry, onMoved }) {
  // While the editor makes a change itself, what the reader typed to cause it:
  // a character, or null when they typed nothing. Undefined otherwise.
  let intent;

  // Insert `text` at the selection. `typed` is the character the reader typed
  // that this insertion stands for, if any.
  function insert(text, typed = null) {
    focusWithoutScrolling(source);
    intent = typed;
    try {
      if (document.execCommand?.("insertText", false, text)) return;
      source.setRangeText(text, source.selectionStart, source.selectionEnd, "end");
      source.dispatchEvent(new InputEvent("input", { inputType: "insertText", data: text }));
    } finally {
      intent = undefined;
    }
  }

  function replaceRange(start, end, text, typed = null) {
    focusWithoutScrolling(source);
    source.setSelectionRange(start, end);
    if (text) {
      insert(text, typed);
      return;
    }
    if (start === end) return;
    intent = null;
    try {
      if (!document.execCommand?.("delete", false)) insert("");
    } finally {
      intent = undefined;
    }
  }

  function moveCaret(offset) {
    focusWithoutScrolling(source);
    source.setSelectionRange(offset, offset);
    geometry.reveal(offset);
    onMoved();
  }

  function newline(event) {
    const { selectionStart: start, selectionEnd: end, value } = source;
    const before = value.slice(0, start);
    const indentation = LEADING_SPACE.exec(before.slice(lineStartOf(value, start)))[0];
    const opens = OPENS_BLOCK.test(before);
    if (!indentation && !opens) return;
    event.preventDefault();
    if (opens && CLOSES_NEXT.test(value.slice(end))) {
      insert(`\n${indentation}${INDENT}\n${indentation}`);
      moveCaret(start + 1 + indentation.length + INDENT.length);
    } else {
      insert(`\n${indentation}${opens ? INDENT : ""}`);
    }
  }

  // Brackets and quotes are typed in pairs; typing the closer the caret stands
  // before steps over it; a `}` typed on a blank line moves back a level.
  function typeCharacter(event) {
    const { selectionStart: start, selectionEnd: end, value } = source;
    const key = event.key;
    const quoted = inCommentOrString(value, start);
    if (quoted && key !== '"') return;
    if (start === end && CLOSERS.has(key) && value[end] === key && (key !== '"' || quoted)) {
      event.preventDefault();
      moveCaret(start + 1);
      return;
    }
    if (key === "}" && start === end && dedentBeforeClose(start)) {
      event.preventDefault();
      return;
    }
    if (!(key in BRACKET_PAIRS)) return;
    if (key === '"' && (quoted || WORD_END.test(value.slice(0, start)))) return;
    if (start !== end) {
      event.preventDefault();
      const selected = value.slice(start, end);
      insert(key + selected + BRACKET_PAIRS[key], key);
      source.setSelectionRange(start + 1, start + 1 + selected.length);
      return;
    }
    if (value[end] && !PAIR_ALLOWED_BEFORE.test(value[end])) return;
    event.preventDefault();
    insert(key + BRACKET_PAIRS[key], key);
    moveCaret(start + 1);
  }

  function dedentBeforeClose(caret) {
    const lineStart = lineStartOf(source.value, caret);
    const leading = source.value.slice(lineStart, caret);
    if (leading.length < INDENT.length || !/^ +$/.test(leading)) return false;
    replaceRange(caret - INDENT.length, caret, "}", "}");
    return true;
  }

  // Backspace between an empty pair removes both halves.
  function removePair(event) {
    const { selectionStart: start, selectionEnd: end, value } = source;
    if (start !== end || start === 0) return;
    if (BRACKET_PAIRS[value[start - 1]] === value[start]) {
      event.preventDefault();
      replaceRange(start - 1, start + 1, "");
    }
  }

  // The lines the selection touches.
  function selectedBlock() {
    const { selectionStart: start, value } = source;
    let end = source.selectionEnd;
    if (end > start && value[end - 1] === "\n") end -= 1;
    const first = lineStartOf(value, start);
    return { first, last: lineEndFrom(value, end) };
  }

  function rewriteLines(change) {
    const { first, last } = selectedBlock();
    const block = source.value.slice(first, last);
    const rewritten = block.split("\n").map(change).join("\n");
    if (rewritten === block) return;
    replaceRange(first, last, rewritten);
    source.setSelectionRange(first, first + rewritten.length);
  }

  function indent() {
    const { selectionStart: start, selectionEnd: end, value } = source;
    if (value.slice(start, end).includes("\n")) rewriteLines((line) => (line ? INDENT + line : line));
    else insert(INDENT);
  }

  function outdent() {
    const { selectionStart: start, selectionEnd: end, value } = source;
    if (start !== end) {
      rewriteLines((line) => line.replace(/^ {1,2}/, ""));
      return;
    }
    const lineStart = lineStartOf(value, start);
    const leading = /^ {0,2}/.exec(value.slice(lineStart))[0].length;
    if (leading === 0) return;
    replaceRange(lineStart, lineStart + leading, "");
    moveCaret(Math.max(lineStart, start - leading));
  }

  function toggleComment() {
    const { first, last } = selectedBlock();
    const lines = source.value.slice(first, last).split("\n");
    const commented = lines.filter((line) => line.trim()).every((line) => COMMENTED.test(line));
    rewriteLines((line) => {
      if (!line.trim()) return line;
      return commented ? line.replace(/^(\s*)\/\/ ?/, "$1") : line.replace(/^(\s*)/, "$1// ");
    });
  }

  // Replace the whole program, as one step Undo can take back.
  function replaceAll(text) {
    replaceRange(0, source.value.length, text);
    moveCaret(0);
    source.scrollTop = 0;
    source.scrollLeft = 0;
  }

  return {
    insert,
    replaceRange,
    replaceAll,
    moveCaret,
    newline,
    typeCharacter,
    removePair,
    indent,
    outdent,
    toggleComment,
    intent: () => intent,
  };
}
