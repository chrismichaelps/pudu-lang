// A choreography waits here before each act, so nothing plays in a hidden tab
// or while the banner is scrolled out of view.

export function watchVisibility(host) {
  let onScreen = true;
  const waiting = [];
  const release = () => {
    if (onScreen && !document.hidden) waiting.splice(0).forEach((resolve) => resolve());
  };
  new IntersectionObserver((entries) => {
    onScreen = entries.some((entry) => entry.isIntersecting);
    release();
  }).observe(host);
  document.addEventListener("visibilitychange", release);
  return () => (onScreen && !document.hidden ? Promise.resolve() : new Promise((resolve) => waiting.push(resolve)));
}
