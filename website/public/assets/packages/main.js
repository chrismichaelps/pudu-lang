import { bindCopyButtons } from "./clipboard/copy.js";
import { bindVersionPickers } from "./install/picker.js";
import { bindSourceFilter } from "./source/filter.js";

bindVersionPickers(document);
bindCopyButtons(document);
bindSourceFilter(document);
