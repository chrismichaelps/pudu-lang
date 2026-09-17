// Where text is drawn. The editor's font is monospaced, so a position on screen
// is arithmetic on the character cell rather than a measurement per character.

import { characterAtColumn, columnOf, lineText, offsetAt, positionAt } from "../text/positions.js";

const PROBE_LENGTH = 100;
const FALLBACK = Object.freeze({ width: 8, height: 21, left: 18, top: 14 });

export function createGeometry(source) {
  const cell = { ...FALLBACK };

  // Read the character cell and the padding the text starts after from the
  // page's own styles.
  function measure() {
    const style = getComputedStyle(source);
    const probe = document.createElement("span");
    probe.textContent = "0".repeat(PROBE_LENGTH);
    probe.style.cssText = `position:absolute;visibility:hidden;white-space:pre;font:${style.font};font-variant-ligatures:none`;
    document.body.appendChild(probe);
    const width = probe.getBoundingClientRect().width / PROBE_LENGTH;
    probe.remove();
    cell.width = width || FALLBACK.width;
    cell.height = parseFloat(style.lineHeight) || FALLBACK.height;
    cell.left = parseFloat(style.paddingLeft) || 0;
    cell.top = parseFloat(style.paddingTop) || 0;
  }

  // Where a line and column is drawn, relative to the text box's content.
  function pointOf(line, column) {
    return { x: cell.left + column * cell.width, y: cell.top + line * cell.height };
  }

  function pointAt(offset) {
    const text = source.value;
    const { line, character } = positionAt(text, offset);
    return pointOf(line, columnOf(lineText(text, line), character));
  }

  function screenPoint(offset) {
    const box = source.getBoundingClientRect();
    const point = pointAt(offset);
    return { x: box.left + point.x - source.scrollLeft, y: box.top + point.y - source.scrollTop };
  }

  // The offset of the character under a point of the window, or -1.
  function offsetUnder(clientX, clientY) {
    const box = source.getBoundingClientRect();
    const line = Math.floor((clientY - box.top - cell.top + source.scrollTop) / cell.height);
    const column = Math.floor((clientX - box.left - cell.left + source.scrollLeft) / cell.width);
    const text = source.value;
    if (line < 0 || column < 0 || line >= text.split("\n").length) return -1;
    const character = characterAtColumn(lineText(text, line), column);
    return character < 0 ? -1 : offsetAt(text, { line, character });
  }

  // Scroll the text box just enough to show an offset.
  function reveal(offset) {
    const point = pointAt(offset);
    const { clientHeight, clientWidth } = source;
    if (point.y - cell.top < source.scrollTop) source.scrollTop = point.y - cell.top;
    else if (point.y + cell.height * 2 > source.scrollTop + clientHeight) source.scrollTop = point.y + cell.height * 2 - clientHeight;
    if (point.x - cell.left < source.scrollLeft) source.scrollLeft = Math.max(0, point.x - cell.left * 2);
    else if (point.x + cell.width * 2 > source.scrollLeft + clientWidth) source.scrollLeft = point.x + cell.width * 4 - clientWidth;
  }

  return { cell, measure, pointOf, pointAt, screenPoint, offsetUnder, reveal };
}
