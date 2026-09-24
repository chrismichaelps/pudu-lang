import { PLATFORM, PLATFORMS, TAB_CLASS, TABBED_CLASS, TABLIST_CLASS } from "./constants.js";

// Turn the install sections into tabs, selecting the reader's platform.
export function tabPlatforms(target) {
  const holder = document.querySelector(PLATFORMS);
  const panels = holder ? [...holder.querySelectorAll(PLATFORM)] : [];
  if (panels.length < 2) return;
  const list = document.createElement("div");
  list.className = TABLIST_CLASS;
  list.setAttribute("role", "tablist");
  list.setAttribute("aria-label", "Platform");
  const tabs = panels.map((panel) => {
    const tab = document.createElement("button");
    tab.type = "button";
    tab.className = TAB_CLASS;
    tab.id = `${panel.id}-tab`;
    tab.textContent = panel.dataset.label;
    tab.setAttribute("role", "tab");
    tab.setAttribute("aria-controls", panel.id);
    panel.setAttribute("role", "tabpanel");
    panel.setAttribute("aria-labelledby", tab.id);
    list.append(tab);
    return tab;
  });
  const select = (index, focus) => {
    tabs.forEach((tab, at) => {
      const on = at === index;
      tab.setAttribute("aria-selected", String(on));
      tab.tabIndex = on ? 0 : -1;
      panels[at].hidden = !on;
    });
    if (focus) tabs[index].focus();
  };
  list.addEventListener("click", (event) => {
    const index = tabs.indexOf(event.target.closest(`.${TAB_CLASS}`));
    if (index >= 0) select(index, false);
  });
  list.addEventListener("keydown", (event) => {
    const current = tabs.findIndex((tab) => tab.getAttribute("aria-selected") === "true");
    const moves = { ArrowRight: current + 1, ArrowLeft: current - 1, Home: 0, End: tabs.length - 1 };
    if (!(event.key in moves)) return;
    event.preventDefault();
    select((moves[event.key] + tabs.length) % tabs.length, true);
  });
  holder.prepend(list);
  holder.classList.add(TABBED_CLASS);
  const preferred = panels.findIndex((panel) => panel.dataset.platform === target);
  select(preferred < 0 ? 0 : preferred, false);
}
