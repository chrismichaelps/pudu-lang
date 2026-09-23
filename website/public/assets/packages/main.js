import { bindCopyButtons } from "./clipboard/copy.js";
import { bindVersionPickers } from "./install/picker.js";
import { bindSourceFilter } from "./source/filter.js";
import "./pagination.js?v=3";

bindVersionPickers(document);
bindCopyButtons(document);
bindSourceFilter(document);
