import { preferButton } from "./buttons.js";
import { readerTarget } from "./platform.js";
import { tabPlatforms } from "./tabs.js";

const target = readerTarget();
preferButton(target);
tabPlatforms(target);
