import { bindSearchBox } from "./search/box.js";
import { FORM_SELECTOR } from "./search/constants.js";

const forms = [...document.querySelectorAll(FORM_SELECTOR)];
forms.forEach(bindSearchBox);

function typing(target) {
  return target instanceof HTMLElement && (target.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName));
}

document.addEventListener("keydown", (event) => {
  if (event.key !== "/" || event.metaKey || event.ctrlKey || event.altKey || typing(event.target)) return;
  const field = forms[0]?.querySelector('input[name="q"]');
  if (!field) return;
  event.preventDefault();
  field.focus();
  field.select();
});
