// The output pane: what a run printed, and how it ended.
//
// The nodes mirror `View.Playground.outcomeNodes`, so an answer shown in place
// and an answer to a form post look the same.

import { OUTCOME, PLACE_PATTERN } from "../config/constants.js";
import { MESSAGES } from "../config/messages.js";
import { element, paragraph } from "../dom/nodes.js";

const REVEAL_MARGIN = 80;

function reducedMotion() {
  return window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;
}

export function createOutput(pane, { onJump }) {
  const title = pane.querySelector(".playground-output-title");
  const initial = Array.from(pane.children).filter((node) => node !== title).map((node) => node.cloneNode(true));

  function show(nodes) {
    pane.replaceChildren(...(title ? [title] : []), ...nodes);
    const status = pane.querySelector(".playground-status");
    if (status) status.id = "playground-status";
    pane.scrollTop = 0;
  }

  return {
    status: (kind, text) => show([paragraph(`playground-status ${kind}`, text)]),
    outcome: (answer) => show(outcomeNodes(answer, onJump)),
    reset: () => show(initial.map((node) => node.cloneNode(true))),
    // Bring the pane into view when it starts below the window, as it does
    // under the editor on a narrow screen.
    reveal() {
      if (pane.getBoundingClientRect().top > window.innerHeight - REVEAL_MARGIN) {
        pane.scrollIntoView({ block: "start", behavior: reducedMotion() ? "auto" : "smooth" });
      }
    },
    busy(on) {
      if (on) pane.setAttribute("aria-busy", "true");
      else pane.removeAttribute("aria-busy");
    },
  };
}

// Mirrors `View.Playground.statusClass`.
export function statusClass(answer) {
  if (answer.outcome === OUTCOME.finished) return answer.status === 0 ? "is-ok" : "is-failed";
  if (answer.outcome === OUTCOME.timedOut) return "is-failed";
  if (answer.outcome === OUTCOME.formatted) return "is-ok";
  return "is-refused";
}

function outcomeNodes(answer, onJump) {
  const nodes = [paragraph(`playground-status ${statusClass(answer)}`, String(answer.headline || answer.reason || ""))];
  if (answer.meaning) nodes.push(paragraph("playground-meaning", String(answer.meaning)));
  if (answer.outcome !== OUTCOME.finished && answer.outcome !== OUTCOME.timedOut) return nodes;
  const printed = typeof answer.output === "string" ? answer.output : "";
  const errors = typeof answer.errors === "string" ? answer.errors : "";
  if (printed) nodes.push(stream("playground-stream", MESSAGES.standardOutput, printed, onJump));
  if (errors) nodes.push(stream("playground-stream is-errors", MESSAGES.standardError, errors, onJump));
  if (!printed && !errors) nodes.push(paragraph("playground-empty", MESSAGES.printedNothing));
  return nodes;
}

// A stream, with each place a diagnostic names — `Main.pudu:4:7` — made a
// button that puts the caret there.
function stream(className, label, text, onJump) {
  const pre = element("pre", className);
  pre.setAttribute("aria-label", label);
  const code = element("code");
  let at = 0;
  for (const found of text.matchAll(PLACE_PATTERN)) {
    code.append(text.slice(at, found.index), jumpButton(found, onJump));
    at = found.index + found[0].length;
  }
  code.append(text.slice(at));
  pre.appendChild(code);
  return pre;
}

function jumpButton(found, onJump) {
  const button = element("button", "playground-jump", found[0]);
  button.type = "button";
  const line = Number(found[2]) - 1;
  const character = Number(found[3]) - 1;
  button.addEventListener("click", () => onJump({ line, character }));
  return button;
}
