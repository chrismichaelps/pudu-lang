// Blinks on their own clock, whatever else the pudu is doing.

import { BLINK } from "../config/constants.js";
import { blink } from "../motion/moves.js";
import { between, chance, wait } from "../motion/timing.js";

export async function blinking(pudu, slow = 1) {
  for (;;) {
    await wait(between(BLINK.min, BLINK.max) * slow);
    await pudu.visible();
    await blink(pudu);
    if (chance(BLINK.twice)) {
      await wait(90);
      await blink(pudu);
    }
  }
}
