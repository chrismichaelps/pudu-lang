// What the editor draws around the text area: the painted copy beneath it, the
// line numbers, the current line, and the marks under problems.
//
// The painted copy, the marks, and the line numbers follow the text area's
// scrolling by being moved rather than scrolled themselves, so none of them can
// stop short of where the text area went.

import { MESSAGES } from "../config/messages.js";
import { columnOf, countLines, positionAt } from "../text/positions.js";
import { colour } from "../text/syntax.js";
import { countProblems, isError } from "../model/problems.js";

export function createView({ source, highlight, gutter, code, geometry, status }) {
  const layer = document.createElement("div");
  layer.className = "playground-marks";
  layer.setAttribute("aria-hidden", "true");
  const currentLine = document.createElement("div");
  currentLine.className = "playground-line";
  const marks = document.createElement("div");
  layer.append(currentLine, marks);
  code.appendChild(layer);

  let paintedText = null;
  let lineCount = 0;
  let caretLine = -1;
  let problemLines = new Map();
  let queued = false;
  let shown = { problems: [], fresh: true };

  function paint() {
    const text = source.value;
    if (text !== paintedText) {
      highlight.innerHTML = colour(text) + "\n";
      paintedText = text;
      numberLines(countLines(text));
    }
    placeCurrentLine();
    follow();
  }

  function schedulePaint() {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      paint();
    });
  }

  function follow() {
    const shift = `translate(${-source.scrollLeft}px, ${-source.scrollTop}px)`;
    highlight.style.transform = shift;
    layer.style.transform = shift;
    gutter.scrollTop = source.scrollTop;
  }

  function numberLines(count) {
    if (count === lineCount) return;
    lineCount = count;
    const rows = [];
    for (let line = 1; line <= count; line += 1) rows.push(`<span>${line}</span>`);
    gutter.innerHTML = rows.join("\n");
    decorateGutter();
  }

  function decorateGutter() {
    const rows = gutter.children;
    for (let index = 0; index < rows.length; index += 1) {
      const kind = problemLines.get(index);
      const classes = [];
      if (kind) classes.push(`has-${kind}`);
      if (index === caretLine) classes.push("is-current");
      rows[index].className = classes.join(" ");
    }
  }

  function placeCurrentLine() {
    const collapsed = source.selectionStart === source.selectionEnd;
    const line = collapsed ? positionAt(source.value, source.selectionStart).line : -1;
    currentLine.hidden = line < 0 || document.activeElement !== source;
    if (line >= 0) {
      const { y } = geometry.pointOf(line, 0);
      currentLine.style.top = `${y}px`;
      currentLine.style.height = `${geometry.cell.height}px`;
    }
    if (line !== caretLine) {
      caretLine = line;
      decorateGutter();
    }
  }

  function showProblems(problems, fresh) {
    shown = { problems, fresh };
    const lines = source.value.split("\n");
    problemLines = new Map();
    marks.replaceChildren(...problems.flatMap((problem) => marksFor(problem, lines)));
    layer.classList.toggle("is-stale", !fresh);
    decorateGutter();
    const { errors, warnings } = countProblems(problems);
    status.setProblems(MESSAGES.problems(errors, warnings), errors ? "is-errors" : warnings ? "is-warnings" : "");
  }

  function marksFor(problem, lines) {
    const kind = isError(problem) ? "error" : "warning";
    const { start, end } = problem.range;
    const made = [];
    for (let line = start.line; line <= Math.min(end.line, lines.length - 1); line += 1) {
      const text = lines[line] ?? "";
      const from = line === start.line ? start.character : text.length - text.trimStart().length;
      const to = line === end.line ? Math.max(end.character, from + 1) : Math.max(text.length, from + 1);
      const left = columnOf(text, from);
      const point = geometry.pointOf(line, left);
      const mark = document.createElement("div");
      mark.className = `playground-mark is-${kind}`;
      mark.style.cssText = `left:${point.x}px;top:${point.y}px;width:${Math.max(1, columnOf(text, to) - left) * geometry.cell.width}px;height:${geometry.cell.height}px`;
      made.push(mark);
      if (problemLines.get(line) !== "error") problemLines.set(line, kind);
    }
    return made;
  }

  // Draw everything again, after the character cell was measured anew.
  function redraw() {
    paintedText = null;
    paint();
    showProblems(shown.problems, shown.fresh);
  }

  return { paint, schedulePaint, follow, showProblems, redraw };
}
