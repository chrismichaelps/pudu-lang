import { bindCopyButtons } from "./clipboard/copy.js";
import { bindVersionPickers } from "./install/picker.js";
import { bindSourceFilter } from "./source/filter.js";
import { bindSourceNavigation } from "./source/navigate.js";
import "./pagination.js?v=3";
import "../docs/copy.js?v=1";

bindVersionPickers(document);
bindCopyButtons(document);
bindSourceFilter(document);
bindSourceNavigation(document);
