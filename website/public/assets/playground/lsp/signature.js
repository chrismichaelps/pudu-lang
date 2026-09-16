// The signature of the call being written, shown above it.

import { ASSIST } from "../config/constants.js";
import { createFloating, hideFloating, placeFloating } from "../dom/floating.js";
import { documentationText, markdownNodes } from "../dom/markdown.js";
import { element } from "../dom/nodes.js";
import { inCommentOrString, openCallAt } from "../text/scan.js";

const GAP = 6;

export function createSignatureHelp({ editor, session }) {
  const panel = createFloating("playground-tip playground-signature", editor.signal);
  let round = 0;

  async function request() {
    const text = editor.text();
    const caret = editor.caret();
    const opened = openCallAt(text, caret);
    if (opened < 0 || inCommentOrString(text, caret)) {
      hide();
      return;
    }
    const mine = ++round;
    const answer = await session.ask(ASSIST.signatureHelp, text, editor.positionOf(caret, text));
    if (!answer || mine !== round || answer.text !== editor.text()) return;
    const signatures = answer.result?.signatures;
    if (!Array.isArray(signatures) || signatures.length === 0) {
      hide();
      return;
    }
    show(answer.result, opened);
  }

  function show(result, opened) {
    const active = result.signatures[result.activeSignature ?? 0] ?? result.signatures[0];
    if (typeof active?.label !== "string") return;
    const parameter = result.activeParameter ?? active.activeParameter ?? 0;
    const parts = [labelNode(active.label, active.parameters?.[parameter]?.label)];
    const documentation = documentationText(active.documentation);
    if (documentation) parts.push(...markdownNodes(documentation));
    panel.replaceChildren(...parts);
    const point = editor.screenPoint(opened);
    panel.hidden = false;
    placeFloating(panel, point.x, point.y - GAP - panel.offsetHeight, point.y + editor.lineHeight() + GAP);
  }

  function hide() {
    round += 1;
    hideFloating(panel);
  }

  return {
    request,
    hide,
    get visible() {
      return !panel.hidden;
    },
    // The text changed by typing `typed`, when that is known.
    typed(typedText) {
      if (typedText === "(" || typedText === ",") request();
      else if (!panel.hidden && openCallAt(editor.text(), editor.caret()) < 0) hide();
    },
  };
}

// The signature with the active parameter marked. A parameter is named by its
// range in the label or by its own text.
function labelNode(label, parameter) {
  let from = -1;
  let to = -1;
  if (Array.isArray(parameter)) [from, to] = parameter;
  else if (typeof parameter === "string") {
    from = label.indexOf(parameter);
    to = from + parameter.length;
  }
  const code = element("code");
  if (from >= 0 && to <= label.length && from < to) {
    code.append(label.slice(0, from), element("strong", "", label.slice(from, to)), label.slice(to));
  } else {
    code.textContent = label;
  }
  return code;
}
