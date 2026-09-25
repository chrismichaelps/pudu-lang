// Small readings of the text around the caret. They decide when a question is
// worth asking the language server, never what the answer is.

import { lineStartOf } from "./positions.js";

const WORD_BEFORE = /[A-Za-z0-9_]*$/;
const WORD_AFTER = /^[A-Za-z0-9_]*/;
const NAME = /^[A-Za-z0-9_]*$/;
const MEMBER_BEING_WRITTEN = /(?:^|[^.])\.[A-Za-z_]?[A-Za-z0-9_]*$/;
const NUMBER_BEFORE_DOT = /\d\.[A-Za-z0-9_]*$/;
const CALLEE_BEFORE = /[A-Za-z0-9_]\s*$/;
// A name written after one of these words is a new name, so there is nothing
// to complete.
const NAMING = /(?:^|[^A-Za-z0-9_])(?:let|var|const|fn|type|trait|module|as|for)\s+(?:mut\s+)?[A-Za-z0-9_]*$/;
// After these words a name is chosen from what the server knows: a module's
// path after `import`, a variant after `case`.
const CHOOSING = /(?:^|[^A-Za-z0-9_])(?:import|case)\s+[A-Za-z0-9_.]*$/;
// What stands before a brace that opens a list of names: an import's path, or
// a record literal's type written directly before it.
const SELECTION_OPENER = /(?:^|[^A-Za-z0-9_])import\s+[A-Za-z0-9_.]+\s*$/;
const RECORD_OPENER = /(?:^|[^A-Za-z0-9_.])[A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)*$/;
// How far back an enclosing brace is looked for.
const BRACE_REACH = 4000;

export function wordBefore(text, caret) {
  return WORD_BEFORE.exec(text.slice(0, caret))[0];
}

export function wordAfter(text, caret) {
  return WORD_AFTER.exec(text.slice(caret))[0];
}

export function isName(text) {
  return NAME.test(text);
}

export function isNameCharacter(character) {
  return typeof character === "string" && character.length === 1 && NAME.test(character);
}

// Whether an offset is inside a comment or a string on its line, where a
// completion list would only get in the way.
export function inCommentOrString(text, offset) {
  const line = text.slice(lineStartOf(text, offset), offset);
  let quoted = false;
  for (let index = 0; index < line.length; index += 1) {
    const character = line[index];
    if (quoted) {
      if (character === "\\") index += 1;
      else if (character === '"') quoted = false;
    } else if (character === '"') {
      quoted = true;
    } else if (character === "/" && line[index + 1] === "/") {
      return true;
    }
  }
  return quoted;
}

// Whether completion is worth asking for at the caret, typing `trigger` when
// a character other than a name's set it off.
export function wantsCompletion(text, caret, explicit, trigger = "") {
  if (inCommentOrString(text, caret)) return false;
  const before = text.slice(0, caret);
  if (MEMBER_BEING_WRITTEN.test(before)) return !NUMBER_BEFORE_DOT.test(before);
  if (explicit || CHOOSING.test(before)) return true;
  if (trigger === "{" || trigger === ",") return opensNameList(text, caret);
  const word = wordBefore(text, caret);
  return Boolean(word) && !/^\d/.test(word) && !NAMING.test(before);
}

// Whether the caret is inside the braces of an import's selection or a record
// literal, where a brace or comma starts the next name.
export function opensNameList(text, caret) {
  const brace = enclosingBrace(text, caret);
  if (brace < 0) return false;
  const before = text.slice(0, brace);
  return SELECTION_OPENER.test(before) || RECORD_OPENER.test(before);
}

// Whether the caret is inside an import's selection braces, where a function
// is named, not called.
export function inImportSelection(text, caret) {
  const brace = enclosingBrace(text, caret);
  return brace >= 0 && SELECTION_OPENER.test(text.slice(0, brace));
}

// Where the brace the caret is inside opens, or -1.
function enclosingBrace(text, caret) {
  let depth = 0;
  for (let index = caret - 1; index >= Math.max(0, caret - BRACE_REACH); index -= 1) {
    const character = text[index];
    if (character === "}") depth += 1;
    else if (character === "{") {
      if (depth === 0) return index;
      depth -= 1;
    }
  }
  return -1;
}

// Where the call the caret is inside opens, on the caret's line, or -1.
export function openCallAt(text, caret) {
  const lineStart = lineStartOf(text, caret);
  let depth = 0;
  for (let index = caret - 1; index >= lineStart; index -= 1) {
    const character = text[index];
    if (character === ")") depth += 1;
    else if (character === "(") {
      if (depth === 0) return CALLEE_BEFORE.test(text.slice(lineStart, index)) ? index : -1;
      depth -= 1;
    }
  }
  return -1;
}

// The ranges of `label` that spell `typed` in order, or null.
export function subsequenceMarks(label, typed) {
  const marks = [];
  let from = 0;
  for (const character of typed) {
    const found = label.indexOf(character, from);
    if (found < 0) return null;
    marks.push([found, found + 1]);
    from = found + 1;
  }
  return marks;
}

// What an edit changed: the length of the text both versions start with, and
// where the changed part ends in the version before.
export function changedSpan(before, after) {
  const shortest = Math.min(before.length, after.length);
  let prefix = 0;
  while (prefix < shortest && before[prefix] === after[prefix]) prefix += 1;
  let suffix = 0;
  while (suffix < shortest - prefix && before[before.length - 1 - suffix] === after[after.length - 1 - suffix]) {
    suffix += 1;
  }
  return { prefix, oldEnd: before.length - suffix, delta: after.length - before.length };
}
