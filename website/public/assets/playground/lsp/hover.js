// What the pointer rests on: the problems there, and what the server says the
// name is.

import { ASSIST, HOVER_DELAY_MS, HOVER_HIDE_GRACE_MS } from "../config/constants.js";
import { createFloating, hideFloating, placeFloating } from "../dom/floating.js";
import { markdownNodes } from "../dom/markdown.js";
import { paragraph } from "../dom/nodes.js";
import { isNameCharacter } from "../text/scan.js";
import { isError } from "../model/problems.js";

const BELOW_POINTER = 16;
const BELOW_LINE = 4;

export function createHover({ editor, session, problemsAt, blocked }) {
  const panel = createFloating("playground-tip", editor.signal);
  let showTimer = null;
  let hideTimer = null;
  let hovered = -1;
  let round = 0;

  panel.addEventListener("mouseenter", () => clearTimeout(hideTimer));
  panel.addEventListener("mouseleave", hideSoon);

  function pointerMoved(event) {
    if (blocked()) return;
    const offset = editor.offsetUnder(event.clientX, event.clientY);
    if (offset === hovered) return;
    hovered = offset;
    clearTimeout(showTimer);
    if (offset < 0) {
      hideSoon();
      return;
    }
    showTimer = setTimeout(() => explain(offset, event.clientX, event.clientY), HOVER_DELAY_MS);
  }

  function pointerLeft() {
    clearTimeout(showTimer);
    hovered = -1;
    hideSoon();
  }

  function hideSoon() {
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => {
      if (!panel.matches(":hover")) hide();
    }, HOVER_HIDE_GRACE_MS);
  }

  async function explain(offset, x, y) {
    const mine = ++round;
    const text = editor.text();
    const parts = problemsAt(offset).map(problemNode);
    const answer = isNameCharacter(text[offset])
      ? await session.ask(ASSIST.hover, text, editor.positionOf(offset, text))
      : null;
    if (mine !== round || hovered !== offset) return;
    if (answer && answer.text === editor.text()) parts.push(...markdownNodes(hoverText(answer.result)));
    if (parts.length === 0) {
      hide();
      return;
    }
    clearTimeout(hideTimer);
    showAt(parts, x, y + BELOW_POINTER, y - editor.lineHeight());
  }

  // The problems at an offset, shown under its line: how F8 explains the
  // problem it moved to.
  function showProblemsAt(offset) {
    const parts = problemsAt(offset).map(problemNode);
    if (parts.length === 0) return;
    const point = editor.screenPoint(offset);
    showAt(parts, point.x, point.y + editor.lineHeight() + BELOW_LINE, point.y);
  }

  function showAt(parts, x, below, above) {
    panel.replaceChildren(...parts);
    placeFloating(panel, x, below, above);
  }

  function hide() {
    round += 1;
    hideFloating(panel);
  }

  return {
    pointerMoved,
    pointerLeft,
    showProblemsAt,
    hide,
    get visible() {
      return !panel.hidden;
    },
  };
}

function hoverText(result) {
  const contents = result?.contents;
  if (!contents) return "";
  if (typeof contents === "string") return contents;
  if (Array.isArray(contents)) {
    return contents.map((entry) => (typeof entry === "string" ? entry : entry?.value ?? "")).join("\n\n");
  }
  return typeof contents.value === "string" ? contents.value : "";
}

function problemNode(problem) {
  return paragraph(`playground-tip-problem ${isError(problem) ? "is-error" : "is-warning"}`, problem.message);
}
