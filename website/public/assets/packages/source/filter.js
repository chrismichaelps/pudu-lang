import { HIDDEN_CLASS } from "../constants.js";

function applyFilter(tree, query) {
  const wanted = query.trim().toLowerCase();
  for (const file of tree.querySelectorAll(".code-tree-file")) {
    const shown = wanted === "" || file.dataset.path.toLowerCase().includes(wanted);
    file.classList.toggle(HIDDEN_CLASS, !shown);
  }
  const folders = [...tree.querySelectorAll(".code-tree-folder")].reverse();
  for (const folder of folders) {
    const visible = folder.querySelector(`.code-tree-file:not(.${HIDDEN_CLASS})`) !== null;
    folder.classList.toggle(HIDDEN_CLASS, !visible);
    if (wanted !== "" && visible) folder.querySelector("details")?.setAttribute("open", "");
  }
}

export function bindSourceFilter(root) {
  const input = root.querySelector(".code-filter");
  const tree = root.querySelector(".code-sidebar nav");
  if (!input || !tree) return;
  input.addEventListener("input", () => applyFilter(tree, input.value));
}
