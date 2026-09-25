// Promise-returning animation and time. A finished animation commits its end
// state to the element's style and is cancelled, so moves never stack fills.

/// Animates `element` to `frames` and settles with the end state kept.
export function play(element, frames, options) {
  const animation = element.animate(frames, { fill: "forwards", ...options });
  return animation.finished.then(
    () => {
      animation.commitStyles();
      animation.cancel();
    },
    () => {},
  );
}

/// Animates `element` from its current transform to `transform`.
export function to(element, transform, duration, easing) {
  return play(element, [{ transform }], { duration, easing });
}

export function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function between(low, high) {
  return low + Math.random() * (high - low);
}

export function chance(probability) {
  return Math.random() < probability;
}

export function pick(items) {
  return items[Math.floor(Math.random() * items.length)];
}
