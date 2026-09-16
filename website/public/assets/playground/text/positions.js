// Offsets into a program and the lines and characters the language server
// counts in. Both count UTF-16 units, as a text area does.

import { TAB_WIDTH } from "../config/constants.js";

export function positionAt(text, offset) {
  const bounded = Math.max(0, Math.min(offset, text.length));
  let line = 0;
  let lineStart = 0;
  for (let index = text.indexOf("\n"); index >= 0 && index < bounded; index = text.indexOf("\n", index + 1)) {
    line += 1;
    lineStart = index + 1;
  }
  return { line, character: bounded - lineStart };
}

export function offsetAt(text, position) {
  let offset = 0;
  for (let line = 0; line < position.line; line += 1) {
    const end = text.indexOf("\n", offset);
    if (end < 0) return text.length;
    offset = end + 1;
  }
  return Math.min(offset + Math.max(0, position.character), lineEndFrom(text, offset));
}

export function lineStartOf(text, offset) {
  return text.lastIndexOf("\n", offset - 1) + 1;
}

export function lineEndFrom(text, offset) {
  const end = text.indexOf("\n", offset);
  return end < 0 ? text.length : end;
}

export function lineText(text, line) {
  return text.split("\n", line + 1)[line] ?? "";
}

export function countLines(text) {
  let count = 1;
  for (let index = text.indexOf("\n"); index >= 0; index = text.indexOf("\n", index + 1)) count += 1;
  return count;
}

// The column a character is drawn in: a tab reaches the next tab stop.
export function columnOf(line, character) {
  let column = 0;
  for (let index = 0; index < character && index < line.length; index += 1) {
    column = line[index] === "\t" ? column + TAB_WIDTH - (column % TAB_WIDTH) : column + 1;
  }
  return column + Math.max(0, character - line.length);
}

// The character drawn in a column of a line, or -1 past its end.
export function characterAtColumn(line, column) {
  for (let character = 0; character < line.length; character += 1) {
    if (column < columnOf(line, character + 1)) return character;
  }
  return -1;
}
