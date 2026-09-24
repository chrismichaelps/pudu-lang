// Copy a code block's text.
//
// Each block ships its button hidden, so a page read without script never
// offers a button that does nothing. The text comes from the block itself
// rather than a copy kept in an attribute, which would double every block.
// The asynchronous clipboard is tried first; where it is missing or refused
// (an insecure page, a frame without permission), the text is selected in a
// hidden field and copied the way browsers did before it.

import { CODE_COPY, CODE_FIGURE, CODE_TEXT, COPIED_LABEL, COPIED_MILLIS, COPY_FAILED_LABEL } from "./constants.js";

async function writeText(text) {
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      // Refused: fall through to the selection.
    }
  }
  const field = document.createElement("textarea");
  field.value = text;
  field.setAttribute("readonly", "");
  field.style.position = "fixed";
  field.style.inset = "0 auto auto 0";
  field.style.opacity = "0";
  document.body.append(field);
  field.select();
  let copied = false;
  try {
    copied = document.execCommand("copy");
  } catch {
    copied = false;
  }
  field.remove();
  return copied;
}

export function bindCodeCopy(root = document) {
  for (const button of root.querySelectorAll(CODE_COPY)) {
    const code = button.closest(CODE_FIGURE)?.querySelector(CODE_TEXT);
    if (!code) continue;
    const label = button.textContent;
    button.hidden = false;
    button.addEventListener("click", async () => {
      button.textContent = (await writeText(code.textContent)) ? COPIED_LABEL : COPY_FAILED_LABEL;
      setTimeout(() => { button.textContent = label; }, COPIED_MILLIS);
    });
  }
}

bindCodeCopy();
