package org.pudu;

import android.os.Build;
import android.view.View;
import android.view.accessibility.AccessibilityNodeInfo;

/** Accessibility beyond names: the traits of Std.Mobile.Access, a hint and a
 *  value, given to the platform's accessibility services through a
 *  delegate. Trait bits follow the iOS order; each maps to the closest role,
 *  state or action the platform has, and a trait the platform has no form
 *  for is kept for the report and otherwise ignored. */
final class PuduAccess extends View.AccessibilityDelegate {
  static final int BUTTON = 1, LINK = 1 << 1, HEADER = 1 << 2, SEARCH = 1 << 3, IMAGE = 1 << 4, SELECTED = 1 << 5,
      KEY = 1 << 7, STATIC_TEXT = 1 << 8, NOT_ENABLED = 1 << 10, UPDATES = 1 << 11, ADJUSTABLE = 1 << 13,
      PAGE_TURN = 1 << 15, TAB_BAR = 1 << 16, TOGGLE = 1 << 17;
  static final int R_ACCESS = 0x7f0f0003;

  final View view;
  int mask;
  String hint = "", value = "";

  private PuduAccess(View view) { this.view = view; }

  static PuduAccess of(View view) {
    PuduAccess held = (PuduAccess) view.getTag(R_ACCESS);
    if (held == null) {
      held = new PuduAccess(view);
      view.setTag(R_ACCESS, held);
      view.setAccessibilityDelegate(held);
    }
    return held;
  }

  void traits(int traits) {
    mask = traits;
    if (Build.VERSION.SDK_INT >= 28) view.setAccessibilityHeading((traits & HEADER) != 0);
    view.setSelected((traits & SELECTED) != 0);
    view.setAccessibilityLiveRegion((traits & UPDATES) != 0 ? View.ACCESSIBILITY_LIVE_REGION_POLITE : View.ACCESSIBILITY_LIVE_REGION_NONE);
    if (Build.VERSION.SDK_INT >= 28) view.setScreenReaderFocusable(true);
  }

  void hint(String text) {
    hint = text;
    if (Build.VERSION.SDK_INT >= 26) view.setTooltipText(text);
  }

  void value(String text) {
    value = text;
    if (Build.VERSION.SDK_INT >= 30) view.setStateDescription(text);
  }

  /** The role a screen reader announces for the traits. */
  private String role() {
    if ((mask & (BUTTON | KEY)) != 0) return "android.widget.Button";
    if ((mask & TOGGLE) != 0) return "android.widget.ToggleButton";
    if ((mask & SEARCH) != 0) return "android.widget.EditText";
    if ((mask & IMAGE) != 0) return "android.widget.ImageView";
    if ((mask & ADJUSTABLE) != 0) return "android.widget.SeekBar";
    if ((mask & TAB_BAR) != 0) return "android.widget.TabWidget";
    if ((mask & STATIC_TEXT) != 0) return "android.widget.TextView";
    return null;
  }

  @Override public void onInitializeAccessibilityNodeInfo(View host, AccessibilityNodeInfo info) {
    super.onInitializeAccessibilityNodeInfo(host, info);
    String role = role();
    if (role != null) info.setClassName(role);
    if (Build.VERSION.SDK_INT >= 26 && !hint.isEmpty()) info.setHintText(hint);
    if ((mask & NOT_ENABLED) != 0) info.setEnabled(false);
    if ((mask & (BUTTON | LINK)) != 0) info.setClickable(true);
    if ((mask & SELECTED) != 0) info.setSelected(true);
    if ((mask & ADJUSTABLE) != 0) {
      info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_FORWARD);
      info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_BACKWARD);
    }
    if ((mask & PAGE_TURN) != 0) info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_PAGE_DOWN);
  }
}
