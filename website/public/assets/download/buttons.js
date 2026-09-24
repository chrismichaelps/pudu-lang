import { BUTTON, BUTTONS, PRIMARY, SECONDARY } from "./constants.js";

// Make the reader's archive the primary button and move it first.
export function preferButton(target) {
  const row = document.querySelector(BUTTONS);
  const chosen = target && row?.querySelector(`${BUTTON}[data-platform="${target}"]`);
  if (!chosen) return;
  for (const button of row.querySelectorAll(BUTTON)) {
    button.classList.toggle(PRIMARY, button === chosen);
    button.classList.toggle(SECONDARY, button !== chosen);
  }
  row.prepend(chosen);
}
